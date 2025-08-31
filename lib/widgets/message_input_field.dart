import 'package:flutter/material.dart';

class MessageInputField extends StatefulWidget {
  final Function(String)? onSendMessage;
  final VoidCallback? onAttachTap;
  final String hintText;

  const MessageInputField({
    super.key,
    this.onSendMessage,
    this.onAttachTap,
    this.hintText = 'Type a message...',
  });

  @override
  State<MessageInputField> createState() => _MessageInputFieldState();
}

class _MessageInputFieldState extends State<MessageInputField> {
  final TextEditingController _messageController = TextEditingController();
  bool _isMessageEmpty = true;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onMessageChanged() {
    final isEmpty = _messageController.text.trim().isEmpty;
    if (isEmpty != _isMessageEmpty) {
      setState(() {
        _isMessageEmpty = isEmpty;
      });
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isNotEmpty && widget.onSendMessage != null) {
      widget.onSendMessage!(message);
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attach button
            IconButton(
              onPressed: widget.onAttachTap,
              icon: Icon(
                Icons.attach_file,
                color: Colors.grey.shade600,
              ),
            ),
            
            // Message input field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Send button
            Container(
              decoration: BoxDecoration(
                color: _isMessageEmpty 
                    ? Colors.grey.shade400 
                    : Colors.blue.shade600,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isMessageEmpty ? null : _sendMessage,
                icon: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}