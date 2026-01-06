import 'dart:async';

/// Interface for external "Muscles"
abstract class Actuator {
  String get name;
  Future<ActuatorResult> act(dynamic input);
}

class ActuatorResult {
  final bool success;
  final dynamic output;
  final String? error;

  ActuatorResult({required this.success, this.output, this.error});
}

/// Cloud Muscle: Deploys and triggers logic in Appwrite Functions
class AppwriteActuator implements Actuator {
  @override
  String get name => 'AppwriteCloud';

  @override
  Future<ActuatorResult> act(dynamic input) async {
    // print('🦾 AppwriteActuator: Deploying/Executing Cloud Function for $input');

    // Simulation of Appwrite Function execution
    await Future.delayed(const Duration(seconds: 2));

    // In a real implementation, we'd use the Appwrite SDK:
    // final functions = Functions(client);
    // final execution = await functions.createExecution(functionId: '...', body: input);

    return ActuatorResult(
        success: true,
        output: 'Function execution completed on Appwrite Cloud.');
  }
}

/// Local Muscle: Executes shell commands (for robotics or machinery)
class ShellActuator implements Actuator {
  @override
  String get name => 'LocalShell';

  @override
  Future<ActuatorResult> act(dynamic input) async {
    if (input is! String) {
      return ActuatorResult(
          success: false, error: 'Shell input must be a String command');
    }

    // print('🦾 ShellActuator: Executing command "$input"');

    try {
      // In a real environment, this would be highly restricted/sandboxed
      // For this biological resilience simulation, we'll simulate the "Motor" movement
      if (input.contains('move')) {
        return ActuatorResult(
            success: true, output: 'Servo movement executed.');
      }

      return ActuatorResult(
          success: true, output: 'Shell command executed successfully.');
    } catch (e) {
      return ActuatorResult(success: false, error: e.toString());
    }
  }
}
