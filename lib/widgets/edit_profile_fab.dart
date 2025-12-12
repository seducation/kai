import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/appwrite_service.dart';
import 'package:provider/provider.dart';

class EditProfileFAB extends StatelessWidget {
  const EditProfileFAB({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => const ChannelSettingsDialog(),
        );
      },
      child: const Icon(Icons.edit),
    );
  }
}

class ChannelSettingsDialog extends StatefulWidget {
  const ChannelSettingsDialog({super.key});

  @override
  State<ChannelSettingsDialog> createState() => _ChannelSettingsDialogState();
}

class _ChannelSettingsDialogState extends State<ChannelSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _handleController = TextEditingController();
  final _locationController = TextEditingController();
  String _privacy = 'Public';
  String? _profileId;
  File? _profileImage;
  File? _bannerImage;
  String? _profileImageUrl;
  String? _bannerImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final appwriteService =
          Provider.of<AppwriteService>(context, listen: false);
      final user = await appwriteService.getUser();
      if (user != null) {
        final profiles = await appwriteService.getUserProfiles(ownerId: user.$id);
        if (profiles.rows.isNotEmpty) {
          final profile = profiles.rows.first;
          setState(() {
            _profileId = profile.$id;
            _nameController.text = profile.data['name'] ?? '';
            _bioController.text = profile.data['bio'] ?? '';
            _handleController.text = profile.data['handle'] ?? '';
            _locationController.text = profile.data['location'] ?? '';
            _privacy = profile.data['privacy'] ?? 'Public';

            final profileImageId = profile.data['profileImageUrl'];
            if (profileImageId != null && profileImageId.isNotEmpty) {
              _profileImageUrl = appwriteService.getFileViewUrl(profileImageId);
            }

            final bannerImageId = profile.data['bannerImageUrl'];
            if (bannerImageId != null && bannerImageId.isNotEmpty) {
              _bannerImageUrl = appwriteService.getFileViewUrl(bannerImageId);
            }
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

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
            lockAspectRatio: false),
        IOSUiSettings(
          title: 'Cropper',
        ),
      ],
    );

    return croppedFile != null ? File(croppedFile.path) : null;
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate() && _profileId != null) {
      try {
        final appwriteService =
            Provider.of<AppwriteService>(context, listen: false);

        final Map<String, dynamic> dataToUpdate = {
          'name': _nameController.text,
          'bio': _bioController.text,
          'handle': _handleController.text,
          'location': _locationController.text,
          'privacy': _privacy,
        };

        if (_profileImage != null) {
          final file = await appwriteService.uploadFile(
            bytes: _profileImage!.readAsBytesSync(),
            filename: _profileImage!.path.split('/').last,
          );
          dataToUpdate['profileImageUrl'] = file.$id;
        }

        if (_bannerImage != null) {
          final file = await appwriteService.uploadFile(
            bytes: _bannerImage!.readAsBytesSync(),
            filename: _bannerImage!.path.split('/').last,
          );
          dataToUpdate['bannerImageUrl'] = file.$id;
        }

        await appwriteService.updateProfile(
          profileId: _profileId!,
          data: dataToUpdate,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated!")),
        );
        Navigator.of(context).pop();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              const Divider(thickness: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: <Widget>[
                      ChannelHeader(
                        handleController: _handleController,
                        onBannerTap: () async {
                          final image = await _pickAndCropImage(ImageSource.gallery);
                          if (image != null) {
                            setState(() {
                              _bannerImage = image;
                            });
                          }
                        },
                        onProfileTap: () async {
                          final image = await _pickAndCropImage(ImageSource.gallery);
                          if (image != null) {
                            setState(() {
                              _profileImage = image;
                            });
                          }
                        },
                        bannerImage: _bannerImage,
                        profileImage: _profileImage,
                        bannerImageUrl: _bannerImageUrl,
                        profileImageUrl: _profileImageUrl,
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        controller: _nameController,
                        label: "Name",
                        hintText: "Enter your channel name",
                        icon: Icons.edit,
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        controller: _bioController,
                        label: "Bio",
                        hintText: "Enter your bio",
                        minLines: 3,
                        isSingleLine: false,
                        icon: Icons.description,
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        controller: _locationController,
                        label: "Location",
                        hintText: "Enter your location",
                        icon: Icons.location_on,
                      ),
                      const SizedBox(height: 24),
                      CustomDropdown(
                        key: ValueKey(_privacy),
                        label: "Privacy",
                        icon: Icons.lock,
                        value: _privacy,
                        items: const [
                          'Public',
                          'Private',
                          'Private for some people'
                        ],
                        onChanged: (value) {
                          setState(() {
                            _privacy = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Channel settings',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

class ChannelHeader extends StatelessWidget {
  final TextEditingController handleController;
  final VoidCallback onBannerTap;
  final VoidCallback onProfileTap;
  final File? bannerImage;
  final File? profileImage;
  final String? bannerImageUrl;
  final String? profileImageUrl;

  const ChannelHeader({
    super.key,
    required this.handleController,
    required this.onBannerTap,
    required this.onProfileTap,
    this.bannerImage,
    this.profileImage,
    this.bannerImageUrl,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget bannerWidget;
    if (bannerImage != null) {
      bannerWidget = Image.file(bannerImage!, fit: BoxFit.cover);
    } else if (bannerImageUrl != null && bannerImageUrl!.isNotEmpty) {
      bannerWidget = CachedNetworkImage(
        imageUrl: bannerImageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: theme.colorScheme.secondaryContainer),
        errorWidget: (context, url, error) =>
            Center(child: Icon(Icons.image, color: theme.colorScheme.onSecondaryContainer)),
      );
    } else {
      bannerWidget = Center(
          child: Icon(Icons.image,
              color: theme.colorScheme.onSecondaryContainer, size: 50));
    }

    return Column(
      children: [
        GestureDetector(
          onTap: onBannerTap,
          child: SizedBox(
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                bannerWidget,
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(128),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: onProfileTap,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: ClipOval(
                        child: SizedBox.fromSize(
                          size: const Size.fromRadius(40),
                          child: (
                            profileImage != null 
                            ? Image.file(profileImage!, fit: BoxFit.cover)
                            : (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                              ? CachedNetworkImage(
                                  imageUrl: profileImageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) => Icon(Icons.person, size: 50, color: theme.colorScheme.onSecondaryContainer),
                                )
                              : Icon(Icons.person, size: 50, color: theme.colorScheme.onSecondaryContainer)
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(128),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: CustomTextField(
                controller: handleController,
                label: "Handle",
                hintText: "Enter your handle",
                icon: Icons.alternate_email,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// --- Reusable Custom Input Field with NULL Checkbox and Counter ---
class CustomTextField extends StatefulWidget {
  final String label;
  final String hintText;
  final int? maxLength;
  final int minLines;
  final bool isSingleLine;
  final IconData icon;
  final TextEditingController controller;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hintText,
    this.maxLength,
    this.minLines = 1,
    this.isSingleLine = false,
    required this.icon,
    required this.controller,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Row (title optional)
        Row(
          children: [
            Icon(widget.icon, size: 14, color: theme.iconTheme.color),
            const SizedBox(width: 6),
            RichText(
              text: TextSpan(
                text: widget.label,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Input Container with Counter
        Container(
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: widget.controller,
                maxLines: widget.isSingleLine ? 1 : widget.minLines,
                maxLength: widget.maxLength,
                style: TextStyle(
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: theme.inputDecorationTheme.hintStyle,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  counterText: "", // Hide default counter provided by maxLength
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a value';
                  }
                  return null;
                },
              ),

              // Footer inside the input box (Counter)
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 8, bottom: 4),
                child: Row(
                  children: [
                    // Custom Counter
                    if (widget.maxLength != null)
                      ValueListenableBuilder(
                        valueListenable: widget.controller,
                        builder: (context, TextEditingValue value, _) {
                          return Text(
                            "${value.text.length}/${widget.maxLength}",
                            style: theme.textTheme.bodySmall,
                          );
                        },
                      ),
                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CustomDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const CustomDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.iconTheme.color),
            const SizedBox(width: 6),
            RichText(
              text: TextSpan(
                text: label,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.dividerColor),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            items: items.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
