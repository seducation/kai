import 'dart:async';
import 'package:uuid/uuid.dart';
import '../core/step_logger.dart';
import '../core/step_types.dart';
import '../core/step_schema.dart';
import 'message_bus.dart';

/// Mission status tracking
enum MissionStatus {
  /// Mission is being planned
  planning,

  /// Mission is actively running
  active,

  /// Mission is paused (awaiting user input or resource)
  paused,

  /// Mission is in monitoring mode (watching for issues)
  monitoring,

  /// Mission completed successfully
  completed,

  /// Mission was aborted (manually or by abort condition)
  aborted,

  /// Mission failed
  failed,
}

/// A long-running mission objective (hours/days)
///
/// JARVIS-level: "I am managing a mission, not just tasks."
///
/// Missions provide:
/// - Long-running objectives with explicit success criteria
/// - Abort conditions that stop execution
/// - Progress confidence tracking
/// - Constraint enforcement
class Mission {
  final String id;
  final String objective;
  final List<String> constraints;
  final List<String> successCriteria;
  final List<String> abortConditions;
  final DateTime created;
  final DateTime? estimatedCompletion;

  MissionStatus status;
  double confidencePercent;
  double progressPercent;
  List<String> completedCriteria;
  List<String> notes;
  DateTime? completedAt;
  String? abortReason;

  Mission({
    String? id,
    required this.objective,
    this.constraints = const [],
    this.successCriteria = const [],
    this.abortConditions = const [],
    this.estimatedCompletion,
    this.status = MissionStatus.planning,
    this.confidencePercent = 50.0,
    this.progressPercent = 0.0,
    this.notes = const [],
    DateTime? created,
  })  : id = id ?? const Uuid().v4(),
        created = created ?? DateTime.now(),
        completedCriteria = [];

  /// Check if mission is in a terminal state
  bool get isTerminal =>
      status == MissionStatus.completed ||
      status == MissionStatus.aborted ||
      status == MissionStatus.failed;

  /// Check if mission is actively running
  bool get isActive =>
      status == MissionStatus.active || status == MissionStatus.monitoring;

  /// Calculate progress based on completed criteria
  void updateProgress() {
    if (successCriteria.isEmpty) {
      progressPercent = 0.0;
      return;
    }
    progressPercent = (completedCriteria.length / successCriteria.length) * 100;
  }

  /// Mark a success criterion as completed
  void completeCriterion(String criterion) {
    if (!completedCriteria.contains(criterion) &&
        successCriteria.contains(criterion)) {
      completedCriteria.add(criterion);
      updateProgress();
    }
  }

  /// Check if all success criteria are met
  bool get isSuccessful =>
      successCriteria.isNotEmpty &&
      completedCriteria.length >= successCriteria.length;

  /// Add a mission note
  void addNote(String note) {
    notes = [...notes, '${DateTime.now().toIso8601String()}: $note'];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'objective': objective,
        'constraints': constraints,
        'successCriteria': successCriteria,
        'abortConditions': abortConditions,
        'status': status.index,
        'confidencePercent': confidencePercent,
        'progressPercent': progressPercent,
        'completedCriteria': completedCriteria,
        'notes': notes,
        'created': created.toIso8601String(),
        'estimatedCompletion': estimatedCompletion?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'abortReason': abortReason,
      };

  factory Mission.fromJson(Map<String, dynamic> json) {
    final mission = Mission(
      id: json['id'],
      objective: json['objective'],
      constraints: List<String>.from(json['constraints'] ?? []),
      successCriteria: List<String>.from(json['successCriteria'] ?? []),
      abortConditions: List<String>.from(json['abortConditions'] ?? []),
      status: MissionStatus.values[json['status'] ?? 0],
      confidencePercent: json['confidencePercent']?.toDouble() ?? 50.0,
      progressPercent: json['progressPercent']?.toDouble() ?? 0.0,
      notes: List<String>.from(json['notes'] ?? []),
      created: DateTime.parse(json['created']),
      estimatedCompletion: json['estimatedCompletion'] != null
          ? DateTime.parse(json['estimatedCompletion'])
          : null,
    );
    mission.completedCriteria =
        List<String>.from(json['completedCriteria'] ?? []);
    mission.completedAt = json['completedAt'] != null
        ? DateTime.parse(json['completedAt'])
        : null;
    mission.abortReason = json['abortReason'];
    return mission;
  }
}

/// Mission Controller 🎯
///
/// Manages long-running missions with explicit success criteria.
/// This is the "BIGGEST remaining gap" for JARVIS-level behavior.
///
/// Key capabilities:
/// - Track mission progress and confidence
/// - Enforce constraints on all task execution
/// - Check abort conditions continuously
/// - Provide mission context to all subsystems
class MissionController {
  static final MissionController _instance = MissionController._internal();
  factory MissionController() => _instance;
  MissionController._internal();

  final Map<String, Mission> _missions = {};
  final MessageBus _bus = messageBus;
  final GlobalStepLogger _logger = GlobalStepLogger();
  Timer? _monitorTimer;

  Mission? _activeMission;

  /// Get the currently active mission (if any)
  Mission? get activeMission => _activeMission;

  /// Get all missions
  List<Mission> get allMissions => _missions.values.toList();

  /// Get active and monitoring missions
  List<Mission> get runningMissions =>
      _missions.values.where((m) => m.isActive).toList();

  /// Start the mission monitor
  void start() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _monitorMissions(),
    );
  }

  /// Stop the mission monitor
  void stop() {
    _monitorTimer?.cancel();
  }

  /// Create and start a new mission
  Future<Mission> createMission(Mission mission) async {
    _missions[mission.id] = mission;
    mission.status = MissionStatus.active;
    _activeMission = mission;

    _logMissionEvent(
      'Mission created: ${mission.objective}',
      StepStatus.running,
    );

    // Broadcast mission start
    _bus.broadcast(AgentMessage(
      id: 'mission_start_${mission.id}',
      from: 'MissionController',
      type: MessageType.status,
      payload: 'MISSION_START:${mission.id}:${mission.objective}',
    ));

    return mission;
  }

  /// Update mission progress
  void updateProgress(
    String missionId, {
    double? progress,
    double? confidence,
    String? note,
    String? completedCriterion,
  }) {
    final mission = _missions[missionId];
    if (mission == null) return;

    if (progress != null) {
      mission.progressPercent = progress.clamp(0.0, 100.0);
    }

    if (confidence != null) {
      mission.confidencePercent = confidence.clamp(0.0, 100.0);
    }

    if (note != null) {
      mission.addNote(note);
    }

    if (completedCriterion != null) {
      mission.completeCriterion(completedCriterion);
    }

    // Check for automatic completion
    if (mission.isSuccessful && mission.status == MissionStatus.active) {
      completeMission(missionId);
    }
  }

  /// Check abort conditions for a mission
  Future<bool> checkAbortConditions(
    String missionId, {
    Map<String, dynamic>? context,
  }) async {
    final mission = _missions[missionId];
    if (mission == null || mission.isTerminal) return false;

    for (final condition in mission.abortConditions) {
      if (_evaluateAbortCondition(condition, context)) {
        mission.status = MissionStatus.aborted;
        mission.abortReason = condition;
        mission.completedAt = DateTime.now();

        _logMissionEvent(
          'Mission ABORTED: ${mission.objective} — $condition',
          StepStatus.failed,
        );

        _bus.broadcast(AgentMessage(
          id: 'mission_abort_${mission.id}',
          from: 'MissionController',
          type: MessageType.error,
          payload: 'MISSION_ABORT:${mission.id}:$condition',
        ));

        if (_activeMission?.id == missionId) {
          _activeMission = null;
        }

        return true;
      }
    }

    return false;
  }

  /// Complete a mission successfully
  void completeMission(String missionId) {
    final mission = _missions[missionId];
    if (mission == null || mission.isTerminal) return;

    mission.status = MissionStatus.completed;
    mission.progressPercent = 100.0;
    mission.completedAt = DateTime.now();

    _logMissionEvent(
      'Mission COMPLETED: ${mission.objective}',
      StepStatus.success,
    );

    _bus.broadcast(AgentMessage(
      id: 'mission_complete_${mission.id}',
      from: 'MissionController',
      type: MessageType.status,
      payload: 'MISSION_COMPLETE:${mission.id}',
    ));

    if (_activeMission?.id == missionId) {
      _activeMission = null;
    }
  }

  /// Pause a mission
  void pauseMission(String missionId) {
    final mission = _missions[missionId];
    if (mission == null || !mission.isActive) return;

    mission.status = MissionStatus.paused;
    mission.addNote('Mission paused');

    _logMissionEvent(
        'Mission PAUSED: ${mission.objective}', StepStatus.running);
  }

  /// Resume a paused mission
  void resumeMission(String missionId) {
    final mission = _missions[missionId];
    if (mission == null || mission.status != MissionStatus.paused) return;

    mission.status = MissionStatus.active;
    mission.addNote('Mission resumed');

    _activeMission = mission;
    _logMissionEvent(
      'Mission RESUMED: ${mission.objective}',
      StepStatus.running,
    );
  }

  /// Abort a mission manually
  void abortMission(String missionId, String reason) {
    final mission = _missions[missionId];
    if (mission == null || mission.isTerminal) return;

    mission.status = MissionStatus.aborted;
    mission.abortReason = reason;
    mission.completedAt = DateTime.now();

    _logMissionEvent(
      'Mission ABORTED (manual): ${mission.objective} — $reason',
      StepStatus.failed,
    );

    if (_activeMission?.id == missionId) {
      _activeMission = null;
    }
  }

  /// Check if an action violates mission constraints
  bool checkConstraints(String action) {
    if (_activeMission == null) return true; // No constraints

    for (final constraint in _activeMission!.constraints) {
      if (_violatesConstraint(action, constraint)) {
        _logMissionEvent(
          'Action blocked by mission constraint: $constraint',
          StepStatus.failed,
        );
        return false;
      }
    }

    return true;
  }

  /// Get mission context for other systems
  Map<String, dynamic>? getMissionContext() {
    if (_activeMission == null) return null;

    return {
      'missionId': _activeMission!.id,
      'objective': _activeMission!.objective,
      'constraints': _activeMission!.constraints,
      'progress': _activeMission!.progressPercent,
      'confidence': _activeMission!.confidencePercent,
    };
  }

  // ============================================================
  // INTERNAL
  // ============================================================

  void _monitorMissions() {
    for (final mission in runningMissions) {
      checkAbortConditions(mission.id);
    }
  }

  bool _evaluateAbortCondition(
    String condition,
    Map<String, dynamic>? context,
  ) {
    // Simple condition evaluation
    // Format: "error rate > 5%", "timeout > 1h", etc.
    final lowerCondition = condition.toLowerCase();

    if (context == null) return false;

    // Check error rate
    if (lowerCondition.contains('error rate')) {
      final errorRate = context['errorRate'] as double?;
      final threshold = _extractThreshold(condition);
      if (errorRate != null && threshold != null && errorRate > threshold) {
        return true;
      }
    }

    // Check timeout
    if (lowerCondition.contains('timeout')) {
      final elapsed = context['elapsedMinutes'] as int?;
      final threshold = _extractThreshold(condition);
      if (elapsed != null && threshold != null && elapsed > threshold) {
        return true;
      }
    }

    // Check explicit flags
    if (context['abort'] == true) {
      return true;
    }

    return false;
  }

  double? _extractThreshold(String condition) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(condition);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  bool _violatesConstraint(String action, String constraint) {
    final lowerAction = action.toLowerCase();
    final lowerConstraint = constraint.toLowerCase();

    // Simple keyword matching for now
    if (lowerConstraint.contains('no downtime')) {
      return lowerAction.contains('restart') ||
          lowerAction.contains('shutdown');
    }

    if (lowerConstraint.contains('human approval')) {
      // This should trigger escalation, not blocking
      return false;
    }

    if (lowerConstraint.contains('read-only')) {
      return lowerAction.contains('write') ||
          lowerAction.contains('delete') ||
          lowerAction.contains('modify');
    }

    return false;
  }

  void _logMissionEvent(String message, StepStatus status) {
    _logger.log(
      agentName: 'MissionController',
      action: StepType.decide,
      target: message,
      status: status,
    );
  }
}

/// Global mission controller instance
final missionController = MissionController();
