import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../widgets/message_input_field.dart';
import '../widgets/message_bubble.dart';
import 'user_details_screen.dart';

enum MessageType { text, image, video, document }
enum MediaType { image, video, document }

class MessageData {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final MessageType type;
  final String? mediaUrl;
  final String? fileName;
  final String? mimeType;
  final int? fileSize;

  MessageData({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    this.type = MessageType.text,
    this.mediaUrl,
    this.fileName,
    this.mimeType,
    this.fileSize,
  });

  factory MessageData.fromMap(String id, Map<String, dynamic> data) {
    return MessageData(
      id: id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      message: data['message'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0),
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${data['type'] ?? 'text'}',
        orElse: () => MessageType.text,
      ),
      mediaUrl: data['mediaUrl'],
      fileName: data['fileName'],
      mimeType: data['mimeType'],
      fileSize: data['fileSize'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': type.toString().split('.').last,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (fileName != null) 'fileName': fileName,
      if (mimeType != null) 'mimeType': mimeType,
      if (fileSize != null) 'fileSize': fileSize,
    };
  }
}

class ChatScreen extends StatefulWidget {
  final UserModel user;

  const ChatScreen({
    super.key,
    required this.user,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ScrollController _scrollController = ScrollController();
  
  List<MessageData> _messages = [];
  bool _isLoadingOlderMessages = false;
  static const int _messagesPerPage = 20;
  String? _lastMessageKey;
  bool _hasMoreMessages = true;
  bool _isInitialLoading = true;
  bool _chatExists = false;

  String _getChatDocumentId() {
    final currentUserId = _auth.currentUser?.uid ?? '';
    final otherUserId = widget.user.uid;
    
    // Create consistent document ID by sorting UIDs alphabetically
    final List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    return '${ids[0]}+${ids[1]}';
  }

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _listenForNewMessages();
    _scrollController.addListener(_scrollListener);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoadingOlderMessages && _hasMoreMessages) {
        _loadOlderMessages();
      }
    }
  }
  
  Future<void> _loadInitialMessages() async {
    final chatDocId = _getChatDocumentId();
    
    setState(() {
      _isInitialLoading = true;
    });
    
    // Add a delay to show the loading animation
    await Future.delayed(const Duration(seconds: 1));
    
    try {
      // Check if chat exists first
      final chatRef = _database.ref('chats').child(chatDocId);
      final chatSnapshot = await chatRef.get();
      
      if (chatSnapshot.exists) {
        final chatData = chatSnapshot.value as Map<dynamic, dynamic>?;
        _chatExists = chatData?['chatExists'] == true;
        
        if (_chatExists) {
          // Load messages
          final messagesRef = _database
              .ref('chats')
              .child(chatDocId)
              .child('messages');
          
          final query = messagesRef
              .orderByChild('timestamp')
              .limitToLast(_messagesPerPage);
          
          final snapshot = await query.get();
          
          if (snapshot.exists) {
            final Map<dynamic, dynamic> messagesData = snapshot.value as Map<dynamic, dynamic>;
            List<MessageData> messages = [];
            
            for (var entry in messagesData.entries) {
              final messageId = entry.key.toString();
              final messageData = Map<String, dynamic>.from(entry.value);
              
              try {
                final message = MessageData.fromMap(messageId, messageData);
                messages.add(message);
              } catch (e) {
                print('Error processing message $messageId: $e');
              }
            }
            
            // Sort by timestamp (newest first for display)
            messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            
            if (messages.isNotEmpty) {
              _lastMessageKey = messagesData.keys.first.toString();
              _hasMoreMessages = messages.length >= _messagesPerPage;
            }
            
            setState(() {
              _messages = messages;
              _isInitialLoading = false;
            });
            
            // Auto-scroll to bottom (latest message) with animation
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          } else {
            setState(() {
              _isInitialLoading = false;
            });
          }
        } else {
          setState(() {
            _isInitialLoading = false;
          });
        }
      } else {
        setState(() {
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      print('Error loading initial messages: $e');
      setState(() {
        _isInitialLoading = false;
      });
    }
  }
  
  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlderMessages || !_hasMoreMessages) return;
    
    setState(() {
      _isLoadingOlderMessages = true;
    });
    
    final chatDocId = _getChatDocumentId();
    final messagesRef = _database
        .ref('chats')
        .child(chatDocId)
        .child('messages');
    
    try {
      // Get timestamp of the oldest message we have
      final oldestTimestamp = _messages.last.timestamp.millisecondsSinceEpoch;
      
      // Load older messages
      final query = messagesRef
          .orderByChild('timestamp')
          .endBefore(oldestTimestamp)
          .limitToLast(_messagesPerPage);
      
      final snapshot = await query.get();
      
      if (snapshot.exists) {
        final Map<dynamic, dynamic> messagesData = snapshot.value as Map<dynamic, dynamic>;
        List<MessageData> olderMessages = [];
        
        for (var entry in messagesData.entries) {
          final messageId = entry.key.toString();
          final messageData = Map<String, dynamic>.from(entry.value);
          
          try {
            final message = MessageData.fromMap(messageId, messageData);
            olderMessages.add(message);
          } catch (e) {
            print('Error processing older message $messageId: $e');
          }
        }
        
        // Sort older messages by timestamp (newest first)
        olderMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        setState(() {
          _messages.addAll(olderMessages);
          _hasMoreMessages = olderMessages.length >= _messagesPerPage;
        });
      } else {
        setState(() {
          _hasMoreMessages = false;
        });
      }
    } catch (e) {
      print('Error loading older messages: $e');
    } finally {
      setState(() {
        _isLoadingOlderMessages = false;
      });
    }
  }
  
  void _listenForNewMessages() {
    final chatDocId = _getChatDocumentId();
    final messagesRef = _database
        .ref('chats')
        .child(chatDocId)
        .child('messages');
    
    // Listen for new messages added after the latest message we have
    messagesRef.orderByChild('timestamp').onChildAdded.listen((event) {
      if (event.snapshot.value != null) {
        try {
          final messageData = Map<String, dynamic>.from(event.snapshot.value as Map);
          final message = MessageData.fromMap(event.snapshot.key!, messageData);
          
          // Only add if this message is newer than our latest message
          if (_messages.isEmpty || message.timestamp.isAfter(_messages.first.timestamp)) {
            setState(() {
              _messages.insert(0, message);
            });
            
            // Auto-scroll to bottom when new message arrives
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients && _scrollController.position.pixels <= 100) {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        } catch (e) {
          print('Error processing new message: $e');
        }
      }
    });
  }

  Future<void> _onSendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final chatDocId = _getChatDocumentId();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Create message data with explicit timestamp
      final messageData = {
        'senderId': currentUser.uid,
        'receiverId': widget.user.uid,
        'message': message.trim(),
        'timestamp': timestamp,
        'type': 'text',
      };

      print('DEBUG: Sending message data: $messageData');

      // Send message to Realtime Database
      final DatabaseReference messagesRef = _database
          .ref('chats')
          .child(chatDocId)
          .child('messages');
      
      final newMessageRef = messagesRef.push();
      await newMessageRef.set(messageData);
      
      print('DEBUG: Message stored at path: chats/$chatDocId/messages/${newMessageRef.key}');

      // Update chat info with last message and ensure chatExists is true
      final DatabaseReference chatRef = _database.ref('chats').child(chatDocId);
      final chatData = {
        'chatExists': true,
        'lastMessage': message.trim(),
        'lastMessageTime': timestamp,
        'lastMessageSenderId': currentUser.uid,
        'participants': [currentUser.uid, widget.user.uid],
      };
      
      await chatRef.update(chatData);

      print('DEBUG: Message sent successfully to Realtime Database');
      print('DEBUG: Chat updated with data: $chatData');
      
      // Auto-scroll to bottom after sending message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
      
    } catch (e) {
      print('DEBUG: Error sending message to Realtime Database: $e');
      print('DEBUG: Error details: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMediaMessage({
    required MessageType type,
    required String mediaUrl,
    required String fileName,
    String? mimeType,
    int? fileSize,
    String additionalText = '',
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final chatDocId = _getChatDocumentId();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Create message data for media
      final messageData = {
        'senderId': currentUser.uid,
        'receiverId': widget.user.uid,
        'message': additionalText,
        'timestamp': timestamp,
        'type': type.toString().split('.').last,
        'mediaUrl': mediaUrl,
        'fileName': fileName,
        if (mimeType != null) 'mimeType': mimeType,
        if (fileSize != null) 'fileSize': fileSize,
      };

      print('DEBUG: Sending media message data: $messageData');

      // Send message to Realtime Database
      final DatabaseReference messagesRef = _database
          .ref('chats')
          .child(chatDocId)
          .child('messages');
      
      final newMessageRef = messagesRef.push();
      await newMessageRef.set(messageData);
      
      // Update chat info
      final DatabaseReference chatRef = _database.ref('chats').child(chatDocId);
      String lastMessageText;
      switch (type) {
        case MessageType.image:
          lastMessageText = '📷 Photo';
          break;
        case MessageType.video:
          lastMessageText = '🎥 Video';
          break;
        case MessageType.document:
          lastMessageText = '📄 Document';
          break;
        default:
          lastMessageText = fileName;
      }
      
      final chatData = {
        'chatExists': true,
        'lastMessage': lastMessageText,
        'lastMessageTime': timestamp,
        'lastMessageSenderId': currentUser.uid,
        'participants': [currentUser.uid, widget.user.uid],
      };
      
      await chatRef.update(chatData);

      print('DEBUG: Media message sent successfully');
      
    } catch (e) {
      print('DEBUG: Error sending media message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send media: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onAttachTap() async {
    // Pre-request storage permission to show native dialog immediately
    await Permission.storage.request();
    
    if (mounted) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Share',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.photo,
                    label: 'Photo',
                    color: Colors.green,
                    onTap: () => _pickMedia(MediaType.image),
                  ),
                  _buildAttachmentOption(
                    icon: Icons.videocam,
                    label: 'Video',
                    color: Colors.red,
                    onTap: () => _pickMedia(MediaType.video),
                  ),
                  _buildAttachmentOption(
                    icon: Icons.insert_drive_file,
                    label: 'Document',
                    color: Colors.blue,
                    onTap: () => _pickMedia(MediaType.document),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _requestPermissions(MediaType mediaType) async {
    // Request storage permission first - this will show native Android dialog
    final storageStatus = await Permission.storage.request();
    
    // For Android 13+ (API 33+), also try specific media permissions
    if (Platform.isAndroid) {
      try {
        if (mediaType == MediaType.image) {
          await Permission.photos.request();
        } else if (mediaType == MediaType.video) {
          await Permission.videos.request();
        }
      } catch (e) {
        // Ignore if these permissions are not available on this Android version
        print('Media permissions not available: $e');
      }
    }

    // Request camera permission if needed - this will also show native dialog
    bool hasCameraAccess = true;
    if (mediaType == MediaType.image || mediaType == MediaType.video) {
      final cameraStatus = await Permission.camera.request();
      hasCameraAccess = cameraStatus.isGranted;
    }

    // Check if we have basic storage access
    bool hasStorageAccess = storageStatus.isGranted;
    
    // For Android 13+, also check media permissions if available
    if (Platform.isAndroid && !hasStorageAccess) {
      try {
        if (mediaType == MediaType.image) {
          hasStorageAccess = await Permission.photos.isGranted;
        } else if (mediaType == MediaType.video) {
          hasStorageAccess = await Permission.videos.isGranted;
        }
      } catch (e) {
        // Ignore if these permissions are not available
      }
    }

    // Show simple error message if permissions denied
    if (!hasStorageAccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Text('Storage permission required to access files'),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return false;
    }

    if (!hasCameraAccess && (mediaType == MediaType.image || mediaType == MediaType.video)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.camera_alt, color: Colors.white),
                SizedBox(width: 8),
                Text('Camera permission required for photos/videos'),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }

    return hasStorageAccess && hasCameraAccess;
  }


  Future<void> _pickMedia(MediaType mediaType) async {
    Navigator.pop(context);
    
    try {
      // Request necessary permissions based on media type
      bool permissionsGranted = await _requestPermissions(mediaType);
      if (!permissionsGranted) {
        return;
      }

      FilePickerResult? result;
      
      switch (mediaType) {
        case MediaType.image:
          result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: false,
          );
          break;
        case MediaType.video:
          result = await FilePicker.platform.pickFiles(
            type: FileType.video,
            allowMultiple: false,
          );
          break;
        case MediaType.document:
          result = await FilePicker.platform.pickFiles(
            type: FileType.any,
            allowMultiple: false,
          );
          break;
      }

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;
        
        // Upload file to Firebase Storage (progress dialog will be shown inside)
        final downloadUrl = await _uploadFileToStorage(file, fileName);
        
        // Hide upload progress dialog
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        
        // Determine message type
        MessageType messageType;
        String? mimeType = result.files.single.extension;
        
        if (mediaType == MediaType.image) {
          messageType = MessageType.image;
        } else if (mediaType == MediaType.video) {
          messageType = MessageType.video;
        } else {
          messageType = MessageType.document;
        }
        
        // Send media message
        await _sendMediaMessage(
          type: messageType,
          mediaUrl: downloadUrl,
          fileName: fileName,
          mimeType: mimeType,
          fileSize: fileSize,
        );
        
      }
    } catch (e) {
      // Hide upload progress if it was shown
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      print('Error picking/uploading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _uploadFileToStorage(File file, String fileName) async {
    final currentUser = _auth.currentUser!;
    final chatDocId = _getChatDocumentId();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Create unique filename
    final fileExtension = path.extension(fileName);
    final uniqueFileName = '${timestamp}_$fileName';
    
    // Upload to Firebase Storage
    final storageRef = _storage
        .ref()
        .child('chats')
        .child(chatDocId)
        .child(uniqueFileName);
    
    final uploadTask = storageRef.putFile(file);
    
    // Show upload progress dialog
    _showUploadProgressDialog(uploadTask, fileName);
    
    final snapshot = await uploadTask;
    
    return await snapshot.ref.getDownloadURL();
  }

  void _showUploadProgressDialog(UploadTask uploadTask, String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: StreamBuilder<TaskSnapshot>(
              stream: uploadTask.snapshotEvents,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final progress = snapshot.data!.bytesTransferred / snapshot.data!.totalBytes;
                  final percentage = (progress * 100).toInt();
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Loading animation
                      LoadingAnimationWidget.staggeredDotsWave(
                        color: Colors.blue.shade600,
                        size: 50,
                      ),
                      const SizedBox(height: 20),
                      
                      // Progress bar
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                      ),
                      const SizedBox(height: 12),
                      
                      // Percentage text
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // File name
                      Text(
                        'Uploading ${_getShortFileName(fileName)}...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      
                      // Data transferred
                      Text(
                        '${_formatBytes(snapshot.data!.bytesTransferred)} / ${_formatBytes(snapshot.data!.totalBytes)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  );
                }
                
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LoadingAnimationWidget.staggeredDotsWave(
                      color: Colors.blue.shade600,
                      size: 50,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Preparing upload...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _getShortFileName(String fileName) {
    if (fileName.length <= 30) return fileName;
    
    final extension = fileName.contains('.') ? fileName.split('.').last : '';
    final nameWithoutExt = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
    
    if (nameWithoutExt.length <= 25) {
      return fileName;
    }
    
    return '${nameWithoutExt.substring(0, 25)}...${extension.isNotEmpty ? '.$extension' : ''}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  
  Widget _buildInitialLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LoadingAnimationWidget.staggeredDotsWave(
            color: Colors.blue.shade600,
            size: 60,
          ),
          const SizedBox(height: 24),
          Text(
            'Searching chat...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Looking for messages with ${widget.user.name}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 60,
              color: Colors.blue.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _chatExists ? 'No messages found' : 'No chats found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _chatExists ? 'Start a conversation with ${widget.user.name}' : 'Let\'s begin a chat',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_emotions_outlined, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Say hello to ${widget.user.name}! 👋',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: Colors.blue.shade600,
          size: 30,
        ),
      ),
    );
  }
  
  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_arrow_up,
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Scroll up to load older messages',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Back button with professional styling
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.arrow_back_ios_rounded, 
                            color: Colors.white, 
                            size: 20
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Clickable User profile section with professional styling
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserDetailsScreen(user: widget.user),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              // Enhanced profile image
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.blue.shade100,
                                  backgroundImage: widget.user.profileImageUrl.isNotEmpty
                                      ? NetworkImage(widget.user.profileImageUrl)
                                      : null,
                                  child: widget.user.profileImageUrl.isEmpty
                                      ? Icon(
                                          Icons.person_rounded,
                                          color: Colors.blue.shade600,
                                          size: 26,
                                        )
                                      : null,
                                ),
                              ),
                              
                              const SizedBox(width: 16),
                              
                              // Enhanced user info section
                              Expanded(
                                child: Text(
                                  widget.user.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Chat messages area with professional gradient background
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey.shade50,
                    Colors.white,
                  ],
                ),
              ),
              child: _isInitialLoading
                  ? _buildInitialLoadingScreen()
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Show latest messages at bottom
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length + (_isLoadingOlderMessages ? 1 : 0) + (_hasMoreMessages && _messages.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Loading indicator at the top (end of list due to reverse)
                        if (_isLoadingOlderMessages && index == _messages.length) {
                          return _buildLoadingIndicator();
                        }
                        
                        // "Load more" indicator when there are more messages
                        if (_hasMoreMessages && _messages.isNotEmpty && index == _messages.length) {
                          return _buildLoadMoreIndicator();
                        }
                        
                        final message = _messages[index];
                        final currentUserId = _auth.currentUser?.uid ?? '';
                        final isCurrentUser = message.senderId == currentUserId;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: MessageBubble(
                            message: message.message,
                            isCurrentUser: isCurrentUser,
                            timestamp: message.timestamp,
                            senderName: isCurrentUser ? 'You' : widget.user.name,
                            messageType: message.type,
                            mediaUrl: message.mediaUrl,
                            fileName: message.fileName,
                            mimeType: message.mimeType,
                          ),
                        );
                      },
                    ),
            ),
          ),
          
          // Message input field at bottom with professional styling
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: MessageInputField(
              onSendMessage: _onSendMessage,
              onAttachTap: _onAttachTap,
              hintText: 'Message ${widget.user.name}...',
            ),
          ),
        ],
      ),
    );
  }
}