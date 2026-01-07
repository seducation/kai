/// The Self-Limitation Detector 🛡️
///
/// Detects and communicates uncertainty/limitations honestly.
/// This is JARVIS-level behavior: intelligence includes knowing
/// when you DON'T know something.
///
/// Key Principle: Admitting limitations INCREASES perceived intelligence.
class SelfLimitationDetector {
  static const double CONFIDENCE_THRESHOLD = 0.6;
  static const double HIGH_RISK_THRESHOLD = 0.8;

  /// Keywords that indicate irreversible/destructive actions
  static const List<String> IRREVERSIBLE_ACTIONS = [
    'delete',
    'drop',
    'remove',
    'format',
    'truncate',
    'purge',
    'destroy',
    'wipe',
    'erase',
    'rm -rf',
  ];

  /// Keywords that indicate high-risk operations
  static const List<String> HIGH_RISK_KEYWORDS = [
    'production',
    'deploy',
    'migrate',
    'sudo',
    'admin',
    'root',
    'credentials',
    'password',
    'secret',
    'api_key',
  ];

  /// Check if confidence is too low for autonomous action
  bool isLowConfidence(double confidence) {
    return confidence < CONFIDENCE_THRESHOLD;
  }

  /// Check if action is high-risk
  bool isHighRisk(String action) {
    final lowerAction = action.toLowerCase();
    return HIGH_RISK_KEYWORDS.any((term) => lowerAction.contains(term));
  }

  /// Check if action cannot be safely reversed
  bool isIrreversible(String action) {
    final lowerAction = action.toLowerCase();
    return IRREVERSIBLE_ACTIONS.any((term) => lowerAction.contains(term));
  }

  /// Determine the limitation type for an action
  LimitationType detectLimitation({
    required String action,
    double? confidence,
    Map<String, dynamic>? context,
  }) {
    // Priority order: Irreversible > High Risk > Low Confidence

    if (isIrreversible(action)) {
      return LimitationType.irreversible;
    }

    if (isHighRisk(action)) {
      return LimitationType.highRisk;
    }

    if (confidence != null && isLowConfidence(confidence)) {
      return LimitationType.lowConfidence;
    }

    // Check for external dependencies
    if (context != null && context['requiresNetwork'] == true) {
      return LimitationType.externalDependency;
    }

    return LimitationType.none;
  }

  /// Generate appropriate warning message based on limitation
  String? generateWarning({
    required LimitationType type,
    double? confidence,
    String? action,
  }) {
    switch (type) {
      case LimitationType.irreversible:
        return '⚠️ This action cannot be safely reversed. '
            'Please confirm before proceeding.';

      case LimitationType.highRisk:
        return '⚠️ This is a high-risk operation. '
            'I recommend human verification before execution.';

      case LimitationType.lowConfidence:
        final pct = confidence != null
            ? '(${(confidence * 100).toStringAsFixed(0)}%)'
            : '';
        return '⚠️ This exceeds my current certainty $pct. '
            'I recommend human confirmation.';

      case LimitationType.externalDependency:
        return '⚠️ This action depends on external services. '
            'Results may vary based on network conditions.';

      case LimitationType.none:
        return null;
    }
  }

  /// JARVIS-like phrasing for honest limitations
  String generateHumbleStatement(LimitationType type) {
    switch (type) {
      case LimitationType.lowConfidence:
        return "I'm not entirely certain about this.";
      case LimitationType.irreversible:
        return "This requires your explicit authorization.";
      case LimitationType.highRisk:
        return "I recommend we proceed with caution.";
      case LimitationType.externalDependency:
        return "This involves factors outside my control.";
      case LimitationType.none:
        return "Proceeding with confidence.";
    }
  }

  /// Check if action requires explicit human approval
  bool requiresHumanApproval({
    required String action,
    double? confidence,
  }) {
    final type = detectLimitation(action: action, confidence: confidence);
    return type == LimitationType.irreversible ||
        type == LimitationType.highRisk ||
        (type == LimitationType.lowConfidence && (confidence ?? 1.0) < 0.4);
  }
}

/// Types of self-limitations the system can detect
enum LimitationType {
  /// Confidence is below threshold
  lowConfidence,

  /// Action cannot be reversed
  irreversible,

  /// Action is high-risk (production, credentials, etc.)
  highRisk,

  /// Action depends on external services
  externalDependency,

  /// No limitation detected
  none,
}
