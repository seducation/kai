import 'step_types.dart';

/// Status of a step execution
enum StepStatus {
  /// Step is currently running
  running,

  /// Step completed successfully
  success,

  /// Step failed with error
  failed,

  /// Step was skipped
  skipped,

  /// Step is pending/queued
  pending,
}

extension StepStatusExtension on StepStatus {
  String get displayName {
    switch (this) {
      case StepStatus.running:
        return 'Running';
      case StepStatus.success:
        return 'Success';
      case StepStatus.failed:
        return 'Failed';
      case StepStatus.skipped:
        return 'Skipped';
      case StepStatus.pending:
        return 'Pending';
    }
  }

  String get icon {
    switch (this) {
      case StepStatus.running:
        return '→';
      case StepStatus.success:
        return '✓';
      case StepStatus.failed:
        return '✗';
      case StepStatus.skipped:
        return '○';
      case StepStatus.pending:
        return '◌';
    }
  }
}

/// Single source of truth for agent actions.
/// This schema represents a REAL action that occurred.
/// Logs are written by code, not AI.
class AgentStep {
  /// Unique step ID within the execution
  final int stepId;

  /// Name of the agent that performed this action
  final String agentName;

  /// Type of action performed
  final StepType action;

  /// Target of the action (URL, file path, etc.)
  final String target;

  /// Current status of the step
  final StepStatus status;

  /// When this step was executed
  final DateTime timestamp;

  /// Optional additional metadata
  final Map<String, dynamic>? metadata;

  /// Optional error message if status is failed
  final String? errorMessage;

  /// Duration of the step execution (null if still running)
  final Duration? duration;

  const AgentStep({
    required this.stepId,
    required this.agentName,
    required this.action,
    required this.target,
    required this.status,
    required this.timestamp,
    this.metadata,
    this.errorMessage,
    this.duration,
  });

  /// Create a copy with updated fields
  AgentStep copyWith({
    int? stepId,
    String? agentName,
    StepType? action,
    String? target,
    StepStatus? status,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    String? errorMessage,
    Duration? duration,
  }) {
    return AgentStep(
      stepId: stepId ?? this.stepId,
      agentName: agentName ?? this.agentName,
      action: action ?? this.action,
      target: target ?? this.target,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      errorMessage: errorMessage ?? this.errorMessage,
      duration: duration ?? this.duration,
    );
  }

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() {
    return {
      'step_id': stepId,
      'agent': agentName,
      'action': action.name,
      'target': target,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
      if (errorMessage != null) 'error': errorMessage,
      if (duration != null) 'duration_ms': duration!.inMilliseconds,
    };
  }

  /// Create from JSON
  factory AgentStep.fromJson(Map<String, dynamic> json) {
    return AgentStep(
      stepId: json['step_id'] as int,
      agentName: json['agent'] as String,
      action: StepType.values.byName(json['action'] as String),
      target: json['target'] as String,
      status: StepStatus.values.byName(json['status'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
      errorMessage: json['error'] as String?,
      duration: json['duration_ms'] != null
          ? Duration(milliseconds: json['duration_ms'] as int)
          : null,
    );
  }

  @override
  String toString() {
    return 'AgentStep(#$stepId ${action.name} -> $target [${status.name}])';
  }
}

/// Action plan schema for orchestrating multiple agents
class ActionPlan {
  /// Unique plan ID
  final String planId;

  /// Original user request
  final String userRequest;

  /// Ordered list of planned tasks
  final List<PlannedTask> tasks;

  /// When this plan was created
  final DateTime createdAt;

  const ActionPlan({
    required this.planId,
    required this.userRequest,
    required this.tasks,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'plan_id': planId,
      'user_request': userRequest,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// A single planned task within an action plan
class PlannedTask {
  /// Which agent should execute this
  final String agentName;

  /// What action type to perform
  final StepType action;

  /// Target of the action
  final String target;

  /// Tasks that must complete before this one
  final List<int> dependsOn;

  /// Optional configuration for the task
  final Map<String, dynamic>? config;

  const PlannedTask({
    required this.agentName,
    required this.action,
    required this.target,
    this.dependsOn = const [],
    this.config,
  });

  Map<String, dynamic> toJson() {
    return {
      'agent': agentName,
      'action': action.name,
      'target': target,
      'depends_on': dependsOn,
      if (config != null) 'config': config,
    };
  }
}
