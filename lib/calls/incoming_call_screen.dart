import 'package:flutter/material.dart';

class IncomingCallScreen extends StatelessWidget {
  final String roomName;

  const IncomingCallScreen({super.key, required this.roomName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Call'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Incoming call from $roomName'),
            ElevatedButton(
              onPressed: () {
                // Navigate to the answering screen
              },
              child: const Text('Answer'),
            ),
            ElevatedButton(
              onPressed: () {
                // Decline the call
              },
              child: const Text('Decline'),
            ),
          ],
        ),
      ),
    );
  }
}
