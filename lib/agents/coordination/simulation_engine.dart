import 'dart:async';
import 'package:uuid/uuid.dart';
import '../core/step_logger.dart';
import '../core/step_types.dart';
import '../core/step_schema.dart';
import 'execution_manager.dart';
import 'reliability_tracker.dart';
import '../rules/rule_engine.dart';
import '../rules/rule_definitions.dart';

/// Result of simulating an action
class SimulationResult {
  final String id;
  final String scenario;
  final double riskScore; // 0.0 (safe) to 1.0 (catastrophic)
  final String predictedOutcome;
  final List<String> sideEffects;
  final bool isRecommended;
  final DateTime simulatedAt;

  SimulationResult({
    String? id,
    required this.scenario,
    required this.riskScore,
    required this.predictedOutcome,
    this.sideEffects = const [],
    this.isRecommended = false,
    DateTime? simulatedAt,
  })  : id = id ?? const Uuid().v4(),
        simulatedAt = simulatedAt ?? DateTime.now();

  /// Human-readable risk level
  String get riskLevel {
    if (riskScore < 0.2) return 'Very Low';
    if (riskScore < 0.4) return 'Low';
    if (riskScore < 0.6) return 'Moderate';
    if (riskScore < 0.8) return 'High';
    return 'Critical';
  }

  /// Emoji for quick visual feedback
  String get riskEmoji {
    if (riskScore < 0.2) return '🟢';
    if (riskScore < 0.4) return '🟡';
    if (riskScore < 0.6) return '🟠';
    if (riskScore < 0.8) return '🔴';
    return '⛔';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'scenario': scenario,
        'riskScore': riskScore,
        'predictedOutcome': predictedOutcome,
        'sideEffects': sideEffects,
        'isRecommended': isRecommended,
        'simulatedAt': simulatedAt.toIso8601String(),
      };
}

/// Counterfactual Simulation Engine 🔮
///
/// Before executing high-risk actions:
/// - Simulates 2-3 outcome branches
/// - Compares risk deltas
/// - Picks safest path
///
/// This is NOT AGI — it's deterministic sandboxing with risk scoring.
class SimulationEngine {
  static final SimulationEngine _instance = SimulationEngine._internal();
  factory SimulationEngine() => _instance;
  SimulationEngine._internal();

  final GlobalStepLogger _logger = GlobalStepLogger();
  final ReliabilityTracker _reliability = ReliabilityTracker();
  final RuleEngine _ruleEngine = RuleEngine();
  ExecutionManager? _executionManager;

  /// Set the execution manager for dry-run capability
  void setExecutionManager(ExecutionManager manager) {
    _executionManager = manager;
  }

  /// Risk threshold above which simulation is triggered
  static const double RISK_THRESHOLD = 0.5;

  /// Actions that always require simulation
  static const List<String> HIGH_RISK_ACTIONS = [
    'delete',
    'drop',
    'format',
    'deploy',
    'production',
    'migrate',
    'truncate',
  ];

  /// Check if action should be simulated
  bool shouldSimulate(String action) {
    final lowerAction = action.toLowerCase();
    return HIGH_RISK_ACTIONS.any((term) => lowerAction.contains(term));
  }

  /// Simulate an action and return possible outcomes
  ///
  /// Returns 2-3 scenarios with risk scores, sorted by risk (lowest first)
  Future<List<SimulationResult>> simulateAction({
    required String agentName,
    required String action,
    dynamic input,
    Map<String, dynamic>? context,
  }) async {
    _logSimulation('Starting simulation: $action', StepStatus.running);

    final results = <SimulationResult>[];

    try {
      // Scenario 1: Best case (action succeeds normally)
      results.add(await _simulateBestCase(agentName, action, input));

      // Scenario 2: Typical case (action with common issues)
      results.add(await _simulateTypicalCase(agentName, action, input));

      // Scenario 3: Worst case (action fails catastrophically)
      results.add(await _simulateWorstCase(agentName, action, input));

      // Sort by risk (lowest first)
      results.sort((a, b) => a.riskScore.compareTo(b.riskScore));

      // Mark the lowest-risk as recommended
      if (results.isNotEmpty) {
        final safest = results.first;
        results[0] = SimulationResult(
          id: safest.id,
          scenario: safest.scenario,
          riskScore: safest.riskScore,
          predictedOutcome: safest.predictedOutcome,
          sideEffects: safest.sideEffects,
          isRecommended: true,
          simulatedAt: safest.simulatedAt,
        );
      }

      _logSimulation(
        'Simulation complete: ${results.length} scenarios analyzed',
        StepStatus.success,
      );
    } catch (e) {
      _logSimulation('Simulation failed: $e', StepStatus.failed);

      // Return a high-risk result on simulation failure
      results.add(SimulationResult(
        scenario: 'Simulation Failed',
        riskScore: 0.9,
        predictedOutcome: 'Unable to simulate: $e',
        sideEffects: ['Proceed with extreme caution'],
      ));
    }

    return results;
  }

  /// Get the safest path from simulation results
  SimulationResult selectSafestPath(List<SimulationResult> results) {
    if (results.isEmpty) {
      return SimulationResult(
        scenario: 'No Simulation',
        riskScore: 0.5,
        predictedOutcome: 'No simulation data available',
      );
    }

    return results.firstWhere(
      (r) => r.isRecommended,
      orElse: () => results.first,
    );
  }

  /// Check if simulation results recommend proceeding
  bool shouldProceed(List<SimulationResult> results) {
    if (results.isEmpty) return false;

    final safest = selectSafestPath(results);
    return safest.riskScore < RISK_THRESHOLD;
  }

  // ============================================================
  // SCENARIO GENERATORS
  // ============================================================

  Future<SimulationResult> _simulateBestCase(
    String agentName,
    String action,
    dynamic input,
  ) async {
    // Calculate risk based on agent reliability and action type
    final agentSuccess = _reliability.getReliability(agentName);
    final actionRisk = _calculateActionRisk(action);

    // Best case: agent succeeds, minimal risk
    final risk = (1.0 - agentSuccess) * 0.3 + actionRisk * 0.2;

    return SimulationResult(
      scenario: 'Best Case (Success)',
      riskScore: risk.clamp(0.0, 1.0),
      predictedOutcome: 'Action completes successfully with no issues',
      sideEffects: _predictSideEffects(action, risk),
    );
  }

  Future<SimulationResult> _simulateTypicalCase(
    String agentName,
    String action,
    dynamic input,
  ) async {
    final agentSuccess = _reliability.getReliability(agentName);
    final actionRisk = _calculateActionRisk(action);

    // Typical case: some issues expected
    final risk = (1.0 - agentSuccess) * 0.5 + actionRisk * 0.5;

    final sideEffects = _predictSideEffects(action, risk);
    if (risk > 0.3) {
      sideEffects.add('May require retry or manual intervention');
    }

    return SimulationResult(
      scenario: 'Typical Case (Mixed)',
      riskScore: risk.clamp(0.0, 1.0),
      predictedOutcome: 'Action completes with minor issues',
      sideEffects: sideEffects,
    );
  }

  Future<SimulationResult> _simulateWorstCase(
    String agentName,
    String action,
    dynamic input,
  ) async {
    final agentSuccess = _reliability.getReliability(agentName);
    final actionRisk = _calculateActionRisk(action);

    // Worst case: failure with cascading effects
    final risk = (1.0 - agentSuccess) * 0.8 + actionRisk * 0.9;

    final sideEffects = _predictSideEffects(action, risk);
    sideEffects.addAll([
      'Data loss possible',
      'May require rollback',
      'System instability',
    ]);

    return SimulationResult(
      scenario: 'Worst Case (Failure)',
      riskScore: risk.clamp(0.0, 1.0),
      predictedOutcome: 'Action fails with potential cascading effects',
      sideEffects: sideEffects,
    );
  }

  // ============================================================
  // RISK CALCULATION
  // ============================================================

  double _calculateActionRisk(String action) {
    final lowerAction = action.toLowerCase();
    double risk = 0.1; // Base risk

    // High-risk keywords
    if (lowerAction.contains('delete')) risk += 0.4;
    if (lowerAction.contains('drop')) risk += 0.5;
    if (lowerAction.contains('format')) risk += 0.6;
    if (lowerAction.contains('production')) risk += 0.3;
    if (lowerAction.contains('deploy')) risk += 0.2;
    if (lowerAction.contains('migrate')) risk += 0.3;

    // Medium-risk keywords
    if (lowerAction.contains('update')) risk += 0.15;
    if (lowerAction.contains('modify')) risk += 0.15;
    if (lowerAction.contains('write')) risk += 0.1;

    // Low-risk keywords actually reduce risk
    if (lowerAction.contains('read')) risk -= 0.1;
    if (lowerAction.contains('list')) risk -= 0.1;
    if (lowerAction.contains('check')) risk -= 0.05;

    // Check against rule engine for blocked actions
    final context = RuleContext(
      agentName: 'SimulationEngine',
      action: action,
      input: null,
      requestedPriority: PriorityLevel.normal,
    );

    if (!_ruleEngine.evaluate(context).isAllowed) {
      risk = 1.0; // Blocked by rules = maximum risk
    }

    return risk.clamp(0.0, 1.0);
  }

  List<String> _predictSideEffects(String action, double risk) {
    final effects = <String>[];
    final lowerAction = action.toLowerCase();

    if (lowerAction.contains('delete')) {
      effects.add('Permanent data removal');
    }

    if (lowerAction.contains('deploy')) {
      effects.add('Service restart may occur');
    }

    if (lowerAction.contains('migrate')) {
      effects.add('Schema changes');
    }

    if (risk > 0.5) {
      effects.add('Human verification recommended');
    }

    if (risk > 0.7) {
      effects.add('Backup strongly advised');
    }

    return effects;
  }

  void _logSimulation(String message, StepStatus status) {
    _logger.log(
      agentName: 'SimulationEngine',
      action: StepType.check,
      target: message,
      status: status,
    );
  }
}

/// Global simulation engine instance
final simulationEngine = SimulationEngine();
