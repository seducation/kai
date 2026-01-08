import 'dart:async';
import 'package:uuid/uuid.dart';

enum EntityType {
  project,
  file,
  bug,
  user,
  agent,
  other,
}

/// An object in the virtual world
class WorldEntity {
  final String id;
  final String name;
  final EntityType type;
  final Map<String, dynamic> metadata;

  // Spatial metaphor (0.0 to 1.0 coords for sandbox visualization)
  final double x;
  final double y;

  WorldEntity({
    required this.id,
    required this.name,
    required this.type,
    this.metadata = const {},
    this.x = 0.5,
    this.y = 0.5,
  });

  WorldEntity copyWith({
    String? name,
    Map<String, dynamic>? metadata,
    double? x,
    double? y,
  }) {
    return WorldEntity(
      id: id,
      name: name ?? this.name,
      type: type,
      metadata: metadata ?? this.metadata,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}

enum WorldEventType {
  entityCreated,
  entityUpdated,
  entityDeleted,
  entityMoved,
}

/// An event that occurred in the world
class WorldEvent {
  final String id;
  final WorldEventType type;
  final String entityId;
  final WorldEntity? entity;
  final DateTime timestamp;

  WorldEvent({
    required this.type,
    required this.entityId,
    this.entity,
  })  : id = const Uuid().v4(),
        timestamp = DateTime.now();
}

/// The Virtual World (Sandbox) 🌍
///
/// Maintains the persistent state of the system's "belief" about the world.
class VirtualWorld {
  static final VirtualWorld _instance = VirtualWorld._internal();
  factory VirtualWorld() => _instance;
  VirtualWorld._internal();

  final Map<String, WorldEntity> _entities = {};

  final StreamController<WorldEvent> _eventStream =
      StreamController.broadcast();
  Stream<WorldEvent> get events => _eventStream.stream;

  List<WorldEntity> get entities => _entities.values.toList();

  /// Create or Add an entity
  void addEntity(WorldEntity entity) {
    _entities[entity.id] = entity;
    _eventStream.add(WorldEvent(
      type: WorldEventType.entityCreated,
      entityId: entity.id,
      entity: entity,
    ));
  }

  /// Update an existing entity
  void updateEntity(WorldEntity entity) {
    if (!_entities.containsKey(entity.id)) return;
    _entities[entity.id] = entity;
    _eventStream.add(WorldEvent(
      type: WorldEventType.entityUpdated,
      entityId: entity.id,
      entity: entity,
    ));
  }

  /// Remove an entity
  void removeEntity(String id) {
    if (!_entities.containsKey(id)) return;
    _entities.remove(id);
    _eventStream.add(WorldEvent(
      type: WorldEventType.entityDeleted,
      entityId: id,
    ));
  }

  WorldEntity? getEntity(String id) => _entities[id];

  void clear() {
    _entities.clear();
  }
}
