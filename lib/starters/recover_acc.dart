import 'dart:io';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_attendance/components/snackbar.dart';
import 'package:hr_attendance/shared/constants.dart';
import 'package:page_transition/page_transition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/home.dart';
import 'login.dart';

class RecoverAcc extends ConsumerStatefulWidget {
  const RecoverAcc({super.key});
  static String routeName = "/recover";

  @override
  ConsumerState<RecoverAcc> createState() => _RecoverAccState();
}

class _RecoverAccState extends ConsumerState<RecoverAcc> {
  String _emailError = '';
  bool optSend = false;
  bool _isLoading = false;
  bool _canChangePass = false;
  bool _isObscured = true;
  bool _isPasswordValid = false;
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  List<TextEditingController> otpController =
      List.generate(6, (index) => TextEditingController());
  TextEditingController f1passController = TextEditingController();
  TextEditingController f2passController = TextEditingController();

  AppBar _buildAppbar() {
    return AppBar(
      toolbarHeight: 60,
      backgroundColor: const Color.fromARGB(51, 41, 41, 41),
      titleSpacing: 0,
      leadingWidth: 100,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Row(
          children: [
            SizedBox(width: 8),
            Icon(Icons.chevron_left, size: 30, color: Colors.blue),
            Text(
              'Back',
              textScaler: TextScaler.linear(1.0),
              style: TextStyle(fontSize: 14, color: Colors.blue),
            ),
          ],
        ),
      ),
      title: const Text(
        'Recover Account',
        textScaler: TextScaler.linear(1.0),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    for (var controller in otpController) {
      controller.dispose();
    }
    f1passController.dispose();
    f2passController.dispose();
    super.dispose();
  }

  Future<bool> emailExists(String email) async {
    final response = await sb.pubbase!
        .from('users')
        .select('id')
        .eq('email', email.trim())
        .maybeSingle();
    if (response == null) {
      info('Email id doesn\'t associated with any Office', Severity.warning);
    }
    return response != null;
  }

  Future<void> requestOTP() async {
    FocusScope.of(context).unfocus();

    try {
      if (emailController.text.trim().isEmpty || _emailError.isNotEmpty) {
        info('Provide a valid email to proceed', Severity.warning);
      } else if ((emailController.text.trim().isNotEmpty ||
              _emailError.isEmpty) &&
          !optSend) {
        _isLoading = true;
        setState(() {});
        final isValidEmail = await emailExists(emailController.text.trim());
        if (!isValidEmail) return;

        if ((forgetEmailRequest.isEmpty ||
                DateTime.now()
                        .difference(DateTime.parse(forgetEmailRequest))
                        .inMinutes >
                    30) &&
            emailRequest != emailController.text.trim()) {
          await sb.pubbase!.auth
              .signInWithOtp(email: emailController.text.trim());
          forgetEmailRequest = DateTime.now().toString();
          emailRequest = emailController.text.trim();
        } else {
          info(
              'OTP sent to ${emailController.text.trim()}, valid for 1 hour. Check your email before retrying.',
              Severity.success);
        }
        await Future.delayed(Duration(seconds: 1));
        optSend = true;
        setState(() {});
      } else if (optSend && !_canChangePass) {
        _isLoading = true;
        setState(() {});
        if (otpController.map((controller) => controller.text).join().isEmpty) {
          info('Enter otp to verify your request', Severity.warning);
          return;
        }
        final AuthResponse res = await sb.pubbase!.auth.verifyOTP(
            email: emailController.text.trim(),
            token: otpController.map((controller) => controller.text).join(),
            type: OtpType.email);
        final Session? session = res.session;
        final User? user = res.user;

        if (session != null && user != null) {
          _canChangePass = true;
          setState(() {});
          info('Otp Verified Successfully', Severity.success);
        }
      } else if (_canChangePass) {
        if (f1passController.text.trim().isEmpty ||
            f2passController.text.trim().isEmpty ||
            !_isPasswordValid ||
            f1passController.text.trim() != f2passController.text.trim()) {
          info('Ensure correct password entered before submitting.',
              Severity.warning);
        } else if (f1passController.text.trim() ==
            f2passController.text.trim()) {
          _isLoading = true;
          setState(() {});
          final updateUserPass = await sb.pubbase!.auth.updateUser(
              UserAttributes(password: f1passController.text.trim()));
          final User? updatedUser = updateUserPass.user;
          if (updatedUser!.updatedAt != updatedUser.createdAt) {
            info(
                'Password changed successfully, proceed login with your credentials.',
                Severity.success);
            Navigator.pushReplacement(
                context,
                PageTransition(
                    type: PageTransitionType.rightToLeftWithFade,
                    child: const Login()));
          }
        }
      }
    } catch (e) {
      debugPrint('--- here the error $e');
      if (e is AuthException) {
        if (e.message.toLowerCase().contains('token has expired')) {
          info('Oops! Otp Expired or invalid.', Severity.error);
        }
        if (e.message.toLowerCase().contains('should be different')) {
          info('New password must be different from the old one.',
              Severity.warning);
        }
      } else if (e is SocketException) {
        info('Check your internet connection, before retry.', Severity.error);
      }
    } finally {
      _isLoading = false;
      setState(() {});
    }
  }

  Widget _buildInputContainer({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required TextInputType keyboardType,
    bool isPassword = false,
    bool isPhoneNumber = false,
    Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
    int? minLines,
    int? maxLines,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 23, 23, 23),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
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
                controller: controller,
                cursorColor: Colors.blueAccent,
                keyboardType:
                    isPhoneNumber ? TextInputType.phone : keyboardType,
                obscureText: isPassword ? _isObscured : false,
                onChanged: onChanged,
                inputFormatters: inputFormatters ?? [],
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: (controller == emailController)
                      ? (_emailError.isEmpty ? Colors.white : Colors.red)
                      : (isPassword
                          ? (_isPasswordValid ? Colors.green : Colors.red)
                          : Colors.white),
                ),
                textInputAction: textInputAction,
                minLines: minLines ?? 1,
                maxLines: maxLines ?? 1,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
                  border: InputBorder.none,
                  suffixIcon: isPassword
                      ? IconButton(
                          icon: Image.asset(
                              _isObscured
                                  ? 'assets/eye_hide.png'
                                  : 'assets/eye_show.png',
                              color: Colors.grey.shade500,
                              width: 25),
                          onPressed: () {
                            _isObscured = !_isObscured;
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
              // const SizedBox(height: 3)
            ],
          ),
        ),
        const SizedBox(height: 8)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppbar(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 25),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                  _canChangePass
                                      ? "Enter New Password"
                                      : optSend
                                          ? 'Enter Verification Code'
                                          : "Forget Password ",
                                  style: GoogleFonts.poppins(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold),
                                  softWrap: true,
                                  maxLines: 3),
                            ),
                            Image.asset(
                                _canChangePass
                                    ? 'assets/lock.png'
                                    : optSend
                                        ? 'assets/paper_plane.png'
                                        : 'assets/sad_face.png',
                                height: 45),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                            _canChangePass
                                ? 'Enter your new strong password'
                                : optSend
                                    ? 'We have sent the code verification to  ${emailController.text.trim()}'
                                    : "Enter your registered email address, and we'll help you reset your password.",
                            style: GoogleFonts.poppins(
                                fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 20),

                        //  email box
                        if (!optSend && !_canChangePass)
                          _buildInputContainer(
                              label: "Email",
                              hintText: "johndurairaj@gmail.com",
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(40),
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                              onChanged: (value) {
                                if (!RegExp(
                                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{3}$')
                                    .hasMatch(value)) {
                                  _emailError = "Enter a valid email id";
                                  setState(() {});
                                } else {
                                  _emailError = '';
                                  setState(() {});
                                }
                              },
                              errorText: _emailError),

                        const SizedBox(height: 10),
                        if (optSend && !_canChangePass)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                              return Container(
                                width: 45,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 23, 23, 23),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: TextField(
                                    focusNode: _focusNodes[index],
                                    controller: otpController[index],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    cursorColor: Colors.blueAccent,
                                    style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(1),
                                    ],
                                    decoration: InputDecoration(
                                        border: InputBorder.none),
                                    onChanged: (value) {
                                      if (value.isNotEmpty && index < 5) {
                                        FocusScope.of(context).requestFocus(
                                            _focusNodes[index + 1]);
                                      } else if (value.isEmpty && index > 0) {
                                        FocusScope.of(context).requestFocus(
                                            _focusNodes[index - 1]);
                                      }
                                    },
                                  ),
                                ),
                              );
                            }),
                          ),

                        if (_canChangePass) ...[
                          _buildInputContainer(
                            label: "New Password",
                            hintText: "aStrongPassword123#",
                            controller: f1passController,
                            isPassword: true,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(20)
                            ],
                            onChanged: (value) {
                              setState(() {
                                if (f2passController.text.trim().isEmpty) {
                                  _isPasswordValid = value.length >= 8 &&
                                      value.length <= 20 &&
                                      RegExp(r'[a-z]').hasMatch(value);
                                } else {
                                  _isPasswordValid = value.length >= 8 &&
                                      value.length <= 20 &&
                                      RegExp(r'[a-z]').hasMatch(value) &&
                                      f1passController.text.trim() ==
                                          f2passController.text.trim();
                                }
                              });
                            },
                          ),
                          _buildInputContainer(
                            label: "Re-enter Password",
                            hintText: "aStrongPassword123#",
                            controller: f2passController,
                            isPassword: true,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(20)
                            ],
                            onChanged: (value) {
                              setState(() {
                                _isPasswordValid = value.length >= 8 &&
                                    value.length <= 20 &&
                                    RegExp(r'[a-z]').hasMatch(value) &&
                                    f1passController.text.trim() ==
                                        f2passController.text.trim();
                              });
                            },
                          ),
                          SizedBox(height: ScreenSize.screenHeight! / 10),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                    context,
                                    PageTransition(
                                        type: PageTransitionType
                                            .rightToLeftWithFade,
                                        child: const Home()));
                              },
                              child: Text(
                                "Skip for now...",
                                style: GoogleFonts.poppins(
                                    color: Colors.blue.shade200,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
                // Submit Button
                if (MediaQuery.of(context).viewInsets.bottom > 0 == false)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : requestOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius(
                              cornerRadius: 16, cornerSmoothing: .7),
                        ),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.blue),
                                ),
                                const SizedBox(width: 10),
                                Text("Loading ...",
                                    style: GoogleFonts.poppins(
                                        fontSize: 18, color: Colors.blue)),
                              ],
                            )
                          : Text(
                              _canChangePass
                                  ? 'Update Password'
                                  : optSend
                                      ? 'Verify OTP'
                                      : "Request OTP",
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
      ),
    );
  }
}
