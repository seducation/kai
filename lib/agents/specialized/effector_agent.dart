import '../core/agent_base.dart';
import '../core/step_types.dart';
import '../core/step_schema.dart';

import '../coordination/motor_system.dart';
import '../coordination/agent_capability.dart';

/// The Effector Agent 🦾
///
/// A specialized agent that "acts" upon the world.
/// It uses the MotorSystem to perform physical or cloud-based tasks.
class EffectorAgent extends AgentBase {
  final MotorSystem motor = MotorSystem();

  EffectorAgent({super.logger}) : super(name: 'Effector');

  @override
  Future<R> onRun<R>(dynamic input) async {
    // Input format: "actuatorName:payload" or just payload (default to cloud)
    String actuatorKey = 'cloud';
    dynamic payload = input;

    if (input is String && input.contains(':')) {
      final parts = input.split(':');
      actuatorKey = parts[0].trim();
      payload = parts.sublist(1).join(':').trim();
    }

    logStatus(
        StepType.analyze, 'Actuating $actuatorKey muscle', StepStatus.running);

    final result = await motor.execute(actuatorKey, payload);

    if (result.success) {
      logStatus(StepType.complete, 'Actuation successful: ${result.output}',
          StepStatus.success);
      return result.output as R;
    } else {
      logStatus(StepType.error, 'Actuation failed: ${result.error}',
          StepStatus.failed);
      throw Exception('Effector Failure: ${result.error}');
    }
  }

  List<AgentCapability> get capabilities => [
        const AgentCapability(
          id: 'cap_actuation',
          name: 'Actuation',
          category: CapabilityCategory.custom,
          proficiency: 0.9,
          keywords: [
            'actuate',
            'move',
            'execute',
            'cloud',
            'appwrite',
            'shell'
          ],
        ),
      ];
}
