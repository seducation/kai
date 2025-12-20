import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/comments_screen.dart';
import 'package:my_app/model/post.dart';
import 'package:my_app/model/profile.dart';
import 'package:my_app/profile_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:url_launcher/url_launcher.dart';


class PostItem extends StatefulWidget {
  final Post post;
  final String profileId;

  const PostItem({super.key, required this.post, required this.profileId});

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  late bool _isLiked;
  late bool _isSaved;
  late int _likeCount;
  int _commentCount = 0;
  late AppwriteService _appwriteService;
  SharedPreferences? _prefs;
  VideoPlayerController? _controller;
  String? _authorName;

  @override
  void initState() {
    super.initState();
    _appwriteService = context.read<AppwriteService>();
    _isLiked = false;
    _isSaved = false;
    _likeCount = widget.post.stats.likes;
    _commentCount = widget.post.stats.comments;
    _initializeState();

    if (widget.post.type == PostType.video && widget.post.mediaUrl != null) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.post.mediaUrl!))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
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
    _fetchAuthorName();
    if(mounted){
      setState(() {
        _isLiked = _prefs?.getBool(widget.post.id) ?? false;
        _isSaved = _prefs?.getBool('saved_${widget.post.id}') ?? false;
      });
    }
  }

  Future<void> _fetchAuthorName() async {
    if (widget.post.originalAuthor != null) {
      try {
        final Profile authorProfile = await _appwriteService.getProfile(widget.post.originalAuthor!.id);
        if (mounted) {
          setState(() {
            _authorName = authorProfile.name;
          });
        }
      } catch (e) {
        // Handle error if needed
      }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You must be logged in to like posts.'),
      ));
      return;
    }
    
    final newLikedState = !_isLiked;
    final newLikeCount = newLikedState ? _likeCount + 1 : _likeCount - 1;

    if(mounted){
      setState(() {
        _isLiked = newLikedState;
        _likeCount = newLikeCount;
      });
    }

    try {
      await _appwriteService.updatePostLikes(widget.post.id, newLikeCount, widget.post.timestamp.toIso8601String());
      await _prefs!.setBool(widget.post.id, newLikedState);
    } catch (e) {
      if(mounted){
        setState(() {
          _isLiked = !newLikedState;
          _likeCount = _isLiked ? newLikeCount + 1 : newLikeCount -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
        ));
      }
    }
  }

  Future<void> _toggleSaved() async {
    if (_prefs == null) return;
    final user = await _appwriteService.getUser();
    if (!mounted) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You must be logged in to save posts.'),
      ));
      return;
    }
    
    final newSavedState = !_isSaved;

    if(mounted){
      setState(() {
        _isSaved = newSavedState;
      });
    }

    try {
      if (newSavedState) {
        await _appwriteService.savePost(profileId: widget.profileId, postId: widget.post.id);
      } else {
        await _appwriteService.unsavePost(profileId: widget.profileId, postId: widget.post.id);
      }
      await _prefs!.setBool('saved_${widget.post.id}', newSavedState);
    } catch (e) {
      if(mounted){
        setState(() {
          _isSaved = !newSavedState;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update saved status. Please try again.'),
        ));
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
    if (_prefs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (widget.post.contentText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Text(
                widget.post.contentText,
                style: const TextStyle(fontSize: 15, height: 1.3),
              ),
            ),
          _buildMedia(context),
          if (widget.post.linkTitle != null && widget.post.linkTitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Text(
                widget.post.linkTitle!,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: _buildActionBar(),
          ),
          const Divider(height: 1, color: Color(0xFFE0E0E0)),
        ],
      ),
    );
  }

  Widget _buildMedia(BuildContext context) {
    switch (widget.post.type) {
      case PostType.image:
        return _buildImageContent(context);
      case PostType.video:
        if (_controller != null && _controller!.value.isInitialized) {
          return AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller!),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                    });
                  },
                  child: Icon(
                    _controller!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: const Color.fromRGBO(255, 255, 255, 0.7),
                    size: 60,
                  ),
                ),
              ],
            ),
          );
        } else {
          return Container(height: 250, color: Colors.grey[300], child: const Center(child: CircularProgressIndicator()));
        }
      case PostType.linkPreview:
        return _buildLinkPreview(context);
      default:
        return const SizedBox.shrink();
    }
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
                  Row(
                    children: [
                      Text(
                        widget.post.author.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      ),
                      if (widget.post.originalAuthor != null)
                        Flexible(
                          child: Row(
                            children: [
                              const SizedBox(width: 4),
                              Text(
                                'by',
                                style: TextStyle(color: handleColor, fontSize: 14),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _authorName ?? widget.post.originalAuthor!.id,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  Text(
                     timeago.format(widget.post.timestamp),
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
        // Handle image tap if necessary
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
    if (widget.post.linkUrl == null) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: () async {
         final url = Uri.parse(widget.post.linkUrl!);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.inAppWebView);
          }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: AnyLinkPreview(
            link: widget.post.linkUrl!,
            displayDirection: UIDirection.uiDirectionHorizontal,
            showMultimedia: true,
            bodyMaxLines: 3,
            bodyTextOverflow: TextOverflow.ellipsis,
            titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            bodyStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
            errorWidget: Container(height: 100, color: Colors.grey[300], child: const Center(child: Text('Could not load preview'))),
            cache: const Duration(days: 7),
            backgroundColor: Colors.grey[100],
            borderRadius: 8,
            removeElevation: true,
            urlLaunchMode: LaunchMode.inAppWebView,
          )
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
            const SizedBox(width: 24),
            GestureDetector(
              onTap: _openComments,
              child: _buildActionItem(Icons.comment, _commentCount.toString()),
            ),
            const SizedBox(width: 24),
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
            const SizedBox(width: 24),
            Icon(Icons.share, color: Colors.grey[600], size: 22),
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
          style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
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
