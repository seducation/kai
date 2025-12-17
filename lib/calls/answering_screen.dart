import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:my_app/calls/call_service.dart';

class AnsweringScreen extends StatefulWidget {
  final String roomName;

  const AnsweringScreen({super.key, required this.roomName});

  @override
  State<AnsweringScreen> createState() => _AnsweringScreenState();
}

class _AnsweringScreenState extends State<AnsweringScreen> {
  Room? _room;
  final CallService _callService = CallService();

  @override
  void initState() {
    super.initState();
    _connectToRoom();
  }

  void _connectToRoom() async {
    try {
      final room = await _callService.connectToRoom(widget.roomName);
      setState(() {
        _room = room;
      });
    } catch (e) {
      // Handle connection error
    }
  }

  @override
  void dispose() {
    _room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Answering Call'),
      ),
      body: Center(
        child: _room == null
            ? const CircularProgressIndicator()
            : const Text('Connected to room'),
      ),
    );
  }
}
