import 'dart:async';
import 'message_bus.dart';
import 'reliability_tracker.dart';

/// The Immune System 🛡️
///
/// Actively defends the Agent System against "pathogens" (errors, corruption).
///
/// Functions:
/// 1. **White Blood Cells**: Scans for anomalies.
/// 2. **Fever Response**: Enters "Safe Mode" if infection rate (errors) is high.
/// 3. **Antibodies**: Auto-patches specific known issues.
class ImmuneSystem {
  static final ImmuneSystem _instance = ImmuneSystem._internal();
  factory ImmuneSystem() => _instance;
  ImmuneSystem._internal();

  Timer? _scanTimer;
  final Duration _scanInterval = const Duration(minutes: 5);
  final MessageBus _bus = messageBus;
  final ReliabilityTracker _reliability = ReliabilityTracker();

  // Inflammation Level (0.0 to 1.0)
  double _inflammation = 0.0;
  bool _isFeverMode = false;

  final StreamController<double> _inflammationStream =
      StreamController.broadcast();
  Stream<double> get inflammationStream => _inflammationStream.stream;

  void start() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(_scanInterval, (_) => _patrol());

    // Listen to "Pain" signals (Errors)
    _bus.allMessages.listen((event) {
      if (event.type == MessageType.error) {
        _spikeInflammation(0.1);
      } else if (event.type == MessageType.status &&
          event.payload == 'complete') {
        _reduceInflammation(0.01);
      }
    });

    _patrol(); // Initial patrol
  }

  void stop() {
    _scanTimer?.cancel();
  }

  /// White Blood Cell Patrol
  Future<void> _patrol() async {
    // 1. Check for "Dead" Agents (High failure rate)
    final deadAgents = _reliability.getFailingAgents(threshold: 0.8);
    if (deadAgents.isNotEmpty) {
      // print('🦠 Pathogens detected (Failing Agents): $deadAgents');
      _spikeInflammation(0.2 * deadAgents.length);
      // In future: Quarantine them
    }

    // 2. Check for "Fever" conditions
    if (_inflammation > 0.6 && !_isFeverMode) {
      _triggerFever();
    } else if (_inflammation < 0.3 && _isFeverMode) {
      _breakFever();
    }

    // Decay inflammation naturally over time
    _reduceInflammation(0.05);
  }

  void _spikeInflammation(double amount) {
    _inflammation = (_inflammation + amount).clamp(0.0, 1.0);
    _inflammationStream.add(_inflammation);
  }

  void _reduceInflammation(double amount) {
    _inflammation = (_inflammation - amount).clamp(0.0, 1.0);
    _inflammationStream.add(_inflammation);
  }

  void _triggerFever() {
    _isFeverMode = true;
    // print('🔥 FEVER RESPONSE ACTIVATED: System Entering Safe Mode');
    // Lock down non-essential systems (simulated)
    // _bus.publish(Message(type: MessageType.systemLockdown));
  }

  void _breakFever() {
    _isFeverMode = false;
    // print('💧 Fever Broken: System Returning to Homeostasis');
  }

  bool get isCompromised => _isFeverMode;
}
