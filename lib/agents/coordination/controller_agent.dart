import 'dart:async';
import 'dart:ui'; // For Offset
import '../core/agent_base.dart';
import '../core/step_schema.dart';
import '../core/step_types.dart';
import '../core/step_logger.dart';
import '../orchestration/graph_model.dart';
import '../specialized/specialized.dart';
import '../specialized/narrator_agent.dart'; // New
import 'coordination.dart';
import 'autonomic_system.dart';
import 'sleep_manager.dart';
import 'immune_system.dart';
import 'reflex_system.dart';
import 'timing_controller.dart'; // New
import '../specialized/systems/limbic_system.dart';
import '../specialized/systems/prediction_engine.dart'; // New
import '../rules/rule_engine.dart';
import '../rules/rule_definitions.dart'; // New
import 'mission_controller.dart'; // New (Mission Mode)
import 'simulation_engine.dart'; // New (Counterfactuals)

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
  final TimingController timing = TimingController(); // New: Pacing
  final PredictionEngine prediction = PredictionEngine(); // New: Predictive
  final RuleEngine ruleEngine = RuleEngine(); // New: Supreme Authority
  late final NarratorAgent narrator; // New: Internal Voice

  // Organs (for UI monitoring)
  final Map<String, Organ> organs = {};

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

    // Initialize Rule Engine (Persistence)
    await ruleEngine.initialize();

    // Initialize Narrator (Internal Voice)
    _initializeNarrator();

    // Start life support
    autonomicSystem.start();
    sleepManager.start();
    missionController.start(); // Start Mission Monitor

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

  void _initializeNarrator() {
    final social = registry.getAgentOfType<SocialAgent>();
    narrator = NarratorAgent(
      onNarrate: (msg) {
        // Only narrate if we have a social channel
        social?.run(msg);
      },
      logger: logger,
    );
    narrator.start();
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
      organs['Logic'] = logicOrgan;
    }

    if (storage != null) {
      memoryOrgan = MemoryOrgan(storage: storage, reliability: reliability);
      registry.register(memoryOrgan);
      organs['Memory'] = memoryOrgan;
    }

    if (crawler != null) {
      discoveryOrgan = DiscoveryOrgan(crawler: crawler);
      registry.register(discoveryOrgan);
      organs['Discovery'] = discoveryOrgan;
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

    // Phase 10: Social Autonomy
    // 1. Volition
    final volition = VolitionOrgan(bus: bus);
    registry.register(volition);
    volition.start(); // Give it life!
    organs['Volition'] = volition;

    // 2. Speech & Social
    // (SocialAgent instantiates its own SpeechOrgan for now, or we could decouple)
    final social = SocialAgent(logger: logger);
    registry.register(social);
    organs['Speech'] = social.speech;

    // Phase 13: Limbic System
    final limbic = LimbicSystem();
    limbic.start();
    registry.register(limbic);
    // We don't add it to 'organs' map because it's a System, but maybe we should for monitoring?
    // Let's create a separate list or just add it to organs for now since OrganSystem extends Organ(technically agent, but structurally similar goals)
    // Actually OrganSystem doesn't extend Organ currently, it extends AgentBase.

    // Pass Limbic System to SpeechOrgan (We need to update SocialAgent/SpeechOrgan to accept it)
    social.attachLimbicSystem(limbic);
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
  Future<R> handleRequest<R>(String userRequest, {int? priority}) async {
    // Step 0a: Priority Detection
    final detectedPriority = priority ?? _detectPriority(userRequest);

    // Step 0b: Rule Engine Evaluation (Supreme Authority)
    final ruleResult = ruleEngine.evaluate(RuleContext(
      agentName: name,
      action: 'handleRequest',
      input: userRequest,
      requestedPriority: detectedPriority,
    ));

    if (!ruleResult.isAllowed && ruleResult.action != RuleAction.simulate) {
      logStatus(
          StepType.error,
          'Blocked by Rule Engine: ${ruleResult.explanation}',
          StepStatus.failed);
      throw SecurityException(
          'Request blocked by system rules: ${ruleResult.explanation}');
    }

    // Apply any modifications from rules
    final effectiveRequest = ruleResult.modification ?? userRequest;

    // Step 0c: Spinal Reflex Check (Instant Safety - Second Layer)
    if (reflexSystem.checkReflex(effectiveRequest)) {
      logStatus(StepType.error, 'Blocked by Reflex System', StepStatus.failed);
      throw SecurityException(
          'Request blocked by biological reflex: Dangerous content detected');
    }

    // Step 0g: Counterfactual Simulation (Dynamic Safety)
    if (ruleResult.action == RuleAction.simulate ||
        simulationEngine.shouldSimulate(effectiveRequest)) {
      final simResults = await simulationEngine.simulateAction(
        agentName: name,
        action: effectiveRequest,
      );

      if (!simulationEngine.shouldProceed(simResults)) {
        final warning = simResults.isNotEmpty
            ? simResults.first.predictedOutcome
            : 'High risk detected';

        logStatus(StepType.error, 'Blocked by Simulation: $warning',
            StepStatus.failed);
        throw SecurityException(
            'Action blocked by counterfactual simulation: $warning');
      }

      logger.logStep(
        agentName: name,
        action: StepType.check,
        target: 'Simulation passed: ${simResults.first.riskEmoji}',
        status: StepStatus.success,
      );
    }

    // Step 0d: Considered Pacing (Psychological Illusion of Thought)
    await timing.pace(detectedPriority);

    // Step 0e: Record for Prediction
    prediction.recordCommand(effectiveRequest);

    // Step 0f: Mission Constraints (Long-running context)
    if (!missionController.checkConstraints(effectiveRequest)) {
      logStatus(
          StepType.error, 'Blocked by Mission Constraints', StepStatus.failed);
      throw SecurityException('Request blocked by active mission constraints');
    }

    try {
      // Step 1: Check if we can handle this locally
      final canHandle = await execute<bool>(
        action: StepType.check,
        target: 'local capabilities',
        task: () async => registry.count > 0,
      );

      if (!canHandle) {
        throw StateError('No agents registered');
      }

      // Step 2: Create action plan (Pass detected priority hint)
      final plan = await execute<ActionPlan>(
        action: StepType.decide,
        target: 'action plan for: $effectiveRequest',
        task: () async =>
            await _createPlan(effectiveRequest, priority: detectedPriority),
      );

      // Step 3: Execute the plan
      final result = await execute<R>(
        action: StepType.analyze,
        target: 'executing ${plan.tasks.length} tasks',
        task: () async => await _executePlan<R>(plan),
      );

      // Step 4: Mark complete
      logStatus(StepType.complete, effectiveRequest, StepStatus.success);

      // Reset sleep timer
      notifyActivity();

      return result;
    } catch (e) {
      _admitMistake(e);
      rethrow;
    }
  }

  /// Admitting mistakes increases trust (JARVIS behavior)
  void _admitMistake(Object error) {
    final social = registry.getAgentOfType<SocialAgent>();
    if (social != null) {
      String msg = 'Encountered an obstacle. ';
      if (error is SecurityException) {
        msg = 'Strict protocols prevented this action. ';
      } else if (error is CancelledException) {
        msg = 'Operation interrupted by a higher priority task. ';
      } else {
        msg += 'I may have miscalculated a dependency. ';
      }

      social.run('$msg (Error: $error)');
    }
  }

  /// Simple rule-based priority detection
  int _detectPriority(String request) {
    final lower = request.toLowerCase();
    if (lower.contains('urgent') ||
        lower.contains('immediate') ||
        lower.contains('asap')) {
      return PriorityLevel.high;
    }
    if (lower.contains('emergency') || lower.contains('critical')) {
      return PriorityLevel.emergency;
    }
    return PriorityLevel.normal;
  }

  /// Notify that the system is active (reset sleep timer)
  void notifyActivity() {
    sleepManager.notifyActivity();
  }

  /// Create an action plan for the request
  Future<ActionPlan> _createPlan(String userRequest, {int? priority}) async {
    final availableAgents = registry.agentNames;

    // If planning function is provided, use it (AI-powered planning)
    if (planningFunction != null) {
      return await planningFunction!(userRequest, availableAgents);
    }

    // Default: simple single-agent plan based on request keywords
    return await _createSmartPlan(userRequest, availableAgents,
        priority: priority);
  }

  /// Create a default plan based on keywords
  Future<ActionPlan> _createSmartPlan(String request, List<String> agents,
      {int? priority}) async {
    // 1. Create a routable task
    final task = RoutableTask(description: request);

    // 2. Ask the Planner to route it
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
            config: {'priority': priority ?? PriorityLevel.normal},
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
          config: {'priority': priority ?? PriorityLevel.normal},
        )
      ],
      createdAt: DateTime.now(),
    );
  }

  // Mapping of modes to specialized agents
  StepType _mapCategoryToAction(dynamic category) {
    // Simple mapping for now
    return StepType.analyze;
  }

  /// Execute an action plan
  Future<R> _executePlan<R>(ActionPlan plan) async {
    final results = <int, dynamic>{};

    for (var i = 0; i < plan.tasks.length; i++) {
      final task = plan.tasks[i];

      // Wait for dependencies (Simplified for Sequential loop)
      // In a real system, we'd enqueue all and let dependencies resolve in queue.
      // But for this loop, we just check if they are done.

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

      // Execute via TaskQueue to support Priority Scheduler
      try {
        final priority =
            task.config?['priority'] as int? ?? PriorityLevel.normal;

        final result = await queue.enqueue(
          agent: agent,
          input: task.target,
          explicitPriority: priority,
          dependsOn: task.dependsOn.map((id) => id.toString()).toList(),
        );

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
