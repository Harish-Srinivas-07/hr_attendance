import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/supabase.dart';
import '../shared/constants.dart';
import './register.dart';

class Login extends ConsumerStatefulWidget {
  const Login({super.key});
  static String routeName = "/login";

  @override
  ConsumerState<Login> createState() => _LoginState();
}

class _LoginState extends ConsumerState<Login> {
  bool _isObscured = true;

  @override
  void initState() {
    super.initState();
    sb = ref.read(sbiProvider);
  }

  Widget inputFields({
    required String label,
    required String hintText,
    required bool isPassword,
    Function(String)? onSubmit,
    TextInputAction? textInputAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 23, 23, 23),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.blueAccent.shade200,
              ),
            ),
            TextField(
              cursorColor: Colors.blueAccent,
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.white),
              obscureText: isPassword ? _isObscured : false,
              textInputAction: textInputAction,
              onSubmitted: onSubmit,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
                border: InputBorder.none,
                suffixIcon: isPassword
                    ? IconButton(
                        icon: Image.asset(
                            _isObscured
                                ? 'assets/eye_hide.png'
                                : 'assets/eye_show.png',
                            color: Colors.grey.shade500,
                            width: 28),
                        onPressed: () {
                          _isObscured = !_isObscured;
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
            // const SizedBox(height: 2)
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),

                        Image.asset('assets/logo.png', height: 100),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Welcome Back ",
                              style: GoogleFonts.poppins(
                                  fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            Image.asset('assets/hand.png', height: 30),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              "to ",
                              style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "HR Attendance",
                              style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Hello there, login to continue",
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 25),

                        inputFields(
                            label: "Email",
                            hintText: "Enter your email",
                            textInputAction: TextInputAction.next,
                            isPassword: false),
                        const SizedBox(height: 8),
                        inputFields(
                            label: "Password",
                            hintText: "Enter your password",
                            textInputAction: TextInputAction.done,
                            isPassword: true),
                        // Forgot Password
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 5),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () async {
                                await sb.pubbase!.auth.signInWithOtp(
                                    email: emailController.text.trim());
                              },
                              child: Text(
                                "Forgot ?",
                                style: GoogleFonts.poppins(color: Colors.blue),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: SmoothRectangleBorder(
                                borderRadius: SmoothBorderRadius(
                                    cornerRadius: 16, cornerSmoothing: .7),
                              ),
                            ),
                            child: Text(
                              "Login",
                              style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Register
                if (MediaQuery.of(context).viewInsets.bottom > 0 == false)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't have an account ? ",
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(
                                context, Register.routeName);
                          },
                          child: Text(
                            "Register",
                            style: GoogleFonts.poppins(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
