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

class HmvVideosTabScreen extends StatefulWidget {
  const HmvVideosTabScreen({super.key});

  @override
  State<HmvVideosTabScreen> createState() => _HmvVideosTabScreenState();
}

class _HmvVideosTabScreenState extends State<HmvVideosTabScreen> {
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

      debugPrint(
        'HmvVideosTabScreen: Fetched ${postsResponse.rows.length} posts raw.',
      );
      debugPrint(
        'HmvVideosTabScreen: Fetched ${profilesResponse.rows.length} profiles.',
      );

      final profilesMap = {
        for (var doc in profilesResponse.rows) doc.$id: doc.data,
      };

      final posts = postsResponse.rows
          .map((row) {
            debugPrint('HmvVideosTabScreen: Processing post ${row.$id}');

            final profileIds = row.data['profile_id'] as List?;
            if (profileIds == null || profileIds.isEmpty) {
              debugPrint(
                'HmvVideosTabScreen: Post ${row.$id} filtered. profile_id list is null or empty.',
              );
              return null;
            }
            final profileId = profileIds.first as String?;
            if (profileId == null) {
              debugPrint(
                'HmvVideosTabScreen: Post ${row.$id} filtered. First profile_id in list is null.',
              );
              return null;
            }

            final creatorProfileData = profilesMap[profileId];
            if (creatorProfileData == null) {
              debugPrint(
                'HmvVideosTabScreen: Post ${row.$id} filtered. Author profile for ID $profileId not found in profilesMap. profilesMap keys: ${profilesMap.keys.toList()}',
              );
              return null;
            }

            debugPrint(
              'HmvVideosTabScreen: Post ${row.$id} passed all checks. Creating Post object.',
            );

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

            final fileIdsData = row.data['file_ids'];
            final List<String> fileIds = fileIdsData is List
                ? List<String>.from(fileIdsData.map((id) => id.toString()))
                : [];

            List<String> mediaUrls = [];
            if (fileIds.isNotEmpty) {
              mediaUrls = fileIds
                  .map((id) => _appwriteService.getFileViewUrl(id))
                  .toList();
            }
            debugPrint('HmvVideosTabScreen: Post ${row.$id} mediaUrls: $mediaUrls');

            String? postTypeString = row.data['type'];
            final postType = _getPostType(postTypeString, row.data['linkUrl'], mediaUrls);

            debugPrint('HmvVideosTabScreen: Post ${row.$id} has postType: $postType');

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
              mediaUrls: mediaUrls,
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
          })
          .whereType<Post>()
          .where((post) => post.type == PostType.video)
          .toList();

      debugPrint(
        'HmvVideosTabScreen: Finished mapping. Found ${posts.length} valid posts.',
      );

      if (!mounted) return;

      debugPrint(
        'HmvVideosTabScreen: Setting state with ${posts.length} valid posts.',
      );

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
      _rankPosts();
    } catch (e, stackTrace) {
      debugPrint('Error fetching data in HmvVideosTabScreen: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  PostType _getPostType(String? type, String? linkUrl, List<String> mediaUrls) {
    if (type == 'video') {
      return PostType.video;
    }
    for (final url in mediaUrls) {
      if (url.endsWith('.mp4') || url.endsWith('.mov') || url.endsWith('.avi')) {
        return PostType.video;
      }
    }
    if (linkUrl != null && linkUrl.isNotEmpty) {
      return PostType.linkPreview;
    }
    if (mediaUrls.isNotEmpty) {
      return PostType.image;
    }
    return PostType.text;
  }

  void _rankPosts() {
    if (!mounted) return;
    final rankedPosts = List<Post>.from(_posts);
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
                const Center(child: Text("No videos available.")),
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
