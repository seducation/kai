import 'dart:async';
import '../core/agent_base.dart';
import '../core/step_types.dart';
import '../core/step_schema.dart';

/// An Organ is a higher-level functional unit that groups multiple Agents.
///
/// It coordinates complex cycles (e.g., Logic Organ = Write -> Debug -> Verify).
/// It also manages its own "Metabolism" (resource budgeting).
abstract class Organ extends AgentBase {
  final List<AgentBase> tissues;
  double _metabolism = 1.0; // Health multiplier
  int _tokenUsage = 0;
  final int tokenLimit;

  Organ({
    required super.name,
    required this.tissues,
    this.tokenLimit = 10000,
    super.logger,
  });

  /// Current metabolic health (0.0 to 1.0)
  double get health => _metabolism;

  /// System is fatigued if metabolism is low
  bool get isFatigued => _metabolism < 0.3;

  /// Total tokens consumed by this organ
  int get tokenUsage => _tokenUsage;

  /// Records resource consumption.
  /// If limit exceeded, metabolism drops, triggering a "Refractory Period".
  void consumeMetabolite(int amount) {
    _tokenUsage += amount;
    if (_tokenUsage > tokenLimit) {
      _metabolism = (_metabolism - 0.1).clamp(0.0, 1.0);
      if (_metabolism < 0.3) {
        logStatus(StepType.waiting, 'Organ Fatigue: Entering Rest Period',
            StepStatus.pending);
      }
    }
  }

  /// Restores metabolism over time
  void rest() {
    _metabolism = (_metabolism + 0.2).clamp(0.0, 1.0);
    _tokenUsage = (_tokenUsage * 0.5).toInt(); // Simulate recovery
  }

  @override
  Future<R> onRun<R>(dynamic input);
}
