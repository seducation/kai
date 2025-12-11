import 'package:flutter/material.dart';
import 'package:my_app/appwrite_client.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/post_detail_screen.dart';

enum PostType { text, image, video }

class User {
  final String name;
  final String avatarUrl;

  User({
    required this.name,
    required this.avatarUrl,
  });
}

class Post {
  final String id;
  final User author;
  final String? mediaUrl;
  final String caption;
  final PostType type;

  Post({
    required this.id,
    required this.author,
    this.mediaUrl,
    required this.caption,
    required this.type,
  });
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late AppwriteService _appwriteService;
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _appwriteService = AppwriteService(AppwriteClient().client);
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      final postsResponse = await _appwriteService.getPosts();
      final posts = await Future.wait(postsResponse.rows.map((row) async {
        final authorProfile =
            await _appwriteService.getProfile(row.data['profile_id']);
        final author = User(
          name: authorProfile.data['name'],
          avatarUrl: authorProfile.data['profileImageUrl'],
        );
        return Post(
          id: row.$id,
          author: author,
          mediaUrl: row.data['mediaUrl'],
          caption: row.data['caption'],
          type: _getPostType(row.data['type']),
        );
      }));

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  PostType _getPostType(String? type) {
    switch (type) {
      case 'image':
        return PostType.image;
      case 'video':
        return PostType.video;
      default:
        return PostType.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.red),
                  ))
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      if (post.mediaUrl == null) {
                        return Container(color: Colors.grey[800]);
                      }
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PostDetailScreen(post: post),
                            ),
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              post.mediaUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return Container(color: Colors.grey[900]);
                              },
                              errorBuilder: (ctx, err, stack) =>
                                  Container(color: Colors.grey[900]),
                            ),
                            if (post.type == PostType.video)
                              const Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ));
  }
}
