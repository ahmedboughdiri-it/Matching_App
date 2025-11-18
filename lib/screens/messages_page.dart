import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';
import 'chat_page.dart';

class MessagesPage extends StatefulWidget {
  final int userId;

  const MessagesPage({super.key, required this.userId});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> conversations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => isLoading = true);

    final conversationsData = await dbHelper.getConversationsForUser(widget.userId);
    List<Map<String, dynamic>> formattedConversations = [];

    for (var conv in conversationsData) {
      final otherUserId = conv['other_user_id'] as int;
      final userData = await dbHelper.getUserById(otherUserId);

      if (userData != null) {
        final lastMessage = await dbHelper.getLastMessage(widget.userId, otherUserId);
        final unreadCount = await dbHelper.getUnreadMessageCount(widget.userId, otherUserId);

        formattedConversations.add({
          'user': UserModel.fromMap(userData),
          'lastMessage': lastMessage?['message'] ?? '',
          'timestamp': lastMessage?['timestamp'] ?? '',
          'unreadCount': unreadCount,
          'isSentByMe': lastMessage?['sender_id'] == widget.userId,
        });
      }
    }

    setState(() {
      conversations = formattedConversations;
      isLoading = false;
    });
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';

    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
      } else {
        return DateFormat('MMM d').format(date);
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildActivityCircle(UserModel user) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFF6B9D),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          user.photoUrl?.isNotEmpty == true
              ? user.photoUrl!
              : 'assets/images/placeholder.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Icon(Icons.person, size: 32, color: Colors.white),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune, size: 24),
                    onPressed: () {
                      // Add filter functionality if needed
                    },
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) {
                    // Add search functionality
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Activities Section
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activities',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: conversations.length > 5 ? 5 : conversations.length,
                      itemBuilder: (context, index) {
                        final conv = conversations[index];
                        final user = conv['user'] as UserModel;

                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    userId: widget.userId,
                                    otherUser: user,
                                  ),
                                ),
                              );
                              _loadConversations();
                            },
                            child: Column(
                              children: [
                                _buildActivityCircle(user),
                                const SizedBox(height: 4),
                                Text(
                                  user.name ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Messages Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Messages',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Conversations List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : conversations.isEmpty
                  ? const Center(
                child: Text(
                  'No messages yet 💬',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
                  : RefreshIndicator(
                onRefresh: _loadConversations,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conv = conversations[index];
                    final user = conv['user'] as UserModel;
                    final lastMessage = conv['lastMessage'] as String;
                    final timestamp = conv['timestamp'] as String;
                    final unreadCount = conv['unreadCount'] as int;
                    final isSentByMe = conv['isSentByMe'] as bool;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                userId: widget.userId,
                                otherUser: user,
                              ),
                            ),
                          );
                          _loadConversations();
                        },
                        child: Row(
                          children: [
                            // Profile Picture
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundImage: AssetImage(
                                    user.photoUrl?.isNotEmpty == true
                                        ? user.photoUrl!
                                        : 'assets/images/placeholder.jpg',
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 20,
                                        minHeight: 20,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(width: 12),

                            // Message Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (isSentByMe)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 4),
                                          child: Text(
                                            'You: ',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        child: Text(
                                          lastMessage,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: unreadCount > 0
                                                ? Colors.black
                                                : Colors.grey[600],
                                            fontWeight: unreadCount > 0
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Timestamp
                            Text(
                              _formatTimestamp(timestamp),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}