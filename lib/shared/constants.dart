import 'package:flutter/material.dart';

import '../services/supabase.dart';

late SupaBase sb;
TextEditingController emailController = TextEditingController();
TextEditingController passController = TextEditingController();
TextEditingController nameController = TextEditingController();
TextEditingController ofcController = TextEditingController();
TextEditingController promoController = TextEditingController();
TextEditingController ofcnameController = TextEditingController();
TextEditingController ofcaddrController = TextEditingController();
TextEditingController ofcphController = TextEditingController();

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
