import '../core/step_schema.dart';
import '../core/step_types.dart';
import '../specialized/systems/tone_modulator.dart';
import '../specialized/systems/user_context.dart';
import '../rules/rule_definitions.dart';
import 'speech_gate.dart';

/// Converts step logs to human-readable text.
/// The narrator ONLY rephrases logged actions - it NEVER invents steps.
class NarratorService {
  /// Convert a single step to human-readable text
  String narrate(AgentStep step) {
    // Neural Wiring: Get current tone from system state
    // (Simplified: Narrator is passive, would usually get tone from service)
    final tone = ToneModulator().determineTone(
      priorityLevel: 40, // Assume normal priority for log readout
      reliabilityScore: 1.0,
      isDreaming: false,
      context: UserContext(),
    );

    final status = step.status.icon;
    final action = _actionToVerb(step.action, step.status);
    final target = _formatTarget(step.target);

    final narration = '$status Step ${step.stepId}: $action $target';

    // Apply tone styling
    return ToneModulator().modulate(narration, tone);
  }

  /// Narrate a step with more detail
  String narrateDetailed(AgentStep step) {
    final status = step.status.displayName;
    final action = step.action.displayName;
    final duration =
        step.duration != null ? ' (${_formatDuration(step.duration!)})' : '';
    final error =
        step.errorMessage != null ? '\n   Error: ${step.errorMessage}' : '';

    return '${step.status.icon} Step ${step.stepId}: ${step.agentName} $action "${step.target}" — $status$duration$error';
  }

  /// Sends a message to the "Speech Organ" if the SpeechGate allows it.
  Future<void> speak(String message, SpeechIntent intent,
      {int priority = PriorityLevel.normal}) async {
    final allowed = SpeechGate().evaluateIntent(intent, priority: priority);

    if (allowed) {
      // In a real implementation, this would call a TTS service
      // or emit an event that the UI catches to play audio.
      print('🔊 SPEECH: $message');
    } else {
      // print('🔇 SPEECH BLOCKED: $message');
    }
  }

  /// Narrate all steps
  String narrateAll(List<AgentStep> steps) {
    if (steps.isEmpty) return 'No steps recorded.';

    return steps.map((s) => narrate(s)).join('\n');
  }

  /// Generate a summary of execution
  String summarize(List<AgentStep> steps) {
    if (steps.isEmpty) return 'No actions were performed.';

    final successful =
        steps.where((s) => s.status == StepStatus.success).length;
    final failed = steps.where((s) => s.status == StepStatus.failed).length;
    final running = steps.where((s) => s.status == StepStatus.running).length;

    final totalDuration = steps
        .where((s) => s.duration != null)
        .fold<Duration>(Duration.zero, (sum, s) => sum + s.duration!);

    final parts = <String>[];
    parts.add('$successful completed');
    if (failed > 0) parts.add('$failed failed');
    if (running > 0) parts.add('$running in progress');

    return '${steps.length} steps: ${parts.join(', ')} (${_formatDuration(totalDuration)})';
  }

  /// Get agent activity breakdown
  Map<String, List<AgentStep>> groupByAgent(List<AgentStep> steps) {
    final groups = <String, List<AgentStep>>{};
    for (final step in steps) {
      groups.putIfAbsent(step.agentName, () => []).add(step);
    }
    return groups;
  }

  /// Generate timeline view
  String timeline(List<AgentStep> steps) {
    if (steps.isEmpty) return 'No activity.';

    final buffer = StringBuffer();
    String? currentAgent;

    for (final step in steps) {
      if (step.agentName != currentAgent) {
        currentAgent = step.agentName;
        buffer.writeln('\n📋 ${step.agentName}');
      }
      buffer.writeln('  ${narrate(step)}');
    }

    return buffer.toString().trim();
  }

  /// Convert action type to past tense verb
  String _actionToVerb(StepType action, StepStatus status) {
    final isPast = status == StepStatus.success || status == StepStatus.failed;

    switch (action) {
      case StepType.check:
        return isPast ? 'Checked' : 'Checking';
      case StepType.decide:
        return isPast ? 'Decided' : 'Deciding';
      case StepType.fetch:
        return isPast ? 'Fetched' : 'Fetching';
      case StepType.download:
        return isPast ? 'Downloaded' : 'Downloading';
      case StepType.extract:
        return isPast ? 'Extracted' : 'Extracting';
      case StepType.transcribe:
        return isPast ? 'Transcribed' : 'Transcribing';
      case StepType.analyze:
        return isPast ? 'Analyzed' : 'Analyzing';
      case StepType.modify:
        return isPast ? 'Modified' : 'Modifying';
      case StepType.validate:
        return isPast ? 'Validated' : 'Validating';
      case StepType.store:
        return isPast ? 'Stored' : 'Storing';
      case StepType.complete:
        return 'Completed';
      case StepType.error:
        return 'Error in';
      case StepType.waiting:
        return 'Waiting for';
      case StepType.cancelled:
        return 'Cancelled';
    }
  }

  /// Format target for display (truncate if too long)
  String _formatTarget(String target) {
    if (target.length > 50) {
      return '${target.substring(0, 47)}...';
    }
    return target;
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds < 1000) {
      return '${duration.inMilliseconds}ms';
    } else if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else {
      final mins = duration.inMinutes;
      final secs = duration.inSeconds % 60;
      return '${mins}m ${secs}s';
    }
  }
}

/// Global narrator instance
final narrator = NarratorService();
