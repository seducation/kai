import 'dart:async';
import 'world_state.dart';

/// Interface for things that can sense the world
abstract class SensoryInput {
  void onWorldEvent(WorldEvent event);
}

/// The Sensory System 👂
///
/// Decouples "happenings" (WorldEvents) from "perceiving" (Agents).
/// Agents subscribe to this system to receive updates about the virtual world.
class SensorySystem {
  static final SensorySystem _instance = SensorySystem._internal();
  factory SensorySystem() => _instance;
  SensorySystem._internal();

  final List<SensoryInput> _sensors = [];
  StreamSubscription? _subscription;

  /// Start listening to the world
  void initialize() {
    _subscription?.cancel();
    _subscription = VirtualWorld().events.listen(_propagateEvent);
  }

  void registerSensor(SensoryInput sensor) {
    _sensors.add(sensor);
  }

  void unregisterSensor(SensoryInput sensor) {
    _sensors.remove(sensor);
  }

  void _propagateEvent(WorldEvent event) {
    for (final sensor in _sensors) {
      sensor.onWorldEvent(event);
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
