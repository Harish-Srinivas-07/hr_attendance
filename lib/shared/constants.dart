import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/leave.dart';
import '../models/user.dart';
import '../models/attendance.dart';
import '../services/supabase.dart';

late SupaBase sb;
late User userData;
late Office officeData;
List<LeaveRecord> leaveRecord = [];
List<User> manageUsers = [];
User? managerInfo;
List<User> officeContacts = [];
List<LeaveRecord> teamLeaveRecords = [];
List<Attendance> attendances = [];
final TextEditingController searchController = TextEditingController();

final tabIndexProvider = StateProvider<int>((ref) => 0);
int tabIndex = 0;
bool isDarkMode = false;
bool isAdmin = false;
Position? userPosition;
int officeTime = 0;
bool nearOffice = false;
bool isFakeLocation = true;

// recover_acc
String forgetEmailRequest = '';
String emailRequest = '';
String emailRetryTime = '';
int emailAttempt = 0;

class ScreenSize {
  static MediaQueryData? _mediaQueryData;
  static double? screenWidth;
  static double? screenHeight;
  // static final supabase = Supabase.instance.client;
  // static final Session? ses = supabase.auth.currentSession;
  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData!.size.width;
    screenHeight = _mediaQueryData!.size.height;
  }
}

// dashboard
final todayDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
