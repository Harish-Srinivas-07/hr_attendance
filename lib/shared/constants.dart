import 'package:flutter/material.dart';

import '../services/supabase.dart';

late SupaBase sb;
TextEditingController emailController = TextEditingController();
TextEditingController passController = TextEditingController();
TextEditingController f1passController = TextEditingController();
TextEditingController f2passController = TextEditingController();
TextEditingController nameController = TextEditingController();
TextEditingController ofcController = TextEditingController();
TextEditingController promoController = TextEditingController();
TextEditingController ofcnameController = TextEditingController();
TextEditingController ofcaddrController = TextEditingController();
TextEditingController ofcphController = TextEditingController();
List<TextEditingController> otpController =
    List.generate(6, (index) => TextEditingController());

void clearForm() {
  nameController.clear();
  emailController.clear();
  passController.clear();
  promoController.clear();
  ofcnameController.clear();
  ofcaddrController.clear();
  ofcphController.clear();
  ofcController.clear();
  for (var controller in otpController) {
    controller.clear();
  }
  f1passController.clear();
  f2passController.clear();
}

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
