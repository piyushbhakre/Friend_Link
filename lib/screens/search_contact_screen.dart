import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/user_model.dart';
import '../widgets/chat_card.dart';
import 'chat_screen.dart';

class SearchContactScreen extends StatefulWidget {
  const SearchContactScreen({super.key});

  @override
  State<SearchContactScreen> createState() => _SearchContactScreenState();
}

class _SearchContactScreenState extends State<SearchContactScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isSearching = false;
  UserModel? _foundUser;
  bool _showNoResults = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the +91 prefix
    _phoneController.text = '+91';
    _phoneController.selection = TextSelection.fromPosition(
      TextPosition(offset: _phoneController.text.length),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneNumberChanged(String value) {
    // Ensure +91 prefix is always there
    if (!value.startsWith('+91')) {
      _phoneController.text = '+91';
      _phoneController.selection = TextSelection.fromPosition(
        TextPosition(offset: _phoneController.text.length),
      );
      return;
    }

    // Auto-search when user completes 10 digits after +91
    if (value.length == 13) { // +91 + 10 digits = 13 characters
      _searchUser(value);
    } else {
      // Clear results if phone number is not complete
      setState(() {
        _foundUser = null;
        _showNoResults = false;
        _isSearching = false;
      });
    }
  }

  Future<void> _searchUser(String phoneNumber) async {
    // Check if user entered their own number
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        final currentUserDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (currentUserDoc.exists) {
          final currentUserData = currentUserDoc.data()!;
          final currentUserPhone = currentUserData['phoneNumber'];
          
          if (phoneNumber == currentUserPhone) {
            // Show toast message
            Fluttertoast.showToast(
              msg: "Don't enter your own number",
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.TOP,
              timeInSecForIosWeb: 3,
              backgroundColor: Colors.red.shade600,
              textColor: Colors.white,
              fontSize: 16.0,
            );
            return;
          }
        }
      } catch (e) {
        print('Error checking current user: $e');
      }
    }

    setState(() {
      _isSearching = true;
      _foundUser = null;
      _showNoResults = false;
    });

    HapticFeedback.lightImpact();

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        final foundUser = UserModel.fromMap(userData);
        
        // Double check it's not the current user (by UID)
        if (foundUser.uid != currentUser?.uid) {
          setState(() {
            _foundUser = foundUser;
            _showNoResults = false;
            _isSearching = false;
          });
          HapticFeedback.selectionClick();
        } else {
          // Show toast if somehow got here
          Fluttertoast.showToast(
            msg: "Don't enter your own number",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.TOP,
            timeInSecForIosWeb: 3,
            backgroundColor: Colors.red.shade600,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      } else {
        setState(() {
          _foundUser = null;
          _showNoResults = true;
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _foundUser = null;
        _showNoResults = true;
        _isSearching = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Error searching user: $e'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _onChatTap() {
    if (_foundUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(user: _foundUser!),
        ),
      );
    }
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.search,
              color: Colors.grey.shade500,
              size: 20,
            ),
          ),

          // Phone input field
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 13,
              onChanged: _onPhoneNumberChanged,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: '+91 98765 43210',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                counterText: '',
              ),
            ),
          ),

          // Clear button or success indicator
          if (_phoneController.text.length > 3)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _phoneController.text.length == 13
                  ? Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 20,
              )
                  : GestureDetector(
                onTap: () {
                  _phoneController.text = '+91';
                  _phoneController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _phoneController.text.length),
                  );
                  setState(() {
                    _foundUser = null;
                    _showNoResults = false;
                    _isSearching = false;
                  });
                },
                child: Icon(
                  Icons.clear,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Searching...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_foundUser != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Search Result',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ChatCard(
            user: _foundUser!,
            onTap: _onChatTap,
          ),
        ],
      );
    }

    if (_showNoResults) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.person_search,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No user found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure the phone number is correct\nand the user is registered on FriendLink.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default empty state
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.contacts,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Enter phone number to search',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.grey.shade200,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.grey.shade700,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Find Friends',
          style: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Search instruction
            Text(
              'Search by phone number',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 12),

            // Search bar
            _buildSearchBar(),

            const SizedBox(height: 24),

            // Search results
            Expanded(
              child: _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }
}
