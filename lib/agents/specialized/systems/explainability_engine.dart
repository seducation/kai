import 'dart:collection';
import 'package:uuid/uuid.dart';

/// Types of decisions the system makes
enum DecisionType {
  routing, // Which agent to use?
  ruleCheck, // Is this allowed?
  priority, // When to run it?
  simulation, // Is it safe?
  mission, // Does it fit the mission? (New)
  execution, // Final go/no-go
}

/// A specific factor influencing a decision
class DecisionFactor {
  final String source; // e.g., "RuleEngine", "MissionController"
  final String reason; // e.g., "Blocked by safe mode", "High confidence"
  final double weight; // -1.0 (Critical Block) to 1.0 (Critical Support)
  final Map<String, dynamic> metadata;

  DecisionFactor({
    required this.source,
    required this.reason,
    required this.weight,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        'reason': reason,
        'weight': weight,
        'metadata': metadata,
      };
}

/// A complete trace of a single AI decision
class DecisionTrace {
  final String traceId;
  final String intent; // What were we trying to do?
  final DateTime timestamp;
  final List<DecisionFactor> factors;
  final String? relatedMemoryId; // Link to "What" (memories)
  String finalOutcome; // "Approved", "Blocked", "Modified"
  double confidenceScore; // 0.0 - 1.0

  DecisionTrace({
    String? traceId,
    required this.intent,
    required this.timestamp,
    List<DecisionFactor>? factors,
    this.relatedMemoryId,
    this.finalOutcome = 'Pending',
    this.confidenceScore = 1.0,
  })  : traceId = traceId ?? const Uuid().v4(),
        factors = factors ?? [];

  void addFactor({
    required String source,
    required String reason,
    required double weight,
    Map<String, dynamic> metadata = const {},
  }) {
    factors.add(DecisionFactor(
      source: source,
      reason: reason,
      weight: weight,
      metadata: metadata,
    ));
  }

  /// Calculates a net score, though logic usually depends on specific blockers
  double get netScore => factors.fold(0.0, (sum, f) => sum + f.weight);

  Map<String, dynamic> toJson() => {
        'traceId': traceId,
        'intent': intent,
        'timestamp': timestamp.toIso8601String(),
        'outcome': finalOutcome,
        'confidence': confidenceScore,
        'factors': factors.map((f) => f.toJson()).toList(),
      };
}

/// Service to record and query decision traces
/// "The Black Box Recorder" for AI accountability
class ExplainabilityEngine {
  static final ExplainabilityEngine _instance =
      ExplainabilityEngine._internal();
  factory ExplainabilityEngine() => _instance;
  ExplainabilityEngine._internal();

  final Queue<DecisionTrace> _history = Queue<DecisionTrace>();
  static const int _maxHistory = 50; // Keep last 50 decisions in memory

  DecisionTrace startTrace(String intent) {
    final trace = DecisionTrace(
      intent: intent,
      timestamp: DateTime.now(),
    );
    _history.addFirst(trace);
    if (_history.length > _maxHistory) _history.removeLast();
    return trace;
  }

  List<DecisionTrace> get recentTraces => _history.toList();

  /// Get traces that were blocked
  List<DecisionTrace> get blockedTraces =>
      _history.where((t) => t.finalOutcome == 'Blocked').toList();

  /// Get the "Why Chain" for a memory
  WhyChain? getWhyChain(String memoryId) {
    try {
      final trace = _history.firstWhere((t) => t.relatedMemoryId == memoryId);
      return WhyChain(trace);
    } catch (e) {
      return null;
    }
  }
}

/// A helper class to traverse the "Why" of a decision
class WhyChain {
  final DecisionTrace trace;

  WhyChain(this.trace);

  /// Get the primary reason (highest weight factor)
  DecisionFactor? get primaryFactor {
    if (trace.factors.isEmpty) return null;
    return trace.factors
        .reduce((a, b) => a.weight.abs() > b.weight.abs() ? a : b);
  }

  /// Get all blocking factors (negative weight)
  List<DecisionFactor> get blockers =>
      trace.factors.where((f) => f.weight < 0).toList();

  /// Get all supporting factors (positive weight)
  List<DecisionFactor> get supporters =>
      trace.factors.where((f) => f.weight > 0).toList();
}
