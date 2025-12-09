import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/add_product.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/auth_service.dart';
import 'package:my_app/model/profile.dart';
import 'package:my_app/tabs/about_tab.dart';
import 'package:my_app/tabs/home_tab.dart';
import 'package:my_app/tabs/live_tab.dart';
import 'package:my_app/tabs/podcasts_tab.dart';
import 'package:my_app/tabs/posts_tab.dart';
import 'package:my_app/tabs/products_tab.dart';
import 'package:my_app/tabs/shorts_tab.dart';
import 'package:my_app/tabs/videos_tab.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class ProfilePageScreen extends StatefulWidget {
  final String profileId;
  const ProfilePageScreen({super.key, required this.profileId});

  @override
  State<ProfilePageScreen> createState() => _ProfilePageScreenState();
}

class _ProfilePageScreenState extends State<ProfilePageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AppwriteService _appwriteService;
  late AuthService _authService;
  Profile? _profile;
  String? _currentUserId;

  bool _isFollowing = false;
  int _followersCount = 0;
  bool _isLoading = true;

  List<String> _tabs = [];

  @override
  void initState() {
    super.initState();
    _appwriteService = context.read<AppwriteService>();
    _authService = context.read<AuthService>();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final user = await _authService.getCurrentUser();
      if (!mounted) return;
      _currentUserId = user?.id;

      final profile = await _appwriteService.getProfile(widget.profileId);
      if (!mounted) return;
      final followers = List<String>.from(profile.data['followers'] ?? []);

      setState(() {
        _profile = Profile.fromMap(profile.data, profile.$id);
        _followersCount = followers.length;
        if (_currentUserId != null) {
          _isFollowing = followers.contains(_currentUserId);
        }

        _tabs = _getTabsForProfile(_profile);
        _tabController = TabController(length: _tabs.length, vsync: this);

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      // Handle error, maybe show a snackbar
    }
  }

  List<String> _getTabsForProfile(Profile? profile) {
    final baseTabs = [
      "Home",
      "Posts",
      "Videos",
      "Shorts",
      "Live",
      "Podcasts",
    ];
    if (profile?.type == 'business') {
      baseTabs.add("Products");
    }
    baseTabs.add("About");
    return baseTabs;
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null) {
      // Maybe prompt user to log in
      return;
    }

    final originalFollowState = _isFollowing;
    final originalFollowersCount = _followersCount;

    setState(() {
      _isFollowing = !_isFollowing;
      if (_isFollowing) {
        _followersCount++;
      } else {
        _followersCount--;
      }
    });

    try {
      if (_isFollowing) {
        await _appwriteService.followProfile(
          profileId: widget.profileId,
          followerId: _currentUserId!,
        );
      } else {
        await _appwriteService.unfollowProfile(
          profileId: widget.profileId,
          followerId: _currentUserId!,
        );
      }
    } catch (e) {
      // Revert state on error
      setState(() {
        _isFollowing = originalFollowState;
        _followersCount = originalFollowersCount;
      });
      // Handle error, maybe show a snackbar
    }
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _profile?.name);
    final bioController = TextEditingController(text: _profile?.bio);
    
    // Store the Navigator and ScaffoldMessenger before the async gap.
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: bioController,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () async {
                if (_profile == null) return;
                try {
                  await _appwriteService.updateProfile(
                    profileId: _profile!.id,
                    data: {
                      'name': nameController.text,
                      'bio': bioController.text,
                    },
                  );
                  
                  // Use the cached navigator to pop the dialog
                  navigator.pop();
                  _loadProfileData(); // Reload data to show changes
                } catch (e) {
                  // Use the cached scaffoldMessenger to show a snackbar
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to update profile: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUser =
        _currentUserId != null && _currentUserId == _profile?.ownerId;
    final accountTypes = ['profile', 'channel', 'thread', 'business'];
    final showEditButton =
        isCurrentUser && _profile != null && accountTypes.contains(_profile!.type);

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text("Profile not found"))
              : NestedScrollView(
                  headerSliverBuilder:
                      (BuildContext context, bool innerBoxIsScrolled) {
                    return <Widget>[
                      SliverAppBar(
                        expandedHeight: 180.0,
                        pinned: true,
                        floating: false,
                        backgroundColor: Colors.white,
                        leading: IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () => context.pop(),
                        ),
                        actions: [
                          IconButton(
                              icon: const Icon(Icons.cast, color: Colors.black),
                              onPressed: () {}),
                          IconButton(
                              icon:
                                  const Icon(Icons.search, color: Colors.black),
                              onPressed: () {}),
                          IconButton(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.black),
                              onPressed: () {}),
                        ],
                        flexibleSpace: FlexibleSpaceBar(
                          background: _profile!.profileImageUrl != null &&
                                  _profile!.profileImageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _profile!.profileImageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Shimmer.fromColors(
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
                                    backgroundImage: _profile!
                                                .profileImageUrl !=
                                            null &&
                                            _profile!
                                                .profileImageUrl!.isNotEmpty
                                        ? CachedNetworkImageProvider(
                                            _profile!.profileImageUrl!)
                                        : null,
                                    child: _profile!.profileImageUrl == null ||
                                            _profile!.profileImageUrl!.isEmpty
                                        ? Icon(Icons.person,
                                            size: 40, color: Colors.grey[600])
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _profile!.name,
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "$_followersCount followers",
                                          style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_profile!.bio != null &&
                                  _profile!.bio!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _profile!.bio!,
                                    style: const TextStyle(
                                        color: Colors.black87, fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              if (!isCurrentUser)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _toggleFollow,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isFollowing
                                          ? Colors.grey[200]
                                          : Colors.black,
                                      foregroundColor: _isFollowing
                                          ? Colors.black
                                          : Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(24)),
                                    ),
                                    child: Text(
                                        _isFollowing ? "Unfollow" : "Follow",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
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
                            tabs: _tabs
                                .map((String name) => Tab(text: name))
                                .toList(),
                          ),
                        ),
                        pinned: true,
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: _getTabViewsForProfile(_profile),
                  ),
                ),
      floatingActionButton: showEditButton
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_profile?.type == 'business')
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddProductScreen(),
                          ),
                        );
                      },
                      backgroundColor: Colors.black,
                      child: const Icon(Icons.shopping_bag),
                    ),
                  ),
                FloatingActionButton(
                  onPressed: _showEditProfileDialog,
                  backgroundColor: Colors.black,
                  child: const Icon(Icons.edit),
                ),
              ],
            )
          : null,
    );
  }

  List<Widget> _getTabViewsForProfile(Profile? profile) {
    final baseTabViews = [
      const HomeTab(),
      const PostsTab(),
      const VideosTab(),
      const ShortsTab(),
      const LiveTab(),
      const PodcastsTab(),
    ];
    if (profile?.type == 'business') {
      baseTabViews.add(const ProductsTab());
    }
    baseTabViews.add(const AboutTab());
    return baseTabViews;
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
