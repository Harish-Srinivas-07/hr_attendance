import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';
import 'package:detect_fake_location/detect_fake_location.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:page_transition/page_transition.dart';
import 'package:slide_action/slide_action.dart';

import '../models/user.dart';
import '../services/supabase.dart';
import '../shared/constants.dart';
import 'home.dart';

class Checkout extends ConsumerStatefulWidget {
  const Checkout({super.key});
  static String routeName = "/home";

  @override
  CheckoutState createState() => CheckoutState();
}

class CheckoutState extends ConsumerState<Checkout> {
  bool worked8Hrs = false;
  bool hasCheckedOut = false;
  bool securityCheck = false;
  double distanceFromOffice = 0.0;
  String securityCheckReason = "Checking environment...";


  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    userData = await ref.read(userInfoProvider.future);

    if (userData.officeId != null) {
      officeData = await ref.read(officeInfoProvider.future);
    }
    attendances = await ref.read(userAttendanceProvider.future);

    // Calculate worked8Hrs based on today's check-in if available.
    DateTime today = DateTime.now();
    final todayAttendance = attendances.firstWhere((att) =>
        att.checkIn.year == today.year &&
        att.checkIn.month == today.month &&
        att.checkIn.day == today.day);

    Duration workedDuration =
        DateTime.now().difference(todayAttendance.checkIn);
    // Add 5 hours and 30 minutes to the workedDuration
    // workedDuration = workedDuration + Duration(hours: 5, minutes: 30);

    worked8Hrs = workedDuration.inHours >= 8;
    officeTime = workedDuration.inHours;
    worked8Hrs = true;

    // Start process for fetching location and simulating security check.
    _startProcess();
    _securityProcess();
  }

  Future<void> _startProcess() async {
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
            userPosition!.longitude);
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

  Future<void> checkOut() async {
    try {
      final response = await sb.pubbase!.rpc('check_out', params: {
        '_id': userData.id,
        '_latitude': userPosition!.latitude,
        '_longitude': userPosition!.longitude,
      });


      if (response is bool) {
        hasCheckedOut = response;
        // Refresh the userAttendance provider to get updated checkout time
        attendances = await ref.refresh(userAttendanceProvider.future);
        if (hasCheckedOut) {
          Navigator.push(
              context,
              PageTransition(
                  type: PageTransitionType.rightToLeftWithFade,
                  child: const Home()));

          if (distanceFromOffice < 50) {
            Navigator.push(
                context,
                PageTransition(
                    type: PageTransitionType.rightToLeftWithFade,
                    child: const CheckInRequestScreen(type: 'checkout')));
          }
        }
      } else {
        hasCheckedOut = false;
      }

      setState(() {});
    } catch (error) {
      debugPrint('--- ERROR: Failed to call RPC: $error');
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

Future<void> _securityProcess() async {
    await Future.delayed(const Duration(seconds: 1));

    final plugin = JailbreakRootDetection.instance;

    bool isJailBroken = false;
    bool isRealDevice = true;
    bool isDevMode = false;
    bool isOnExternalStorage = false;
    List<String> issues = [];

    try {
      isJailBroken = await plugin.isJailBroken;
      isRealDevice = await plugin.isRealDevice;
      isDevMode = await plugin.isDevMode;
      isOnExternalStorage = await plugin.isOnExternalStorage;
      issues = (await plugin.checkForIssues).map((e) => e.name).toList();
    } catch (e) {
      issues.add("Error during security check.");
      debugPrint("Security check error: $e");
    }

    // Determine if any security issue is present
    final bool hasIssues =
        isJailBroken || !isRealDevice || isDevMode || isOnExternalStorage;

    // Generate reason text
    final List<String> reasons = [];
    if (isJailBroken) reasons.add("Device is rooted/jailbroken");
    if (!isRealDevice) reasons.add("Running on emulator");
    if (isDevMode) reasons.add("Developer mode enabled");
    if (isOnExternalStorage) reasons.add("Installed on external storage");
    if (issues.contains("Error during security check.")) {
      reasons.add("Security check failed");
    }

    // Assign final values
    securityCheck = !hasIssues;
    securityCheckReason = securityCheck
        ? "Security Verified"
        : reasons.isNotEmpty
            ? reasons.join(', ')
            : "Potential risks detected";

    if (mounted) setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Modern gradient background.
      body: Container(
        decoration: BoxDecoration(
       
            color: Colors.black),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar with close button.
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title section.
                        Text(
                          "Check Out!",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Processing your checkout process...",
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 16),
                        ),
                        SizedBox(height: 30),
                        // Process steps.
                        Column(
                          children: [
                            buildStepCard(
                              title: "Location",
                              subtitle: nearOffice
                                  ? (distanceFromOffice < 50
                                      ? "You are at the office"
                                      : "You are away from the office")
                                  : "Fetching location...",
                              isCompleted: nearOffice,
                              iconData: Icons.navigation,
                              infoText: isFakeLocation && userPosition != null
                                  ? 'Location mocking detected, kindly remove any unwanted software mocking your current location.'
                                  : distanceFromOffice > 0
                                      ? "You are ${distanceFromOffice >= 1000 ? '${(distanceFromOffice / 1000).toStringAsFixed(1)} km' : '${distanceFromOffice.toStringAsFixed(0)} meters'} away from the office"
                                      : 'We are fetching your current location.',
                            ),
                            buildStepCard(
                                title: "Security Check",
                                subtitle: securityCheckReason,
                                isCompleted: securityCheck,
                                iconData: Icons.shield,
                                infoText:
                                    "The app undergoes some security checks.")

                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Checkout button enabled only if all conditions are met.
              if (securityCheck && distanceFromOffice > 0)
                Padding(
                  padding: const EdgeInsets.only(
                      left: 30, bottom: 15, right: 30, top: 5),
                  child: SlideAction(
                    trackBuilder: (context, state) {
                      return Container(
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: SmoothBorderRadius(
                              cornerRadius: 18, cornerSmoothing: 1),
                          color: const Color.fromARGB(255, 243, 7, 7),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            state.isPerformingAction
                                ? "Processing..."
                                : "Swipe to Check Out",
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
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.red,
                                  ),
                                )
                              : Icon(
                                  Icons.keyboard_double_arrow_right,
                                  color: Colors.red,
                                ),
                        ),
                      );
                    },
                    action: () async {
                      await checkOut();
                    },
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget buildStepCard({
    required String title,
    required String subtitle,
    required bool isCompleted,
    String? infoText,
    IconData? iconData,
  }) {
    // Provide a default icon if none is specified
    final icon = iconData ?? Icons.navigation;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
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
                    color: isCompleted ? Colors.green : Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.black,
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
                          distanceFromOffice > 50 &&
                          nearOffice)
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

class CheckInRequestScreen extends ConsumerStatefulWidget {
  final String type;
  const CheckInRequestScreen({super.key, required this.type});

  @override
  ConsumerState<CheckInRequestScreen> createState() =>
      _CheckInRequestScreenState();
}

class _CheckInRequestScreenState extends ConsumerState<CheckInRequestScreen> {
  double distanceFromOffice = 0.0;

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
    }
    attendances = await ref.read(userAttendanceProvider.future);

    _startLocate();
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

  Widget buildCard({
    required String title,
    required String subtitle,
    String? infoText,
    IconData? iconData,
  }) {
    // Provide a default icon if none is specified
    final icon = iconData ?? Icons.navigation;

    return Container(
      // margin: const EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(3),
      decoration: ShapeDecoration(
        color: const Color.fromARGB(255, 28, 28, 28),
        shape: SmoothRectangleBorder(
          borderRadius:
              SmoothBorderRadius(cornerRadius: 25, cornerSmoothing: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Map Button
          if (userPosition != null) ...[
            _mapCard(
                latitude: userPosition!.latitude,
                longitude: userPosition!.longitude),
          ],
          const SizedBox(height: 10),

          // Top (gray) section
          Container(
            // decoration: BoxDecoration(
            //   gradient: const LinearGradient(colors: [
            //     Color.fromARGB(255, 0, 43, 108),
            //     Colors.transparent,
            //     // Colors.transparent,
            //     Colors.transparent
            //   ], end: Alignment.bottomLeft, begin: Alignment.topRight),
            //   // borderRadius: const BorderRadius.only(
            //   //   topLeft: Radius.circular(20),
            //   //   topRight: Radius.circular(20),
            //   // ),
            // ),
            padding:
                const EdgeInsets.only(left: 16, right: 16, top: 5, bottom: 16),
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
                          color: Colors.black,
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

  Widget _mapCard({
    required double latitude,
    required double longitude,
  }) {
    return Container(
      padding: EdgeInsets.all(1),
      height: 180,
      child: ClipRRect(
        borderRadius: SmoothBorderRadius.only(
          topLeft: SmoothRadius(cornerRadius: 21, cornerSmoothing: 1),
          topRight: SmoothRadius(cornerRadius: 21, cornerSmoothing: 1),
        ),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(latitude, longitude),
            initialZoom: 12,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png",
              subdomains: const ['a', 'b', 'c'],
              retinaMode: RetinaMode.isHighDensity(context),
              maxNativeZoom: 20,
            ),

            // Marker for user's location
            MarkerLayer(
              markers: [
                Marker(
                  width: 10,
                  height: 10,
                  point: LatLng(latitude, longitude),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.blue, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isCheckIn = widget.type == "checkin";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    SizedBox(
                      height: 55,
                      child: Image.asset(
                        'assets/location.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      isCheckIn ? 'Check-In Request' : 'Check-Out Request',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Description
                    Text(
                      isCheckIn
                          ? 'As you are far away from the office location, your check-in request has been sent for approval. Please wait for confirmation.'
                          : 'You are away from the office location, your check-out request has been registered and sent for approval. Please wait for confirmation.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      softWrap: true,
                    ),

                    const SizedBox(height: 24),

                    // Location info
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
                              : 'We are fetching your current location.',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // "Understood" Button
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20),
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Understood',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
