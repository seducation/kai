import 'dart:ui';
import '../core/agent_base.dart';
import '../core/step_types.dart';
import '../orchestration/graph_model.dart';

/// Agent responsible for modifying the system configuration and graph.
class SystemAgent extends AgentBase {
  SystemAgent({super.logger}) : super(name: 'System');

  @override
  Future<R> onRun<R>(dynamic input) async {
    if (input is GraphModificationRequest) {
      return await modifyGraph(input) as R;
    }
    throw ArgumentError('Expected GraphModificationRequest');
  }

  /// Modify the agent graph based on instructions
  Future<AgentGraph> modifyGraph(GraphModificationRequest request) async {
    final graph = request.currentGraph;
    final instruction = request.instruction.toLowerCase();

    // Log the intent
    await execute<void>(
      action: StepType.decide,
      target: 'interpreting: ${request.instruction}',
      task: () async {},
    );

    // Simple keyword-based modification for demo
    // In a real system, this would use an LLM
    if (instruction.contains('add')) {
      return await _handleAddNode(graph, instruction);
    } else if (instruction.contains('connect')) {
      return await _handleConnectNodes(graph, instruction);
    }

    return graph;
  }

  Future<AgentGraph> _handleAddNode(
      AgentGraph graph, String instruction) async {
    return await execute<AgentGraph>(
      action: StepType.modify,
      target: 'adding node to graph',
      task: () async {
        final newGraph = AgentGraph(
          id: graph.id,
          name: graph.name,
          nodes: List.from(graph.nodes),
          edges: List.from(graph.edges),
        );

        // Heuristic: "Add a [Type] agent"
        String label = 'New Node';
        String agentName = 'Unknown';

        if (instruction.contains('translate')) {
          label = 'Translator';
          agentName = 'Translator'; // Assumes Translator agent exists
        } else if (instruction.contains('review')) {
          label = 'Reviewer';
          agentName = 'Reviewer';
        }

        final newNode = GraphNode(
          id: 'node_${DateTime.now().millisecondsSinceEpoch}',
          label: label,
          type: NodeType.agent,
          position: const Offset(500, 300), // Default position
          inputs: [NodePort(name: 'in', type: DataType.text)],
          outputs: [NodePort(name: 'out', type: DataType.text)],
          data: {'agentName': agentName},
        );

        newGraph.nodes.add(newNode);
        return newGraph;
      },
    );
  }

  Future<AgentGraph> _handleConnectNodes(
      AgentGraph graph, String instruction) async {
    return await execute<AgentGraph>(
      action: StepType.modify,
      target: 'connecting nodes',
      task: () async {
        final newGraph = AgentGraph(
          id: graph.id,
          name: graph.name,
          nodes: List.from(graph.nodes),
          edges: List.from(graph.edges),
        );

        // Heuristic: "Connect [Source] to [Target]"
        // Very simplified matching
        String? sourceId;
        String? targetId;
        String? sourceSlot;
        String? targetSlot;

        for (final node in graph.nodes) {
          if (instruction.contains(node.label.toLowerCase())) {
            if (sourceId == null) {
              sourceId = node.id;
              // Default to first output
              if (node.outputs.isNotEmpty) {
                sourceSlot = node.outputs.first.name;
              }
            } else {
              targetId = node.id;
              // Default to first input
              if (node.inputs.isNotEmpty) {
                targetSlot = node.inputs.first.name;
              }
            }
          }
        }

        if (sourceId != null &&
            targetId != null &&
            sourceSlot != null &&
            targetSlot != null) {
          newGraph.edges.add(GraphEdge(
            id: 'edge_${DateTime.now().millisecondsSinceEpoch}',
            sourceNodeId: sourceId,
            sourceSlot: sourceSlot,
            targetNodeId: targetId,
            targetSlot: targetSlot,
          ));
        }

        return newGraph;
      },
    );
  }
}

/// Request to modify the graph
class GraphModificationRequest {
  final AgentGraph currentGraph;
  final String instruction;

  GraphModificationRequest({
    required this.currentGraph,
    required this.instruction,
  });
}
