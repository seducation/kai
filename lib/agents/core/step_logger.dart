import 'dart:async';
import 'step_schema.dart';
import 'step_types.dart';

/// Single source of truth for agent actions.
/// Logs are written by CODE, not AI.
/// No action → No log → No narration
class StepLogger {
  /// In-memory step history
  final List<AgentStep> _steps = [];

  /// Stream controller for live updates
  final StreamController<AgentStep> _stepController =
      StreamController<AgentStep>.broadcast();

  /// Counter for step IDs
  int _stepCounter = 0;

  /// Get all logged steps
  List<AgentStep> get allSteps => List.unmodifiable(_steps);

  /// Get the latest step
  AgentStep? get latestStep => _steps.isNotEmpty ? _steps.last : null;

  /// Stream of steps for live UI updates
  Stream<AgentStep> get stepStream => _stepController.stream;

  /// Total number of steps logged
  int get stepCount => _steps.length;

  /// Log a new step - this is the ONLY way actions get recorded
  AgentStep logStep({
    required String agentName,
    required StepType action,
    required String target,
    required StepStatus status,
    Map<String, dynamic>? metadata,
    String? errorMessage,
    Duration? duration,
  }) {
    final step = AgentStep(
      stepId: ++_stepCounter,
      agentName: agentName,
      action: action,
      target: target,
      status: status,
      timestamp: DateTime.now(),
      metadata: metadata,
      errorMessage: errorMessage,
      duration: duration,
    );

    _steps.add(step);
    _stepController.add(step);

    return step;
  }

  /// Start a step (marks as running)
  AgentStep startStep({
    required String agentName,
    required StepType action,
    required String target,
    Map<String, dynamic>? metadata,
  }) {
    return logStep(
      agentName: agentName,
      action: action,
      target: target,
      status: StepStatus.running,
      metadata: metadata,
    );
  }

  /// Complete a step (marks as success)
  AgentStep completeStep({
    required int stepId,
    Duration? duration,
    Map<String, dynamic>? metadata,
  }) {
    final index = _steps.indexWhere((s) => s.stepId == stepId);
    if (index == -1) {
      throw StateError('Step $stepId not found');
    }

    final updatedStep = _steps[index].copyWith(
      status: StepStatus.success,
      duration: duration,
      metadata: metadata != null
          ? {...?_steps[index].metadata, ...metadata}
          : _steps[index].metadata,
    );

    _steps[index] = updatedStep;
    _stepController.add(updatedStep);

    return updatedStep;
  }

  /// Fail a step (marks as failed)
  AgentStep failStep({
    required int stepId,
    required String errorMessage,
    Duration? duration,
  }) {
    final index = _steps.indexWhere((s) => s.stepId == stepId);
    if (index == -1) {
      throw StateError('Step $stepId not found');
    }

    final updatedStep = _steps[index].copyWith(
      status: StepStatus.failed,
      errorMessage: errorMessage,
      duration: duration,
    );

    _steps[index] = updatedStep;
    _stepController.add(updatedStep);

    return updatedStep;
  }

  /// Get steps for a specific agent
  List<AgentStep> getStepsForAgent(String agentName) {
    return _steps.where((s) => s.agentName == agentName).toList();
  }

  /// Get steps by action type
  List<AgentStep> getStepsByAction(StepType action) {
    return _steps.where((s) => s.action == action).toList();
  }

  /// Get failed steps
  List<AgentStep> get failedSteps {
    return _steps.where((s) => s.status == StepStatus.failed).toList();
  }

  /// Get running steps
  List<AgentStep> get runningSteps {
    return _steps.where((s) => s.status == StepStatus.running).toList();
  }

  /// Clear all steps (for new execution)
  void clear() {
    _steps.clear();
    _stepCounter = 0;
  }

  /// Export all steps to JSON
  List<Map<String, dynamic>> toJson() {
    return _steps.map((s) => s.toJson()).toList();
  }

  /// Dispose resources
  void dispose() {
    _stepController.close();
  }
}

/// Global step logger instance (singleton pattern)
class GlobalStepLogger {
  static final GlobalStepLogger _instance = GlobalStepLogger._internal();
  factory GlobalStepLogger() => _instance;
  GlobalStepLogger._internal();

  final StepLogger _logger = StepLogger();

  StepLogger get logger => _logger;

  /// Convenience methods
  Stream<AgentStep> get stepStream => _logger.stepStream;
  List<AgentStep> get allSteps => _logger.allSteps;

  AgentStep log({
    required String agentName,
    required StepType action,
    required String target,
    required StepStatus status,
    Map<String, dynamic>? metadata,
    String? errorMessage,
    Duration? duration,
  }) {
    return _logger.logStep(
      agentName: agentName,
      action: action,
      target: target,
      status: status,
      metadata: metadata,
      errorMessage: errorMessage,
      duration: duration,
    );
  }
}
