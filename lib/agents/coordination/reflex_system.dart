import '../specialized/reflex_audit_agent.dart';
import 'message_bus.dart';

/// The Reflex System (Spinal Cord) ⚡
///
/// Reacts faster than the Brain (`Planner`). Intercepts signals and inputs
/// to prevent damage before high-level processing occurs.
///
/// Functions:
/// 1. **Nociception (Pain Sensing)**: Detects dangerous keywords.
/// 2. **Motor Reflex**: Blocks execution of risky actions.
/// 3. **Startle Response**: Instant reaction to rapid failure.
class ReflexSystem {
  static final ReflexSystem _instance = ReflexSystem._internal();
  factory ReflexSystem() => _instance;
  ReflexSystem._internal();

  final MessageBus _bus = messageBus;
  bool _isActive = false;

  // Dangerous keywords that trigger a "Pain" withdrawal reflex
  static const List<String> _dangerSignals = [
    'rm -rf',
    'delete database',
    'drop table',
    'format c:',
    'sudo',
  ];

  // Startle Reflex: Short-term failure memory
  final Map<String, List<int>> _failureTimestamps = {};
  static const int _windowSeconds = 10;
  static const int _threshold = 5;

  // AI Judge
  ReflexAuditAgent? auditAgent;

  void setAuditAgent(ReflexAuditAgent agent) {
    auditAgent = agent;
  }

  void start() {
    if (_isActive) return;
    _isActive = true;
  }

  /// Record a failure for an agent and check for Startle Reflex
  Future<bool> reportFailure(String agentName, String error) async {
    if (!_isActive) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final timestamps = _failureTimestamps.putIfAbsent(agentName, () => []);

    // 1. Add new failure
    timestamps.add(now);

    // 2. Prune old failures (sliding window)
    timestamps.removeWhere((t) => now - t > _windowSeconds * 1000);

    // 3. Check Threshold
    if (timestamps.length >= _threshold) {
      // STARTLE TRIGGERED ⚡
      // Instead of instant block, we ask the AI Judge
      if (auditAgent != null) {
        final shouldQuarantine = await auditAgent!.run<bool>({
          'agent': agentName,
          'errors': List.filled(timestamps.length, error), // Simplified history
        });

        if (shouldQuarantine) {
          _triggerQuarantine(agentName);
          return true;
        }
      } else {
        // Fallback if no AI -> Hard block
        _triggerQuarantine(agentName);
        return true;
      }
    }
    return false;
  }

  void _triggerQuarantine(String agentName) {
    // print('⚡ STARTLE REFLEX: Quarantining agent "$agentName"');
    _bus.broadcast(AgentMessage(
      id: 'reflex_q_${DateTime.now().millisecondsSinceEpoch}',
      from: 'ReflexSystem',
      type: MessageType.error,
      payload: 'QUARANTINE:$agentName',
    ));
    _failureTimestamps.remove(agentName); // Reset after action
  }

  /// The "Dodge" Reflex
  /// Returns TRUE if danger is detected and blocked.
  bool checkReflex(String input) {
    if (!_isActive) return false;

    // Nociception: Check for pain signals
    for (final signal in _dangerSignals) {
      if (input.toLowerCase().contains(signal)) {
        _triggerPainWithdrawal(signal);
        return true; // Blocked!
      }
    }
    return false;
  }

  void _triggerPainWithdrawal(String stimulus) {
    // print('⚡ REFLEX ACTIVATED: Withdrawal from dangerous stimulus "$stimulus"');
    _bus.broadcast(AgentMessage(
      id: 'reflex_${DateTime.now().millisecondsSinceEpoch}',
      from: 'ReflexSystem',
      type: MessageType.error,
      payload: 'Blocked dangerous action: $stimulus',
    ));
  }
}
