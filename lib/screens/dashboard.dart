// ignore_for_file: unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:detect_fake_location/detect_fake_location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:material_dialogs/material_dialogs.dart';
import 'package:material_dialogs/shared/types.dart';
import 'package:material_dialogs/widgets/buttons/icon_button.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shimmer/shimmer.dart';
import 'package:slide_action/slide_action.dart';

import '../components/snackbar.dart';
import '../models/user.dart';
import '../services/supabase.dart';
import '../shared/constants.dart';
import 'checkout.dart';

class Dashboard extends ConsumerStatefulWidget {
  const Dashboard({super.key});

  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> {
  bool isLoading = true;
  bool hasCheckedIn = false;
  bool hasCheckedOut = false;
  DateTime? breakStartTime;
  DateTime? lunchStartTime;
  bool isBreakProcessing = false;
  bool isLunchProcessing = false;

  double distanceFromOffice = 0.0;
  bool _refreshEnd = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!mounted) return;
    sb = ref.read(sbiProvider);
    userData = await ref.read(userInfoProvider.future);
    if (userData.officeId != null) {
      officeData = await ref.read(officeInfoProvider.future);
      managerInfo = await fetchManagerInfo();
    }
    officeContacts = await ref.read(officeUsersProvider.future);
    attendances = await ref.read(userAttendanceProvider.future);
    leaveRecord = await ref.read(userLeaveRecordsProvider.future);
    manageUsers = await ref.read(managedUsersProvider.future);

    checkToday();

    _startLocate();
    isLoading = false;
    setState(() {});
  }

  Future<User> fetchManagerInfo() async {
    try {
      if (userData.managerId == null) {
        return userData;
      }

      final List<Map<String, dynamic>> response = await sb.pubbase!
          .from('users')
          .select()
          .eq('id', userData.managerId!)
          .limit(1);

      if (response.isEmpty) {
        return userData;
      }

      return User.fromJson(response.first);
    } catch (e) {
      debugPrint("Error fetching manager info: $e");
      return userData;
    }
  }

  Future<void> _startLocate() async {
    try {
      userPosition = await _determinePosition();

      nearOffice = true;
      if (nearOffice) {
        isFakeLocation = await DetectFakeLocation().detectFakeLocation();
      }

      setState(() {});
      // Compute the distance from office if officeData is available.
      if (officeData.latitude != null && officeData.longitude != null) {
        distanceFromOffice = Geolocator.distanceBetween(
          officeData.latitude!,
          officeData.longitude!,
          userPosition!.latitude,
          userPosition!.longitude,
        );
      }
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  Future<void> _refreshLocation() async {
    nearOffice = false;
    if (mounted) setState(() {});
    await Future.delayed(const Duration(seconds: 2));
    try {
      final position = await _determinePosition();
      setState(() {
        userPosition = position;
        nearOffice = true;
      });
      if (officeData.latitude != null && officeData.longitude != null) {
        distanceFromOffice = Geolocator.distanceBetween(
          officeData.latitude!,
          officeData.longitude!,
          userPosition!.latitude,
          userPosition!.longitude,
        );
      }
      debugPrint(
          "Refreshed location: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      debugPrint("Error refreshing location: $e");
    } finally {
      nearOffice = true;
      if (mounted) setState(() {});
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> checkIn() async {
    try {
      // Ensure userPosition is available
      if (userPosition == null) {
        debugPrint('--- ERROR: User position is not available.');
        await _refreshLocation();
        info('Location is required to make check in', Severity.warning);
        return;
      }

      final response = await sb.pubbase!.rpc(
        'check_in',
        params: {
          '_id': userData.id,
          '_latitude': userPosition!.latitude,
          '_longitude': userPosition!.longitude,
          '_approval_required': distanceFromOffice > 50 ? true : false,
        },
      );

      if (response is bool && response) {
        hasCheckedIn = true;
      } else {
        hasCheckedIn = false;
        debugPrint('-- Check-in failed.');
      }

      setState(() {});
      // Refresh attendance data to reflect check-in
      attendances = await ref.refresh(userAttendanceProvider.future);
    } catch (error) {
      debugPrint('--- ERROR: Failed to call RPC: $error');
    }
  }

  Future<void> updateBreakTime() async {
    final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());

    // Fetch today's record
    final record = await sb.pubbase!
        .from('attendance')
        .select('break_time')
        .eq('user_id', userData.id)
        .eq('date_stamp', todayDate)
        .maybeSingle();
    ref.invalidate(userAttendanceProvider);

    if (record != null && record['break_time'] != null) {
      debugPrint("Break time already recorded for today.");
      ref.invalidate(userAttendanceProvider);
      attendances = await ref.refresh(userAttendanceProvider.future);

      return;
    }

    // Update break time only if it's not set
    final response = await sb.pubbase!.from('attendance').upsert(
      {
        'user_id': userData.id,
        'date_stamp': todayDate,
        'break_time': DateTime.now().toUtc().toIso8601String(),
        'latitude': userPosition!.latitude,
        'longitude': userPosition!.longitude,
      },
      onConflict: 'user_id, date_stamp',
    );

    if (response == null) {
      debugPrint("Break time updated successfully!");
      ref.invalidate(userAttendanceProvider);
      attendances = await ref.refresh(userAttendanceProvider.future);
    }
  }

  Future<void> updateLunchTime() async {
    final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc());

    // Fetch today's record
    final record = await sb.pubbase!
        .from('attendance')
        .select('lunch_time')
        .eq('user_id', userData.id)
        .eq('date_stamp', todayDate)
        .maybeSingle();
    ref.invalidate(userAttendanceProvider);

    if (record != null && record['lunch_time'] != null) {
      debugPrint("Lunch time already recorded for today.");
      ref.invalidate(userAttendanceProvider);
      attendances = await ref.refresh(userAttendanceProvider.future);

      return;
    }
    if (userPosition == null) {
      _refreshLocation();
    }

    // Update lunch time only if it's not set
    final response = await sb.pubbase!.from('attendance').upsert(
      {
        'user_id': userData.id,
        'date_stamp': todayDate,
        'lunch_time': DateTime.now().toUtc().toIso8601String(),
        'latitude': userPosition!.latitude,
        'longitude': userPosition!.longitude,
      },
      onConflict: 'user_id , date_stamp',
    );

    if (response == null) {
      debugPrint("Lunch time updated successfully!");
      ref.invalidate(userAttendanceProvider);
      attendances = await ref.refresh(userAttendanceProvider.future);
    }
  }

  Future<bool> checkToday() async {
    final response = await sb.pubbase!
        .from('attendance')
        .select('id')
        .eq('user_id', userData.id)
        .eq('date_stamp', DateTime.now().toIso8601String().split('T')[0])
        .maybeSingle();
    debugPrint('----- here the hasCheckedIN response $response');
    hasCheckedIn = response != null;
    if (mounted) setState(() {});
    return response != null;
  }

  String getGreeting() {
    int hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "GOOD MORNING";
    } else if (hour >= 12 && hour < 17) {
      return "GOOD AFTERNOON";
    } else if (hour >= 17 && hour < 20) {
      return "GOOD EVENING";
    } else {
      return "GOOD NIGHT";
    }
  }

  // Function to return appropriate image based on time
  String getImagePath() {
    int hour = DateTime.now().hour;
    if (hour >= 5 && hour < 17) {
      return 'assets/morning.png';
    } else if (hour >= 17 && hour < 20) {
      return 'assets/evening.png';
    } else {
      return 'assets/evening.png';
    }
  }

  Widget designCard({
    required String title,
    required String subtitle,
    required String imagePath,
    required int totalDuration,
    DateTime? startTime,
    double? iconsize,
    bool isProcessing = false,
  }) {
    // If startTime is null, show "Start" (or "Processing..." if busy)
    final todayDate = ref.watch(todayDateProvider);
    bool today = DateTime.now().year == todayDate.year &&
        DateTime.now().month == todayDate.month &&
        DateTime.now().day == todayDate.day;
    final selectedDateOnly =
        DateTime(todayDate.year, todayDate.month, todayDate.day);
    final filteredAttendance = attendances.where((att) {
      final checkInDate =
          DateTime(att.checkIn.year, att.checkIn.month, att.checkIn.day);
      return checkInDate.isAtSameMomentAs(selectedDateOnly);
    }).toList();
    final lastCheckOutTime = filteredAttendance.isNotEmpty &&
            filteredAttendance.last.checkOut != null
        ? DateFormat('hh:mm a').format(filteredAttendance.last.checkOut!
            .add(Duration(hours: 5, minutes: 30)))
        : '--';

    bool isTimerActive = startTime != null;
    String? displayText = isProcessing
        ? "Processing..."
        : (isTimerActive
            ? null
            : today && lastCheckOutTime == '--'
                ? "Start"
                : 'NOT taken');
    String activeImagePath =
        isTimerActive ? imagePath.replaceFirst('.png', '_open.png') : imagePath;

    if (isTimerActive) {
      return StreamBuilder<int>(
        stream: Stream.periodic(Duration(seconds: 1),
            (_) => DateTime.now().toUtc().difference(startTime).inMinutes),
        initialData: DateTime.now().toUtc().difference(startTime).inMinutes,
        builder: (context, snapshot) {
          final elapsed = snapshot.data ?? 0;
          int remainingMinutes = totalDuration - elapsed;
          remainingMinutes = remainingMinutes < 0 ? 0 : remainingMinutes;
          final progressValue =
              remainingMinutes > 0 ? remainingMinutes / totalDuration : 0.0;

          // When time is over, show actual punched time (formatted)
          String finalDisplayText = remainingMinutes > 0
              ? "$remainingMinutes min left"
              : DateFormat('hh:mm a').format(startTime.toLocal());

          return _buildCardContent(
            title: title,
            subtitle: subtitle,
            imagePath: activeImagePath,
            remainingMinutes: remainingMinutes,
            progressValue: progressValue,
            iconsize: iconsize,
            overrideText: finalDisplayText,
          );
        },
      );
    } else {
      return _buildCardContent(
        title: title,
        subtitle: subtitle,
        imagePath: activeImagePath,
        remainingMinutes: totalDuration,
        progressValue: 1.0,
        iconsize: iconsize,
        overrideText: displayText,
      );
    }
  }

  String getCheckInStatus(DateTime selectedDateOnly, String checkInTimeStr) {
    DateTime nineAM = DateTime(selectedDateOnly.year, selectedDateOnly.month,
        selectedDateOnly.day, 9, 0, 0);

    DateTime? checkInTime;
    if (checkInTimeStr != '--') {
      checkInTime = DateFormat('hh:mm a').parse(checkInTimeStr);
      checkInTime = DateTime(selectedDateOnly.year, selectedDateOnly.month,
          selectedDateOnly.day, checkInTime.hour, checkInTime.minute);
    }

    // For past dates
    if (selectedDateOnly.isBefore(DateTime.now())) {
      if (checkInTime != null) {
        if (checkInTime
            .isBefore(nineAM.subtract(const Duration(minutes: 30)))) {
          return "Quite early, great job!";
        } else if (checkInTime.isBefore(nineAM)) {
          return "On time, great job!";
        } else if (checkInTime
            .isBefore(nineAM.add(const Duration(minutes: 30)))) {
          return "Slightly late, but still good!";
        } else {
          return "Quite late—let's try to be on time next time!";
        }
      } else {
        return "No check-in recorded.";
      }
    }

    // For the current day
    DateTime now = DateTime.now();
    if (now.isBefore(nineAM.subtract(const Duration(minutes: 30)))) {
      return "Too early, relax a bit!";
    } else if (now.isBefore(nineAM)) {
      return "On time, great job!";
    } else if (now.isBefore(nineAM.add(const Duration(minutes: 30)))) {
      return "Slightly late, but still good!";
    } else {
      return "You're quite late, let's get started!";
    }
  }

  String getCheckOutStatus(String lastCheckInTimeStr, String checkOutTimeStr) {
    if (lastCheckInTimeStr == '--' || checkOutTimeStr == '--') {
      return "No check-in or check-out recorded.";
    }

    // Convert string times to DateTime
    DateTime now = DateTime.now();
    DateTime lastCheckInTime = DateFormat('hh:mm a').parse(lastCheckInTimeStr);
    lastCheckInTime = DateTime(now.year, now.month, now.day,
        lastCheckInTime.hour, lastCheckInTime.minute);

    DateTime checkOutTime = DateFormat('hh:mm a').parse(checkOutTimeStr);
    checkOutTime = DateTime(
        now.year, now.month, now.day, checkOutTime.hour, checkOutTime.minute);

    // Define standard checkout time (9 hours after check-in)
    DateTime expectedCheckOutTime =
        lastCheckInTime.add(const Duration(hours: 9));

    // Compare checkout time with expected time
    if (checkOutTime
        .isBefore(expectedCheckOutTime.subtract(const Duration(minutes: 30)))) {
      return "You left a bit early.";
    } else if (checkOutTime.isBefore(expectedCheckOutTime)) {
      return "Almost checkout time.";
    } else if (checkOutTime
        .isBefore(expectedCheckOutTime.add(const Duration(minutes: 30)))) {
      return "Right on time, well done!";
    } else {
      return "You worked overtime, great job!";
    }
  }

  Widget buildDateHeader({
    required DateTime selectedDateOnly,
  }) {
    final now = DateTime.now();
    final bool isToday = selectedDateOnly.year == now.year &&
        selectedDateOnly.month == now.month &&
        selectedDateOnly.day == now.day;
    final String topLineDate =
        DateFormat('MMMM d, yyyy').format(selectedDateOnly);
    final String bottomLineText =
        isToday ? 'Today' : DateFormat('EEEE').format(selectedDateOnly);

    // Determine dot color based on check-in/check-out status
    Color statusColor = const Color.fromARGB(255, 59, 59, 59);
    if (hasCheckedOut) {
      statusColor = Colors.red;
    } else if (isLunchProcessing) {
      statusColor = Colors.orange;
    } else if (isBreakProcessing) {
      statusColor = Colors.yellow;
    } else if (hasCheckedIn) {
      statusColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.only(left: 25, right: 25, top: 10, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Date & Day
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topLineDate,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                bottomLineText,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          Stack(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blueAccent,
                radius: 26,
                backgroundImage:
                    userData.icon != null && userData.icon!.isNotEmpty
                        ? NetworkImage(userData.icon!)
                        : null,
                child: (userData.icon == null || userData.icon!.isEmpty)
                    ? Text(
                        userData.email[0].toUpperCase(),
                        style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      )
                    : null,
              ),
              // Small status indicator dot
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent({
    required String title,
    required String subtitle,
    required String imagePath,
    required int remainingMinutes,
    required double progressValue,
    double? iconsize,
    String? overrideText,
  }) {
    bool notTaken = false;
    final todayDate = ref.watch(todayDateProvider);

    if (overrideText != null) {
      notTaken = overrideText.toLowerCase().contains('not taken');
    }
    return Container(
        decoration: ShapeDecoration(
          shadows: [
            BoxShadow(
              color: const Color.fromARGB(205, 0, 20, 36),
              blurRadius: 70,
              offset: Offset(0, 0),
            ),
          ],
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
              cornerRadius: 20,
              cornerSmoothing: 0.8,
            ),
            borderAlign: BorderAlign.outside,
            side: BorderSide(
              color: const Color.fromARGB(255, 0, 36, 66),
              width: .5,
            ),
          ),
        ),
        child: Container(
          height: ScreenSize.screenWidth! / 2.4,
          width: ScreenSize.screenWidth! / 2.4,
          decoration: ShapeDecoration(
            color: Colors.black,
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: 20,
                cornerSmoothing: 0.8,
              ),
              borderAlign: BorderAlign.outside,
              // side: BorderSide(
              //   color: const Color.fromARGB(255, 0, 54, 99),
              //   width: 1,
              // ),
            ),
          ),
          child: Stack(
            children: [
              // Text Section (Top-Left)
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      notTaken
                          ? 'No data found on ${DateFormat("dd MMM").format(todayDate)}'
                          : subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Time & Progress Bar
                    if (!notTaken)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Remaining time text
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(16),
                                right: Radius.circular(0),
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.transparent,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Text(
                              overrideText ?? "$remainingMinutes min left",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Progress Bar
                          if (remainingMinutes > 0 &&
                              (title.contains("BREAK")
                                  ? remainingMinutes > 0 &&
                                      remainingMinutes < 10
                                  : remainingMinutes > 0 &&
                                      remainingMinutes < 30))
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 5, right: 80),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progressValue,
                                  minHeight: 3,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    remainingMinutes >
                                            (title.contains('BREAK') ? 3 : 10)
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                    if (notTaken)
                      Text('NOT TAKEN',
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.red))
                  ],
                ),
              ),

              // Image (Bottom-Right)
              Positioned(
                bottom: 0,
                right: 3,
                child: Image.asset(imagePath,
                    height: iconsize ?? 65, fit: BoxFit.contain),
              ),
            ],
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final todayDate = ref.watch(todayDateProvider);
    ref.watch(userAttendanceProvider.future).then((data) {
      attendances = data;
    });

    final selectedDateOnly =
        DateTime(todayDate.year, todayDate.month, todayDate.day);

    String greeting = getGreeting();
    String imagePath = getImagePath();
    bool isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final filteredAttendance = attendances.where((att) {
      final checkInDate =
          DateTime(att.checkIn.year, att.checkIn.month, att.checkIn.day);
      return checkInDate.isAtSameMomentAs(selectedDateOnly);
    }).toList();

// Get last check-in and check-out time for the selected date
    final lastCheckInTime = filteredAttendance.isNotEmpty
        ? DateFormat('hh:mm a').format(filteredAttendance.last.checkIn
            .add(Duration(hours: 5, minutes: 30)))
        : '--';

    final lastCheckOutTime = filteredAttendance.isNotEmpty &&
            filteredAttendance.last.checkOut != null
        ? DateFormat('hh:mm a').format(filteredAttendance.last.checkOut!
            .add(Duration(hours: 5, minutes: 30)))
        : '--';
    String officeCheckInStatment = getCheckInStatus(todayDate, lastCheckInTime);
    String officeCheckOutStatment =
        getCheckOutStatus(lastCheckInTime, lastCheckOutTime);
    // Extract last break and lunch start times
    DateTime? breakStartTime = filteredAttendance.isNotEmpty
        ? filteredAttendance.last.breakTime
        : null;

    DateTime? lunchStartTime = filteredAttendance.isNotEmpty
        ? filteredAttendance.last.lunchTime
        : null;

    bool isToday = DateTime.now().year == todayDate.year &&
        DateTime.now().month == todayDate.month &&
        DateTime.now().day == todayDate.day;

    return SafeArea(
      child: isLoading
          ? Center(
              child: LoadingAnimationWidget.flickr(
                  leftDotColor: Colors.blue,
                  rightDotColor:
                      isDarkMode ? Colors.white : Colors.lightBlueAccent,
                  size: 50))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // const SizedBox(height: 10),
                buildDateHeader(selectedDateOnly: selectedDateOnly),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        children: [
                          // 7 days wudget
                          Past7DaysCalendar(
                            initialSelectedDate: DateTime.now(),
                            onDateChange: (newDate) {
                              // Cancel the previous timer if it exists
                              _refreshTimer?.cancel();
                              _refreshEnd = false;
                              setState(() {});

                              // Update the date state
                              ref.read(todayDateProvider.notifier).state =
                                  newDate;

                              // Start a new timer
                              _refreshTimer =
                                  Timer(const Duration(milliseconds: 700), () {
                                _refreshEnd = true;
                                setState(() {});
                              });
                            },
                          ),
// time general good morninig
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Container(
                              width: double.infinity,
                              height: 90,
                              decoration: ShapeDecoration(
                                shape: SmoothRectangleBorder(
                                  borderRadius: SmoothBorderRadius(
                                    cornerRadius: 20,
                                    cornerSmoothing: 0.8,
                                  ),
                                  // side: BorderSide(
                                  //   color: const Color.fromARGB(255, 0, 39, 70),
                                  //   width: .4,
                                  // ),
                                ),
                                // shadows: [
                                //   BoxShadow(
                                //     color:
                                //         const Color.fromARGB(43, 23, 116, 255),
                                //     blurRadius: 60,
                                //     offset: const Offset(0, 4),
                                //   ),
                                // ],
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 15),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Greeting Text
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        greeting,
                                        style: GoogleFonts.outfit(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        "Time to do what you do best",
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.white54),
                                      ),
                                    ],
                                  ),

                                  // Dynamic Image
                                  Image.asset(
                                    imagePath,
                                    height: 70,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (distanceFromOffice > 50 && isToday)
                            infoCard(
                              text:
                                  "You are far away from office so the approval of ${lastCheckInTime != '--' && lastCheckOutTime == '--' ? "check-out request" : lastCheckInTime == '--' && lastCheckOutTime != '--' ? "check-in request" : "attendance update request"} sent to the corresponding reporting manager.",
                            ),

                          

                          if (lastCheckInTime != '--') ...[
                            if (_refreshEnd)
                              buildCard(
                                  title: 'CheckIn',
                                  subtitle: lastCheckInTime,
                                  iconData: Icons.access_time_filled,
                                  infoText: officeCheckInStatment),
                            if (!_refreshEnd)
                              buildShimmer(
                                  height: 125,
                                  width: ScreenSize.screenWidth! - 40),
                          ],

                          if (lastCheckInTime == '--' && isToday) ...[
                            buildCard(
                                title: "Location",
                                subtitle: nearOffice
                                    ? (distanceFromOffice < 50
                                        ? "You are at the office"
                                        : "You are away from the office")
                                    : "Fetching location...",
                                iconData: Icons.navigation,
                                infoText: isFakeLocation && userPosition != null
                                    ? 'Location mocking detected, kindly remove any unwanted software mocking your current location.'
                                    : distanceFromOffice > 0
                                        ? "You are ${distanceFromOffice >= 1000 ? '${(distanceFromOffice / 1000).toStringAsFixed(1)} km' : '${distanceFromOffice.toStringAsFixed(0)} meters'} away from the office"
                                        : 'We are fetching your current location.'),
                            buildCard(
                                title: 'Office timeIn',
                                subtitle: officeCheckInStatment,
                                iconData: Icons.access_time_filled,
                                infoText: 'You office entry time is 9:00 AM'),
                          ],

                          if (lastCheckInTime != '--')
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Break Time Card
                                  if (_refreshEnd)
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        if (DateTime.now().year ==
                                                todayDate.year &&
                                            DateTime.now().month ==
                                                todayDate.month &&
                                            DateTime.now().day ==
                                                todayDate.day &&
                                            breakStartTime == null &&
                                            !isBreakProcessing &&
                                            lastCheckOutTime == '--') {
                                          if (filteredAttendance.isNotEmpty &&
                                              lastCheckInTime != '--') {
                                            DateTime lastCheckInDateTime =
                                                DateFormat('hh:mm a')
                                                    .parse(lastCheckInTime);

                                            // Adjust to today's date
                                            lastCheckInDateTime = DateTime(
                                                todayDate.year,
                                                todayDate.month,
                                                todayDate.day,
                                                lastCheckInDateTime.hour,
                                                lastCheckInDateTime.minute);

                                            final differenceFromCheckIn =
                                                DateTime.now().difference(
                                                    lastCheckInDateTime);

                                            // ✅ Restrict break if within 1 hour of last check-in
                                            if (differenceFromCheckIn
                                                    .inMinutes <
                                                60) {
                                              info(
                                                  "Too early for a break. Please wait at least 1 hour after check-in.",
                                                  Severity.warning);
                                              return;
                                            }
                                          }
                                          if (lunchStartTime != null) {
                                            final difference = DateTime.now()
                                                .difference(lunchStartTime);
                                            if (difference.inMinutes < 30) {
                                              info("Lunch is under progress.",
                                                  Severity.warning);
                                              return;
                                            }
                                          }

                                          setState(() {
                                            isBreakProcessing = true;
                                          });

                                          updateBreakTime().then((_) {
                                            setState(() {
                                              isBreakProcessing = false;
                                            });
                                          });
                                        }
                                      },
                                      child: designCard(
                                        title: "BREAK TIME",
                                        subtitle: "Enjoy your coffee break ☕",
                                        imagePath: "assets/break.png",
                                        totalDuration: 10,
                                        startTime: breakStartTime,
                                        isProcessing: isBreakProcessing,
                                      ),
                                    ),
                                  if (!_refreshEnd)
                                    buildShimmer(
                                        height: ScreenSize.screenWidth! / 2.4,
                                        width: ScreenSize.screenWidth! / 2.4),
                                  if (!_refreshEnd)
                                    buildShimmer(
                                        height: ScreenSize.screenWidth! / 2.4,
                                        width: ScreenSize.screenWidth! / 2.4),

                                  // Lunch Time Card
                                  if (_refreshEnd)
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        if (DateTime.now().year ==
                                                todayDate.year &&
                                            DateTime.now().month ==
                                                todayDate.month &&
                                            DateTime.now().day ==
                                                todayDate.day &&
                                            lunchStartTime == null &&
                                            !isLunchProcessing &&
                                            lastCheckOutTime == '--') {
                                          // ✅ Convert lastCheckInTime (String) back to DateTime
                                          if (filteredAttendance.isNotEmpty &&
                                              lastCheckInTime != '--') {
                                            DateTime lastCheckInDateTime =
                                                DateFormat('hh:mm a')
                                                    .parse(lastCheckInTime);

                                            // Adjust to today's date
                                            lastCheckInDateTime = DateTime(
                                                todayDate.year,
                                                todayDate.month,
                                                todayDate.day,
                                                lastCheckInDateTime.hour,
                                                lastCheckInDateTime.minute);

                                            final differenceFromCheckIn =
                                                DateTime.now().difference(
                                                    lastCheckInDateTime);

                                            // ✅ Restrict lunch if within 2 hours of last check-in
                                            if (differenceFromCheckIn
                                                    .inMinutes <
                                                120) {
                                              info(
                                                  "Too early for lunch. Please wait at least 2 hours after check-in.",
                                                  Severity.warning);
                                              return;
                                            }
                                          }

                                          if (breakStartTime != null) {
                                            final difference = DateTime.now()
                                                .difference(breakStartTime);
                                            if (difference.inMinutes < 10) {
                                              info("Break time is running.",
                                                  Severity.warning);
                                              return;
                                            }
                                          }

                                          setState(() {
                                            isLunchProcessing = true;
                                          });

                                          updateLunchTime().then((_) {
                                            setState(() {
                                              isLunchProcessing = false;
                                            });
                                          });
                                        }
                                      },
                                      child: designCard(
                                        title: "LUNCH TIME",
                                        subtitle: "Have a delicious meal 🍽️",
                                        imagePath: "assets/lunch.png",
                                        totalDuration: 30,
                                        startTime: lunchStartTime,
                                        isProcessing: isLunchProcessing,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                          if (lastCheckOutTime != '--' && _refreshEnd)
                            buildCard(
                                title: 'CheckOut',
                                subtitle: lastCheckOutTime,
                                iconData: Icons.access_time_filled,
                                infoText: officeCheckOutStatment),

                          if (!isToday &&
                              lastCheckInTime == '--' &&
                              lastCheckOutTime == '--') ...[
                            const SizedBox(height: 30),
                            Image.asset(
                              'assets/doubt.png',
                              height: 120,
                            ),
                            Text(
                              'No record found!',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                          ],

                          if (isToday &&
                              lastCheckInTime != '--' &&
                              lastCheckOutTime == '--' &&
                              _refreshEnd)
                            GestureDetector(
                              onTap: () {
                                DateTime lastCheckInDateTime =
                                    DateFormat('hh:mm a')
                                        .parse(lastCheckInTime);

                                // Adjust to today's date
                                lastCheckInDateTime = DateTime(
                                  DateTime.now().year,
                                  DateTime.now().month,
                                  DateTime.now().day,
                                  lastCheckInDateTime.hour,
                                  lastCheckInDateTime.minute,
                                );

                                // Calculate working hours
                                final workDuration = DateTime.now()
                                    .difference(lastCheckInDateTime);

                                if (workDuration.inHours < 8) {
                                  // ✅ Show confirmation dialog if work hours < 8
                                  Dialogs.bottomMaterialDialog(
                                    msgStyle: const TextStyle(
                                        fontWeight: FontWeight.normal,
                                        fontSize: 12),
                                    color: Colors.black,
                                    context: context,
                                    customView: Column(
                                      children: [
                                        const SizedBox(height: 50),
                                        Image.asset(
                                          'assets/lessthan8hrs.png',
                                          width: 50,
                                          // color: Colors.orange,
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          'Short Working Hours',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        const SizedBox(height: 10),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 45),
                                          child: Text(
                                            'Your working hours are less than 8 hours. Do you still want to proceed with checkout?',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontWeight: FontWeight.normal,
                                                fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                    customViewPosition:
                                        CustomViewPosition.BEFORE_TITLE,
                                    actionsBuilder: (context) => [
                                      Column(
                                        children: [
                                          IconsButton(
                                            onPressed: () {
                                              // ✅ Proceed to checkout
                                              Navigator.pop(context);
                                              Navigator.push(
                                                context,
                                                PageTransition(
                                                  type: PageTransitionType.fade,
                                                  child: const Checkout(),
                                                ),
                                              );
                                            },
                                            text: 'Yes, proceed',
                                            iconData:
                                                Icons.check_circle_outline,
                                            textStyle: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.w600),
                                            iconColor: Colors.green,
                                            shape: SmoothRectangleBorder(
                                              borderRadius: SmoothBorderRadius(
                                                  cornerRadius: 12,
                                                  cornerSmoothing: .6),
                                            ),
                                          ),
                                          IconsButton(
                                            onPressed: () {
                                              // ✅ Cancel, just close dialog
                                              Navigator.pop(context);
                                            },
                                            text: 'No, cancel',
                                            color: const Color.fromARGB(
                                                0, 128, 128, 128),
                                            textStyle: const TextStyle(
                                                color: Colors.grey),
                                            shape: SmoothRectangleBorder(
                                              borderRadius: SmoothBorderRadius(
                                                  cornerRadius: 12,
                                                  cornerSmoothing: .6),
                                            ),
                                          ),
                                          const SizedBox(height: 35),
                                        ],
                                      ),
                                    ],
                                  );
                                } else {
                                  // ✅ Directly go to Checkout (if work hours >= 8)
                                  Navigator.push(
                                    context,
                                    PageTransition(
                                      type: PageTransitionType.fade,
                                      child: const Checkout(),
                                    ),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 25),
                                child: Container(
                                    width: double.infinity,
                                    decoration: ShapeDecoration(
                                      color: const Color.fromARGB(69, 58, 0, 6),
                                      shape: SmoothRectangleBorder(
                                          side: BorderSide(
                                              width: 0.8,
                                              color: const Color.fromARGB(
                                                  255, 61, 17, 14)),
                                          borderRadius: SmoothBorderRadius(
                                              cornerRadius: 13,
                                              cornerSmoothing: 0.8),
                                          borderAlign: BorderAlign.outside),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Text(
                                        'Check out now',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red),
                                      ),
                                    )),
                              ),
                            ),
                        
                          if (isAdmin)
                            buildCard(
                                title: 'Team Requests',
                                subtitle:
                                    'your belonged employees attendance requests at once.',
                                iconData: IconlyLight.chart,
                                infoText: 'manage at once'),
                          const SizedBox(height: 50)
                        ],
                      ),
                    ),
                  ),
                ),
                if (isToday && lastCheckInTime == '--' && nearOffice)
                  Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.only(
                        left: 20, bottom: 15, right: 20, top: 5),
                    child: SlideAction(
                      trackBuilder: (context, state) {
                        return Container(
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: SmoothBorderRadius(
                                cornerRadius: 18, cornerSmoothing: 1),
                            color: const Color.fromARGB(255, 47, 124, 233),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 6),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              state.isPerformingAction
                                  ? "Processing..."
                                  : "Swipe to Check In",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                      thumbBuilder: (context, state) {
                        return Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(60, 255, 255, 255),
                                blurRadius: 3,
                                spreadRadius: 1.5,
                                blurStyle: BlurStyle.solid,
                              ),
                            ],
                            color: Colors.white,
                            borderRadius: SmoothBorderRadius(
                              cornerRadius: 15,
                              cornerSmoothing: 1,
                            ),
                          ),
                          child: Center(
                            child: state.isPerformingAction
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        LoadingAnimationWidget.twoRotatingArc(
                                      color: Colors.blue,
                                      size: 18,
                                    ))
                                : Icon(
                                    Icons.keyboard_double_arrow_right,
                                    color: Colors.blue,
                                  ),
                          ),
                        );
                      },
                      action: () async {
                        await checkIn();

                        await Future.delayed(const Duration(seconds: 5));
                        ref
                            .refresh(userAttendanceProvider.future)
                            .then((attendances) {
                          if (mounted) setState(() {});

                          if (distanceFromOffice > 50) {
                            Navigator.push(
                              context,
                              PageTransition(
                                type: PageTransitionType.rightToLeftWithFade,
                                child:
                                    const CheckInRequestScreen(type: 'checkin'),
                              ),
                            );
                          }
                        });
                      },
                    ),
                  )
              ],
            ),
    );
  }

  Widget buildShimmer({
    required double height,
    required double width,
    double rounded = 16,
  }) {
    return Shimmer.fromColors(
      baseColor: const Color.fromARGB(255, 21, 21, 21),
      highlightColor: const Color.fromARGB(255, 0, 0, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            height: height,
            width: width,
            decoration: ShapeDecoration(
              shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius(
                    cornerRadius: rounded,
                    cornerSmoothing: 1,
                  ),
                  side: BorderSide(
                      color: const Color.fromARGB(255, 62, 62, 62), width: 1)),
              color: const Color.fromARGB(255, 12, 12, 12),
            ),
          ),
          const SizedBox(height: 8)
        ],
      ),
    );
  }

  Widget buildCard({
    required String title,
    required String subtitle,
    String? infoText,
    IconData? iconData,
  }) {
    // Provide a default icon if none is specified
    final icon = iconData ?? Icons.navigation;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: EdgeInsets.all(3),
      decoration: ShapeDecoration(
        color: const Color.fromARGB(255, 28, 28, 28),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 20,
            cornerSmoothing: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top (gray) section
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [
                Color.fromARGB(255, 0, 43, 108),
                Colors.transparent,
                // Colors.transparent,
                Colors.transparent
              ], end: Alignment.bottomLeft, begin: Alignment.topRight),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Circular icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: title.toLowerCase().contains('check')
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            title.toLowerCase().contains('checkout')
                                ? 'assets/checkout.png'
                                : 'assets/checkin.png',
                            color: Colors.white,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Icon(
                          icon,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 12),
                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      if (title.toLowerCase().contains('location') &&
                          distanceFromOffice > 50)
                        GestureDetector(
                          onTap: () => nearOffice ? _refreshLocation() : null,
                          child: Text(
                            'relocate',
                            style: GoogleFonts.poppins(
                              color: Colors.blue,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom (black) section
          // Only show if there's infoText
          if (infoText != null && infoText.isNotEmpty)
            Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info icon
                  const Icon(
                    Icons.info,
                    color: Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  // Info text
                  Expanded(
                    child: Text(
                      infoText,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class Past7DaysCalendar extends StatefulWidget {
  final DateTime initialSelectedDate;
  final ValueChanged<DateTime> onDateChange;

  const Past7DaysCalendar({
    super.key,
    required this.initialSelectedDate,
    required this.onDateChange,
  });

  @override
  Past7DaysCalendarState createState() => Past7DaysCalendarState();
}

class Past7DaysCalendarState extends State<Past7DaysCalendar> {
  late DateTime _selectedDate;
  late List<DateTime> _past7Days;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialSelectedDate;
    _past7Days = _generatePast7Days();

    // Wait until the layout is built, then scroll to the right end.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // You can jump or animate; here we animate for a smoother effect.
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Generate a list of the past 7 days (including today).
  List<DateTime> _generatePast7Days() {
    final today = DateTime.now();
    final days = <DateTime>[];
    for (int i = 0; i < 7; i++) {
      days.add(DateTime(today.year, today.month, today.day - i));
    }
    // Reverse so that the oldest day is on the left and today is on the right.
    return days.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _past7Days.map((day) {
            final bool isSelected = _isSameDate(day, _selectedDate);
            final Color textColor = Colors.white;

            return GestureDetector(
              onTap: () {
                setState(() => _selectedDate = day);
                widget.onDateChange(day);
              },
              child: Container(
                decoration: ShapeDecoration(
                  shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius(
                        cornerRadius: 14, cornerSmoothing: 1),
                    side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : const Color.fromARGB(255, 40, 40, 40),
                        width: 1),
                  ),
                  color: isSelected
                      ? Colors.blue
                      : const Color.fromARGB(255, 12, 12, 12),
                ),
                width: 55,
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('EEE').format(day),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        color: textColor,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      DateFormat('d').format(day),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

Widget infoCard({
  required String text,
  IconData icon = Icons.info,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: ShapeDecoration(
        color: Colors.transparent,
        shape: SmoothRectangleBorder(
            borderRadius:
                SmoothBorderRadius(cornerRadius: 16, cornerSmoothing: 1),
            side: BorderSide(color: const Color.fromARGB(255, 65, 65, 65)))),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: Colors.white30,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color.fromARGB(255, 166, 166, 166),
            ),
          ),
        ),
      ],
    ),
  );
}
