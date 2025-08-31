import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AuthState {
  loading,
  loggedOut,
  loggedInWithoutProfile,
  loggedInWithProfile,
}

class AuthProvider extends ChangeNotifier {
  AuthState _authState = AuthState.loading;
  User? _currentUser;
  bool _hasProfile = false;

  AuthState get authState => _authState;
  User? get currentUser => _currentUser;
  bool get hasProfile => _hasProfile;
  bool get isLoggedIn => _currentUser != null;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    print('DEBUG: AuthProvider - Initializing authentication listener');
    
    _auth.authStateChanges().listen((User? user) async {
      print('DEBUG: AuthProvider - Auth state changed: ${user?.uid}');
      _currentUser = user;
      
      if (user == null) {
        print('DEBUG: AuthProvider - User is logged out');
        _authState = AuthState.loggedOut;
        _hasProfile = false;
      } else {
        print('DEBUG: AuthProvider - User is logged in, checking profile');
        await _checkUserProfile(user);
      }
      
      notifyListeners();
    });
  }

  Future<void> _checkUserProfile(User user) async {
    try {
      print('DEBUG: AuthProvider - Checking profile for user: ${user.uid}');
      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        print('DEBUG: AuthProvider - User has profile');
        _hasProfile = true;
        _authState = AuthState.loggedInWithProfile;
      } else {
        print('DEBUG: AuthProvider - User does not have profile');
        _hasProfile = false;
        _authState = AuthState.loggedInWithoutProfile;
      }
    } catch (e) {
      print('DEBUG: AuthProvider - Error checking profile: $e');
      _hasProfile = false;
      _authState = AuthState.loggedInWithoutProfile;
    }
  }

  Future<void> signOut() async {
    try {
      print('DEBUG: AuthProvider - Signing out user');
      await _auth.signOut();
      _currentUser = null;
      _hasProfile = false;
      _authState = AuthState.loggedOut;
      notifyListeners();
    } catch (e) {
      print('DEBUG: AuthProvider - Error signing out: $e');
      throw Exception('Failed to sign out: $e');
    }
  }

  Future<void> refreshAuthState() async {
    print('DEBUG: AuthProvider - Refreshing auth state');
    final user = _auth.currentUser;
    
    if (user != null) {
      await _checkUserProfile(user);
      notifyListeners();
    }
  }

  void setProfileCreated() {
    print('DEBUG: AuthProvider - Profile created, updating state');
    if (_currentUser != null) {
      _hasProfile = true;
      _authState = AuthState.loggedInWithProfile;
      notifyListeners();
    }
  }

  void setLoading() {
    _authState = AuthState.loading;
    notifyListeners();
  }

  // Method to check if user needs to complete profile
  bool shouldShowProfileSetup() {
    return _authState == AuthState.loggedInWithoutProfile;
  }

  // Method to check if user should go to home
  bool shouldShowHome() {
    return _authState == AuthState.loggedInWithProfile;
  }

  // Method to check if user should go to login
  bool shouldShowLogin() {
    return _authState == AuthState.loggedOut;
  }

  // Method to check if still loading
  bool isLoading() {
    return _authState == AuthState.loading;
  }
}