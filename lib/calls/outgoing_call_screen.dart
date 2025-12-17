import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/calls/call_service.dart';
import 'package:provider/provider.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String roomName;

  const OutgoingCallScreen({super.key, required this.roomName});

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  Room? _room;
  late final CallService _callService;

  @override
  void initState() {
    super.initState();
    _callService = CallService(context.read<AppwriteService>());
    _connectToRoom();
  }

  void _connectToRoom() async {
    try {
      final room = await _callService.connectToRoom(widget.roomName);
      setState(() {
        _room = room;
      });
    } catch (e) {
      log('Error connecting to room: $e');
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
        title: const Text('Outgoing Call'),
      ),
      body: Center(
        child: _room == null
            ? const CircularProgressIndicator()
            : const Text('Connected to room'),
      ),
    );
  }
}
