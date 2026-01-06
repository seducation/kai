import 'dart:async';
import '../core/agent_base.dart';
import '../core/step_types.dart';
import '../core/step_schema.dart';
import 'organ_base.dart';

/// An OrganSystem coordinates multiple Organs to achieve complex systemic goals.
///
/// It maintains "Homeostasis" by balancing the metabolic load of its organs.
abstract class OrganSystem extends AgentBase {
  final List<Organ> organs;

  OrganSystem({
    required super.name,
    required this.organs,
    super.logger,
  });

  /// Overall system health based on organ metabolic states
  double get systemicHomeostasis {
    if (organs.isEmpty) return 1.0;
    final totalHealth =
        organs.fold<double>(0, (sum, organ) => sum + organ.health);
    return totalHealth / organs.length;
  }

  /// Balance load across organs.
  /// If homeostasis is low, the system may delay or throttle requests.
  Future<void> maintainHomeostasis() async {
    final health = systemicHomeostasis;
    if (health < 0.5) {
      logStatus(StepType.waiting,
          'Systemic Fatigue: Throttling for Homeostasis', StepStatus.pending);
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  @override
  Future<R> onRun<R>(dynamic input);
}
