import 'package:flutter/material.dart';
import '../coordination/agent_registry.dart';
import '../coordination/controller_agent.dart';
import '../core/agent_base.dart';
import '../core/step_logger.dart';
import '../core/step_schema.dart';
import '../services/api_key_manager.dart';
import '../specialized/organs/volition_organ.dart';
import 'biological/organ_monitor_widget.dart';
import 'biological/volition_stream_widget.dart';
import 'step_stream_widget.dart';
import 'dream_reports_screen.dart';
import 'visual_orchestration_screen.dart';
import 'api_key_settings_screen.dart';
import 'rule_priority_screen.dart';
import 'system_status_row.dart';

/// Dashboard showing all agents and their status.
/// Provides overview of the multi-agent system.
class AgentDashboard extends StatefulWidget {
  final AgentRegistry registry;
  final StepLogger logger;

  const AgentDashboard({
    super.key,
    required this.registry,
    required this.logger,
  });

  @override
  State<AgentDashboard> createState() => _AgentDashboardState();
}

class _AgentDashboardState extends State<AgentDashboard> {
  @override
  void initState() {
    super.initState();
    // Listen for agent registration changes
    widget.registry.onRegister((_) => setState(() {}));
    widget.registry.onUnregister((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final agents = widget.registry.allAgents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    '🤖 Agent Dashboard',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${agents.length} agents',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // System Health & Sleep Status
              const SystemStatusRow(),

              const SizedBox(height: 8),

              // Biological Monitoring (Phase 12 Integration)
              // We find the ControllerAgent to access biological state
              Builder(builder: (context) {
                final controller = agents.firstWhere(
                    (a) => a is ControllerAgent,
                    orElse: () => agents.first);

                if (controller is ControllerAgent &&
                    controller.organs.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: OrganMonitorWidget(organs: controller.organs),
                      ),
                      if (controller.organs.containsKey('Volition'))
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: VolitionStreamWidget(
                              volition: controller.organs['Volition']
                                  as VolitionOrgan),
                        ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              }),
            ],
          ),
        ),

        // Summary stats
        _StatsRow(logger: widget.logger),

        const Divider(),

        // Agent grid
        Expanded(
          child: agents.isEmpty
              ? const Center(
                  child: Text(
                    'No agents registered',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: agents.length,
                  itemBuilder: (context, index) {
                    return AgentCard(
                      agent: agents[index],
                      logger: widget.logger,
                    );
                  },
                ),
        ),

        const Divider(),

        // Navigation
        ListTile(
          leading: const Icon(Icons.nightlight_round, color: Colors.purple),
          title: const Text('Dream Reports'),
          subtitle: const Text('Offline Analysis & Optimization'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DreamReportsScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.hub),
          title: const Text('Visual Orchestration'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VisualOrchestrationScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.gavel),
          title: const Text('Rules & Priority Engine'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RulePriorityScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.key),
          title: const Text('API Keys'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FutureBuilder<ApiKeyManager>(
                  future: ApiKeyManager.init(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    return ApiKeySettingsScreen(apiKeyManager: snapshot.data!);
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Stats row showing execution summary
class _StatsRow extends StatelessWidget {
  final StepLogger logger;

  const _StatsRow({required this.logger});

  @override
  Widget build(BuildContext context) {
    final steps = logger.allSteps;
    final successful =
        steps.where((s) => s.status == StepStatus.success).length;
    final failed = steps.where((s) => s.status == StepStatus.failed).length;
    final running = steps.where((s) => s.status == StepStatus.running).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Total',
            value: steps.length.toString(),
            color: Colors.blue,
          ),
          _StatItem(
            label: 'Success',
            value: successful.toString(),
            color: Colors.green,
          ),
          _StatItem(
            label: 'Failed',
            value: failed.toString(),
            color: Colors.red,
          ),
          _StatItem(
            label: 'Running',
            value: running.toString(),
            color: Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// Card displaying a single agent
class AgentCard extends StatelessWidget {
  final AgentBase agent;
  final StepLogger logger;

  const AgentCard({
    super.key,
    required this.agent,
    required this.logger,
  });

  @override
  Widget build(BuildContext context) {
    final agentSteps = logger.getStepsForAgent(agent.name);
    final isExecuting = agent.isExecuting;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showAgentDetails(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isExecuting ? Colors.green : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      agent.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${agentSteps.length} steps',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (isExecuting)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAgentDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${agent.name} Steps',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              // Step list
              Expanded(
                child: StepStreamWidget(
                  logger: logger,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
