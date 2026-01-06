import 'package:flutter/material.dart';
import '../core/step_logger.dart';
import '../core/step_schema.dart';
import '../core/step_types.dart';
import '../services/narrator_service.dart';

/// Execution panel showing detailed step information.
/// Obsidian-style presentation with expandable details.
class ExecutionPanel extends StatefulWidget {
  final StepLogger logger;

  const ExecutionPanel({super.key, required this.logger});

  @override
  State<ExecutionPanel> createState() => _ExecutionPanelState();
}

class _ExecutionPanelState extends State<ExecutionPanel> {
  int? _selectedStepId;
  final _narrator = NarratorService();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Step list
        SizedBox(
          width: 300,
          child: _StepList(
            logger: widget.logger,
            selectedId: _selectedStepId,
            onSelect: (id) => setState(() => _selectedStepId = id),
          ),
        ),

        const VerticalDivider(width: 1),

        // Detail pane
        Expanded(
          child: _selectedStepId == null
              ? const Center(
                  child: Text(
                    'Select a step to view details',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : _StepDetail(
                  step: widget.logger.allSteps.firstWhere(
                    (s) => s.stepId == _selectedStepId,
                  ),
                  narrator: _narrator,
                ),
        ),
      ],
    );
  }
}

/// Step list with timeline
class _StepList extends StatelessWidget {
  final StepLogger logger;
  final int? selectedId;
  final void Function(int) onSelect;

  const _StepList({
    required this.logger,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final steps = logger.allSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text(
                'Execution Timeline',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => logger.clear(),
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List
        Expanded(
          child: ListView.builder(
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final isSelected = step.stepId == selectedId;

              return InkWell(
                onTap: () => onSelect(step.stepId),
                child: Container(
                  color: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1)
                      : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Timeline dot
                      Column(
                        children: [
                          if (index > 0)
                            Container(
                              width: 1,
                              height: 8,
                              color: Colors.grey[300],
                            ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _statusColor(step.status),
                            ),
                          ),
                          if (index < steps.length - 1)
                            Container(
                              width: 1,
                              height: 8,
                              color: Colors.grey[300],
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.action.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                            Text(
                              step.target,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Time
                      Text(
                        _formatTime(step.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _statusColor(StepStatus status) {
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

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}

/// Detailed view of a single step
class _StepDetail extends StatelessWidget {
  final AgentStep step;
  final NarratorService narrator;

  const _StepDetail({
    required this.step,
    required this.narrator,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Step ${step.stepId}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              _StatusChip(status: step.status),
            ],
          ),
          const SizedBox(height: 16),

          // Narration
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              narrator.narrateDetailed(step),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),

          // Details
          _DetailRow(label: 'Agent', value: step.agentName),
          _DetailRow(label: 'Action', value: step.action.displayName),
          _DetailRow(label: 'Target', value: step.target),
          _DetailRow(label: 'Status', value: step.status.displayName),
          _DetailRow(
            label: 'Timestamp',
            value: step.timestamp.toIso8601String(),
          ),
          if (step.duration != null)
            _DetailRow(
              label: 'Duration',
              value: '${step.duration!.inMilliseconds}ms',
            ),

          // Error
          if (step.errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ Error',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.errorMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Metadata
          if (step.metadata != null && step.metadata!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Metadata',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: step.metadata!.entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${e.key}: ${e.value}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final StepStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _color,
        ),
      ),
    );
  }

  Color get _color {
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
