import 'dart:io'; // For File type
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mindfeed/core/services/auth_service.dart';
import 'package:mindfeed/features/auth/screens/login_screen.dart';
import 'package:mindfeed/features/user_preferences/screens/topic_selection_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:dio/dio.dart'; // For Cloudinary upload
import 'package:flutter_spinkit/flutter_spinkit.dart';


// --- USER ACTION REQUIRED ---
// Replace with your actual Cloudinary details
const String cloudinaryCloudName = "db2vusdvh";
const String cloudinaryUploadPreset = "mindfeed_pfp_unsigned";
// --- END USER ACTION ---


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  User? _currentUser;
  Map<String, dynamic>? _userData;

  bool _isLoadingUserData = true;
  bool _isUploadingPfp = false;
  bool _isSavingDisplayName = false;

  final TextEditingController _displayNameController = TextEditingController();
  String _initialDisplayName = ''; // To track changes

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoadingUserData = true);
    _currentUser = _firebaseAuth.currentUser;

    if (_currentUser != null) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
        if (userDoc.exists) {
          _userData = userDoc.data() as Map<String, dynamic>?;
          _initialDisplayName = _userData?['displayName'] ?? _currentUser!.email?.split('@').first ?? '';
          _displayNameController.text = _initialDisplayName;
        } else {
          // This case should ideally be handled by ensureUserDataExists earlier in the flow
          // but as a fallback:
          await _authService.ensureUserDataExists(_currentUser!);
          DocumentSnapshot freshUserDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
           _userData = freshUserDoc.data() as Map<String, dynamic>?;
          _initialDisplayName = _userData?['displayName'] ?? _currentUser!.email?.split('@').first ?? '';
          _displayNameController.text = _initialDisplayName;
        }
      } catch (e) {
        print("Error loading user data in Settings: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading profile: ${e.toString()}"), backgroundColor: Colors.red),
          );
        }
      }
    }
    if (mounted) {
      setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _pickAndUploadProfilePicture() async {
    if (cloudinaryCloudName == "YOUR_CLOUD_NAME_HERE" || cloudinaryUploadPreset == "YOUR_UNSIGNED_UPLOAD_PRESET_HERE") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cloudinary is not configured by the developer."), backgroundColor: Colors.red),
        );
        return;
    }

    if (!mounted) return;
    setState(() => _isUploadingPfp = true);

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

      if (image == null || !mounted) {
        setState(() => _isUploadingPfp = false);
        return;
      }

      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatioPresets: [CropAspectRatioPreset.square],
        compressQuality: 70,
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Crop Profile Picture',
              toolbarColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).primaryColor,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true),
          IOSUiSettings(
              title: 'Crop Profile Picture',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
              minimumAspectRatio: 1.0),
        ],
      );

      if (croppedFile == null || !mounted) {
        setState(() => _isUploadingPfp = false);
        return;
      }

      File fileToUpload = File(croppedFile.path);
      String fileName = fileToUpload.path.split('/').last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(fileToUpload.path, filename: fileName),
        'upload_preset': cloudinaryUploadPreset,
      });

      Dio dio = Dio();
      Response response = await dio.post(
        "https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload",
        data: formData,
      );

      if (response.statusCode == 200 && response.data != null) {
        final String newPhotoUrl = response.data['secure_url'];
        await _firestore.collection('users').doc(_currentUser!.uid).update({'photoURL': newPhotoUrl});
        // Optionally update FirebaseAuth user photoURL
        // await _currentUser?.updatePhotoURL(newPhotoUrl); 
        // This often requires re-authentication, so updating Firestore is usually primary for app UI.
        
        if (mounted) {
          setState(() {
            _userData?['photoURL'] = newPhotoUrl; // Update local state for immediate UI change
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile picture updated successfully!"), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('Failed to upload image. Status: ${response.statusCode}');
      }
    } catch (e) {
      print("Error during profile picture update: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update profile picture: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPfp = false);
      }
    }
  }

  Future<void> _saveDisplayName() async {
    if (_displayNameController.text.trim() == _initialDisplayName || _currentUser == null) {
      return; // No change or no user
    }
    if (_displayNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Display name cannot be empty."), backgroundColor: Colors.orange),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSavingDisplayName = true);

    try {
      final newName = _displayNameController.text.trim();
      await _firestore.collection('users').doc(_currentUser!.uid).update({'displayName': newName});
      // await _currentUser?.updateDisplayName(newName); // Optional Firebase Auth update

      if (mounted) {
        setState(() {
          _initialDisplayName = newName; // Update initial name to reflect saved state
          _userData?['displayName'] = newName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Display name updated!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Error saving display name: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update display name: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingDisplayName = false);
      }
    }
  }

  void _navigateToTopicSelection() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const TopicSelectionScreen(isEditing: true),
    )).then((value) {
      // Optional: Reload user data if topics might affect something on this screen
      // For now, topic changes are self-contained.
      // _loadUserData();
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool hasDisplayNameChanged = _displayNameController.text.trim() != _initialDisplayName && _displayNameController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoadingUserData
          ? Center(child: SpinKitFadingCircle(color: Theme.of(context).colorScheme.primary))
          : _currentUser == null
              ? const Center(child: Text("User not found. Please log in again."))
              : RefreshIndicator( // Allows pull-to-refresh for user data
                  onRefresh: _loadUserData,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                    children: [
                      // --- Profile Picture and User Info ---
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _isUploadingPfp ? null : _pickAndUploadProfilePicture,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                    backgroundImage: (_userData?['photoURL'] != null && (_userData!['photoURL'] as String).isNotEmpty)
                                        ? CachedNetworkImageProvider(_userData!['photoURL'] as String)
                                        : null,
                                    child: (_userData?['photoURL'] == null || (_userData!['photoURL'] as String).isEmpty)
                                        ? Icon(Icons.person_outline, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant)
                                        : null,
                                  ),
                                  if (_isUploadingPfp)
                                    SpinKitFadingCircle(color: Theme.of(context).colorScheme.primary, size: 50.0),
                                  if (!_isUploadingPfp)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(Icons.edit, size: 20, color: Theme.of(context).colorScheme.onPrimary),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _userData?['displayName'] ?? _currentUser!.email?.split('@').first ?? 'User',
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              _currentUser!.email ?? '',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Divider(color: Colors.grey[800]),
                      const SizedBox(height: 16),

                      // --- Change Display Name ---
                      Text("Profile", style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Display Name',
                          // prefixIcon: Icon(Icons.person_outline),
                        ),
                        onChanged: (value) {
                          setState(() {
                            // This just triggers a rebuild to update button state
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: (hasDisplayNameChanged && !_isSavingDisplayName) ? _saveDisplayName : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (hasDisplayNameChanged && !_isSavingDisplayName)
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[600], // Disabled color
                            foregroundColor: (hasDisplayNameChanged && !_isSavingDisplayName)
                                ? Theme.of(context).colorScheme.onPrimary
                                : Colors.grey[400],
                          ),
                          child: _isSavingDisplayName
                              ? const SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                              : const Text('Save Name'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Divider(color: Colors.grey[800]),
                      const SizedBox(height: 16),

                      // --- Manage Interests ---
                       Text("Preferences", style: Theme.of(context).textTheme.titleMedium),
                       const SizedBox(height: 12),
                      ListTile(
                        leading: Icon(Icons.topic_outlined, color: Theme.of(context).colorScheme.primary),
                        title: const Text('Manage News Topics'),
                        // subtitle: const Text('Customize your feed'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onTap: _navigateToTopicSelection,
                        contentPadding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      const SizedBox(height: 40), // Spacer
                    ],
                  ),
                ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0), // Adjust padding for safe area
        child: ElevatedButton.icon(
          icon: const Icon(Icons.logout_outlined),
          label: const Text('Logout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent[400], // Slightly less intense red
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            await _authService.signOut();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            }
          },
        ),
      ),
    );
  }
}