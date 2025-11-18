import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';
import '../models/like_model.dart';
import '../models/match_model.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'face_verification_screen.dart';

class DiscoverPage extends StatefulWidget {
  final int userId;

  const DiscoverPage({super.key, required this.userId});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final dbHelper = DatabaseHelper.instance;
  List<UserModel> users = [];
  List<UserModel> allUsers = [];

  UserModel? currentUser;
  bool isLoading = true;
  bool isFaceVerified = false; // 🔹 NEW: Track face verification status

  // Filter values
  int minAge = 18;
  int maxAge = 100;
  int maxDistance = 50;

  @override
  void initState() {
    super.initState();
    _checkFaceVerification(); // 🔹 Check verification first
  }

  // 🔹 NEW: Check if user has verified their face
  Future<void> _checkFaceVerification() async {
    final verified = await dbHelper.isFaceVerified(widget.userId);
    setState(() {
      isFaceVerified = verified;
    });

    if (verified) {
      _loadAllUsers();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadAllUsers() async {
    final data = await dbHelper.getAllUsers();
    setState(() {
      allUsers = data.map((e) => UserModel.fromMap(e)).toList();
      isLoading = false;
    });
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final userData = await dbHelper.getUserById(widget.userId);
    if (userData != null) {
      setState(() {
        currentUser = UserModel.fromMap(userData);
        maxDistance = currentUser!.distanceRange ?? 50;
      });
      _loadDiscoverUsers();
    }
  }

  Future<void> _loadDiscoverUsers() async {
    if (currentUser == null) return;

    final excludedIds = await dbHelper.getExcludedUserIds(widget.userId);

    List<UserModel> filteredUsers = [];

    for (var user in allUsers) {
      // Skip current user and excluded users
      if (user.id == widget.userId || excludedIds.contains(user.id)) {
        continue;
      }

      // Filter by opposite gender
      if (currentUser!.preferredGender != 'Both') {
        if (user.gender != currentUser!.preferredGender) {
          continue;
        }
      }

      // Filter by age range
      if (user.age != null) {
        if (user.age! < minAge || user.age! > maxAge) {
          continue;
        }
      }

      // Filter by distance
      if (currentUser!.latitude != null &&
          currentUser!.longitude != null &&
          user.latitude != null &&
          user.longitude != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          currentUser!.latitude!,
          currentUser!.longitude!,
          user.latitude!,
          user.longitude!,
        );
        double distanceInKm = distanceInMeters / 1000;

        if (distanceInKm > maxDistance) {
          continue;
        }
      }

      filteredUsers.add(user);
    }

    setState(() {
      users = filteredUsers;
    });
  }

  Future<void> _handleSwipeRight(UserModel likedUser) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final existingMatchesData = await dbHelper.getMatchesForUser(widget.userId);
    final existingMatches =
    existingMatchesData.map((e) => MatchModel.fromMap(e)).toList();
    bool alreadyMatched = existingMatches.any(
            (m) => m.user1Id == likedUser.id || m.user2Id == likedUser.id);

    if (alreadyMatched) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You are already matched with ${likedUser.name}')),
      );
    } else {
      final mutualLike =
      await dbHelper.checkMutualLike(widget.userId, likedUser.id!);
      if (mutualLike != null) {
        await dbHelper.insertMatch(MatchModel(
          user1Id: widget.userId,
          user2Id: likedUser.id!,
          createdAt: timestamp,
        ).toMap());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🎉 You matched with ${likedUser.name}!')),
        );
      } else {
        await dbHelper.insertLike(LikeModel(
          likerId: widget.userId,
          likedId: likedUser.id!,
          timestamp: timestamp,
        ).toMap());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You liked ${likedUser.name} ❤️')),
        );
      }
    }

    setState(() {
      users.removeWhere((u) => u.id == likedUser.id);
    });
  }

  Future<void> _handleSwipeLeft(UserModel passedUser) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    await dbHelper.insertPass({
      'passer_id': widget.userId,
      'passed_id': passedUser.id!,
      'timestamp': timestamp,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You passed ${passedUser.name} 👋')),
    );

    setState(() {
      users.removeWhere((u) => u.id == passedUser.id);
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filters'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Age Range
              const Text(
                'Age Range',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: minAge.toString()),
                      onChanged: (value) {
                        final age = int.tryParse(value);
                        if (age != null) {
                          setDialogState(() {
                            minAge = age;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Max',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: maxAge.toString()),
                      onChanged: (value) {
                        final age = int.tryParse(value);
                        if (age != null) {
                          setDialogState(() {
                            maxAge = age;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Distance Range
              const Text(
                'Maximum Distance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: maxDistance.toDouble(),
                      min: 1,
                      max: 500,
                      divisions: 50,
                      label: '$maxDistance km',
                      onChanged: (value) {
                        setDialogState(() {
                          maxDistance = value.toInt();
                        });
                      },
                    ),
                  ),
                  Text(
                    '$maxDistance km',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadDiscoverUsers();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B9D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: Text('Are you sure you want to logout, ${currentUser?.name ?? 'User'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B9D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  double _calculateDistance(UserModel user) {
    if (currentUser == null ||
        currentUser!.latitude == null ||
        currentUser!.longitude == null ||
        user.latitude == null ||
        user.longitude == null) {
      return 0;
    }

    double distanceInMeters = Geolocator.distanceBetween(
      currentUser!.latitude!,
      currentUser!.longitude!,
      user.latitude!,
      user.longitude!,
    );
    return distanceInMeters / 1000;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 🔹 NEW: Show verification required screen if not verified
    if (!isFaceVerified) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.face_retouching_natural,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Face Verification Required',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'You need to verify your face before you can discover and match with users.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FaceVerificationScreen(
                            userId: widget.userId,
                          ),
                        ),
                      );
                      // Refresh verification status after returning
                      _checkFaceVerification();
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Verify Face Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B9D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _showLogoutDialog,
                    child: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Original discover page UI (when verified)
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logout button
                  IconButton(
                    icon: const Icon(Icons.logout, size: 24, color: Colors.red),
                    onPressed: _showLogoutDialog,
                    tooltip: 'Logout',
                  ),
                  Column(
                    children: [
                      const Text(
                        'Discover',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            currentUser?.name ?? 'User',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            size: 14,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune, size: 24),
                    onPressed: _showFilterDialog,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Main Card Area
            Expanded(
              child: users.isEmpty
                  ? const Center(
                child: Text(
                  'No users to show 😅',
                  style: TextStyle(fontSize: 18),
                ),
              )
                  : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Container(
                    key: ValueKey(users.first.id),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          // Background Image
                          Positioned.fill(
                            child: Image.asset(
                              users.first.photoUrl?.isNotEmpty == true
                                  ? users.first.photoUrl!
                                  : 'assets/images/placeholder.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.person,
                                    size: 100,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ),

                          // Distance Badge
                          Positioned(
                            top: 20,
                            left: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_calculateDistance(users.first).toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Dots Navigation (right side)
                          Positioned(
                            right: 16,
                            top: 0,
                            bottom: 0,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                3,
                                    (index) => Container(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: index == 0
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.4),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Bottom Gradient + Info
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.7),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${users.first.name ?? 'Unknown'}, ${users.first.age ?? 25}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    users.first.bio ??
                                        'Professional model',
                                    style: TextStyle(
                                      color:
                                      Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pass Button
                  GestureDetector(
                    onTap: users.isNotEmpty
                        ? () => _handleSwipeLeft(users.first)
                        : null,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFFFF6B6B),
                        size: 32,
                      ),
                    ),
                  ),

                  const SizedBox(width: 32),

                  // Like Button
                  GestureDetector(
                    onTap: users.isNotEmpty
                        ? () => _handleSwipeRight(users.first)
                        : null,
                    child: Container(
                      width: 75,
                      height: 75,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6B9D), Color(0xFFFF5E7A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFFF6B9D),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 36,
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
  }
}