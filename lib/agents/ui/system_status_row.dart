import 'package:flutter/material.dart';
import '../coordination/autonomic_system.dart';
import '../coordination/sleep_manager.dart';

class SystemStatusRow extends StatelessWidget {
  const SystemStatusRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Health Indicator
        StreamBuilder<SystemHealth>(
          stream: AutonomicSystem().healthStream,
          initialData: AutonomicSystem().currentHealth,
          builder: (context, snapshot) {
            final health = snapshot.data ?? SystemHealth.healthy;
            Color color;
            IconData icon;
            String text;

            switch (health) {
              case SystemHealth.healthy:
                color = Colors.green;
                icon = Icons.favorite;
                text = 'Healthy';
                break;
              case SystemHealth.degraded:
                color = Colors.orange;
                icon = Icons.warning;
                text = 'Degraded';
                break;
              case SystemHealth.critical:
                color = Colors.red;
                icon = Icons.error;
                text = 'Critical';
                break;
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        // Sleep Status
        StreamBuilder<SleepState>(
          stream: SleepManager().stateStream,
          initialData: SleepManager().currentState,
          builder: (context, snapshot) {
            final state = snapshot.data ?? SleepState.awake;
            if (state == SleepState.awake) return const SizedBox();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.nights_stay, size: 16, color: Colors.indigo),
                  const SizedBox(width: 6),
                  Text(
                    state == SleepState.lightSleep
                        ? 'Light Sleep'
                        : state == SleepState.deepSleep
                            ? 'Deep Sleep'
                            : 'Dreaming',
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
