import 'dart:async';
import '../coordination/agent_registry.dart';

/// Prediction Engine (Strategic Anticipation) 🔮
///
/// Tracks user command patterns to preload agents and tools.
/// Eliminates "loading" perception by being ready before the user asks.
class PredictionEngine {
  final List<String> _commandHistory = [];
  final Map<String, int> _patternWeights = {};

  /// Minimum occurrences to consider a pattern
  static const int minPatternThreshold = 3;

  /// Record a command and update patterns
  void recordCommand(String command) {
    _commandHistory.add(command.toLowerCase());
    if (_commandHistory.length > 50) _commandHistory.removeAt(0);

    _updatePatterns();
  }

  void _updatePatterns() {
    if (_commandHistory.length < 2) return;

    // Simple Bigram pattern: "cmd A" -> "cmd B"
    final last = _commandHistory[_commandHistory.length - 2];
    final current = _commandHistory.last;
    final pattern = '$last -> $current';

    _patternWeights[pattern] = (_patternWeights[pattern] ?? 0) + 1;
  }

  /// Predict next likely agent based on history
  List<String> predictNextAgents() {
    if (_commandHistory.isEmpty) return [];

    final lastCmd = _commandHistory.last;
    final candidates = <String, int>{};

    _patternWeights.forEach((pattern, weight) {
      if (pattern.startsWith('$lastCmd -> ')) {
        final predicted = pattern.split(' -> ').last;
        candidates[predicted] = weight;
      }
    });

    final sorted = candidates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Map command keywords to agents (Simple map for now)
    return sorted
        .map((e) => _mapCommandToAgent(e.key))
        .whereType<String>()
        .toList();
  }

  String? _mapCommandToAgent(String command) {
    if (command.contains('code') || command.contains('write'))
      return 'CodeWriter';
    if (command.contains('crawl') || command.contains('web'))
      return 'WebCrawler';
    if (command.contains('test') || command.contains('debug'))
      return 'CodeDebugger';
    return null;
  }
}
