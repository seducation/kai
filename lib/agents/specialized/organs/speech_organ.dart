import '../../core/step_types.dart';
import '../../coordination/organ_base.dart';

/// The Speech Organ (Broca's Area) 🗣️
///
/// Responsible for formatting raw data into "Human-like" communication.
/// It gives the AI a voice and personality.
class SpeechOrgan extends Organ {
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
    if (raw.startsWith('VOLITION:')) {
      final thought = raw.replaceAll('VOLITION:', '').trim();
      return '🤖 *Self-Talk*: "$thought"';
    }

    if (raw.contains('error') || raw.contains('failed')) {
      return '⚠️ *Ouch*: It looks like something went wrong. Here\'s what happened: "$raw"';
    }

    if (raw.contains('success') || raw.contains('complete')) {
      return '✅ *Done*: "$raw". Ready for the next challenge!';
    }

    return '💬 "$raw"';
  }
}
