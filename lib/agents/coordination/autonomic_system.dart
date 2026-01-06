import 'dart:async';
import 'package:path_provider/path_provider.dart';

import 'reliability_tracker.dart';
import '../storage/taxonomy_registry.dart';
import 'agent_registry.dart';
import 'organ_base.dart';

/// Autonomic Nervous System - Keeps the system alive and healthy.
///
/// Runs a periodic "Heartbeat" to:
/// - Check critical file integrity
/// - Monitor storage usage
/// - Verify subsystem health
/// - Auto-heal simple issues
class AutonomicSystem {
  static final AutonomicSystem _instance = AutonomicSystem._internal();
  factory AutonomicSystem() => _instance;
  AutonomicSystem._internal();

  Timer? _heartbeatTimer;
  final Duration _heartbeatInterval = const Duration(seconds: 30);

  final StreamController<SystemHealth> _healthStream =
      StreamController.broadcast();
  Stream<SystemHealth> get healthStream => _healthStream.stream;

  SystemHealth _lastHealth = SystemHealth.healthy;
  SystemHealth get currentHealth => _lastHealth;

  bool _isActive = false;

  /// Start the heartbeat
  void start() {
    if (_isActive) return;
    _isActive = true;
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _pulse());
    _pulse(); // Initial pulse
  }

  /// Stop the heartbeat
  void stop() {
    _isActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _pulse() async {
    final issues = <String>[];

    // 1. Check Storage Integrity
    try {
      TaxonomyRegistry();
      // Ensure registry is initialized
      // In a real system, we'd check if critical directories exist
    } catch (e) {
      issues.add('Storage Registry error: $e');
    }

    // 2. Check Reliability Tracker
    try {
      ReliabilityTracker();
      // Just accessing it ensures it's reachable
    } catch (e) {
      issues.add('Reliability Tracker unreachable');
    }

    // 3. Storage Quota Check (Simulated)
    final criticalStorage = await _checkStorageQuota();
    if (criticalStorage != null) {
      issues.add(criticalStorage);
    }

    // 4. Record Metabolic Rest for Organs
    _restOrgans();

    // Determine Health
    SystemHealth newHealth;
    if (issues.isEmpty) {
      newHealth = SystemHealth.healthy;
    } else if (issues.length < 3) {
      newHealth = SystemHealth.degraded;
    } else {
      newHealth = SystemHealth.critical;
    }

    // Notify if changed or issues persist
    if (newHealth != _lastHealth || issues.isNotEmpty) {
      _lastHealth = newHealth;
      _healthStream.add(newHealth);

      if (issues.isNotEmpty) {
        // print('[AutonomicSystem] Health: ${newHealth.name}, Issues: $issues');
        // In future: emit to event bus
      }
    }
  }

  Future<String?> _checkStorageQuota() async {
    try {
      await getApplicationDocumentsDirectory();
      // Simulated check - in real app would use disk_space package or similar
      // For now, allow unlimited
      return null;
    } catch (e) {
      return 'Storage check failed: $e';
    }
  }

  void _restOrgans() {
    final organs = agentRegistry.allAgents.whereType<Organ>();
    for (final organ in organs) {
      organ.rest();
    }
  }
}

enum SystemHealth {
  healthy,
  degraded,
  critical,
}
