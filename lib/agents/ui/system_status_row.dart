import 'package:flutter/material.dart';
import '../coordination/autonomic_system.dart';
import '../coordination/sleep_manager.dart';
import '../specialized/systems/tone_modulator.dart';

class SystemStatusRow extends StatelessWidget {
  const SystemStatusRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Health Indicator (Neural Style)
        StreamBuilder<SystemHealth>(
          stream: AutonomicSystem().healthStream,
          initialData: AutonomicSystem().currentHealth,
          builder: (context, snapshot) {
            final health = snapshot.data ?? SystemHealth.healthy;

            // Map Health to Tone for consistent aesthetics
            final tone = health == SystemHealth.critical
                ? SystemTone.urgent
                : (health == SystemHealth.degraded
                    ? SystemTone.cautionary
                    : SystemTone.routine);

            final style = ToneModulator().getStyle(tone);
            final color = Color(style.colorHex);

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
                  Text(style.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    health.name.toUpperCase(),
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
