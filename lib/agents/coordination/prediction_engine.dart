import '../core/step_schema.dart';
import '../specialized/systems/circadian_tracker.dart';
import 'agent_registry.dart';

/// Prediction Engine 🔮
///
/// Forecasts the success probability of a task before it is executed.
class PredictionEngine {
  static final PredictionEngine _instance = PredictionEngine._internal();
  factory PredictionEngine() => _instance;
  PredictionEngine._internal();

  final AgentRegistry _registry = agentRegistry;
  final CircadianRhythmTracker _temporal = CircadianRhythmTracker();

  /// Forecast success probability for a planned task
  double forecast(PlannedTask task) {
    final agent = _registry.getAgent(task.agentName);
    final scorecard = _registry.getScorecard(task.agentName);

    double confidence = 1.0;

    // 1. Base Reliability
    if (scorecard != null) {
      confidence *= scorecard.reliabilityScore;
    }

    // 2. Metabolic Stress Penalty
    if (agent != null) {
      // 20% penalty at max stress
      confidence *= (1.0 - (agent.metabolicStress * 0.2));
    }

    // 3. Temporal Context Adjustment
    final likelyActionTypes = _temporal.getLikelyActions();
    if (likelyActionTypes.contains(task.action.name)) {
      // 10% boost if this task matches historical behavior for this time
      confidence = (confidence + 0.1).clamp(0.0, 1.0);
    }

    return confidence;
  }
}

final predictionEngine = PredictionEngine();
