import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:provider/provider.dart';
import 'package:appwrite/models.dart' as models;

class OneTimeMessageScreen extends StatefulWidget {
  final models.Row message;

  const OneTimeMessageScreen({super.key, required this.message});

  @override
  OneTimeMessageScreenState createState() => OneTimeMessageScreenState();
}

class OneTimeMessageScreenState extends State<OneTimeMessageScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        final appwriteService = context.read<AppwriteService>();
        appwriteService.deleteMessage(widget.message.$id);
        final fileId = widget.message.data['fileId'];
        if (fileId != null) {
          appwriteService.deleteFile(fileId);
        }
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: Image.network(widget.message.data['message'])),
    );
  }
}
