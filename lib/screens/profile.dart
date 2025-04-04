import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconly/iconly.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:material_dialogs/dialogs.dart';
import 'package:material_dialogs/shared/types.dart';
import 'package:material_dialogs/widgets/buttons/icon_button.dart';

import '../components/snackbar.dart';
import '../models/user.dart';
import '../shared/constants.dart';

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
    userData = await ref.read(userInfoProvider.future);
    officeContacts = await ref.read(officeUsersProvider.future);
    isLoading = false;
    setState(() {});
  }
  
  Widget _buildTopBar() {
    return Row(
      children: [
        Text(
          "Profile",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),

      ],
    );
  }

  @override
  Widget build(BuildContext context) {
     isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
       
        body: isLoading
            ? Center(
                child: LoadingAnimationWidget.flickr(
                    leftDotColor: Colors.blue,
                    rightDotColor:
                        isDarkMode ? Colors.white : Colors.lightBlueAccent,
                    size: 50),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                       const SizedBox(height: 16),
                    _buildTopBar(),
                    const SizedBox(height: 30),
      
                    // Profile Avatar (Centered from the top)
                    Center(
                      child: CircleAvatar(
                        backgroundColor: Colors.blueAccent,
                        radius: 45,
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
                    ),
      
                    const SizedBox(height: 15),
      
                    // User Name
                    Text(
                      userData.fullName ?? "User Name",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 4),
      
                    // Email
                    Text(
                      userData.email,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 20),
      
                    // Logout Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius(
                            cornerRadius: 22,
                            cornerSmoothing: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                      ),
                      onPressed: () => logoutConfirmation(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(IconlyBroken.logout,
                              size: 20, color: Colors.white),
                          const SizedBox(width: 15),
                          const Text("Logout", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
      
                    const SizedBox(height: 30),
                  ],
                ),
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
                    info(
                      "Successfully Logout",
                      Severity.success
                    );
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
              textStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
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
