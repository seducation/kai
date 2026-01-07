import 'self_limitation_detector.dart';

/// The Persona Gateway (Illusion of Identity) 🎭
///
/// Ensures all system outputs follow a consistent, calm, and professional
/// JARVIS-like tone. It strips agent jargon and enforces brevity.
///
/// Enhanced with Self-Limitation Awareness: JARVIS knows when to admit uncertainty.
class PersonaGateway {
  static const String identity = 'JARVIS';

  final SelfLimitationDetector _limitationDetector = SelfLimitationDetector();

  /// Process a message to enforce persona
  ///
  /// [confidence] - Optional confidence score (0.0 to 1.0)
  /// [action] - Optional action being performed (for limitation detection)
  String process(
    String message, {
    bool isEmergency = false,
    double? confidence,
    String? action,
  }) {
    if (message.isEmpty) return message;

    String processed = message.trim();

    // 1. Remove common AI "Disclaimer" patterns
    processed = _removeAIPrefixes(processed);

    // 2. Enforce Brevity
    processed = _enforceBrevity(processed, isEmergency);

    // 3. Personality Nuances (The "Illusion")
    processed = _applyTone(processed, isEmergency);

    // 4. Add Self-Limitation Warnings (NEW - JARVIS-level honesty)
    if (action != null || confidence != null) {
      final warning = _checkLimitations(
        action: action ?? '',
        confidence: confidence,
      );
      if (warning != null) {
        processed = '$warning\n\n$processed';
      }
    }

    return processed;
  }

  /// Check for limitations and generate warning if needed
  String? _checkLimitations({
    required String action,
    double? confidence,
  }) {
    final type = _limitationDetector.detectLimitation(
      action: action,
      confidence: confidence,
    );

    if (type == LimitationType.none) return null;

    return _limitationDetector.generateWarning(
      type: type,
      confidence: confidence,
      action: action,
    );
  }

  /// Get a JARVIS-style humble statement for current limitation
  String getHumbleStatement({
    required String action,
    double? confidence,
  }) {
    final type = _limitationDetector.detectLimitation(
      action: action,
      confidence: confidence,
    );
    return _limitationDetector.generateHumbleStatement(type);
  }

  /// Check if action requires human approval
  bool requiresApproval({
    required String action,
    double? confidence,
  }) {
    return _limitationDetector.requiresHumanApproval(
      action: action,
      confidence: confidence,
    );
  }

  String _removeAIPrefixes(String input) {
    final patterns = [
      RegExp(r'^as an (ai|artificial intelligence|large language model).*?,',
          caseSensitive: false),
      RegExp(r'^i am an ai.*?\.', caseSensitive: false),
      RegExp(r'^certainly! ', caseSensitive: false),
      RegExp(r'^here is.*?:', caseSensitive: false),
      RegExp(r'^i understand.*?\.', caseSensitive: false),
    ];

    String result = input;
    for (final pattern in patterns) {
      result = result.replaceFirst(pattern, '').trim();
    }

    // Capitalize first letter if we stripped it
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }

    return result;
  }

  String _enforceBrevity(String input, bool isEmergency) {
    if (isEmergency) {
      // Emergency: Strip all fluff
      if (input.length > 100) {
        return '${input.substring(0, 97)}...';
      }
    }
    return input;
  }

  String _applyTone(String input, bool isEmergency) {
    if (isEmergency) return '⚠️ $input';

    // Add subtle JARVIS-style markers
    if (input.toLowerCase().startsWith('yes')) {
      return 'Certainly. ${input.substring(3).trim()}';
    }

    return input;
  }
}
