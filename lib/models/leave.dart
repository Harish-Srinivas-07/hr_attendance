class LeaveRecord {
  final int id;
  final int userId;
  final DateTime fromDate;
  final DateTime toDate;
  final DateTime createdAt;
  final bool status;
  final int? decisionBy;
  final DateTime updatedAt;
  final String type;
  final String? contact;
  final String? reason;
  final String? remarks;
  final String title;

  LeaveRecord({
    required this.id,
    required this.userId,
    required this.fromDate,
    required this.toDate,
    required this.createdAt,
    required this.status,
    this.decisionBy,
    required this.updatedAt,
    required this.type,
    this.contact,
    this.reason,
    this.remarks,
    required this.title,
  });

  factory LeaveRecord.fromJson(Map<String, dynamic> json) {
    return LeaveRecord(
      id: json['id'],
      userId: json['user_id'],
      fromDate: DateTime.parse(json['from_date']),
      toDate: DateTime.parse(json['to_date']),
      createdAt: DateTime.parse(json['created_at']),
      status: json['status'],
      decisionBy: json['decision_by'],
      updatedAt: DateTime.parse(json['updated_at']),
      type: json['type'],
      contact: json['contact'],
      reason: json['reason'],
      remarks: json['remarks'],
      title: json['title'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'from_date': fromDate.toIso8601String(),
      'to_date': toDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'status': status,
      'decision_by': decisionBy,
      'updated_at': updatedAt.toIso8601String(),
      'type': type,
      'contact': contact,
      'reason': reason,
      'remarks': remarks,
      'title': title,
    };
  }

  @override
  String toString() {
    return 'LeaveRecord{id: $id, userId: $userId, fromDate: $fromDate, toDate: $toDate, createdAt: $createdAt, status: $status, decisionBy: $decisionBy, updatedAt: $updatedAt, type: $type, contact: $contact, title: $title, reason $reason, remarks $remarks}';
  }
}
