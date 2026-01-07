import 'package:uuid/uuid.dart';

/// Capability categories for agents
enum CapabilityCategory {
  /// Text processing (writing, translation, summarization)
  text,

  /// Code-related (writing, debugging, analysis)
  code,

  /// File system operations
  fileSystem,

  /// Web/network operations
  web,

  /// Data storage/retrieval
  storage,

  /// AI/ML model operations
  aiModel,

  /// System/orchestration
  system,

  /// Visual/image processing
  visual,

  /// Audio processing
  audio,

  /// Custom/specialized
  custom,
}

/// A specific capability an agent has
class AgentCapability {
  final String id;
  final String name;
  final CapabilityCategory category;
  final double proficiency; // 0.0 to 1.0
  final List<String> keywords;
  final Duration averageExecutionTime;
  final bool isAsync;

  const AgentCapability({
    required this.id,
    required this.name,
    required this.category,
    this.proficiency = 1.0,
    this.keywords = const [],
    this.averageExecutionTime = const Duration(seconds: 1),
    this.isAsync = true,
  });

  /// Check if this capability matches a task description
  double matchScore(String taskDescription) {
    final lowerTask = taskDescription.toLowerCase();
    double score = 0.0;

    // Check keywords
    for (final keyword in keywords) {
      if (lowerTask.contains(keyword.toLowerCase())) {
        score += 0.2;
      }
    }

    // Check category keywords
    if (lowerTask.contains(category.name.toLowerCase())) {
      score += 0.3;
    }

    // Check name
    if (lowerTask.contains(name.toLowerCase())) {
      score += 0.5;
    }

    return (score * proficiency).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.index,
        'proficiency': proficiency,
        'keywords': keywords,
        'averageExecutionTimeMs': averageExecutionTime.inMilliseconds,
        'isAsync': isAsync,
      };

  factory AgentCapability.fromJson(Map<String, dynamic> json) =>
      AgentCapability(
        id: json['id'],
        name: json['name'],
        category: CapabilityCategory.values[json['category']],
        proficiency: json['proficiency'],
        keywords: List<String>.from(json['keywords']),
        averageExecutionTime:
            Duration(milliseconds: json['averageExecutionTimeMs']),
        isAsync: json['isAsync'],
      );
}

/// Agent profile with capabilities
class AgentProfile {
  final String agentName;
  final List<AgentCapability> capabilities;
  final int maxConcurrentTasks;
  final double reliability; // 0.0 to 1.0 based on success rate
  int currentLoad;

  AgentProfile({
    required this.agentName,
    required this.capabilities,
    this.maxConcurrentTasks = 5,
    this.reliability = 1.0,
    this.currentLoad = 0,
  });

  /// Check if agent can take more tasks
  bool get canAcceptTask => currentLoad < maxConcurrentTasks;

  /// Get load factor (0.0 = idle, 1.0 = full)
  double get loadFactor => currentLoad / maxConcurrentTasks;

  /// Find best matching capability for a task
  AgentCapability? bestCapabilityFor(String taskDescription) {
    AgentCapability? best;
    double bestScore = 0.0;

    for (final cap in capabilities) {
      final score = cap.matchScore(taskDescription);
      if (score > bestScore) {
        bestScore = score;
        best = cap;
      }
    }

    return bestScore > 0.1 ? best : null;
  }

  /// Get overall match score for a task
  double matchScore(String taskDescription) {
    final cap = bestCapabilityFor(taskDescription);
    if (cap == null) return 0.0;

    final capScore = cap.matchScore(taskDescription);
    final loadPenalty = loadFactor * 0.3; // Penalize busy agents
    final reliabilityBonus = reliability * 0.2;

    return (capScore - loadPenalty + reliabilityBonus).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'agentName': agentName,
        'capabilities': capabilities.map((c) => c.toJson()).toList(),
        'maxConcurrentTasks': maxConcurrentTasks,
        'reliability': reliability,
      };
}

/// A task to be routed
class RoutableTask {
  final String id;
  final String description;
  final Map<String, dynamic>? input;
  final TaskPriority priority;
  final DateTime createdAt;
  final Duration? deadline;
  final String? preferredAgent; // Manual assignment
  final bool allowParallel;

  RoutableTask({
    String? id,
    required this.description,
    this.input,
    this.priority = TaskPriority.normal,
    DateTime? createdAt,
    this.deadline,
    this.preferredAgent,
    this.allowParallel = true,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();
}

/// Task priority levels
enum TaskPriority {
  low,
  normal,
  high,
  critical,
}

/// Confidence level classification for UI display
enum ConfidenceLevel {
  /// 80-100%: High confidence, proceed autonomously
  high,

  /// 60-79%: Moderate confidence, proceed with monitoring
  moderate,

  /// 40-59%: Low confidence, consider escalation
  low,

  /// 0-39%: Very low confidence, requires human confirmation
  uncertain,
}

/// Result of task routing
class TaskRouting {
  final RoutableTask task;
  final String assignedAgent;
  final AgentCapability matchedCapability;
  final double confidence;
  final String confidenceReason; // NEW: Explains why this confidence level
  final PlanningMode mode;
  final DateTime routedAt;

  /// Threshold below which decisions should be escalated
  static const double ESCALATION_THRESHOLD = 0.6;

  TaskRouting({
    required this.task,
    required this.assignedAgent,
    required this.matchedCapability,
    required this.confidence,
    required this.mode,
    String? confidenceReason,
    DateTime? routedAt,
  })  : confidenceReason = confidenceReason ?? _defaultReason(confidence, mode),
        routedAt = routedAt ?? DateTime.now();

  /// Generate default confidence reason based on score and mode
  static String _defaultReason(double confidence, PlanningMode mode) {
    final pct = (confidence * 100).toStringAsFixed(0);

    switch (mode) {
      case PlanningMode.manual:
        return 'Manual assignment by user';
      case PlanningMode.deterministic:
        if (confidence >= 0.8) {
          return 'High capability match ($pct%)';
        } else if (confidence >= 0.6) {
          return 'Moderate capability match ($pct%)';
        } else {
          return 'Low capability match ($pct%) — recommend verification';
        }
      case PlanningMode.exploratory:
        return 'Exploratory attempt — limited history';
      case PlanningMode.hybrid:
        if (confidence >= 0.6) {
          return 'Hybrid routing: deterministic path ($pct%)';
        } else {
          return 'Hybrid routing: exploratory fallback ($pct%)';
        }
    }
  }

  /// Get confidence level classification
  ConfidenceLevel get confidenceLevel {
    if (confidence >= 0.8) return ConfidenceLevel.high;
    if (confidence >= 0.6) return ConfidenceLevel.moderate;
    if (confidence >= 0.4) return ConfidenceLevel.low;
    return ConfidenceLevel.uncertain;
  }

  /// Check if this decision should be escalated for human review
  bool get shouldEscalate => confidence < ESCALATION_THRESHOLD;

  /// Human-readable confidence display
  String get confidenceDisplay => '${(confidence * 100).toStringAsFixed(0)}%';

  /// Emoji indicator for quick visual feedback
  String get confidenceEmoji {
    switch (confidenceLevel) {
      case ConfidenceLevel.high:
        return '🟢';
      case ConfidenceLevel.moderate:
        return '🟡';
      case ConfidenceLevel.low:
        return '🟠';
      case ConfidenceLevel.uncertain:
        return '🔴';
    }
  }
}

/// Planning modes
enum PlanningMode {
  /// Deterministic: Use predefined rules and capability matching
  deterministic,

  /// Exploratory: Try multiple agents and learn from results
  exploratory,

  /// Hybrid: Start deterministic, switch to exploratory on failure
  hybrid,

  /// Manual: User specifies the agent
  manual,
}

/// Pre-defined agent capability templates
class DefaultCapabilities {
  static const codeWriter = AgentCapability(
    id: 'cap_code_write',
    name: 'Code Writing',
    category: CapabilityCategory.code,
    keywords: [
      'write',
      'create',
      'function',
      'class',
      'implement',
      'code',
      'program'
    ],
    averageExecutionTime: Duration(seconds: 5),
  );

  static const codeDebugger = AgentCapability(
    id: 'cap_code_debug',
    name: 'Code Debugging',
    category: CapabilityCategory.code,
    keywords: ['debug', 'fix', 'error', 'bug', 'issue', 'problem', 'crash'],
    averageExecutionTime: Duration(seconds: 10),
  );

  static const webCrawler = AgentCapability(
    id: 'cap_web_crawl',
    name: 'Web Crawling',
    category: CapabilityCategory.web,
    keywords: [
      'fetch',
      'crawl',
      'scrape',
      'web',
      'url',
      'http',
      'website',
      'download'
    ],
    averageExecutionTime: Duration(seconds: 3),
  );

  static const fileManager = AgentCapability(
    id: 'cap_file_manage',
    name: 'File Management',
    category: CapabilityCategory.fileSystem,
    keywords: [
      'file',
      'folder',
      'directory',
      'read',
      'write',
      'delete',
      'move',
      'copy'
    ],
    averageExecutionTime: Duration(milliseconds: 500),
  );

  static const storage = AgentCapability(
    id: 'cap_storage',
    name: 'Data Storage',
    category: CapabilityCategory.storage,
    keywords: [
      'save',
      'store',
      'load',
      'retrieve',
      'vault',
      'memory',
      'persist'
    ],
    averageExecutionTime: Duration(milliseconds: 200),
  );

  static const diff = AgentCapability(
    id: 'cap_diff',
    name: 'Diff/Patch',
    category: CapabilityCategory.code,
    keywords: ['diff', 'patch', 'compare', 'change', 'edit', 'modify'],
    averageExecutionTime: Duration(milliseconds: 100),
  );

  static const system = AgentCapability(
    id: 'cap_system',
    name: 'System Control',
    category: CapabilityCategory.system,
    keywords: ['graph', 'node', 'connect', 'orchestrate', 'control', 'manage'],
    averageExecutionTime: Duration(seconds: 1),
  );

  static const appwriteFunction = AgentCapability(
    id: 'cap_appwrite',
    name: 'Serverless Function',
    category: CapabilityCategory.custom,
    keywords: [
      'function',
      'serverless',
      'appwrite',
      'execute',
      'lambda',
      'cloud'
    ],
    averageExecutionTime: Duration(seconds: 2),
  );
}
