import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/model/chat_model.dart';
import 'package:my_app/widgets/chat_app_bar.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:my_app/environment.dart';
import 'package:provider/provider.dart';

class ChatMessagingScreen extends StatefulWidget {
  final ChatModel chat;
  final Function(String) onMessageSent;

  const ChatMessagingScreen(
      {super.key, required this.chat, required this.onMessageSent});

  @override
  State<ChatMessagingScreen> createState() => _ChatMessagingScreenState();
}

class _ChatMessagingScreenState extends State<ChatMessagingScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AppwriteService _appwriteService;
  late final Realtime _realtime;
  RealtimeSubscription? _subscription;
  models.User? _currentUser;
  String? _chatId;
  String? _receiverOwnerId;
  String _profileName = "";

  final List<models.Row> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _appwriteService = context.read<AppwriteService>();
    _realtime = Realtime(_appwriteService.client);
    _loadChat();
  }

  Future<void> _loadChat() async {
    try {
      _currentUser = await _appwriteService.getUser();
      if (!mounted) return;

      final senderProfiles = await _appwriteService.getUserProfiles(ownerId: _currentUser!.$id);
      if (!mounted) return;
      final userProfiles = senderProfiles.rows.where((p) => p.data['type'] == 'profile');

      if (userProfiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Go and create a profile first'),
          ));
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final receiverChatProfile = await _appwriteService.getProfile(widget.chat.userId);
      _receiverOwnerId = receiverChatProfile.data['ownerId'];
      if (!mounted) return;

      final receiverOwnerProfiles = await _appwriteService.getUserProfiles(ownerId: _receiverOwnerId!);
      if (!mounted) return;

      String nameToShow = receiverChatProfile.data['name']; // Default to current chat profile name
      final receiverMainProfile = receiverOwnerProfiles.rows.where((p) => p.data['type'] == 'profile');
      if (receiverMainProfile.isNotEmpty) {
        nameToShow = receiverMainProfile.first.data['name'];
      }

      setState(() {
        _profileName = nameToShow;
      });

      _chatId = _getChatId(_currentUser!.$id, _receiverOwnerId!);

      final initialMessages = await _appwriteService.getMessages(
        userId1: _currentUser!.$id,
        userId2: _receiverOwnerId!,
      );
      setState(() {
        _messages.addAll(initialMessages.rows.reversed);
        _isLoading = false;
      });

      _subscribeToMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading chat: $e")),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToMessages() {
    const channel = 'databases.${Environment.appwriteDatabaseId}.collections.${AppwriteService.messagesCollection}.documents';
    _subscription = _realtime.subscribe([channel]);

    _subscription!.stream.listen((response) {
      if (response.events.contains("databases.*.collections.*.documents.*.create")) {
        final newDocument = models.Row.fromMap(response.payload);
        if (newDocument.data['chatId'] == _chatId) {
          setState(() {
            _messages.insert(0, newDocument);
          });
        }
      }
    });
  }

  String _getChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return ids.join('_');
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty || _currentUser == null || _receiverOwnerId == null) return;

    final senderProfiles = await _appwriteService.getUserProfiles(ownerId: _currentUser!.$id);
    if (!mounted) return;
    final userProfiles = senderProfiles.rows.where((p) => p.data['type'] == 'profile');

    if (userProfiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Go and create a profile first'),
        ));
      }
      return;
    }

    final receiverProfiles = await _appwriteService.getUserProfiles(ownerId: _receiverOwnerId!);
    if (!mounted) return;
    final receiverMainProfiles = receiverProfiles.rows.where((p) => p.data['type'] == 'profile');

    if (receiverMainProfiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This user does not have a main profile and cannot receive messages.'),
        ));
      }
      return;
    }

    _textController.clear();
    _focusNode.requestFocus();

    try {
      await _appwriteService.sendMessage(
        senderId: _currentUser!.$id,
        receiverId: _receiverOwnerId!,
        message: text.trim(),
      );
      widget.onMessageSent(text.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send message: $e")),
      );
      _textController.text = text;
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBar(
        urlImage: widget.chat.imgPath,
        title: _profileName,
        onOff: widget.chat.isOnline ? "Online" : "Offline",
        onCallPressed: () {
          final roomName = _getChatId(_currentUser!.$id, _receiverOwnerId!);
          context.push('/outgoing_call/$roomName');
        },
        onProfileTap: () {
          context.push('/profile_page/${widget.chat.userId}');
        },
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("web/icons/Icon-512.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Flexible(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? _buildEmptyChatView()
                      : _buildMessageList(),
            ),
            const Divider(height: 1.0),
            Container(
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: _buildTextComposer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      reverse: true,
      itemCount: _messages.length,
      itemBuilder: (_, index) {
        final message = _messages[index];
        final isMe = message.data['senderId'] == _currentUser!.$id;
        return _buildMessageBubble(message.data['message'], isMe);
      },
    );
  }

  Widget _buildMessageBubble(String message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[700],
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          Flexible(
            child: TextField(
              controller: _textController,
              onSubmitted: _handleSubmitted,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                hintText: 'Message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () => _handleSubmitted(_textController.text),
                ),
              ),
              focusNode: _focusNode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(128),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "No messages here yet...",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Send a message to start the conversation.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
