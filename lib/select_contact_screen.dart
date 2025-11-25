import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/chat_messaging_screen.dart';
import 'package:my_app/find_account_page_screen.dart';
import 'package:my_app/model/chat_model.dart';
import 'package:my_app/sign_in.dart';
import 'package:provider/provider.dart';
import 'package:appwrite/models.dart' as models;

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
  models.User? _currentUser;

  @override
  void initState() {
    super.initState();
    _appwriteService = context.read<AppwriteService>();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      _currentUser = await _appwriteService.getUser();
      final profiles = await _appwriteService.getProfiles();
      if (!mounted) return;

      final contactList = profiles.documents
          .where((doc) => doc.data['ownerId'] != _currentUser!.$id) // Exclude self
          .map((doc) => ChatModel(
                userId: doc.$id, // This is the PROFILE document ID
                name: doc.data['name'] ?? 'No Name',
                message: doc.data['status'] ?? 'No Status',
                time: "",
                imgPath: doc.data['profileImageUrl'] ?? "",
              ))
          .toList();

      setState(() {
        _contacts = contactList;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading contacts: $e")),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleContactTap(ChatModel contact) async {
    try {
      await _appwriteService.getUser(); // Ensure user is still logged in
      if (!mounted) return;
      Navigator.of(context).push(
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
      Navigator.of(context).pushReplacement(
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
            const Text("Select contact"),
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
            onPressed: () {},
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
                // Static Action Items
                const ActionItem(
                  icon: Icons.group,
                  label: "New group",
                ),
                const ActionItem(
                  icon: Icons.person_add,
                  label: "New contact",
                  trailingIcon: Icons.qr_code,
                ),
                 ActionItem(
            icon: Icons.search,
            label: "Find",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FindAccountPageScreen(),
                ),
              );
            },
          ),
          ActionItem(
            icon: Icons.smart_toy_outlined,
            label: "Chat with AIs",
            onTap: () {
              final aiChat = ChatModel(
                userId: "kai_ai_user",
                name: "KAI",
                message: "How can I help you?",
                time: "",
                imgPath: "",
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatMessagingScreen(
                    chat: aiChat,
                    onMessageSent: (newMessage) {
                      final newChat = aiChat;
                      newChat.message = newMessage;
                      newChat.time = "Now"; // Or format current time
                      widget.onNewChat(newChat);
                    },
                  ),
                ),
              );
            },
          ),


                // Section Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    "Contacts on WhatsApp",
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),

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

// Widget for the top action buttons (New Group, New Contact, etc.)
class ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const ActionItem({
    super.key,
    required this.icon,
    required this.label,
    this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: theme.colorScheme.primary,
        child: Icon(
          icon,
          color: theme.colorScheme.onPrimary,
          size: 24,
        ),
      ),
      title: Text(
        label,
        style: theme.textTheme.titleMedium,
      ),
      trailing: trailingIcon != null
          ? Icon(trailingIcon, color: Colors.grey)
          : null,
    );
  }
}

// Widget for individual contacts
class ContactItem extends StatelessWidget {
  final ChatModel contact;
  final VoidCallback onTap;

  const ContactItem({super.key, required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.grey[300],
        // Use a placeholder if the image path is empty
        backgroundImage: (contact.imgPath.isNotEmpty && Uri.parse(contact.imgPath).isAbsolute) 
            ? NetworkImage(contact.imgPath)
            : null,
        child: (contact.imgPath.isEmpty || !Uri.parse(contact.imgPath).isAbsolute)
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
