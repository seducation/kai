import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'appwrite_service.dart';
import 'auth_service.dart';
import 'model/profile.dart';

class WhereToPostStoryScreen extends StatefulWidget {
  final Map<String, dynamic> storyData;

  const WhereToPostStoryScreen({super.key, required this.storyData});

  factory WhereToPostStoryScreen.fromQuery(String query) {
    final Map<String, dynamic> queryParams = Uri.splitQueryString(query);
    final String storyDataEncoded = queryParams['storyData'] ?? '';
    final Map<String, dynamic> storyData = jsonDecode(storyDataEncoded);
    return WhereToPostStoryScreen(storyData: storyData);
  }

  @override
  State<WhereToPostStoryScreen> createState() => _WhereToPostStoryScreenState();
}

class _WhereToPostStoryScreenState extends State<WhereToPostStoryScreen> {
  late Future<List<Profile>> _profilesFuture;
  final List<String> _selectedProfileIds = [];
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _profilesFuture = _fetchUserProfiles(authService.currentUser!.id);
  }

  Future<List<Profile>> _fetchUserProfiles(String userId) async {
    try {
      final appwriteService = context.read<AppwriteService>();
      final response = await appwriteService.getUserProfiles(ownerId: userId);
      return response.rows.map((row) => Profile.fromRow(row)).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching profiles: $e')),
        );
      }
      return [];
    }
  }

  void _toggleProfileSelection(String profileId) {
    setState(() {
      if (_selectedProfileIds.contains(profileId)) {
        _selectedProfileIds.remove(profileId);
      } else {
        _selectedProfileIds.add(profileId);
      }
    });
  }

  Future<void> _publishStories() async {
    if (_selectedProfileIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one account to post to.')),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final appwriteService = context.read<AppwriteService>();
    final router = GoRouter.of(context);

    setState(() {
      _isPublishing = true;
    });

    try {
      final storyFutures = _selectedProfileIds.map((profileId) {
        return appwriteService.createStory(
          profileId: profileId,
          mediaUrl: widget.storyData['mediaUrl']!,
          mediaType: widget.storyData['mediaType']!,
          caption: widget.storyData['caption'],
        );
      });

      await Future.wait(storyFutures);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Successfully posted story to ${_selectedProfileIds.length} account(s).')),
        );
        router.go('/');
      }
    } on AppwriteException catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to create one or more stories: ${e.message}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Story To...'),
      ),
      body: FutureBuilder<List<Profile>>(
        future: _profilesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Error loading profiles.'));
          }

          final profiles = snapshot.data!;

          if (profiles.isEmpty) {
            return const Center(
              child: Text(
                'You don\'t have any profiles to post a story to.\nGo to your profile to create one.',
                textAlign: TextAlign.center,
              ),
            );
          }
          
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Text(
                  'Your Profiles',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ...profiles.map((profile) {
                final isSelected = _selectedProfileIds.contains(profile.id);
                return CheckboxListTile(
                  secondary: CircleAvatar(
                    backgroundImage: NetworkImage(profile.profileImageUrl ?? ''),
                  ),
                  title: Text(profile.name),
                  subtitle: Text(profile.type),
                  value: isSelected,
                  onChanged: (bool? value) {
                    if (value != null) {
                      _toggleProfileSelection(profile.id);
                    }
                  },
                );
              }),
            ],
          );
        },
      ),
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedProfileIds.isEmpty || _isPublishing ? null : _publishStories,
              child: _isPublishing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Post Story'),
            ),
          ),
        ),
      ],
    );
  }
}
