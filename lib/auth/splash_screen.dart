import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';
import '../screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStateAndNavigate();
  }

  void _checkAuthStateAndNavigate() {
    // Wait for auth state to be ready, with minimum 2 seconds splash time
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        // If still loading, wait for auth state to be ready
        if (authProvider.isLoading()) {
          _waitForAuthStateAndNavigate();
        } else {
          _navigateBasedOnAuthState();
        }
      }
    });
  }

  void _waitForAuthStateAndNavigate() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check every 100ms if auth state is ready
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        if (!authProvider.isLoading()) {
          _navigateBasedOnAuthState();
        } else {
          _waitForAuthStateAndNavigate();
        }
      }
    });
  }

  bool _hasNavigated = false;

  void _navigateBasedOnAuthState() {
    if (_hasNavigated) return; // Prevent multiple navigations
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    print('DEBUG: SplashScreen - Current auth state: ${authProvider.authState}');
    
    Widget destination;
    
    if (authProvider.shouldShowHome()) {
      print('DEBUG: SplashScreen - Navigating to Home');
      destination = const HomeScreen();
    } else if (authProvider.shouldShowProfileSetup()) {
      print('DEBUG: SplashScreen - Navigating to Profile Setup');
      destination = const ProfileSetupScreen();
    } else {
      print('DEBUG: SplashScreen - Navigating to Login');
      destination = const LoginScreen();
    }
    
    _hasNavigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          // Auto navigate when auth state changes from loading
          if (!authProvider.isLoading() && !_hasNavigated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigateBasedOnAuthState();
            });
          }
          
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'FriendLink',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 24),
                CircularProgressIndicator(
                  color: Colors.blue.shade600,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}