import 'package:flutter/material.dart';
import '../storage/taxonomy_model.dart';
import '../storage/taxonomy_registry.dart';

/// Screen for managing storage zones (vaults).
class ZoneSettingsScreen extends StatefulWidget {
  const ZoneSettingsScreen({super.key});

  @override
  State<ZoneSettingsScreen> createState() => _ZoneSettingsScreenState();
}

class _ZoneSettingsScreenState extends State<ZoneSettingsScreen> {
  final TaxonomyRegistry _registry = TaxonomyRegistry();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _registry.initialize();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗄️ Storage Zones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddZoneDialog(context),
            tooltip: 'Add Zone',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildZoneList(),
    );
  }

  Widget _buildZoneList() {
    final zones = _registry.allZones;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // System Zones Section
        _buildSectionHeader('System Zones', Icons.lock_outline),
        ...zones.where((z) => z.isSystem).map((z) => _ZoneCard(
              zone: z,
              onTap: () => _showZoneInfo(context, z),
            )),

        const SizedBox(height: 24),

        // Custom Zones Section
        _buildSectionHeader('Custom Zones', Icons.folder_special),
        ...zones.where((z) => !z.isSystem).map((z) => _ZoneCard(
              zone: z,
              onTap: () => _showZoneInfo(context, z),
              onDelete: () => _deleteZone(z.id),
            )),

        if (zones.where((z) => !z.isSystem).isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.create_new_folder,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No custom zones yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddZoneDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Zone'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddZoneDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    StorageZoneType selectedType = StorageZoneType.custom;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Storage Zone'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Zone Name',
                    hintText: 'e.g., research, projects, exports',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<StorageZoneType>(
                  // initialValue sets the initial state, value is deprecated for FormField
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Zone Type',
                    border: OutlineInputBorder(),
                  ),
                  items: StorageZoneType.values
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Text(type.icon),
                                const SizedBox(width: 8),
                                Text(type.displayName),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedType = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: nameController.text.isEmpty
                  ? null
                  : () async {
                      await _registry.addZone(
                        name: nameController.text.trim(),
                        type: selectedType,
                        description: descController.text.isEmpty
                            ? null
                            : descController.text,
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context, true);
                    },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() {});
    }
  }

  void _showZoneInfo(BuildContext context, StorageZone zone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(zone.icon),
            const SizedBox(width: 8),
            Text(zone.name),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Path', zone.path),
            _infoRow('Type', zone.type.displayName),
            if (zone.description != null)
              _infoRow('Description', zone.description!),
            if (zone.ttl != null) _infoRow('TTL', '${zone.ttl!.inHours} hours'),
            _infoRow('System', zone.isSystem ? 'Yes' : 'No'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _deleteZone(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Zone?'),
        content: const Text(
            'This will remove the zone from the taxonomy. Files will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _registry.removeZone(id);
      setState(() {});
    }
  }
}

class _ZoneCard extends StatelessWidget {
  final StorageZone zone;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ZoneCard({
    required this.zone,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(zone.icon, style: const TextStyle(fontSize: 24)),
        title: Text(zone.name),
        subtitle: Text(
          zone.description ?? zone.type.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getTypeColor(zone.type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                zone.type.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: _getTypeColor(zone.type),
                ),
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
                color: Colors.red[400],
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Color _getTypeColor(StorageZoneType type) {
    switch (type) {
      case StorageZoneType.temporary:
        return Colors.orange;
      case StorageZoneType.agentOwned:
        return Colors.blue;
      case StorageZoneType.permanent:
        return Colors.green;
      case StorageZoneType.cache:
        return Colors.grey;
      case StorageZoneType.custom:
        return Colors.purple;
    }
  }
}
