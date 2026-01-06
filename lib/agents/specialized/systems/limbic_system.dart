import 'dart:async';
import '../../coordination/organ_system.dart';

/// The Emotional State using the PAD Model (Pleasure, Arousal, Dominance)
/// Values range from -1.0 to 1.0
class EmotionalState {
  double pleasure; // -1 (Misery) to +1 (Ecstasy)
  double arousal; // -1 (Sleepy) to +1 (Excitement/Frenzy)
  double dominance; // -1 (Fear/Submissive) to +1 (Rage/Dominant)

  EmotionalState({
    this.pleasure = 0.0,
    this.arousal = 0.0,
    this.dominance = 0.0,
  });

  /// Derive a simple label for the current state
  String get label {
    if (pleasure > 0.5 && arousal > 0.5) return 'Joyful 🤩';
    if (pleasure > 0.5 && arousal < -0.2) return 'Content 😌';
    if (pleasure < -0.5 && arousal > 0.5) return 'Anxious 😰';
    if (pleasure < -0.5 && arousal < -0.5) return 'Depressed 😞';
    if (dominance > 0.5 && pleasure < 0.0) return 'Frustrated 😠';
    if (dominance < -0.5 && arousal > 0.0) return 'Fearful 😨';
    return 'Neutral 😐';
  }

  /// Decay emotions back to neutral over time
  void decay() {
    pleasure *= 0.95;
    arousal *= 0.95;
    dominance *= 0.95;
  }
}

/// The Limbic System 🎭
///
/// Regulates emotions and modulates system behavior.
class LimbicSystem extends OrganSystem {
  final EmotionalState _state = EmotionalState();
  Timer? _decayTimer;

  EmotionalState get state => _state;

  LimbicSystem() : super(name: 'LimbicSystem', organs: []); // No sub-organs yet

  void start() {
    // Emotions fade over time if not reinforced
    _decayTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _state.decay();
    });
  }

  void stop() {
    _decayTimer?.cancel();
  }

  /// React to an external stimulus or internal event
  ///
  /// [valence] - Positive or negative impact (-1.0 to 1.0)
  /// [intensity] - How strong the event is (0.0 to 1.0)
  void stimulate(double valence, double intensity) {
    // 1. Pleasure shifts based on valence
    _state.pleasure =
        (_state.pleasure + (valence * intensity)).clamp(-1.0, 1.0);

    // 2. Arousal increases with intensity (regardless of valence)
    _state.arousal = (_state.arousal + (intensity * 0.5)).clamp(-1.0, 1.0);

    // 3. Dominance increases with positive success, drops with failure
    if (valence > 0) {
      _state.dominance = (_state.dominance + 0.1).clamp(-1.0, 1.0);
    } else {
      _state.dominance = (_state.dominance - 0.2).clamp(-1.0, 1.0);
    }
  }

  @override
  Future<R> onRun<R>(dynamic input) async {
    return 'Emotional State: ${_state.label} (P:${_state.pleasure.toStringAsFixed(1)}, A:${_state.arousal.toStringAsFixed(1)}, D:${_state.dominance.toStringAsFixed(1)})'
        as R;
  }
}
