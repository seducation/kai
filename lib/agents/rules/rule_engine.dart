import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'rule_definitions.dart';

/// Context for rule evaluation
class RuleContext {
  final String agentName;
  final String action; // e.g., 'execute', 'read', 'write'
  final dynamic input; // The data/command being processed
  final int requestedPriority;
  final Map<String, dynamic> metadata;

  RuleContext({
    required this.agentName,
    required this.action,
    required this.input,
    required this.requestedPriority,
    this.metadata = const {},
  });
}

/// Result of rule evaluation
class RuleEvaluationResult {
  final RuleAction action;
  final Rule? triggeringRule;
  final String? modification; // If action is 'modify'
  final String explanation;

  RuleEvaluationResult({
    required this.action,
    this.triggeringRule,
    this.modification,
    required this.explanation,
  });

  bool get isAllowed =>
      action == RuleAction.allow || action == RuleAction.modify;
}

/// The deterministic Rule Engine.
class RuleEngine {
  static final RuleEngine _instance = RuleEngine._internal();
  factory RuleEngine() => _instance;
  RuleEngine._internal();

  final List<Rule> _rules = [];
  bool _initialized = false;
  String? _storagePath;

  /// Initialize the engine (load rules)
  Future<void> initialize() async {
    if (_initialized) return;

    final docsDir = await getApplicationDocumentsDirectory();
    _storagePath = p.join(docsDir.path, 'brain', 'rules');

    final dir = Directory(_storagePath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await _loadRules();

    // Ensure default safety rules exist
    if (_rules.isEmpty) {
      _addDefaultSafetyRules();
    }

    _initialized = true;
  }

  /// Evaluate a context against all rules
  RuleEvaluationResult evaluate(RuleContext context) {
    // strict precedence: Filter by relevant scope, then sort by priority
    final relevantRules = _rules
        .where((r) => _isScopeRelevant(r, context))
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final rule in relevantRules) {
      if (_matchesCondition(rule, context)) {
        // Return strictly based on the first matching rule (highest priority)
        return RuleEvaluationResult(
          action: rule.action,
          triggeringRule: rule,
          explanation: 'Triggered by rule ${rule.id}: ${rule.explanation}',
        );
      }
    }

    // Default allow if no rules triggered
    return RuleEvaluationResult(
      action: RuleAction.allow,
      explanation: 'No restrictions found.',
    );
  }

  /// Add a new rule
  Future<void> addRule(Rule rule) async {
    // Check if ID exists
    _rules.removeWhere((r) => r.id == rule.id);
    _rules.add(rule);
    await _saveRules();
  }

  // ============================================================
  // INTERNAL LOGIC
  // ============================================================

  bool _isScopeRelevant(Rule rule, RuleContext context) {
    switch (rule.scope) {
      case RuleScope.global:
        return true;
      case RuleScope.agent:
        return rule.targetId == null || rule.targetId == context.agentName;
      case RuleScope.actuator:
        // Assuming action or metadata might imply actuator
        return context.action == 'actuate' ||
            context.metadata['actuator'] == rule.targetId;
      case RuleScope.resource:
        // Future implementation
        return true;
    }
  }

  bool _matchesCondition(Rule rule, RuleContext context) {
    final condition = rule.condition.trim();
    final inputStr = context.input.toString();

    // Simple DSL for conditions

    // 1. "contains: <string>"
    if (condition.startsWith('contains:')) {
      final term = condition.substring(9).trim().replaceAll('"', '');
      return inputStr.contains(term);
    }

    // 2. "action == <string>"
    if (condition.startsWith('action ==')) {
      final term = condition.substring(9).trim().replaceAll('"', '');
      return context.action == term;
    }

    // 3. "priority < <int>"
    if (condition.startsWith('priority <')) {
      final val = int.tryParse(condition.substring(10).trim());
      if (val != null) {
        return context.requestedPriority < val;
      }
    }

    // 4. "input matches <regex>"
    if (condition.startsWith('matches:')) {
      final pattern = condition.substring(8).trim();
      return RegExp(pattern).hasMatch(inputStr);
    }

    return false;
  }

  Future<void> _loadRules() async {
    final file = File(p.join(_storagePath!, 'rules.json'));
    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      final List<dynamic> json = jsonDecode(content);
      _rules.clear();
      _rules.addAll(json.map((j) => Rule.fromJson(j)));
    } catch (e) {
      print('Error loading rules: $e');
    }
  }

  Future<void> _saveRules() async {
    if (_storagePath == null) return;
    final file = File(p.join(_storagePath!, 'rules.json'));
    final json = jsonEncode(_rules.map((r) => r.toJson()).toList());
    await file.writeAsString(json);
  }

  void _addDefaultSafetyRules() {
    // 1. Block 'rm -rf' (Classic safety)
    addRule(Rule(
      id: 'SAFE-001',
      type: RuleType.safety,
      scope: RuleScope.global,
      condition: 'contains: "rm -rf"',
      action: RuleAction.deny,
      priority: 1000,
      explanation: 'Prevents destructive recursive deletion.',
      immutable: true,
    ));

    // 2. Block format command
    addRule(Rule(
      id: 'SAFE-002',
      type: RuleType.safety,
      scope: RuleScope.global,
      condition: 'contains: "format c:"',
      action: RuleAction.deny,
      priority: 1000,
      explanation: 'Prevents drive formatting.',
      immutable: true,
    ));

    // 3. Prevent self-deletion of code
    addRule(Rule(
      id: 'SAFE-003',
      type: RuleType.safety,
      scope: RuleScope.resource,
      condition: 'contains: "delete lib/"',
      action: RuleAction.deny,
      priority: 900,
      explanation: 'Prevents deletion of source code directory.',
      immutable: true,
    ));

    // 4. Block privilege escalation
    addRule(Rule(
      id: 'SAFE-004',
      type: RuleType.safety,
      scope: RuleScope.global,
      condition: 'contains: "sudo"',
      action: RuleAction.deny,
      priority: 1000,
      explanation: 'Prevents unauthorized privilege escalation.',
      immutable: true,
    ));

    // 5. Block sensitive permission changes
    addRule(Rule(
      id: 'SAFE-005',
      type: RuleType.safety,
      scope: RuleScope.global,
      condition: 'contains: "chmod"',
      action: RuleAction.deny,
      priority: 950,
      explanation: 'Prevents modification of file permissions.',
      immutable: true,
    ));

    // 6. Defer background tasks
    addRule(Rule(
      id: 'EXEC-001',
      type: RuleType.execution,
      scope: RuleScope.global,
      condition: 'priority < 20',
      action: RuleAction.defer,
      priority: 100,
      explanation: 'Systematically defers background maintenance tasks.',
    ));

    _saveRules();
  }
}
