import 'package:livekit_client/livekit_client.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/environment.dart';

class CallService {
  final AppwriteService _appwriteService;

  CallService(this._appwriteService);

  Future<Room> connectToRoom(String roomName) async {
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );

    final token = await _appwriteService.getLiveKitToken(roomName: roomName);

    await room.connect(
      Environment.liveKitUrl,
      token,
    );

    return room;
  }
}
