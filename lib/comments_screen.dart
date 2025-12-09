import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/hmv_features_tabscreen.dart';
import 'package:provider/provider.dart';
import 'package:my_app/model/profile.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CommentsScreen extends StatefulWidget {
  final Post post;

  const CommentsScreen({super.key, required this.post});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _Comment {
  final String text;
  final Profile author;
  final DateTime timestamp;

  _Comment(
      {required this.text, required this.author, required this.timestamp});
}

class _CommentsScreenState extends State<CommentsScreen> {
  late AppwriteService _appwriteService;
  late List<_Comment> _comments;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _appwriteService = context.read<AppwriteService>();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final commentsResponse = await _appwriteService.getComments(widget.post.id);
      final profilesResponse = await _appwriteService.getProfiles();

      final profilesMap =
          {for (var p in profilesResponse.rows) p.$id: Profile.fromMap(p.data, p.$id)};

      final comments = commentsResponse.rows.map((row) {
        final profileId = row.data['user_id'] as String?;
        final author = profilesMap[profileId];

        if (author == null) {
          return null;
        }

        return _Comment(
          text: row.data['text'] as String? ?? '',
          author: author,
          timestamp: DateTime.tryParse(row.data['timestamp'] ?? '') ?? DateTime.now(),
        );
      }).whereType<_Comment>().toList();

      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) {
      return;
    }

    final user = await _appwriteService.getUser();
    if (user == null) {
      // Handle user not being authenticated
      return;
    }

    try {
      await _appwriteService.createComment(
        postId: widget.post.id,
        userId: user.$id,
        text: _commentController.text,
      );
      _commentController.clear();
      _fetchComments(); // Refresh comments
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCommentsList(),
          ),
          _buildCommentInputField(),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_comments.isEmpty) {
      return const Center(
        child: Text('No comments yet.'),
      );
    }

    return ListView.builder(
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        final bool isValidUrl = comment.author.profileImageUrl != null && (comment.author.profileImageUrl!.startsWith('http') || comment.author.profileImageUrl!.startsWith('https'));

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if(isValidUrl)
              CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(comment.author.profileImageUrl!),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.author.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(comment.text),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentInputField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _addComment,
          ),
        ],
      ),
    );
  }
}
