import 'package:flutter/material.dart';
import '../ai/dataset_lineage.dart';

/// Screen for viewing dataset lineage and training history.
///
/// Provides:
/// - Training Audit Log
/// - Model Lineage (what datasets trained this model)
/// - Dataset History (what usage this dataset had)
/// - Comparison View (old vs new model)
class LineageAuditScreen extends StatefulWidget {
  const LineageAuditScreen({super.key});

  @override
  State<LineageAuditScreen> createState() => _LineageAuditScreenState();
}

class _LineageAuditScreenState extends State<LineageAuditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatasetLineageTracker _tracker = DatasetLineageTracker();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initialize();
  }

  Future<void> _initialize() async {
    await _tracker.initialize();
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧬 Training Audits'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'Audit Log'),
            Tab(icon: Icon(Icons.model_training), text: 'Models'),
            Tab(icon: Icon(Icons.dataset), text: 'Datasets'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_fill),
            onPressed: () => _showTrainingDialog(context),
            tooltip: 'Train New Model',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAuditLog(),
                _buildModelList(),
                _buildDatasetList(),
              ],
            ),
    );
  }

  Widget _buildAuditLog() {
    final logs = _tracker.trainingAuditLog;

    if (logs.isEmpty) {
      return const Center(child: Text('No training records found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final record = logs[logs.length - 1 - index]; // Newest first
        return Card(
          child: ListTile(
            leading: _getOutcomeIcon(record.outcome),
            title: Text('Trained ${record.modelId} v${record.modelVersion}'),
            subtitle: Text(
              '${record.datasetIds.length} datasets • ${_formatDuration(record.duration)}',
            ),
            trailing: Text(
              _formatDate(record.timestamp),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            onTap: () => _showTrainingDetails(record),
          ),
        );
      },
    );
  }

  Widget _buildModelList() {
    final models = _tracker.allModels;

    if (models.isEmpty) {
      return const Center(child: Text('No models registered'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: models.length,
      itemBuilder: (context, index) {
        final model = models[index];
        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.psychology),
            title: Text(model.name),
            subtitle: Text(
                'v${model.currentVersion} • ${model.type.name.toUpperCase()}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Capabilities:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      children: model.capabilities
                          .map((c) => Chip(
                                label: Text(c,
                                    style: const TextStyle(fontSize: 10)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Training History:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._tracker
                        .getTrainingHistoryForModel(model.modelId)
                        .map((r) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: _getOutcomeIcon(r.outcome, size: 16),
                              title: Text('v${r.modelVersion}'),
                              subtitle: Text(_formatDate(r.timestamp)),
                              trailing:
                                  const Icon(Icons.chevron_right, size: 16),
                              onTap: () => _showTrainingDetails(r),
                            )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDatasetList() {
    final datasets = _tracker.allDatasets;

    if (datasets.isEmpty) {
      return const Center(child: Text('No datasets tracked'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: datasets.length,
      itemBuilder: (context, index) {
        final dataset = datasets[index];
        return Card(
          child: ListTile(
            leading: _getDatasetIcon(dataset.type),
            title: Text(dataset.name),
            subtitle: Text('${dataset.sampleCount} samples • Used in matches'),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showDatasetUsage(dataset),
            ),
          ),
        );
      },
    );
  }

  void _showTrainingDetails(TrainingRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  _getOutcomeIcon(record.outcome),
                  const SizedBox(width: 16),
                  Text(
                    'Training Record',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
              const Divider(height: 32),
              _detailRow('Model', '${record.modelId} v${record.modelVersion}'),
              _detailRow('Duration', _formatDuration(record.duration)),
              _detailRow('Date', _formatDate(record.timestamp)),
              _detailRow('Outcome', record.outcome.name.toUpperCase()),
              if (record.notes != null) _detailRow('Notes', record.notes!),
              const SizedBox(height: 24),
              const Text('Datasets Used',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ...record.datasetIds.map((id) {
                final ds = _tracker.getDataset(id);
                return ListTile(
                  leading: _getDatasetIcon(ds?.type ?? DatasetType.mixed),
                  title: Text(ds?.name ?? 'Unknown Dataset ($id)'),
                  subtitle: Text(ds?.path ?? ''),
                );
              }),
              const SizedBox(height: 24),
              const Text('Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (record.metrics != null)
                ...record.metrics!.entries.map((e) => ListTile(
                      dense: true,
                      title: Text(e.key),
                      trailing: Text(e.value.toStringAsFixed(4)),
                    )),
              const SizedBox(height: 24),
              const Text('Hyperparameters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (record.hyperparameters != null)
                ...record.hyperparameters!.entries.map((e) => ListTile(
                      dense: true,
                      title: Text(e.key),
                      trailing: Text(e.value.toString()),
                      contentPadding: EdgeInsets.zero,
                    )),
            ],
          ),
        ),
      ),
    );
  }

  void _showDatasetUsage(DatasetMetadata dataset) {
    final history = _tracker.getTrainingHistoryForDataset(dataset.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dataset.name),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type: ${dataset.type.name}'),
              Text('Samples: ${dataset.sampleCount}'),
              Text('Path: ${dataset.path}'),
              const SizedBox(height: 16),
              const Text('Used to train:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (history.isEmpty)
                const Text('No training usage recorded')
              else
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final r = history[index];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.model_training, size: 16),
                        title: Text('${r.modelId} v${r.modelVersion}'),
                        subtitle: Text(_formatDate(r.timestamp)),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Icon _getOutcomeIcon(TrainingOutcome outcome, {double size = 24}) {
    switch (outcome) {
      case TrainingOutcome.success:
        return Icon(Icons.check_circle, color: Colors.green, size: size);
      case TrainingOutcome.failed:
        return Icon(Icons.error, color: Colors.red, size: size);
      case TrainingOutcome.partial:
        return Icon(Icons.warning, color: Colors.orange, size: size);
      case TrainingOutcome.cancelled:
        return Icon(Icons.cancel, color: Colors.grey, size: size);
    }
  }

  Icon _getDatasetIcon(DatasetType type) {
    switch (type) {
      case DatasetType.text:
        return const Icon(Icons.text_fields);
      case DatasetType.image:
        return const Icon(Icons.image);
      case DatasetType.audio:
        return const Icon(Icons.audiotrack);
      case DatasetType.video:
        return const Icon(Icons.videocam);
      case DatasetType.structured:
        return const Icon(Icons.table_chart);
      case DatasetType.mixed:
        return const Icon(Icons.folder_zip);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    return '${duration.inSeconds}s';
  }

  Future<void> _showTrainingDialog(BuildContext context) async {
    final modelController = TextEditingController();
    final versionController = TextEditingController(text: '1.0.0');
    final selectedDatasets = <String>{};

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Start Training Run'),
          content: SizedBox(
            width: 400,
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model ID',
                    hintText: 'e.g., my-custom-model',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: versionController,
                  decoration: const InputDecoration(
                    labelText: 'Version',
                    hintText: 'e.g., 1.0.0',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Select Datasets:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  width: double.maxFinite,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListView.builder(
                      itemCount: _tracker.allDatasets.length,
                      itemBuilder: (context, index) {
                        final ds = _tracker.allDatasets[index];
                        return CheckboxListTile(
                          title: Text(ds.name),
                          subtitle: Text(ds.type.name),
                          value: selectedDatasets.contains(ds.id),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selectedDatasets.add(ds.id);
                              } else {
                                selectedDatasets.remove(ds.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Training'),
              onPressed: (modelController.text.isEmpty ||
                      selectedDatasets.isEmpty)
                  ? null
                  : () async {
                      Navigator.pop(context);

                      // Simulate training start
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Training started...')),
                      );

                      // In a real app, this would trigger a background job
                      // Here we verify permissions first (using TrainingGate if integrated)

                      await Future.delayed(
                          const Duration(seconds: 2)); // Simulating

                      await _tracker.recordTraining(
                        modelId: modelController.text,
                        modelVersion: versionController.text,
                        datasetIds: selectedDatasets.toList(),
                        outcome: TrainingOutcome.success, // Simulated success
                        duration:
                            const Duration(minutes: 5), // Simulated duration
                        notes: 'Manual run initiator: User',
                      );

                      setState(() {}); // Refresh list
                    },
            ),
          ],
        ),
      ),
    );
  }
}
