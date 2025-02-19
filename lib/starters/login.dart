import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_attendance/components/snackbar.dart';
import 'package:hr_attendance/starters/recover_acc.dart';

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
  bool _isLoading = false;
  bool _isPasswordValid = false;
  String _emailError = '';

  @override
  void initState() {
    super.initState();
    sb = ref.read(sbiProvider);
    if (mounted) clearForm();
  }

  Future<void> validateLogin() async {
    FocusScope.of(context).unfocus();
    try {
      _isLoading = true;
      setState(() {});
      if (emailController.text.trim().isEmpty || _emailError.isNotEmpty) {
        info('Provide a valid email.', Severity.warning);
      } else if (passController.text.trim().isEmpty || !_isPasswordValid) {
        info('Provide a valid password', Severity.warning);
      } else {
        // Check for email attempt timeout
        DateTime currentTime = DateTime.now();
        DateTime? retryTime = emailRetryTime.isNotEmpty
            ? DateTime.tryParse(emailRetryTime)
            : null;

        debugPrint(
            '-- here the email attempts $emailAttempt && time$retryTime');

        if (emailAttempt > 5) {
          if (retryTime != null && currentTime.isBefore(retryTime)) {
            info(
                'Too many attempts. Retry after: ${retryTime.difference(currentTime).inHours} hours.',
                Severity.error);
            return;
          } else {
            // Reset after 24 hours has passed
            emailAttempt = 0;
            emailRetryTime = '';
          }
        }

        await sb.login(emailController.text.trim(), passController.text.trim());
      }
    } catch (e) {
      debugPrint('-- here the validateError $e');
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
                            setState(() {
                              _isObscured = !_isObscured;
                            });
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

// email
                        _buildInputContainer(
                            label: "Email",
                            hintText: "johndurairaj@gmail.com",
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
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
                        const SizedBox(height: 8),
                        // password
                        _buildInputContainer(
                          label: "Password",
                          hintText: "aStrongPassword123#",
                          controller: passController,
                          isPassword: true,
                          keyboardType: TextInputType.visiblePassword,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(20),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _isPasswordValid = value.length >= 8 &&
                                  value.length <= 20 &&
                                  RegExp(r'[a-z]').hasMatch(value) &&
                                  RegExp(r'[A-Z]').hasMatch(value);
                            });
                          },
                        ),

                        // Forgot Password
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 10),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () async {
                                Navigator.pushNamed(
                                    context, RecoverAcc.routeName);
                              },
                              child: Text(
                                "Forgot ?",
                                style: GoogleFonts.poppins(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : validateLogin,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.blue),
                                      ),
                                      const SizedBox(width: 10),
                                      Text("Validating ...",
                                          style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              color: Colors.blue)),
                                    ],
                                  )
                                : Text(
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
