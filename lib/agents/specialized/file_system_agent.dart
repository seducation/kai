import 'dart:io';
import '../core/agent_base.dart';
import '../core/step_types.dart';

/// Agent for file system operations.
/// Works like an IDE - can read, write, delete any file type.
class FileSystemAgent extends AgentBase {
  /// Root directory (for sandboxing)
  final String? rootPath;

  FileSystemAgent({
    this.rootPath,
    super.logger,
  }) : super(name: 'FileSystem');

  @override
  Future<R> onRun<R>(dynamic input) async {
    if (input is FileRequest) {
      return await handleRequest(input) as R;
    }
    throw ArgumentError('Expected FileRequest');
  }

  /// Handle a file request
  Future<dynamic> handleRequest(FileRequest request) async {
    switch (request.operation) {
      case FileOperation.read:
        return await read(request.path);
      case FileOperation.write:
        return await write(request.path, request.content ?? '');
      case FileOperation.delete:
        return await delete(request.path);
      case FileOperation.list:
        return await list(request.path);
      case FileOperation.exists:
        return await exists(request.path);
      case FileOperation.mkdir:
        return await createDirectory(request.path);
    }
  }

  /// Read file contents
  Future<String> read(String path) async {
    final resolvedPath = _resolvePath(path);

    // Step 1: Check if file exists
    final fileExists = await execute<bool>(
      action: StepType.check,
      target: 'file exists: $path',
      task: () async => File(resolvedPath).existsSync(),
    );

    if (!fileExists) {
      throw FileSystemException('File not found', path);
    }

    // Step 2: Read the file
    final content = await execute<String>(
      action: StepType.fetch,
      target: path,
      task: () async => await File(resolvedPath).readAsString(),
      metadata: {'size': File(resolvedPath).lengthSync()},
    );

    return content;
  }

  /// Write content to file
  Future<void> write(String path, String content) async {
    final resolvedPath = _resolvePath(path);

    // Step 1: Check parent directory
    final parentExists = await execute<bool>(
      action: StepType.check,
      target: 'parent directory exists',
      task: () async {
        final parent = File(resolvedPath).parent;
        return parent.existsSync();
      },
    );

    // Step 2: Create parent if needed
    if (!parentExists) {
      await execute<void>(
        action: StepType.modify,
        target: 'creating parent directories',
        task: () async {
          await File(resolvedPath).parent.create(recursive: true);
        },
      );
    }

    // Step 3: Write the file
    await execute<void>(
      action: StepType.store,
      target: path,
      task: () async {
        await File(resolvedPath).writeAsString(content);
      },
      metadata: {'bytes': content.length},
    );
  }

  /// Delete a file
  Future<void> delete(String path) async {
    final resolvedPath = _resolvePath(path);

    // Step 1: Check existence
    final exists = await execute<bool>(
      action: StepType.check,
      target: 'file exists for deletion: $path',
      task: () async => File(resolvedPath).existsSync(),
    );

    if (!exists) {
      throw FileSystemException('File not found', path);
    }

    // Step 2: Delete
    await execute<void>(
      action: StepType.modify,
      target: 'deleting: $path',
      task: () async {
        await File(resolvedPath).delete();
      },
    );
  }

  /// List directory contents
  Future<List<FileEntry>> list(String path) async {
    final resolvedPath = _resolvePath(path);

    // Step 1: Check directory exists
    final dirExists = await execute<bool>(
      action: StepType.check,
      target: 'directory exists: $path',
      task: () async => Directory(resolvedPath).existsSync(),
    );

    if (!dirExists) {
      throw FileSystemException('Directory not found', path);
    }

    // Step 2: List contents
    final entries = await execute<List<FileEntry>>(
      action: StepType.fetch,
      target: 'listing: $path',
      task: () async {
        final dir = Directory(resolvedPath);
        final list = <FileEntry>[];

        await for (final entity in dir.list()) {
          list.add(FileEntry(
            path: entity.path,
            name: entity.uri.pathSegments.last,
            isDirectory: entity is Directory,
            size: entity is File ? entity.lengthSync() : 0,
          ));
        }

        return list;
      },
    );

    return entries;
  }

  /// Check if file/directory exists
  Future<bool> exists(String path) async {
    final resolvedPath = _resolvePath(path);

    return await execute<bool>(
      action: StepType.check,
      target: 'exists: $path',
      task: () async {
        return File(resolvedPath).existsSync() ||
            Directory(resolvedPath).existsSync();
      },
    );
  }

  /// Create directory
  Future<void> createDirectory(String path) async {
    final resolvedPath = _resolvePath(path);

    await execute<void>(
      action: StepType.modify,
      target: 'creating directory: $path',
      task: () async {
        await Directory(resolvedPath).create(recursive: true);
      },
    );
  }

  /// Resolve path with optional sandboxing
  String _resolvePath(String path) {
    if (rootPath == null) return path;

    // Prevent path traversal
    final normalized = path.replaceAll('..', '');
    return '$rootPath/$normalized';
  }
}

/// File operations
enum FileOperation {
  read,
  write,
  delete,
  list,
  exists,
  mkdir,
}

/// Request for file operation
class FileRequest {
  final FileOperation operation;
  final String path;
  final String? content;

  const FileRequest({
    required this.operation,
    required this.path,
    this.content,
  });

  /// Create a read request
  factory FileRequest.read(String path) =>
      FileRequest(operation: FileOperation.read, path: path);

  /// Create a write request
  factory FileRequest.write(String path, String content) =>
      FileRequest(operation: FileOperation.write, path: path, content: content);

  /// Create a delete request
  factory FileRequest.delete(String path) =>
      FileRequest(operation: FileOperation.delete, path: path);

  /// Create a list request
  factory FileRequest.list(String path) =>
      FileRequest(operation: FileOperation.list, path: path);
}

/// Entry in a directory listing
class FileEntry {
  final String path;
  final String name;
  final bool isDirectory;
  final int size;

  const FileEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'isDirectory': isDirectory,
        'size': size,
      };
}
