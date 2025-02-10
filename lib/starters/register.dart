import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hr_attendance/components/snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/supabase.dart';
import '../shared/constants.dart';
import 'login.dart';

class Register extends ConsumerStatefulWidget {
  const Register({super.key});
  static String routeName = "/register";
  @override
  ConsumerState<Register> createState() => _RegisterState();
}

class _RegisterState extends ConsumerState<Register> {
  bool _isObscured = true;
  bool _isLoading = false;
  bool _isPasswordValid = false;
  String _emailError = '';
  String _selectedRole = 'Employee';
  List<String> _roles = [];
  bool showPersonalDetails = true;
  bool showOfficeDetails = false;
  bool showPromoCode = false;
  bool showOfficeCode = false;

  @override
  void initState() {
    super.initState();
    sb = ref.read(sbiProvider);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _init();
  }

  Future<void> _init() async {
    if (!mounted) return;
    // final dynamic roleResponse = await sb.pubbase!
    //     .rpc('get_enum_values', params: {'enum_type': 'user_role'});
    // List<String> roles = List<String>.from(roleResponse);
    _roles = ['Employee', 'Admin'];
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
    if (!mounted) return;
    clearForm();
  }

  void clearForm() {
    nameController.clear();
    emailController.clear();
    passController.clear();
    promoController.clear();
    ofcnameController.clear();
    ofcaddrController.clear();
    ofcphController.clear();
    ofcController.clear();
  }

  Future<void> validateUser() async {
    FocusScope.of(context).unfocus();
    if (showPersonalDetails) {
      // Validate personal details
      if (nameController.text.trim().isNotEmpty &&
          (emailController.text.trim().isNotEmpty && _emailError.isEmpty) &&
          (passController.text.trim().isNotEmpty && _isPasswordValid)) {
        showPersonalDetails = false;
        showOfficeDetails = true;
        if (_selectedRole == 'Admin') {
          showPromoCode = true;
        } else {
          showOfficeCode = true;
        }
        setState(() {});
      } else {
        if (nameController.text.isEmpty) {
          info('Provide a valid name', Severity.warning);
        } else if (emailController.text.isEmpty || _emailError.isNotEmpty) {
          info('Provide a valid email', Severity.warning);
        } else if (passController.text.isEmpty || _isPasswordValid == false) {
          info(
              'Password must be at least 8 characters long & include at least one uppercase letter.',
              Severity.warning);
        }
      }
    } else if (showOfficeDetails && _selectedRole == 'Admin') {
      // Validate office details for Admin
      if (ofcnameController.text.trim().isNotEmpty &&
          ofcaddrController.text.trim().isNotEmpty &&
          ofcphController.text.trim().isNotEmpty) {
        setState(() {
          showOfficeDetails = false;
          showOfficeCode = true;
        });
      } else {
        if (ofcnameController.text.isEmpty) {
          info('Provide a valid office name', Severity.warning);
        } else if (ofcaddrController.text.isEmpty || _emailError.isNotEmpty) {
          info('Oops, fill up the office address', Severity.warning);
        } else if (ofcphController.text.isEmpty) {
          info('Oops, all fields are manditory', Severity.warning);
        }
      }
    } else if (showPromoCode || showOfficeCode) {
      // Validate promo code for Employee
      if (_selectedRole != 'Employee' &&
          promoController.text.trim().isNotEmpty) {
        debugPrint(
            "All fields validated for admin entry. Proceed with submission.");
        registerUser();
        // Final submission logic
      } else if (promoController.text.trim().isEmpty &&
          _selectedRole != 'Employee') {
        info('Enter a valid Promcode to register', Severity.warning);
      } else if (_selectedRole == 'Employee' &&
          ofcController.text.trim().isNotEmpty) {
        debugPrint(
            "All fields validated for employee entry. Proceed with submission.");
        registerUser();
        // Final submission logic
      } else if (ofcController.text.trim().isEmpty) {
        info('Enter a valid officecode to register', Severity.warning);
      }
    }
  }

  Future<void> registerUser() async {
    try {
      _isLoading = true;
      setState(() {});
      if (_selectedRole == 'Admin') {
        final validatePromo =
            await validatePromoCode(promoController.text.trim());

        // Check if the promo code is valid
        if (validatePromo['isvalid'] == 'YES') {
          // info('Promocode is valid.', Severity.success);
          bool isAdminCreated = await createAdminUser(
              emailController.text.trim(),
              passController.text.trim(),
              ofcnameController.text.trim(),
              ofcaddrController.text
                  .trim()
                  .replaceAll(RegExp(r'[\*\+\%\$\&\#\@\!\/\\]'), '-'),
              ofcphController.text.trim());
          if (isAdminCreated) {
            info('Admin user created successfully, verify your email to login.',
                Severity.success);

            Navigator.pushReplacementNamed(
                navigatorKey.currentContext!, Login.routeName);
          } else {
            final emailExistsRes = await sb.pubbase!
                .from('users')
                .select('id')
                .eq('email', emailController.text.trim())
                .count(CountOption.exact);
            if (emailExistsRes.count >= 1) {
              info('User already exists, verify your email and proceed login.',
                  Severity.warning);

              Navigator.pushReplacementNamed(
                  navigatorKey.currentContext!, Login.routeName);
            } else {
              info(
                  'Oops! Something issue with your account, try again sometimes.',
                  Severity.error);
            }
          }
        } else {
          info('Promo code is invalid or expired.', Severity.warning);
        }
      } else if (_selectedRole != 'Admin') {
        final validateOfcCode = await validateOfficeCode(ofcController.text);
        if (validateOfcCode) {
          bool isUserCreated = await createUser(emailController.text.trim(),
              passController.text.trim(), ofcController.text.trim());
          if (isUserCreated) {
            info(
              'Office Account created successfully. Verify your email to activate.',
              Severity.success,
            );

            Navigator.pushReplacementNamed(
                navigatorKey.currentContext!, Login.routeName);
          } else {
            final emailExistsRes = await sb.pubbase!
                .from('users')
                .select('id')
                .eq('email', emailController.text.trim())
                .count(CountOption.exact);
            if (emailExistsRes.count >= 1) {
              info('User already exists, verify your email and proceed login.',
                  Severity.warning);

              Navigator.pushReplacementNamed(
                  navigatorKey.currentContext!, Login.routeName);
            } else {
              info(
                  'Oops! Something issue with your account, try again sometimes.',
                  Severity.error);
            }
          }
        } else {
          info('Office Code is invalid or expired', Severity.warning);
        }
      }
    } catch (e) {
      debugPrint('--> register user catch $e');
      info('Something went wrong, try again sometimes...', Severity.error);
    } finally {
      _isLoading = false;
      setState(() {});
    }
  }

  Future<Map<String, dynamic>> validatePromoCode(String promoCode) async {
    final response = await sb.pubbase!
        .rpc('validate_promo', params: {'param_code': promoCode});
    return response[0] as Map<String, dynamic>;
  }

  Future<bool> validateOfficeCode(String ofcCode) async {
    final response =
        await sb.pubbase!.from('offices').select().eq('ofc_code', ofcCode);

    return response.isNotEmpty;
  }

  Future<bool> createAdminUser(String emailid, String password,
      String officeName, String address, String phoneNumber) async {
    try {
      bool isAdminCreate = false;
      await sb.signUp(emailid, password, 'Admin', () async {
        isAdminCreate = await sb.pubbase!.rpc('create_admin_user', params: {
          'emailid': emailid,
          'password': password,
          'office_name': officeName,
          'address': address,
          'phone_number': phoneNumber
        });
      }, () {
        debugPrint('Sign-up failed.');
      });

      return isAdminCreate;
    } catch (error) {
      debugPrint('Error during admin user creation: $error');
      return false;
    }
  }

  Future<bool> createUser(
      String emailid, String password, String officeCode) async {
    try {
      bool isEmployeeCreated = false;
      await sb.signUp(emailid, password, 'Employee', () async {
        isEmployeeCreated = await sb.pubbase!.rpc('create_user', params: {
          'emailid': emailid,
          'password': password,
          'office_code': officeCode
        });
      }, () {
        debugPrint('Sign-up failed.');
      });

      return isEmployeeCreated;
    } catch (error) {
      debugPrint('Error during employee user creation: $error');
      return false;
    }
  }

  Widget toggleRole() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: Colors.blue.shade700, width: 2),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _roles.map((role) {
              final isSelected = _selectedRole == role;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    _selectedRole = role;
                    clearForm();
                    FocusScope.of(context).unfocus();
                    setState(() {});
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.shade700
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: Colors.blue.withAlpha(2),
                                  blurRadius: 8,
                                  offset: Offset(0, 4)),
                            ]
                          : null,
                    ),
                    child: Text(
                      role,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.blue.shade700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  void _showPromoCodeBottomSheet() {
    showModalBottomSheet(
      barrierColor: Colors.black54,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 15),
              Container(
                height: 4,
                width: 60,
                decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(height: 30),
              Image.asset('assets/email.png', height: 60),
              const SizedBox(height: 16),
              Text(
                'Apply for Promocode',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "Hi, ${nameController.text.trim()}",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "The promo code can currently be obtained only by contacting us. No worries!  just click the button below to reach out.",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _launchEmailApp,
                label: Text('Send a mail',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        );
      },
    );
  }

  void _launchEmailApp() async {
    final String name = nameController.text.trim();
    final String email = emailController.text.trim();
    final String officeName = ofcnameController.text.trim();
    final String officeAddress = ofcaddrController.text.trim();
    final String officePhone = ofcphController.text.trim();

    final String emailSubject = '$officeName Promo Code Request';
    final String emailBody = '''
Dear HiveMind Corporation,

I am $name, and I would like to request a promo code to create the admin account for our office, $officeName.

- **Office Name:** $officeName
- **Address:** $officeAddress
- **Contact Number:** $officePhone
- **Email:** $email

We would appreciate it if you could provide the necessary promo code at your earliest convenience. 
Thank you for your assistance. Please feel free to contact us if you require any additional information.

Best regards,  
$name  
$officeName  
''';

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'alerts.hivemind@gmail.com',
      query:
          'subject=${Uri.encodeComponent(emailSubject)}&body=${Uri.encodeComponent(emailBody)}',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      debugPrint('Could not launch email app.');
    }
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
                        const SizedBox(height: 24),

                        Image.asset(
                            showOfficeCode && _selectedRole == "Employee"
                                ? 'assets/access.png'
                                : _selectedRole == 'Admin' && showOfficeDetails
                                    ? 'assets/secure.png'
                                    : showOfficeCode &&
                                            _selectedRole != 'Employee'
                                        ? 'assets/gift.png'
                                        : 'assets/logo.png',
                            height: 100),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                _selectedRole == 'Admin' && showOfficeDetails
                                    ? 'Register Office Info '
                                    : showOfficeCode &&
                                            _selectedRole == "Employee"
                                        ? 'Almost there !'
                                        : showOfficeCode &&
                                                _selectedRole != 'Employee'
                                            ? 'Provide Promo code'
                                            : "Register Account ",
                                style: GoogleFonts.poppins(
                                    fontSize: 28, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.clip,
                                softWrap: true,
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (showPersonalDetails)
                              Image.asset('assets/hand.png', height: 30),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                                showOfficeCode && _selectedRole == "Employee"
                                    ? 'Each office has a '
                                    : _selectedRole == 'Admin' &&
                                            showOfficeDetails
                                        ? 'in '
                                        : "to ",
                                style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.clip,
                                softWrap: true),
                            Text(
                                showOfficeCode && _selectedRole == "Employee"
                                    ? 'unique code '
                                    : showOfficeCode &&
                                            _selectedRole != 'Employee'
                                        ? 'complete registeration.'
                                        : "HR Attendance",
                                style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.clip,
                                softWrap: true),
                          ],
                        ),

                        const SizedBox(height: 10),
                        Text(
                          _selectedRole == 'Admin' && showOfficeDetails
                              ? 'Provide your office details'
                              : showOfficeCode && _selectedRole == "Employee"
                                  ? 'Provide your office code to proceed with registration.'
                                  : showOfficeCode &&
                                          _selectedRole != 'Employee'
                                      ? 'Account will be created once the promo code is validated.'
                                      : "Fill in the details below to get started.",
                          style: GoogleFonts.poppins(
                              fontSize: 16, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 20),

                        // Role Dropdown
                        if (showPersonalDetails && _roles.isNotEmpty)
                          toggleRole(),

// Name Field
                        if (showPersonalDetails)
                          _buildInputContainer(
                            label: "Name",
                            hintText: "eg: John Durairaj",
                            controller: nameController,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z\s]')),
                              LengthLimitingTextInputFormatter(25)
                            ],
                          ),

// Email Field
                        if (showPersonalDetails)
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

// Password Field
                        if (showPersonalDetails)
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

// Office Name
                        if (_selectedRole == 'Admin' && showOfficeDetails)
                          _buildInputContainer(
                              label: "Office Name",
                              hintText: "XYZ Corporation Pvt Ltd ",
                              controller: ofcnameController,
                              keyboardType: TextInputType.text,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[A-Za-z\s]')),
                                LengthLimitingTextInputFormatter(50),
                              ],
                              textInputAction: TextInputAction.next,
                              maxLines: 2,
                              minLines: 1),

// Office Address
                        if (_selectedRole == 'Admin' && showOfficeDetails)
                          _buildInputContainer(
                              label: "Office Address",
                              hintText: "IT Park, \nECR, \nChennai ",
                              controller: ofcaddrController,
                              keyboardType: TextInputType.text,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[A-Za-z0-9,\-\s:]')),
                                LengthLimitingTextInputFormatter(250),
                              ],
                              textInputAction: TextInputAction.next,
                              maxLines: 5,
                              minLines: 2),

                        // Office Phone Number
                        if (_selectedRole == 'Admin' && showOfficeDetails)
                          _buildInputContainer(
                              label: "Office Phone Number",
                              hintText: "91********",
                              controller: ofcphController,
                              keyboardType: TextInputType.phone,
                              isPhoneNumber: true,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(10),
                              ]),

                        // Promo Code
                        if (showOfficeCode && _selectedRole != "Employee") ...[
                          _buildInputContainer(
                            label: "Promo Code",
                            hintText: "Enter your promo code",
                            controller: promoController,
                            keyboardType: TextInputType.text,
                            onChanged: (value) {
                              promoController.value = TextEditingValue(
                                text: value.toUpperCase(),
                                selection: TextSelection.fromPosition(
                                  TextPosition(offset: value.length),
                                ),
                              );
                            },
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]')),
                              LengthLimitingTextInputFormatter(16),
                            ],
                          ),
                          SizedBox(height: ScreenSize.screenHeight! / 3.9),
                          Column(
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  // color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade400,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Image.asset('assets/question.png',
                                          height: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Don't have a promo code?",
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          GestureDetector(
                                            onTap: _showPromoCodeBottomSheet,
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Text('No worries! Get your',
                                                    style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors
                                                            .grey.shade600)),
                                                Text(' promo code',
                                                    style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors
                                                            .grey.shade500)),
                                                Text(' now.',
                                                    style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors
                                                            .grey.shade600))
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        ],
                        if (showOfficeCode && _selectedRole == "Employee") ...[
                          _buildInputContainer(
                            label: "Office Code",
                            hintText: "Enter your office code",
                            controller: ofcController,
                            keyboardType: TextInputType.text,
                            onChanged: (value) => setState(() {}),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9]')),
                              LengthLimitingTextInputFormatter(16),
                            ],
                          ),
                          SizedBox(height: ScreenSize.screenHeight! / 3.9),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Image.asset('assets/idcard.png', height: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "An office code is mandatory to verify and link your account to the appropriate office. Reach out your administrator to know your office code.",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],

                        // login user -- already
                        if (showPersonalDetails) ...[
                          SizedBox(height: ScreenSize.screenHeight! / 30),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account ? ",
                                style: GoogleFonts.poppins(
                                    color: Colors.grey.shade600),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacementNamed(
                                      context, Login.routeName);
                                },
                                child: Text(
                                  "Login",
                                  style: GoogleFonts.poppins(
                                      color: Colors.blue.shade400,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30)
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Register Button
                if (MediaQuery.of(context).viewInsets.bottom > 0 == false) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : validateUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: SmoothRectangleBorder(
                              borderRadius: SmoothBorderRadius(
                                  cornerRadius: 16, cornerSmoothing: 0.7)),
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
                                _selectedRole == 'Admin' && showOfficeDetails
                                    ? 'Enter Promocode'
                                    : showOfficeCode &&
                                            _selectedRole == "Employee"
                                        ? 'Register'
                                        : showOfficeCode &&
                                                _selectedRole != 'Employee'
                                            ? 'Register'
                                            : _selectedRole == 'Admin'
                                                ? 'Continue'
                                                : "Enter Office code",
                                style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ]
              ],
            ),
          ),
        ),
      ),
    );
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
                            width: 28,
                          ),
                          onPressed: () {
                            setState(() {
                              _isObscured = !_isObscured;
                            });
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 3)
            ],
          ),
        ),
        const SizedBox(height: 8)
      ],
    );
  }
}
