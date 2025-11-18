import 'package:flutter/material.dart';

class UserCard extends StatelessWidget {
  final dynamic user;
  final VoidCallback onLike;
  final VoidCallback onPass;

  const UserCard({
    Key? key,
    required this.user,
    required this.onLike,
    required this.onPass,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              user.photoUrl?.isNotEmpty == true
                  ? user.photoUrl
                  : 'assets/images/placeholder.jpg',
              height: double.infinity,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Gradient overlay + name
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(16)),
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
            child: Text(
              '${user.name}, ${user.ageRangeMin ?? ''}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Action buttons
          Positioned(
            bottom: 16,
            right: 16,
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: onPass,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: onLike,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(14),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
