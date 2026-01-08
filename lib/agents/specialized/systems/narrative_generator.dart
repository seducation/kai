import 'explainability_engine.dart';

/// Narrative Generator 🗣️
///
/// Converts raw data (DecisionTraces, Factors) into human-readable stories.
/// "Translating machine thought into human language."
class NarrativeGenerator {
  /// Generate a summary for a decision
  static String explainDecision(DecisionTrace trace) {
    final chain = WhyChain(trace);
    final primary = chain.primaryFactor;

    // 1. Basic Outcome
    final buffer = StringBuffer();
    if (trace.finalOutcome == 'Approved') {
      buffer.write('I decided to **${trace.intent}**');
    } else if (trace.finalOutcome == 'Blocked') {
      buffer.write('I could not **${trace.intent}**');
    } else {
      buffer.write('I considered **${trace.intent}**');
    }

    // 2. The "Because"
    if (primary != null) {
      if (primary.weight < 0) {
        // Blocked
        buffer.write(' because ${primary.reason.toLowerCase()}.');
      } else {
        // Supported
        buffer.write(' primarily because ${primary.reason.toLowerCase()}.');
      }
    } else {
      buffer.write('.');
    }

    // 3. Nuance (Other factors)
    if (trace.factors.length > 1) {
      final others = trace.factors.where((f) => f != primary).toList();
      if (others.isNotEmpty) {
        buffer.write(' I also considered ${others.length} other factors, ');
        buffer.write('such as ${_formatFactor(others.first)}.');
      }
    }

    return buffer.toString();
  }

  static String _formatFactor(DecisionFactor factor) {
    if (factor.source == 'RuleEngine') {
      return 'a safety rule';
    } else if (factor.source == 'PredictionEngine') {
      return 'the risk forecast';
    } else if (factor.source == 'UserContext') {
      return 'your current preference';
    }
    return factor.reason.toLowerCase();
  }

  /// Explain a list of decisions (e.g., "Why have you been idle?")
  static String summarizeActivity(List<DecisionTrace> traces) {
    if (traces.isEmpty) return "I haven't made any major decisions recently.";

    final blocked = traces.where((t) => t.finalOutcome == 'Blocked').length;
    final approved = traces.where((t) => t.finalOutcome == 'Approved').length;

    return "In the last ${traces.length} decisions, I took action $approved times and was blocked $blocked times using my safety protocols.";
  }
}
