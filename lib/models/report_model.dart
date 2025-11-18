class ReportModel {
  int? id;
  int reporterId; // User who got harassed (User B)
  int reportedId; // User who sent bad message (User A)
  String type; // 'harassment', 'hate_speech', 'spam', 'inappropriate'
  String? reason; // Optional: specific message that triggered it
  String timestamp;
  bool isBlocked; // Whether users are blocked from messaging

  ReportModel({
    this.id,
    required this.reporterId,
    required this.reportedId,
    required this.type,
    this.reason,
    required this.timestamp,
    this.isBlocked = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'reported_id': reportedId,
      'type': type,
      'reason': reason,
      'timestamp': timestamp,
      'is_blocked': isBlocked ? 1 : 0,
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: map['id'],
      reporterId: map['reporter_id'],
      reportedId: map['reported_id'],
      type: map['type'],
      reason: map['reason'],
      timestamp: map['timestamp'],
      isBlocked: map['is_blocked'] == 1,
    );
  }
}