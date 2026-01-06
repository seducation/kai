import 'package:flutter/material.dart';
import '../orchestration/graph_model.dart';
import 'editor/node_editor_widget.dart';
import 'execution_timeline_widget.dart';

/// Screen for Visual Orchestration (Phase 6).
/// Allows users to visually connect agents and AI providers.
class VisualOrchestrationScreen extends StatefulWidget {
  const VisualOrchestrationScreen({super.key});

  @override
  State<VisualOrchestrationScreen> createState() =>
      _VisualOrchestrationScreenState();
}

class _VisualOrchestrationScreenState extends State<VisualOrchestrationScreen> {
  late AgentGraph _graph;

  @override
  void initState() {
    super.initState();
    _initDemoGraph();
  }

  void _initDemoGraph() {
    // sophisticated demo graph
    _graph = AgentGraph(
      id: 'demo_graph',
      name: 'Agent Flow',
      nodes: [
        GraphNode(
          id: 'web_crawler',
          label: 'Web Crawler',
          type: NodeType.agent,
          position: const Offset(100, 100),
          inputs: [NodePort(name: 'url', type: DataType.text)],
          outputs: [
            NodePort(name: 'html', type: DataType.text),
            NodePort(name: 'text', type: DataType.text)
          ],
          data: {'agentName': 'WebCrawler'},
        ),
        GraphNode(
          id: 'openai_gpt4',
          label: 'OpenAI GPT-4',
          type: NodeType.aiProvider,
          position: const Offset(400, 200),
          inputs: [
            NodePort(name: 'prompt', type: DataType.text),
            NodePort(name: 'context', type: DataType.text)
          ],
          outputs: [NodePort(name: 'response', type: DataType.text)],
          data: {'agentName': 'GPT-4'},
        ),
        GraphNode(
          id: 'code_writer',
          label: 'Code Writer',
          type: NodeType.agent,
          position: const Offset(700, 150),
          inputs: [NodePort(name: 'spec', type: DataType.text)],
          outputs: [
            NodePort(name: 'code', type: DataType.code),
            NodePort(name: 'file', type: DataType.json)
          ],
          data: {'agentName': 'CodeWriter'},
        ),
        GraphNode(
          id: 'file_system',
          label: 'File System',
          type: NodeType.utility,
          position: const Offset(1000, 300),
          inputs: [
            NodePort(name: 'file', type: DataType.json),
            NodePort(name: 'path', type: DataType.text)
          ],
          outputs: [NodePort(name: 'status', type: DataType.text)],
          data: {'agentName': 'FileSystem'},
        ),
      ],
      edges: [
        GraphEdge(
          id: 'e1',
          sourceNodeId: 'web_crawler',
          sourceSlot: 'text',
          targetNodeId: 'openai_gpt4',
          targetSlot: 'context',
        ),
        GraphEdge(
          id: 'e2',
          sourceNodeId: 'openai_gpt4',
          sourceSlot: 'response',
          targetNodeId: 'code_writer',
          targetSlot: 'spec',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Orchestrator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              // Trigger execution (dummy)
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              // Save graph
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Adaptive Breakpoint: 600px
          if (constraints.maxWidth < 600) {
            return const ExecutionTimelineWidget();
          } else {
            return NodeEditorWidget(
              graph: _graph,
              onGraphChanged: (newGraph) {
                // In a real app, we'd auto-save or update state
                _graph = newGraph;
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add node logic
          setState(() {
            _graph.nodes.add(
              GraphNode(
                id: 'new_node_${DateTime.now().millisecondsSinceEpoch}',
                label: 'New Agent',
                type: NodeType.agent,
                position: const Offset(100, 100),
                inputs: [NodePort(name: 'in', type: DataType.any)],
                outputs: [NodePort(name: 'out', type: DataType.any)],
              ),
            );
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
