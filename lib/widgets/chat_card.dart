import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../screens/chat_screen.dart';

class ChatCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onTap;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final String? currentUserId;

  const ChatCard({
    super.key,
    required this.user,
    this.onTap,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.currentUserId,
  });

  String _getDisplayMessage() {
    if (lastMessage?.isNotEmpty != true) {
      return user.about.isNotEmpty ? user.about : 'Hey there! I am using FriendLink.';
    }

    // Show "You: message" if current user sent the last message
    if (lastMessageSenderId != null && currentUserId != null && lastMessageSenderId == currentUserId) {
      return 'You: ${lastMessage!}';
    }

    // Show just the message if other user sent it
    return lastMessage!;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0, // Removed shadow
      color: Colors.white, // Pure white color
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200, // Subtle border for definition
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap ?? () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(user: user),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.blue.shade50, // Beautiful tap effect
        highlightColor: Colors.blue,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // Profile Image with enhanced styling
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blue.shade100,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.shade50,
                  backgroundImage: user.profileImageUrl.isNotEmpty
                      ? NetworkImage(user.profileImageUrl)
                      : null,
                  child: user.profileImageUrl.isEmpty
                      ? Icon(
                    Icons.person,
                    color: Colors.blue.shade600,
                    size: 34,
                  )
                      : null,
                ),
              ),

              const SizedBox(width: 18),

              // User Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name with improved styling
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Last message or about with improved styling
                    Text(
                      _getDisplayMessage(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: lastMessage?.isNotEmpty == true ? FontWeight.w400 : FontWeight.w300,
                        height: 1.2,
                      ),
                      maxLines: 2, // Increased to 2 lines for better readability
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Phone Number with improved styling
                    Text(
                      user.phoneNumber,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),

              // Enhanced Action Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.blue.shade600,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
