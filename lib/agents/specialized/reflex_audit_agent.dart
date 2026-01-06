import '../core/agent_base.dart';
import '../core/step_types.dart';
import '../core/step_schema.dart';
import '../core/step_logger.dart';

/// Reflex Audit Agent 🛡️🤖
///
/// A light-weight agent that acts as a "Safety Jury".
/// It decides if an agent should be quarantined based on failure context.
class ReflexAuditAgent extends AgentBase {
  ReflexAuditAgent({StepLogger? logger})
      : super(name: 'ReflexAudit', logger: logger);

  @override
  Future<R> onRun<R>(dynamic input) async {
    // Input is failure context: { 'agent': '...', 'errors': ['e1', 'e2'] }
    if (input is! Map<String, dynamic>) {
      throw ArgumentError('Audit expects Map input');
    }

    final agentName = input['agent'];
    final errors = input['errors'] as List<dynamic>;

    return await execute<R>(
      action: StepType.decide,
      target: 'Safety Audit for $agentName',
      task: () async {
        logStatus(StepType.examine, 'Auditing ${errors.length} recent failures',
            StepStatus.running);

        // Simple Heuristic AI (mocking a prompt-based decision for speed)
        // In full implementation, this would call an LLM with:
        // "Agent X failed 5 times with these errors: [...]. Is it corrupted?"

        bool shouldQuarantine = false;
        String reason = '';

        if (errors.length >= 5) {
          shouldQuarantine = true;
          reason = 'Rapid failure rate (>5 in window)';
        }

        // Detect looping patterns
        final firstError = errors.first.toString();
        if (errors.every((e) => e.toString() == firstError)) {
          shouldQuarantine = true;
          reason = 'Infinite loop detected (identical errors)';
        }

        if (shouldQuarantine) {
          logStatus(StepType.error, 'QUARANTINE VERDICT: $reason',
              StepStatus.success);
          return true as R; // YES, quarantine
        } else {
          logStatus(StepType.complete,
              'Verdict: Transient failure (Retry allowed)', StepStatus.success);
          return false as R; // NO, safe to retry
        }
      },
    );
  }
}
