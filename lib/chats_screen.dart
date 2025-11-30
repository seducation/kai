import 'package:flutter/material.dart';
import 'package:my_app/select_contact_screen.dart';
import 'package:my_app/cnm_calls_tabscreen.dart';
import 'package:my_app/cnm_chats_tabscreen.dart';
import 'package:my_app/cnm_reply_tabscreen.dart';
import 'package:my_app/model/chat_model.dart';
import 'package:my_app/cnm_notifications_tabscreen.dart';
import 'package:my_app/cnm_updates_tabscreen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late List<ChatModel> _chatItems;

  @override
  void initState() {
    super.initState();
    _chatItems = [
      ChatModel(
        userId: "691948bf001eb3eccd78",
        name: "User 1",
        message: "Hello there!",
        time: "12:30 PM",
        imgPath: "https://picsum.photos/seed/p1/200/200",
        isOnline: true,
        messageCount: 2,
        hasStory: true,
      ),
      ChatModel(
        userId: "691948bf001eb3eccd79",
        name: "User 2",
        message: "How are you?",
        time: "12:35 PM",
        imgPath: "https://picsum.photos/seed/p2/200/200",
        hasStory: true,
      ),
      ChatModel(
        userId: "691948bf001eb3eccd80",
        name: "User 3",
        message: "See you soon.",
        time: "12:40 PM",
        imgPath: "https://picsum.photos/seed/p3/200/200",
        isOnline: true,
        messageCount: 1,
      ),
    ];
  }

  void _addNewChat(ChatModel newChat) {
    setState(() {
      final index = _chatItems.indexWhere((chat) => chat.userId == newChat.userId);
      if (index != -1) {
        _chatItems[index] = newChat;
      } else {
        _chatItems.insert(0, newChat);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          leading: Row(
            children: [
              Expanded(
                child: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {},
                ),
              ),
              Expanded(
                child: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          title: const Text("MyApps"),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.notifications)),
              Tab(text: "Updates"),
              Tab(text: "Chat"),
              Tab(text: "Reply"),
              Tab(icon: Icon(Icons.call)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const CNMNotificationsTabscreen(),
            const CNMUpdatesTabscreen(),
            CNMChatsTabscreen(chatItems: _chatItems),
            const CNMReplyTabscreen(),
            const CNMCallsTabscreen(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelectContactScreen(onNewChat: _addNewChat),
              ),
            );
          },
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }
}
