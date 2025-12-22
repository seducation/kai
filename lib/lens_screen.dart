import 'package:appwrite/appwrite.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
// import 'package:image_picker/image_picker.dart'; // Removed unused import
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/camera_screen.dart'; // Added import
import 'package:my_app/webview_screen.dart';
import 'package:provider/provider.dart';

class LensScreen extends StatefulWidget {
  const LensScreen({super.key});

  @override
  State<LensScreen> createState() => _LensScreenState();
}

class _LensScreenState extends State<LensScreen> {
  final List<models.Row> _items = [];
  bool _isLoading = false;
  String? _error;
  bool _hasMore = true;
  String? _lastRowId;
  AppwriteService? _appwriteService;
  bool _isCameraOpen = false; // Added state

  final _scrollController = ScrollController();
  // final ImagePicker _picker = ImagePicker(); // Removed ImagePicker

  @override
  void initState() {
    super.initState();
    _appwriteService = context.read<AppwriteService>();
    _fetchData();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _fetchData();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _appwriteService!.getImages(cursor: _lastRowId);

      if (response.rows.isNotEmpty) {
        setState(() {
          _items.addAll(response.rows);
          _lastRowId = response.rows.last.$id;
          if (response.rows.length < 10) {
            _hasMore = false;
          }
        });
      } else {
        setState(() {
          _hasMore = false;
        });
      }
    } on AppwriteException catch (e) {
      setState(() {
        _error = e.message;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _items.clear();
      _lastRowId = null;
      _hasMore = true;
    });
    await _fetchData();
  }

  void _onCameraTap() {
    setState(() {
      _isCameraOpen = true;
    });
  }

  Future<void> _closeCamera({bool refreshed = false}) async {
    setState(() {
      _isCameraOpen = false;
    });
    if (refreshed) {
      await _refreshData();
    }
  }

  void _launchUrl(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WebViewScreen(url: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCameraOpen) {
      return CameraScreen(
        onClose: () => _closeCamera(),
        onImageUploaded: () => _closeCamera(refreshed: true),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            title: const Text('gvone'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshData,
              ),
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  context.push('/profile');
                },
              ),
            ],
            pinned: true,
            floating: true,
          ),
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: _onCameraTap, // Changed to _onCameraTap
              child: const Card(
                margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined),
                      SizedBox(width: 8),
                      Text('Camera'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error: $_error'),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(4.0),
            sliver: SliverGrid(
              gridDelegate: SliverQuiltedGridDelegate(
                crossAxisCount: 2,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                pattern: const [
                  QuiltedGridTile(2, 2),
                  QuiltedGridTile(1, 1),
                  QuiltedGridTile(1, 1),
                ],
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = _items[index];
                final isBigTile = (index % 3) == 0;
                return GestureDetector(
                  onTap: () {
                    if (item.data['link'] != null) {
                      // Using 'link' field
                      _launchUrl(item.data['link']);
                    }
                  },
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.data['imageUrl'] != null)
                          Expanded(
                            child: CachedNetworkImage(
                              imageUrl: item.data['imageUrl'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            ),
                          ),
                        if (item.data['title'] != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              item.data['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (item.data['description'] != null && !isBigTile)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Text(
                              item.data['description'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }, childCount: _items.length),
            ),
          ),
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
