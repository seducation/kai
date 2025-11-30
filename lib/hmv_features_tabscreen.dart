import 'package:flutter/material.dart';
import './profile_page.dart';

// ---------------------------------------------------------------------------
// 1. DATA MODELS ( The "Base" Structure )
// ---------------------------------------------------------------------------

enum PostType { text, image, linkPreview, video }

class User {
  final String id;
  final String name;
  final String handle;
  final String avatarUrl;
  final bool isVerified;

  User({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatarUrl,
    this.isVerified = false,
  });
}

class PostStats {
  final int likes;
  final int comments;
  final int shares;
  final int views;

  PostStats({this.likes = 0, this.comments = 0, this.shares = 0, this.views = 0});
}

class Post {
  final String id;
  final User author;
  final String timestamp;
  final String contentText;
  final PostType type;
  final String? mediaUrl; // Image URL or Link Preview Image
  final String? linkUrl;  // For Link Previews
  final String? linkTitle; // For Link Previews
  final PostStats stats;

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
  });
}

// ---------------------------------------------------------------------------
// 2. MOCK DATA REPOSITORY
// ---------------------------------------------------------------------------

class MockData {
  static final User currentUser = User(
    id: 'user_alex',
    name: "Alex Designer",
    handle: "@alex_ux",
    avatarUrl: "https://i.pravatar.cc/150?u=alex",
  );

  static final User techSource = User(
    id: 'user_tech',
    name: "Android for PCs",
    handle: "@android_pc_mods",
    avatarUrl: "https://upload.wikimedia.org/wikipedia/commons/d/db/Android_robot_2014.svg", // Placeholder
    isVerified: true,
  );

  static final User gamingSource = User(
    id: 'user_gaming',
    name: "Warzone Updates",
    handle: "@cod_warfare",
    avatarUrl: "https://i.pravatar.cc/150?u=gaming",
  );

   static final User animeSource = User(
    id: 'user_anime',
    name: "Shonen Jump Daily",
    handle: "@shonen_leaks",
    avatarUrl: "https://i.pravatar.cc/150?u=anime",
    isVerified: true,
  );

  static List<Post> getFeed() {
    return [
      // 1. Link Preview Style (Like the Apple News item)
      Post(
        id: '1',
        author: techSource,
        timestamp: "6d",
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
        timestamp: "2h",
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
        timestamp: "Just now",
        contentText: "Just finished designing a new UI in Flutter. The declarative syntax makes building complex lists so much easier! #FlutterDev #UI",
        type: PostType.text,
        stats: PostStats(likes: 12, comments: 2, shares: 0, views: 45),
      ),
       // 4. Anime Image Style
      Post(
        id: '4',
        author: animeSource,
        timestamp: "12h",
        contentText: "Vegeta's pride is on the line in the upcoming chapter. Who else is hyped?",
        type: PostType.image,
        mediaUrl: "https://images.unsplash.com/photo-1578632767115-351597cf2477?auto=format&fit=crop&w=800&q=80", // Anime vibe
        stats: PostStats(likes: 15000, comments: 890, shares: 3400, views: 250000),
      ),
    ];
  }
}


class HMVFeaturesTabscreen extends StatelessWidget {
  const HMVFeaturesTabscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = MockData.getFeed();

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView.separated(
        itemCount: posts.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE0E0E0)),
        itemBuilder: (context, index) {
          return PostWidget(
            post: posts[index],
            allPosts: posts,
          );
        },
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
              post.timestamp,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final handleColor = Colors.grey[600];

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
            CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(post.author.avatarUrl),
              backgroundColor: Colors.grey[200],
            ),
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
                    post.author.handle,
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
      child: Image.network(
        post.mediaUrl!,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          // Maintain a square aspect ratio for the placeholder
          return AspectRatio(
            aspectRatio: 1, 
            child: Container(color: Colors.grey[200])
          );
        },
        errorBuilder: (ctx, err, stack) => AspectRatio(
          aspectRatio: 1, 
          child: Container(
            color: Colors.grey[200], 
            child: const Icon(Icons.error, color: Colors.grey)
          )
        ),
      ),
    );
  }

  Widget _buildLinkPreview(BuildContext context) {
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
            if (post.mediaUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    post.mediaUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
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
            _buildActionItem(Icons.chat_bubble_outline, post.stats.comments.toString()),
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
            if (post.mediaUrl != null)
              Image.network(post.mediaUrl!,
                  width: double.infinity, height: 250, fit: BoxFit.cover),
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
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(post.author.avatarUrl),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          post.mediaUrl!,
          fit: BoxFit.cover,
        ),
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
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(post.author.avatarUrl),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post.author.handle,
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
