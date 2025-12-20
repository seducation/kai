import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/model/post.dart';
import 'package:provider/provider.dart';
import 'package:appwrite/appwrite.dart';

import './widgets/post_item.dart';
import 'model/profile.dart';

class SrvFollowingTabscreen extends StatefulWidget {
  const SrvFollowingTabscreen({super.key});

  @override
  State<SrvFollowingTabscreen> createState() => _SrvFollowingTabscreenState();
}

class _SrvFollowingTabscreenState extends State<SrvFollowingTabscreen> {
  late AppwriteService appwriteService;
  List<Post>? _posts;
  bool _isLoading = true;
  String? _error;
  String? _profileId; // This is the current user's active profile ID

  @override
  void initState() {
    super.initState();
    appwriteService = context.read<AppwriteService>();
    _fetchFollowingPosts();
  }

  Future<void> _fetchFollowingPosts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // 1. Get the authenticated user
      final user = await appwriteService.getUser();
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _error = 'User not authenticated. Please sign in.';
          _isLoading = false;
        });
        return;
      }

      // 2. Get the user's active profile
      final profiles = await appwriteService.getUserProfiles(ownerId: user.$id);
      if (profiles.rows.isEmpty) {
         if (!mounted) return;
        setState(() {
          _error = 'No profile found for the current user.';
          _isLoading = false;
        });
        return;
      }
      _profileId = profiles.rows.first.$id;


      // 3. Get the list of profiles the current user is following
      final followingProfiles = await appwriteService.getFollowingProfiles(userId: _profileId!);
      
      // 4. Extract the IDs of the followed profiles
      final followedProfileIds = followingProfiles.rows.map((profile) => profile.$id).toList();
      
      // Also include the user's own posts in their following feed
      if (!followedProfileIds.contains(_profileId!)) {
        followedProfileIds.add(_profileId!);
      }

      if (followedProfileIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _posts = [];
          _isLoading = false;
        });
        return;
      }

      // 5. Fetch posts from those users
      final postsResponse = await appwriteService.getPostsFromUsers(followedProfileIds);

      // 6. Fetch all profiles to map authors (can be optimized later)
      final profilesResponse = await appwriteService.getProfiles();
      final profilesMap = {for (var p in profilesResponse.rows) p.$id: Profile.fromMap(p.data, p.$id)};

      // 7. Map the post data to Post objects
      final posts = postsResponse.rows.map((row) {
        // Handle array for profile_id
        final profileIdsList = row.data['profile_id'] as List?;
        final postAuthorProfileId = (profileIdsList?.isNotEmpty ?? false) ? profileIdsList!.first as String? : null;
        
        if (postAuthorProfileId == null) return null;

        final author = profilesMap[postAuthorProfileId];

        if (author == null) {
          return null; // Skip post if author profile not found
        }
        
        final updatedAuthor = Profile(
          id: author.id,
          name: author.name,
          type: author.type,
          bio: author.bio,
          profileImageUrl: author.profileImageUrl != null && author.profileImageUrl!.isNotEmpty
              ? appwriteService.getFileViewUrl(author.profileImageUrl!)
              : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
          ownerId: author.ownerId,
          createdAt: author.createdAt,
        );


        PostType type = PostType.text;
        String? mediaUrl;
        final fileIds = row.data['file_ids'] as List?;
        if (fileIds != null && fileIds.isNotEmpty) {
          type = PostType.image; // Assuming image for now, could be video
          mediaUrl = appwriteService.getFileViewUrl(fileIds.first);
        }

        return Post(
          id: row.$id,
          author: updatedAuthor,
          timestamp: DateTime.tryParse(row.data['timestamp'] ?? '') ?? DateTime.now(),
          linkTitle: row.data['titles'] as String? ?? '',
          contentText: row.data['caption'] as String? ?? '',
          type: type,
          mediaUrl: mediaUrl,
          linkUrl: row.data['linkUrl'] as String?,
          stats: PostStats(
            likes: row.data['likes'] ?? 0,
            comments: row.data['comments'] ?? 0,
            shares: row.data['shares'] ?? 0,
            views: row.data['views'] ?? 0,
          ),
        );
      }).whereType<Post>().toList();

      // Sort posts by timestamp, newest first
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } on AppwriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'An Appwrite error occurred.';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_error', textAlign: TextAlign.center),
        ),
      );
    }

    if (_posts == null || _posts!.isEmpty) {
      return const Center(
        child: Text('No posts yet. Follow some people to see their posts here.'),
      );
    }

    // Use RefreshIndicator to allow pull-to-refresh
    return RefreshIndicator(
      onRefresh: _fetchFollowingPosts,
      child: ListView.builder(
        itemCount: _posts!.length,
        itemBuilder: (context, index) {
          final post = _posts![index];
          // Pass the current user's profileId, not the post author's
          return PostItem(post: post, profileId: _profileId ?? '');
        },
      ),
    );
  }
}
