/// The Persona Gateway (Illusion of Identity) 🎭
///
/// Ensures all system outputs follow a consistent, calm, and professional
/// JARVIS-like tone. It strips agent jargon and enforces brevity.
class PersonaGateway {
  static const String identity = 'JARVIS';

  /// Process a message to enforce persona
  String process(String message, {bool isEmergency = false}) {
    if (message.isEmpty) return message;

    String processed = message.trim();

    // 1. Remove common AI "Disclaimer" patterns
    processed = _removeAIPrefixes(processed);

    // 2. Enforce Brevity
    processed = _enforceBrevity(processed, isEmergency);

    // 3. Personality Nuances (The "Illusion")
    processed = _applyTone(processed, isEmergency);

    return processed;
  }

  String _removeAIPrefixes(String input) {
    final patterns = [
      RegExp(r'^as an (ai|artificial intelligence|large language model).*?,',
          caseInsensitive: true),
      RegExp(r'^i am an ai.*?\.', caseInsensitive: true),
      RegExp(r'^certainly! ', caseInsensitive: true),
      RegExp(r'^here is.*?:', caseInsensitive: true),
      RegExp(r'^i understand.*?\.', caseInsensitive: true),
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
        return input.substring(0, 97) + '...';
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
