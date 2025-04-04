import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';

import 'screens/home.dart';
import 'shared/env.dart';
import 'shared/themes.dart';
import 'starters/login.dart';
import 'shared/constants.dart';
import 'starters/register.dart';
import '../starters/recover_acc.dart';
import '../starters/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Supabase.initialize(url: Env.supaUrl, anonKey: Env.anonKey);

  runApp(ToastificationWrapper(child: ProviderScope(child: const MyApp())));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> initDeepLinks() async {
    _linkSubscription = AppLinks().uriLinkStream.listen((uri) {
      debugPrint('onAppLink: $uri');
    });
  }

  @override
  Widget build(BuildContext context) {
    isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    ScreenSize().init(context);
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'HR Attendance',
      debugShowCheckedModeBanner: false,
      // theme: isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
      theme: AppTheme.darkTheme,
      home: const Splash(),
      routes: {
        Splash.routeName: (context) => const Splash(),
        Home.routeName: (context) => const Home(),
        Login.routeName: (context) => const Login(),
        Register.routeName: (context) => const Register(),
        RecoverAcc.routeName: (context) => const RecoverAcc()
      },
    );
  }
}
