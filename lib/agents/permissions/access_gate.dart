import '../core/step_logger.dart';
import '../core/step_types.dart';
import '../core/step_schema.dart';

import 'permission_types.dart';
import 'permission_registry.dart';
import 'audit_log.dart';
import '../services/narrator_service.dart';
import '../services/speech_gate.dart';
import '../rules/rule_definitions.dart';

/// Central enforcement layer for all storage access.
///
/// Every read, write, delete, and train operation MUST go through the AccessGate.
/// All attempts (allowed AND denied) are logged to the audit trail.
class AccessGate {
  // Singleton
  static final AccessGate _instance = AccessGate._internal();
  factory AccessGate() => _instance;
  AccessGate._internal();

  final PermissionRegistry _registry = PermissionRegistry();
  final AuditLog _audit = AuditLog();
  final StepLogger _logger = GlobalStepLogger().logger;

  bool _initialized = false;

  /// Initialize the gate and its dependencies
  Future<void> initialize() async {
    if (_initialized) return;
    await _registry.initialize();
    await _audit.initialize();
    _initialized = true;
  }

  /// Request access to a resource.
  ///
  /// This method:
  /// 1. Checks the permission registry
  /// 2. Logs the attempt to the audit trail
  /// 3. Logs to the step logger for UI visibility
  /// 4. Returns the result
  Future<AccessResult> requestAccess({
    required String requester,
    required GranteeType requesterType,
    required String resourcePath,
    required PermissionType action,
    Map<String, dynamic>? metadata,
  }) async {
    // Ensure initialized
    if (!_initialized) await initialize();

    // Check permission
    bool allowed;
    switch (action) {
      case PermissionType.read:
        allowed = _registry.canRead(requester, resourcePath);
        break;
      case PermissionType.write:
        allowed = _registry.canWrite(requester, resourcePath);
        break;
      case PermissionType.delete:
        allowed = _registry.canDelete(requester, resourcePath);
        break;
      case PermissionType.train:
        allowed = _registry.canTrain(requester, resourcePath);
        break;
      case PermissionType.execute:
        allowed = _registry.canExecute(requester, resourcePath);
        break;
    }

    final result = allowed ? AccessResult.allowed : AccessResult.denied;

    // Record in audit log
    await _audit.record(
      requester: requester,
      requesterType: requesterType,
      resource: resourcePath,
      action: action,
      result: result,
      metadata: metadata,
    );

    // Log to step logger for UI
    _logger.logStep(
      agentName: 'AccessGate',
      action: allowed ? StepType.check : StepType.error,
      target:
          '${action.name.toUpperCase()} access to "$resourcePath" for $requester',
      status: allowed ? StepStatus.success : StepStatus.failed,
      metadata: {
        'requester': requester,
        'resource': resourcePath,
        'action': action.name,
        'allowed': allowed,
      },
    );

    // Safety Alert: If access is denied, trigger reflex speech
    if (!allowed) {
      narrator.speak(
        'Action blocked: ${action.name.toUpperCase()} access to "$resourcePath" for $requester was denied.',
        SpeechIntent.safetyAlert,
        priority: PriorityLevel.reflex,
      );
    }

    return result;
  }

  /// Convenience method for read access
  Future<bool> canRead(String agent, String path) async {
    final result = await requestAccess(
      requester: agent,
      requesterType: GranteeType.agent,
      resourcePath: path,
      action: PermissionType.read,
    );
    return result == AccessResult.allowed;
  }

  /// Convenience method for write access
  Future<bool> canWrite(String agent, String path) async {
    final result = await requestAccess(
      requester: agent,
      requesterType: GranteeType.agent,
      resourcePath: path,
      action: PermissionType.write,
    );
    return result == AccessResult.allowed;
  }

  /// Convenience method for training access
  Future<bool> canTrain(String model, String path) async {
    final result = await requestAccess(
      requester: model,
      requesterType: GranteeType.model,
      resourcePath: path,
      action: PermissionType.train,
    );
    return result == AccessResult.allowed;
  }

  /// Get the audit log for inspection
  AuditLog get auditLog => _audit;

  /// Get the permission registry for management
  PermissionRegistry get registry => _registry;
}

/// Exception thrown when access is denied
class PermissionDeniedException implements Exception {
  final String requester;
  final String resource;
  final PermissionType action;

  PermissionDeniedException({
    required this.requester,
    required this.resource,
    required this.action,
  });

  @override
  String toString() {
    return 'PermissionDeniedException: $requester denied ${action.name} access to $resource';
  }
}
