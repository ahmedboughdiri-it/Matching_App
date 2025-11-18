import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../models/report_model.dart';
import '../service/huggingface_moderation_service.dart';

class ChatPage extends StatefulWidget {
  final int userId;
  final UserModel otherUser;

  const ChatPage({
    super.key,
    required this.userId,
    required this.otherUser,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final dbHelper = DatabaseHelper.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MessageModel> messages = [];
  bool isLoading = true;
  bool isBlocked = false;
  bool isSending = false; // To show loading state

  @override
  void initState() {
    super.initState();
    _checkBlockStatus();
    _loadMessages();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => isLoading = true);

    final conversationData = await dbHelper.getConversation(
      widget.userId,
      widget.otherUser.id!,
    );

    setState(() {
      messages = conversationData.map((e) => MessageModel.fromMap(e)).toList();
      isLoading = false;
    });

    // Scroll to bottom after loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _markMessagesAsRead() async {
    await dbHelper.markMessagesAsRead(widget.userId, widget.otherUser.id!);
  }

  Future<void> _checkBlockStatus() async {
    final blocked = await dbHelper.isUserBlocked(widget.userId, widget.otherUser.id!);
    setState(() {
      isBlocked = blocked;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || isSending) return;

    // Check if users are blocked
    if (isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ You cannot message this user. They have been blocked.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show loading state
    setState(() {
      isSending = true;
    });

    // 🔹 AI MODERATION CHECK using OpenAI
    try {
      final moderationResult = await HuggingFaceModerationService.moderateMessage(text);

      if (moderationResult['isInappropriate']) {
        final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

        // Create report
        final report = ReportModel(
          reporterId: widget.otherUser.id!, // Receiver is the one being protected
          reportedId: widget.userId, // Sender is the one who sent bad message
          type: moderationResult['type'] ?? 'harassment',
          reason: text, // Store the offensive message
          timestamp: timestamp,
          isBlocked: true,
        );

        await dbHelper.insertReport(report.toMap());

        // Update blocked status
        setState(() {
          isBlocked = true;
          isSending = false;
        });

        // Show warning to sender
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(HuggingFaceModerationService.getWarningMessage(moderationResult['type'])),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );

        _messageController.clear();
        return;
      }

      // Message is appropriate, send it
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final message = MessageModel(
        senderId: widget.userId,
        receiverId: widget.otherUser.id!,
        message: text,
        timestamp: timestamp,
      );

      await dbHelper.insertMessage(message.toMap());
      _messageController.clear();

      setState(() {
        isSending = false;
      });

      await _loadMessages();
    } catch (e) {
      setState(() {
        isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _formatMessageTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return DateFormat('h:mm a').format(date);
    } catch (e) {
      return '';
    }
  }

  String _getDateLabel(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(date.year, date.month, date.day);

      if (messageDate == today) {
        return 'Today';
      } else if (messageDate == today.subtract(const Duration(days: 1))) {
        return 'Yesterday';
      } else {
        return DateFormat('MMMM d, yyyy').format(date);
      }
    } catch (e) {
      return '';
    }
  }

  bool _shouldShowDateLabel(int index) {
    if (index == 0) return true;

    try {
      final currentDate = DateTime.parse(messages[index].timestamp);
      final previousDate = DateTime.parse(messages[index - 1].timestamp);

      return currentDate.day != previousDate.day ||
          currentDate.month != previousDate.month ||
          currentDate.year != previousDate.year;
    } catch (e) {
      return false;
    }
  }

  Widget _buildDateLabel(String timestamp) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _getDateLabel(timestamp),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    final isSentByMe = message.senderId == widget.userId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
        isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSentByMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage(
                widget.otherUser.photoUrl?.isNotEmpty == true
                    ? widget.otherUser.photoUrl!
                    : 'assets/images/placeholder.jpg',
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isSentByMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSentByMe
                        ? const Color(0xFFFF6B9D)
                        : Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isSentByMe ? 20 : 4),
                      bottomRight: Radius.circular(isSentByMe ? 4 : 20),
                    ),
                  ),
                  child: Text(
                    message.message,
                    style: TextStyle(
                      fontSize: 15,
                      color: isSentByMe ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatMessageTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (isSentByMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all,
                        size: 14,
                        color: message.isRead
                            ? const Color(0xFFFF6B9D)
                            : Colors.grey[400],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isSentByMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage(
                widget.otherUser.photoUrl?.isNotEmpty == true
                    ? widget.otherUser.photoUrl!
                    : 'assets/images/placeholder.jpg',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.name ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isBlocked ? Colors.red : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isBlocked ? 'Blocked' : 'Online',
                        style: TextStyle(
                          color: isBlocked ? Colors.red : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              // Add more options
            },
          ),
        ],
      ),
      body: isBlocked
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.block,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'This conversation is blocked',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Inappropriate content was detected by AI and this user has been blocked from messaging.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Messages List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a conversation with ${widget.otherUser.name}!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return Column(
                  children: [
                    if (_shouldShowDateLabel(index))
                      _buildDateLabel(message.timestamp),
                    _buildMessageBubble(message),
                  ],
                );
              },
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Clock Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
                      onPressed: () {
                        // Add scheduled message functionality
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Text Input
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Your message',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send Button with loading state
                  GestureDetector(
                    onTap: isSending ? null : _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSending
                              ? [Colors.grey, Colors.grey]
                              : [const Color(0xFFFF6B9D), const Color(0xFFFF5E7A)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: isSending
                          ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Icon(
                        _messageController.text.isEmpty
                            ? Icons.mic
                            : Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}