import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/auth_service.dart';
import 'package:my_app/model/post.dart';
import 'package:my_app/widgets/add_to_playlist.dart';
import 'package:my_app/provider/queue_provider.dart';
import 'package:provider/provider.dart';

class PostOptionsMenu extends StatelessWidget {
  final Post post;
  final String profileId;
  final bool isSaved;
  final VoidCallback onSaveToggle;

  const PostOptionsMenu({
    super.key,
    required this.post,
    required this.profileId,
    required this.isSaved,
    required this.onSaveToggle,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isOwner = authService.currentUser?.id == post.author.ownerId;

    return IconButton(
      icon: Icon(Icons.more_horiz, color: Colors.grey[600], size: 22),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (context) {
            return ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text(
                    'Post Setting',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.high_quality),
                  title: Text('Quality Setting'),
                ),
                const ListTile(
                  leading: Icon(Icons.translate),
                  title: Text('Translate and Transcript'),
                ),
                ListTile(
                  leading: const Icon(Icons.queue_play_next),
                  title: const Text('Add to Queue'),
                  onTap: () {
                    final queueProvider = Provider.of<QueueProvider>(
                      context,
                      listen: false,
                    );
                    queueProvider.addToQueue(post.id, post.contentText);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added to Queue')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  title: Text(isSaved ? 'Unsave' : 'Save'),
                  onTap: () {
                    Navigator.pop(context);
                    onSaveToggle();
                  },
                ),
                if (isOwner) ...[
                  const Divider(),
                  const ListTile(
                    title: Text(
                      'Owner Setting',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add),
                    title: const Text('Add to Playlist'),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        builder: (context) => AddToPlaylistScreen(
                          postId: post.id,
                          profileId: profileId,
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete),
                    title: const Text('Delete'),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => _DeletePostDialog(post: post),
                      );
                    },
                  ),
                ],
                const Divider(),
                const ListTile(
                  title: Text(
                    'Caution',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.report, color: Colors.red),
                  title: const Text(
                    'Report',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) =>
                          _ReportPostDialog(post: post, reporterId: profileId),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DeletePostDialog extends StatelessWidget {
  const _DeletePostDialog({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Post'),
      content: const Text(
        'Are you sure you want to delete this post? Posts will not be recovered.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () {
            final appwriteService = Provider.of<AppwriteService>(
              context,
              listen: false,
            );
            appwriteService.deletePost(post.id);
            Navigator.of(context).pop();
          },
          child: const Text('Yes'),
        ),
      ],
    );
  }
}

class _ReportPostDialog extends StatefulWidget {
  final Post post;
  final String reporterId;

  const _ReportPostDialog({required this.post, required this.reporterId});

  @override
  State<_ReportPostDialog> createState() => _ReportPostDialogState();
}

class _ReportPostDialogState extends State<_ReportPostDialog> {
  final List<String> _reasons = [
    'Spam',
    'Inappropriate Content',
    'Harassment',
    'False Information',
    'Other',
  ];
  String? _selectedReason;
  bool _isSubmitting = false;

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final appwriteService = Provider.of<AppwriteService>(
        context,
        listen: false,
      );
      await appwriteService.reportPost(
        postId: widget.post.id,
        reporterId: widget.reporterId,
        reason: _selectedReason!,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Post'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select a reason for reporting this post:'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _selectedReason,
            items: _reasons.map((reason) {
              return DropdownMenuItem(value: reason, child: Text(reason));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedReason = value;
              });
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Reason',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting || _selectedReason == null
              ? null
              : _submitReport,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Report'),
        ),
      ],
    );
  }
}
