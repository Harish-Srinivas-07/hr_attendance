import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_attendance/screens/leave_requests.dart';
import 'package:iconly/iconly.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:material_dialogs/dialogs.dart';
import 'package:material_dialogs/shared/types.dart';
import 'package:material_dialogs/widgets/buttons/icon_button.dart';
import 'package:page_transition/page_transition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/snackbar.dart';
import '../models/attendance.dart';
import '../models/user.dart';
import '../shared/constants.dart';
import 'contacts.dart';
import 'discover.dart';
import 'unassigned.dart';

class Profile extends ConsumerStatefulWidget {
  const Profile({super.key});

  @override
  ConsumerState<Profile> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<Profile> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!mounted) return;
    userData = await ref.refresh(userInfoProvider.future);

    officeContacts = await ref.refresh(officeUsersProvider.future);

    manageUsers = await ref.refresh(managedUsersProvider.future);
    await fetchManagerData();

    notManagedUsers = await ref.refresh(officeUsersWithoutAdminProvider.future);

    teamLeaveRecords = await fetchTeamLeaveRecords();
    teamAttendance = await fetchPendingApprovalAttendances();

    isLoading = false;
    setState(() {});
  }

  void showProfilePicOptions(BuildContext context) {
    Dialogs.bottomMaterialDialog(
      msgStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
      color: Colors.black,
      context: context,
      customView: Column(
        children: [
          const SizedBox(height: 50),
          Image.asset('assets/man.png', width: 60),
          const SizedBox(height: 15),
          const Text('Modify Profile Pic',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 50),
            child: Text('Choose an option to update your profile picture.',
                textAlign: TextAlign.center),
          ),
        ],
      ),
      customViewPosition: CustomViewPosition.BEFORE_TITLE,
      actionsBuilder: (context) => [
        Column(
          children: [
            IconsButton(
              onPressed: () async {
                Navigator.pop(context);
                await changeProfilePicture();
              },
              text: 'Change Profile Pic',
              iconData: Icons.photo_library_outlined,
              color: Colors.blue,
              textStyle: const TextStyle(color: Colors.white),
              iconColor: Colors.white,
              shape: SmoothRectangleBorder(
                borderRadius:
                    SmoothBorderRadius(cornerRadius: 12, cornerSmoothing: .6),
              ),
            ),
            IconsButton(
              onPressed: () async {
                Navigator.pop(context);
                await removeProfilePicture();
              },
              text: 'Remove Profile Pic',
              color: Colors.transparent,
              textStyle: TextStyle(color: Colors.blue.shade900),
              shape: SmoothRectangleBorder(
                borderRadius:
                    SmoothBorderRadius(cornerRadius: 12, cornerSmoothing: .6),
              ),
            ),
            const SizedBox(height: 35),
          ],
        ),
      ],
    );
  }

  Future<void> changeProfilePicture() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      final int fileSize = await image.length();
      if (fileSize > 5 * 1024 * 1024) {
        info('Please select an image under 5MB', Severity.warning);
        return;
      }

      final bytes = await image.readAsBytes();
      final fileName = '${userData.id}.jpg';

      await sb.pubbase!.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final publicUrl =
          sb.pubbase!.storage.from('avatars').getPublicUrl(fileName);

      await sb.pubbase!
          .from('users')
          .update({'icon': publicUrl}).eq('id', userData.id);

      userData = await ref.refresh(userInfoProvider.future);
      setState(() {});
      info('Profile picture updated successfully!', Severity.success);
    } catch (e) {
      debugPrint('Profile picture error: $e');
      info('Failed to update profile picture', Severity.error);
    }
  }

  Future<void> removeProfilePicture() async {
    try {
      await sb.pubbase!
          .from('users')
          .update({'icon': null}).eq('id', userData.id);
      userData = await ref.refresh(userInfoProvider.future);
      setState(() {});
      info('Profile picture removed', Severity.success);
    } catch (e) {
      debugPrint('Remove profile pic error: $e');
      info('Failed to remove profile picture', Severity.error);
    }
  }

  Widget _buildTopBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
            image: AssetImage(manageUsers.isNotEmpty
                ? 'assets/profile_background.png'
                : 'assets/normal_profile_background.png'),
            fit: BoxFit.cover,
            opacity: 0.6),
        gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            tileMode: TileMode.clamp,
            colors: [Colors.black, Colors.transparent]),
        borderRadius: SmoothBorderRadius.only(
            bottomLeft: SmoothRadius(cornerRadius: 22, cornerSmoothing: 1),
            bottomRight: SmoothRadius(cornerRadius: 22, cornerSmoothing: 1)),
        backgroundBlendMode: BlendMode.overlay,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              "Profile",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Profile Avatar (Centered from the top)
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                radius: 45,
                backgroundImage: userData.icon != null &&
                        userData.icon!.isNotEmpty
                    ? NetworkImage(
                        '${userData.icon!}?t=${DateTime.now().millisecondsSinceEpoch}')
                    : null,
                child: (userData.icon == null || userData.icon!.isEmpty)
                    ? Text(
                        userData.fullName![0].toUpperCase(),
                        style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      )
                    : null,
              ),
              Positioned(
                bottom: -5,
                right: -5,
                child: GestureDetector(
                  onTap: () => showProfilePicOptions(context),
                  child: CircleAvatar(
                    backgroundColor: Colors.black,
                    radius: 16,
                    child: Icon(Icons.edit, size: 14, color: Colors.blue),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // User Name
          Text(
            userData.fullName ?? "User Name",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),

          // Email
          Text(
            userData.email,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 20),

          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.4),
                  Colors.transparent
                ],
              ),
              borderRadius:
                  SmoothBorderRadius(cornerRadius: 18, cornerSmoothing: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/crown.png',
                    height: 16, color: Colors.amber.shade400),
                const SizedBox(width: 6),
                Text(
                  userData.role,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Logout Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: SmoothRectangleBorder(
                borderRadius:
                    SmoothBorderRadius(cornerRadius: 22, cornerSmoothing: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            ),
            onPressed: () => logoutConfirmation(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(IconlyBroken.logout, size: 20, color: Colors.white),
                const SizedBox(width: 15),
                Text(
                  "Logout",
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: isLoading
          ? Center(
              child: LoadingAnimationWidget.flickr(
                  leftDotColor: Colors.blue,
                  rightDotColor:
                      isDarkMode ? Colors.white : Colors.lightBlueAccent,
                  size: 50),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),

                  if (managerData != null) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 20),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      decoration: ShapeDecoration(
                        color: const Color.fromARGB(255, 15, 15, 15),
                        shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius(
                            cornerRadius: 22,
                            cornerSmoothing: 1,
                          ),
                          side: BorderSide(
                              color: const Color.fromARGB(255, 62, 62, 62)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REPORTING MANAGER',
                            style: GoogleFonts.gabarito(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text('All your requests are managing by:',
                              softWrap: true,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                  color: const Color.fromARGB(
                                      255, 104, 104, 104))),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Avatar or Initial
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.blueGrey.shade700,
                                backgroundImage: managerData!.icon != null &&
                                        managerData!.icon!.isNotEmpty
                                    ? NetworkImage(managerData!.icon!)
                                    : null,
                                child: (managerData!.icon == null ||
                                        managerData!.icon!.isEmpty)
                                    ? Text(
                                        managerData!.fullName
                                                ?.substring(0, 1)
                                                .toUpperCase() ??
                                            '',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              // Manager Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      managerData!.fullName ?? 'Unknown',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    // const SizedBox(height: 4),
                                    Text(
                                      managerData!.email.split('@')[0],
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    if (managerData!.position != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        managerData!.position!,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (managerData!.phone != null)
                                IconButton(
                                  icon: const Icon(IconlyLight.call,
                                      color: Colors.blueAccent, size: 22),
                                  onPressed: () {
                                    launchPhoneDialer(managerData!.phone!);
                                  },
                                ),
                              if (managerData!.phone == null)
                                IconButton(
                                  icon: const Icon(IconlyLight.send,
                                      color: Colors.blueAccent, size: 22),
                                  onPressed: () {
                                    launchEmail(managerData!.email);
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color.fromARGB(255, 38, 38, 38)),
                  ],
                  const SizedBox(height: 20),

                  Padding(
                      padding:
                          const EdgeInsets.only(left: 20, top: 15, bottom: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MANAGE TEAM',
                              style: GoogleFonts.gabarito(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                          Text('Control your team activities.',
                              softWrap: true,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                  color: const Color.fromARGB(
                                      255, 104, 104, 104))),
                        ],
                      )),

                  optionCard(
                    title: 'Attendance Requests',
                    subtitle:
                        'All your weekly attendance approvals are listed over here',
                    onPress: () {
                      Navigator.push(
                          context,
                          PageTransition(
                              type: PageTransitionType.rightToLeftWithFade,
                              child: PendingApprovalPage()));
                    },
                  ),
                  optionCard(
                    title: 'Leave Requests',
                    subtitle:
                        'All your team mates leave approvals are listed over here',
                    onPress: () {
                      Navigator.push(
                          context,
                          PageTransition(
                              type: PageTransitionType.rightToLeftWithFade,
                              child: LeaveRequests()));
                    },
                  ),
                  if (isPrimeUser && notManagedUsers.isNotEmpty)
                    optionCard(
                      title: 'Unassigned Employees',
                      subtitle:
                          'Employee without manager assigned are listed over here.',
                      onPress: () {
                        Navigator.push(
                            context,
                            PageTransition(
                                type: PageTransitionType.rightToLeftWithFade,
                                child: UnAssignedUsers()));
                      },
                    ),
                  // const SizedBox(height: 10),
                  const Divider(color: Color.fromARGB(255, 38, 38, 38)),
                  const SizedBox(height: 60),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Make',
                              style: GoogleFonts.gabarito(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Colors.white54,
                                height: .6,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'it Happen ',
                                  style: GoogleFonts.gabarito(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white54,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Image.asset('assets/heart.png',
                                    height: 40, alignment: Alignment.center),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'CRAFTED WITH CARE',
                              style: GoogleFonts.gabarito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color.fromARGB(255, 47, 47, 47),
                                  height: 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget optionCard({
    required String title,
    required String subtitle,
    required VoidCallback onPress,
  }) {
    return GestureDetector(
      onTap: onPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: GoogleFonts.gabarito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      softWrap: true,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: const Color.fromARGB(255, 104, 104, 104),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Icon(IconlyBroken.arrow_right_2,
                color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }

  void logoutConfirmation(BuildContext context) {
    Dialogs.bottomMaterialDialog(
      msgStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
      color: Colors.black,
      context: context,
      customView: Column(
        children: [
          const SizedBox(height: 50),
          Image.asset(
            'assets/logout.png',
            width: 50,
            color: Colors.red,
          ),
          const SizedBox(height: 20),
          const Text(
            'Logout Confirmation',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 45),
            child: Text(
              'You\'ll need to sign in again to access your account. Do you want to proceed?',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
            ),
          )
        ],
      ),
      customViewPosition: CustomViewPosition.BEFORE_TITLE,
      actionsBuilder: (context) => [
        Column(
          children: [
            IconsButton(
              onPressed: () async {
                Navigator.pop(context);

                try {
                  await showLogoutLoadingDialog(context);
                  await sb.signOut();
                  debugPrint(
                      'Successfully signed out from Supabase and OneSignal.');
                  try {
                    info("Successfully Logout", Severity.success);
                  } catch (e) {
                    debugPrint('info statement debugPrint error3');
                  }
                } catch (e) {
                  await sb.signOut();
                  debugPrint('Error during sign out: $e');
                } finally {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              text: ' Yes, logout',
              iconData: Icons.logout_rounded,
              // color: Colors.blue,
              textStyle: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.w600),
              iconColor: Colors.red,
              shape: SmoothRectangleBorder(
                borderRadius:
                    SmoothBorderRadius(cornerRadius: 12, cornerSmoothing: .6),
              ),
            ),
            IconsButton(
              onPressed: () async {
                Navigator.pop(context);
              },
              text: 'No, cancel',
              // iconData: Icons.close,
              color: const Color.fromARGB(0, 128, 128, 128),
              textStyle: const TextStyle(color: Colors.grey),
              shape: SmoothRectangleBorder(
                borderRadius:
                    SmoothBorderRadius(cornerRadius: 12, cornerSmoothing: .6),
              ),
              // iconColor: Colors.white,
            ),
            const SizedBox(height: 35),
          ],
        )
      ],
    );
  }
}

Future<void> showLogoutLoadingDialog(context) async {
  showDialog(
    barrierColor: const Color.fromARGB(200, 0, 0, 0),
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.black,
          shape: SmoothRectangleBorder(
            borderRadius:
                SmoothBorderRadius(cornerRadius: 30, cornerSmoothing: .9),
          ),
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Image.asset(
                'assets/logout.png',
                width: 35,
                color: Colors.red,
              ),
              const SizedBox(height: 15),
              Text(
                'Logging Out',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[300]!,
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'Logging out, please hold on. This may take a moment..',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              LoadingAnimationWidget.progressiveDots(
                color: Colors.red,
                size: 45,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      );
    },
  );
}

Future<List<Attendance>> fetchPendingApprovalAttendances() async {
  if (manageUsers.isEmpty) return [];

  List<int> userIds = manageUsers.map((user) => user.id).toList();

  final cutoffDate =
      DateTime.now().subtract(const Duration(days: 45)).toIso8601String();

  try {
    final response = await sb.pubbase!
        .from('attendance')
        .select()
        .inFilter('user_id', userIds)
        .gte('date_stamp', cutoffDate)
        .order('date_stamp', ascending: false);

    if (response.isEmpty) return [];

    final all = response.map((data) => Attendance.fromJson(data)).toList();

    // Apply your conditional status logic
    final filtered = all.where((att) {
      if (att.approvalRequired == true && att.approvedBy == null) {
        return true;
      }
      if (att.approvalRequired == true && att.approvedBy != null) {
        return true;
      }
      if (att.approvalRequired == false && att.approvedBy != null) {
        return true;
      }
      return false;
    }).toList();

    return filtered;
  } catch (e) {
    debugPrint("Error fetching attendances: $e");
    return [];
  }
}
