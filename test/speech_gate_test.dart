import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/agents/services/speech_gate.dart';
import 'package:my_app/agents/services/narrator_service.dart';
import 'package:my_app/agents/permissions/access_gate.dart';
import 'package:my_app/agents/rules/rule_definitions.dart';
import 'package:my_app/agents/rules/rule_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Volitional Speech Gate Tests', () {
    late SpeechGate gate;
    late NarratorService narrator;

    setUp(() {
      gate = SpeechGate();
      narrator = NarratorService();
      gate.setMissionMode(false);
      RuleEngine().setProfile(ComplianceProfile.personal);
    });

    test('Normal background logs remain silent', () {
      final allowed = gate.evaluateIntent(SpeechIntent.backgroundLog);
      expect(allowed, isFalse);
    });

    test('Access denial triggers safety alert speech', () {
      final allowed = gate.evaluateIntent(SpeechIntent.safetyAlert,
          priority: PriorityLevel.reflex);
      expect(allowed, isTrue);
    });

    test('Mission reports are blocked when Mission Mode is OFF', () {
      gate.setMissionMode(false);
      final allowed = gate.evaluateIntent(SpeechIntent.missionReport);
      expect(allowed, isFalse);
    });

    test(
        'Mission reports are allowed when Mission Mode is ON and priority is sufficient',
        () {
      gate.setMissionMode(true);
      final allowed = gate.evaluateIntent(SpeechIntent.missionReport,
          priority: PriorityLevel.normal);
      expect(allowed, isTrue);
    });

    test('Direct responses are always allowed', () {
      final allowed = gate.evaluateIntent(SpeechIntent.directResponse);
      expect(allowed, isTrue);
    });

    test('System stays silent in Operator Mode', () {
      RuleEngine().setProfile(ComplianceProfile.operator);
      final allowed = gate.evaluateIntent(SpeechIntent.safetyAlert,
          priority: PriorityLevel.reflex);
      expect(allowed, isFalse);
    });
  });
}
