import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:appwrite/appwrite.dart';
import 'package:uuid/uuid.dart';

import 'package:my_app/environment.dart';
import '../models/feed_item.dart';

/// Feed controller manages feed state, pagination, and signal tracking
class FeedController extends ChangeNotifier {
  final Functions _functions;
  final TablesDB _databases;
  final String _userId;
  final String _postType;

  final List<FeedItem> _feedItems = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String _sessionId = '';
  int _offset = 0;
  String? _error;

  FeedController({
    required Client client,
    required String userId,
    String postType = 'all', // Add postType parameter with a default value
  }) : _functions = Functions(client),
       _databases = TablesDB(client),
       _userId = userId,
       _postType = postType {
    _sessionId = const Uuid().v4(); // Generate unique session ID
    loadFeed();
  }

  // Getters
  List<FeedItem> get feedItems => _feedItems;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String get sessionId => _sessionId;
  String get userId => _userId; // Added getter for userId

  /// Load feed from Cloud Function
  Future<void> loadFeed() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Call Cloud Function
      final execution = await _functions.createExecution(
        functionId: 'generate-feed', // Replace with your actual function ID
        body: jsonEncode({
          'sessionId': _sessionId,
          'offset': _offset,
          'limit': 20,
          'postType': _postType,
        }),
      );

      if (execution.responseStatusCode != 200) {
        throw Exception(
          'Function execution failed: ${execution.responseStatusCode}',
        );
      }

      final result = jsonDecode(execution.responseBody) as Map<String, dynamic>;

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Failed to load feed');
      }

      final List<dynamic> items = result['items'] as List<dynamic>;

      if (items.isEmpty) {
        _hasMore = false;
      } else {
        final newItems = items
            .map((item) => FeedItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _feedItems.addAll(newItems);
        _offset += items.length;
        _hasMore = result['hasMore'] ?? false;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading feed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh feed (reset and reload)
  Future<void> refresh() async {
    _feedItems.clear();
    _offset = 0;
    _hasMore = true;
    _sessionId = const Uuid().v4(); // New session
    await loadFeed();
  }

  /// Track user signal asynchronously (fire-and-forget)
  void trackSignal(String itemId, String signalType, {int? dwellTime}) {
    _databases
        .createRow(
          databaseId: Environment.appwriteDatabaseId,
          tableId: 'user_signals', // Ensure this table/collection exists
          rowId: ID.unique(),
          data: {
            'userId': _userId,
            'postId': itemId,
            'signalType': signalType,
            'dwellTime': dwellTime,
            'createdAt': DateTime.now().toIso8601String(),
          },
        )
        .catchError((e) {
          debugPrint('Signal tracking failed: $e');
          throw e;
        });
  }

  /// Track like action
  void trackLike(String itemId) {
    trackSignal(itemId, 'like');
  }

  /// Track comment action
  void trackComment(String itemId) {
    trackSignal(itemId, 'comment');
  }

  /// Track share action
  void trackShare(String itemId) {
    trackSignal(itemId, 'share');
  }

  /// Track skip (quick scroll past)
  void trackSkip(String itemId, int dwellTime) {
    if (dwellTime < 1000) {
      trackSignal(itemId, 'skip', dwellTime: dwellTime);
    }
  }

  /// Track dwell (viewed for a while)
  void trackDwell(String itemId, int dwellTime) {
    if (dwellTime > 3000) {
      trackSignal(itemId, 'dwell', dwellTime: dwellTime);
    }
  }
}
