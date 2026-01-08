import 'user_context.dart';
import 'circadian_tracker.dart';

/// Tone Modulator (Narrator Personality) 🗣️
///
/// Adapts the "voice" of the system based on context urgency and health.
/// Gives the system a "Cinematic JARVIS" feel by shifting tone dynamically.
class ToneModulator {
  static final ToneModulator _instance = ToneModulator._internal();
  factory ToneModulator() => _instance;
  ToneModulator._internal();

  /// Determine the appropriate tone based on system state and user context
  SystemTone determineTone({
    required int priorityLevel, // 0-100 (Normal=40, High=60, Critical=90)
    required double reliabilityScore, // 0.0 - 1.0 (from AgentScorecard)
    required bool isDreaming,
    UserContext? context,
  }) {
    final user = context ?? UserContext();
    final temporal = CircadianRhythmTracker().getTemporalContext();

    if (isDreaming) return SystemTone.subconscious;

    // Hyper-Personalized Overrides
    if (user.mood == UserMood.busy) return SystemTone.concise;
    if (user.mood == UserMood.frustrated) return SystemTone.empathetic;

    // Normalizing for "Efficiency" context (e.g. Monday Morning)
    if (temporal.contains('Monday') && temporal.contains('Morning')) {
      if (priorityLevel < 60) return SystemTone.concise;
    }

    // Critical Priority -> Urgent/Sharp
    if (priorityLevel >= 90) return SystemTone.urgent;

    // Low Reliability -> Cautionary
    if (reliabilityScore < 0.7) return SystemTone.cautionary;

    // High Reliability + Success -> Celebratory/Smooth
    if (reliabilityScore > 0.95 && priorityLevel <= 60) {
      return SystemTone.celebratory;
    }

    // Default
    return SystemTone.routine;
  }

  /// Modulate a message based on the current tone
  String modulate(String message, SystemTone tone) {
    switch (tone) {
      case SystemTone.urgent:
        return '🟥 URGENT: $message';
      case SystemTone.cautionary:
        return '⚠️ NOTICE: $message';
      case SystemTone.celebratory:
        return '✨ $message';
      case SystemTone.subconscious:
        return '💤 $message';
      case SystemTone.routine:
        return '🟦 $message';
      case SystemTone.concise:
        return '📑 $message';
      case SystemTone.empathetic:
        return '🕊️ $message';
    }
  }

  /// Get a style description for UI rendering
  ToneStyle getStyle(SystemTone tone) {
    switch (tone) {
      case SystemTone.urgent:
        return ToneStyle(
          colorHex: 0xFFFF5252, // Red Accent
          prefix: 'URGENT',
          icon: '🚨',
        );
      case SystemTone.cautionary:
        return ToneStyle(
          colorHex: 0xFFFFB74D, // Orange
          prefix: 'CAUTION',
          icon: '⚠️',
        );
      case SystemTone.celebratory:
        return ToneStyle(
          colorHex: 0xFF69F0AE, // Green Accent
          prefix: 'SUCCESS',
          icon: '✨',
        );
      case SystemTone.subconscious:
        return ToneStyle(
          colorHex: 0xFF7C4DFF, // Deep Purple
          prefix: 'DREAM',
          icon: '💤',
        );
      case SystemTone.routine:
        return ToneStyle(
          colorHex: 0xFF448AFF, // Blue Accent
          prefix: 'SYSTEM',
          icon: '🟦',
        );
      case SystemTone.concise:
        return ToneStyle(
          colorHex: 0xFF90A4AE, // Blue Grey
          prefix: 'BRIEF',
          icon: '📑',
        );
      case SystemTone.empathetic:
        return ToneStyle(
          colorHex: 0xFFF06292, // Pink
          prefix: 'SUPPORT',
          icon: '🕊️',
        );
    }
  }
}

enum SystemTone {
  routine, // Calm, professional (Default)
  urgent, // Sharp, concise (Critical errors/tasks)
  cautionary, // Warning, hesitant (Low confidence)
  celebratory, // Warm, confirming (High success)
  subconscious, // Abstract, floaty (Dreaming)
  concise, // Very brief (Busy mode)
  empathetic, // Soothing, supportive (Frustrated mode)
}

class ToneStyle {
  final int colorHex;
  final String prefix;
  final String icon;

  ToneStyle({
    required this.colorHex,
    required this.prefix,
    required this.icon,
  });
}
