import 'package:flutter/material.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/model/profile.dart';
import 'package:provider/provider.dart';

class SentPostScreen extends StatelessWidget {
  final List<String> imagePaths;
  const SentPostScreen({super.key, required this.imagePaths});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Send To'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'OTM'),
              Tab(text: 'Chat'),
              Tab(text: 'Other Apps'),
              Tab(text: 'Post'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            OTMTab(),
            Center(child: Text('Chat')),
            Center(child: Text('Other Apps')),
            Center(child: Text('Post')),
          ],
        ),
      ),
    );
  }
}

class OTMTab extends StatefulWidget {
  const OTMTab({super.key});

  @override
  State<OTMTab> createState() => _OTMTabState();
}

class _OTMTabState extends State<OTMTab> {
  late final AppwriteService _appwriteService;
  List<Profile> _contacts = [];
  bool _isLoading = true;
  final Set<String> _selectedContactIds = {};
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _appwriteService = context.read<AppwriteService>();
    _loadFollowingContacts();
  }

  Future<void> _loadFollowingContacts() async {
    try {
      final currentUser = await _appwriteService.getUser();
      if (currentUser == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }
      final profiles = await _appwriteService.getFollowingProfiles(
        userId: currentUser.$id,
      );
      if (!mounted) return;
      setState(() {
        _contacts = profiles.rows
            .map((doc) => Profile.fromMap(doc.data, doc.$id))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(String contactId) {
    setState(() {
      if (_selectedContactIds.contains(contactId)) {
        _selectedContactIds.remove(contactId);
      } else {
        _selectedContactIds.add(contactId);
      }
    });
  }

  void _sendOTMs(List<String> imagePaths) async {
    if (_selectedContactIds.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final currentUser = await _appwriteService.getUser();
      if (currentUser != null) {
        await _appwriteService.sendOneTimeMessages(
          senderId: currentUser.$id,
          receiverIds: _selectedContactIds.toList(),
          imagePath: imagePaths.first,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'One-time message sent to ${_selectedContactIds.length} users!',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send messages: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagePaths =
        (ModalRoute.of(context)!.settings.arguments
                as Map<String, dynamic>)['images']
            as List<String>;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_contacts.isNotEmpty)
                  CheckboxListTile(
                    title: const Text('Select All'),
                    value: _selectedContactIds.length == _contacts.length,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedContactIds.addAll(
                            _contacts.map((c) => c.id),
                          );
                        } else {
                          _selectedContactIds.clear();
                        }
                      });
                    },
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      final isSelected = _selectedContactIds.contains(
                        contact.id,
                      );
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(
                            contact.profileImageUrl ?? '',
                          ),
                        ),
                        title: Text(contact.name),
                        trailing: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected ? Colors.blue : Colors.grey,
                        ),
                        onTap: () => _toggleSelection(contact.id),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: _selectedContactIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isSending ? null : () => _sendOTMs(imagePaths),
              label: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Send to ${_selectedContactIds.length}'),
              icon: const Icon(Icons.send),
            )
          : null,
    );
  }
}
