import 'package:flutter/material.dart';

// Agent system imports
import 'agents/agents.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Agent AI System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AgentDemoScreen(),
    );
  }
}

/// Demo screen showing the multi-agent system in action
class AgentDemoScreen extends StatefulWidget {
  const AgentDemoScreen({super.key});

  @override
  State<AgentDemoScreen> createState() => _AgentDemoScreenState();
}

class _AgentDemoScreenState extends State<AgentDemoScreen> {
  final TextEditingController _inputController = TextEditingController();
  final StepLogger _logger = GlobalStepLogger().logger;
  final AgentRegistry _registry = agentRegistry;

  late final ControllerAgent _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _setupAgents();
  }

  void _setupAgents() {
    // Register specialized agents
    _registry.register(CodeWriterAgent(logger: _logger));
    _registry.register(CodeDebuggerAgent(logger: _logger));
    _registry.register(FileSystemAgent(logger: _logger));
    _registry.register(StorageAgent(logger: _logger));
    _registry.register(SystemAgent(logger: _logger));
    _registry.register(AppwriteFunctionAgent(logger: _logger));

    // Create controller
    _controller = ControllerAgent(
      registry: _registry,
      logger: _logger,
    );
  }

  Future<void> _processRequest(String request) async {
    if (request.trim().isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      await _controller.handleRequest<dynamic>(request);
    } catch (e) {
      _logger.logStep(
        agentName: 'System',
        action: StepType.error,
        target: e.toString(),
        status: StepStatus.failed,
        errorMessage: e.toString(),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 Multi-Agent AI System'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              _logger.clear();
              setState(() {});
            },
            tooltip: 'Clear steps',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatBadge(
                  label: 'Agents',
                  value: _registry.count.toString(),
                  icon: Icons.smart_toy,
                ),
                _StatBadge(
                  label: 'Steps',
                  value: _logger.stepCount.toString(),
                  icon: Icons.checklist,
                ),
                _StatBadge(
                  label: 'Running',
                  value: _logger.runningSteps.length.toString(),
                  icon: Icons.pending,
                ),
                _StatBadge(
                  label: 'Failed',
                  value: _logger.failedSteps.length.toString(),
                  icon: Icons.error_outline,
                  color: Colors.red,
                ),
              ],
            ),
          ),

          // Main content - Step stream
          Expanded(
            child: StepStreamWidget(
              logger: _logger,
              autoScroll: true,
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText:
                          'Enter a request (e.g., "write a hello world function")...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    onSubmitted: (value) {
                      _processRequest(value);
                      _inputController.clear();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          _processRequest(_inputController.text);
                          _inputController.clear();
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Run'),
                ),
              ],
            ),
          ),
        ],
      ),
      // Drawer for agent dashboard
      drawer: Drawer(
        child: AgentDashboard(
          registry: _registry,
          logger: _logger,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(
            fontSize: 12,
            color: color ?? Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
