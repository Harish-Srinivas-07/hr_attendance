import 'package:flutter/material.dart';
import 'dart:async';

import '../starters/landingscreen.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});
  static String routeName = "/splash";

  @override
  SplashState createState() => SplashState();
}

class SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    _opacityAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const Landing()));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Image.asset('assets/logo.png', width: 150),
        ),
      ),
    );
  }
}
