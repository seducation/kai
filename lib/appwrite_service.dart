import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:appwrite/enums.dart';
import 'package:my_app/environment.dart';

import 'package:my_app/model/post.dart';
import 'package:my_app/model/profile.dart';
import 'package:my_app/utils/handle_system.dart';
import 'package:my_app/calls/models/call_models.dart';

class AppwriteService {
  final Client _client;
  late TablesDB _db;
  late Storage _storage;
  late Account _account;
  late Functions _functions;
  late Realtime _realtime;

  Client get client => _client;

  static const String profilesCollection = "profiles";
  static const String messagesCollection = "messages";
  static const String postsCollection = "posts";
  static const String imagesCollection = "images";
  static const String commentsCollection = "comments";
  static const String productsCollection = "products";
  static const String playlistsCollection = "playlists";
  static const String storiesCollection = "stories";
  static const String notificationsCollection = "notifications";
  static const String callsCollection = "calls";
  static const String savedPostsCollection = "saved_posts";
  static const String likesCollection = "likes";
  static const String followsCollection = "follows";

  AppwriteService(this._client) {
    _db = TablesDB(_client);
    _storage = Storage(_client);
    _account = Account(_client);
    _functions = Functions(_client);
    _realtime = Realtime(_client);
  }

  Future<String> getLiveKitToken({required String roomName}) async {
    final user = await getUser();
    if (user == null) {
      throw AppwriteException('User not authenticated', 401);
    }

    try {
      final result = await _functions.createExecution(
        functionId: 'generate-livekit-token',
        body: '{"roomName": "$roomName", "userId": "${user.$id}"}',
      );
      final response = jsonDecode(result.responseBody);
      if (response.containsKey('error')) {
        throw AppwriteException(response['error']);
      }
      return response['token'];
    } on AppwriteException catch (e) {
      log('Error getting LiveKit token: ${e.message}');
      rethrow;
    }
  }

  Future<models.User> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final user = await _account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<models.Session> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final session = await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      return session;
    } catch (e) {
      rethrow;
    }
  }

  Future<models.User?> getUser() async {
    try {
      final user = await _account.get();
      return user;
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (e) {
      rethrow;
    }
  }

  Future<models.Row> createProfile({
    required String name,
    required String type,
    required String bio,
    required String handle,
    required String location,
    required String profileImageUrl,
    required String bannerImageUrl,
  }) async {
    final user = await getUser();
    if (user == null) {
      throw AppwriteException('User not authenticated', 401);
    }
    final ownerId = user.$id;

    final fingerprint = HandleSystem.generateFingerprint(handle);

    // Initial check (optional but good for UX)
    if (!await isHandleAvailable(handle)) {
      throw AppwriteException(
        'Handle is already taken or visually similar to an existing one.',
        409,
      );
    }

    return await _db.createRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: profilesCollection,
      rowId: ID.unique(),
      data: {
        'ownerId': ownerId,
        'name': name,
        'type': type,
        'bio': bio,
        'handle': handle,
        'currentHandle': handle,
        'reservedHandles': [handle],
        'handleFingerprints': [fingerprint],
        'lastHandleChangeAt': DateTime.now().toIso8601String(),
        'location': location,
        'profileImageUrl': profileImageUrl,
        'bannerImageUrl': bannerImageUrl,
      },
      permissions: [
        Permission.read(Role.any()),
        Permission.update(Role.user(ownerId)),
        Permission.delete(Role.user(ownerId)),
      ],
    );
  }

  Future<bool> isHandleAvailable(String handle) async {
    final fingerprint = HandleSystem.generateFingerprint(handle);

    try {
      final result = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: profilesCollection,
        queries: [Query.equal('handleFingerprints', fingerprint)],
      );
      return result.total == 0;
    } catch (e) {
      log('Error checking handle availability: $e');
      return false;
    }
  }

  Future<models.Row> updateUserHandle({
    required String profileId,
    required String newHandle,
  }) async {
    final profile = await getProfile(profileId);
    final lastChangeAt = profile.data['lastHandleChangeAt'];

    // Check cooldown (7 days)
    if (!HandleSystem.canChangeHandle(lastChangeAt)) {
      final remaining = HandleSystem.remainingCooldown(lastChangeAt);
      throw AppwriteException(
        'Handle change is on cooldown. Try again in ${remaining.inHours} hours.',
        403,
      );
    }

    final fingerprint = HandleSystem.generateFingerprint(newHandle);

    // Check availability
    if (!await isHandleAvailable(newHandle)) {
      throw AppwriteException(
        'Handle is already taken or visually similar to an existing one.',
        409,
      );
    }

    final List<String> reservedHandles = List<String>.from(
      profile.data['reservedHandles'] ?? [],
    );
    final List<String> handleFingerprints = List<String>.from(
      profile.data['handleFingerprints'] ?? [],
    );

    if (!reservedHandles.contains(newHandle)) {
      reservedHandles.add(newHandle);
    }
    if (!handleFingerprints.contains(fingerprint)) {
      handleFingerprints.add(fingerprint);
    }

    return await updateProfile(
      profileId: profileId,
      data: {
        'handle': newHandle,
        'currentHandle': newHandle,
        'reservedHandles': reservedHandles,
        'handleFingerprints': handleFingerprints,
        'lastHandleChangeAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<models.Row> updateProfile({
    required String profileId,
    required Map<String, dynamic> data,
  }) async {
    return await _db.updateRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: profilesCollection,
      rowId: profileId,
      data: data,
    );
  }

  Future<models.RowList> searchProfiles({required String query}) async {
    final results = await Future.wait([
      _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: profilesCollection,
        queries: [],
      ),
      _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: profilesCollection,
        queries: [],
      ),
    ]);

    final allProfiles = <String, models.Row>{};
    for (final result in results) {
      for (final doc in result.rows) {
        allProfiles[doc.$id] = doc;
      }
    }

    return models.RowList(
      total: allProfiles.length,
      rows: allProfiles.values.toList(),
    );
  }

  Future<models.RowList> getUserProfiles({required String ownerId}) async {
    return await _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: profilesCollection,
      queries: [Query.equal('ownerId', ownerId)],
    );
  }

  Future<models.Row> getProfile(String profileId) async {
    return await _db.getRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: profilesCollection,
      rowId: profileId,
    );
  }

  Future<models.RowList> getProfiles() async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: profilesCollection,
      queries: [],
    );
  }

  Future<void> followEntity({
    required String senderId,
    required String targetId,
    required bool isAnonymous,
    String targetType = 'profile', // Default to profile
  }) async {
    try {
      // Check if already following (schema now includes target_type in unique index)
      final existing = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: followsCollection,
        queries: [
          Query.equal('follower_id', senderId),
          Query.equal('target_id', targetId),
          Query.equal('target_type', targetType),
        ],
      );

      if (existing.total == 0) {
        await _db.createRow(
          databaseId: Environment.appwriteDatabaseId,
          tableId: followsCollection,
          rowId: ID.unique(),
          data: {
            'follower_id': senderId,
            'target_id': targetId,
            'follower_type': isAnonymous ? 'private' : 'public',
            'target_type': targetType,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      log('Error following entity: $e');
      rethrow;
    }
  }

  Future<void> unfollowEntity({
    required String senderId,
    required String targetId,
    String targetType = 'profile',
  }) async {
    try {
      final existing = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: followsCollection,
        queries: [
          Query.equal('follower_id', senderId),
          Query.equal('target_id', targetId),
          Query.equal('target_type', targetType),
        ],
      );

      if (existing.total > 0) {
        await _db.deleteRow(
          databaseId: Environment.appwriteDatabaseId,
          tableId: followsCollection,
          rowId: existing.rows.first.$id,
        );
      }
    } catch (e) {
      log('Error unfollowing entity: $e');
      rethrow;
    }
  }

  Future<bool> isFollowing({
    required String currentUserId,
    required String targetId,
    String targetType = 'profile',
    String? activeIdentityId, // Optional: for UI button state specifically
  }) async {
    try {
      // 1. Check Global State (Does ANY of my personas follow this?)
      // We need to fetch all profiles owned by the user
      final userProfiles = await getUserProfiles(ownerId: currentUserId);
      final ownedIds = userProfiles.rows.map((p) => p.$id).toList();

      if (ownedIds.isEmpty) return false;

      final globalCheck = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: followsCollection,
        queries: [
          Query.equal('follower_id', ownedIds),
          Query.equal('target_id', targetId),
          Query.equal('target_type', targetType),
          Query.limit(1), // We just need to know if ANY exist
        ],
      );

      return globalCheck.total > 0;
    } catch (e) {
      log('Error checking isFollowing: $e');
      return false;
    }
  }

  Future<int> getFollowerCount({required String targetId}) async {
    try {
      final result = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: followsCollection,
        queries: [
          Query.equal('target_id', targetId),
          Query.limit(0), // Count only
        ],
      );
      return result.total;
    } catch (e) {
      log('Error getting follower count: $e');
      return 0;
    }
  }

  // Helper to be used if we need legacy profile ID fetching (temporarily kept or refactored)
  // Renamed to clarify it fetches the MAIN profile ID.
  Future<String?> getMainUserProfileId(String userId) async {
    try {
      final profiles = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: profilesCollection,
        queries: [
          Query.equal('ownerId', userId),
          Query.equal('type', 'profile'),
        ],
      );

      if (profiles.total > 0) {
        return profiles.rows.first.$id;
      }
      return null;
    } catch (e) {
      log('Error getting main user profile ID: $e');
      return null;
    }
  }

  Future<void> savePost({
    required String profileId,
    required String postId,
  }) async {
    final user = await getUser();
    if (user == null) {
      throw AppwriteException('User not authenticated', 401);
    }

    try {
      // Check if already saved
      final existing = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: savedPostsCollection,
        queries: [
          Query.equal('profile_id', profileId),
          Query.equal('post_id', postId),
        ],
      );

      if (existing.total == 0) {
        await _db.createRow(
          databaseId: Environment.appwriteDatabaseId,
          tableId: savedPostsCollection,
          rowId: ID.unique(),
          data: {
            'profile_id': profileId,
            'post_id': postId,
            'timestamp': DateTime.now().toIso8601String(),
          },
          permissions: [
            Permission.read(Role.user(user.$id)),
            Permission.update(Role.user(user.$id)),
            Permission.delete(Role.user(user.$id)),
          ],
        );
      }
    } catch (e) {
      log('Error saving post: $e');
      rethrow;
    }
  }

  Future<void> unsavePost({
    required String profileId,
    required String postId,
  }) async {
    try {
      final existing = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: savedPostsCollection,
        queries: [
          Query.equal('profile_id', profileId),
          Query.equal('post_id', postId),
        ],
      );

      if (existing.total > 0) {
        await _db.deleteRow(
          databaseId: Environment.appwriteDatabaseId,
          tableId: savedPostsCollection,
          rowId: existing.rows.first.$id,
        );
      }
    } catch (e) {
      log('Error unsaving post: $e');
      rethrow;
    }
  }

  Future<models.RowList> getFollowingProfiles({
    String? userId,
    String? followerId,
  }) async {
    try {
      String? idToUse = followerId;
      if (idToUse == null && userId != null) {
        idToUse = await getMainUserProfileId(userId);
      }

      if (idToUse == null) return models.RowList(total: 0, rows: []);

      final follows = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: followsCollection,
        queries: [Query.equal('follower_id', idToUse)],
      );

      if (follows.total == 0) return models.RowList(total: 0, rows: []);

      final followingIds = follows.rows
          .map((row) => row.data['target_id'] as String)
          .toList();

      return await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: profilesCollection,
        queries: [Query.equal('\$id', followingIds)],
      );
    } catch (e) {
      log('Error getting following profiles: $e');
      return models.RowList(total: 0, rows: []);
    }
  }

  Future<models.RowList> getFollowerProfiles({
    String? userId,
    String? profileId,
  }) async {
    try {
      String? idToUse = profileId;
      if (idToUse == null && userId != null) {
        idToUse = await getMainUserProfileId(userId);
      }

      if (idToUse == null) return models.RowList(total: 0, rows: []);

      // Query follows where target_id is the current profile
      final followers = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: followsCollection,
        queries: [Query.equal('target_id', idToUse)],
      );

      if (followers.total == 0) return models.RowList(total: 0, rows: []);

      final followerIds = followers.rows
          .map((row) => row.data['follower_id'] as String)
          .toList();

      return await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: profilesCollection,
        queries: [Query.equal('\$id', followerIds)],
      );
    } catch (e) {
      log('Error getting follower profiles: $e');
      return models.RowList(total: 0, rows: []);
    }
  }

  String _getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return ids.join('_');
  }

  Future<models.Row> sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    final chatId = _getChatId(senderId, receiverId);

    final newDocument = await _db.createRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: messagesCollection,
      rowId: ID.unique(),
      data: {'chatId': chatId, 'senderId': senderId, 'message': message},
    );

    try {
      return await _db.updateRow(
        databaseId: Environment.appwriteDatabaseId,
        tableId: messagesCollection,
        rowId: newDocument.$id,
        permissions: [
          Permission.read(Role.user(senderId)),
          Permission.update(Role.user(senderId)),
          Permission.delete(Role.user(senderId)),
          Permission.read(Role.user(receiverId)),
        ],
      );
    } on AppwriteException {
      // Silently fail, as the message is already delivered.
      // The root cause is the server-side permissions.
      return newDocument;
    }
  }

  Future<void> sendOneTimeMessages({
    required String senderId,
    required List<String> receiverIds,
    required String imagePath,
  }) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final filename = imagePath.split('/').last;

    for (final receiverId in receiverIds) {
      // Upload file for each recipient to allow independent deletion
      final file = await uploadFile(bytes: imageBytes, filename: filename);

      final chatId = _getChatId(senderId, receiverId);

      await _db.createRow(
        databaseId: Environment.appwriteDatabaseId,
        tableId: messagesCollection,
        rowId: ID.unique(),
        data: {
          'chatId': chatId,
          'senderId': senderId,
          'message': getFileViewUrl(file.$id),
          'isOtm': true,
          'fileId': file.$id,
        },
        permissions: [
          Permission.read(Role.user(senderId)),
          Permission.update(Role.user(senderId)),
          Permission.delete(Role.user(senderId)),
          Permission.read(Role.user(receiverId)),
        ],
      );
    }
  }

  Future<void> deleteMessage(String messageId) async {
    await _db.deleteRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: messagesCollection,
      rowId: messageId,
    );
  }

  Future<void> deleteFile(String fileId) async {
    await _storage.deleteFile(
      bucketId: Environment.appwriteStorageBucketId,
      fileId: fileId,
    );
  }

  Future<models.RowList> getMyOneTimeMessages(String currentUserId) async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: messagesCollection,
      queries: [
        Query.equal('isOtm', true),
        // We only want messages sent *to* us, filtering out ones we sent (if any show up due to permissions)
        Query.notEqual('senderId', currentUserId),
      ],
    );
  }

  Future<models.RowList> getMessages({
    required String userId1,
    required String userId2,
  }) async {
    final chatId = _getChatId(userId1, userId2);

    return await _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: messagesCollection,
      queries: [Query.equal('chatId', chatId)],
    );
  }

  Future<models.RowList> getAllMessages() async {
    return await _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: messagesCollection,
    );
  }

  Future<models.RowList> getPosts({List<String>? queries}) async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: postsCollection,
      queries: queries,
    );
  }

  Future<models.RowList> getPostsFromUsers(List<dynamic> profileIds) async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: postsCollection,
      queries: [Query.equal('profile_id', profileIds)],
    );
  }

  Future<void> createPost(Map<String, dynamic> postData) async {
    final user = await getUser();
    if (user == null) {
      throw AppwriteException('User not authenticated', 401);
    }
    final ownerId = user.$id;

    final data = {
      ...postData,
      'timestamp': DateTime.now().toIso8601String(),
      'author_id': postData['author_id'],
    };

    await _db.createRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: postsCollection,
      rowId: ID.unique(),
      data: data,
      permissions: [
        Permission.read(Role.any()),
        Permission.update(Role.user(ownerId)),
        Permission.delete(Role.user(ownerId)),
      ],
    );
  }

  Future<void> updatePostLikes(
    String postId,
    int likes,
    String timestamp,
  ) async {
    await _db.updateRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: postsCollection,
      rowId: postId,
      data: {'likes': likes, 'timestamp': timestamp},
    );
  }

  Future<void> likePost({
    required String userId,
    required String postId,
  }) async {
    try {
      // Check if already liked to prevent duplicates
      final existing = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: likesCollection,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('post_id', postId),
        ],
      );

      if (existing.total == 0) {
        await _db.createRow(
          databaseId: Environment.appwriteDatabaseId,
          tableId: likesCollection,
          rowId: ID.unique(),
          data: {
            'user_id': userId,
            'post_id': postId,
            'timestamp': DateTime.now().toIso8601String(),
          },
          permissions: [
            Permission.read(Role.user(userId)),
            Permission.update(Role.user(userId)),
            Permission.delete(Role.user(userId)),
          ],
        );
      }
    } catch (e) {
      log('Error liking post: $e');
      rethrow;
    }
  }

  Future<void> unlikePost({
    required String userId,
    required String postId,
  }) async {
    try {
      final existing = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: likesCollection,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('post_id', postId),
        ],
      );

      if (existing.total > 0) {
        await _db.deleteRow(
          databaseId: Environment.appwriteDatabaseId,
          tableId: likesCollection,
          rowId: existing.rows.first.$id,
        );
      }
    } catch (e) {
      log('Error unliking post: $e');
      rethrow;
    }
  }

  Future<bool> hasUserLikedPost({
    required String userId,
    required String postId,
  }) async {
    try {
      final existing = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: likesCollection,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('post_id', postId),
        ],
      );
      return existing.total > 0;
    } catch (e) {
      log('Error checking if user liked post: $e');
      return false;
    }
  }

  Future<Post> getPost(String postId) async {
    final postRow = await _db.getRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: postsCollection,
      rowId: postId,
    );
    return await _mapRowToPost(postRow);
  }

  Future<Post> _mapRowToPost(models.Row postRow) async {
    final profileIdData = postRow.data['profile_id'];
    String? profileId;
    if (profileIdData is List) {
      profileId = profileIdData.isNotEmpty
          ? profileIdData.first.toString()
          : null;
    } else {
      profileId = profileIdData?.toString();
    }

    if (profileId == null) {
      throw Exception('Post ${postRow.$id} has no profile_id');
    }

    final profile = await getProfile(profileId);
    final author = Profile.fromRow(profile);

    // Handle file_ids -> mediaUrls conversion if mediaUrls is null/empty
    List<String> mediaUrls = [];
    final mediaUrlsData = postRow.data['mediaUrls'];
    if (mediaUrlsData is List && mediaUrlsData.isNotEmpty) {
      mediaUrls = List<String>.from(mediaUrlsData.map((e) => e.toString()));
    } else {
      final fileIdsData = postRow.data['file_ids'];
      if (fileIdsData is List) {
        mediaUrls = fileIdsData
            .map((id) => getFileViewUrl(id.toString()))
            .toList();
      }
    }

    return Post(
      id: postRow.$id,
      author: author,
      timestamp: postRow.data['timestamp'] != null
          ? DateTime.parse(postRow.data['timestamp'])
          : DateTime.now(),
      contentText: postRow.data['caption'] ?? postRow.data['contentText'] ?? '',
      stats: PostStats(
        likes: postRow.data['likes'] ?? 0,
        comments: postRow.data['comments'] ?? 0,
        shares: postRow.data['shares'] ?? 0,
        views: postRow.data['views'] ?? 0,
      ),
      mediaUrls: mediaUrls.isNotEmpty ? mediaUrls : null,
      linkUrl: postRow.data['linkUrl'],
      linkTitle: postRow.data['linkTitle'],
      type: PostType.values.firstWhere(
        (e) => e.toString() == 'PostType.${postRow.data['type']}',
        orElse: () {
          if (mediaUrls.isNotEmpty) return PostType.image;
          return PostType.text;
        },
      ),
    );
  }

  Future<void> deletePost(String postId) async {
    await _db.deleteRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: postsCollection,
      rowId: postId,
    );
  }

  Future<models.RowList> getComments(String postId) async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: commentsCollection,
      queries: [Query.equal('post_id', postId), Query.orderDesc('timestamp')],
    );
  }

  Future<void> createComment({
    required String postId,
    required String profileId,
    required String text,
    String? parentCommentId,
  }) async {
    final profile = await getProfile(profileId);
    final ownerId = profile.data['ownerId'];
    if (ownerId == null) {
      throw AppwriteException(
        'Could not determine the owner of the profile.',
        403,
      );
    }

    final data = {
      'post_id': postId,
      'profile_id': profileId,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
      if (parentCommentId != null) 'parent_comment_id': parentCommentId,
    };

    await _db.createRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: commentsCollection,
      rowId: ID.unique(),
      data: data,
      permissions: [
        Permission.read(Role.any()),
        Permission.update(Role.user(ownerId)),
        Permission.delete(Role.user(ownerId)),
      ],
    );
  }

  Future<models.RowList> getImages({String? cursor}) async {
    return await _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: imagesCollection,
      queries: [Query.limit(10), if (cursor != null) Query.cursorAfter(cursor)],
    );
  }

  Future<models.Row> uploadImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final file = await _storage.createFile(
      bucketId: Environment.appwriteStorageBucketId,
      fileId: ID.unique(),
      file: InputFile.fromBytes(bytes: bytes, filename: filename),
    );

    final imageUrl =
        '${Environment.appwritePublicEndpoint}/storage/buckets/${Environment.appwriteStorageBucketId}/files/${file.$id}/view?project=${Environment.appwriteProjectId}';

    return await _db.createRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: imagesCollection,
      rowId: ID.unique(),
      data: {
        'title': 'New Image',
        'description': 'A beautiful new image',
        'imageUrl': imageUrl,
        'link': 'https://example.com',
      },
    );
  }

  Future<models.File> uploadFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    final user = await getUser();
    if (user == null) {
      throw AppwriteException('User not authenticated', 401);
    }
    final result = await _storage.createFile(
      bucketId: Environment.appwriteStorageBucketId,
      fileId: ID.unique(),
      file: InputFile.fromBytes(bytes: bytes, filename: filename),
      permissions: [
        Permission.read(Role.any()),
        Permission.update(Role.user(user.$id)),
        Permission.delete(Role.user(user.$id)),
      ],
    );
    return result;
  }

  String getFileViewUrl(String fileId) {
    return '${Environment.appwritePublicEndpoint}/storage/buckets/${Environment.appwriteStorageBucketId}/files/$fileId/view?project=${Environment.appwriteProjectId}';
  }

  Future<models.File> getFile(String fileId) async {
    return _storage.getFile(
      bucketId: Environment.appwriteStorageBucketId,
      fileId: fileId,
    );
  }

  Future<models.RowList> searchPosts({required String query}) async {
    final results = await Future.wait([
      _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: postsCollection,
        queries: [Query.search('caption', query)],
      ),
      _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: postsCollection,
        queries: [Query.search('titles', query)],
      ),
      _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: postsCollection,
        queries: [Query.search('tags', query)],
      ),
    ]);

    final allPosts = <String, models.Row>{};
    for (final result in results) {
      for (final doc in result.rows) {
        allPosts[doc.$id] = doc;
      }
    }

    return models.RowList(
      total: allPosts.length,
      rows: allPosts.values.toList(),
    );
  }

  Future<void> createProduct({
    required String name,
    required String description,
    required double price,
    required String profileId,
    required String location,
    String? imageId,
  }) async {
    final profile = await getProfile(profileId);
    final ownerId = profile.data['ownerId'];

    if (ownerId == null) {
      throw AppwriteException(
        'Could not determine the owner of the profile for this product.',
        403,
      );
    }

    final Map<String, dynamic> data = {
      'name': name,
      'description': description,
      'price': price,
      'profile_id': profileId,
      'location': location,
    };

    if (imageId != null) {
      data['imageId'] = imageId;
    }

    await _db.createRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: productsCollection,
      rowId: ID.unique(),
      data: data,
      permissions: [
        Permission.read(Role.any()),
        Permission.update(Role.user(ownerId)),
        Permission.delete(Role.user(ownerId)),
      ],
    );
  }

  Future<models.RowList> getProducts({int limit = 25, String? cursor}) async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: productsCollection,
      queries: [
        Query.limit(limit),
        if (cursor != null) Query.cursorAfter(cursor),
      ],
    );
  }

  Future<models.RowList> getProductsByProfile(String profileId) async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: productsCollection,
      queries: [Query.equal('profile_id', profileId)],
    );
  }

  Future<void> updateProduct({
    required String productId,
    required Map<String, dynamic> data,
  }) async {
    await _db.updateRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: productsCollection,
      rowId: productId,
      data: data,
    );
  }

  Future<void> deleteProduct(String productId) async {
    await _db.deleteRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: productsCollection,
      rowId: productId,
    );
  }

  Future<void> createPlaylist({
    required String name,
    required bool isPrivate,
    required String profileId,
    required String postId,
  }) async {
    final profile = await getProfile(profileId);
    final ownerId = profile.data['ownerId'];

    if (ownerId == null) {
      throw AppwriteException(
        'Could not determine the owner of the profile for this playlist.',
        403,
      );
    }

    await _db.createRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: playlistsCollection,
      rowId: ID.unique(),
      data: {
        'name': name,
        'isPrivate': isPrivate,
        'profile_id': profileId,
        'post_ids': [postId],
      },
      permissions: [
        Permission.read(Role.any()),
        Permission.update(Role.user(ownerId)),
        Permission.delete(Role.user(ownerId)),
      ],
    );
  }

  Future<models.RowList> getPlaylists(String profileId) async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: playlistsCollection,
      queries: [Query.equal('profile_id', profileId)],
    );
  }

  Future<void> addPostToPlaylist({
    required String playlistId,
    required String postId,
  }) async {
    final playlist = await _db.getRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: playlistsCollection,
      rowId: playlistId,
    );

    final List<dynamic> postIds = List<dynamic>.from(
      playlist.data['post_ids'] ?? [],
    );

    if (!postIds.contains(postId)) {
      postIds.add(postId);
      await _db.updateRow(
        databaseId: Environment.appwriteDatabaseId,
        tableId: playlistsCollection,
        rowId: playlistId,
        data: {'post_ids': postIds},
      );
    }
  }

  Future<List<Post>> getPostsFromPlaylist(String playlistId) async {
    try {
      final playlist = await _db.getRow(
        databaseId: Environment.appwriteDatabaseId,
        tableId: playlistsCollection,
        rowId: playlistId,
      );

      final List<String> postIds = List<String>.from(
        playlist.data['post_ids'] ?? [],
      );

      if (postIds.isEmpty) {
        return [];
      }

      // Fetch all posts concurrently
      final postFutures = postIds.map(
        (postId) => _db.getRow(
          databaseId: Environment.appwriteDatabaseId,
          tableId: postsCollection,
          rowId: postId,
        ),
      );

      final postRows = await Future.wait(postFutures);

      final posts = <Post>[];
      for (final postRow in postRows) {
        try {
          final post = await _mapRowToPost(postRow);
          posts.add(post);
        } catch (e) {
          log('Failed to process post: ${postRow.$id}, error: $e');
        }
      }
      return posts;
    } on AppwriteException catch (e) {
      log('Failed to get playlist: $playlistId, error: $e');
      // Re-throw the exception to be handled by the UI
      rethrow;
    }
  }

  Future<void> createStory({
    required String profileId,
    required String mediaUrl,
    required String mediaType,
    String? caption,
    String? location,
  }) async {
    final user = await getUser();
    if (user == null) {
      throw AppwriteException('User not authenticated', 401);
    }
    final ownerId = user.$id;

    await _db.createRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: storiesCollection,
      rowId: ID.unique(),
      data: {
        'profileId': profileId,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 24))
            .toIso8601String(),
        if (caption != null) 'caption': caption,
        if (location != null) 'location': location,
      },
      permissions: [
        Permission.read(Role.any()),
        Permission.update(Role.user(ownerId)),
        Permission.delete(Role.user(ownerId)),
      ],
    );
  }

  Future<models.RowList> getStories(List<String> profileIds) async {
    return await _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: storiesCollection,
      queries: [
        Query.equal('profileId', profileIds),
        Query.greaterThan('expiresAt', DateTime.now().toIso8601String()),
      ],
    );
  }

  // --- OTP & MFA ---

  /// Creates an email token (OTP) for passwordless login or verification.
  Future<models.Token> createEmailToken({
    required String userId,
    required String email,
    bool phrase = false,
  }) async {
    return await _account.createEmailToken(
      userId: userId,
      email: email,
      phrase: phrase,
    );
  }

  /// Creates a session using the OTP (secret) received via email.
  Future<models.Session> createSessionWithToken({
    required String userId,
    required String secret,
  }) async {
    return await _account.createSession(userId: userId, secret: secret);
  }

  /// Updates the Multi-Factor Authentication status for the current user.
  Future<models.User> updateMFA({required bool mfa}) async {
    return await _account.updateMFA(mfa: mfa);
  }

  /// Lists available MFA factors for the current user.
  Future<models.MfaFactors> listMFAFactors() async {
    return await _account.listMFAFactors();
  }

  /// Creates an MFA challenge using a specific factor (e.g., 'email').
  Future<models.MfaChallenge> createMFAChallenge({
    required AuthenticationFactor factor,
  }) async {
    return await _account.createMFAChallenge(factor: factor);
  }

  /// Completes an MFA challenge using the secret (OTP).
  Future<models.Session> updateMFAChallenge({
    required String challengeId,
    required String secret,
  }) async {
    return await _account.updateMFAChallenge(
      challengeId: challengeId,
      otp: secret,
    );
  }

  Future<models.RowList> getNotifications() async {
    final user = await getUser();
    if (user == null) {
      throw AppwriteException('User not authenticated', 401);
    }

    return await _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: notificationsCollection,
      queries: [Query.equal('userId', user.$id), Query.orderDesc('timestamp')],
    );
  }

  Future<void> reportPost({
    required String postId,
    required String reportedBy,
    required String reason,
  }) async {}

  Future<void> registerDevice(String deviceToken) async {
    final user = await getUser();
    if (user == null) return;

    try {
      // Appwrite 1.5+ uses Account.createPushTarget for FCM/APNS registration
      await _account.createPushTarget(
        targetId: ID.unique(),
        identifier: deviceToken,
        providerId: 'fcm',
      );
      log('Device registered with Appwrite Messaging via Account service');
    } catch (e) {
      log('Error registering push target: $e');
    }
  }

  // Call-related methods

  Future<RealtimeSubscription> subscribeToCollection({
    required String collectionId,
    required Function(RealtimeMessage) callback,
  }) async {
    final subscription = _realtime.subscribe([
      'databases.${Environment.appwriteDatabaseId}.collections.$collectionId.documents',
    ]);
    subscription.stream.listen(
      callback,
      onError: (error) {
        log('Realtime stream error: $error');
      },
      onDone: () {
        log('Realtime stream closed for collection: $collectionId');
      },
    );
    return subscription;
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final result = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: profilesCollection,
        queries: [Query.equal('ownerId', userId)],
      );
      if (result.rows.isNotEmpty) {
        return result.rows.first.data;
      }
      return null;
    } catch (e) {
      log('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> createCallDocument(CallData callData) async {
    await _db.createRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: callsCollection,
      rowId: callData.callId,
      data: callData.toJson(),
      permissions: [
        Permission.read(Role.user(callData.caller.userId)),
        Permission.read(Role.user(callData.receiver.userId)),
        Permission.update(Role.user(callData.caller.userId)),
        Permission.update(Role.user(callData.receiver.userId)),
      ],
    );
  }

  Future<void> updateCallDocument({
    required String callId,
    required CallState status,
    DateTime? acceptedAt,
    DateTime? endedAt,
    int? duration,
  }) async {
    await _db.updateRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: callsCollection,
      rowId: callId,
      data: {
        'status': status.name,
        if (acceptedAt != null) 'acceptedAt': acceptedAt.toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt.toIso8601String(),
        if (duration != null) 'duration': duration,
      },
    );
  }

  Future<CallData?> getActiveCallForUser(String userId) async {
    try {
      final result = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: callsCollection,
        queries: [
          Query.or([
            Query.equal('callerId', userId),
            Query.equal('receiverId', userId),
          ]),
          Query.notEqual('status', [
            CallState.ended.name,
            CallState.rejected.name,
            CallState.timeout.name,
          ]),
          Query.limit(1),
        ],
      );

      if (result.rows.isNotEmpty) {
        return CallData.fromJson(result.rows.first.data);
      }
      return null;
    } catch (e) {
      log('Error getting active call: $e');
      return null;
    }
  }
}
