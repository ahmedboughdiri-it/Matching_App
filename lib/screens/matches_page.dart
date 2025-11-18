import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/match_model.dart';
import '../models/user_model.dart';
import 'chat_page.dart';

class MatchesPage extends StatefulWidget {
  final int userId;

  const MatchesPage({super.key, required this.userId});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  final dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> matches = [];

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    final matchData = await dbHelper.getMatchesForUser(widget.userId);
    final allUsersData = await dbHelper.getAllUsers();

    // Map users by ID for easy lookup
    final userMap = {for (var u in allUsersData) u['id']: UserModel.fromMap(u)};

    // Format match list with other user info
    final formattedMatches = matchData.map((m) {
      final match = MatchModel.fromMap(m);
      final otherUserId =
      match.user1Id == widget.userId ? match.user2Id : match.user1Id;
      final otherUser = userMap[otherUserId];
      return {
        'id': match.id,
        'otherUser': otherUser,
        'createdAt': match.createdAt,
      };
    }).toList();

    setState(() {
      matches = formattedMatches;
    });
  }

  Future<void> _unmatchUser(int otherUserId) async {
    await dbHelper.unmatchUsers(widget.userId, otherUserId);
    setState(() {
      matches.removeWhere((m) => (m['otherUser'] as UserModel).id == otherUserId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Match removed 💔')),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupMatchesByDate() {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var match in matches) {
      String dateKey = _getDateKey(match['createdAt']);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(match);
    }

    return grouped;
  }

  String _getDateKey(String? createdAt) {
    if (createdAt == null) return 'Earlier';

    try {
      final date = DateTime.parse(createdAt);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final matchDate = DateTime(date.year, date.month, date.day);

      if (matchDate == today) {
        return 'Today';
      } else if (matchDate == yesterday) {
        return 'Yesterday';
      } else {
        return 'Earlier';
      }
    } catch (e) {
      return 'Earlier';
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedMatches = _groupMatchesByDate();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Matches',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Match count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B9D), Color(0xFFFF5E7A)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${matches.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'This is a list of people who have liked you\nand your matches.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Matches Grid
            Expanded(
              child: matches.isEmpty
                  ? const Center(
                child: Text(
                  'No matches yet 💔',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
                  : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: groupedMatches.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Header
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Grid of matches
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: entry.value.length,
                        itemBuilder: (context, index) {
                          final match = entry.value[index];
                          final otherUser = match['otherUser'] as UserModel?;
                          if (otherUser == null) return const SizedBox();

                          final name = otherUser.name ?? 'Unknown';
                          final age = otherUser.age ?? 25;
                          final photo = otherUser.photoUrl ??
                              'assets/images/Aa.jpg';

                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Background Image
                                  Image.asset(
                                    photo,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  ),

                                  // Gradient overlay
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withOpacity(0.6),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                    ),
                                  ),

                                  // Name and age
                                  Positioned(
                                    bottom: 50,
                                    left: 12,
                                    right: 12,
                                    child: Text(
                                      '$name, $age',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                  // Action buttons at bottom
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                      children: [
                                        // Unmatch button
                                        GestureDetector(
                                          onTap: () =>
                                              _unmatchUser(otherUser.id!),
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Color(0xFFFF6B6B),
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                        // Message button (updated)
                                        GestureDetector(
                                          onTap: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChatPage(
                                                  userId: widget.userId,
                                                  otherUser: otherUser,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.favorite,
                                              color: Color(0xFFFF6B9D),
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}