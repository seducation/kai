import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Tracks dataset lineage and model training history.
///
/// This provides a complete audit trail of:
/// - Which datasets were used to train which models
/// - What capabilities each model has
/// - Version history (old vs new models)
/// - Training date, duration, and outcome
class DatasetLineageTracker {
  // Singleton
  static final DatasetLineageTracker _instance =
      DatasetLineageTracker._internal();
  factory DatasetLineageTracker() => _instance;
  DatasetLineageTracker._internal();

  final List<TrainingRecord> _trainingHistory = [];
  final Map<String, ModelCapabilityProfile> _modelProfiles = {};
  final Map<String, DatasetMetadata> _datasets = {};

  String? _storagePath;
  bool _initialized = false;

  /// Initialize tracker
  Future<void> initialize() async {
    if (_initialized) return;

    final docsDir = await getApplicationDocumentsDirectory();
    _storagePath = p.join(docsDir.path, 'lineage');

    final dir = Directory(_storagePath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await _load();
    _initialized = true;
  }

  // ============================================================
  // DATASET REGISTRATION
  // ============================================================

  /// Register a dataset
  void registerDataset(DatasetMetadata dataset) {
    _datasets[dataset.id] = dataset;
    _save();
  }

  /// Get dataset by ID
  DatasetMetadata? getDataset(String id) => _datasets[id];

  /// Get all datasets
  List<DatasetMetadata> get allDatasets => _datasets.values.toList();

  // ============================================================
  // MODEL REGISTRATION
  // ============================================================

  /// Register a model with capabilities
  void registerModel(ModelCapabilityProfile profile) {
    _modelProfiles[profile.modelId] = profile;
    _save();
  }

  /// Get model profile
  ModelCapabilityProfile? getModelProfile(String modelId) =>
      _modelProfiles[modelId];

  /// Get all models
  List<ModelCapabilityProfile> get allModels => _modelProfiles.values.toList();

  /// Get models that can perform a specific task
  List<ModelCapabilityProfile> modelsForTask(String taskType) {
    return _modelProfiles.values
        .where((m) => m.capabilities.contains(taskType))
        .toList();
  }

  // ============================================================
  // TRAINING LINEAGE
  // ============================================================

  /// Record a training event
  Future<TrainingRecord> recordTraining({
    required String modelId,
    required String modelVersion,
    required List<String> datasetIds,
    required TrainingOutcome outcome,
    required Duration duration,
    Map<String, dynamic>? hyperparameters,
    Map<String, double>? metrics,
    String? notes,
  }) async {
    final record = TrainingRecord(
      modelId: modelId,
      modelVersion: modelVersion,
      datasetIds: datasetIds,
      outcome: outcome,
      duration: duration,
      hyperparameters: hyperparameters,
      metrics: metrics,
      notes: notes,
    );

    _trainingHistory.add(record);

    // Update model profile
    final profile = _modelProfiles[modelId];
    if (profile != null) {
      profile.trainingHistory.add(record.id);
      profile.lastTrainedAt = record.timestamp;
      if (outcome == TrainingOutcome.success) {
        profile.currentVersion = modelVersion;
      }
    }

    await _save();
    return record;
  }

  /// Get training history for a model
  List<TrainingRecord> getTrainingHistoryForModel(String modelId) {
    return _trainingHistory.where((r) => r.modelId == modelId).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Get training history for a dataset
  List<TrainingRecord> getTrainingHistoryForDataset(String datasetId) {
    return _trainingHistory
        .where((r) => r.datasetIds.contains(datasetId))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Get dataset lineage for a model version
  DatasetLineage getLineageForModel(String modelId, String version) {
    final records = _trainingHistory
        .where((r) => r.modelId == modelId && r.modelVersion == version)
        .toList();

    final datasetIds = <String>{};
    for (final record in records) {
      datasetIds.addAll(record.datasetIds);
    }

    final datasets = datasetIds
        .map((id) => _datasets[id])
        .whereType<DatasetMetadata>()
        .toList();

    return DatasetLineage(
      modelId: modelId,
      modelVersion: version,
      datasets: datasets,
      trainingRecords: records,
    );
  }

  /// Compare old vs new model capabilities
  ModelComparison compareModels(
      String modelId, String oldVersion, String newVersion) {
    final oldRecords = _trainingHistory
        .where((r) => r.modelId == modelId && r.modelVersion == oldVersion)
        .toList();
    final newRecords = _trainingHistory
        .where((r) => r.modelId == modelId && r.modelVersion == newVersion)
        .toList();

    final oldDatasets = <String>{};
    final newDatasets = <String>{};

    for (final r in oldRecords) {
      oldDatasets.addAll(r.datasetIds);
    }
    for (final r in newRecords) {
      newDatasets.addAll(r.datasetIds);
    }

    return ModelComparison(
      modelId: modelId,
      oldVersion: oldVersion,
      newVersion: newVersion,
      addedDatasets: newDatasets.difference(oldDatasets).toList(),
      removedDatasets: oldDatasets.difference(newDatasets).toList(),
      sharedDatasets: oldDatasets.intersection(newDatasets).toList(),
      oldMetrics: oldRecords.lastOrNull?.metrics ?? {},
      newMetrics: newRecords.lastOrNull?.metrics ?? {},
    );
  }

  /// Get full training audit log
  List<TrainingRecord> get trainingAuditLog =>
      List.unmodifiable(_trainingHistory);

  // ============================================================
  // PERSISTENCE
  // ============================================================

  Future<void> _load() async {
    final file = File(p.join(_storagePath!, 'lineage_data.json'));
    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      _trainingHistory.clear();
      _modelProfiles.clear();
      _datasets.clear();

      if (data['trainingHistory'] != null) {
        for (final json in data['trainingHistory']) {
          _trainingHistory.add(TrainingRecord.fromJson(json));
        }
      }

      if (data['modelProfiles'] != null) {
        (data['modelProfiles'] as Map<String, dynamic>).forEach((k, v) {
          _modelProfiles[k] = ModelCapabilityProfile.fromJson(v);
        });
      }

      if (data['datasets'] != null) {
        (data['datasets'] as Map<String, dynamic>).forEach((k, v) {
          _datasets[k] = DatasetMetadata.fromJson(v);
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_storagePath == null) return;

    final file = File(p.join(_storagePath!, 'lineage_data.json'));
    final data = {
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'trainingHistory': _trainingHistory.map((r) => r.toJson()).toList(),
      'modelProfiles': _modelProfiles.map((k, v) => MapEntry(k, v.toJson())),
      'datasets': _datasets.map((k, v) => MapEntry(k, v.toJson())),
    };
    await file.writeAsString(jsonEncode(data));
  }
}

/// Outcome of a training run
enum TrainingOutcome {
  success,
  failed,
  partial,
  cancelled,
}

/// Record of a single training event
class TrainingRecord {
  final String id;
  final String modelId;
  final String modelVersion;
  final List<String> datasetIds;
  final TrainingOutcome outcome;
  final DateTime timestamp;
  final Duration duration;
  final Map<String, dynamic>? hyperparameters;
  final Map<String, double>? metrics;
  final String? notes;

  TrainingRecord({
    String? id,
    required this.modelId,
    required this.modelVersion,
    required this.datasetIds,
    required this.outcome,
    DateTime? timestamp,
    required this.duration,
    this.hyperparameters,
    this.metrics,
    this.notes,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'modelId': modelId,
        'modelVersion': modelVersion,
        'datasetIds': datasetIds,
        'outcome': outcome.index,
        'timestamp': timestamp.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'hyperparameters': hyperparameters,
        'metrics': metrics,
        'notes': notes,
      };

  factory TrainingRecord.fromJson(Map<String, dynamic> json) => TrainingRecord(
        id: json['id'],
        modelId: json['modelId'],
        modelVersion: json['modelVersion'],
        datasetIds: List<String>.from(json['datasetIds']),
        outcome: TrainingOutcome.values[json['outcome']],
        timestamp: DateTime.parse(json['timestamp']),
        duration: Duration(milliseconds: json['durationMs']),
        hyperparameters: json['hyperparameters'],
        metrics: json['metrics']?.map<String, double>(
            (k, v) => MapEntry(k as String, (v as num).toDouble())),
        notes: json['notes'],
      );
}

/// Metadata about a dataset
class DatasetMetadata {
  final String id;
  final String name;
  final String path;
  final DatasetType type;
  final int sampleCount;
  final DateTime createdAt;
  final String? description;
  final Map<String, dynamic>? schema;
  final List<String> tags;

  DatasetMetadata({
    String? id,
    required this.name,
    required this.path,
    required this.type,
    required this.sampleCount,
    DateTime? createdAt,
    this.description,
    this.schema,
    this.tags = const [],
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'type': type.index,
        'sampleCount': sampleCount,
        'createdAt': createdAt.toIso8601String(),
        'description': description,
        'schema': schema,
        'tags': tags,
      };

  factory DatasetMetadata.fromJson(Map<String, dynamic> json) =>
      DatasetMetadata(
        id: json['id'],
        name: json['name'],
        path: json['path'],
        type: DatasetType.values[json['type']],
        sampleCount: json['sampleCount'],
        createdAt: DateTime.parse(json['createdAt']),
        description: json['description'],
        schema: json['schema'],
        tags: List<String>.from(json['tags'] ?? []),
      );
}

/// Types of datasets
enum DatasetType {
  text,
  image,
  audio,
  video,
  structured,
  mixed,
}

/// Model capability profile
class ModelCapabilityProfile {
  final String modelId;
  final String name;
  String currentVersion;
  final List<String> capabilities;
  final List<String> trainingHistory;
  DateTime? lastTrainedAt;
  final ModelType type;

  ModelCapabilityProfile({
    required this.modelId,
    required this.name,
    required this.currentVersion,
    required this.capabilities,
    List<String>? trainingHistory,
    this.lastTrainedAt,
    required this.type,
  }) : trainingHistory = trainingHistory ?? [];

  Map<String, dynamic> toJson() => {
        'modelId': modelId,
        'name': name,
        'currentVersion': currentVersion,
        'capabilities': capabilities,
        'trainingHistory': trainingHistory,
        'lastTrainedAt': lastTrainedAt?.toIso8601String(),
        'type': type.index,
      };

  factory ModelCapabilityProfile.fromJson(Map<String, dynamic> json) =>
      ModelCapabilityProfile(
        modelId: json['modelId'],
        name: json['name'],
        currentVersion: json['currentVersion'],
        capabilities: List<String>.from(json['capabilities']),
        trainingHistory: List<String>.from(json['trainingHistory'] ?? []),
        lastTrainedAt: json['lastTrainedAt'] != null
            ? DateTime.parse(json['lastTrainedAt'])
            : null,
        type: ModelType.values[json['type']],
      );
}

/// Types of AI models
enum ModelType {
  llm,
  vision,
  audio,
  multimodal,
  embedding,
  custom,
}

/// Dataset lineage for a model version
class DatasetLineage {
  final String modelId;
  final String modelVersion;
  final List<DatasetMetadata> datasets;
  final List<TrainingRecord> trainingRecords;

  DatasetLineage({
    required this.modelId,
    required this.modelVersion,
    required this.datasets,
    required this.trainingRecords,
  });

  /// Total samples used in training
  int get totalSamples => datasets.fold(0, (sum, d) => sum + d.sampleCount);

  /// All dataset types used
  Set<DatasetType> get datasetTypes => datasets.map((d) => d.type).toSet();
}

/// Comparison between old and new model versions
class ModelComparison {
  final String modelId;
  final String oldVersion;
  final String newVersion;
  final List<String> addedDatasets;
  final List<String> removedDatasets;
  final List<String> sharedDatasets;
  final Map<String, double> oldMetrics;
  final Map<String, double> newMetrics;

  ModelComparison({
    required this.modelId,
    required this.oldVersion,
    required this.newVersion,
    required this.addedDatasets,
    required this.removedDatasets,
    required this.sharedDatasets,
    required this.oldMetrics,
    required this.newMetrics,
  });

  /// Calculate metric improvements
  Map<String, double> get metricChanges {
    final changes = <String, double>{};
    for (final key in newMetrics.keys) {
      if (oldMetrics.containsKey(key)) {
        changes[key] = newMetrics[key]! - oldMetrics[key]!;
      }
    }
    return changes;
  }
}
