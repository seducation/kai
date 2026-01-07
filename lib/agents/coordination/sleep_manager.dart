import 'dart:async';

import 'execution_manager.dart';
import 'dreaming_mode.dart';
import '../storage/taxonomy_registry.dart';

/// Sleep Manager - Optimizes the system when idle.
///
/// Monitors user activity and triggers sleep cycles:
/// - Stage 1 (Light): Cache cleanup
/// - Stage 2 (Deep): Log compaction
/// - Stage 3 (REM): Dreaming Mode - Optimization & Analysis
class SleepManager {
  static final SleepManager _instance = SleepManager._internal();
  factory SleepManager() => _instance;
  SleepManager._internal();

  Timer? _idleTimer;
  final Duration _idleThreshold = const Duration(minutes: 5);
  DateTime _lastActivity = DateTime.now();
  DateTime? _deepSleepStart;

  final StreamController<SleepState> _stateStream =
      StreamController.broadcast();
  Stream<SleepState> get stateStream => _stateStream.stream;

  SleepState _currentState = SleepState.awake;
  SleepState get currentState => _currentState;

  bool _isActive = false;

  // Dreaming Mode integration
  final DreamingMode _dreamingMode = DreamingMode();

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
    // Abort any running dream cycle
    if (_currentState == SleepState.remSleep) {
      _dreamingMode.abort();
    }

    _currentState = SleepState.awake;
    _stateStream.add(_currentState);
    _deepSleepStart = null;
    _resetTimer();
  }

  Future<void> _enterSleep() async {
    if (!_isActive) return;

    // Stage 1: Light Sleep (Cleanup)
    _currentState = SleepState.lightSleep;
    _stateStream.add(_currentState);
    await _performLightCleanup();

    // If still idle after 10min, go to deep sleep
    if (DateTime.now().difference(_lastActivity) >
        const Duration(minutes: 10)) {
      _currentState = SleepState.deepSleep;
      _stateStream.add(_currentState);
      _deepSleepStart = DateTime.now();
      await _performDeepCompaction();

      // Stage 3: REM Sleep (Dreaming Mode)
      // Only enter if conditions are met
      if (_shouldEnterDreamingMode()) {
        await _enterDreamingMode();
      }
    }
  }

  /// Check if conditions are met for dreaming mode
  bool _shouldEnterDreamingMode() {
    // 1. Must still be idle
    if (DateTime.now().difference(_lastActivity) <
        const Duration(minutes: 15)) {
      return false;
    }

    // 2. Must have been in deep sleep for at least 5 minutes
    if (_deepSleepStart == null ||
        DateTime.now().difference(_deepSleepStart!) <
            const Duration(minutes: 5)) {
      return false;
    }

    // 3. System must be active
    if (!_isActive) {
      return false;
    }

    return true;
  }

  Future<void> _enterDreamingMode() async {
    _currentState = SleepState.remSleep;
    _stateStream.add(_currentState);

    try {
      // Run the dream cycle
      await _dreamingMode.runDreamCycle();
    } finally {
      // Return to deep sleep after dreaming (if still idle)
      if (_isActive &&
          DateTime.now().difference(_lastActivity) >
              const Duration(minutes: 5)) {
        _currentState = SleepState.deepSleep;
        _stateStream.add(_currentState);
      }
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
      // Cleanup failed silently
    }
  }

  Future<void> _performDeepCompaction() async {
    try {
      // 1. Compact logs (future)
      // 2. Archive old execution history
    } catch (e) {
      // Compaction failed silently
    }
  }
}

enum SleepState {
  awake,
  lightSleep, // Cache cleanup
  deepSleep, // Log compaction
  remSleep, // Optimization/Training
}
