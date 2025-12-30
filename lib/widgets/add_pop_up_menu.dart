import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:my_app/widgets/edit_profile_fab.dart';
import 'package:provider/provider.dart';

// The main dialog widget that contains the form.
class CreateRowDialog extends StatefulWidget {
  const CreateRowDialog({super.key});

  @override
  State<CreateRowDialog> createState() => _CreateRowDialogState();
}

class _CreateRowDialogState extends State<CreateRowDialog> {
  // ========== ACCOUNT TYPE LIMITS (Easy to modify) ==========
  static const int maxProfileLimit = 1;
  static const int maxBusinessLimit = 5;
  static const int maxThreadLimit = 5;
  static const int maxChannelLimit = 5;
  // ===========================================================

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _handleController = TextEditingController();
  final _locationController = TextEditingController();
  String _selectedType = "profile";
  File? _profileImage;
  File? _bannerImage;

  bool _createMore = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _handleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<File?> _pickAndCropImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return null;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Cropper',
          toolbarColor: Colors.deepOrange,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Cropper'),
      ],
    );

    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> _createProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final appwriteService = Provider.of<AppwriteService>(
          context,
          listen: false,
        );
        final user = await appwriteService.getUser();

        if (user == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You must be logged in to create a profile.'),
            ),
          );
          return;
        }

        // ========== ACCOUNT TYPE LIMITATION CHECKS ==========
        final existingProfiles = await appwriteService.getUserProfiles(
          ownerId: user.$id,
        );

        // Count existing accounts by type
        final typeCount = existingProfiles.rows
            .where((row) => row.data['type'] == _selectedType)
            .length;

        // Check limits based on selected type
        int maxLimit;
        String typeName;

        switch (_selectedType) {
          case 'profile':
            maxLimit = maxProfileLimit;
            typeName = 'Profile';
            break;
          case 'business':
            maxLimit = maxBusinessLimit;
            typeName = 'Business';
            break;
          case 'thread':
            maxLimit = maxThreadLimit;
            typeName = 'Thread';
            break;
          case 'channel':
            maxLimit = maxChannelLimit;
            typeName = 'Channel';
            break;
          default:
            maxLimit = 1;
            typeName = _selectedType.isEmpty
                ? 'Account'
                : '${_selectedType[0].toUpperCase()}${_selectedType.substring(1)}';
        }

        if (typeCount >= maxLimit) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You have reached the limit for $typeName accounts. '
                'You have $typeCount/$maxLimit accounts.',
              ),
            ),
          );
          return;
        }
        // ====================================================

        // Check handle availability
        final handle = _handleController.text;

        // Validate handle format
        if (!RegExp(r'^[a-z0-9]+$').hasMatch(handle)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Handle must only contain lowercase letters and numbers (no spaces or special characters).',
              ),
            ),
          );
          return;
        }

        if (!await appwriteService.isHandleAvailable(handle)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Handle is visually similar to an existing or reserved handle.',
              ),
            ),
          );
          return;
        }

        String? profileImageId;
        if (_profileImage != null) {
          final file = await appwriteService.uploadFile(
            bytes: _profileImage!.readAsBytesSync(),
            filename: _profileImage!.path.split('/').last,
          );
          profileImageId = file.$id;
        }

        String? bannerImageId;
        if (_bannerImage != null) {
          final file = await appwriteService.uploadFile(
            bytes: _bannerImage!.readAsBytesSync(),
            filename: _bannerImage!.path.split('/').last,
          );
          bannerImageId = file.$id;
        }

        await appwriteService.createProfile(
          name: _nameController.text,
          type: _selectedType,
          bio: _bioController.text,
          handle: _handleController.text,
          location: _locationController.text,
          profileImageUrl: profileImageId ?? '',
          bannerImageUrl: bannerImageId ?? '',
        );

        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Profile Created!")));

        if (!_createMore) {
          Navigator.of(context).pop();
        } else {
          // Clear the form for the next entry
          _formKey.currentState!.reset();
          _nameController.clear();
          _bioController.clear();
          _handleController.clear();
          _locationController.clear();
          setState(() {
            _profileImage = null;
            _bannerImage = null;
            _selectedType = "profile";
          });
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create profile: $e')));
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 600, // Max width for tablet/desktop
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Header Section ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Create Profile",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      color: theme.iconTheme.color,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // --- Scrollable Form Content ---
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChannelHeader(
                        handleController: _handleController,
                        onBannerTap: () async {
                          final image = await _pickAndCropImage(
                            ImageSource.gallery,
                          );
                          if (image != null) {
                            setState(() {
                              _bannerImage = image;
                            });
                          }
                        },
                        onProfileTap: () async {
                          final image = await _pickAndCropImage(
                            ImageSource.gallery,
                          );
                          if (image != null) {
                            setState(() {
                              _profileImage = image;
                            });
                          }
                        },
                        bannerImage: _bannerImage,
                        profileImage: _profileImage,
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        controller: _nameController,
                        label: "Name",
                        hintText: "Enter a name for the profile",
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 24),
                      CustomDropdown(
                        label: "Type",
                        value: _selectedType,
                        items: const [
                          "profile",
                          "channel",
                          "thread",
                          "business",
                        ],
                        onChanged: (newValue) {
                          setState(() {
                            _selectedType = newValue!;
                          });
                        },
                        icon: Icons.category,
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        controller: _bioController,
                        label: "Bio",
                        hintText: "Tell us about yourself",
                        isSingleLine: false,
                        minLines: 3,
                        icon: Icons.description,
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        controller: _locationController,
                        label: "Location",
                        hintText: "Enter your location",
                        icon: Icons.location_on,
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // --- Footer Section (Toggle and Buttons) ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Create More Switch
                    Row(
                      children: [
                        Switch(
                          value: _createMore,
                          onChanged: (val) => setState(() => _createMore = val),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Create more",
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Cancel Button
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 12),

                    // Create Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Create"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
