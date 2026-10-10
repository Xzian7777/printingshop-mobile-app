import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import '../utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _loginFormKey = GlobalKey<FormState>();
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;
  bool _loginAgreeTerms = false; // State para sa Login T&C Checkbox

  late AnimationController _animController;
  late Animation<double> _bgFadeAnimation;
  late Animation<Offset> _logoPosAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _buttonsSlideAnimation;
  late Animation<double> _buttonsFadeAnimation;

  bool _showFormCard = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _bgFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.25, 0.65, curve: Curves.easeIn),
      ),
    );

    _logoPosAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.22),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.20, 0.70, curve: Curves.easeInOutCubic),
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.55, 0.85, curve: Curves.easeIn),
      ),
    );

    _buttonsSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.40),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.60, 1.00, curve: Curves.easeOutCubic),
      ),
    );

    _buttonsFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.60, 0.95, curve: Curves.easeIn),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  // --- TERMS & CONDITIONS DIALOG ---
  void _showTermsAndConditionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.gavel_rounded, color: Color(0xFFE11D48)),
            SizedBox(width: 8),
            Text("Terms & Conditions", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text("1. Account Responsibility", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text("Users are responsible for keeping account credentials confidential and providing accurate contact information for order notifications.", style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
              SizedBox(height: 10),
              Text("2. Printing Orders & Proofing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text("Customers must verify file contents, document sizes, and spelling prior to submitting orders. Printing custom jobs cannot be cancelled once processing begins.", style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
              SizedBox(height: 10),
              Text("3. Unclaimed Print Items Disposal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text("Printed materials left unclaimed at the shop after 30 calendar days will be disposed of without refund eligibility.", style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
              SizedBox(height: 10),
              Text("4. Data Privacy & RFID Tapping", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
              SizedBox(height: 2),
              Text("Personal details and RFID card taps are securely recorded strictly for order fulfillment, account authentication, and store loyalty reward tracking.", style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("I Understand & Agree"),
          ),
        ],
      ),
    );
  }

  Future<bool> _sendEmailOTP({
    required String recipientEmail,
    required String otpCode,
    required String subjectText,
  }) async {
    const String senderEmail = 'xdawinan@gmail.com';
    const String appPassword = 'rowb brnm dtzo oufu';

    final smtpServer = gmail(senderEmail, appPassword);

    final message = Message()
      ..from = const Address(senderEmail, 'Kez C-Em Zek Printing')
      ..recipients.add(recipientEmail)
      ..subject = subjectText
      ..html = '''
        <div style="font-family: Arial, sans-serif; padding: 20px; border: 1px solid #e2e8f0; border-radius: 10px;">
          <h2 style="color: #e11d48;">Kez C-Em Zek Printing Shop Service</h2>
          <p>Hello,</p>
          <p>Your verification code is:</p>
          <h1 style="color: #0f172a; letter-spacing: 5px;">$otpCode</h1>
          <p style="color: #64748b; font-size: 12px;">This code will expire in 5 minutes.</p>
        </div>
      ''';

    try {
      await send(message, smtpServer);
      return true;
    } catch (e) {
      debugPrint('SMTP Email Error: $e');
      return false;
    }
  }

  String _generate6DigitOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> _handleLogin() async {
    if (_loginFormKey.currentState!.validate()) {
      if (!_loginAgreeTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please accept the Terms & Conditions to log in.'),
            backgroundColor: Color(0xFFE11D48),
          ),
        );
        return;
      }

      final email = _loginEmailController.text.trim();
      final password = _loginPasswordController.text.trim();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFFE11D48))),
      );

      try {
        // Login using Firebase Authentication
        final credential =
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = credential.user;

        if (user == null) {
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'User account not found.',
          );
        }

        // Get user's role from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final role = userDoc.data()?['role']?.toString().toLowerCase();

        final isAdmin = role == 'admin';

        if (!mounted) return;

        Navigator.pop(context); // Close loading dialog

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              userEmail: user.email ?? email,
              isAdmin: isAdmin,
            ),
          ),
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // pop loading
        String errorMsg = 'Login failed.';
        if (e.code == 'user-not-found') {
          errorMsg = 'Firebase error: user-not-found';
        } else if (e.code == 'invalid-credential') {
          errorMsg = 'Firebase error: invalid-credential';
        } else if (e.code == 'wrong-password') {
          errorMsg = 'Firebase error: wrong-password';
        } else {
          errorMsg = 'Firebase error: ${e.code}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRegisterModal(BuildContext context) {
    final registerFormKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscurePass = true;
    bool obscureConfirmPass = true;
    bool agreeToTerms = false;
    bool isLoading = false;
    String? termsErrorMsg;

    Widget buildRequirementItem(String text, bool isMet) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            Icon(
              isMet ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 16,
              color: isMet ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isMet ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildModalField({
      required String label,
      required String hintText,
      required TextEditingController controller,
      bool isRequired = false,
      bool obscureText = false,
      TextInputType keyboardType = TextInputType.text,
      int? maxLength,
      Widget? suffixIcon,
      String? subtext,
      String? Function(String?)? validator,
      void Function(String)? onChanged,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (isRequired)
                const Text(' *', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            maxLength: maxLength,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFC026D3), width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE11D48))),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
              suffixIcon: suffixIcon,
            ),
            validator: validator,
          ),
          if (subtext != null) ...[
            const SizedBox(height: 4),
            Text(subtext, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ],
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final pass = passwordController.text;
            final name = nameController.text.trim().toLowerCase();
            final emailPrefix = emailController.text.trim().split('@').first.toLowerCase();

            bool req1 = pass.length >= 8;
            bool req2 = RegExp(r'[A-Z]').hasMatch(pass) && RegExp(r'[a-z]').hasMatch(pass);
            bool req3 = RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]').hasMatch(pass);
            bool req4 = pass.isNotEmpty && !pass.contains(' ');
            bool req5 = pass.isNotEmpty &&
                (name.length < 2 || !pass.toLowerCase().contains(name)) &&
                (emailPrefix.length < 2 || !pass.toLowerCase().contains(emailPrefix));

            int metCount = [req1, req2, req3, req4, req5].where((b) => b).length;
            String strengthText = 'Weak';
            Color strengthColor = const Color(0xFFF43F5E);
            double strengthValue = 0.25;

            if (pass.isEmpty) {
              strengthText = 'Weak';
              strengthColor = const Color(0xFFF43F5E);
              strengthValue = 0.25;
            } else if (metCount <= 2) {
              strengthText = 'Weak';
              strengthColor = const Color(0xFFF43F5E);
              strengthValue = 0.33;
            } else if (metCount <= 4) {
              strengthText = 'Medium';
              strengthColor = const Color(0xFFF59E0B);
              strengthValue = 0.66;
            } else {
              strengthText = 'Strong';
              strengthColor = const Color(0xFF10B981);
              strengthValue = 1.0;
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: registerFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Create New Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 1. Full Name
                        buildModalField(
                          label: 'Full Name',
                          hintText: 'e.g. Juan A. Dela Cruz',
                          controller: nameController,
                          onChanged: (_) => setModalState(() {}),
                          validator: (v) => AppValidators.validateName(v),
                        ),
                        const SizedBox(height: 14),

                        // 2. Contact Number
                        buildModalField(
                          label: 'Contact Number (For SMS Alerts)',
                          hintText: '09171234567',
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 11,
                          subtext: 'Format: 11-digit PH mobile number starting with 09',
                          validator: (v) => AppValidators.validateContactNumber(v),
                        ),
                        const SizedBox(height: 14),

                        // 3. Gmail Address
                        buildModalField(
                          label: 'Gmail Address (*.gmail.com)',
                          hintText: 'juan.delacruz@gmail.com',
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) => setModalState(() {}),
                          validator: (v) => AppValidators.validateEmail(v),
                        ),
                        const SizedBox(height: 14),

                        // 4. Password
                        buildModalField(
                          label: 'Password',
                          isRequired: true,
                          hintText: 'Enter strong password',
                          controller: passwordController,
                          obscureText: obscurePass,
                          onChanged: (_) => setModalState(() {}),
                          suffixIcon: IconButton(
                            icon: Icon(obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B), size: 20),
                            onPressed: () => setModalState(() => obscurePass = !obscurePass),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter a password';
                            if (!req1 || !req2 || !req3 || !req4 || !req5) return 'Password does not meet requirements';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        // Password Strength Indicator
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password strength: $strengthText',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: strengthColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: strengthValue,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Password Requirements Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PASSWORD REQUIREMENTS:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 8),
                              buildRequirementItem('Must be at least 8 characters', req1),
                              buildRequirementItem('Must have Uppercase (A-Z) and Lowercase (a-z)', req2),
                              buildRequirementItem('Must have at least one symbol or number', req3),
                              buildRequirementItem("Can't contain spaces", req4),
                              buildRequirementItem("Can't include your name or email address", req5),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 5. Confirm Password
                        buildModalField(
                          label: 'Confirm Password',
                          isRequired: true,
                          hintText: 'Re-enter password',
                          controller: confirmPasswordController,
                          obscureText: obscureConfirmPass,
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirmPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B), size: 20),
                            onPressed: () => setModalState(() => obscureConfirmPass = !obscureConfirmPass),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please confirm your password';
                            if (v != passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Terms & Conditions Checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: agreeToTerms,
                                activeColor: const Color(0xFFC026D3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  setModalState(() {
                                    agreeToTerms = val ?? false;
                                    if (agreeToTerms) termsErrorMsg = null;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showTermsAndConditionsDialog(context),
                                child: const Text.rich(
                                  TextSpan(
                                    text: "Sumasang-ayon ako sa ",
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.3),
                                    children: [
                                      TextSpan(
                                        text: "Terms & Conditions",
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                                      ),
                                      TextSpan(
                                        text: " (Ang hindi mai-claim na prints sa loob ng 30 araw ay ida-dispose na).",
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (termsErrorMsg != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 32, top: 4),
                            child: Text(termsErrorMsg!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 11)),
                          ),
                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () async {
                                          setModalState(() {
                                            termsErrorMsg = agreeToTerms ? null : 'You must agree to the Terms & Conditions.';
                                          });

                                          if (registerFormKey.currentState!.validate() && agreeToTerms) {
                                            setModalState(() => isLoading = true);
                                            final otp = _generate6DigitOTP();
                                            final recipient = emailController.text.trim();

                                            bool sent = await _sendEmailOTP(
                                              recipientEmail: recipient,
                                              otpCode: otp,
                                              subjectText: 'Account Verification - Kez C-Em Zek',
                                            );

                                            if (sent) {
                                              try {
                                                await FirebaseAuth.instance.createUserWithEmailAndPassword(
                                                  email: recipient,
                                                  password: passwordController.text.trim(),
                                                );
                                              } catch (fbErr) {
                                                debugPrint('Firebase Auth Register Error: $fbErr');
                                              }
                                            }

                                            setModalState(() => isLoading = false);

                                            if (mounted) {
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    sent
                                                        ? 'Account registered! Verification code sent to $recipient'
                                                        : 'Failed to send verification email.',
                                                  ),
                                                  backgroundColor: sent ? const Color(0xFF059669) : const Color(0xFFE11D48),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFC026D3),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Send Verification Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  foregroundColor: const Color(0xFF334155),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showForgotPasswordModal(BuildContext context) {
    int currentStep = 1;
    final stepAKey = GlobalKey<FormState>();
    final stepBKey = GlobalKey<FormState>();
    final stepCKey = GlobalKey<FormState>();

    final emailController = TextEditingController();
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();

    Timer? countdownTimer;
    int secondsRemaining = 60;
    bool canResend = false;
    bool isLoading = false;
    String activeOtp = '';
    String recipientEmail = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void startTimer() {
              setModalState(() {
                secondsRemaining = 60;
                canResend = false;
              });
              countdownTimer?.cancel();
              countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                if (secondsRemaining > 0) {
                  setModalState(() => secondsRemaining--);
                } else {
                  setModalState(() => canResend = true);
                  timer.cancel();
                }
              });
            }

            Future<void> sendOtpToEmail() async {
              setModalState(() => isLoading = true);
              activeOtp = _generate6DigitOTP();

              bool success = await _sendEmailOTP(
                recipientEmail: recipientEmail,
                otpCode: activeOtp,
                subjectText: 'Password Reset OTP - Kez C-Em Zek',
              );

              setModalState(() => isLoading = false);

              if (success) {
                startTimer();
                setModalState(() => currentStep = 2);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to send OTP email.')),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currentStep == 1 ? 'Forgot Password' : (currentStep == 2 ? 'Email OTP Verification' : 'Set New Password'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () {
                              countdownTimer?.cancel();
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (currentStep == 1)
                        Form(
                          key: stepAKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Enter your registered Email Address to receive OTP code.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _buildInputDecoration('Registered Email Address', Icons.email_outlined),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Please enter your email address';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () async {
                                    if (stepAKey.currentState!.validate()) {
                                      recipientEmail = emailController.text.trim();
                                      await sendOtpToEmail();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  child: isLoading
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Send Verification Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (currentStep == 2)
                        Form(
                          key: stepBKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('A 6-digit verification code was sent to: $recipientEmail', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: otpController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 8),
                                decoration: _buildInputDecoration('6-Digit Code', Icons.security_rounded).copyWith(counterText: ''),
                                validator: (v) => (v == null || v.trim().length != 6) ? 'Please enter valid 6-digit OTP' : null,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (stepBKey.currentState!.validate()) {
                                      if (otpController.text.trim() == activeOtp) {
                                        countdownTimer?.cancel();
                                        setModalState(() => currentStep = 3);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid OTP code.')));
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  child: const Text('Verify OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: TextButton(
                                  onPressed: canResend && !isLoading ? () async => await sendOtpToEmail() : null,
                                  child: Text(
                                    canResend ? 'Resend Email' : 'Resend Email in ${secondsRemaining}s',
                                    style: TextStyle(color: canResend ? const Color(0xFFE11D48) : const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Form(
                          key: stepCKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Create a new password for your account.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: newPasswordController,
                                obscureText: true,
                                decoration: _buildInputDecoration('New Password', Icons.lock_outline_rounded),
                                validator: (v) => (v == null || v.length < 6) ? 'Must be at least 6 characters' : null,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (stepCKey.currentState!.validate()) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Password reset successfully!'), backgroundColor: Color(0xFF059669)),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  child: const Text('Reset Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _bgFadeAnimation,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1562654501-a0ccc0fc3fb1?auto=format&fit=crop&w=1000&q=80'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(Colors.black87, BlendMode.darken),
                ),
              ),
            ),
          ),

          SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 32,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),

                      SlideTransition(
                        position: _logoPosAnimation,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF97316), Color(0xFFE11D48)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE11D48).withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.print_rounded, color: Colors.white, size: 38),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'KCZ PRINTING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3.0,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      FadeTransition(
                        opacity: _textFadeAnimation,
                        child: const Text(
                          'The premier web & mobile printing shop service.\nOnline order submission, live production tracking & store supplies.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12.5,
                            height: 1.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),

                      const Spacer(flex: 4),

                      SlideTransition(
                        position: _buttonsSlideAnimation,
                        child: FadeTransition(
                          opacity: _buttonsFadeAnimation,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!_showFormCard) ...[
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() => _showFormCard = true);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF0F172A),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'LOGIN',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: OutlinedButton(
                                    onPressed: () => _showRegisterModal(context),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white54, width: 1.5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                                    ),
                                    child: const Text(
                                      'SIGN UP',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // LANDING SCREEN T&C LINK
                                TextButton.icon(
                                  onPressed: () => _showTermsAndConditionsDialog(context),
                                  icon: const Icon(Icons.gavel_rounded, size: 14, color: Colors.white70),
                                  label: const Text(
                                    'Terms & Conditions',
                                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                                    ],
                                  ),
                                  child: Form(
                                    key: _loginFormKey,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                            IconButton(
                                              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                                              onPressed: () => setState(() => _showFormCard = false),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _loginEmailController,
                                          keyboardType: TextInputType.emailAddress,
                                          decoration: _buildInputDecoration('Email Address', Icons.email_outlined),
                                          validator: (v) => AppValidators.validateEmail(v),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _loginPasswordController,
                                          obscureText: _obscureLoginPassword,
                                          decoration: _buildInputDecoration('Password', Icons.lock_outline_rounded).copyWith(
                                            suffixIcon: IconButton(
                                              icon: Icon(_obscureLoginPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B), size: 20),
                                              onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
                                            ),
                                          ),
                                          validator: (v) => AppValidators.validatePassword(v),
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () => _showForgotPasswordModal(context),
                                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
                                            child: const Text('Forgot password?', style: TextStyle(color: Color(0xFFE11D48), fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                        ),

                                        // LOGIN CARD T&C CHECKBOX
                                        Row(
                                          children: [
                                            Checkbox(
                                              value: _loginAgreeTerms,
                                              activeColor: const Color(0xFFE11D48),
                                              onChanged: (val) => setState(() => _loginAgreeTerms = val ?? false),
                                            ),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () => _showTermsAndConditionsDialog(context),
                                                child: const Text.rich(
                                                  TextSpan(
                                                    text: "I agree to the ",
                                                    style: TextStyle(fontSize: 10.5, color: Color(0xFF334155)),
                                                    children: [
                                                      TextSpan(
                                                        text: "Terms & Conditions",
                                                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE11D48), decoration: TextDecoration.underline),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        SizedBox(
                                          width: double.infinity,
                                          height: 46,
                                          child: ElevatedButton(
                                            onPressed: _handleLogin,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0F172A),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            child: const Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE11D48))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
    );
  }
} s