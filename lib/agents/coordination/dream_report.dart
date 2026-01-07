// Dream Mode Data Models

/// Capability types for Dreaming Mode
enum DreamCapability {
  /// Clusters related vault entries, links cause→effect
  memoryConsolidation,

  /// Replays failures, detects recurring patterns
  failurePatternAnalysis,

  /// Re-runs old tasks in simulation (non-executing)
  plannerSimulation,

  /// Finds conflicting/dead/overlapping rules
  ruleConflictDetection,
}

/// Status of a dream cycle
enum DreamStatus {
  /// Currently running
  running,

  /// Completed successfully
  completed,

  /// Interrupted by user activity
  interrupted,

  /// Terminated due to safety constraint violation
  safetyTriggered,
}

/// Type of recommendation
enum RecommendationType {
  /// Suggests a new rule
  newRule,

  /// Suggests modifying an existing rule
  modifyRule,

  /// Suggests removing a rule
  removeRule,

  /// Suggests memory organization
  memoryLink,

  /// General insight/observation
  insight,
}

/// Approval status for recommendations
enum ApprovalStatus {
  pending,
  approved,
  rejected,
  deferred,
}

/// A single observation made during dreaming
class DreamObservation {
  final String id;
  final String category;
  final String description;
  final double confidence;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  DreamObservation({
    required this.id,
    required this.category,
    required this.description,
    required this.confidence,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'description': description,
        'confidence': confidence,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  factory DreamObservation.fromJson(Map<String, dynamic> json) =>
      DreamObservation(
        id: json['id'] as String,
        category: json['category'] as String,
        description: json['description'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        data: json['data'] as Map<String, dynamic>? ?? {},
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// A recommendation requiring human approval
class DreamRecommendation {
  final String id;
  final String title;
  final String description;
  final RecommendationType type;
  ApprovalStatus status;
  final Map<String, dynamic> proposedChange;
  final String? sourceObservationId;
  final DateTime createdAt;
  DateTime? reviewedAt;
  String? reviewNote;

  DreamRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.status = ApprovalStatus.pending,
    this.proposedChange = const {},
    this.sourceObservationId,
    DateTime? createdAt,
    this.reviewedAt,
    this.reviewNote,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'status': status.name,
        'proposedChange': proposedChange,
        'sourceObservationId': sourceObservationId,
        'createdAt': createdAt.toIso8601String(),
        'reviewedAt': reviewedAt?.toIso8601String(),
        'reviewNote': reviewNote,
      };

  factory DreamRecommendation.fromJson(Map<String, dynamic> json) =>
      DreamRecommendation(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        type: RecommendationType.values.byName(json['type'] as String),
        status: ApprovalStatus.values.byName(json['status'] as String),
        proposedChange: json['proposedChange'] as Map<String, dynamic>? ?? {},
        sourceObservationId: json['sourceObservationId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        reviewedAt: json['reviewedAt'] != null
            ? DateTime.parse(json['reviewedAt'] as String)
            : null,
        reviewNote: json['reviewNote'] as String?,
      );
}

/// Complete report from a dream cycle
class DreamReport {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  final DreamCapability capability;
  final List<DreamObservation> observations;
  final List<DreamRecommendation> recommendations;
  DreamStatus status;
  String? interruptReason;

  DreamReport({
    required this.id,
    required this.capability,
    DateTime? startTime,
    this.endTime,
    List<DreamObservation>? observations,
    List<DreamRecommendation>? recommendations,
    this.status = DreamStatus.running,
    this.interruptReason,
  })  : startTime = startTime ?? DateTime.now(),
        observations = observations ?? [],
        recommendations = recommendations ?? [];

  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  int get observationCount => observations.length;
  int get pendingRecommendations =>
      recommendations.where((r) => r.status == ApprovalStatus.pending).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'capability': capability.name,
        'observations': observations.map((o) => o.toJson()).toList(),
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
        'status': status.name,
        'interruptReason': interruptReason,
      };

  factory DreamReport.fromJson(Map<String, dynamic> json) => DreamReport(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        capability: DreamCapability.values.byName(json['capability'] as String),
        observations: (json['observations'] as List<dynamic>?)
                ?.map(
                    (o) => DreamObservation.fromJson(o as Map<String, dynamic>))
                .toList() ??
            [],
        recommendations: (json['recommendations'] as List<dynamic>?)
                ?.map((r) =>
                    DreamRecommendation.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
        status: DreamStatus.values.byName(json['status'] as String),
        interruptReason: json['interruptReason'] as String?,
      );

  @override
  String toString() {
    return 'DreamReport(${capability.name}, ${observations.length} observations, '
        '${recommendations.length} recommendations, status: ${status.name})';
  }
}

/// Complete dream session containing multiple capability reports
class DreamSession {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  final List<DreamReport> reports;
  DreamStatus status;

  DreamSession({
    required this.id,
    DateTime? startTime,
    this.endTime,
    List<DreamReport>? reports,
    this.status = DreamStatus.running,
  })  : startTime = startTime ?? DateTime.now(),
        reports = reports ?? [];

  int get totalObservations =>
      reports.fold(0, (sum, r) => sum + r.observationCount);
  int get totalPendingRecommendations =>
      reports.fold(0, (sum, r) => sum + r.pendingRecommendations);

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'reports': reports.map((r) => r.toJson()).toList(),
        'status': status.name,
      };

  factory DreamSession.fromJson(Map<String, dynamic> json) => DreamSession(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        reports: (json['reports'] as List<dynamic>?)
                ?.map((r) => DreamReport.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
        status: DreamStatus.values.byName(json['status'] as String),
      );
}
