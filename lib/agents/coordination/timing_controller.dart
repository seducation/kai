import '../rules/rule_definitions.dart';

/// Timing Controller (Pacing Layer) ⏱️
///
/// Implements intentional delays to make the system feel "thoughtful".
/// Strategic timing increases user trust and perceived intelligence.
class TimingController {
  /// Calculate and wait for a considered delay based on priority
  Future<void> pace(int priority) async {
    int delayMs = 0;

    // The scale of "Considering..."
    if (priority >= PriorityLevel.reflex) {
      delayMs = 0; // Reflexes must be instant
    } else if (priority >= PriorityLevel.emergency) {
      delayMs = 50; // Emergencies should feel snappy but verified
    } else if (priority >= PriorityLevel.high) {
      delayMs = 300; // High priority: focused but fast
    } else if (priority >= PriorityLevel.normal) {
      delayMs = 700; // Normal: "Thinking about it..."
    } else {
      delayMs = 1500; // Low: Background/Leisurely
    }

    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }
}
