import 'package:livekit_client/livekit_client.dart';

class CallService {
  final String _url = 'YOUR_LIVEKIT_URL'; // Replace with your LiveKit URL
  final String _token = 'YOUR_LIVEKIT_TOKEN'; // Replace with your LiveKit Token

  Future<Room> connectToRoom(String roomName) async {
    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );

    await room.connect(
      _url,
      _token,
    );

    return room;
  }
}
