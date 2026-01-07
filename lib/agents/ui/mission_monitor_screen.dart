import 'package:flutter/material.dart';
import 'dart:async';
import '../coordination/mission_controller.dart';
import '../coordination/agent_capability.dart'; // For ConfidenceLevel

/// Screen to monitor active missions and simulations
class MissionMonitorScreen extends StatefulWidget {
  const MissionMonitorScreen({super.key});

  @override
  State<MissionMonitorScreen> createState() => _MissionMonitorScreenState();
}

class _MissionMonitorScreenState extends State<MissionMonitorScreen> {
  Timer? _refreshTimer;
  final MissionController _controller = MissionController();

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final missions = _controller.allMissions;
    final active = _controller.activeMission;

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text('Mission Control'),
        backgroundColor: Colors.black,
        actions: [
          if (active != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: _buildConfidenceBadge(active.confidencePercent),
              ),
            ),
        ],
      ),
      body: missions.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                if (active != null) _buildActiveMissionCard(active),
                Expanded(
                  child: ListView.builder(
                    itemCount: missions.length,
                    itemBuilder: (context, index) {
                      final mission = missions[index];
                      if (mission.id == active?.id)
                        return const SizedBox.shrink(); // Skip active
                      return _buildMissionTile(mission);
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Show create mission dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Mission creation dialog not implemented yet')),
          );
        },
        icon: const Icon(Icons.add_task),
        label: const Text('New Mission'),
        backgroundColor: Colors.cyanAccent,
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildActiveMissionCard(Mission mission) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.2),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CURRENT MISSION',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 12,
                ),
              ),
              _buildStatusBadge(mission.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mission.objective,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildProgressBar('Progress', mission.progressPercent, Colors.green),
          const SizedBox(height: 8),
          _buildProgressBar('Confidence', mission.confidencePercent,
              _getConfidenceColor(mission.confidencePercent)),
          const SizedBox(height: 16),
          _buildSectionTitle('Constraints'),
          ...mission.constraints
              .map((c) => _buildBullet(c, Colors.orangeAccent)),
          const SizedBox(height: 8),
          _buildSectionTitle('Success Criteria'),
          ...mission.successCriteria.map((c) {
            final isDone = mission.completedCriteria.contains(c);
            return _buildCheckbox(c, isDone);
          }),
        ],
      ),
    );
  }

  Widget _buildMissionTile(Mission mission) {
    return ListTile(
      title:
          Text(mission.objective, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        '${mission.status.name.toUpperCase()} • ${mission.progressPercent.toStringAsFixed(0)}%',
        style: TextStyle(color: Colors.white70),
      ),
      trailing: _buildStatusBadge(mission.status),
      onTap: () {
        // TODO: Show mission details
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.rocket_launch, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            'No Active Missions',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(double confidence) {
    final color = _getConfidenceColor(confidence);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${(confidence).toStringAsFixed(0)}% CONFIDENCE',
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildStatusBadge(MissionStatus status) {
    Color color;
    switch (status) {
      case MissionStatus.active:
        color = Colors.green;
        break;
      case MissionStatus.planning:
        color = Colors.blue;
        break;
      case MissionStatus.paused:
        color = Colors.orange;
        break;
      case MissionStatus.completed:
        color = Colors.cyan;
        break;
      case MissionStatus.failed:
        color = Colors.red;
        break;
      case MissionStatus.aborted:
        color = Colors.grey;
        break;
      case MissionStatus.monitoring:
        color = Colors.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.name.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProgressBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text('${value.toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value / 100,
          backgroundColor: Colors.white12,
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildBullet(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  Widget _buildCheckbox(String text, bool checked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: checked ? Colors.greenAccent : Colors.white30,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: checked ? Colors.white : Colors.white54,
                decoration: checked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 80) return Colors.greenAccent;
    if (confidence >= 60) return Colors.yellowAccent;
    if (confidence >= 40) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}
