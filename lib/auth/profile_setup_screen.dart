import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String? existingName;
  final String? existingAbout;
  final String? existingProfileImageUrl;
  
  const ProfileSetupScreen({
    super.key, 
    this.existingName,
    this.existingAbout,
    this.existingProfileImageUrl,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    // Pre-fill form with existing data if provided
    if (widget.existingName != null) {
      _nameController.text = widget.existingName!;
    }
    if (widget.existingAbout != null) {
      _aboutController.text = widget.existingAbout!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxHeight: 512,
        maxWidth: 512,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _proceedToApp() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    if (_aboutController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter about yourself')),
      );
      return;
    }

    try {
      print('DEBUG: Profile setup - Starting profile creation');
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Test Firestore connection first
      final isConnected = await userProvider.testFirestoreConnection();
      if (!isConnected) {
        throw Exception('Unable to connect to Firestore. Please check your internet connection.');
      }
      
      await userProvider.createUserProfile(
        name: _nameController.text.trim(),
        about: _aboutController.text.trim(),
        profileImage: _selectedImage,
        existingImageUrl: widget.existingProfileImageUrl,
      );

      print('DEBUG: Profile setup - Profile created, updating auth state');
      if (mounted) {
        // Update auth state to indicate profile is created
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.setProfileCreated();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
          (route) => false,
        );
      }
      
    } catch (e) {
      print('DEBUG: Profile setup - Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Complete Your Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your details to get started',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade100,
                        border: Border.all(
                          color: Colors.blue.shade300,
                          width: 2,
                        ),
                      ),
                      child: _selectedImage != null
                          ? ClipOval(
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : widget.existingProfileImageUrl != null && widget.existingProfileImageUrl!.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    widget.existingProfileImageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.camera_alt,
                                            size: 32,
                                            color: Colors.blue.shade600,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Add Photo',
                                            style: TextStyle(
                                              color: Colors.blue.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt,
                                  size: 32,
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add Photo',
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Your Name',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _aboutController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'About yourself...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  
                  if (userProvider.error.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        userProvider.error,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: userProvider.isLoading ? null : _proceedToApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: userProvider.isLoading
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Creating Profile...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Proceed',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}