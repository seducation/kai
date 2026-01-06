/// Barrel export for the permissions module.
library;

/// This module provides:
/// - Permission types and models
/// - Central permission registry
/// - Access gate for enforcement
/// - Training gate for model training validation
/// - Tamper-proof audit logging

export 'permission_types.dart';
export 'permission_entry.dart';
export 'permission_registry.dart';
export 'access_gate.dart';
export 'training_gate.dart';
export 'audit_log.dart';
