import '../core/agent_base.dart';
import '../core/step_types.dart';
import '../core/step_schema.dart';
import '../core/step_logger.dart';
import 'organs/speech_organ.dart';
import 'social/external_interface.dart';

/// Social Agent 🤝
///
/// The "Face" of the system. Uses the SpeechOrgan to communicate
/// with the outside world (User, Chat, Other Agents) via multiple interfaces.
class SocialAgent extends AgentBase {
  final SpeechOrgan speech = SpeechOrgan();
  final List<ExternalInterface> interfaces = [];

  SocialAgent({StepLogger? logger})
      : super(name: 'SocialAgent', logger: logger);

  void addInterface(ExternalInterface interface) {
    interfaces.add(interface);
    interface.connect().catchError((e) {
      logStatus(StepType.error, 'Failed to connect ${interface.name}: $e',
          StepStatus.success);
    });
  }

  @override
  Future<R> onRun<R>(dynamic input) async {
    // Input might be raw data needing communication
    return await execute<R>(
      action: StepType.analyze, // analyze -> communicate
      target: 'Social Broadcast',
      task: () async {
        logStatus(
            StepType.modify, 'Formulating response...', StepStatus.running);

        // 1. Humanize the content via Broca's Area
        final message = await speech.run<String>(input);

        // 2. Broadcast to all interfaces
        int sentCount = 0;
        for (final interface in interfaces) {
          try {
            await interface.send(message);
            sentCount++;
          } catch (e) {
            print('Error sending to ${interface.name}: $e');
          }
        }

        logStatus(StepType.complete, 'Said: "$message" ($sentCount channels)',
            StepStatus.success);

        return message as R;
      },
    );
  }
}
