import 'dart:async';
import 'dart:collection';
import '../core/agent_base.dart';
import '../core/step_logger.dart';

/// Priority levels for tasks
enum TaskPriority {
  low,
  normal,
  high,
  critical,
}

/// A task in the queue
class QueuedTask {
  /// Unique task ID
  final String id;

  /// Agent to execute this task
  final AgentBase agent;

  /// Input for the agent
  final dynamic input;

  /// Priority level
  final TaskPriority priority;

  /// Tasks that must complete before this one
  final List<String> dependsOn;

  /// When this task was queued
  final DateTime queuedAt;

  /// Completer for async result
  final Completer<dynamic> _completer = Completer<dynamic>();

  /// Current status
  TaskQueueStatus status;

  QueuedTask({
    required this.id,
    required this.agent,
    required this.input,
    this.priority = TaskPriority.normal,
    this.dependsOn = const [],
  })  : queuedAt = DateTime.now(),
        status = TaskQueueStatus.pending;

  /// Get the future result
  Future<dynamic> get result => _completer.future;

  /// Complete the task with result
  void complete(dynamic result) {
    status = TaskQueueStatus.completed;
    _completer.complete(result);
  }

  /// Fail the task with error
  void fail(Object error) {
    status = TaskQueueStatus.failed;
    _completer.completeError(error);
  }
}

/// Status of a queued task
enum TaskQueueStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
}

/// Task queue for managing parallel and sequential agent execution.
/// Supports dependency resolution and priority ordering.
class TaskQueue {
  /// All tasks
  final Map<String, QueuedTask> _tasks = {};

  /// Pending tasks by priority
  final Map<TaskPriority, Queue<String>> _pendingQueues = {
    TaskPriority.critical: Queue<String>(),
    TaskPriority.high: Queue<String>(),
    TaskPriority.normal: Queue<String>(),
    TaskPriority.low: Queue<String>(),
  };

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
    List<String> dependsOn = const [],
  }) {
    final taskId = 'task_${++_taskCounter}';

    final task = QueuedTask(
      id: taskId,
      agent: agent,
      input: input,
      priority: priority,
      dependsOn: dependsOn,
    );

    _tasks[taskId] = task;
    _pendingQueues[priority]!.add(taskId);

    // Start processing if not already
    _processQueue();

    return task.result.then((r) => r as T);
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

  /// Run tasks in parallel (respecting maxConcurrent)
  Future<List<T>> runParallel<T>(List<Future<T>> futures) async {
    // Chunk into max concurrent batches
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

    while (_hasRunnableTasks() && _runningTasks.length < maxConcurrent) {
      final taskId = _getNextTask();
      if (taskId == null) break;

      _runTask(taskId);
    }

    _isProcessing = false;
  }

  /// Check if there are tasks that can run
  bool _hasRunnableTasks() {
    for (final queue in _pendingQueues.values) {
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
    // Check each priority level in order
    for (final priority in TaskPriority.values.reversed) {
      final queue = _pendingQueues[priority]!;
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

  /// Run a specific task
  Future<void> _runTask(String taskId) async {
    final task = _tasks[taskId]!;
    task.status = TaskQueueStatus.running;
    _runningTasks.add(taskId);

    try {
      final result = await task.agent.run(task.input);
      task.complete(result);
      _completedTasks.add(taskId);
    } catch (e) {
      task.fail(e);
    } finally {
      _runningTasks.remove(taskId);
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
      _pendingQueues[task.priority]!.remove(taskId);
    }
  }

  /// Get task by ID
  QueuedTask? getTask(String taskId) => _tasks[taskId];

  /// Get all running tasks
  List<QueuedTask> get runningTasks =>
      _runningTasks.map((id) => _tasks[id]!).toList();

  /// Get pending task count
  int get pendingCount =>
      _pendingQueues.values.fold(0, (sum, q) => sum + q.length);

  /// Clear completed tasks from memory
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
