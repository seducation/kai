import 'dart:typed_data';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:my_app/environment.dart';
import 'community_screen_widget/poster_item.dart';

class AppwriteService {
  final Client _client;
  late TablesDB _db;
  late Storage _storage;
  late Account _account;

  Client get client => _client;

  static const String profilesCollection = "profiles";
  static const String messagesCollection = "messages";
  static const String postsCollection = "posts";
  static const String imagesCollection = "images";
  static const String commentsCollection = "comments";
  static const String productsCollection = "products";
  static const String playlistsCollection = "playlists";

  AppwriteService(this._client) {
    _db = TablesDB(_client);
    _storage = Storage(_client);
    _account = Account(_client);
  }

  Future<models.User> signUp(
      {required String email, required String password, required String name}) async {
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

  Future<models.Session> signIn(
      {required String email, required String password}) async {
    try {
      final session =
          await _account.createEmailPasswordSession(email: email, password: password);
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
        'location': location,
        'profileImageUrl': profileImageUrl,
        'bannerImageUrl': bannerImageUrl,
        'followers': [],
        'savedPosts': [],
      },
      permissions: [
        Permission.read(Role.any()),
        Permission.update(Role.user(ownerId)),
        Permission.delete(Role.user(ownerId)),
      ],
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
        queries: [Query.search('name', query)],
      ),
      _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: profilesCollection,
        queries: [Query.search('bio', query)],
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
        queries: [Query.equal('ownerId', ownerId)]);
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
    );
  }

  Future<models.Row> followProfile({
    required String profileId,
    required String followerId,
  }) async {
    final profile = await getProfile(profileId);
    final List<String> followers = List<String>.from(profile.data['followers'] ?? []);
    if (!followers.contains(followerId)) {
      followers.add(followerId);
      return await updateProfile(
        profileId: profileId,
        data: {'followers': followers},
      );
    }
    return profile;
  }

  Future<models.Row> unfollowProfile({
    required String profileId,
    required String followerId,
  }) async {
    final profile = await getProfile(profileId);
    final List<String> followers = List<String>.from(profile.data['followers'] ?? []);
    if (followers.contains(followerId)) {
      followers.remove(followerId);
      return await updateProfile(
        profileId: profileId,
        data: {'followers': followers},
      );
    }
    return profile;
  }

  Future<models.Row> savePost({
    required String profileId,
    required String postId,
  }) async {
    final profile = await getProfile(profileId);
    final List<String> savedPosts = List<String>.from(profile.data['savedPosts'] ?? []);
    if (!savedPosts.contains(postId)) {
      savedPosts.add(postId);
      return await updateProfile(
        profileId: profileId,
        data: {'savedPosts': savedPosts},
      );
    }
    return profile;
  }

  Future<models.Row> unsavePost({
    required String profileId,
    required String postId,
  }) async {
    final profile = await getProfile(profileId);
    final List<String> savedPosts = List<String>.from(profile.data['savedPosts'] ?? []);
    if (savedPosts.contains(postId)) {
      savedPosts.remove(postId);
      return await updateProfile(
        profileId: profileId,
        data: {'savedPosts': savedPosts},
      );
    }
    return profile;
  }

  Future<models.RowList> getFollowingProfiles({required String userId}) async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: profilesCollection,
      queries: [
        Query.equal('followers', userId),
      ],
    );
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
      data: {
        'chatId': chatId,
        'senderId': senderId,
        'message': message,
      },
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

  Future<List<PosterItem>> getMovies() async {
    try {
      final data = await _db.listRows(
        databaseId: Environment.appwriteDatabaseId,
        tableId: "movies",
      );

      final movies = <PosterItem>[];
      for (final row in data.rows) {
        final imageId = row.data['imageId'];
        if (imageId != null && imageId.isNotEmpty) {
          final imageUrl = _storage.getFileView(
            bucketId: Environment.appwriteStorageBucketId,
            fileId: imageId,
          ).toString();
          movies.add(PosterItem.fromMap({
            '\$id': row.$id,
            'title': row.data['title'],
            'imageUrl': imageUrl,
          }));
        }
      }
      return movies;
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        return [];
      }
      return [];
    }
  }

  Future<models.RowList> getPosts() async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: postsCollection,
    );
  }

  Future<models.RowList> getPostsFromUsers(List<dynamic> profileIds) async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: postsCollection,
      queries: [
        Query.equal('profile_id', profileIds),
      ],
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

  Future<void> updatePostLikes(String postId, int likes, String timestamp) async {
    await _db.updateRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: postsCollection,
      rowId: postId,
      data: {
        'likes': likes,
        'timestamp': timestamp,
      },
    );
  }

  Future<models.RowList> getComments(String postId) async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: commentsCollection,
      queries: [
        Query.equal('post_id', postId),
        Query.orderDesc('timestamp'),
      ],
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
      throw AppwriteException('Could not determine the owner of the profile.', 403);
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
      queries: [
        Query.limit(10),
        if (cursor != null) Query.cursorAfter(cursor),
      ],
    );
  }

  Future<models.Row> uploadImage({required Uint8List bytes, required String filename}) async {
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

  Future<models.File> uploadFile({required Uint8List bytes, required String filename}) async {
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
      ]
    );
    return result;
  }
  
  String getFileViewUrl(String fileId) {
    return '${Environment.appwritePublicEndpoint}/storage/buckets/${Environment.appwriteStorageBucketId}/files/$fileId/view?project=${Environment.appwriteProjectId}';
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
      throw AppwriteException('Could not determine the owner of the profile for this product.', 403);
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

  Future<models.RowList> getProducts() async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: productsCollection,
    );
  }

  Future<models.RowList> getProductsByProfile(String profileId) async {
    return _db.listRows(
      databaseId: Environment.appwriteDatabaseId,
      tableId: productsCollection,
      queries: [
        Query.equal('profile_id', profileId),
      ],
    );
  }

  Future<void> createPlaylist({
    required String name,
    required bool isCollaborative,
    required String profileId,
    required String postId,
  }) async {
    final profile = await getProfile(profileId);
    final ownerId = profile.data['ownerId'];

    if (ownerId == null) {
      throw AppwriteException('Could not determine the owner of the profile for this playlist.', 403);
    }

    await _db.createRow(
      databaseId: Environment.appwriteDatabaseId,
      tableId: playlistsCollection,
      rowId: ID.unique(),
      data: {
        'name': name,
        'isCollaborative': isCollaborative,
        'profile_id': profileId,
        'post_ids': [postId], // Use the new 'post_ids' array
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
      queries: [
        Query.equal('profile_id', profileId),
      ],
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

    final List<dynamic> postIds = List<dynamic>.from(playlist.data['post_ids'] ?? []);
    
    if (!postIds.contains(postId)) {
      postIds.add(postId);
      await _db.updateRow(
        databaseId: Environment.appwriteDatabaseId,
        tableId: playlistsCollection,
        rowId: playlistId,
        data: {
          'post_ids': postIds, // Use 'post_ids' array
        },
      );
    }
  }
}
