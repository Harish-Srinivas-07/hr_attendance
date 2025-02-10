import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';

import 'screens/home.dart';
import 'shared/constants.dart';
import 'shared/env.dart';
import 'shared/themes.dart';
import 'starters/login.dart';
import 'starters/register.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Supabase.initialize(url: Env.supaUrl, anonKey: Env.anonKey);

  runApp(ToastificationWrapper(child: ProviderScope(child: const MyApp())));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    ScreenSize().init(context);
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'HR Attendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const Login(),
      routes: {
        Home.routeName: (context) => const Home(),
        Login.routeName: (context) => const Login(),
        Register.routeName: (context) => const Register()
      },
    );
  }
}
