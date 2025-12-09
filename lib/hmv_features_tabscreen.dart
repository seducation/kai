import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:provider/provider.dart';
import './profile_page.dart';
import 'dart:math';
import 'model/profile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'comments_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// 1. DATA MODELS ( The "Base" Structure )
// ---------------------------------------------------------------------------

enum PostType { text, image, linkPreview, video }

class PostStats {
  int likes;
  int comments;
  final int shares;
  final int views;

  PostStats({this.likes = 0, this.comments = 0, this.shares = 0, this.views = 0});
}

class Post {
  final String id;
  final Profile author;
  final DateTime timestamp;
  final String contentText;
  final PostType type;
  final String? mediaUrl; // Image URL or Link Preview Image
  final String? linkUrl;  // For Link Previews
  final String? linkTitle; // For Link Previews
  final PostStats stats;
  double score;
  bool isLiked; // To track liked state locally
  bool isSaved; // To track saved state locally


  Post({
    required this.id,
    required this.author,
    required this.timestamp,
    required this.contentText,
    this.type = PostType.text,
    this.mediaUrl,
    this.linkUrl,
    this.linkTitle,
    required this.stats,
    this.score = 0.0,
    this.isLiked = false, // Default to not liked
    this.isSaved = false, // Default to not saved
  });
}

// ... (MockData remains the same)

double calculateScore(Post post) {
  final hoursSincePosted = DateTime.now().difference(post.timestamp).inHours;
  final score = ((post.stats.likes * 1) + (post.stats.comments * 5) + (post.stats.shares * 10)) /
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
  late List<Post> _posts;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _appwriteService = context.read<AppwriteService>();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      final postsResponse = await _appwriteService.getPosts();
      final profilesResponse = await _appwriteService.getProfiles();

      final profilesMap = {for (var p in profilesResponse.rows) p.$id: Profile.fromMap(p.data, p.$id)};

      final posts = postsResponse.rows.map((row) {
        final profileId = row.data['profile_id'] as String?;
        final author = profilesMap[profileId];

        if (author == null) {
          return null;
        }

        PostType type = PostType.text;
        String? mediaUrl;
        final fileIds = row.data['file_ids'] as List?;
        if (fileIds != null && fileIds.isNotEmpty) {
          type = PostType.image;
          mediaUrl = _appwriteService.getFileViewUrl(fileIds.first);
        }

        return Post(
          id: row.$id,
          author: author,
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
          // We will manage the `isLiked` and `isSaved` state within the PostWidget itself
        );
      }).whereType<Post>().toList();

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
      _rankPosts();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

  void _rankPosts() {
    for (var post in _posts) {
      post.score = calculateScore(post);
    }
    _posts.sort((a, b) => b.score.compareTo(a.score));
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

    final shortsPosts = _posts.where((p) => p.type == PostType.image).toList();
    final List<Widget> feedItems = [];

    if (_posts.isNotEmpty) {
      feedItems.add(PostWidget(post: _posts.first, allPosts: _posts));
    }

    if (shortsPosts.isNotEmpty) {
      feedItems.add(_buildShortsRail(context, shortsPosts));
    }

    if (_posts.length > 1) {
      feedItems.addAll(_posts.skip(1).map((post) => PostWidget(post: post, allPosts: _posts)));
    }

    return ListView.separated(
      itemCount: feedItems.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE0E0E0)),
      itemBuilder: (context, index) => feedItems[index],
    );
  }

   Widget _buildShortsRail(BuildContext context, List<Post> shortsPosts) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              "Shorts",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: shortsPosts.length,
              itemBuilder: (context, index) {
                return _ShortsThumbnail(
                  post: shortsPosts[index],
                  allPosts: shortsPosts,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortsThumbnail extends StatelessWidget {
  final Post post;
  final List<Post> allPosts;

  const _ShortsThumbnail({required this.post, required this.allPosts});

  @override
  Widget build(BuildContext context) {
    final bool isValidUrl = post.mediaUrl != null && (post.mediaUrl!.startsWith('http') || post.mediaUrl!.startsWith('https'));
    return GestureDetector(
      onTap: () {
        final initialIndex = allPosts.indexWhere((p) => p.id == post.id);
        if (initialIndex != -1) {
            Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ShortsViewerScreen(
                posts: allPosts,
                initialIndex: initialIndex,
                ),
            ),
            );
        }
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(left: 12.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isValidUrl)
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: CachedNetworkImage(
                imageUrl: post.mediaUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.error, color: Colors.grey),
                ),
              ),
            ) else Container(color: Colors.grey[200], child: const Icon(Icons.error, color: Colors.grey)),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                gradient: const LinearGradient(
                  colors: [Colors.transparent, Colors.black54],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.author.profileImageUrl != null)
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: CachedNetworkImageProvider(post.author.profileImageUrl!),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.author.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// --- CONVERTED TO STATEFULWIDGET ---
class PostWidget extends StatefulWidget {
  final Post post;
  final List<Post> allPosts;

  const PostWidget({super.key, required this.post, required this.allPosts});

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  late bool _isLiked;
  late bool _isSaved;
  late int _likeCount;
  int _commentCount = 0;
  late AppwriteService _appwriteService;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _appwriteService = context.read<AppwriteService>();
    _isLiked = false;
    _isSaved = false;
    _likeCount = widget.post.stats.likes;
    _commentCount = widget.post.stats.comments;
    _initializeState();
  }

  Future<void> _initializeState() async {
    _prefs = await SharedPreferences.getInstance();
    _fetchCommentCount();
    setState(() {
      _isLiked = _prefs?.getBool(widget.post.id) ?? false;
      _isSaved = _prefs?.getBool('saved_${widget.post.id}') ?? false;
    });
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You must be logged in to like posts.'),
      ));
      return;
    }

    final profiles = await _appwriteService.getUserProfiles(ownerId: user.$id);
    if (!mounted) return;

    final userProfiles = profiles.rows.where((p) => p.data['type'] == 'profile');

    if (userProfiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You must have a user profile to like a post.'),
      ));
      return;
    }

    final newLikedState = !_isLiked;
    final newLikeCount = newLikedState ? _likeCount + 1 : _likeCount - 1;

    setState(() {
      _isLiked = newLikedState;
      _likeCount = newLikeCount;
    });

    try {
      await _appwriteService.updatePostLikes(widget.post.id, newLikeCount);
      await _prefs!.setBool(widget.post.id, newLikedState);
    } catch (e) {
      // Revert the state if the update fails
      setState(() {
        _isLiked = !newLikedState;
        _likeCount = _isLiked ? newLikeCount + 1 : newLikeCount -1;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update like. Please try again.'),
        ));
      }
    }
  }

  Future<void> _toggleSaved() async {
    if (_prefs == null) return;

    final newSavedState = !_isSaved;
    setState(() {
      _isSaved = newSavedState;
    });

    await _prefs!.setBool('saved_${widget.post.id}', newSavedState);
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
    if (_prefs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (widget.post.type == PostType.image) _buildImageContent(context),
          if (widget.post.type == PostType.linkPreview) _buildLinkPreview(context),
          GestureDetector(
            onTap: () {
              if (widget.post.type != PostType.text) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DetailPage(post: widget.post)),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.post.linkTitle != null && widget.post.linkTitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        widget.post.linkTitle!,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                  if (widget.post.contentText.isNotEmpty)
                    Text(
                      widget.post.contentText,
                      style: const TextStyle(fontSize: 15, height: 1.3),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: _buildActionBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final handleColor = Colors.grey[600];
    final bool isValidUrl = widget.post.author.profileImageUrl != null && (widget.post.author.profileImageUrl!.startsWith('http') || widget.post.author.profileImageUrl!.startsWith('https'));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfilePageScreen(profileId: widget.post.author.id)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        child: Row(
          children: [
            if(isValidUrl)
            CircleAvatar(
              radius: 20,
              backgroundImage: CachedNetworkImageProvider(widget.post.author.profileImageUrl!),
              backgroundColor: Colors.grey[200],
            ) else CircleAvatar(radius: 20, backgroundColor: Colors.grey[200]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post.author.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  ),
                  Text(
                    widget.post.author.type,
                    style: TextStyle(color: handleColor, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.more_horiz, color: handleColor, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
     final bool isValidUrl = widget.post.mediaUrl != null && (widget.post.mediaUrl!.startsWith('http') || widget.post.mediaUrl!.startsWith('https'));
    return GestureDetector(
        onTap: () {
        final imagePosts = widget.allPosts.where((p) => p.type == PostType.image).toList();
        final initialIndex = imagePosts.indexWhere((p) => p.id == widget.post.id);
        if (initialIndex != -1) {
            Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ShortsViewerScreen(
                posts: imagePosts,
                initialIndex: initialIndex,
                ),
            ),
            );
        }
        },
        child: isValidUrl ? CachedNetworkImage(
        imageUrl: widget.post.mediaUrl!,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => AspectRatio(
            aspectRatio: 1, 
            child: Container(color: Colors.grey[200])
          ),
        errorWidget: (context, url, error) => AspectRatio(
          aspectRatio: 1, 
          child: Container(
            color: Colors.grey[200], 
            child: const Icon(Icons.error, color: Colors.grey)
          )
        ),
      ): AspectRatio(
          aspectRatio: 1, 
          child: Container(
            color: Colors.grey[200], 
            child: const Icon(Icons.error, color: Colors.grey)
          )
        ),
    );
    }

  Widget _buildLinkPreview(BuildContext context) {
    final bool isValidUrl = widget.post.mediaUrl != null && (widget.post.mediaUrl!.startsWith('http') || widget.post.mediaUrl!.startsWith('https'));
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailPage(post: widget.post),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isValidUrl)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: widget.post.mediaUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.error, color: Colors.grey),
                    ),
                  ),
                ),
              ) else AspectRatio(aspectRatio: 16/9, child: Container(color: Colors.grey[200], child: const Icon(Icons.error, color: Colors.grey))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post.linkUrl ?? "link.com",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.post.linkTitle ?? "Link Preview",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _toggleLike,
              child: _buildActionItem(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                _formatCount(_likeCount),
                color: _isLiked ? Colors.red : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: _openComments,
              child: _buildActionItem(Icons.comment, _commentCount.toString()),
            ),
            const SizedBox(width: 20),
            _buildActionItem(Icons.repeat, widget.post.stats.shares.toString()),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: _toggleSaved,
              child: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: Colors.grey[600],
                size: 22,
              ),
            ),
            const SizedBox(width: 20),
            Icon(Icons.share, color: Colors.grey[600], size: 22),
            const SizedBox(width: 20),
            Text(
              '${DateTime.now().difference(widget.post.timestamp).inHours} hours ago',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 22, color: color ?? Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) {
      return "${(count / 1000).toStringAsFixed(1)}k";
    }
    return count.toString();
  }
}


// ---------------------------------------------------------------------------
// 4. DETAIL PAGE & SHORTS VIEWER (largely unchanged)
// ---------------------------------------------------------------------------

class DetailPage extends StatelessWidget {
  final Post post;

  const DetailPage({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final bool isValidUrl = post.mediaUrl != null && (post.mediaUrl!.startsWith('http') || post.mediaUrl!.startsWith('https'));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(post.linkUrl ?? "Details", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isValidUrl)
              CachedNetworkImage(
                  imageUrl: post.mediaUrl!,
                  width: double.infinity, height: 250, fit: BoxFit.cover)
            else Container(width: double.infinity, height: 250, color: Colors.grey[200], child: const Icon(Icons.error, color: Colors.grey)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.linkTitle ?? post.contentText,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (post.author.profileImageUrl != null)
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: CachedNetworkImageProvider(post.author.profileImageUrl!),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        post.author.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ],
                  ),
                  const Divider(height: 30, color: Color(0xFFE0E0E0)),
                  Text(
                    post.contentText,
                    style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShortsViewerScreen extends StatefulWidget {
  final List<Post> posts;
  final int initialIndex;

  const ShortsViewerScreen({super.key, required this.posts, required this.initialIndex});

  @override
  ShortsViewerScreenState createState() => ShortsViewerScreenState();
}

class ShortsViewerScreenState extends State<ShortsViewerScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.posts.length,
        itemBuilder: (context, index) {
          return ShortsPage(post: widget.posts[index]);
        },
      ),
    );
  }
}

class ShortsPage extends StatelessWidget {
  final Post post;

  const ShortsPage({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final bool isValidUrl = post.mediaUrl != null && (post.mediaUrl!.startsWith('http') || post.mediaUrl!.startsWith('https'));
    return Stack(
      fit: StackFit.expand,
      children: [
        if (isValidUrl)
        CachedNetworkImage(
          imageUrl: post.mediaUrl!,
          fit: BoxFit.cover,
        ) else Container(color: Colors.black, child: const Center(child: Icon(Icons.error, color: Colors.white, size: 50))),
        // ... rest of ShortsPage remains the same
         Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withAlpha(178), Colors.transparent, Colors.black.withAlpha(178)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if(post.author.profileImageUrl != null)
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: CachedNetworkImageProvider(post.author.profileImageUrl!),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post.author.name, // handle is not available in Profile model
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.contentText,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
         Positioned(
          top: 40,
          left: 16,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          )
        )
      ],
    );
  }
}
