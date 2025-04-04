import 'package:hr_attendance/models/leave.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../shared/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import 'attendance.dart';

part 'user.g.dart';

@Riverpod(keepAlive: true)
Future<User> userInfo(ref) async {
  final prefs = await SharedPreferences.getInstance();
  final email = prefs.getString('email');

  if (email != null) {
    try {
      var data =
          await sb.pubbase!.from('users').select().eq('email', email).single();

      return User.fromJson(data);
    } catch (e) {
      throw Exception("Error fetching user information: $e");
    }
  } else {
    sb.signOut();
    throw Exception(
        "No user information found in Device Storage, Try logout and then login again.");
  }
}

@Riverpod(keepAlive: true)
Future<Office> officeInfo(ref) async {
  // Get the current user (assumes userInfoProvider is defined)
  final user = await ref.watch(userInfoProvider.future);

  if (user.officeId == null) {
    throw Exception("User has no office assigned.");
  }

  try {
    final data = await sb.pubbase!
        .from('offices')
        .select()
        .eq('id', user.officeId)
        .single();

    return Office.fromJson(data);
  } catch (e) {
    throw Exception("Error fetching office details: $e");
  }
}

@Riverpod(keepAlive: true)
Future<List<User>> officeUsers(ref) async {
  final user = await ref.watch(userInfoProvider.future);

  if (user.officeId == null) {
    debugPrint('-- error in getting office emplyees empty user.officeID');
    return [];
  }

  try {
    final data = await sb.pubbase!
        .from('users')
        .select()
        .eq('office_id', user.officeId!)
        .order('full_name', ascending: true);

    return data.isNotEmpty
        ? data.map<User>((json) => User.fromJson(json)).toList()
        : [];
  } catch (e) {
    debugPrint('-- error in getting office emplyees $e');
    return [];
  }
}

@Riverpod(keepAlive: true)
Future<List<Attendance>> userAttendance(ref) async {
  final userData = await ref.watch(userInfoProvider.future);

  final DateTime today = DateTime.now();
  final DateTime pastFiveDays = today.subtract(const Duration(days: 5));

  try {
    final response = await sb.pubbase!
        .from('attendance')
        .select()
        .eq('user_id', userData.id)
        .gte('date_stamp', pastFiveDays.toIso8601String().split('T')[0])
        .lte('date_stamp', today.toIso8601String().split('T')[0])
        .order('date_stamp', ascending: false);

    if (response.isNotEmpty) {
      return response
          .map<Attendance>((json) => Attendance.fromJson(json))
          .toList();
    }

    return [];
  } catch (e) {
    debugPrint("Error fetching past attendance: $e");
    return [];
  }
}

@Riverpod(keepAlive: true)
Future<List<LeaveRecord>> userLeaveRecords(ref) async {
  try {
    final userData = await ref.read(userInfoProvider.future);

    final DateTime today = DateTime.now();
    final DateTime pastMonth = today.subtract(const Duration(days: 30));

    final response = await sb.pubbase!
        .from('leave_record')
        .select()
        .eq('user_id', userData.id)
        .or('from_date.gte.${pastMonth.toIso8601String().split('T')[0]},to_date.gte.${pastMonth.toIso8601String().split('T')[0]}')
        .order('from_date', ascending: false);
    debugPrint('---here the response $response');
    return response
        .map<LeaveRecord>((json) => LeaveRecord.fromJson(json))
        .toList();
  } catch (e) {
    debugPrint("Error fetching leave records: $e");
    return [];
  }
}

@Riverpod(keepAlive: true)
Future<List<User>> managedUsers(ref) async {
  try {
    // Retrieve current user's data from the userInfoProvider.
    final userData = await ref.read(userInfoProvider.future);

    // Query the 'users' table where manager_id equals the current user's id.
    if (userData.id == null) {
      throw 'Empty user data, failed to fetch managedUsers';
    }
    final response =
        await sb.pubbase!.from('users').select().eq('manager_id', userData.id);

    // Map the response to a List<User> using the fromJson constructor.
    final managedUsers =
        response.map<User>((json) => User.fromJson(json)).toList();
    isAdmin = managedUsers.isNotEmpty;

    return managedUsers;
  } catch (e) {
    debugPrint("Error fetching managed users: $e");
    return [];
  }
}

// user dataclass
class User {
  final int id;
  final String email;
  final String role;
  final DateTime createdAt;
  final int? officeId;
  final String? fullName;
  final String? position;
  final String? icon;
  final int? phone;
  final int? managerId;
  DateTime? startTime;
  DateTime? endTime;
  DateTime? breakTime;
  DateTime? lunchTime;

  User(
      {required this.id,
      required this.email,
      required this.role,
      required this.createdAt,
      this.officeId,
      this.fullName,
      this.position,
      this.icon,
      this.phone,
      this.managerId,
      this.startTime,
      this.endTime,
      this.breakTime,
      this.lunchTime});

  // JSON Constructor
  User.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        email = json['email'],
        role = json['role'],
        createdAt = DateTime.parse(json['created_at']),
        officeId = json['office_id'],
        fullName = json['full_name'],
        position = json['position'],
        icon = json['icon'],
        phone = json['phone'],
        managerId = json['manager_id'],
        startTime = json['check_in'],
        endTime = json['check_out'],
        breakTime = json['break_time'],
        lunchTime = json['lunch_time'];

  // JSON Serializer
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'office_id': officeId,
      'full_name': fullName,
      'position': position,
      'icon': icon,
      'phone': phone,
      'manager_id': managerId,
      'check_in': startTime,
      'check_out': endTime,
      'break_time': breakTime,
      'lunch_time': lunchTime
    };
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, role: $role, createdAt: $createdAt, officeId: $officeId, fullName: $fullName, position: $position, icon: $icon, phone: $phone, managerId: $managerId)';
  }
}

// office dataclass
class Office {
  final int id;
  final String name;
  final int adminId;
  final DateTime? createdAt;
  final String ofcCode;
  final String address;
  final String phNo;
  final DateTime validity;
  final double? latitude;
  final double? longitude;

  Office({
    required this.id,
    required this.name,
    required this.adminId,
    this.createdAt,
    required this.ofcCode,
    required this.address,
    required this.phNo,
    required this.validity,
    this.latitude,
    this.longitude,
  });

  factory Office.fromJson(Map<String, dynamic> json) {
    return Office(
      id: json['id'] as int,
      name: json['name'] as String,
      adminId: json['admin_id'] as int,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      ofcCode: json['ofc_code'] as String,
      address: json['address'] as String,
      phNo: json['ph_no'] as String,
      validity: DateTime.parse(json['validity'] as String),
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'admin_id': adminId,
      'created_at': createdAt?.toIso8601String(),
      'ofc_code': ofcCode,
      'address': address,
      'ph_no': phNo,
      'validity': validity.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  String toString() {
    return 'Office{id: $id, name: $name, adminId: $adminId, createdAt: $createdAt, ofcCode: $ofcCode, address: $address, phNo: $phNo, validity: $validity, latitude: $latitude, longitude: $longitude}';
  }
}
