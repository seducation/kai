import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/agent_base.dart';
import '../core/step_schema.dart';
import '../core/step_types.dart';

/// Agent for persistent storage operations.
/// Abstracts storage backend (can use Appwrite, local, etc.)
class StorageAgent extends AgentBase {
  /// In-memory cache for demo
  final Map<String, dynamic> _cache = {};

  /// Root directory for the vault
  Directory? _vaultDir;

  StorageAgent({
    super.logger,
  }) : super(name: 'Storage');

  Future<void> _initVault() async {
    if (_vaultDir != null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    _vaultDir = Directory(p.join(docsDir.path, 'vault'));

    if (!await _vaultDir!.exists()) {
      await _vaultDir!.create(recursive: true);
      logStatus(StepType.check, 'created vault at ${_vaultDir!.path}',
          StepStatus.success);
    }
  }

  File _getFile(String key) {
    // Sanitize key to prevent path traversal
    final safeKey = key.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    // Using simple extension inference or default to .md
    final ext = safeKey.contains('.') ? '' : '.md';
    return File(p.join(_vaultDir!.path, '$safeKey$ext'));
  }

  @override
  Future<R> onRun<R>(dynamic input) async {
    await _initVault();
    if (input is StorageRequest) {
      return await handleRequest(input) as R;
    }
    throw ArgumentError('Expected StorageRequest');
  }

  /// Handle a storage request
  Future<dynamic> handleRequest(StorageRequest request) async {
    switch (request.operation) {
      case StorageOperation.save:
        return await save(request.key, request.value);
      case StorageOperation.load:
        return await load(request.key);
      case StorageOperation.delete:
        return await remove(request.key);
      case StorageOperation.exists:
        return await exists(request.key);
      case StorageOperation.list:
        return await listKeys(request.prefix);
    }
  }

  /// Save a value
  Future<void> save(String key, dynamic value) async {
    // Step 1: Validate key
    await execute<void>(
      action: StepType.check,
      target: 'validating key: $key',
      task: () async {
        if (key.isEmpty) throw ArgumentError('Key cannot be empty');
      },
    );

    // Step 2: Write to disk
    await execute<void>(
      action: StepType.store,
      target: key,
      task: () async {
        final file = _getFile(key);

        String content;
        if (value is String) {
          content = value;
        } else {
          content = value.toString();
        }

        await file.writeAsString(content);

        // Update in-memory cache
        _cache[key] = value;
      },
      metadata: {
        'path': _getFile(key).path,
        'type': value.runtimeType.toString(),
      },
    );
  }

  /// Load a value
  Future<dynamic> load(String key) async {
    // Step 1: Check cache
    if (_cache.containsKey(key)) {
      logStatus(StepType.fetch, 'loaded from cache: $key', StepStatus.success);
      return _cache[key];
    }

    // Step 2: Read from disk
    return await execute<dynamic>(
      action: StepType.fetch,
      target: key,
      task: () async {
        final file = _getFile(key);
        if (!await file.exists()) return null;

        final content = await file.readAsString();
        _cache[key] = content; // Cache it
        return content;
      },
    );
  }

  /// Remove a value
  Future<void> remove(String key) async {
    await execute<void>(
      action: StepType.modify,
      target: 'removing: $key',
      task: () async {
        final file = _getFile(key);
        if (await file.exists()) {
          await file.delete();
        }
        _cache.remove(key);
      },
    );
  }

  /// Check if key exists
  Future<bool> exists(String key) async {
    // Check cache first
    if (_cache.containsKey(key)) return true;

    // Check disk
    return await execute<bool>(
      action: StepType.check,
      target: 'exists: $key',
      task: () async => _getFile(key).exists(),
    );
  }

  /// List keys with prefix
  Future<List<String>> listKeys(String? prefix) async {
    return await execute<List<String>>(
      action: StepType.fetch,
      target: 'listing keys${prefix != null ? " with prefix: $prefix" : ""}',
      task: () async {
        final files = _vaultDir!.listSync();
        final keys =
            files.whereType<File>().map((f) => p.basename(f.path)).toList();

        if (prefix != null) {
          return keys.where((k) => k.startsWith(prefix)).toList();
        }
        return keys;
      },
    );
  }

  /// Clear all cached data
  Future<void> clearAll() async {
    await execute(
        action: StepType.modify,
        target: 'clearing vault',
        task: () async {
          if (_vaultDir!.existsSync()) {
            _vaultDir!.deleteSync(recursive: true);
            _vaultDir!.createSync();
          }
          _cache.clear();
        });
  }
}

/// Storage operations
enum StorageOperation {
  save,
  load,
  delete,
  exists,
  list,
}

/// Request for storage operation
class StorageRequest {
  final StorageOperation operation;
  final String key;
  final dynamic value;
  final String? prefix;

  const StorageRequest({
    required this.operation,
    required this.key,
    this.value,
    this.prefix,
  });

  /// Create a save request
  factory StorageRequest.save(String key, dynamic value) =>
      StorageRequest(operation: StorageOperation.save, key: key, value: value);

  /// Create a load request
  factory StorageRequest.load(String key) =>
      StorageRequest(operation: StorageOperation.load, key: key);

  /// Create a delete request
  factory StorageRequest.delete(String key) =>
      StorageRequest(operation: StorageOperation.delete, key: key);
}
