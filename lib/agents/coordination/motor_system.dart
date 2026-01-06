import 'dart:async';
import 'actuators.dart';

/// The Motor System 🦾
///
/// Coordinates external actions via Actuators.
/// Translates abstract "intent" into physical/external results.
class MotorSystem {
  static final MotorSystem _instance = MotorSystem._internal();
  factory MotorSystem() => _instance;
  MotorSystem._internal();

  final Map<String, Actuator> _actuators = {
    'cloud': AppwriteActuator(),
    'local': ShellActuator(),
  };

  /// Perform an action using a specific muscle group
  Future<ActuatorResult> execute(String actuatorKey, dynamic input) async {
    final actuator = _actuators[actuatorKey];
    if (actuator == null) {
      return ActuatorResult(
          success: false, error: 'Actuator "$actuatorKey" not found');
    }

    // print('🧠 MotorSystem: Coordinating ${actuator.name} contraction...');

    try {
      return await actuator.act(input);
    } catch (e) {
      return ActuatorResult(
          success: false, error: 'Muscle failure: ${e.toString()}');
    }
  }

  List<String> get availableActuators => _actuators.keys.toList();
}
