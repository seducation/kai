import 'package:flutter/material.dart';
import '../core/step_logger.dart';
import '../core/step_schema.dart';
import '../core/step_types.dart';

/// Live step streaming widget - Manus-style execution transparency.
/// Shows real-time agent actions with status indicators.
class StepStreamWidget extends StatefulWidget {
  /// Step logger to stream from
  final StepLogger logger;

  /// Maximum steps to display (for performance)
  final int maxSteps;

  /// Whether to auto-scroll to newest step
  final bool autoScroll;

  /// Custom step builder
  final Widget Function(BuildContext, AgentStep)? stepBuilder;

  const StepStreamWidget({
    super.key,
    required this.logger,
    this.maxSteps = 50,
    this.autoScroll = true,
    this.stepBuilder,
  });

  @override
  State<StepStreamWidget> createState() => _StepStreamWidgetState();
}

class _StepStreamWidgetState extends State<StepStreamWidget> {
  final ScrollController _scrollController = ScrollController();
  List<AgentStep> _steps = [];

  @override
  void initState() {
    super.initState();
    _steps = widget.logger.allSteps.toList();

    // Listen for new steps
    widget.logger.stepStream.listen((step) {
      setState(() {
        // Update existing step or add new one
        final index = _steps.indexWhere((s) => s.stepId == step.stepId);
        if (index >= 0) {
          _steps[index] = step;
        } else {
          _steps.add(step);
          if (_steps.length > widget.maxSteps) {
            _steps.removeAt(0);
          }
        }
      });

      // Auto-scroll to bottom
      if (widget.autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) {
      return const Center(
        child: Text(
          'No actions yet. Steps will appear here.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _steps.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final step = _steps[index];
        return widget.stepBuilder?.call(context, step) ?? StepTile(step: step);
      },
    );
  }
}

/// A single step tile widget
class StepTile extends StatelessWidget {
  final AgentStep step;

  const StepTile({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator
          _StatusIcon(status: step.status),
          const SizedBox(width: 12),

          // Step content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step header
                Row(
                  children: [
                    Text(
                      'Step ${step.stepId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AgentBadge(agentName: step.agentName),
                    const Spacer(),
                    if (step.duration != null)
                      Text(
                        _formatDuration(step.duration!),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Action description
                Row(
                  children: [
                    Text(
                      step.action.icon,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${step.action.displayName} ${step.target}',
                        style: TextStyle(
                          fontSize: 13,
                          color: step.status == StepStatus.failed
                              ? Colors.red[700]
                              : Colors.grey[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Error message if failed
                if (step.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '⚠️ ${step.errorMessage}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
}

/// Status indicator icon
class _StatusIcon extends StatelessWidget {
  final StepStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: _backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: status == StepStatus.running
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(_iconColor),
                ),
              )
            : Text(
                status.icon,
                style: TextStyle(
                  fontSize: 12,
                  color: _iconColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Color get _backgroundColor {
    switch (status) {
      case StepStatus.running:
        return Colors.blue[50]!;
      case StepStatus.success:
        return Colors.green[50]!;
      case StepStatus.failed:
        return Colors.red[50]!;
      case StepStatus.skipped:
        return Colors.grey[100]!;
      case StepStatus.pending:
        return Colors.orange[50]!;
    }
  }

  Color get _iconColor {
    switch (status) {
      case StepStatus.running:
        return Colors.blue;
      case StepStatus.success:
        return Colors.green;
      case StepStatus.failed:
        return Colors.red;
      case StepStatus.skipped:
        return Colors.grey;
      case StepStatus.pending:
        return Colors.orange;
    }
  }
}

/// Agent name badge
class _AgentBadge extends StatelessWidget {
  final String agentName;

  const _AgentBadge({required this.agentName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _colorForAgent(agentName).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        agentName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _colorForAgent(agentName),
        ),
      ),
    );
  }

  Color _colorForAgent(String name) {
    switch (name.toLowerCase()) {
      case 'controller':
        return Colors.purple;
      case 'codewriter':
        return Colors.blue;
      case 'codedebugger':
        return Colors.orange;
      case 'webcrawler':
        return Colors.teal;
      case 'filesystem':
        return Colors.brown;
      case 'storage':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}

/// Compact step list for sidebars
class CompactStepList extends StatelessWidget {
  final StepLogger logger;
  final int maxItems;

  const CompactStepList({
    super.key,
    required this.logger,
    this.maxItems = 10,
  });

  @override
  Widget build(BuildContext context) {
    final steps = logger.allSteps.reversed.take(maxItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(step.status.icon, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${step.action.displayName} ${step.target}',
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
