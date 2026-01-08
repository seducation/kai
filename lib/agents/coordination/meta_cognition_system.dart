import 'dart:async';
import '../core/step_logger.dart';
import '../core/step_schema.dart';
import '../core/step_types.dart';
import 'agent_registry.dart';
import '../specialized/systems/user_context.dart';

/// Meta-Cognition System 🧠
///
/// "The system that watches the system."
///
/// Passive observer that listens to the GlobalStepLogger and updates
/// dynamic agent profiles (Scorecards) based on performance.
///
/// Capabilities:
/// - Real-time reliability scoring
/// - Bias detection (repetitive errors)
/// - Tool usage tracking
class MetaCognitionSystem {
  static final MetaCognitionSystem _instance = MetaCognitionSystem._internal();
  factory MetaCognitionSystem() => _instance;
  MetaCognitionSystem._internal();

  StreamSubscription? _logSubscription;
  final GlobalStepLogger _logger = GlobalStepLogger();
  final AgentRegistry _registry = agentRegistry;

  bool _isActive = false;

  /// Start observing system behavior
  void start() {
    if (_isActive) return;
    _isActive = true;

    _logSubscription = _logger.stepStream.listen(_analyzeStep);
    // print('🧠 Meta-Cognition System Online');
  }

  /// Stop observing
  void stop() {
    _isActive = false;
    _logSubscription?.cancel();
    _logSubscription = null;
  }

  void _analyzeStep(AgentStep step) {
    // We only care about completed or failed steps for scoring
    if (step.status != StepStatus.success && step.status != StepStatus.failed) {
      return;
    }

    // Ignore if agent not in registry (e.g. system utilities)
    if (!_registry.hasAgent(step.agentName)) return;

    final scorecard = _registry.requireScorecard(step.agentName);
    final isSuccess = step.status == StepStatus.success;

    // Detect likely tool usage
    // Treat actions that involve external interaction as "tools"
    String? toolName;
    const toolActions = [
      StepType.fetch,
      StepType.download,
      StepType.extract,
      StepType.transcribe,
      StepType.analyze,
      StepType.modify,
      StepType.store,
    ];

    if (toolActions.contains(step.action)) {
      // Use the action paired with the target (truncated) as a proxy for tool usage
      // e.g. "fetch:https://api.xyz..."
      String safeTarget = step.target;
      if (safeTarget.length > 30) {
        safeTarget = '${safeTarget.substring(0, 27)}...';
      }
      toolName = '${step.action.name}:$safeTarget';
    }

    // Isolate error type for bias detection
    String? errorType;
    if (!isSuccess && step.errorMessage != null) {
      errorType = _classifyError(step.errorMessage!);
    }

    // Update Scorecard
    scorecard.recordResult(
      success: isSuccess,
      latency: step.duration,
      toolName: toolName,
      errorType: errorType,
    );

    // Infer User Sentiment (Layer 2)
    if (!isSuccess && scorecard.reliabilityScore < 0.5) {
      // If critical agent failing repeatedly, assume user might be frustrated
      userContext.update(newMood: UserMood.frustrated);
    } else if (isSuccess && scorecard.reliabilityScore > 0.9) {
      // High success might relax the context
      if (userContext.mood == UserMood.frustrated) {
        userContext.update(newMood: UserMood.relaxed);
      }
    }

    // Immediate Bias Check
    // If an agent fails 3 times in a row, it might be stuck in a loop or broken.
    if (!isSuccess && scorecard.reliabilityScore < 0.3) {
      _proposeOptimization(step.agentName, errorType);
    }
  }

  void _proposeOptimization(String agentName, String? errorType) {
    // Log a "Meta-Plan" suggestion
    // In a full system, this would trigger a "Refactor Agent" mission.
    _logger.log(
        agentName: 'MetaCognitionSystem',
        action: StepType.decide,
        target: 'Propose optimization for $agentName',
        status: StepStatus.success,
        metadata: {
          'reason': 'Reliability dropped below 30%',
          'suspected_issue': errorType ?? 'Unknown',
          'suggestion': 'Review error patterns and error handling logic.'
        });
  }

  /// Simple heuristic to group errors
  String _classifyError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('timeout')) return 'Timeout';
    if (lower.contains('network') || lower.contains('socket')) return 'Network';
    if (lower.contains('permission') || lower.contains('access')) {
      return 'Permission';
    }
    if (lower.contains('format') || lower.contains('parse')) return 'Format';
    if (lower.contains('null')) return 'NullPointer';
    return 'Generic';
  }
}
