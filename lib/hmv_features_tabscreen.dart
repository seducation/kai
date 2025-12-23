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

class HMVFeaturesTabscreen extends StatefulWidget {
  const HMVFeaturesTabscreen({super.key});

  @override
  State<HMVFeaturesTabscreen> createState() => _HMVFeaturesTabscreenState();
}

class _HMVFeaturesTabscreenState extends State<HMVFeaturesTabscreen> {
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
        'HMVFeaturesTabscreen: Fetched ${postsResponse.rows.length} posts raw.',
      );
      debugPrint(
        'HMVFeaturesTabscreen: Fetched ${profilesResponse.rows.length} profiles.',
      );

      final profilesMap = {
        for (var p in profilesResponse.rows) p.$id: Profile.fromMap(p.data, p.$id)
      };

      final posts = postsResponse.rows.map((row) {
        final isHidden = row.data['isHidden'] as bool? ?? false;
        if (isHidden) {
          return null;
        }

        final profileIdsList = row.data['profile_id'] as List?;
        final primaryProfileId =
            (profileIdsList?.isNotEmpty ?? false)
                ? profileIdsList!.first as String?
                : null;

        final authorIdsList = row.data['author_id'] as List?;
        final originalAuthorId =
            (authorIdsList?.isNotEmpty ?? false)
                ? authorIdsList!.first as String?
                : null;

        final mainAuthorId = primaryProfileId ?? originalAuthorId;

        if (mainAuthorId == null) {
           debugPrint('HMVFeaturesTabscreen: Post ${row.$id} filtered. No author or profile ID.');
          return null;
        }

        final author = profilesMap[mainAuthorId];
        if (author == null) {
          debugPrint('HMVFeaturesTabscreen: Post ${row.$id} filtered. Profile for ID $mainAuthorId not found in profilesMap.');
          return null;
        }

        final updatedAuthor = Profile(
            id: author.id,
            name: author.name,
            type: author.type,
            bio: author.bio,
            profileImageUrl:
                author.profileImageUrl != null && author.profileImageUrl!.isNotEmpty
                    ? _appwriteService.getFileViewUrl(author.profileImageUrl!)
                    : 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
            ownerId: author.ownerId,
            createdAt: author.createdAt);

        Profile? finalOriginalAuthor;
        if (primaryProfileId != null &&
            originalAuthorId != null &&
            primaryProfileId != originalAuthorId) {
          finalOriginalAuthor = profilesMap[originalAuthorId];
        }

        final fileIdsData = row.data['file_ids'];
        final List<String> fileIds =
            fileIdsData is List
                ? List<String>.from(fileIdsData.map((id) => id.toString()))
                : [];

        String? postTypeString = row.data['type'];
        if (postTypeString == null && fileIds.isNotEmpty) {
          postTypeString = 'image'; // Infer type for old data
        }

        final postType = _getPostType(postTypeString, row.data['linkUrl']);

        List<String> mediaUrls = [];
        if (fileIds.isNotEmpty) {
          mediaUrls = fileIds
              .map((id) => _appwriteService.getFileViewUrl(id))
              .toList();
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
          originalAuthor: finalOriginalAuthor,
          timestamp:
              DateTime.tryParse(row.data['timestamp'] ?? '') ?? DateTime.now(),
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
      }).whereType<Post>().toList();

      if (!mounted) return;

      debugPrint(
        'HMVFeaturesTabscreen: Setting state with ${posts.length} valid posts.',
      );

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
      _rankPosts();
    } catch (e, stackTrace) {
      debugPrint('Error fetching data in HMVFeaturesTabscreen: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    if (_posts.isEmpty) {
      return const Center(child: Text("No posts available."));
    }

    return ListView.builder(
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return PostItem(post: post, profileId: _profileId ?? '');
      },
    );
  }
}
