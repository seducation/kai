import 'dart:async';
import 'dart:collection';
import '../core/agent_base.dart';
import '../core/step_logger.dart';
import '../core/step_types.dart';
import '../core/step_schema.dart';
import '../rules/rule_definitions.dart'; // For PriorityLevel

/// Priority levels for tasks (Legacy Enum mapped to new system)
enum TaskPriority {
  low, // 20
  normal, // 40
  high, // 60
  critical, // 90
}

extension TaskPriorityValues on TaskPriority {
  int get value {
    switch (this) {
      case TaskPriority.low:
        return PriorityLevel.low;
      case TaskPriority.normal:
        return PriorityLevel.normal;
      case TaskPriority.high:
        return PriorityLevel.high;
      case TaskPriority.critical:
        return PriorityLevel.critical;
    }
  }
}

/// A task in the queue
class QueuedTask {
  /// Unique task ID
  final String id;

  /// Agent to execute this task
  final AgentBase agent;

  /// Input for the agent
  final dynamic input;

  /// Priority value (higher = more urgent)
  final int priority;

  /// Tasks that must complete before this one
  final List<String> dependsOn;

  /// When this task was queued
  final DateTime queuedAt;

  /// Token for preemption
  CancellationToken? token;

  /// Completer for async result
  final Completer<dynamic> _completer = Completer<dynamic>();

  /// Current status
  TaskQueueStatus status;

  QueuedTask({
    required this.id,
    required this.agent,
    required this.input,
    this.priority = PriorityLevel.normal,
    this.dependsOn = const [],
  })  : queuedAt = DateTime.now(),
        status = TaskQueueStatus.pending;

  /// Get the future result
  Future<dynamic> get result => _completer.future;

  /// Complete the task with result
  void complete(dynamic result) {
    status = TaskQueueStatus.completed;
    if (!_completer.isCompleted) _completer.complete(result);
  }

  /// Fail the task with error
  void fail(Object error) {
    status = TaskQueueStatus.failed;
    if (!_completer.isCompleted) _completer.completeError(error);
  }
}

/// Status of a queued task
enum TaskQueueStatus {
  pending,
  running,
  paused, // Preempted
  completed,
  failed,
  cancelled,
}

/// Task queue for managing parallel and sequential agent execution.
/// Supports dependency resolution and priority-based preemption.
class TaskQueue {
  /// All tasks
  final Map<String, QueuedTask> _tasks = {};

  /// Pending tasks ordered by priority (descending)
  final SplayTreeMap<int, Queue<String>> _priorityBuckets =
      SplayTreeMap((a, b) => b.compareTo(a));

  /// Currently running tasks
  final Set<String> _runningTasks = {};

  /// Completed task IDs (for dependency checking)
  final Set<String> _completedTasks = {};

  /// Maximum concurrent tasks
  final int maxConcurrent;

  /// Step logger for logging queue operations
  final StepLogger logger;

  /// Whether the queue is processing
  bool _isProcessing = false;

  /// Task counter for unique IDs
  int _taskCounter = 0;

  TaskQueue({
    this.maxConcurrent = 4,
    StepLogger? logger,
  }) : logger = logger ?? GlobalStepLogger().logger;

  /// Add a task to the queue
  Future<T> enqueue<T>({
    required AgentBase agent,
    required dynamic input,
    TaskPriority priority = TaskPriority.normal,
    int? explicitPriority, // Allow overriding the enum
    List<String> dependsOn = const [],
  }) {
    final taskId = 'task_${++_taskCounter}';
    final priorityVal = explicitPriority ?? priority.value;

    final task = QueuedTask(
      id: taskId,
      agent: agent,
      input: input,
      priority: priorityVal,
      dependsOn: dependsOn,
    );

    _tasks[taskId] = task;
    _addToBucket(taskId, priorityVal);

    // Check for preemption
    _checkForPreemption(task);

    // Start processing if not already
    _processQueue();

    return task.result.then((r) => r as T);
  }

  void _addToBucket(String taskId, int priority) {
    if (!_priorityBuckets.containsKey(priority)) {
      _priorityBuckets[priority] = Queue<String>();
    }
    _priorityBuckets[priority]!.add(taskId);
  }

  /// Run tasks sequentially
  Future<List<T>> runSequential<T>(List<AgentTask<T>> tasks) async {
    final results = <T>[];
    for (final task in tasks) {
      final result = await task.execute();
      results.add(result);
    }
    return results;
  }

  /// Run tasks in parallel
  Future<List<T>> runParallel<T>(List<Future<T>> futures) async {
    final results = <T>[];
    final chunks = <List<Future<T>>>[];
    for (var i = 0; i < futures.length; i += maxConcurrent) {
      chunks.add(futures.skip(i).take(maxConcurrent).toList());
    }
    for (final chunk in chunks) {
      final chunkResults = await Future.wait(chunk);
      results.addAll(chunkResults);
    }
    return results;
  }

  /// Process the queue
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (_hasRunnableTasks() && _runningTasks.length < maxConcurrent) {
        final taskId = _getNextTask();
        if (taskId == null) break;

        _runTask(taskId);
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Check if there are tasks that can run
  bool _hasRunnableTasks() {
    for (final queue in _priorityBuckets.values) {
      for (final taskId in queue) {
        final task = _tasks[taskId]!;
        if (_canRun(task)) return true;
      }
    }
    return false;
  }

  /// Check if a task can run (dependencies satisfied)
  bool _canRun(QueuedTask task) {
    return task.dependsOn.every((dep) => _completedTasks.contains(dep));
  }

  /// Get the next task to run (highest priority, dependencies satisfied)
  String? _getNextTask() {
    // Buckets are already sorted descending
    for (final priority in _priorityBuckets.keys) {
      final queue = _priorityBuckets[priority]!;
      for (final taskId in queue) {
        final task = _tasks[taskId]!;
        if (_canRun(task)) {
          queue.remove(taskId);
          return taskId;
        }
      }
    }
    return null;
  }

  /// Preempt lower priority tasks if full
  void _checkForPreemption(QueuedTask urgentTask) {
    if (_runningTasks.length < maxConcurrent) return;

    // Find the lowest priority running task
    String? lowestId;
    int lowestPriority = 9999;

    for (final id in _runningTasks) {
      final task = _tasks[id]!;
      if (task.priority < lowestPriority) {
        lowestPriority = task.priority;
        lowestId = id;
      }
    }

    // If urgent task is higher priority than lowest running
    if (lowestId != null && urgentTask.priority > lowestPriority) {
      final lowestTask = _tasks[lowestId]!;

      // Log preemption event
      logger.logStep(
          agentName: 'System',
          action: StepType.decide,
          target:
              'Priority Interrupt: Task ${urgentTask.id} (P${urgentTask.priority}) requested override of Task $lowestId (P$lowestPriority)',
          status: StepStatus.success);

      // Trigger Actual Preemption
      lowestTask.token?.cancel();
      lowestTask.status = TaskQueueStatus.paused;
    }
  }

  /// Run a specific task
  Future<void> _runTask(String taskId) async {
    final task = _tasks[taskId]!;
    task.status = TaskQueueStatus.running;
    _runningTasks.add(taskId);

    final token = CancellationToken();
    task.token = token;

    try {
      final result = await task.agent.run(task.input, token: token);
      task.complete(result);
      _completedTasks.add(taskId);
    } catch (e) {
      if (e is CancelledException) {
        // Re-queue or fail as 'paused'
        task.fail(e);
      } else {
        task.fail(e);
      }
    } finally {
      _runningTasks.remove(taskId);
      task.token = null;
      // Check if more tasks can run
      _processQueue();
    }
  }

  /// Cancel a task
  void cancel(String taskId) {
    final task = _tasks[taskId];
    if (task == null) return;

    if (task.status == TaskQueueStatus.pending) {
      task.status = TaskQueueStatus.cancelled;
      // Find and remove from bucket
      for (final queue in _priorityBuckets.values) {
        if (queue.remove(taskId)) break;
      }
    }
  }

  QueuedTask? getTask(String taskId) => _tasks[taskId];

  List<QueuedTask> get runningTasks =>
      _runningTasks.map((id) => _tasks[id]!).toList();

  int get pendingCount =>
      _priorityBuckets.values.fold(0, (sum, q) => sum + q.length);

  void clearCompleted() {
    _tasks.removeWhere(
      (id, task) =>
          task.status == TaskQueueStatus.completed ||
          task.status == TaskQueueStatus.failed ||
          task.status == TaskQueueStatus.cancelled,
    );
  }
}

/// Global task queue instance
final taskQueue = TaskQueue();
