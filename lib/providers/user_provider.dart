import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String _error = '';

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String get error => _error;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  Future<String> uploadProfileImage(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final ref = _storage.ref().child('profile_images').child('${user.uid}.jpg');
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> createUserProfile({
    required String name,
    required String about,
    required File? profileImage,
    String? fcmToken,
    String? existingImageUrl,
  }) async {
    try {
      print('DEBUG: Starting profile creation...');
      setLoading(true);
      clearError();

      final user = _auth.currentUser;
      print('DEBUG: Current user: ${user?.uid}');
      if (user == null) throw Exception('User not authenticated');

      String profileImageUrl = existingImageUrl ?? '';
      if (profileImage != null) {
        print('DEBUG: Uploading new profile image...');
        profileImageUrl = await uploadProfileImage(profileImage);
        print('DEBUG: New image uploaded successfully: $profileImageUrl');
      } else if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
        print('DEBUG: Using existing image URL: $existingImageUrl');
        profileImageUrl = existingImageUrl;
      }

      // Get FCM token if not provided
      String finalFcmToken = fcmToken ?? '';
      if (finalFcmToken.isEmpty) {
        try {
          finalFcmToken = await FirebaseMessaging.instance.getToken() ?? '';
          print('DEBUG: FCM Token retrieved: $finalFcmToken');
        } catch (e) {
          print('DEBUG: Failed to get FCM token: $e');
        }
      }

      final userModel = UserModel(
        uid: user.uid,
        phoneNumber: user.phoneNumber ?? '',
        name: name,
        about: about,
        profileImageUrl: profileImageUrl,
        createdAt: DateTime.now(),
        fcmToken: finalFcmToken,
      );

      print('DEBUG: Creating Firestore document...');
      print('DEBUG: User data: ${userModel.toMap()}');
      
      // Add timeout and better error handling for Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toMap())
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Firestore operation timed out');
            },
          );
      print('DEBUG: Firestore document created successfully');
      
      _user = userModel;
      setLoading(false);
      print('DEBUG: Profile creation completed');
      
    } catch (e) {
      print('DEBUG: Error in createUserProfile: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      
      setLoading(false);
      
      // Provide more specific error messages
      String errorMessage;
      if (e.toString().contains('PERMISSION_DENIED')) {
        errorMessage = 'Permission denied. Please check Firestore rules.';
      } else if (e.toString().contains('UNAUTHENTICATED')) {
        errorMessage = 'User authentication failed. Please try logging in again.';
      } else if (e.toString().contains('UNAVAILABLE')) {
        errorMessage = 'Firestore is currently unavailable. Please try again later.';
      } else if (e.toString().contains('NOT_FOUND') && e.toString().contains('database')) {
        errorMessage = 'Firestore database not set up. Please create Firestore database in Firebase Console.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Operation timed out. Please check your internet connection.';
      } else {
        errorMessage = 'Failed to create profile: ${e.toString()}';
      }
      
      setError(errorMessage);
      throw Exception(errorMessage);
    }
  }

  Future<void> getUserProfile() async {
    try {
      setLoading(true);
      clearError();

      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        _user = UserModel.fromMap(doc.data()!);
      }
      
      setLoading(false);
      
    } catch (e) {
      setLoading(false);
      setError(e.toString());
    }
  }

  Future<void> updateUserProfile({
    String? name,
    String? about,
    File? profileImage,
  }) async {
    try {
      setLoading(true);
      clearError();

      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      Map<String, dynamic> updates = {};

      if (name != null) updates['name'] = name;
      if (about != null) updates['about'] = about;

      if (profileImage != null) {
        final imageUrl = await uploadProfileImage(profileImage);
        updates['profileImageUrl'] = imageUrl;
      }

      await _firestore.collection('users').doc(user.uid).update(updates);
      
      if (_user != null) {
        _user = _user!.copyWith(
          name: name ?? _user!.name,
          about: about ?? _user!.about,
          profileImageUrl: updates['profileImageUrl'] ?? _user!.profileImageUrl,
        );
      }
      
      setLoading(false);
      
    } catch (e) {
      setLoading(false);
      setError(e.toString());
      throw Exception('Failed to update user profile: $e');
    }
  }

  Future<void> updateFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
      if (fcmToken.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': fcmToken,
        });
        
        // Update local user model if it exists
        if (_user != null) {
          _user = _user!.copyWith(fcmToken: fcmToken);
          notifyListeners();
        }
      }
    } catch (e) {
      print('DEBUG: Failed to update FCM token: $e');
    }
  }

  void clearUser() {
    _user = null;
    _error = '';
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> testFirestoreConnection() async {
    try {
      print('DEBUG: Testing Firestore connection...');
      await _firestore.collection('test').doc('test').get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );
      print('DEBUG: Firestore connection successful');
      return true;
    } catch (e) {
      print('DEBUG: Firestore connection failed: $e');
      
      // Set specific error message for database not found
      if (e.toString().contains('NOT_FOUND') && e.toString().contains('database')) {
        setError('Firestore database not created. Please set up Firestore in Firebase Console.');
      } else if (e.toString().contains('timeout')) {
        setError('Connection timeout. Please check your internet connection.');
      } else {
        setError('Unable to connect to Firestore: ${e.toString()}');
      }
      
      return false;
    }
  }
}