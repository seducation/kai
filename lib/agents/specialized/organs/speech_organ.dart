import '../../core/step_types.dart';
import '../../coordination/organ_base.dart';
import '../systems/limbic_system.dart';

/// The Speech Organ (Broca's Area) 🗣️
///
/// Responsible for formatting raw data into "Human-like" communication.
/// It gives the AI a voice and personality.
class SpeechOrgan extends Organ {
  LimbicSystem? limbic;

  SpeechOrgan()
      : super(
          name: 'SpeechOrgan',
          tissues: [],
          tokenLimit: 10000,
        );

  @override
  Future<R> onRun<R>(dynamic input) async {
    if (input is! String) {
      throw ArgumentError('SpeechOrgan expects String input');
    }

    return await execute<R>(
      action: StepType.modify,
      target: 'Humanizing Output',
      task: () async {
        // Simple template-based "personality" for now.
        // In a real system, this would use a small LLM call.

        final humanized = _humanize(input);
        consumeMetabolite(humanized.length);
        return humanized as R;
      },
    );
  }

  String _humanize(String raw) {
    String prefix = '';

    // 1. Check Emotional State
    if (limbic != null) {
      final state = limbic!.state;
      // High Pleasure
      if (state.pleasure > 0.6) prefix += '✨ ';
      // Low Pleasure (Sadness/Anger)
      if (state.pleasure < -0.4) prefix += '🌧️ ';
      // High Arousal (Excitement)
      if (state.arousal > 0.6) prefix += '🚀 ';

      // Tone tagging
      // prefix += '[${state.label}] ';
    }

    if (raw.startsWith('VOLITION:')) {
      final thought = raw.replaceAll('VOLITION:', '').trim();
      return '$prefix🤖 *Self-Talk*: "$thought"';
    }

    if (raw.contains('error') || raw.contains('failed')) {
      if (limbic != null) limbic!.stimulate(-0.5, 0.8); // Negative stimulus
      return '$prefix⚠️ *Ouch*: It looks like something went wrong. Here\'s what happened: "$raw"';
    }

    if (raw.contains('success') || raw.contains('complete')) {
      if (limbic != null) limbic!.stimulate(0.3, 0.5); // Positive stimulus
      return '$prefix✅ *Done*: "$raw". Ready for the next challenge!';
    }

    return '$prefix💬 "$raw"';
  }
}
