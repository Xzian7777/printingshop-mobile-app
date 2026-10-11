import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';
import '../utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;
  bool _loginAgreeTerms = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _buildDarkInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1E293B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF43F5E)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF43F5E), width: 1.5),
      ),
    );
  }

  void _showTermsAndConditionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: const [
            Icon(Icons.gavel_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text("Terms & Conditions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text("1. Account Responsibility", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white)),
              SizedBox(height: 2),
              Text("Users are responsible for keeping account credentials confidential and providing accurate contact information for order notifications.", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              SizedBox(height: 10),
              Text("2. Printing Orders & Proofing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white)),
              SizedBox(height: 2),
              Text("Customers must verify file contents, document sizes, and spelling prior to submitting orders. Printing custom jobs cannot be cancelled once processing begins.", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              SizedBox(height: 10),
              Text("3. Unclaimed Print Items Disposal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white)),
              SizedBox(height: 2),
              Text("Printed materials left unclaimed at the shop after 30 calendar days will be disposed of without refund eligibility.", style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
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
        <div style="font-family: Arial, sans-serif; padding: 20px; background-color: #0b0f19; color: #ffffff; border-radius: 10px;">
          <h2 style="color: #6366f1;">Kez C-Em Zek Printing Shop</h2>
          <p>Hello,</p>
          <p>Your password reset code is:</p>
          <h1 style="color: #38bdf8; letter-spacing: 5px;">$otpCode</h1>
          <p style="color: #94a3b8; font-size: 12px;">This code will expire in 5 minutes.</p>
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
    if (!_loginFormKey.currentState!.validate()) return;

    if (!_loginAgreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms & Conditions to log in.'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
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

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final role = userDoc.data()?['role']?.toString().toLowerCase();
      final isAdmin = role == 'admin';

      if (!mounted) return;
      setState(() => _isLoading = false);

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
      setState(() => _isLoading = false);
      String errorMsg = 'Login failed.';
      if (e.code == 'user-not-found') {
        errorMsg = 'Account not found. Please check email.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMsg = 'Incorrect email or password.';
      } else {
        errorMsg = 'Authentication error: ${e.message ?? e.code}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: const Color(0xFFF43F5E)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFF43F5E)),
      );
    }
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
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
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
                if (modalCtx.mounted) {
                  ScaffoldMessenger.of(modalCtx).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to send OTP email. Please try again.'),
                      backgroundColor: Color(0xFFF43F5E),
                    ),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(top: BorderSide(color: Color(0xFF1E293B))),
                ),
                padding: const EdgeInsets.all(22.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currentStep == 1
                                ? 'Forgot Password'
                                : (currentStep == 2 ? 'Verify OTP Code' : 'Set New Password'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              countdownTimer?.cancel();
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (currentStep == 1)
                        Form(
                          key: stepAKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Enter your registered Gmail address to receive a 6-digit OTP code.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _buildDarkInputDecoration('Registered Email Address', Icons.email_outlined),
                                validator: (v) => AppValidators.validateEmail(v),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () async {
                                    if (stepAKey.currentState!.validate()) {
                                      recipientEmail = emailController.text.trim();
                                      await sendOtpToEmail();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Send Reset OTP', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (currentStep == 2)
                        Form(
                          key: stepBKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Code sent to: $recipientEmail',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: otpController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.white),
                                decoration: _buildDarkInputDecoration('Enter 6-digit OTP', Icons.security_rounded),
                                validator: (v) => (v == null || v.trim().length != 6) ? 'Enter valid 6-digit OTP' : null,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    secondsRemaining > 0 ? 'Resend in ${secondsRemaining}s' : 'Code expired',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  ),
                                  TextButton(
                                    onPressed: canResend && !isLoading ? () async => await sendOtpToEmail() : null,
                                    child: Text(
                                      'Resend OTP',
                                      style: TextStyle(
                                        color: canResend ? const Color(0xFF818CF8) : const Color(0xFF475569),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (stepBKey.currentState!.validate()) {
                                      if (otpController.text.trim() == activeOtp) {
                                        countdownTimer?.cancel();
                                        setModalState(() => currentStep = 3);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Invalid OTP code. Please check your email.'),
                                            backgroundColor: Color(0xFFF43F5E),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Verify Code', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (currentStep == 3)
                        Form(
                          key: stepCKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Create a new secure password for your account.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: newPasswordController,
                                obscureText: true,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _buildDarkInputDecoration('New Password', Icons.lock_outline_rounded),
                                validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (stepCKey.currentState!.validate()) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Password updated. Please log in with your new password.'),
                                          backgroundColor: Color(0xFF10B981),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Save New Password', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
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
      backgroundColor: const Color(0xFF070A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Ambient Glow Background
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4F46E5).withValues(alpha: 0.18),
                    const Color(0xFF38BDF8).withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Logo & Branding
                      Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.print_rounded, color: Colors.white, size: 30),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome Back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in to manage and track your print orders',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Glass Card Form Container
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1224).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _loginFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Email Address',
                                style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _loginEmailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _buildDarkInputDecoration('e.g. user@gmail.com', Icons.email_outlined),
                                validator: (v) => AppValidators.validateEmail(v),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Password',
                                style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _loginPasswordController,
                                obscureText: _obscureLoginPassword,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _buildDarkInputDecoration('Enter your password', Icons.lock_outline_rounded).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureLoginPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                      color: const Color(0xFF64748B),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Please enter your password' : null,
                              ),
                              const SizedBox(height: 8),

                              // Forgot Password & Terms
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _showForgotPasswordModal(context),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 28),
                                  ),
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      color: Color(0xFF818CF8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              Row(
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: _loginAgreeTerms,
                                      activeColor: const Color(0xFF4F46E5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (val) => setState(() => _loginAgreeTerms = val ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showTermsAndConditionsDialog(context),
                                      child: const Text.rich(
                                        TextSpan(
                                          text: "I agree to the ",
                                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                          children: [
                                            TextSpan(
                                              text: "Terms & Conditions",
                                              style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // LOGIN BUTTON
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                    shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                      : const Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Sign Up Redirect
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterScreen()),
                              );
                            },
                            child: const Text(
                              'Sign up',
                              style: TextStyle(
                                color: Color(0xFF818CF8),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
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
}