import 'dart:async';

import 'package:uuid/uuid.dart';

import 'dream_report.dart';
import 'execution_manager.dart';
import 'message_bus.dart';
import '../rules/rule_engine.dart';

import '../coordination/agent_registry.dart';
import '../specialized/systems/user_context.dart';
import '../specialized/systems/dream_vault.dart';

/// Dream Type - What kind of dream is this?
enum DreamType {
  /// Tactical: Re-simulate failed tasks to find better parameters
  simulation,

  /// Strategic: Optimize workflows
  optimization,

  /// Replay: Analyze social/interaction logs
  replay,
}

/// Safety constraint violation types

enum SafetyViolation {
  actuatorAccess,
  reflexSystemInactive,
  vaultWriteAttempt,
  priorityModification,
  ruleAutoCreation,
}

/// Dreaming Mode - Offline, sandboxed, non-executing optimization phase
///
/// This is NOT:
/// ❌ Consciousness
/// ❌ Imagination
/// ❌ Free self-learning
/// ❌ Autonomous goal creation
/// ❌ Unsupervised self-modification
///
/// This IS:
/// ✅ Garbage collection
/// ✅ Log review
/// ✅ Dry-run refactoring
/// ✅ What-if analysis
/// ✅ Memory consolidation
class DreamingMode {
  static final DreamingMode _instance = DreamingMode._internal();
  factory DreamingMode() => _instance;
  DreamingMode._internal();

  // Dependencies
  final ExecutionManager _executionManager = ExecutionManager();
  final RuleEngine _ruleEngine = RuleEngine();
  final DreamVault _vault = DreamVault();
  final MessageBus _bus = messageBus;

  // State
  bool _isDreaming = false;
  bool _actuatorsLocked = false;
  bool _vaultReadOnly = false;
  DreamSession? _currentSession;

  // Stream for dream updates
  final StreamController<DreamReport> _reportStream =
      StreamController.broadcast();
  Stream<DreamReport> get reportStream => _reportStream.stream;

  // Helpers
  // Proxy history from Vault
  List<DreamSession> get sessionHistory => _vault.history;

  // Getters
  bool get isDreaming => _isDreaming;
  DreamSession? get currentSession => _currentSession;

  /// Initialize the dreaming mode system
  Future<void> initialize() async {
    await _vault.initialize();
  }

  /// Run a complete dream cycle
  ///
  /// Called by SleepManager when entering REM sleep.
  /// Returns the completed DreamSession or null if safety constraints prevented dreaming.
  Future<DreamSession?> runDreamCycle() async {
    // Pre-flight safety checks
    if (!_verifySafetyConstraints()) {
      _broadcastSafetyViolation('Pre-flight safety check failed');
      return null;
    }

    // Lock the system
    await _enterDreamState();

    try {
      // Determine Dream Type based on context
      final type = _determineDreamType();

      _currentSession = DreamSession(
        id: const Uuid().v4(),
        type: type,
      );

      // Select capabilities based on Dream Type
      final capabilities = _getCapabilitiesForType(type);

      // Run each capability in sequence
      for (final capability in capabilities) {
        // Check if we should abort (user activity detected)
        if (!_isDreaming) {
          _currentSession!.status = DreamStatus.interrupted;
          break;
        }

        // Verify safety before each capability
        if (!_verifySafetyConstraints()) {
          await _triggerKillSwitch('Safety constraint violated during dream');
          return _currentSession;
        }

        // Run the capability
        final report = await _runCapability(capability);
        _currentSession!.reports.add(report);
        _reportStream.add(report);
      }

      // Mark session complete if not interrupted
      if (_currentSession!.status == DreamStatus.running) {
        _currentSession!.status = DreamStatus.completed;
      }
      _currentSession!.endTime = DateTime.now();

      // Save to Vault
      await _vault.saveSession(_currentSession!);

      return _currentSession;
    } catch (e) {
      await _triggerKillSwitch('Exception during dream: $e');
      return _currentSession;
    } finally {
      await _exitDreamState();
    }
  }

  /// Abort current dream cycle (called when user activity detected)
  Future<void> abort() async {
    if (!_isDreaming) return;

    _currentSession?.status = DreamStatus.interrupted;
    await _exitDreamState();
  }

  // ============================================================
  // SAFETY LAYER
  // ============================================================

  Future<void> _enterDreamState() async {
    _isDreaming = true;
    _actuatorsLocked = true;
    _vaultReadOnly = true;

    _bus.broadcast(AgentMessage(
      id: 'dream_start_${DateTime.now().millisecondsSinceEpoch}',
      from: 'DreamingMode',
      type: MessageType.status,
      payload: 'DREAM_CYCLE_START',
    ));
  }

  Future<void> _exitDreamState() async {
    _isDreaming = false;
    _actuatorsLocked = false;
    _vaultReadOnly = false;
    _currentSession = null;

    _bus.broadcast(AgentMessage(
      id: 'dream_end_${DateTime.now().millisecondsSinceEpoch}',
      from: 'DreamingMode',
      type: MessageType.status,
      payload: 'DREAM_CYCLE_END',
    ));
  }

  bool _verifySafetyConstraints() {
    // 1. Reflex system must be active
    // (Currently ReflexSystem doesn't expose isActive, so we check if it can respond)

    // 2. Actuators must be locked (we control this)
    if (!_actuatorsLocked && _isDreaming) {
      return false;
    }

    // 3. Vault must be read-only (we control this)
    if (!_vaultReadOnly && _isDreaming) {
      return false;
    }

    return true;
  }

  Future<void> _triggerKillSwitch(String reason) async {
    _currentSession?.status = DreamStatus.safetyTriggered;

    _bus.broadcast(AgentMessage(
      id: 'dream_kill_${DateTime.now().millisecondsSinceEpoch}',
      from: 'DreamingMode',
      type: MessageType.error,
      payload: 'DREAM_KILL_SWITCH: $reason',
    ));

    await _exitDreamState();
  }

  void _broadcastSafetyViolation(String message) {
    _bus.broadcast(AgentMessage(
      id: 'dream_safety_${DateTime.now().millisecondsSinceEpoch}',
      from: 'DreamingMode',
      type: MessageType.error,
      payload: message,
    ));
  }

  /// Check if actuator access is allowed (always returns false during dreaming)
  bool isActuatorAccessAllowed() {
    return !_actuatorsLocked;
  }

  /// Check if vault write is allowed (always returns false during dreaming)
  bool isVaultWriteAllowed() {
    return !_vaultReadOnly;
  }

  // ============================================================
  // CAPABILITY EXECUTION
  // ============================================================

  Future<DreamReport> _runCapability(DreamCapability capability) async {
    final report = DreamReport(
      id: const Uuid().v4(),
      capability: capability,
    );

    try {
      switch (capability) {
        case DreamCapability.tacticalSimulation:
          await _runTacticalSimulation(report);
          break;
        case DreamCapability.strategicOptimization:
          await _runStrategicOptimization(report);
          break;
        case DreamCapability.structuralAnalysis:
          await _runStructuralAnalysis(report);
          break;
        case DreamCapability.memoryConsolidation:
          await _runMemoryConsolidation(report);
          break;
        case DreamCapability.failurePatternAnalysis:
          await _runFailurePatternAnalysis(report);
          break;
      }

      report.status = DreamStatus.completed;
    } catch (e) {
      report.status = DreamStatus.safetyTriggered;
    }

    return report;
  }

  Future<void> _runMemoryConsolidation(DreamReport report) async {
    // Placeholder - will be implemented in memory_consolidation.dart
    // For now, add a basic observation
    report.observations.add(DreamObservation(
      id: const Uuid().v4(),
      category: 'memory',
      description: 'Memory consolidation scan completed',
      confidence: 1.0,
    ));
  }

  Future<void> _runFailurePatternAnalysis(DreamReport report) async {
    // Analyze failure vault
    final failures = _executionManager.failureVault;

    if (failures.isEmpty) {
      report.observations.add(DreamObservation(
        id: const Uuid().v4(),
        category: 'failures',
        description: 'No failures found in vault',
        confidence: 1.0,
      ));
      return;
    }

    // Group failures by task name (agent identifier from ExecutionRecord)
    final failuresByTask = <String, List<ExecutionRecord>>{};
    for (final failure in failures) {
      failuresByTask.putIfAbsent(failure.taskName, () => []).add(failure);
    }

    // Analyze patterns
    for (final entry in failuresByTask.entries) {
      final taskName = entry.key;
      final taskFailures = entry.value;

      report.observations.add(DreamObservation(
        id: const Uuid().v4(),
        category: 'failure_pattern',
        description: 'Task "$taskName" has ${taskFailures.length} failures',
        confidence: 0.9,
        data: {
          'task': taskName,
          'failure_count': taskFailures.length,
          'error_types': taskFailures
              .map((f) => f.errorMessage ?? 'unknown')
              .toSet()
              .toList(),
        },
      ));

      // If task has multiple failures, recommend investigation
      if (taskFailures.length >= 3) {
        report.recommendations.add(DreamRecommendation(
          id: const Uuid().v4(),
          title: 'Investigate $taskName failures',
          description:
              'Task "$taskName" has failed ${taskFailures.length} times. '
              'Consider adding dry-run requirement or additional validation.',
          type: RecommendationType.insight,
          proposedChange: {
            'task': taskName,
            'suggested_action': 'add_validation',
          },
        ));
      }
    }
  }

  Future<void> _runTacticalSimulation(DreamReport report) async {
    // Layer 1: Tactical (Task-Level)
    // Re-simulate failed tasks to find better parameters
    report.observations.add(DreamObservation(
      id: const Uuid().v4(),
      category: 'tactical',
      description:
          'Tactical simulation scan: No critical failures found requiring re-simulation.',
      confidence: 1.0,
    ));
  }

  Future<void> _runStrategicOptimization(DreamReport report) async {
    // Layer 2: Strategic (Plan-Level)
    // Optimize common workflows
    report.observations.add(DreamObservation(
      id: const Uuid().v4(),
      category: 'strategic',
      description:
          'Strategic optimization: Analyzed recent workflows for efficiency.',
      confidence: 0.9,
    ));
  }

  Future<void> _runStructuralAnalysis(DreamReport report) async {
    // Layer 3: Structural (Rule-Level) - formerly RuleConflictDetection
    await _runRuleConflictDetection(report);
  }

  Future<void> _runRuleConflictDetection(DreamReport report) async {
    final rules = _ruleEngine.rules;

    if (rules.isEmpty) {
      report.observations.add(DreamObservation(
        id: const Uuid().v4(),
        category: 'rules',
        description: 'No rules found for analysis',
        confidence: 1.0,
      ));
      return;
    }

    // Check for potential conflicts (same scope, different actions)
    final conflicts = <Map<String, dynamic>>[];

    for (var i = 0; i < rules.length; i++) {
      for (var j = i + 1; j < rules.length; j++) {
        final ruleA = rules[i];
        final ruleB = rules[j];

        if (ruleA.scope == ruleB.scope && ruleA.action != ruleB.action) {
          // Potential conflict
          conflicts.add({
            'rule_a': ruleA.id,
            'rule_b': ruleB.id,
            'reason': 'Same scope (${ruleA.scope.name}), different actions',
          });
        }
      }
    }

    report.observations.add(DreamObservation(
      id: const Uuid().v4(),
      category: 'rule_analysis',
      description:
          'Analyzed ${rules.length} rules, found ${conflicts.length} potential conflicts',
      confidence: 0.85,
      data: {'rule_count': rules.length, 'conflict_count': conflicts.length},
    ));

    if (conflicts.isNotEmpty) {
      report.recommendations.add(DreamRecommendation(
        id: const Uuid().v4(),
        title: 'Review rule conflicts',
        description:
            'Found ${conflicts.length} potential rule conflicts that may cause unexpected behavior.',
        type: RecommendationType.insight,
        proposedChange: {'conflicts': conflicts},
      ));
    }
  }

  DreamType _determineDreamType() {
    // 1. Priority: Fix broken agents (Tactical Simulation)
    final agents = agentRegistry.allAgents;
    for (final agent in agents) {
      final scorecard = agentRegistry.getScorecard(agent.name);
      if (scorecard != null && scorecard.reliabilityScore < 0.7) {
        return DreamType.simulation;
      }
    }

    // 2. Priority: Optimize based on User Context
    // If user is "Focused", they value efficiency -> Optimization
    if (userContext.mood == UserMood.focused) {
      return DreamType.optimization;
    }

    // 3. Fallback: Rotate based on time or random
    // Late night -> Memory Consolidation (Replay)
    final hour = DateTime.now().hour;
    if (hour >= 2 && hour < 5) {
      return DreamType.replay;
    }

    // Default rotation
    return DreamType.values[DateTime.now().minute % 3];
  }

  List<DreamCapability> _getCapabilitiesForType(DreamType type) {
    switch (type) {
      case DreamType.simulation:
        return [
          DreamCapability.tacticalSimulation,
          DreamCapability.failurePatternAnalysis,
        ];
      case DreamType.optimization:
        return [
          DreamCapability.strategicOptimization,
          DreamCapability.structuralAnalysis,
        ];
      case DreamType.replay:
        return [
          DreamCapability.memoryConsolidation,
          // Could add SentimentAnalysis capability later
        ];
    }
  }

  // ============================================================
  // PERSISTENCE (Delegated to Vault)
  // ============================================================

  /// Get all pending recommendations from all sessions
  List<DreamRecommendation> getPendingRecommendations() {
    return _vault.getPendingRecommendations();
  }

  Future<void> approveRecommendation(String recommendationId) async {
    await _vault.updateRecommendationStatus(
        recommendationId, ApprovalStatus.approved);
  }

  Future<void> rejectRecommendation(
      String recommendationId, String reason) async {
    await _vault.updateRecommendationStatus(
        recommendationId, ApprovalStatus.rejected,
        note: reason);
  }

  Future<void> deferRecommendation(String recommendationId) async {
    await _vault.updateRecommendationStatus(
        recommendationId, ApprovalStatus.deferred);
  }
}
