import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/chat_messaging_screen.dart';
import 'package:my_app/find_account_page_screen.dart';
import 'package:my_app/model/chat_model.dart';
import 'package:my_app/sign_in.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key, required this.onNewChat});

  final Function(ChatModel) onNewChat;

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  late final AppwriteService _appwriteService;
  List<ChatModel> _contacts = [];
  bool _isLoading = true;
  bool _didInitialize = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitialize) {
      _didInitialize = true;
      _appwriteService = context.read<AppwriteService>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadFollowingContacts();
        }
      });
    }
  }

  Future<void> _loadFollowingContacts() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    List<ChatModel> contactList = [];
    String? error;
    try {
      final currentUser = await _appwriteService.getUser();
      if (!mounted) return;

      final profiles = await _appwriteService.getFollowingProfiles(userId: currentUser.$id);
      if (!mounted) return;

      contactList = profiles.rows.map((doc) {
        final data = doc.data;
        return ChatModel(
          userId: data['ownerId']?.toString() ?? '',
          name: data['name']?.toString() ?? 'No Name',
          message: data['status']?.toString() ?? 'No Status',
          time: "",
          imgPath: data['profileImageUrl']?.toString() ?? '',
        );
      }).where((contact) => contact.userId.isNotEmpty).toList();

    } catch (e) {
      error = "Error loading contacts: $e";
    }

    if (!mounted) return;

    if (error != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
    setState(() {
      if (error == null) {
        _contacts = contactList;
      }
      _isLoading = false;
    });
  }

  Future<void> _handleContactTap(ChatModel contact) async {
    final navigator = Navigator.of(context);
    try {
      await _appwriteService.getUser(); // Ensure user is still logged in
      if (!mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (context) => ChatMessagingScreen(
            chat: contact,
            onMessageSent: (newMessage) {
              final newChat = contact;
              newChat.message = newMessage;
              newChat.time = "Now";
              widget.onNewChat(newChat);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // If getUser fails, it means session expired
      await navigator.pushReplacement(
        MaterialPageRoute(
          builder: (context) => const SignInScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Following"),
            if (!_isLoading)
              Text(
                "${_contacts.length} contacts",
                style: TextStyle(
                  fontSize: 13,
                  color: theme.appBarTheme.titleTextStyle?.color?.withAlpha(179),
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FindAccountPageScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 10),
                // Contact Items
                ..._contacts.map((contact) => ContactItem(
                      contact: contact,
                      onTap: () => _handleContactTap(contact),
                    )),
              ],
            ),
    );
  }
}


// Widget for individual contacts
class ContactItem extends StatelessWidget {
  final ChatModel contact;
  final VoidCallback onTap;

  const ContactItem({super.key, required this.contact, required this.onTap});

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.grey[300],
        // Use a placeholder if the image path is empty or invalid
        backgroundImage: _isValidUrl(contact.imgPath)
            ? NetworkImage(contact.imgPath)
            : null,
        child: !_isValidUrl(contact.imgPath)
            ? Text(
                contact.name.isNotEmpty ? contact.name[0] : "",
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Text(
            contact.name,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Text(
          contact.message, // This should be 'status' from the profile
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
