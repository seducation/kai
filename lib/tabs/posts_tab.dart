import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/model/post.dart';
import 'package:my_app/model/profile.dart';
import 'package:my_app/widgets/post_item.dart';
import 'package:provider/provider.dart';

class PostsTab extends StatefulWidget {
  final String profileId;
  const PostsTab({super.key, required this.profileId});

  @override
  State<PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<PostsTab> {
  late AppwriteService _appwriteService;
  List<Post> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _appwriteService = context.read<AppwriteService>();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final results = await Future.wait([
        _appwriteService.getPostsFromUsers([widget.profileId]),
        _appwriteService.getProfiles(),
      ]);

      final postsResponse = results[0];
      final profilesResponse = results[1];

      final profilesMap = {for (var doc in profilesResponse.rows) doc.$id: doc.data};

      final posts = postsResponse.rows.map((row) {
        final profileIds = row.data['profile_id'] as List?;
        final profileId = (profileIds?.isNotEmpty ?? false) ? profileIds!.first as String? : null;
        if (profileId == null) return null;

        final creatorProfileData = profilesMap[profileId];
        if (creatorProfileData == null) return null;

        final author = Profile.fromMap(creatorProfileData, profileId);

        final updatedAuthor = Profile(
          id: author.id,
          name: author.name,
          type: author.type,
          bio: author.bio,
          profileImageUrl: author.profileImageUrl != null && author.profileImageUrl!.isNotEmpty
              ? _appwriteService.getFileViewUrl(author.profileImageUrl!)
              : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
          ownerId: author.ownerId,
          createdAt: author.createdAt,
        );

        final fileIdsData = row.data['file_ids'];
        final List<String> fileIds = fileIdsData is List ? List<String>.from(fileIdsData.map((id) => id.toString())) : [];

        String? postTypeString = row.data['type'];
        if (postTypeString == null && fileIds.isNotEmpty) {
          postTypeString = 'image'; // Infer type for old data
        }

        final postType = _getPostType(postTypeString, row.data['linkUrl']);

        String? mediaUrl;
        if (fileIds.isNotEmpty) {
          mediaUrl = _appwriteService.getFileViewUrl(fileIds.first);
        }

        final postStats = PostStats(
          likes: row.data['likes'] ?? 0,
          comments: row.data['comments'] ?? 0,
          shares: row.data['shares'] ?? 0,
          views: row.data['views'] ?? 0,
        );

        return Post(
          id: row.$id,
          author: updatedAuthor,
          timestamp: DateTime.tryParse(row.data['timestamp'] ?? '') ?? DateTime.now(),
          contentText: row.data['caption'] ?? '',
          mediaUrl: mediaUrl,
          type: postType,
          stats: postStats,
          linkUrl: row.data['linkUrl'],
          linkTitle: row.data['titles'],
        );
      }).where((post) => post != null).cast<Post>().toList();

      if (!mounted) return;
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  PostType _getPostType(String? type, String? linkUrl) {
    if (linkUrl != null && linkUrl.isNotEmpty) {
      return PostType.linkPreview;
    }
    switch (type) {
      case 'image':
        return PostType.image;
      case 'video':
        return PostType.video;
      default:
        return PostType.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _posts.isEmpty
            ? const Center(child: Text("No posts found"))
            : ListView.builder(
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return PostItem(post: post, profileId: widget.profileId);
                },
              );
  }
}
