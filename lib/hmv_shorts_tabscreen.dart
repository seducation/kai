import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/comments_screen.dart';
import 'package:video_player/video_player.dart';

import 'package:my_app/model/post.dart';
import 'package:my_app/model/profile.dart' as profile_model;
import 'package:my_app/profile_page.dart';

// Feed imports
import 'features/feed/controllers/feed_controller.dart';
import 'features/feed/models/feed_item.dart' as feed_models;
import 'features/feed/models/post_item.dart' as feed_models;

class HMVShortsTabscreen extends StatefulWidget {
  const HMVShortsTabscreen({super.key});

  @override
  State<HMVShortsTabscreen> createState() => _HMVShortsTabscreenState();
}

class _HMVShortsTabscreenState extends State<HMVShortsTabscreen> {
  late FeedController _controller;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    final appwriteService = context.read<AppwriteService>();
    final authService = context.read<AuthService>();

    // Initialize FeedController with 'video' postType
    _controller = FeedController(
      client: appwriteService.client,
      userId: authService.currentUser?.id ?? '',
      postType: 'video',
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    // Trigger pagination when user is 3 items away from the end
    if (index >= _controller.feedItems.length - 3) {
      _controller.loadFeed();
    }
  }

  Post? _convertToModelPost(feed_models.FeedItem item) {
    if (item is! feed_models.PostItem) {
      return null; // Skip non-post items for now in Shorts
    }

    // Infer post type - generally video for this screen, but check extension to be safe
    PostType type = PostType.video;

    return Post(
      id: item.postId,
      author: profile_model.Profile(
        id: item.userId,
        name: item.username,
        type: 'profile',
        profileImageUrl: item.profileImage,
        ownerId: '',
        createdAt: DateTime.now(),
      ),
      timestamp: item.createdAt,
      contentText: item.content,
      type: type,
      mediaUrls: item.mediaUrls,
      stats: PostStats(likes: item.engagementScore, views: item.viewCount),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer<FeedController>(
          builder: (context, controller, child) {
            if (!controller.isLoading && controller.feedItems.isEmpty) {
              if (controller.error != null) {
                return Center(
                  child: Text(
                    'Error: ${controller.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }
              return const Center(
                child: Text(
                  "No shorts available.",
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            return PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: controller.feedItems.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final item = controller.feedItems[index];

                // Convert FeedItem to Post model
                final post = _convertToModelPost(item);

                if (post == null) {
                  // Handle non-post items gracefully (e.g. ads could be supported later)
                  return const SizedBox.shrink();
                }

                return ShortsPage(post: post, profileId: controller.userId);
              },
            );
          },
        ),
      ),
    );
  }
}

class ShortsPage extends StatefulWidget {
  final Post post;
  final String profileId;

  const ShortsPage({super.key, required this.post, required this.profileId});

  @override
  State<ShortsPage> createState() => _ShortsPageState();
}

class _ShortsPageState extends State<ShortsPage> {
  late bool _isLiked;
  late int _likeCount;
  int _commentCount = 0;
  late AppwriteService _appwriteService;
  SharedPreferences? _prefs;
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _appwriteService = context.read<AppwriteService>();
    _isLiked = false;
    _likeCount = widget.post.stats.likes;
    _commentCount = widget.post.stats.comments;
    _initializeState();

    if (widget.post.mediaUrls != null && widget.post.mediaUrls!.isNotEmpty) {
      _controller =
          VideoPlayerController.networkUrl(
              Uri.parse(widget.post.mediaUrls!.first),
            )
            ..initialize().then((_) {
              if (mounted) {
                setState(() {});
                _controller?.play();
                _controller?.setLooping(true);
              }
            });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeState() async {
    _prefs = await SharedPreferences.getInstance();
    _fetchCommentCount();
    if (mounted) {
      setState(() {
        _isLiked = _prefs?.getBool(widget.post.id) ?? false;
      });
    }
  }

  Future<void> _fetchCommentCount() async {
    try {
      final comments = await _appwriteService.getComments(widget.post.id);
      if (mounted) {
        setState(() {
          _commentCount = comments.total;
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _toggleLike() async {
    if (_prefs == null) return;

    final user = await _appwriteService.getUser();
    if (!mounted) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to like posts.')),
      );
      return;
    }

    final newLikedState = !_isLiked;
    final newLikeCount = newLikedState ? _likeCount + 1 : _likeCount - 1;

    if (mounted) {
      setState(() {
        _isLiked = newLikedState;
        _likeCount = newLikeCount;
      });
    }

    try {
      await _appwriteService.updatePostLikes(
        widget.post.id,
        newLikeCount,
        widget.post.timestamp.toIso8601String(),
      );
      await _prefs!.setBool(widget.post.id, newLikedState);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = !newLikedState;
          _likeCount = _isLiked ? newLikeCount + 1 : newLikeCount - 1;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openComments() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(post: widget.post),
      ),
    );

    if (result == true) {
      _fetchCommentCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (_controller != null) {
            setState(() {
              if (_controller!.value.isPlaying) {
                _controller!.pause();
              } else {
                _controller!.play();
              }
            });
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video player
            _controller != null && _controller!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  )
                : Container(
                    color: Colors.black,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
            // Gradient overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color.fromARGB(153, 0, 0, 0),
                    Colors.transparent,
                    const Color.fromARGB(153, 0, 0, 0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // UI elements
            _buildUiOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildUiOverlay() {
    return Padding(
      padding: const EdgeInsets.all(16.0).copyWith(bottom: 32, top: 50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top section (optional, e.g., for 'Shorts' title or close button)
          const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Icon(Icons.camera_alt_outlined, color: Colors.white, size: 30)
            ],
          ),
          // Bottom section with post info and actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _buildPostInfo()),
              _buildActionButtons(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ProfilePageScreen(profileId: widget.post.author.id),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: CachedNetworkImageProvider(
                  widget.post.author.profileImageUrl!,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.post.author.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.post.contentText,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildActionButton(
          icon: _isLiked ? Icons.favorite : Icons.favorite_border,
          label: _formatCount(_likeCount),
          onTap: _toggleLike,
          color: _isLiked ? Colors.red : Colors.white,
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: Icons.comment_bank_outlined,
          label: _formatCount(_commentCount),
          onTap: _openComments,
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: Icons.reply,
          label: _formatCount(widget.post.stats.shares),
        ),
        const SizedBox(height: 20),
        _buildActionButton(icon: Icons.more_horiz, label: 'More'),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 30, color: color ?? Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}
