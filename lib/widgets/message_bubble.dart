import 'package:flutter/material.dart';
import '../screens/chat_screen.dart';
import 'media_viewers.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;
  final DateTime timestamp;
  final String senderName;
  final MessageType messageType;
  final String? mediaUrl;
  final String? fileName;
  final String? mimeType;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.timestamp,
    required this.senderName,
    this.messageType = MessageType.text,
    this.mediaUrl,
    this.fileName,
    this.mimeType,
  });

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  Widget _buildMediaContent() {
    switch (messageType) {
      case MessageType.image:
        return ImageViewer(
          imageUrl: mediaUrl!,
          fileName: fileName,
        );
      case MessageType.video:
        return VideoViewer(
          videoUrl: mediaUrl!,
          fileName: fileName,
        );
      case MessageType.document:
        return DocumentViewer(
          documentUrl: mediaUrl!,
          fileName: fileName ?? 'Document',
          mimeType: mimeType,
        );
      case MessageType.text:
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isCurrentUser ? 80 : 12,
          right: isCurrentUser ? 12 : 80,
          top: 6,
          bottom: 6,
        ),
        child: Column(
          crossAxisAlignment: isCurrentUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Sender name for received messages
            if (!isCurrentUser)
              Container(
                margin: const EdgeInsets.only(left: 16, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

            // Message bubble
            Container(
              decoration: BoxDecoration(
                gradient: isCurrentUser
                    ? LinearGradient(
                  colors: [
                    Colors.blue.shade600,
                    Colors.blue.shade500,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : LinearGradient(
                  colors: [
                    Colors.grey.shade50,
                    Colors.grey.shade100,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isCurrentUser
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: isCurrentUser
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isCurrentUser
                        ? Colors.blue.shade200.withOpacity(0.3)
                        : Colors.grey.shade300.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                    spreadRadius: 0,
                  ),
                ],
                border: isCurrentUser
                    ? null
                    : Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: messageType != MessageType.text ? 8 : 16,
                  vertical: messageType != MessageType.text ? 8 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Media content
                    if (messageType != MessageType.text && mediaUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildMediaContent(),
                      ),
                      if (message.isNotEmpty) const SizedBox(height: 10),
                    ],

                    // Message text (if any)
                    if (message.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          left: messageType != MessageType.text ? 8 : 0,
                          right: messageType != MessageType.text ? 8 : 0,
                          bottom: 4,
                        ),
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: isCurrentUser
                                ? Colors.white
                                : Colors.grey.shade800,
                            height: 1.4,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),

                    const SizedBox(height: 2),

                    // Timestamp and status
                    Padding(
                      padding: EdgeInsets.only(
                        left: messageType != MessageType.text && message.isNotEmpty ? 8 : 0,
                        right: messageType != MessageType.text && message.isNotEmpty ? 8 : 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrentUser
                                  ? Colors.white.withOpacity(0.15)
                                  : Colors.grey.shade200.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _formatTime(timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isCurrentUser
                                    ? Colors.white.withOpacity(0.9)
                                    : Colors.grey.shade600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),

                          // Delivery status for sent messages
                          if (isCurrentUser) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.done_all_rounded,
                                size: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
