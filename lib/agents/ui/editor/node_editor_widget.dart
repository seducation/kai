import 'package:flutter/material.dart';
import '../../orchestration/graph_model.dart';
import 'node_widget.dart';

/// The visual node editor canvas.
/// Supports panning, zooming, dragging nodes, and visualizing connections.
class NodeEditorWidget extends StatefulWidget {
  final AgentGraph graph;
  final Function(AgentGraph) onGraphChanged;

  const NodeEditorWidget({
    super.key,
    required this.graph,
    required this.onGraphChanged,
  });

  @override
  State<NodeEditorWidget> createState() => _NodeEditorWidgetState();
}

class _NodeEditorWidgetState extends State<NodeEditorWidget> {
  late AgentGraph _graph;
  String? _selectedNodeId;
  final TransformationController _transformController =
      TransformationController();

  // For connecting nodes
  String? _draggingSourceNode;
  String? _draggingSourceSlot;
  Offset? _dragPosition;

  @override
  void initState() {
    super.initState();
    _graph = widget.graph;
  }

  void _updateNodePosition(String nodeId, Offset delta) {
    setState(() {
      final node = _graph.getNode(nodeId);
      if (node != null) {
        // Adjust delta by scale factor to keep dragging 1:1 with cursor
        final scale = _transformController.value.getMaxScaleOnAxis();
        node.position += delta / scale;
        widget.onGraphChanged(_graph);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E1E), // Dark background like Blender
      child: Stack(
        children: [
          // Grid lines (optional, can be added with CustomPainter)

          // Canvas
          InteractiveViewer(
            transformationController: _transformController,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.1,
            maxScale: 2.0,
            constrained: false, // Infinite canvas
            child: SizedBox(
              width: 5000,
              height: 5000,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Connections Layer
                  CustomPaint(
                    painter: ConnectionPainter(
                      graph: _graph,
                      dragStart: _draggingSourceNode != null
                          ? _getNodeOutputPos(
                              _draggingSourceNode!, _draggingSourceSlot!)
                          : null,
                      dragEnd: _dragPosition,
                    ),
                  ),

                  // Nodes Layer
                  Stack(
                    children: _graph.nodes.map((node) {
                      return NodeWidget(
                        node: node,
                        isSelected: node.id == _selectedNodeId,
                        onTap: () => setState(() => _selectedNodeId = node.id),
                        onDragUpdate: (delta) =>
                            _updateNodePosition(node.id, delta),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // UI Overlays (Zoom controls, Mini-map, etc.)
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  onPressed: () {
                    setState(() {
                      _transformController.value = Matrix4.identity();
                    });
                  },
                  child: const Icon(Icons.center_focus_strong),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to approximate socket position based on node pos
  // Ideally this should be calculated dynamically via GlobalKeys
  Offset _getNodeOutputPos(String nodeId, String slot) {
    final node = _graph.getNode(nodeId);
    if (node == null) return Offset.zero;

    // Very rough approximation for demo
    // To be precise: Node Width is 200, Output is on Right
    // Slot index logic needed
    final slotIndex = node.outputs.indexWhere((p) => p.name == slot);
    final safeIdx = slotIndex == -1 ? 0 : slotIndex;
    return node.position + Offset(200, 50.0 + (safeIdx * 24));
  }
}

/// Paints the curved connections (noodles) between nodes
class ConnectionPainter extends CustomPainter {
  final AgentGraph graph;
  final Offset? dragStart;
  final Offset? dragEnd;

  ConnectionPainter({required this.graph, this.dragStart, this.dragEnd});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw existing connections
    for (final edge in graph.edges) {
      final source = _resolvePos(edge.sourceNodeId, edge.sourceSlot, true);
      final target = _resolvePos(edge.targetNodeId, edge.targetSlot, false);
      _drawBezier(canvas, source, target, paint);
    }

    // Draw active drag line
    if (dragStart != null && dragEnd != null) {
      final activePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      _drawBezier(canvas, dragStart!, dragEnd!, activePaint);
    }
  }

  void _drawBezier(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final path = Path();
    path.moveTo(p1.dx, p1.dy);

    // Cubic bezier for smooth "noodle" look
    final dist = (p2.dx - p1.dx).abs();
    final c1 = Offset(p1.dx + dist / 2, p1.dy);
    final c2 = Offset(p2.dx - dist / 2, p2.dy);

    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    canvas.drawPath(path, paint);
  }

  // Same rough approximation as parent widget
  Offset _resolvePos(String nodeId, String slot, bool isOutput) {
    final node = graph.getNode(nodeId);
    if (node == null) return Offset.zero;

    if (isOutput) {
      final idx = node.outputs.indexWhere((p) => p.name == slot);
      final safeIdx = idx == -1 ? 0 : idx;
      return node.position + Offset(200, 85.0 + (safeIdx * 28));
    } else {
      final idx = node.inputs.indexWhere((p) => p.name == slot);
      final safeIdx = idx == -1 ? 0 : idx;
      return node.position + Offset(0, 85.0 + (safeIdx * 28));
    }
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter oldDelegate) => true;
}
