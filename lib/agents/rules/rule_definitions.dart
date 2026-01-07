/// Priority levels for the system (JARVIS-like).
///
/// These are fixed and cannot be modified by LLMs.
class PriorityLevel {
  static const int reflex = 100; // Immediate safety interception
  static const int critical = 90; // System integrity / data loss prevention
  static const int emergency = 80; // User-defined urgent tasks
  static const int high = 60; // Time-sensitive user tasks
  static const int normal = 40; // Default execution
  static const int low = 20; // Background / optimization
  static const int sleep = 10; // Maintenance, cleanup

  static String getName(int level) {
    if (level >= reflex) return 'Reflex';
    if (level >= critical) return 'Critical';
    if (level >= emergency) return 'Emergency';
    if (level >= high) return 'High';
    if (level >= normal) return 'Normal';
    if (level >= low) return 'Low';
    return 'Sleep';
  }
}

/// Types of rules enforced by the engine.
enum RuleType {
  safety, // Prevent irreversible damage (Never override)
  permission, // Access control (Never override)
  execution, // Workflow constraints (Override allowed)
  interrupt, // Preemption logic (Override allowed)
  resource, // CPU, memory, storage (Override allowed)
  escalation, // Human approval (No override)
}

/// Scope of the rule application.
enum RuleScope {
  global, // Applies to everything
  agent, // Applies to specific agent types
  actuator, // Applies to specific actuators
  resource, // Applies to specific resources (files, etc)
}

/// Action to take when a rule is triggered.
enum RuleAction {
  allow, // Explicitly allow (whitelist)
  deny, // Stop execution
  modify, // Rewrite intent/parameters
  escalate, // Require human/higher approval
  defer, // Lower priority or wait
}

/// A deterministic rule governing system behavior.
class Rule {
  final String id;
  final RuleType type;
  final RuleScope scope;
  final String? targetId; // Specific agent/actuator ID if scope is not global
  final String condition; // Expression or keyword to match
  final RuleAction action;
  final int priority; // Rule evaluation priority (higher = checked first)
  final String explanation;
  final bool immutable; // Can be modified by SystemAgent?

  const Rule({
    required this.id,
    required this.type,
    required this.scope,
    this.targetId,
    required this.condition,
    required this.action,
    this.priority = 10,
    required this.explanation,
    this.immutable = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'scope': scope.index,
        'targetId': targetId,
        'condition': condition,
        'action': action.index,
        'priority': priority,
        'explanation': explanation,
        'immutable': immutable,
      };

  factory Rule.fromJson(Map<String, dynamic> json) {
    return Rule(
      id: json['id'],
      type: RuleType.values[json['type']],
      scope: RuleScope.values[json['scope']],
      targetId: json['targetId'],
      condition: json['condition'],
      action: RuleAction.values[json['action']],
      priority: json['priority'] ?? 10,
      explanation: json['explanation'],
      immutable: json['immutable'] ?? false,
    );
  }
}
