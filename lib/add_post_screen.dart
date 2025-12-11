import 'dart:convert';
import 'dart:ui';

import 'package:appwrite/appwrite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'appwrite_service.dart';
import 'where_to_post.dart';

// Mimics the functionality of the provided React PostEditor component.
class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  // Editor state
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _codeController = TextEditingController();

  List<PlatformFile> _selectedFiles = [];

  String _codeLang = 'javascript';
  bool _isLoading = false;

  // Simple markdown-style toolbar actions
  void _wrapSelection(String prefix, [String? suffix]) {
    final text = _descriptionController.text;
    final selection = _descriptionController.selection;
    if (!selection.isValid) return;

    final start = selection.start;
    final end = selection.end;
    final selectedText = selection.textInside(text);

    final newText = text.substring(0, start) +
        prefix +
        selectedText +
        (suffix ?? prefix) +
        text.substring(end);

    _descriptionController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: end + prefix.length + (suffix?.length ?? prefix.length)),
    );
  }

  void _insertAtCursor(String content) {
    final text = _descriptionController.text;
    final selection = _descriptionController.selection;
    if (!selection.isValid) return;

    final start = selection.start;
    final newText = text.substring(0, start) + content + text.substring(start);
    _descriptionController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + content.length),
    );
  }

  Future<void> _continueToPostDestination() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a title')),
      );
      return;
    }

    if (_codeController.text.length > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Code snippet cannot exceed 5000 characters')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final appwriteService = context.read<AppwriteService>();
      // 1. Upload files
      List<String> uploadedFileIds = [];
      for (final file in _selectedFiles) {
        if (file.bytes != null) {
          final uploadedFile = await appwriteService.uploadFile(
            bytes: file.bytes!,
            filename: file.name,
          );
          uploadedFileIds.add(uploadedFile.$id);
        }
      }

      final postData = {
        'titles': _titleController.text,
        'caption': _descriptionController.text,
        'tags': _tagsController.text.split(',').map((s) => s.trim()).toList(),
        'location': '', // Placeholder
        'snippet': jsonEncode({
          'language': _codeLang,
          'content': _codeController.text,
        }),
        'file_ids': uploadedFileIds,
      };

      // Show the WhereToPostScreen as a modal bottom sheet
      if (mounted) {
        showModalBottomSheet(
          context: context,
          builder: (context) => WhereToPostScreen(postData: postData),
        );
      }
    } on AppwriteException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload files: ${e.message}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      // Use FilePicker to allow the user to select multiple files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'pdf', 'doc', 'png'], // Example extensions
        withData: true, // This is crucial for web and cross-platform uploads
      );

      if (result != null) {
        setState(() {
          _selectedFiles = result.files;
        });
        _showSnackbar('Successfully selected ${_selectedFiles.length} file(s).');
      } else {
        // User canceled the picker
        _showSnackbar('File selection cancelled.');
      }
    } catch (e) {
      _showSnackbar('Error picking file: $e');
    }
  }

  // Helper function to show a temporary message
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Function to remove a selected file
  void _removeFile(PlatformFile file) {
    setState(() {
      _selectedFiles.remove(file);
    });
    _showSnackbar('File removed: ${file.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.help_outline),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _continueToPostDestination,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ))
                  : const Text('Publish'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAttachments(),
            const SizedBox(height: 16),
            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Post Title',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Toolbar and Description
            _buildDescriptionEditor(),
            const SizedBox(height: 16),

            // Code Editor
            _buildCodeEditor(),
            const SizedBox(height: 16),

            // Tags
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma separated)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Toolbar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.format_bold),
                  onPressed: () => _wrapSelection('**')),
              IconButton(
                  icon: const Icon(Icons.format_italic),
                  onPressed: () => _wrapSelection('*')),
              IconButton(
                  icon: const Icon(Icons.looks_one),
                  onPressed: () => _insertAtCursor('# ')),
              IconButton(
                  icon: const Icon(Icons.looks_two),
                  onPressed: () => _insertAtCursor('## ')),
              IconButton(
                  icon: const Icon(Icons.format_list_bulleted),
                  onPressed: () => _insertAtCursor('\n- ')),
              IconButton(
                  icon: const Icon(Icons.format_list_numbered),
                  onPressed: () => _insertAtCursor('\n1. ')),
              IconButton(
                  icon: const Icon(Icons.code),
                  onPressed: () => _wrapSelection('`')),
              IconButton(
                  icon: const Icon(Icons.insert_link),
                  onPressed: () {
                    // Simplified link insertion
                    _wrapSelection('[', '](url)');
                  }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Editor
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Write your post content...',
          ),
          maxLines: 10,
          keyboardType: TextInputType.multiline,
        ),
      ],
    );
  }

  Widget _buildCodeEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Snippet',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            DropdownButton<String>(
              value: _codeLang,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _codeLang = newValue;
                  });
                }
              },
              items: <String>[
                'javascript',
                'typescript',
                'python',
                'java',
                'csharp',
                'sql',
                'json',
                'dart'
              ].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Paste your code here...',
          ),
          maxLines: 8,
          style: const TextStyle(fontFamily: 'monospace'),
          keyboardType: TextInputType.multiline,
        ),
      ],
    );
  }

  Widget _buildAttachments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The main File Uploader/Dropzone UI
        GestureDetector(
          onTap: _pickFile,
          child: FileUploadArea(
            selectedFiles: _selectedFiles,
            onRemove: _removeFile,
          ),
        ),

        const SizedBox(height: 30),

        // Display list of selected files (optional/visual confirmation)
        if (_selectedFiles.isNotEmpty)
          ..._selectedFiles.map((file) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: FileListItem(
                    file: file, onRemove: () => _removeFile(file)),
              )),

        if (_selectedFiles.isNotEmpty) const SizedBox(height: 16),
      ],
    );
  }
}

// Widget to handle the dashed border and core UI of the dropzone
class FileUploadArea extends StatelessWidget {
  final List<PlatformFile> selectedFiles;
  final Function(PlatformFile) onRemove;

  const FileUploadArea({
    super.key,
    required this.selectedFiles,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // CustomPaint is used to draw the dashed border easily
    return CustomPaint(
      painter: DashedRectPainter(color: Colors.blueGrey, strokeWidth: 2, gap: 5),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.cloud_upload,
                color: Colors.blueAccent,
                size: 50.0,
              ),
              const SizedBox(height: 10),
              Text(
                selectedFiles.isEmpty
                    ? 'Drag and drop or click to upload file(s)'
                    : '${selectedFiles.length} file(s) selected.',
                style: TextStyle(
                  color: Colors.blueGrey.shade700,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                'Supported formats: JPG, PNG, PDF, DOC',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper widget to display a list item for a selected file
class FileListItem extends StatelessWidget {
  final PlatformFile file;
  final VoidCallback onRemove;

  const FileListItem({
    super.key,
    required this.file,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '(${((file.bytes?.lengthInBytes ?? 0) / 1024).toStringAsFixed(1)} KB)',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 18, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for drawing the dashed border effect
class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    Path path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    ));

    Path dashedPath = Path();
    double distance = 0.0;
    for (PathMetric metric in path.computeMetrics()) {
      while (distance < metric.length) {
        dashedPath.addPath(
          metric.extractPath(distance, distance + strokeWidth),
          Offset.zero,
        );
        distance += strokeWidth + gap;
      }
      distance = 0.0;
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
