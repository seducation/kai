import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:provider/provider.dart';
import 'package:appwrite/appwrite.dart';

// Import the data models and widgets from the features tab
import './hmv_features_tabscreen.dart';
import 'model/profile.dart';

class HMVFollowingTabscreen extends StatefulWidget {
  const HMVFollowingTabscreen({super.key});

  @override
  State<HMVFollowingTabscreen> createState() => _HMVFollowingTabscreenState();
}

class _HMVFollowingTabscreenState extends State<HMVFollowingTabscreen> {
  late AppwriteService appwriteService;
  // Use the Post model from the features tab
  List<Post>? _posts;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    appwriteService = context.read<AppwriteService>();
    _fetchFollowingPosts();
  }

  Future<void> _fetchFollowingPosts() async {
    try {
      final user = await appwriteService.getUser();
      if (user == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get the profiles of the users that the current user is following.
      final followingProfiles = await appwriteService.getFollowingProfiles(userId: user.$id);
      if (followingProfiles.rows.isEmpty) {
        setState(() {
          _posts = [];
          _isLoading = false;
        });
        return;
      }

      // Extract the profile IDs from the profiles.
      final profileIds = followingProfiles.rows.map((profile) => profile.$id).toList();

      // Fetch the posts from those profiles.
      final postsResponse = await appwriteService.getPostsFromUsers(profileIds);

      // Fetch all profiles to map authors correctly
      final profilesResponse = await appwriteService.getProfiles();
      final profilesMap = {for (var p in profilesResponse.rows) p.$id: Profile.fromMap(p.data, p.$id)};

      final posts = postsResponse.rows.map((row) {
        final profileId = row.data['profile_id'] as String?;
        final author = profilesMap[profileId];

        if (author == null) {
          // If for some reason the author profile is not found, skip this post.
          return null;
        }

        PostType type = PostType.text;
        String? mediaUrl;
        final fileIds = row.data['file_ids'] as List?;
        if (fileIds != null && fileIds.isNotEmpty) {
          type = PostType.image;
          mediaUrl = appwriteService.getFileViewUrl(fileIds.first);
        }

        // Create the Post object, similar to hmv_features_tabscreen.dart
        return Post(
          id: row.$id,
          author: author,
          timestamp: DateTime.tryParse(row.data['timestamp'] ?? '') ?? DateTime.now(),
          linkTitle: row.data['titles'] as String? ?? '',
          contentText: row.data['caption'] as String? ?? '',
          type: type,
          mediaUrl: mediaUrl,
          linkUrl: row.data['linkUrl'] as String?, // Added this line
          // Appwrite posts don't have stats yet, so we use defaults.
          stats: PostStats(
            likes: row.data['likes'] ?? 0,
            comments: row.data['comments'] ?? 0,
            shares: row.data['shares'] ?? 0,
            views: row.data['views'] ?? 0,
          ),
        );
      }).whereType<Post>().toList();

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } on AppwriteException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'An unexpected error occurred: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Text('Error: $_error'),
      );
    }

    if (_posts == null || _posts!.isEmpty) {
      return const Center(
        child: Text('No posts from the users you follow.'),
      );
    }

    // Use the same UI structure as the features tab
    return ListView.separated(
      itemCount: _posts!.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE0E0E0)),
      itemBuilder: (context, index) {
        final post = _posts![index];
        // Reuse the PostWidget
        return PostWidget(post: post, allPosts: _posts!);
      },
    );
  }
}
