import 'dart:async';
import '../core/agent_base.dart';
import '../core/step_types.dart';
import '../core/step_schema.dart';
import '../core/step_logger.dart';
import 'systems/self_limitation_detector.dart';

/// Narrator Agent (The Internal Voice) 🗣️
///
/// Listens to the system's StepStream and generates real-time commentary.
/// It creates the "Illusion of Mind" by explaining what the system is doing.
///
/// Enhanced with Self-Limitation Awareness: narrates uncertainty honestly.
class NarratorAgent extends AgentBase {
  StreamSubscription<AgentStep>? _subscription;
  final SelfLimitationDetector _limitationDetector = SelfLimitationDetector();

  /// Callback for broadcasting narration
  final void Function(String narration)? onNarrate;

  /// Callback for limitation warnings (separate channel for UI)
  final void Function(String warning, LimitationType type)? onLimitationWarning;

  NarratorAgent({
    this.onNarrate,
    this.onLimitationWarning,
    super.logger,
  }) : super(name: 'Narrator');

  void start() {
    _subscription = GlobalStepLogger().stepStream.listen(_onStep);
  }

  void stop() {
    _subscription?.cancel();
  }

  void _onStep(AgentStep step) {
    // Only narrate major events to avoid noise
    if (step.agentName == 'Narrator') return; // Don't narrate self

    String? narration;
    LimitationType? limitationType;

    // Check for confidence metadata (from Planner)
    final confidence = step.metadata?['confidence'] as double?;
    final action = step.metadata?['action'] as String? ?? step.target;

    // Detect limitations
    if (confidence != null || action.isNotEmpty) {
      limitationType = _limitationDetector.detectLimitation(
        action: action,
        confidence: confidence,
      );

      // Broadcast limitation warning separately
      if (limitationType != LimitationType.none &&
          onLimitationWarning != null) {
        final warning = _limitationDetector.generateWarning(
          type: limitationType,
          confidence: confidence,
          action: action,
        );
        if (warning != null) {
          onLimitationWarning!(warning, limitationType);
        }
      }
    }

    // Generate narration based on step type
    if (step.action == StepType.decide && step.status == StepStatus.running) {
      narration = _narrateDecision(step, confidence);
    } else if (step.action == StepType.error) {
      narration = _narrateError(step);
    } else if (step.action == StepType.fetch &&
        step.status == StepStatus.running) {
      narration = 'Retrieving external data...';
    } else if (step.action == StepType.modify &&
        step.status == StepStatus.running) {
      narration = 'Applying changes to target: ${step.target}';
    } else if (step.action == StepType.complete &&
        step.agentName == 'Controller') {
      narration = 'Task finalized.';
    }

    if (narration != null && onNarrate != null) {
      onNarrate!(narration);
    }
  }

  /// Generate narration for decision steps with confidence awareness
  String _narrateDecision(AgentStep step, double? confidence) {
    final base = 'Formulating a plan for: ${step.target}';

    if (confidence == null) return base;

    if (confidence >= 0.8) {
      return '$base (High confidence)';
    } else if (confidence >= 0.6) {
      return '$base (Moderate confidence)';
    } else {
      // Low confidence - use humble statement
      final humble = _limitationDetector.generateHumbleStatement(
        LimitationType.lowConfidence,
      );
      return '$base — $humble';
    }
  }

  /// Generate narration for error steps
  String _narrateError(AgentStep step) {
    final base = 'Encountered an obstacle.';
    final detail = step.errorMessage ?? 'Check logs.';

    // JARVIS admits mistakes gracefully
    return '$base $detail. Adjusting approach.';
  }

  @override
  Future<R> onRun<R>(dynamic input) async {
    // Narrator usually runs passively, but can be forced to summarize
    return 'Watching and narrating...' as R;
  }
}
