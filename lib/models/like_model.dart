class LikeModel {
  int? id;
  int likerId;
  int likedId;
  String timestamp;

  LikeModel({
    this.id,
    required this.likerId,
    required this.likedId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'liker_id': likerId,
      'liked_id': likedId,
      'timestamp': timestamp,
    };
  }

  factory LikeModel.fromMap(Map<String, dynamic> map) {
    return LikeModel(
      id: map['id'],
      likerId: map['liker_id'],
      likedId: map['liked_id'],
      timestamp: map['timestamp'],
    );
  }
}
