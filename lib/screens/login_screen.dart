import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dashboard_screen.dart';

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

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
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

  // ===========================================================================
  // SMTP EMAIL SENDER HELPER FUNCTION
  // ===========================================================================
  Future<bool> _sendEmailOTP({
    required String recipientEmail,
    required String otpCode,
    required String subjectText,
  }) async {
    const String senderEmail = 'yourprintshop@gmail.com';
    const String appPassword = 'xxxx xxxx xxxx xxxx'; // 16-character Gmail App Password

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
          <p style="color: #64748b; font-size: 12px;">This code will expire in 5 minutes. If you did not request this, please ignore this email.</p>
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

  void _handleLogin() {
    if (_loginFormKey.currentState!.validate()) {
      final email = _loginEmailController.text.trim();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen(userEmail: email)),
      );
    }
  }

  // ===========================================================================
  // 1. CREATE NEW ACCOUNT MODAL (WITH SMOOTH ENTRY ANIMATION)
  // ===========================================================================
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, animValue, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - animValue) * 40),
                  child: Opacity(
                    opacity: animValue,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
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
                              const Text(
                                'Create New Account',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: nameController,
                            decoration: _buildInputDecoration('Full Name *', Icons.person_outline_rounded),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your full name' : null,
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _buildInputDecoration('Email Address *', Icons.email_outlined),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Please enter your email address';
                              final reg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!reg.hasMatch(v.trim())) return 'Please enter a valid email address';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 11,
                            decoration: _buildInputDecoration('Contact Number (09XX...) *', Icons.phone_android_rounded).copyWith(counterText: ''),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Please enter your contact number';
                              final phReg = RegExp(r'^09\d{9}$');
                              if (!phReg.hasMatch(v.trim())) return 'Must start with 09 and contain 11 digits';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: passwordController,
                            obscureText: obscurePass,
                            decoration: _buildInputDecoration('Password *', Icons.lock_outline_rounded).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B)),
                                onPressed: () => setModalState(() => obscurePass = !obscurePass),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Please enter a password';
                              if (v.length < 6) return 'Must be at least 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: confirmPasswordController,
                            obscureText: obscureConfirmPass,
                            decoration: _buildInputDecoration('Confirm Password *', Icons.lock_reset_rounded).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(obscureConfirmPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B)),
                                onPressed: () => setModalState(() => obscureConfirmPass = !obscureConfirmPass),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Please confirm your password';
                              if (v != passwordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: termsErrorMsg != null ? const Color(0xFFE11D48) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: agreeToTerms,
                                  activeColor: const Color(0xFFE11D48),
                                  onChanged: (val) {
                                    setModalState(() {
                                      agreeToTerms = val ?? false;
                                      if (agreeToTerms) termsErrorMsg = null;
                                    });
                                  },
                                ),
                                const Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      'I agree to the Terms & Conditions (Unclaimed printed items after 30 days will be automatically disposed of).',
                                      style: TextStyle(fontSize: 10.5, color: Color(0xFF334155), height: 1.3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (termsErrorMsg != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 4),
                              child: Text(termsErrorMsg!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 11)),
                            ),

                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
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

                                  setModalState(() => isLoading = false);

                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          sent
                                              ? 'Account registered! Verification code sent to $recipient'
                                              : 'Failed to send verification email. Please try again.',
                                        ),
                                        backgroundColor: sent ? const Color(0xFF059669) : const Color(0xFFE11D48),
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE11D48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Register Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
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

  // ===========================================================================
  // 2. FORGOT PASSWORD MODAL (WITH ANIMATED SWITCHER STEP TRANSITION)
  // ===========================================================================
  void _showForgotPasswordModal(BuildContext context) {
    int currentStep = 1;
    final stepAKey = GlobalKey<FormState>();
    final stepBKey = GlobalKey<FormState>();
    final stepCKey = GlobalKey<FormState>();

    final emailController = TextEditingController();
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmNewPasswordController = TextEditingController();

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
                    const SnackBar(content: Text('Failed to send OTP email. Please check your address or connection.')),
                  );
                }
              }
            }

            return TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, animValue, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - animValue) * 40),
                  child: Opacity(
                    opacity: animValue,
                    child: child,
                  ),
                );
              },
              child: Padding(
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

                        // ANIMATED STEP TRANSITION (STEP 1 -> STEP 2 -> STEP 3)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.15, 0.0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: currentStep == 1
                              ? Form(
                            key: stepAKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Enter your registered Email Address to receive a password reset verification code.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _buildInputDecoration('Registered Email Address', Icons.email_outlined),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Please enter your email address';
                                    final reg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                    if (!reg.hasMatch(v.trim())) return 'Please enter a valid email address';
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
                              : currentStep == 2
                              ? Form(
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
                                  validator: (v) => (v == null || v.trim().length != 6) ? 'Please enter the valid 6-digit OTP' : null,
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
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid OTP code. Please try again.')));
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
                              : Form(
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
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: confirmNewPasswordController,
                                  obscureText: true,
                                  decoration: _buildInputDecoration('Confirm New Password', Icons.lock_reset_rounded),
                                  validator: (v) => (v != newPasswordController.text) ? 'Passwords do not match' : null,
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
                                          const SnackBar(content: Text('Password reset successfully! You can now log in.'), backgroundColor: Color(0xFF059669)),
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

  // ===========================================================================
  // MAIN LOGIN UI BUILD WITH ANIMATION
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Stack(
            children: [
              // 1. TOP CURVED DARK SLATE HEADER
              FadeTransition(
                opacity: _fadeAnimation,
                child: ClipPath(
                  clipper: CurvedHeaderClipper(),
                  child: Container(
                    height: size.height * 0.38,
                    width: double.infinity,
                    color: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFE11D48)]),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.print_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'KCZ PRINTING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Kez C-Em Zek',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome back! Log in to continue.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. MAIN LOGIN FORM CARD CONTAINER
              Positioned(
                top: size.height * 0.31,
                left: 20,
                right: 20,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 16,
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
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _loginEmailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _buildInputDecoration('Email', Icons.email_outlined),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Please enter your email address';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                TextFormField(
                                  controller: _loginPasswordController,
                                  obscureText: _obscureLoginPassword,
                                  decoration: _buildInputDecoration('Password', Icons.lock_outline_rounded).copyWith(
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureLoginPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        color: const Color(0xFF64748B),
                                      ),
                                      onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Please enter your password';
                                    return null;
                                  },
                                ),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => _showForgotPasswordModal(context),
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                    child: const Text(
                                      'Forgot password?',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Login',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                Row(
                                  children: [
                                    const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('Or', style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildSocialIconButton(Icons.facebook, const Color(0xFF1877F2)),
                                    const SizedBox(width: 16),
                                    _buildSocialIconButton(Icons.g_mobiledata_rounded, const Color(0xFFEA4335), size: 28),
                                    const SizedBox(width: 16),
                                    _buildSocialIconButton(Icons.apple, const Color(0xFF000000)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        GestureDetector(
                          onTap: () => _showRegisterModal(context),
                          child: const Text.rich(
                            TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              children: [
                                TextSpan(
                                  text: 'Sign up',
                                  style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIconButton(IconData icon, Color color, {double size = 20}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE11D48))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
    );
  }
}

// ===========================================================================
// CUSTOM CLIPPER FOR SMOOTH CURVED HEADER
// ===========================================================================
class CurvedHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 40);

    var firstControlPoint = Offset(size.width / 2, size.height + 25);
    var firstEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}