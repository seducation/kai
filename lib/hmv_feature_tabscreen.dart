import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:appwrite/appwrite.dart';

import 'features/feed/models/feed_item.dart';
import 'features/feed/models/post_item.dart' as feed_models;
import 'features/feed/models/ad_item.dart';
import 'features/feed/models/carousel_item.dart';
import 'features/feed/controllers/feed_controller.dart';
import 'features/feed/widgets/ad_card.dart';
import 'features/feed/widgets/carousel_widget.dart';

import 'package:my_app/widgets/post_item.dart' as widgets;
import 'package:my_app/model/post.dart' as model;
import 'package:my_app/model/profile.dart' as profile_model;

/// Main feed screen (HMV Feature Tab)
/// This is the primary social media feed using the advanced ranking algorithm
class HmvFeatureTabScreen extends StatefulWidget {
  const HmvFeatureTabScreen({super.key});

  @override
  State<HmvFeatureTabScreen> createState() => _HmvFeatureTabScreenState();
}

class _HmvFeatureTabScreenState extends State<HmvFeatureTabScreen> {
  late FeedController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Initialize feed controller
    // Note: You'll need to inject AppwriteService dependencies
    // This is a placeholder - adjust according to your actual Appwrite setup
    _controller = FeedController(
      client: context.read<Client>(),
      userId: context
          .read<String>(), // Replace with actual user ID provider if available
    );

    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Trigger pagination when user scrolls to 80% of content
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _controller.loadFeed();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feed'),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                // Navigate to notifications
              },
            ),
          ],
        ),
        body: Consumer<FeedController>(
          builder: (context, controller, child) {
            // Error state
            if (controller.error != null && controller.feedItems.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load feed',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => controller.refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            // Empty state (initial load)
            if (!controller.isLoading && controller.feedItems.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.feed_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No posts yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Follow some users to see their posts',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            // Feed list
            return RefreshIndicator(
              onRefresh: () => controller.refresh(),
              child: ListView.builder(
                controller: _scrollController,
                itemCount:
                    controller.feedItems.length +
                    (controller.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  // Loading indicator at bottom
                  if (index >= controller.feedItems.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final item = controller.feedItems[index];

                  // Render appropriate widget based on type
                  return _buildFeedItem(item, controller);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  model.Post _convertToModelPost(feed_models.PostItem item) {
    // Infer post type from media
    model.PostType type = model.PostType.text;
    if (item.mediaUrls.isNotEmpty) {
      final firstUrl = item.mediaUrls.first.toLowerCase();
      if (firstUrl.endsWith('.mp4') ||
          firstUrl.endsWith('.mov') ||
          firstUrl.endsWith('.avi')) {
        type = model.PostType.video;
      } else {
        type = model.PostType.image;
      }
    }

    return model.Post(
      id: item.postId,
      author: profile_model.Profile(
        id: item.userId,
        name: item.username,
        type: 'profile', // Default
        profileImageUrl: item.profileImage,
        ownerId: '', // Unknown from feed item
        createdAt: DateTime.now(), // Unknown from feed item
      ),
      timestamp: item.createdAt,
      contentText: item.content,
      type: type,
      mediaUrls: item.mediaUrls,
      stats: model.PostStats(
        likes: item.engagementScore, // Approximate
        views: item.viewCount,
      ),
    );
  }

  /// Build appropriate widget for each feed item type
  Widget _buildFeedItem(FeedItem item, FeedController controller) {
    switch (item.type) {
      case 'post':
        if (item is! feed_models.PostItem) return const SizedBox.shrink();
        return widgets.PostItem(
          post: _convertToModelPost(item),
          profileId: controller.userId,
        );

      case 'ad':
        return AdCard(ad: item as AdItem, controller: controller);

      case 'carousel':
        return CarouselWidget(
          carousel: item as CarouselItem,
          onItemTap: (itemId) {
            // Handle carousel item tap
            // Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: itemId)));
          },
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
