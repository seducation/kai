import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:provider/provider.dart';
import './profile_page.dart';
import 'dart:math';
import 'model/profile.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ---------------------------------------------------------------------------
// 1. DATA MODELS ( The "Base" Structure )
// ---------------------------------------------------------------------------

enum PostType { text, image, linkPreview, video }

class PostStats {
  final int likes;
  final int comments;
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
  });
}

// ---------------------------------------------------------------------------
// 2. MOCK DATA REPOSITORY
// ---------------------------------------------------------------------------

class MockData {
  static final Profile currentUser = Profile(
    id: 'user_alex',
    name: "Alex Designer",
    type: "profile",
    ownerId: "",
    profileImageUrl: "https://i.pravatar.cc/150?u=alex",
  );

  static final Profile techSource = Profile(
    id: 'user_tech',
    name: "Android for PCs",
    type: "profile",
    ownerId: "",
    profileImageUrl: "https://upload.wikimedia.org/wikipedia/commons/d/db/Android_robot_2014.svg", // Placeholder
  );

  static final Profile gamingSource = Profile(
    id: 'user_gaming',
    name: "Warzone Updates",
    type: "profile",
    ownerId: "",
    profileImageUrl: "https://i.pravatar.cc/150?u=gaming",
  );

   static final Profile animeSource = Profile(
    id: 'user_anime',
    name: "Shonen Jump Daily",
    type: "profile",
    ownerId: "",
    profileImageUrl: "https://i.pravatar.cc/150?u=anime",
  );

  static List<Post> getFeed() {
    final now = DateTime.now();
    return [
      // 1. Link Preview Style (Like the Apple News item)
      Post(
        id: '1',
        author: techSource,
        timestamp: now.subtract(const Duration(days: 6)),
        contentText: "We've overhauled our list of the best TVs to give you the most up-to-date recommendations – just in time for the holidays.",
        type: PostType.linkPreview,
        mediaUrl: "https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?auto=format&fit=crop&w=800&q=80", // iPhone/Apple image
        linkTitle: "Apple Inc. is a multinational technology company known for its consumer electronics.",
        linkUrl: "apple.com",
        stats: PostStats(likes: 1240, comments: 45, shares: 120, views: 15000),
      ),
      // 2. Large Image Media Style (Like the Ghost Skin item)
      Post(
        id: '2',
        author: gamingSource,
        timestamp: now.subtract(const Duration(hours: 2)),
        linkTitle: "The new Free Ghost Skin is absolutely CRAZY! 🤯",
        contentText: "Check out the details below.",
        type: PostType.image,
        mediaUrl: "https://images.unsplash.com/photo-1552820728-8b83bb6b773f?auto=format&fit=crop&w=800&q=80", // Tactical gear image
        stats: PostStats(likes: 8500, comments: 230, shares: 1400, views: 654000),
      ),
      // 3. Text Only Style
      Post(
        id: '3',
        author: currentUser,
        timestamp: now.subtract(const Duration(minutes: 1)),
        contentText: "Just finished designing a new UI in Flutter. The declarative syntax makes building complex lists so much easier! #FlutterDev #UI",
        type: PostType.text,
        stats: PostStats(likes: 12, comments: 2, shares: 0, views: 45),
      ),
       // 4. Anime Image Style
      Post(
        id: '4',
        author: animeSource,
        timestamp: now.subtract(const Duration(hours: 12)),
        contentText: "Vegeta's pride is on the line in the upcoming chapter. Who else is hyped?",
        type: PostType.image,
        mediaUrl: "https://images.unsplash.com/photo-1578632767115-351597cf2477?auto=format&fit=crop&w=800&q=80", // Anime vibe
        stats: PostStats(likes: 15000, comments: 890, shares: 3400, views: 250000),
      ),
    ];
  }
}

double calculateScore(Post post) {
  final hoursSincePosted = DateTime.now().difference(post.timestamp).inHours;
  // FinalScore = ((Likes * 1) + (Comments * 5) + (Shares * 10)) / (HoursSincePosted + 2)^1.5
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
    // Sort posts in descending order of score
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
    final shortsPosts = _posts.where((p) => p.type == PostType.image).toList();

    // Create a list of widgets to display in the ListView
    final List<Widget> feedItems = [];

    // Add the first regular post
    if (_posts.isNotEmpty) {
      feedItems.add(PostWidget(post: _posts.first, allPosts: _posts));
    }

    // Add the shorts rail
    if (shortsPosts.isNotEmpty) {
      feedItems.add(_buildShortsRail(context, shortsPosts));
    }

    // Add the rest of the regular posts
    if (_posts.length > 1) {
      feedItems.addAll(_posts.skip(1).map((post) => PostWidget(post: post, allPosts: _posts)));
    }

    return ListView.separated(
      itemCount: feedItems.length,
      separatorBuilder: (context, index) {
        // Add a divider between all items
        return const Divider(height: 1, color: Color(0xFFE0E0E0));
      },
      itemBuilder: (context, index) {
        return feedItems[index];
      },
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShortsViewerScreen(
              posts: allPosts,
              initialIndex: initialIndex,
            ),
          ),
        );
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

class PostWidget extends StatelessWidget {
  final Post post;
  final List<Post> allPosts;


  const PostWidget({super.key, required this.post, required this.allPosts});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          _buildHeader(context),

          // 2. Content (Image or Link Preview for non-text posts)
          if (post.type == PostType.image)
            _buildImageContent(context),
          if (post.type == PostType.linkPreview)
            _buildLinkPreview(context),

          // 3. Post Content (Title and Description)
          GestureDetector(
            onTap: () {
              // Text-only posts don't have a separate detail page in this design
              if (post.type != PostType.text) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DetailPage(post: post)),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.linkTitle != null && post.linkTitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        post.linkTitle!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  if (post.contentText.isNotEmpty)
                    Text(
                      post.contentText,
                      style: const TextStyle(fontSize: 15, height: 1.3),
                    ),
                ],
              ),
            ),
          ),

          // 4. Action Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: _buildActionBar(),
          ),
          
          // 5. Timestamp
          Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
            child: Text(
              '${DateTime.now().difference(post.timestamp).inHours} hours ago',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final handleColor = Colors.grey[600];
    final bool isValidUrl = post.author.profileImageUrl != null && (post.author.profileImageUrl!.startsWith('http') || post.author.profileImageUrl!.startsWith('https'));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfilePageScreen(profileId: post.author.id)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        child: Row(
          children: [
            if(isValidUrl)
            CircleAvatar(
              radius: 20,
              backgroundImage: CachedNetworkImageProvider(post.author.profileImageUrl!),
              backgroundColor: Colors.grey[200],
            ) else CircleAvatar(radius: 20, backgroundColor: Colors.grey[200]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.author.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  ),
                  Text(
                    post.author.type,
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
    final bool isValidUrl = post.mediaUrl != null && (post.mediaUrl!.startsWith('http') || post.mediaUrl!.startsWith('https'));
    return GestureDetector(
      onTap: () {
        final imagePosts = allPosts.where((p) => p.type == PostType.image).toList();
        final initialIndex = imagePosts.indexWhere((p) => p.id == post.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShortsViewerScreen(
              posts: imagePosts,
              initialIndex: initialIndex,
            ),
          ),
        );
      },
      // Removed the Stack to prevent overlay
      child: isValidUrl ? CachedNetworkImage(
        imageUrl: post.mediaUrl!,
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
    final bool isValidUrl = post.mediaUrl != null && (post.mediaUrl!.startsWith('http') || post.mediaUrl!.startsWith('https'));
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailPage(post: post),
          ),
        );
      },
      child: Container(
        // Margin for link previews to distinguish them
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
                    imageUrl: post.mediaUrl!,
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
                    post.linkUrl ?? "link.com",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.linkTitle ?? "Link Preview",
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
            _buildActionItem(Icons.favorite_border, _formatCount(post.stats.likes)),
            const SizedBox(width: 20),
            _buildActionItem(Icons.comment, post.stats.comments.toString()),
            const SizedBox(width: 20),
            _buildActionItem(Icons.repeat, post.stats.shares.toString()),
          ],
        ),
        _buildActionItem(Icons.bar_chart, _formatCount(post.stats.views)),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.grey[600]),
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
// 4. DETAIL PAGE (Article/Wikipedia Style)
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
                  const SizedBox(height: 16),
                  Text(
                    "This is the expanded content section, simulating the full page view you requested, similar to a Medium article or YouTube video description. Here, you would find paragraphs of text, more images, comments, and related videos, depending on the platform being mimicked.",
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

// ---------------------------------------------------------------------------
// 5. SHORTS VIEWER (YouTube Shorts/TikTok Style)
// ---------------------------------------------------------------------------

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
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailPage(post: post),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Icon(Icons.link, color: Colors.blueAccent, size: 16),
                    SizedBox(width: 4),
                    Text(
                      "View Details",
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
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
