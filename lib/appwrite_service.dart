import 'dart:typed_data';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'community_screen_widget/poster_item.dart';

class AppwriteService {
  final Client _client = Client();
  late TablesDB _db;
  late Storage _storage;
  late Account _account;

  Client get client => _client; 

  static const String databaseId = "691963ed003c37eb797f";
  static const String profilesCollection = "profiles";
  static const String messagesCollection = "messages";

  AppwriteService() {
    _client
        .setEndpoint("https://sgp.cloud.appwrite.io/v1")
        .setProject("691948bf001eb3eccd77");

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

  Future<models.User> getUser() async {
    try {
      final user = await _account.get();
      return user;
    } catch (e) {
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
    required String ownerId,
    required String name,
    required String type,
    required String bio,
    required String profileImageUrl,
    required String bannerImageUrl,
  }) async {
    return await _db.createRow(
      databaseId: databaseId,
      tableId: profilesCollection,
      rowId: ID.unique(),
      data: {
        'ownerId': ownerId,
        'name': name,
        'type': type,
        'bio': bio,
        'profileImageUrl': profileImageUrl,
        'bannerImageUrl': bannerImageUrl,
        'followers': [], // Initialize with an empty list
      },
      permissions: [
        Permission.read(Role.users()),
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
      databaseId: databaseId,
      tableId: profilesCollection,
      rowId: profileId,
      data: data,
    );
  }

  Future<models.RowList> searchProfiles({required String name}) async {
    return _db.listRows(
      databaseId: databaseId,
      tableId: profilesCollection,
      queries: [Query.search('name', name)],
    );
  }

  Future<models.RowList> getUserProfiles({required String ownerId}) async {
    return await _db.listRows(
        databaseId: databaseId,
        tableId: profilesCollection,
        queries: [Query.equal('ownerId', ownerId)]);
  }

  Future<models.Row> getProfile(String profileId) async {
    return await _db.getRow(
      databaseId: databaseId,
      tableId: profilesCollection,
      rowId: profileId,
    );
  }

  Future<models.RowList> getProfiles() async {
    return _db.listRows(
      databaseId: databaseId,
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

  Future<models.RowList> getFollowingProfiles({required String userId}) async {
    return _db.listRows(
      databaseId: databaseId,
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
    return await _db.createRow(
      databaseId: databaseId,
      tableId: messagesCollection,
      rowId: ID.unique(),
      data: {
        'chatId': chatId,
        'senderId': senderId,
        'message': message,
      },
       permissions: [
        Permission.read(Role.user(senderId)),
        Permission.read(Role.user(receiverId)),
      ],
    );
  }

  Future<models.RowList> getMessages({
    required String userId1,
    required String userId2,
  }) async {
    final chatId = _getChatId(userId1, userId2);
    try {
      return await _db.listRows(
        databaseId: databaseId,
        tableId: messagesCollection,
        queries: [Query.equal('chatId', chatId)],
      );
    } on AppwriteException catch (e) {
      if (e.type == 'database_get_document_not_found' || e.code == 404) {
        return models.RowList(total: 0, rows: []);
      }
      rethrow;
    }
  }

  Future<List<PosterItem>> getMovies() async {
    final data = await _db.listRows(
      databaseId: "691963ed003c37eb797f",
      tableId: "movies",
    );

    return data.rows.map((row) {
      final imageId = row.data['imageId'];

      final imageUrl = _storage.getFileView(
        bucketId: "lens-s",
        fileId: imageId,
      ).toString();

      return PosterItem.fromMap({
        '\$id': row.$id,
        'title': row.data['title'],
        'imageUrl': imageUrl,
      });
    }).toList();
  }

  Future<models.RowList> getImages({String? cursor}) async {
    return await _db.listRows(
      databaseId: '691963ed003c37eb797f',
      tableId: 'image',
      queries: [
        Query.limit(10),
        if (cursor != null) Query.cursorAfter(cursor),
      ],
    );
  }

  Future<models.Row> uploadImage({required Uint8List bytes, required String filename}) async {
    final file = await _storage.createFile(
        bucketId: 'lens-s',
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: bytes, filename: filename));

    final imageUrl =
        'https://sgp.cloud.appwrite.io/v1/storage/buckets/lens-s/files/${file.$id}/view?project=691948bf001eb3eccd77';

    return await _db.createRow(
      databaseId: '691963ed003c37eb797f',
      tableId: 'image',
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
    final result = await _storage.createFile(
      bucketId: "lens-s",
      fileId: ID.unique(),
      file: InputFile.fromBytes(bytes: bytes, filename: filename),
    );
    return result;
  }
}
