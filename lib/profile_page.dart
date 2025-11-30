import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// import 'package:my_app/appwrite_service.dart';
// import 'package:my_app/auth_service.dart';
import 'package:my_app/tabs/about_tab.dart';
import 'package:my_app/tabs/home_tab.dart';
import 'package:my_app/tabs/live_tab.dart';
import 'package:my_app/tabs/podcasts_tab.dart';
import 'package:my_app/tabs/posts_tab.dart';
import 'package:my_app/tabs/shorts_tab.dart';
import 'package:my_app/tabs/videos_tab.dart';
import 'package:shimmer/shimmer.dart';
// import 'package:provider/provider.dart';

class ProfilePageScreen extends StatefulWidget {
  final String profileId;
  const ProfilePageScreen({super.key, required this.profileId});

  @override
  State<ProfilePageScreen> createState() => _ProfilePageScreenState();
}

class _ProfilePageScreenState extends State<ProfilePageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isFollowing = false;
  int _followersCount = 8120000; // Mock data
  final bool _isCurrentUser = false;

  final List<String> _tabs = [
    "Home",
    "Posts",
    "Videos",
    "Shorts",
    "Live",
    "Podcasts",
    "About"
  ];

  // Mock data
  final String name = 'My Awesome Channel';
  final String bio =
      'Welcome to the official channel! Subscribe for the latest updates on everything cool.';
  final String? bannerImageUrl = 'https://picsum.photos/id/1015/1200/300';
  final String? profileImageUrl = 'https://picsum.photos/id/1025/200/200';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  Future<void> _toggleFollow() async {
    setState(() {
      _isFollowing = !_isFollowing;
      if (_isFollowing) {
        _followersCount++;
      } else {
        _followersCount--;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              expandedHeight: 180.0,
              pinned: true,
              floating: false,
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(icon: const Icon(Icons.cast, color: Colors.black), onPressed: () {}),
                IconButton(icon: const Icon(Icons.search, color: Colors.black), onPressed: () {}),
                IconButton(icon: const Icon(Icons.more_vert, color: Colors.black), onPressed: () {}),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: bannerImageUrl != null && bannerImageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: bannerImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) =>
                            Container(color: Colors.grey[200]),
                      )
                    : Container(color: Colors.grey[200]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: profileImageUrl != null &&
                                  profileImageUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(profileImageUrl!)
                              : null,
                          child: profileImageUrl == null ||
                                  profileImageUrl!.isEmpty
                              ? Icon(Icons.person,
                                  size: 40, color: Colors.grey[600])
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$_followersCount subscribers",
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (bio.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          bio,
                          style: const TextStyle(
                              color: Colors.black87, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (!_isCurrentUser)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing
                                ? Colors.grey[200]
                                : Colors.black,
                            foregroundColor:
                                _isFollowing ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                          ),
                          child: Text(
                              _isFollowing ? "Unsubscribe" : "Subscribe",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: Colors.black,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  tabs: _tabs.map((String name) => Tab(text: name)).toList(),
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: const [
            HomeTab(),
            PostsTab(),
            VideosTab(),
            ShortsTab(),
            LiveTab(),
            PodcastsTab(),
            AboutTab(),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
