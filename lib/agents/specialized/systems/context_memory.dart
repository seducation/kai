import 'package:uuid/uuid.dart';

/// Contextual Memory Node 🌳
///
/// Represents a "Why" in the system. Links actions to intents.
class ContextualMemory {
  final String id;
  final String? parentId;
  final String intent; // The goal (e.g., "Prepare for meeting")
  final String action; // The specific action (e.g., "Scan files")
  final DateTime timestamp;

  Map<String, dynamic> metadata;
  bool isSuccessful;
  List<ContextualMemory> subMemories = [];

  ContextualMemory({
    String? id,
    this.parentId,
    required this.intent,
    required this.action,
    this.isSuccessful = true,
    Map<String, dynamic>? metadata,
  })  : id = id ?? const Uuid().v4(),
        timestamp = DateTime.now(),
        metadata = metadata ?? {};

  /// Add a child memory (sub-task)
  void addChild(ContextualMemory child) {
    subMemories.add(child);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'parentId': parentId,
        'intent': intent,
        'action': action,
        'timestamp': timestamp.toIso8601String(),
        'isSuccessful': isSuccessful,
        'metadata': metadata,
        'children': subMemories.map((m) => m.toJson()).toList(),
      };
}

/// Simple memory tree manager
class MemoryTree {
  static final MemoryTree _instance = MemoryTree._internal();
  factory MemoryTree() => _instance;
  MemoryTree._internal();

  final List<ContextualMemory> _roots = [];

  void addRoot(ContextualMemory root) => _roots.add(root);

  List<ContextualMemory> get recentTrees => _roots.reversed.take(5).toList();

  void clear() => _roots.clear();
}

final memoryTree = MemoryTree();
