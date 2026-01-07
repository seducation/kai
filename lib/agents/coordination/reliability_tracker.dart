import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'agent_capability.dart';

/// Tracks agent reliability and performance over time.
///
/// Integrates with the failure vault to track:
/// - Success/failure rates per agent
/// - Average execution times
/// - Priority handling performance
class ReliabilityTracker {
  // Singleton
  static final ReliabilityTracker _instance = ReliabilityTracker._internal();
  factory ReliabilityTracker() => _instance;
  ReliabilityTracker._internal();

  final Map<String, AgentReliabilityStats> _stats = {};
  String? _storagePath;
  bool _initialized = false;

  /// Initialize tracker
  Future<void> initialize() async {
    if (_initialized) return;

    final docsDir = await getApplicationDocumentsDirectory();
    _storagePath = p.join(docsDir.path, 'reliability');

    final dir = Directory(_storagePath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await _load();
    _initialized = true;
  }

  /// Record a successful execution
  void recordSuccess(
      String agentName, Duration executionTime, TaskPriority priority) {
    final stats = _getOrCreate(agentName);
    stats.recordSuccess(executionTime, priority);
    _save();
  }

  /// Record a failed execution
  void recordFailure(String agentName, String error, TaskPriority priority) {
    final stats = _getOrCreate(agentName);
    stats.recordFailure(error, priority);
    _save();
  }

  /// Get reliability score for an agent (0.0 to 1.0)
  double getReliability(String agentName) {
    return _stats[agentName]?.reliabilityScore ?? 1.0;
  }

  /// Get stats for an agent
  AgentReliabilityStats? getStats(String agentName) => _stats[agentName];

  /// Get all stats
  Map<String, AgentReliabilityStats> get allStats => Map.unmodifiable(_stats);

  /// Get agents ranked by reliability
  List<String> getAgentsByReliability() {
    final entries = _stats.entries.toList()
      ..sort((a, b) =>
          b.value.reliabilityScore.compareTo(a.value.reliabilityScore));
    return entries.map((e) => e.key).toList();
  }

  /// Get agents with reliability below a threshold
  List<String> getFailingAgents({double threshold = 0.5}) {
    return _stats.entries
        .where((e) => e.value.reliabilityScore < threshold)
        .map((e) => e.key)
        .toList();
  }

  /// Update agent profile reliability from stats
  void updateProfileReliability(AgentProfile profile) {
    final stats = _stats[profile.agentName];
    if (stats != null) {
      // Use reflection or create new profile with updated reliability
      // For now, we just track it separately
    }
  }

  AgentReliabilityStats _getOrCreate(String agentName) {
    return _stats.putIfAbsent(
        agentName, () => AgentReliabilityStats(agentName));
  }

  Future<void> _load() async {
    final file = File(p.join(_storagePath!, 'reliability_stats.json'));
    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      _stats.clear();
      data.forEach((key, value) {
        _stats[key] = AgentReliabilityStats.fromJson(value);
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_storagePath == null) return;

    final file = File(p.join(_storagePath!, 'reliability_stats.json'));
    final data = _stats.map((k, v) => MapEntry(k, v.toJson()));
    await file.writeAsString(jsonEncode(data));
  }
}

/// Statistics for a single agent's reliability
class AgentReliabilityStats {
  final String agentName;
  int successCount;
  int failureCount;
  Duration totalExecutionTime;
  final List<FailureRecord> recentFailures;
  final Map<int, int> prioritySuccessCount; // priority index -> count
  final Map<int, int> priorityFailureCount;
  DateTime lastUpdated;

  AgentReliabilityStats(this.agentName)
      : successCount = 0,
        failureCount = 0,
        totalExecutionTime = Duration.zero,
        recentFailures = [],
        prioritySuccessCount = {},
        priorityFailureCount = {},
        lastUpdated = DateTime.now();

  /// Calculate reliability score (0.0 to 1.0)
  double get reliabilityScore {
    final total = successCount + failureCount;
    if (total == 0) return 1.0; // No history = assume reliable

    // Weight recent failures more heavily
    final recentFailurePenalty = recentFailures.length * 0.05;
    final baseScore = successCount / total;

    return (baseScore - recentFailurePenalty).clamp(0.0, 1.0);
  }

  /// Calculate Salience Score for a memory/fact
  /// Higher salience = more "Sticky" and likely to be recalled
  double calculateSalience({
    required DateTime timestamp,
    int impact = 1, // 1-10 (Importance)
    int success = 1, // 0 for failure, 1 for success
  }) {
    final now = DateTime.now();
    final ageHours = now.difference(timestamp).inHours;

    // Decay function: Salience drops over time
    // Base = impact x success (Successes are more salient)
    final baseValue = impact * (success + 1);

    // Decay: value / (age + 1)^0.5
    return baseValue / (ageHours + 1);
  }

  /// Average execution time
  Duration get averageExecutionTime {
    if (successCount == 0) return Duration.zero;
    return Duration(
      milliseconds: totalExecutionTime.inMilliseconds ~/ successCount,
    );
  }

  /// Get reliability for a specific priority level
  double reliabilityForPriority(TaskPriority priority) {
    final success = prioritySuccessCount[priority.index] ?? 0;
    final failure = priorityFailureCount[priority.index] ?? 0;
    final total = success + failure;
    if (total == 0) return 1.0;
    return success / total;
  }

  void recordSuccess(Duration executionTime, TaskPriority priority) {
    successCount++;
    totalExecutionTime += executionTime;
    prioritySuccessCount[priority.index] =
        (prioritySuccessCount[priority.index] ?? 0) + 1;
    lastUpdated = DateTime.now();
  }

  void recordFailure(String error, TaskPriority priority) {
    failureCount++;
    priorityFailureCount[priority.index] =
        (priorityFailureCount[priority.index] ?? 0) + 1;

    recentFailures.add(FailureRecord(
      error: error,
      timestamp: DateTime.now(),
      priority: priority,
    ));

    // Keep only last 10 failures
    while (recentFailures.length > 10) {
      recentFailures.removeAt(0);
    }

    lastUpdated = DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'agentName': agentName,
        'successCount': successCount,
        'failureCount': failureCount,
        'totalExecutionTimeMs': totalExecutionTime.inMilliseconds,
        'recentFailures': recentFailures.map((f) => f.toJson()).toList(),
        'prioritySuccessCount': prioritySuccessCount,
        'priorityFailureCount': priorityFailureCount,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory AgentReliabilityStats.fromJson(Map<String, dynamic> json) {
    final stats = AgentReliabilityStats(json['agentName']);
    stats.successCount = json['successCount'];
    stats.failureCount = json['failureCount'];
    stats.totalExecutionTime =
        Duration(milliseconds: json['totalExecutionTimeMs']);
    stats.recentFailures.addAll(
      (json['recentFailures'] as List).map((f) => FailureRecord.fromJson(f)),
    );
    (json['prioritySuccessCount'] as Map<String, dynamic>?)?.forEach((k, v) {
      stats.prioritySuccessCount[int.parse(k)] = v;
    });
    (json['priorityFailureCount'] as Map<String, dynamic>?)?.forEach((k, v) {
      stats.priorityFailureCount[int.parse(k)] = v;
    });
    stats.lastUpdated = DateTime.parse(json['lastUpdated']);
    return stats;
  }
}

/// Record of a single failure
class FailureRecord {
  final String error;
  final DateTime timestamp;
  final TaskPriority priority;

  FailureRecord({
    required this.error,
    required this.timestamp,
    required this.priority,
  });

  Map<String, dynamic> toJson() => {
        'error': error,
        'timestamp': timestamp.toIso8601String(),
        'priority': priority.index,
      };

  factory FailureRecord.fromJson(Map<String, dynamic> json) => FailureRecord(
        error: json['error'],
        timestamp: DateTime.parse(json['timestamp']),
        priority: TaskPriority.values[json['priority']],
      );
}
