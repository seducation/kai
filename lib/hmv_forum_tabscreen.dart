import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:my_app/model/post.dart';
import 'model/profile.dart';
import 'widgets/post_item.dart';

double calculateScore(Post post) {
  final hoursSincePosted = DateTime.now().difference(post.timestamp).inHours;
  final score =
      ((post.stats.likes * 1) +
          (post.stats.comments * 5) +
          (post.stats.shares * 10)) /
      pow(hoursSincePosted + 2, 1.5);
  return score;
}

class HmvForumTabscreen extends StatefulWidget {
  const HmvForumTabscreen({super.key});

  @override
  State<HmvForumTabscreen> createState() => _HmvForumTabscreenState();
}

class _HmvForumTabscreenState extends State<HmvForumTabscreen> {
  late AppwriteService _appwriteService;
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _profileId;

  @override
  void initState() {
    super.initState();
    _appwriteService = context.read<AppwriteService>();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final user = await _appwriteService.getUser();
      if (user != null) {
        final profiles = await _appwriteService.getUserProfiles(
          ownerId: user.$id,
        );
        if (profiles.rows.isNotEmpty) {
          _profileId = profiles.rows.first.$id;
        }
      }

      final results = await Future.wait([
        _appwriteService.getPosts(),
        _appwriteService.getProfiles(),
      ]);

      final postsResponse = results[0];
      final profilesResponse = results[1];

      final profilesMap = {
        for (var doc in profilesResponse.rows) doc.$id: doc.data,
      };

      final postFutures = postsResponse.rows.map((row) async {

        final profileIds = row.data['profile_id'] as List?;
        if (profileIds == null || profileIds.isEmpty) {
          return null;
        }
        final profileId = profileIds.first as String?;
        if (profileId == null) {
          return null;
        }

        final creatorProfileData = profilesMap[profileId];
        if (creatorProfileData == null) {
          return null;
        }

        final author = Profile.fromMap(creatorProfileData, profileId);

        final updatedAuthor = Profile(
          id: author.id,
          name: author.name,
          type: author.type,
          bio: author.bio,
          profileImageUrl:
              author.profileImageUrl != null &&
                      author.profileImageUrl!.isNotEmpty
                  ? _appwriteService.getFileViewUrl(author.profileImageUrl!)
                  : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
          ownerId: author.ownerId,
          createdAt: author.createdAt,
        );

        final originalAuthorIds = row.data['author_id'] as List?;
        final originalAuthorId = (originalAuthorIds?.isNotEmpty ?? false)
            ? originalAuthorIds!.first as String?
            : null;

        Profile? originalAuthor;
        if (originalAuthorId != null && originalAuthorId != profileId) {
          final originalAuthorProfileData = profilesMap[originalAuthorId];
          if (originalAuthorProfileData != null) {
            originalAuthor = Profile.fromMap(
              originalAuthorProfileData,
              originalAuthorId,
            );
          }
        }
        
        final postType = PostType.text;

        final postStats = PostStats(
          likes: row.data['likes'] ?? 0,
          comments: row.data['comments'] ?? 0,
          shares: row.data['shares'] ?? 0,
          views: row.data['views'] ?? 0,
        );

        return Post(
          id: row.$id,
          author: updatedAuthor,
          originalAuthor: originalAuthor,
          timestamp:
              DateTime.tryParse(row.data['timestamp'] ?? '') ??
                  DateTime.now(),
          contentText: row.data['caption'] ?? '',
          mediaUrls: [],
          type: postType,
          stats: postStats,
          linkUrl: row.data['linkUrl'],
          linkTitle: row.data['titles'],
          authorIds: (row.data['author_id'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
          profileIds: (row.data['profile_id'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
        );
      });

      final posts = (await Future.wait(postFutures))
          .whereType<Post>()
          .where((post) => post.type == PostType.text && (post.mediaUrls == null || post.mediaUrls!.isEmpty) && (post.linkUrl == null || post.linkUrl!.isEmpty))
          .toList();

      if (!mounted) return;

      _rankPosts(posts);
      
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error fetching data in HmvForumTabscreen: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _rankPosts(List<Post> posts) {
    if (!mounted) return;
    final rankedPosts = List<Post>.from(posts);
    for (var post in rankedPosts) {
      post.score = calculateScore(post);
    }
    rankedPosts.sort((a, b) => b.score.compareTo(a.score));
    setState(() {
      _posts = rankedPosts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildFeed(),
    );
  }

  Widget _buildFeed() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: _posts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.4),
                const Center(child: Text("No forum posts available.")),
              ],
            )
          : ListView.builder(
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                return PostItem(post: post, profileId: _profileId ?? '');
              },
            ),
    );
  }
}
