import 'package:flutter/material.dart';

/// Valid data types for ports
enum DataType {
  text,
  image,
  audio,
  video,
  json,
  code,
  any, // Universal type
}

/// A named, typed port (socket)
class NodePort {
  final String name;
  final DataType type;

  const NodePort({required this.name, required this.type});

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.toString(),
      };

  factory NodePort.fromJson(Map<String, dynamic> json) {
    return NodePort(
      name: json['name'],
      type: _parseDataType(json['type']),
    );
  }

  static DataType _parseDataType(String typeStr) {
    return DataType.values.firstWhere(
      (e) => e.toString() == typeStr,
      orElse: () => DataType.any,
    );
  }
}

/// Runtime status of a node
enum NodeStatus {
  idle,
  running,
  success,
  failed,
}

/// Represents a node in the agent graph (Agent or AI Provider).
class GraphNode {
  final String id;
  final String label;
  final NodeType type;
  Offset position;
  final List<NodePort> inputs;
  final List<NodePort> outputs;
  final Map<String, dynamic> data;

  // Runtime only - not persisted
  NodeStatus status;

  GraphNode({
    required this.id,
    required this.label,
    required this.type,
    required this.position,
    this.inputs = const [],
    this.outputs = const [],
    this.data = const {},
    this.status = NodeStatus.idle,
  });

  GraphNode copyWith({
    String? id,
    String? label,
    NodeType? type,
    Offset? position,
    List<NodePort>? inputs,
    List<NodePort>? outputs,
    Map<String, dynamic>? data,
    NodeStatus? status,
  }) {
    return GraphNode(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      position: position ?? this.position,
      inputs: inputs ?? this.inputs,
      outputs: outputs ?? this.outputs,
      data: data ?? this.data,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': type.index,
      'dx': position.dx,
      'dy': position.dy,
      'inputs': inputs.map((p) => p.toJson()).toList(),
      'outputs': outputs.map((p) => p.toJson()).toList(),
      'data': data,
      // Status is runtime only
    };
  }

  factory GraphNode.fromJson(Map<String, dynamic> json) {
    return GraphNode(
      id: json['id'],
      label: json['label'],
      type: NodeType.values[json['type'] ?? 0],
      position: Offset(json['dx'] ?? 0.0, json['dy'] ?? 0.0),
      inputs: (json['inputs'] as List?)
              ?.map((p) => NodePort.fromJson(p))
              .toList() ??
          [],
      outputs: (json['outputs'] as List?)
              ?.map((p) => NodePort.fromJson(p))
              .toList() ??
          [],
      data: json['data'] ?? {},
      status: NodeStatus.idle,
    );
  }
}

enum NodeType {
  agent,
  aiProvider,
  trigger, // User input or system event
  utility, // Helper like "Splitter" or "Filter"
}

/// Represents a connection between two nodes.
class GraphEdge {
  final String id;
  final String sourceNodeId;
  final String sourceSlot;
  final String targetNodeId;
  final String targetSlot;

  GraphEdge({
    required this.id,
    required this.sourceNodeId,
    required this.sourceSlot,
    required this.targetNodeId,
    required this.targetSlot,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceNodeId': sourceNodeId,
      'sourceSlot': sourceSlot,
      'targetNodeId': targetNodeId,
      'targetSlot': targetSlot,
    };
  }

  factory GraphEdge.fromJson(Map<String, dynamic> json) {
    return GraphEdge(
      id: json['id'],
      sourceNodeId: json['sourceNodeId'],
      sourceSlot: json['sourceSlot'],
      targetNodeId: json['targetNodeId'],
      targetSlot: json['targetSlot'],
    );
  }
}

/// The entire graph structure.
class AgentGraph {
  final String id;
  final String name;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  AgentGraph({
    required this.id,
    required this.name,
    this.nodes = const [],
    this.edges = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'edges': edges.map((e) => e.toJson()).toList(),
    };
  }

  factory AgentGraph.fromJson(Map<String, dynamic> json) {
    return AgentGraph(
      id: json['id'],
      name: json['name'],
      nodes: (json['nodes'] as List).map((n) => GraphNode.fromJson(n)).toList(),
      edges: (json['edges'] as List).map((e) => GraphEdge.fromJson(e)).toList(),
    );
  }

  /// Helper to find a node by ID
  GraphNode? getNode(String id) {
    try {
      return nodes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Find all edges connected to a node
  List<GraphEdge> getEdgesForNode(String nodeId) {
    return edges
        .where((e) => e.sourceNodeId == nodeId || e.targetNodeId == nodeId)
        .toList();
  }
}
