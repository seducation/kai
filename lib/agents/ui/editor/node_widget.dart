import 'package:flutter/material.dart';
import '../../orchestration/graph_model.dart';

/// A single node widget in the visual editor.
/// Mimics Blender/Unreal node style with inputs on left, outputs on right.
class NodeWidget extends StatelessWidget {
  final GraphNode node;
  final bool isSelected;
  final VoidCallback? onTap;
  final Function(Offset)? onDragUpdate;

  const NodeWidget({
    super.key,
    required this.node,
    this.isSelected = false,
    this.onTap,
    this.onDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: node.position.dx,
      top: node.position.dy,
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (details) => onDragUpdate?.call(details.delta),
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            color: const Color(0xFF2d2d2d),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getStatusColor(node.status),
              width: 2,
            ),
            boxShadow: [
              if (node.status == NodeStatus.running)
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getStatusColor(node.status).withValues(alpha: 0.2),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getNodeIcon(node.type),
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        node.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Body with sockets
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Inputs
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: node.inputs
                            .map((port) => _Socket(
                                  port: port,
                                  isInput: true,
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Outputs
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: node.outputs
                            .map((port) => _Socket(
                                  port: port,
                                  isInput: false,
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(NodeStatus status) {
    switch (status) {
      case NodeStatus.running:
        return Colors.blueAccent;
      case NodeStatus.success:
        return Colors.greenAccent;
      case NodeStatus.failed:
        return Colors.redAccent;
      case NodeStatus.idle:
        return const Color(0xFF444444);
    }
  }

  IconData _getNodeIcon(NodeType type) {
    switch (type) {
      case NodeType.agent:
        return Icons.smart_toy;
      case NodeType.aiProvider:
        return Icons.psychology;
      case NodeType.utility:
        return Icons.build;
      default:
        return Icons.circle;
    }
  }
}

class _Socket extends StatelessWidget {
  final NodePort port;
  final bool isInput;

  const _Socket({
    required this.port,
    required this.isInput,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: isInput ? TextDirection.ltr : TextDirection.rtl,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _getTypeColor(port.type),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5), width: 1),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            port.name,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(DataType type) {
    switch (type) {
      case DataType.text:
        return Colors.white;
      case DataType.image:
        return Colors.purpleAccent;
      case DataType.audio:
        return Colors.orangeAccent;
      case DataType.video:
        return Colors.redAccent;
      case DataType.json:
        return Colors.amberAccent;
      case DataType.code:
        return Colors.blueAccent;
      case DataType.any:
        return Colors.grey;
    }
  }
}
