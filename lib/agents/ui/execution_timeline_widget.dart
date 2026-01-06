import 'package:flutter/material.dart';
import '../core/step_logger.dart';
import '../core/step_schema.dart';
import '../core/step_types.dart';
import '../services/narrator_service.dart';

/// A mobile-friendly timeline view of agent execution steps.
class ExecutionTimelineWidget extends StatelessWidget {
  const ExecutionTimelineWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the global logger
    final logger = GlobalStepLogger().logger;
    final narrator = NarratorService();

    return StreamBuilder<AgentStep>(
      stream: logger.stepStream,
      builder: (context, snapshot) {
        // We use the full history from the logger, enabling "chat-like" history
        final steps = logger.allSteps.reversed.toList();

        if (steps.isEmpty) {
          return const Center(child: Text('No execution steps yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: steps.length,
          itemBuilder: (context, index) {
            final step = steps[index];
            return _buildStepCard(context, step, narrator);
          },
        );
      },
    );
  }

  Widget _buildStepCard(
      BuildContext context, AgentStep step, NarratorService narrator) {
    Color cardColor;
    switch (step.status) {
      case StepStatus.success:
        cardColor = Colors.green.shade50;
        break;
      case StepStatus.failed:
        cardColor = Colors.red.shade50;
        break;
      case StepStatus.running:
        cardColor = Colors.blue.shade50;
        break;
      default:
        cardColor = Colors.grey.shade50;
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _getIconForAction(step.action),
        title: Text('${step.agentName}: ${step.action.name.toUpperCase()}'),
        subtitle: Text(narrator.narrate(step)),
        trailing: Text(
          '${step.timestamp.hour}:${step.timestamp.minute.toString().padLeft(2, '0')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Icon _getIconForAction(StepType action) {
    switch (action) {
      case StepType.fetch:
        return const Icon(Icons.download);
      case StepType.check:
        return const Icon(Icons.check_circle_outline);
      case StepType.decide:
        return const Icon(Icons.lightbulb_outline);
      case StepType.modify:
        return const Icon(Icons.edit);
      case StepType.store:
        return const Icon(Icons.save);
      case StepType.error:
        return const Icon(Icons.error, color: Colors.red);
      default:
        return const Icon(Icons.circle, size: 12);
    }
  }
}
