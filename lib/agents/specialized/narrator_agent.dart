import 'dart:async';
import '../core/agent_base.dart';
import '../core/step_types.dart';
import '../core/step_schema.dart';
import '../core/step_logger.dart';

/// Narrator Agent (The Internal Voice) 🗣️
///
/// Listens to the system's StepStream and generates real-time commentary.
/// It creates the "Illusion of Mind" by explaining what the system is doing.
class NarratorAgent extends AgentBase {
  StreamSubscription<AgentStep>? _subscription;

  /// Callback for broadcasting narration
  final void Function(String narration)? onNarrate;

  NarratorAgent({this.onNarrate, super.logger}) : super(name: 'Narrator');

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

    if (step.action == StepType.decide && step.status == StepStatus.running) {
      narration = 'Formulating a plan for: ${step.target}';
    } else if (step.action == StepType.error) {
      narration =
          'Encountered an obstacle. ${step.errorMessage ?? 'Check logs.'}';
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

  @override
  Future<R> onRun<R>(dynamic input) async {
    // Narrator usually runs passively, but can be forced to summarize
    return 'Watching and narrating...' as R;
  }
}
