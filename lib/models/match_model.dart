class MatchModel {
  int? id;
  int user1Id;
  int user2Id;
  String createdAt;

  MatchModel({
    this.id,
    required this.user1Id,
    required this.user2Id,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user1_id': user1Id,
      'user2_id': user2Id,
      'created_at': createdAt,
    };
  }

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    return MatchModel(
      id: map['id'],
      user1Id: map['user1_id'],
      user2Id: map['user2_id'],
      createdAt: map['created_at'],
    );
  }
}
