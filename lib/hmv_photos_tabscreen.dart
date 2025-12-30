import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/auth_service.dart';
import 'package:provider/provider.dart';

// Feed imports
import 'features/feed/controllers/feed_controller.dart';
import 'features/feed/models/post_item.dart' as feed_models;

class HmvPhotosTabscreen extends StatefulWidget {
  const HmvPhotosTabscreen({super.key});

  @override
  State<HmvPhotosTabscreen> createState() => _HmvPhotosTabscreenState();
}

class _HmvPhotosTabscreenState extends State<HmvPhotosTabscreen> {
  late FeedController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final appwriteService = context.read<AppwriteService>();
    final authService = context.read<AuthService>();

    _controller = FeedController(
      client: appwriteService.client,
      userId: authService.currentUser?.id ?? '',
      postType: 'image',
    );

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _controller.loadFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        body: Consumer<FeedController>(
          builder: (context, controller, child) {
            if (controller.isLoading && controller.feedItems.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.feedItems.isEmpty) {
              if (controller.error != null) {
                return Center(child: Text('Error: ${controller.error}'));
              }
              return const Center(child: Text("No photos available."));
            }

            return RefreshIndicator(
              onRefresh: () => controller.refresh(),
              child: GridView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 3 items per row
                  crossAxisSpacing: 4, // spacing between columns
                  mainAxisSpacing: 4, // spacing between rows
                ),
                itemCount: controller.feedItems.length + 1,
                itemBuilder: (context, index) {
                  if (index == controller.feedItems.length) {
                    return controller.isLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : const SizedBox.shrink();
                  }

                  final item =
                      controller.feedItems[index]; // Use feedItems directly

                  // For GridView, we just need the image URL and ID.
                  // We can get this directly from FeedItem if it's a PostItem
                  if (item is! feed_models.PostItem) {
                    return const SizedBox.shrink();
                  }

                  if (item.mediaUrls.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return GestureDetector(
                    onTap: () {
                      context.push('/post/${item.postId}');
                    },
                    child: CachedNetworkImage(
                      imageUrl: item.mediaUrls.first,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
