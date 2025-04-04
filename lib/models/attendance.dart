class Attendance {
  final int id;
  final int userId;
  final DateTime checkIn;
  final DateTime? checkOut;
  final DateTime createdAt;
  final DateTime? breakTime;
  final DateTime? lunchTime;
  final double latitude;
  final double longitude;
  final bool approvalRequired;
  final int? approvedBy;

  Attendance({
    required this.id,
    required this.userId,
    required this.checkIn,
    this.checkOut,
    required this.createdAt,
    this.breakTime,
    this.lunchTime,
    required this.latitude,
    required this.longitude,
    this.approvalRequired = false,
    this.approvedBy,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      userId: json['user_id'],
      checkIn: DateTime.parse(json['check_in']),
      checkOut:
          json['check_out'] != null ? DateTime.parse(json['check_out']) : null,
      createdAt: DateTime.parse(json['created_at']),
      breakTime: json['break_time'] != null
          ? DateTime.parse(json['break_time'])
          : null,
      lunchTime: json['lunch_time'] != null
          ? DateTime.parse(json['lunch_time'])
          : null,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      approvalRequired: json['approval_required'] ?? false,
      approvedBy: json['approved_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'check_in': checkIn.toIso8601String(),
      'check_out': checkOut?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'break_time': breakTime?.toIso8601String(),
      'lunch_time': lunchTime?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'approval_required': approvalRequired,
      'approved_by': approvedBy,
    };
  }

  @override
  String toString() {
    return 'Attendance{id: $id, userId: $userId, checkIn: $checkIn, checkOut: $checkOut, break: $breakTime, lunch: $lunchTime, latitude: $latitude, longitude: $longitude, approvalRequired: $approvalRequired, approvedBy: $approvedBy, createdAt: $createdAt}';
  }
}
