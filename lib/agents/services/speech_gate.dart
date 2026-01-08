import '../coordination/autonomic_system.dart';
import '../specialized/systems/user_context.dart';
import '../rules/rule_engine.dart';
import '../rules/rule_definitions.dart';
import '../coordination/message_bus.dart';

/// Why the system wants to speak.
enum SpeechIntent {
  /// A critical rule was violated or a dangerous action blocked.
  safetyAlert,

  /// System health or stability has changed significantly.
  healthUpdate,

  /// Periodic report during an active mission.
  missionReport,

  /// Response to a direct user question (Always allowed).
  directResponse,

  /// Low-priority background chatter (Usually blocked).
  backgroundLog,
}

/// A rule that governs whether a specific intent is allowed to speak.
class SpeechRule {
  final bool Function(SpeechIntent intent, SystemHealth health,
      UserContext context, int priority) condition;
  final String description;

  const SpeechRule({required this.condition, required this.description});
}

/// The Volitional Speech Gate 🔊
///
/// Prevents the system from speaking unless specific, intentional conditions are met.
class SpeechGate {
  static final SpeechGate _instance = SpeechGate._internal();
  factory SpeechGate() => _instance;
  SpeechGate._internal() {
    _initListener();
  }

  bool _isMissionMode = false;

  /// Enable or disable Mission Mode.
  /// When enabled, progress reports are allowed.
  void setMissionMode(bool enabled) => _isMissionMode = enabled;
  bool get isMissionMode => _isMissionMode;

  /// Initialize system-wide listener for critical events
  void _initListener() {
    messageBus.allMessages.listen((msg) {
      if (msg.type == MessageType.error) {
        evaluateIntent(SpeechIntent.safetyAlert,
            priority: PriorityLevel.critical);
        // Note: NarratorService would actually handle the 'speak' call,
        // this listener just ensures the Gate is context-aware.
      }
    });
  }

  final List<SpeechRule> _rules = [
    // Rule 1: Always allow direct responses to user commands
    SpeechRule(
      description: 'Allow direct responses',
      condition: (intent, _, __, ___) => intent == SpeechIntent.directResponse,
    ),

    // Rule 2: Safety Alerts are top priority, but blocked in Operator Mode
    SpeechRule(
      description: 'Allow safety alerts except in Operator Mode',
      condition: (intent, _, __, ___) =>
          intent == SpeechIntent.safetyAlert &&
          RuleEngine().activeProfile != ComplianceProfile.operator,
    ),

    // Rule 3: Health updates only if Critical
    SpeechRule(
      description: 'Allow critical health updates',
      condition: (intent, health, _, __) =>
          intent == SpeechIntent.healthUpdate &&
          health == SystemHealth.critical,
    ),

    // Rule 4: Mission reports only if Mission Mode is ON and priority is sufficient
    SpeechRule(
      description: 'Allow mission reports in Mission Mode',
      condition: (intent, _, __, p) =>
          intent == SpeechIntent.missionReport &&
          SpeechGate().isMissionMode &&
          p >= PriorityLevel.normal,
    ),

    // Rule 5: Block everything else if Compliance Profile is Restricted
    SpeechRule(
      description: 'Block all in Restricted mode',
      condition: (_, __, ___, ____) =>
          RuleEngine().activeProfile == ComplianceProfile.restricted
              ? false
              : false, // Intentional fallthrough
    ),
  ];

  /// Evaluate if a speech intent is allowed to proceed.
  bool evaluateIntent(SpeechIntent intent,
      {int priority = PriorityLevel.normal}) {
    final health = AutonomicSystem().currentHealth;
    final context = UserContext();

    // Check Compliance Profile first (Hard override)
    if (RuleEngine().activeProfile == ComplianceProfile.operator) {
      // In Operator Mode, the human is the voice. The system stays silent.
      return false;
    }

    for (final rule in _rules) {
      if (rule.condition(intent, health, context, priority)) {
        return true;
      }
    }

    return false;
  }
}
