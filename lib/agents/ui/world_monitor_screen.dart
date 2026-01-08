import 'package:flutter/material.dart';
import '../world/world_state.dart';

class WorldMonitorScreen extends StatefulWidget {
  const WorldMonitorScreen({super.key});

  @override
  State<WorldMonitorScreen> createState() => _WorldMonitorScreenState();
}

class _WorldMonitorScreenState extends State<WorldMonitorScreen> {
  final VirtualWorld _world = VirtualWorld();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('🌍 World Monitor'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: StreamBuilder<WorldEvent>(
        stream: _world.events,
        builder: (context, snapshot) {
          final entities = _world.entities;

          return Column(
            children: [
              // 1. Stats Header
              _buildStatsRow(entities.length),

              const Divider(color: Color(0xFF334155)),

              // 2. Visualization (Sandbox View)
              Expanded(
                flex: 2,
                child: _buildSandboxView(entities),
              ),

              const Divider(color: Color(0xFF334155)),

              // 3. Entity List
              Expanded(
                flex: 3,
                child: ListView.builder(
                  itemCount: entities.length,
                  itemBuilder: (context, index) {
                    final entity = entities[index];
                    return ListTile(
                      leading: _getEntityIcon(entity.type),
                      title: Text(
                        entity.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${entity.type.name} • (${entity.x.toStringAsFixed(2)}, ${entity.y.toStringAsFixed(2)})',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.redAccent, size: 20),
                        onPressed: () {
                          _world.removeEntity(entity.id);
                        },
                      ),
                    );
                  },
                ),
              ),

              // 4. Manual Controls (Debug)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _addRandomEntity,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Test Entity'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _world.clear(),
                      icon: const Icon(Icons.cleaning_services),
                      label: const Text('Clear World'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(int count) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatCard(label: 'Entities', value: '$count', icon: Icons.token),
          _StatCard(
              label: 'Events', value: 'Live', icon: Icons.notifications_active),
        ],
      ),
    );
  }

  Widget _buildSandboxView(List<WorldEntity> entities) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Grid background
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _GridPainter(),
                ),

                // Entities
                ...entities.map((e) => Positioned(
                      left: e.x * constraints.maxWidth - 12, // Center 24px icon
                      top: e.y * constraints.maxHeight - 12,
                      child: Tooltip(
                        message: e.name,
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _getEntityColor(e.type),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: _getEntityColor(e.type).withAlpha(100),
                                  blurRadius: 8),
                            ],
                          ),
                          child: Icon(
                            _getEntityIconData(e.type),
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  void _addRandomEntity() {
    // Add a dummy entity for testing
    final types = EntityType.values;
    final type = types[DateTime.now().millisecond % types.length];

    _world.addEntity(WorldEntity(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Test ${type.name} ${DateTime.now().second}',
      type: type,
      x: (DateTime.now().millisecond % 100) / 100.0,
      y: (DateTime.now().microsecond % 100) / 100.0,
    ));
  }

  Icon _getEntityIcon(EntityType type) {
    return Icon(_getEntityIconData(type), color: _getEntityColor(type));
  }

  IconData _getEntityIconData(EntityType type) {
    switch (type) {
      case EntityType.project:
        return Icons.folder;
      case EntityType.file:
        return Icons.insert_drive_file;
      case EntityType.bug:
        return Icons.bug_report;
      case EntityType.user:
        return Icons.person;
      case EntityType.agent:
        return Icons.support_agent;
      case EntityType.other:
        return Icons.help_outline;
    }
  }

  Color _getEntityColor(EntityType type) {
    switch (type) {
      case EntityType.project:
        return Colors.blue;
      case EntityType.file:
        return Colors.grey;
      case EntityType.bug:
        return Colors.red;
      case EntityType.user:
        return Colors.green;
      case EntityType.agent:
        return Colors.purple;
      case EntityType.other:
        return Colors.orange;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[400], size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(10)
      ..strokeWidth = 1;

    // Vertical lines
    for (double x = 0; x <= size.width; x += size.width / 10) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y <= size.height; y += size.height / 10) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
