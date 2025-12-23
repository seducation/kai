import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:appwrite/appwrite.dart';

import 'features/feed/models/feed_item.dart';
import 'features/feed/models/post_item.dart';
import 'features/feed/models/ad_item.dart';
import 'features/feed/models/carousel_item.dart';
import 'features/feed/controllers/feed_controller.dart';
import 'features/feed/widgets/post_card.dart';
import 'features/feed/widgets/ad_card.dart';
import 'features/feed/widgets/carousel_widget.dart';

class HmvVideosTabScreen extends StatefulWidget {
  const HmvVideosTabScreen({super.key});

  @override
  State<HmvVideosTabScreen> createState() => _HmvVideosTabScreenState();
}

class _HmvVideosTabScreenState extends State<HmvVideosTabScreen> {
  late FeedController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _isControllerInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isControllerInitialized) {
      _controller = FeedController(
        client: context.read<Client>(),
        userId: context.read<String>(),
        postType: 'video',
      );
      _controller.loadFeed(); // Initial data fetch
      _isControllerInitialized = true;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _controller.loadFeed();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (_isControllerInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isControllerInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Videos'),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
          ],
        ),
        body: Consumer<FeedController>(
          builder: (context, controller, child) {
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
                      'Failed to load videos',
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

            if (controller.isLoading && controller.feedItems.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!controller.isLoading && controller.feedItems.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.video_library_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No videos yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Follow users to see their videos',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => controller.refresh(),
              child: ListView.builder(
                controller: _scrollController,
                itemCount:
                    controller.feedItems.length + (controller.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= controller.feedItems.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final item = controller.feedItems[index];
                  return _buildFeedItem(item, controller);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeedItem(FeedItem item, FeedController controller) {
    switch (item.type) {
      case 'post':
        return PostCard(
          post: item as PostItem,
          controller: controller,
          onTap: () {
            // Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: item)));
          },
        );
      case 'ad':
        return AdCard(ad: item as AdItem, controller: controller);
      case 'carousel':
        return CarouselWidget(
          carousel: item as CarouselItem,
          onItemTap: (itemId) {
            // Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: itemId)));
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
