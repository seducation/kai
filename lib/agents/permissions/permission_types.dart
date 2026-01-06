/// Permission types for the storage access control system.
library;

/// These define what actions can be performed on a resource.

/// Types of permissions that can be granted.
enum PermissionType {
  /// Can read files from the resource
  read,

  /// Can write/create files in the resource
  write,

  /// Can delete files from the resource (separate from write for safety)
  delete,

  /// Can use data for AI model training/fine-tuning
  train,

  /// Can execute functions in this context
  execute,
}

/// Scope of how a permission applies to paths.
enum PermissionScope {
  /// Permission applies only to the exact path specified
  exact,

  /// Permission applies to the path and all its children (recursive)
  recursive,
}

/// Type of entity receiving the permission.
enum GranteeType {
  /// An AI agent (e.g., CodeWriterAgent, WebCrawlerAgent)
  agent,

  /// An AI model (e.g., GPT-4, VisionModel for training access)
  model,
}

/// Result of an access check.
enum AccessResult {
  /// Access was granted
  allowed,

  /// Access was denied
  denied,

  /// Permission has expired
  expired,
}

extension PermissionTypeExtension on PermissionType {
  String get displayName {
    switch (this) {
      case PermissionType.read:
        return 'Read';
      case PermissionType.write:
        return 'Write';
      case PermissionType.delete:
        return 'Delete';
      case PermissionType.train:
        return 'Train';
      case PermissionType.execute:
        return 'Execute';
    }
  }

  String get icon {
    switch (this) {
      case PermissionType.read:
        return '📖';
      case PermissionType.write:
        return '✏️';
      case PermissionType.delete:
        return '🗑️';
      case PermissionType.train:
        return '🧠';
      case PermissionType.execute:
        return '⚡';
    }
  }
}
