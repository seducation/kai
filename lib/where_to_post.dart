import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'appwrite_service.dart';
import 'auth_service.dart';
import 'model/profile.dart';

class WhereToPostScreen extends StatefulWidget {
  final Map<String, dynamic> postData;

  const WhereToPostScreen({super.key, required this.postData});

  @override
  State<WhereToPostScreen> createState() => _WhereToPostScreenState();
}

class _WhereToPostScreenState extends State<WhereToPostScreen> {
  late Future<List<Profile>> _profilesFuture;
  final List<String> _selectedProfileIds = [];
  bool _isPublishing = false;
  List<Profile> _followingProfiles = [];
  bool _isLoadingFollowing = false;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _profilesFuture = _fetchUserProfiles(authService.currentUser!.id);
    _fetchFollowingProfiles(authService.currentUser!.id);
  }

  Future<void> _fetchFollowingProfiles(String userId) async {
    setState(() {
      _isLoadingFollowing = true;
    });
    try {
      final appwriteService = context.read<AppwriteService>();
      final response = await appwriteService.getFollowingProfiles(userId: userId);
      if (mounted) {
        setState(() {
          _followingProfiles = response.rows
              .map((row) => Profile.fromRow(row))
              .where((profile) => profile.type == 'thread')
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching following profiles: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFollowing = false;
        });
      }
    }
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

  Future<void> _publishPosts() async {
    if (_selectedProfileIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one account to post to.')),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final appwriteService = context.read<AppwriteService>();
    final router = GoRouter.of(context);

    final userProfiles = await _profilesFuture;

    if (!mounted) return;

    final allProfiles = [...userProfiles, ..._followingProfiles];
    
    for (final profileId in _selectedProfileIds) {
      final profile = allProfiles.firstWhere((p) => p.id == profileId);
      if (profile.type == 'thread') {
        if (!widget.postData.containsKey('authoreid') || (widget.postData['authoreid'] as List).isEmpty) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('You must allow sharing your author ID to post to a thread.')),
          );
          return;
        }
      }
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      final postData = {
        ...widget.postData,
        'profile_id': _selectedProfileIds,
      };
      await appwriteService.createPost(postData);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Successfully posted to ${_selectedProfileIds.length} account(s).')),
        );
        router.go('/');
      }
    } on AppwriteException catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Failed to create post: ${e.message}')),
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

          if (profiles.isEmpty && _followingProfiles.isEmpty) {
            return const Center(
              child: Text(
                'You don\'t have any profiles to post to and you are not following anyone.\nGo to your profile to create one or find accounts to follow.',
                textAlign: TextAlign.center,
              ),
            );
          }
          
          List<Widget> listItems = [];

          if (profiles.isNotEmpty) {
            listItems.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
                child: Text(
                  'Your Profiles',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            );
            listItems.addAll(profiles.map((profile) {
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
            }).toList());
          }

          if (_isLoadingFollowing) {
            listItems.add(const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            )));
          } else if (_followingProfiles.isNotEmpty) {
             listItems.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
                child: Text(
                  'Following',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            );
            listItems.addAll(_followingProfiles.map((profile) {
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
            }).toList());
          }

          return ListView(
            children: listItems,
          );
        },
      ),
      persistentFooterButtons: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedProfileIds.isEmpty || _isPublishing ? null : _publishPosts,
            child: _isPublishing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publish'),
          ),
        ),
      ],
    );
  }
}
