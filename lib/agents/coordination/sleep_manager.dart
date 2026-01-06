import 'dart:async';

import 'execution_manager.dart';
import '../storage/taxonomy_registry.dart';

/// Sleep Manager - Optimizes the system when idle.
///
/// Monitors user activity and triggers sleep cycles:
/// - Stage 1 (Light): Cache cleanup
/// - Stage 2 (Deep): Log compaction
/// - Stage 3 (REM): Optimization (future)
class SleepManager {
  static final SleepManager _instance = SleepManager._internal();
  factory SleepManager() => _instance;
  SleepManager._internal();

  Timer? _idleTimer;
  final Duration _idleThreshold = const Duration(minutes: 5);
  DateTime _lastActivity = DateTime.now();

  final StreamController<SleepState> _stateStream =
      StreamController.broadcast();
  Stream<SleepState> get stateStream => _stateStream.stream;

  SleepState _currentState = SleepState.awake;
  SleepState get currentState => _currentState;

  bool _isActive = false;

  /// Start monitoring
  void start() {
    if (_isActive) return;
    _isActive = true;
    _resetTimer();
  }

  /// Register user activity (mouse, keyboard, request)
  void notifyActivity() {
    _lastActivity = DateTime.now();

    if (_currentState != SleepState.awake) {
      _wakeUp();
    } else {
      _resetTimer();
    }
  }

  void _resetTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleThreshold, _enterSleep);
  }

  void _wakeUp() {
    print('[SleepManager] Waking up!');
    _currentState = SleepState.awake;
    _stateStream.add(_currentState);
    _resetTimer();
  }

  Future<void> _enterSleep() async {
    if (!_isActive) return;

    print('[SleepManager] Entering Sleep Mode...');

    // Stage 1: Light Sleep (Cleanup)
    _currentState = SleepState.lightSleep;
    _stateStream.add(_currentState);
    await _performLightCleanup();

    // If still idle, go deeper
    if (DateTime.now().difference(_lastActivity) >
        const Duration(minutes: 10)) {
      _currentState = SleepState.deepSleep;
      _stateStream.add(_currentState);
      await _performDeepCompaction();
    }
  }

  Future<void> _performLightCleanup() async {
    try {
      // 1. Clear temp storage
      TaxonomyRegistry();
      // Implementation pending: registry.clearZone('temporary');

      // 2. Clear old cache
      ExecutionManager();
      // Compact runtime memory if needed
    } catch (e) {
      print('[SleepManager] Cleanup failed: $e');
    }
  }

  Future<void> _performDeepCompaction() async {
    try {
      // 1. Compact logs (future)
      // 2. Archive old execution history
    } catch (e) {
      print('[SleepManager] Compaction failed: $e');
    }
  }
}

enum SleepState {
  awake,
  lightSleep, // Cache cleanup
  deepSleep, // Log compaction
  remSleep, // Optimization/Training
}
