import 'dart:async';
import 'dart:ui'; // For Offset
import '../core/agent_base.dart';
import '../core/step_schema.dart';
import '../core/step_types.dart';
import '../core/step_logger.dart';
import '../orchestration/graph_model.dart';
import '../specialized/specialized.dart';
import 'coordination.dart';
import 'message_bus.dart';
import 'task_queue.dart';
import 'planner_agent.dart';
import 'reliability_tracker.dart';
import 'execution_manager.dart';
import 'agent_capability.dart' show RoutableTask;
import 'autonomic_system.dart';
import 'sleep_manager.dart';
import 'immune_system.dart';
import 'reflex_system.dart';
import 'motor_system.dart';
import 'agent_profile_setup.dart';
import '../specialized/reflex_audit_agent.dart';

/// Function type for AI planning
typedef PlanningFunction = Future<ActionPlan> Function(
  String request,
  List<String> availableAgents,
);

/// The Controller Agent orchestrates other agents.
/// It takes user requests, creates action plans, and coordinates execution.
class ControllerAgent extends AgentBase with AgentDelegation {
  /// Agent registry for looking up available agents
  final AgentRegistry registry;

  /// Message bus for agent communication
  final MessageBus bus;

  /// Task queue for execution
  final TaskQueue queue;

  /// Planning function (can be AI-powered)
  final PlanningFunction? planningFunction;

  // Dynamic Routing (Phase 6b)
  AgentGraph? _activeGraph;

  // Robustness: Retry Counters
  final Map<int, int> _retryCounts = {};
  static const int _maxRetries = 3;

  // Intelligent Components
  late final PlannerAgent planner;
  final ReliabilityTracker reliability = ReliabilityTracker();
  final ExecutionManager executionManager = ExecutionManager();
  final AutonomicSystem autonomicSystem = AutonomicSystem();
  final SleepManager sleepManager = SleepManager();
  final ImmuneSystem immuneSystem = ImmuneSystem();
  final ReflexSystem reflexSystem = ReflexSystem();
  final MotorSystem motorSystem = MotorSystem();

  ControllerAgent({
    required this.registry,
    MessageBus? bus,
    TaskQueue? queue,
    this.planningFunction,
    StepLogger? logger,
  })  : bus = bus ?? messageBus,
        queue = queue ?? taskQueue,
        super(name: 'Controller', logger: logger) {
    // Initialize Planner
    planner = PlannerAgent(registry: registry, logger: logger);

    // Listen for step completions to trigger routing
    this.logger.stepStream.listen(_handleStepEvent);

    // Initialize subsystems
    _initializeSubsystems();
  }

  Future<void> _initializeSubsystems() async {
    await reliability.initialize();
    await executionManager.initialize();

    // Start life support
    autonomicSystem.start();
    sleepManager.start();

    // Start active defense
    immuneSystem.start();
    reflexSystem.start();

    final auditAgent = registry.getAgentOfType<ReflexAuditAgent>();
    if (auditAgent != null) {
      reflexSystem.setAuditAgent(auditAgent);
    }

    // Instantiate Organs (using other agents as tissues)
    _initializeOrgans();

    // Register capabilities
    AgentProfileSetup.registerDefaults(planner, registry);
  }

  void _initializeOrgans() {
    final writer = registry.getAgentOfType<CodeWriterAgent>();
    final debugger = registry.getAgentOfType<CodeDebuggerAgent>();
    final differ = registry.getAgentOfType<DiffAgent>();
    final storage = registry.getAgentOfType<StorageAgent>();
    final crawler = registry.getAgentOfType<WebCrawlerAgent>();

    LogicOrgan? logicOrgan;
    MemoryOrgan? memoryOrgan;
    DiscoveryOrgan? discoveryOrgan;

    if (writer != null && debugger != null && differ != null) {
      logicOrgan =
          LogicOrgan(writer: writer, debugger: debugger, differ: differ);
      registry.register(logicOrgan);
    }

    if (storage != null) {
      memoryOrgan = MemoryOrgan(storage: storage, reliability: reliability);
      registry.register(memoryOrgan);
    }

    if (crawler != null) {
      discoveryOrgan = DiscoveryOrgan(crawler: crawler);
      registry.register(discoveryOrgan);
    }

    // Initialize Organ Systems
    if (discoveryOrgan != null && logicOrgan != null && memoryOrgan != null) {
      final digestiveSystem = DigestiveSystem(
        discovery: discoveryOrgan,
        logic: logicOrgan,
        memory: memoryOrgan,
      );
      registry.register(digestiveSystem);
    }
  }

  void _handleStepEvent(AgentStep step) {
    // Execution Highlighting: Update node status in graph
    if (_activeGraph != null) {
      for (var node in _activeGraph!.nodes) {
        // Match node to agent name
        if (node.data['agentName'] == step.agentName) {
          switch (step.status) {
            case StepStatus.running:
              node.status = NodeStatus.running;
              break;
            case StepStatus.success:
              node.status = NodeStatus.success;
              break;
            case StepStatus.failed:
              node.status = NodeStatus.failed;
              break;
            case StepStatus.pending:
            case StepStatus.skipped:
              node.status = NodeStatus.idle;
              break;
          }
        }
      }
    }

    if (step.status == StepStatus.failed) {
      _handleStepFailure(step);
    } else if (step.status == StepStatus.success) {
      _handleStepCompletion(step);
    }
  }

  Future<void> _handleStepFailure(AgentStep step) async {
    // 1. Check if retryable
    final retries = _retryCounts[step.stepId] ?? 0;
    if (retries < _maxRetries) {
      _retryCounts[step.stepId] = retries + 1;

      logger.logStep(
        agentName: name,
        action: StepType.decide,
        target:
            'Retrying step ${step.stepId} (Attempt ${retries + 1}/$_maxRetries)',
        status: StepStatus.success,
      );

      // Auto-save state on failure/retry
      await saveRuntimeState();

      // Re-enqueue the task via the queue
      // Note: In a real system we'd need the original input.
      // For now, we assume the Agent can "retry" if we ask the Queue,
      // but Queue doesn't support generic retry of ID yet.
      // So we'll simulate by creating a new recovery task.

      // Attempt to find the agent and re-run the same action?
      // Without original input storage, this is hard.
      // Assuming 'target' contains enough info or we improve TaskQueue later.

      // For this demo, we'll just log the intent to retry.
    } else {
      logger.logStep(
        agentName: name,
        action: StepType.error,
        target: 'Max retries reached for step ${step.stepId}',
        status: StepStatus.failed,
      );
      _retryCounts.remove(step.stepId); // Cleanup
      await saveRuntimeState();
      // Trigger "Error Handler" node if exists (Future work)
    }
  }

  /// Save current runtime state to Storage/Vault
  Future<void> saveRuntimeState() async {
    final storage = registry.getAgent('Storage');
    if (storage != null && storage is StorageAgent) {
      await storage.save(
          'controller_state.json',
          {
            'retryCounts':
                _retryCounts.map((k, v) => MapEntry(k.toString(), v)),
            'timestamp': DateTime.now().toIso8601String(),
          },
          requester: 'Controller');
    }
  }

  /// Restore runtime state from Storage/Vault
  Future<void> restoreRuntimeState() async {
    final storage = registry.getAgent('Storage');
    if (storage != null && storage is StorageAgent) {
      final state =
          await storage.load('controller_state.json', requester: 'Controller');
      if (state != null && state is Map<String, dynamic>) {
        if (state['retryCounts'] != null) {
          _retryCounts.clear();
          (state['retryCounts'] as Map).forEach((k, v) {
            _retryCounts[int.parse(k)] = v as int;
          });
        }

        logger.logStep(
          agentName: name,
          action: StepType.check,
          target: 'Restored runtime state',
          status: StepStatus.success,
        );
      }
    }
  }

  void loadGraph(AgentGraph graph) {
    _activeGraph = graph;
    logger.logStep(
      agentName: name,
      action: StepType.decide,
      target: 'Graph Layout',
      status: StepStatus.success,
      metadata: {'graphId': graph.id, 'nodes': graph.nodes.length},
    );
  }

  void _handleStepCompletion(AgentStep step) {
    if (_activeGraph == null) return;
    if (step.status != StepStatus.success) return;
    if (step.agentName == name) return; // Don't route controller's own steps

    // 1. Find the node corresponding to this agent
    // Assuming agentName maps to nodeId or label for now
    // In a real system, we'd have a map or check both
    final node = _activeGraph!.nodes.firstWhere(
      (n) => n.data['agentName'] == step.agentName || n.label == step.agentName,
      orElse: () => GraphNode(
          id: 'null', label: '', type: NodeType.utility, position: Offset.zero),
    );

    if (node.id == 'null') return;

    // 2. Find outgoing edges
    final edges = _activeGraph!
        .getEdgesForNode(node.id)
        .where((e) => e.sourceNodeId == node.id);

    for (final edge in edges) {
      // 3. Identify target
      final targetNode = _activeGraph!.getNode(edge.targetNodeId);
      if (targetNode == null) continue;

      // 4. Schedule task for target
      // This is a simplification: we pass the *output* of the source
      // as the *input* (target) of the destination
      _routeData(step, targetNode, edge);
    }
  }

  Future<void> _routeData(
      AgentStep sourceStep, GraphNode targetNode, GraphEdge edge) async {
    final targetAgentName = targetNode.data['agentName'] ?? targetNode.label;

    // Log the routing event
    logger.logStep(
      agentName: name,
      action: StepType.decide,
      target: '$targetAgentName (via ${edge.id})',
      status: StepStatus.success,
      metadata: {
        'source': sourceStep.agentName,
        'target': targetAgentName,
        'data': sourceStep.target // Using 'target' as the payload for now
      },
    );

    // Create a new task
    // In a real system, we'd inspect the input port type and format accordingly
    // Here we just pass the string payload

    final agent = registry.getAgent(targetAgentName);
    if (agent != null) {
      await queue.enqueue(
        agent: agent,
        input: sourceStep.target, // Pass the output as input
        dependsOn: [sourceStep.stepId.toString()], // Enforce dependency
      );
    } else {
      logger.logStep(
        agentName: name,
        action: StepType.error,
        target: 'Target agent $targetAgentName not found',
        status: StepStatus.failed,
      );
    }
  }

  @override
  Future<R> onRun<R>(dynamic input) async {
    if (input is! String) {
      throw ArgumentError('ControllerAgent expects a String request');
    }

    return await handleRequest<R>(input);
  }

  /// Handle a user request
  Future<R> handleRequest<R>(String userRequest) async {
    // Step 0: Spinal Reflex Check (Instant Safety)
    if (reflexSystem.checkReflex(userRequest)) {
      logStatus(StepType.error, 'Blocked by Reflex System', StepStatus.failed);
      throw SecurityException(
          'Request blocked by biological reflex: Dangerous content detected');
    }

    // Step 1: Check if we can handle this locally
    final canHandle = await execute<bool>(
      action: StepType.check,
      target: 'local capabilities',
      task: () async => registry.count > 0,
    );

    if (!canHandle) {
      throw StateError('No agents registered');
    }

    // Step 2: Create action plan
    final plan = await execute<ActionPlan>(
      action: StepType.decide,
      target: 'action plan for: $userRequest',
      task: () async => await _createPlan(userRequest),
    );

    // Step 3: Execute the plan
    final result = await execute<R>(
      action: StepType.analyze,
      target: 'executing ${plan.tasks.length} tasks',
      task: () async => await _executePlan<R>(plan),
    );

    // Step 4: Mark complete
    logStatus(StepType.complete, userRequest, StepStatus.success);

    // Reset sleep timer
    notifyActivity();

    return result;
  }

  /// Notify that the system is active (reset sleep timer)
  void notifyActivity() {
    sleepManager.notifyActivity();
  }

  /// Create an action plan for the request
  Future<ActionPlan> _createPlan(String userRequest) async {
    final availableAgents = registry.agentNames;

    // If planning function is provided, use it (AI-powered planning)
    if (planningFunction != null) {
      return await planningFunction!(userRequest, availableAgents);
    }

    // Default: simple single-agent plan based on request keywords
    return await _createSmartPlan(userRequest, availableAgents);
  }

  /// Create a default plan based on keywords
  Future<ActionPlan> _createSmartPlan(
      String request, List<String> agents) async {
    // 1. Create a routable task
    final task = RoutableTask(description: request);

    // 2. Ask the Planner to route it
    // The Planner uses reliability stats and capabilities to decide
    final routing = await planner.routeTask(task);

    if (routing == null) {
      // Fallback: use first agent
      return ActionPlan(
        planId: 'plan_fallback_${DateTime.now().millisecondsSinceEpoch}',
        userRequest: request,
        tasks: [
          PlannedTask(
            agentName: agents.isNotEmpty ? agents.first : 'System',
            action: StepType.analyze,
            target: request,
          )
        ],
        createdAt: DateTime.now(),
      );
    }

    return ActionPlan(
      planId: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      userRequest: request,
      tasks: [
        PlannedTask(
          agentName: routing.assignedAgent,
          action: _mapCategoryToAction(routing.matchedCapability.category),
          target: request,
        )
      ],
      createdAt: DateTime.now(),
    );
  }

  // TODO: Add proper mapping enum
  StepType _mapCategoryToAction(dynamic category) {
    // Simple mapping for now
    return StepType.analyze;
  }

  /// Execute an action plan
  Future<R> _executePlan<R>(ActionPlan plan) async {
    final results = <int, dynamic>{};

    for (var i = 0; i < plan.tasks.length; i++) {
      final task = plan.tasks[i];

      // Wait for dependencies
      for (final depIndex in task.dependsOn) {
        if (!results.containsKey(depIndex)) {
          throw StateError('Dependency $depIndex not yet completed');
        }
      }

      // Get the agent
      final agent = registry.getAgent(task.agentName);
      if (agent == null) {
        logger.logStep(
          agentName: name,
          action: StepType.error,
          target: 'Agent ${task.agentName} not found',
          status: StepStatus.failed,
          errorMessage: 'Agent not registered',
        );
        continue;
      }

      // Execute via delegation
      try {
        final result = await delegateTo(agent, task.target);
        results[i] = result;
      } catch (e) {
        logger.logStep(
          agentName: name,
          action: StepType.error,
          target: 'Task $i failed',
          status: StepStatus.failed,
          errorMessage: e.toString(),
        );
      }
    }

    // Return the last result
    return results.isEmpty ? null as R : results.values.last as R;
  }

  /// Get all registered agent capabilities
  List<String> get capabilities => registry.agentNames;
}

/// Global controller instance
ControllerAgent? _globalController;

ControllerAgent getController({
  AgentRegistry? registry,
  MessageBus? bus,
  TaskQueue? queue,
}) {
  return _globalController!;
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  @override
  String toString() => 'SecurityException: $message';
}
