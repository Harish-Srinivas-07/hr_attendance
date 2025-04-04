import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../components/internet_dialog.dart';
import '../components/snackbar.dart';
import '../screens/home.dart';
import '../services/supabase.dart';
import '../shared/constants.dart';

class Landing extends ConsumerStatefulWidget {
  const Landing({super.key});

  @override
  ConsumerState<Landing> createState() => _LandingState();
}

class _LandingState extends ConsumerState<Landing> {
  bool _isProcessing = false;
  bool _redirectToHome = false;
  bool _autoLoginMessageShown = false;

  @override
  void initState() {
    super.initState();
    sb = ref.read(sbiProvider);
    _initialize();
  }

  Future<void> _initialize() async {
    await _initInternetChecker();
    if (mounted) await _refreshSessionOrSignOut();
    tabIndex = ref.read(tabIndexProvider);

  }

  Future<void> _initInternetChecker() async {
    InternetConnection().onStatusChange.listen((status) {
      if (!mounted) return;
      if (status == InternetStatus.disconnected) {
        InternetDialogHelper.showInternetDialog(context);
      } else {
        if (!_isProcessing) _refreshSessionOrSignOut();
      }
    });
  }

  Future<void> _refreshSessionOrSignOut() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final currentSession = sb.pubbase?.auth.currentSession;
      final credentials = await _getStoredCredentials();
      if (currentSession != null &&
          !_isSessionExpiring(currentSession) &&
          credentials != null) {
        debugPrint('Session is still valid & last sign-in was at: '
            '${currentSession.user.lastSignInAt}');
        setState(() => _redirectToHome = true);
        return;
      }

      if (await InternetConnection().hasInternetAccess) {
        final credentials = await _getStoredCredentials();
        if (credentials != null) {
          debugPrint('Attempting auto-login & credentials found.');
          await attemptAutoLogin(credentials);
          setState(() => _redirectToHome = true);
        } else {
          debugPrint('No credentials found. Signing out.');
          await sb.signOut();
        }
      }
    } catch (e) {
      final credentials = await _getStoredCredentials();
      if (credentials != null) {
        debugPrint('catch block: Attempting auto-login & credentials found.');
        await attemptAutoLogin(credentials);
        setState(() => _redirectToHome = true);
      } else {
        debugPrint('catch block: No credentials found. Signing out.');
        await sb.signOut();
      }
    } finally {
      _isProcessing = false;
    }
  }

  bool _isSessionExpiring(Session session) {
    final expiryTime = DateTime.parse(session.user.lastSignInAt!)
        .add(Duration(seconds: session.expiresIn!));
    return DateTime.now()
        .isAfter(expiryTime.subtract(const Duration(minutes: 5)));
  }

  Future<Map<String, dynamic>?> _getStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    final passkey = prefs.getString('passkey');

    if (email != null && passkey != null) {
      return {'email': email, 'passkey': passkey};
    }
    return null;
  }

  Future<void> attemptAutoLogin(Map<String, dynamic> credentials) async {
    if (_autoLoginMessageShown) return;

    await sb.signIn(
      credentials['email'],
      credentials['passkey'],
      () async {
        try {
          _autoLoginMessageShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            info('Welcome Back ', Severity.success);
          });
        } catch (e) {
          debugPrint('Error during Firebase setup: $e');
        }
      },
      () async {
        info('Login failed.', Severity.error);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    return FutureBuilder<bool>(
      future: InternetConnection().hasInternetAccess,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: LoadingAnimationWidget.flickr(
                  leftDotColor: Colors.blue,
                  rightDotColor:
                      isDarkMode ? Colors.white : Colors.lightBlueAccent,
                  size: 50));
        } else if (snapshot.hasData && snapshot.data == true) {
          return _redirectToHome
              ? const Home()
              : Center(
                  child: LoadingAnimationWidget.flickr(
                      leftDotColor: Colors.blue,
                      rightDotColor:
                          isDarkMode ? Colors.white : Colors.lightBlueAccent,
                      size: 50));
        } else {
          debugPrint('No internet access.');

          return FutureBuilder(
            future: Future.delayed(const Duration(seconds: 3)),
            builder: (context, loadingSnapshot) {
              if (loadingSnapshot.connectionState == ConnectionState.waiting) {
                return Center(
                    child: LoadingAnimationWidget.flickr(
                        leftDotColor: Colors.blue,
                        rightDotColor:
                            isDarkMode ? Colors.white : Colors.lightBlueAccent,
                        size: 50));
              } else {
                return Scaffold(
                  body: Container(
                    color: Colors.black,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Image.asset('assets/no_internet.png',
                              height: 150),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: ScreenSize.screenHeight! / 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No internet connection!',
                                  style: GoogleFonts.poppins(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blueAccent)),
                              const SizedBox(height: 10),
                              Text(
                                  'Something went wrong. Try refreshing the page or checking your internet connection. We\'ll see you in a moment!',
                                  style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w300,
                                      color: Colors.blueGrey)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }
            },
          );
        }
      },
    );
  }
}
