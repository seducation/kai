import 'dart:async';
import 'step_logger.dart';
import 'step_schema.dart';
import 'step_types.dart';

/// Token for cancelling agent execution
class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// Exception thrown when a task is cancelled
class CancelledException implements Exception {
  final String message;
  CancelledException([this.message = 'Task was cancelled']);
  @override
  String toString() => 'CancelledException: $message';
}

/// Abstract base class for all agents.
/// Enforces auto-logging - agents CANNOT perform actions without logging.
/// This is how we ensure execution transparency.
abstract class AgentBase {
  /// Unique name of this agent
  final String name;

  /// Step logger instance (shared or per-agent)
  final StepLogger logger;

  /// Whether this agent is currently executing
  bool _isExecuting = false;

  /// Current cancellation token
  CancellationToken? _activeToken;

  AgentBase({
    required this.name,
    StepLogger? logger,
  }) : logger = logger ?? GlobalStepLogger().logger;

  /// Check if agent is currently executing
  bool get isExecuting => _isExecuting;

  /// Execute an action with automatic logging.
  /// This is the ONLY way agents should perform actions.
  /// Ensures: action → log → result (never action without log)
  Future<T> execute<T>({
    required StepType action,
    required String target,
    required Future<T> Function() task,
    Map<String, dynamic>? metadata,
  }) async {
    throwIfCancelled();

    final stopwatch = Stopwatch()..start();

    // Log step start
    final step = logger.startStep(
      agentName: name,
      action: action,
      target: target,
      metadata: metadata,
    );

    try {
      // Execute the actual task
      final result = await task();

      throwIfCancelled();

      stopwatch.stop();

      // Log success
      logger.completeStep(
        stepId: step.stepId,
        duration: stopwatch.elapsed,
        metadata: {'result_type': T.toString()},
      );

      return result;
    } catch (e) {
      stopwatch.stop();

      // Log failure (if not already failed via throwIfCancelled)
      if (e is CancelledException) {
        logger.failStep(
          stepId: step.stepId,
          errorMessage: 'Interrupt: User or System requested stop.',
          duration: stopwatch.elapsed,
        );
      } else {
        logger.failStep(
          stepId: step.stepId,
          errorMessage: e.toString(),
          duration: stopwatch.elapsed,
        );
      }

      // Re-throw for caller to handle
      rethrow;
    }
  }

  /// Helper to check if task was interrupted
  void throwIfCancelled() {
    if (_activeToken?.isCancelled ?? false) {
      throw CancelledException('Agent $name was interrupted.');
    }
  }

  /// Execute multiple actions in sequence
  Future<List<T>> executeSequence<T>({
    required List<AgentTask<T>> tasks,
  }) async {
    final results = <T>[];

    for (final task in tasks) {
      final result = await execute<T>(
        action: task.action,
        target: task.target,
        task: task.execute,
        metadata: task.metadata,
      );
      results.add(result);
    }

    return results;
  }

  /// Execute multiple actions in parallel
  Future<List<T>> executeParallel<T>({
    required List<AgentTask<T>> tasks,
  }) async {
    final futures = tasks.map((task) => execute<T>(
          action: task.action,
          target: task.target,
          task: task.execute,
          metadata: task.metadata,
        ));

    return Future.wait(futures);
  }

  /// Log a simple status update (no execution)
  void logStatus(StepType action, String target, StepStatus status) {
    logger.logStep(
      agentName: name,
      action: action,
      target: target,
      status: status,
    );
  }

  /// Start execution context
  void _startExecution(CancellationToken? token) {
    if (_isExecuting) {
      throw StateError('$name is already executing');
    }
    _isExecuting = true;
    _activeToken = token;
  }

  /// End execution context
  void _endExecution() {
    _isExecuting = false;
    _activeToken = null;
  }

  /// Run the agent with a given input.
  /// Subclasses implement the actual logic.
  Future<R> run<R>(dynamic input, {CancellationToken? token}) async {
    _startExecution(token);
    try {
      return await onRun<R>(input);
    } finally {
      _endExecution();
    }
  }

  /// Override this in subclasses to implement agent logic
  Future<R> onRun<R>(dynamic input);

  /// Get all steps performed by this agent
  List<AgentStep> get steps => logger.getStepsForAgent(name);

  /// Get the last step performed by this agent
  AgentStep? get lastStep {
    final agentSteps = steps;
    return agentSteps.isNotEmpty ? agentSteps.last : null;
  }
}

/// A task to be executed by an agent
class AgentTask<T> {
  final StepType action;
  final String target;
  final Future<T> Function() execute;
  final Map<String, dynamic>? metadata;

  const AgentTask({
    required this.action,
    required this.target,
    required this.execute,
    this.metadata,
  });
}

/// Mixin for agents that need to call other agents
mixin AgentDelegation on AgentBase {
  /// Delegate work to another agent
  Future<T> delegateTo<T>(
    AgentBase agent,
    dynamic input,
  ) async {
    // Log that we're delegating
    logger.logStep(
      agentName: name,
      action: StepType.decide,
      target: 'delegate to ${agent.name}',
      status: StepStatus.success,
    );

    // Run the other agent
    return agent.run<T>(input);
  }
}

/// Mixin for agents that can be paused/resumed
mixin PausableAgent on AgentBase {
  bool _isPaused = false;
  final Completer<void> _resumeCompleter = Completer<void>();

  bool get isPaused => _isPaused;

  void pause() {
    _isPaused = true;
    logger.logStep(
      agentName: name,
      action: StepType.waiting,
      target: 'paused by user',
      status: StepStatus.pending,
    );
  }

  void resume() {
    _isPaused = false;
    if (!_resumeCompleter.isCompleted) {
      _resumeCompleter.complete();
    }
    logger.logStep(
      agentName: name,
      action: StepType.decide,
      target: 'resumed',
      status: StepStatus.success,
    );
  }

  Future<void> waitIfPaused() async {
    if (_isPaused) {
      await _resumeCompleter.future;
    }
  }
}
