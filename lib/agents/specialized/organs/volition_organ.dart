import 'dart:async';
import 'dart:math';
import '../../core/step_types.dart';
import '../../core/step_schema.dart';
import '../../coordination/organ_base.dart';
import '../../coordination/message_bus.dart';

/// The Volition Organ 🧠✨
///
/// The source of "Free Will". It doesn't wait for commands; it generates them.
/// Driven by internal states (Curiosity, Maintenance, Achievement).
class VolitionOrgan extends Organ {
  final MessageBus bus;
  Timer? _driveTimer;
  final Random _rng = Random();

  // Internal Drives (0.0 to 1.0)
  double _curiosity = 0.5;
  double _maintenance = 0.5;

  VolitionOrgan({
    required this.bus,
  }) : super(
          name: 'VolitionOrgan',
          tissues: [], // Purely cognitive/logic based, no sub-agents needed yet
          tokenLimit: 5000,
        );

  void start() {
    // Check drives every 60 seconds (simulated "boredom")
    _driveTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _checkDrives());
  }

  void stop() {
    _driveTimer?.cancel();
  }

  Future<void> _checkDrives() async {
    // naturally increase drives over time
    _curiosity += 0.1;
    _maintenance += 0.05;

    if (_curiosity > 0.8) {
      await _triggerCuriosity();
    } else if (_maintenance > 0.9) {
      await _triggerMaintenance();
    }
  }

  Future<void> _triggerCuriosity() async {
    logStatus(
        StepType.decide, 'High Curiosity: Seeking novelty', StepStatus.running);

    // Generate a random exploration task
    final topics = [
      'Check system health',
      'Review recent logs',
      'Analyze storage usage'
    ];
    final topic = topics[_rng.nextInt(topics.length)];

    _publishDesire('I wonder about... $topic. Let\'s investigate.');
    _curiosity = 0.0; // Reset drive
    consumeMetabolite(50);
  }

  Future<void> _triggerMaintenance() async {
    logStatus(StepType.decide, 'High Maintenance Drive: Seeking order',
        StepStatus.running);

    _publishDesire('System feels cluttered. I should perform a health check.');
    _maintenance = 0.0;
    consumeMetabolite(50);
  }

  void _publishDesire(String thought) {
    // Broadcast a "Volition" message. The Controller or Social Agent can pick this up.
    bus.broadcast(AgentMessage(
      id: 'volition_${DateTime.now().millisecondsSinceEpoch}',
      from: name,
      type:
          MessageType.status, // Using status for now, or could define new type
      payload: 'VOLITION: $thought',
    ));
  }

  @override
  Future<R> onRun<R>(dynamic input) async {
    // Can also be prompted to "think"
    return 'Volition is active. Curiosity: $_curiosity' as R;
  }
}
