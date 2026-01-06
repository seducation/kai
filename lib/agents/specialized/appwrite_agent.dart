import '../core/agent_base.dart';
import '../core/step_types.dart';
import '../core/step_schema.dart';

/// Agent responsible for executing "Appwrite-style" functions.
/// This allows for serverless logic to be integrated into the orchestration graph.
class AppwriteFunctionAgent extends AgentBase {
  AppwriteFunctionAgent({super.logger}) : super(name: 'AppwriteFunction');

  @override
  Future<R> onRun<R>(dynamic input) async {
    return await execute<R>(
      action: StepType.modify,
      target: 'executing function: $input',
      task: () async {
        // Simulate executing a serverless function
        // In a real app, this would call Appwrite Functions SDK
        final functionId = input.toString();

        logger.logStep(
          agentName: name,
          action: StepType.analyze,
          target: 'Function context: $functionId',
          status: StepStatus.running,
        );

        await Future.delayed(const Duration(seconds: 2));

        final result = {
          'status': 'success',
          'functionId': functionId,
          'output':
              'Simulated output from Appwrite function execution for: $functionId',
          'timestamp': DateTime.now().toIso8601String(),
        };

        return result as R;
      },
    );
  }
}
