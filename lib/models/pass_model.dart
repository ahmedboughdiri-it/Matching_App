class PassModel {
  int? id;
  int passerId;
  int passedId;
  String timestamp;

  PassModel({
    this.id,
    required this.passerId,
    required this.passedId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'passer_id': passerId,
      'passed_id': passedId,
      'timestamp': timestamp,
    };
  }

  factory PassModel.fromMap(Map<String, dynamic> map) {
    return PassModel(
      id: map['id'],
      passerId: map['passer_id'],
      passedId: map['passed_id'],
      timestamp: map['timestamp'],
    );
  }
}