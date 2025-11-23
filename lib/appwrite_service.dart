import 'dart:io' as io;
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'poster_item.dart';

class AppwriteService {
  final Client _client = Client();
  late Databases _db;
  late Storage _storage;

  AppwriteService() {
    _client
        .setEndpoint("https://sgp.cloud.appwrite.io/v1")
        .setProject("691948bf001eb3eccd77");

    _db = Databases(_client);
    _storage = Storage(_client);
  }

  Future<List<PosterItem>> getMovies() async {
    // ignore: deprecated_member_use
    final data = await _db.listDocuments(
      databaseId: "691963ed003c37eb797f",
      collectionId: "movies",
    );

    return data.documents.map((doc) {
      final imageId = doc.data['imageId'];

      final imageUrl = _storage.getFileView(
        bucketId: "lens-s",
        fileId: imageId,
      ).toString();

      return PosterItem.fromMap({
        '\$id': doc.$id,
        'title': doc.data['title'],
        'imageUrl': imageUrl,
      });
    }).toList();
  }

  Future<DocumentList> getImages({String? cursor}) async {
    // ignore: deprecated_member_use
    return await _db.listDocuments(
      databaseId: '691963ed003c37eb797f',
      collectionId: 'image',
      queries: [
        Query.limit(10),
        if (cursor != null) Query.cursorAfter(cursor),
      ],
    );
  }

  Future<Document> uploadImage({required io.File image}) async {
    final file = await _storage.createFile(
        bucketId: 'lens-s',
        fileId: ID.unique(),
        file: InputFile.fromPath(path: image.path));

    final imageUrl =
        'https://sgp.cloud.appwrite.io/v1/storage/buckets/lens-s/files/${file.$id}/view?project=691948bf001eb3eccd77';

    // ignore: deprecated_member_use
    return await _db.createDocument(
      databaseId: '691963ed003c37eb797f',
      collectionId: 'image',
      documentId: ID.unique(),
      data: {
        'title': 'New Image',
        'description': 'A beautiful new image',
        'imageUrl': imageUrl,
        'link': 'https://example.com',
      },
    );
  }

  Future<File> uploadFile({required io.File file}) async {
    final result = await _storage.createFile(
      bucketId: "lens-s",
      fileId: ID.unique(),
      file: InputFile.fromPath(path: file.path),
    );
    return result;
  }
}
