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

/// Authority Escalation Ladder 🎖️
///
/// Explicit hierarchy for conflict resolution. JARVIS always knows who is in charge.
/// Higher priority = higher authority (absolute override).
///
/// Order of authority (highest to lowest):
/// 1. Reflex (1000) - Absolute, instant safety (Spinal Cord)
/// 2. Safety Rule (900) - Immutable safety rules
/// 3. System Rule (500) - Configurable system constraints
/// 4. Mission Constraint (400) - Mission-specific limitations
/// 5. User Intent (300) - Direct user requests
/// 6. Agent Suggestion (100) - AI recommendations
enum AuthorityLevel {
  /// Absolute - blocks instantly (Reflex System)
  /// Cannot be overridden by anyone or anything.
  reflex(1000),

  /// Immutable safety rules that protect the system and user.
  /// These are hardcoded and cannot be modified by LLMs.
  safetyRule(900),

  /// Configurable system rules that govern behavior.
  /// Can be modified by admins but not by LLMs autonomously.
  systemRule(500),

  /// Mission-specific constraints set for long-running objectives.
  /// Bound to active missions only.
  missionConstraint(400),

  /// Direct user requests and intent expressions.
  /// The primary driver of action.
  userIntent(300),

  /// AI recommendations and suggestions.
  /// Can be overridden by any higher authority.
  agentSuggestion(100);

  const AuthorityLevel(this.priority);
  final int priority;

  /// Resolve conflicts between two authority levels.
  /// Higher priority wins.
  static AuthorityLevel resolveConflict(AuthorityLevel a, AuthorityLevel b) {
    return a.priority > b.priority ? a : b;
  }

  /// Check if this authority level can override another.
  bool canOverride(AuthorityLevel other) {
    return priority > other.priority;
  }

  /// Human-readable name for UI display
  String get displayName {
    switch (this) {
      case AuthorityLevel.reflex:
        return 'Reflex (Absolute)';
      case AuthorityLevel.safetyRule:
        return 'Safety Rule';
      case AuthorityLevel.systemRule:
        return 'System Rule';
      case AuthorityLevel.missionConstraint:
        return 'Mission Constraint';
      case AuthorityLevel.userIntent:
        return 'User Intent';
      case AuthorityLevel.agentSuggestion:
        return 'Agent Suggestion';
    }
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
  simulate, // Run counterfactual simulation (NEW)
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
  final AuthorityLevel
      authority; // NEW: Authority level for conflict resolution

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
    this.authority = AuthorityLevel.systemRule, // Default to system rule
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
        'authority': authority.index,
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
      authority: json['authority'] != null
          ? AuthorityLevel.values[json['authority']]
          : AuthorityLevel.systemRule,
    );
  }
}
