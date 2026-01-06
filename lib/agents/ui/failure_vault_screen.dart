import 'package:flutter/material.dart';
import '../coordination/execution_manager.dart';
import '../coordination/execution_control_agent.dart';

/// Screen for viewing failure vault and execution history.
///
/// Provides:
/// - Failure vault (like git commits for failed tasks)
/// - Execution history
/// - Replay/Redo controls
class FailureVaultScreen extends StatefulWidget {
  const FailureVaultScreen({super.key});

  @override
  State<FailureVaultScreen> createState() => _FailureVaultScreenState();
}

class _FailureVaultScreenState extends State<FailureVaultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ExecutionManager _manager = ExecutionManager();
  final ExecutionControlAgent _controlAgent = ExecutionControlAgent();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initialize();
  }

  Future<void> _initialize() async {
    await _manager.initialize();
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Execution Vault'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.error_outline), text: 'Failures'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services),
            onPressed: _cleanup,
            tooltip: 'Cleanup old data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFailureVault(),
                _buildHistory(),
              ],
            ),
    );
  }

  Widget _buildFailureVault() {
    final failures = _manager.failureVault;

    if (failures.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: Colors.green[400]),
            const SizedBox(height: 16),
            Text(
              'No failures recorded',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'All tasks completed successfully!',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: failures.length,
      itemBuilder: (context, index) {
        final failure = failures[failures.length - 1 - index]; // Newest first
        return _FailureCard(
          record: failure,
          onRedo: () => _redoTask(failure),
          onDismiss: () => _dismissFailure(failure),
        );
      },
    );
  }

  Widget _buildHistory() {
    final history = _manager.history;

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No execution history',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final record = history[history.length - 1 - index]; // Newest first
        return _HistoryCard(
          record: record,
          onReplay: record.canReplay ? () => _replayTask(record) : null,
        );
      },
    );
  }

  Future<void> _redoTask(ExecutionRecord failure) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redo Failed Task?'),
        content: Text('Retry "${failure.taskName}" with original input?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Redo'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _controlAgent.redo(failure.taskName);
      setState(() {});
    }
  }

  Future<void> _replayTask(ExecutionRecord record) async {
    await _controlAgent.replay(record.taskName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Replaying "${record.taskName}"...')),
    );
  }

  Future<void> _dismissFailure(ExecutionRecord failure) async {
    await _manager.resolveFailure(failure.id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _cleanup() async {
    await _controlAgent.cleanup();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cleanup complete')),
    );
  }
}

class _FailureCard extends StatelessWidget {
  final ExecutionRecord record;
  final VoidCallback onRedo;
  final VoidCallback onDismiss;

  const _FailureCard({
    required this.record,
    required this.onRedo,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.taskName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _formatTime(record.timestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (record.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  record.errorMessage!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.red[900],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${record.steps.length} steps • ${record.duration.inMilliseconds}ms',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onDismiss,
                  child: const Text('Dismiss'),
                ),
                FilledButton.icon(
                  onPressed: onRedo,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Redo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')} ${time.day}/${time.month}';
  }
}

class _HistoryCard extends StatelessWidget {
  final ExecutionRecord record;
  final VoidCallback? onReplay;

  const _HistoryCard({
    required this.record,
    this.onReplay,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = record.result == ExecutionResult.success;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isSuccess ? Icons.check_circle : Icons.cancel,
          color: isSuccess ? Colors.green : Colors.red,
        ),
        title: Text(record.taskName),
        subtitle: Text(
          '${record.steps.length} steps • ${record.duration.inMilliseconds}ms • ${record.mode.name}',
        ),
        trailing: onReplay != null
            ? IconButton(
                icon: const Icon(Icons.replay),
                onPressed: onReplay,
                tooltip: 'Replay',
              )
            : null,
      ),
    );
  }
}
