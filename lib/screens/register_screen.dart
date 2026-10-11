import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'login_screen.dart';
import '../utils/validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _regStep = 1;
  final _formKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  String? _termsError;

  Timer? _countdownTimer;
  int _secondsRemaining = 60;
  bool _canResend = false;
  String _activeOtp = '';
  String _recipientEmail = '';

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _generate6DigitOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
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
        <div style="font-family: Arial, sans-serif; padding: 24px; background-color: #0b0f19; color: #ffffff; border-radius: 12px; border: 1px solid #1e293b;">
          <h2 style="color: #6366f1; margin-top: 0;">Kez C-Em Zek Printing Shop</h2>
          <p style="color: #cbd5e1;">Hello,</p>
          <p style="color: #cbd5e1;">Your 6-digit account verification code is:</p>
          <div style="background-color: #111827; padding: 14px 24px; border-radius: 8px; display: inline-block; margin: 12px 0;">
            <h1 style="color: #38bdf8; letter-spacing: 6px; margin: 0; font-size: 32px;">$otpCode</h1>
          </div>
          <p style="color: #94a3b8; font-size: 12px;">This code will expire in 5 minutes. If you did not request this, please ignore this email.</p>
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

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        if (mounted) setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  Future<void> _sendRegisterOtp() async {
    setState(() => _isLoading = true);
    _activeOtp = _generate6DigitOTP();
    _recipientEmail = _emailController.text.trim();

    try {
      await FirebaseFirestore.instance
          .collection('pending_users')
          .doc(_recipientEmail)
          .set({
        'full_name': _fullNameController.text.trim(),
        'phone': _mobileController.text.trim(),
        'email': _recipientEmail,
        'password': _passwordController.text.trim(),
        'otp': _activeOtp,
        'created_at': FieldValue.serverTimestamp(),
      });

      bool sent = await _sendEmailOTP(
        recipientEmail: _recipientEmail,
        otpCode: _activeOtp,
        subjectText: 'Account Verification - Kez C-Em Zek',
      );

      setState(() => _isLoading = false);

      if (sent) {
        _otpController.clear();
        _startTimer();
        setState(() => _regStep = 2);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send verification email. Please check your internet or email address.'),
            backgroundColor: Color(0xFFF43F5E),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving registration data: $e'),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
    }
  }

  Future<void> _verifyOtpAndComplete() async {
    if (_otpFormKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final docRef = FirebaseFirestore.instance
            .collection('pending_users')
            .doc(_recipientEmail);

        final doc = await docRef.get();

        if (!doc.exists) {
          setState(() => _isLoading = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pending registration expired or not found. Please register again.'),
              backgroundColor: Color(0xFFF43F5E),
            ),
          );
          return;
        }

        final pendingData = doc.data()!;

        if (pendingData['otp'] == _otpController.text.trim()) {
          UserCredential userCredential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(
            email: pendingData['email'],
            password: pendingData['password'],
          );

          await userCredential.user?.updateDisplayName(pendingData['full_name']);

          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'uid': userCredential.user!.uid,
            'full_name': pendingData['full_name'],
            'phone': pendingData['phone'],
            'email': pendingData['email'],
            'role': 'customer',
            'created_at': FieldValue.serverTimestamp(),
          });

          await docRef.delete();

          _countdownTimer?.cancel();
          setState(() => _isLoading = false);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! You can now log in.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        } else {
          setState(() => _isLoading = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid OTP code. Please enter the correct code.'),
              backgroundColor: Color(0xFFF43F5E),
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing registration: $e'),
            backgroundColor: const Color(0xFFF43F5E),
          ),
        );
      }
    }
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 15,
            color: isMet ? const Color(0xFF10B981) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                color: isMet ? const Color(0xFFE2E8F0) : const Color(0xFF64748B),
                fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
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
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFCBD5E1)),
            ),
            if (isRequired)
              const Text(' *', style: TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            counterText: '',
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF43F5E)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF43F5E), width: 1.5),
            ),
            suffixIcon: suffixIcon,
          ),
          validator: validator,
        ),
        if (subtext != null) ...[
          const SizedBox(height: 4),
          Text(subtext, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pass = _passwordController.text;
    final name = _fullNameController.text.trim().toLowerCase();
    final emailPrefix = _emailController.text.trim().split('@').first.toLowerCase();

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

    return Scaffold(
      backgroundColor: const Color(0xFF070A14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _regStep == 1 ? 'Create Account' : 'Verify Email OTP',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (_regStep == 2) {
              setState(() => _regStep = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Stack(
        children: [
          // Background ambient glow
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
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
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1224).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _regStep == 1
                        ? Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Get Started with KCZ Printing',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Register to place orders and track print jobs in real time',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          const SizedBox(height: 20),

                          // 1. Full Name
                          _buildField(
                            label: 'Full Name',
                            hintText: 'e.g. Juan A. Dela Cruz',
                            controller: _fullNameController,
                            onChanged: (_) => setState(() {}),
                            validator: (v) => AppValidators.validateName(v),
                          ),
                          const SizedBox(height: 14),

                          // 2. Contact Number
                          _buildField(
                            label: 'Contact Number (For SMS Alerts)',
                            hintText: '09171234567',
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            maxLength: 11,
                            subtext: 'Format: 11-digit PH mobile number starting with 09',
                            validator: (v) => AppValidators.validateContactNumber(v),
                          ),
                          const SizedBox(height: 14),

                          // 3. Gmail Address
                          _buildField(
                            label: 'Gmail Address (*.gmail.com)',
                            hintText: 'juan.delacruz@gmail.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) => setState(() {}),
                            validator: (v) => AppValidators.validateEmail(v),
                          ),
                          const SizedBox(height: 14),

                          // 4. Password
                          _buildField(
                            label: 'Password',
                            isRequired: true,
                            hintText: 'Enter strong password',
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            onChanged: (_) => setState(() {}),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: const Color(0xFF64748B),
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: strengthColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: strengthValue,
                                  backgroundColor: const Color(0xFF1E293B),
                                  valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                                  minHeight: 5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Password Requirements Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PASSWORD REQUIREMENTS:',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 6),
                                _buildRequirementItem('Must be at least 8 characters', req1),
                                _buildRequirementItem('Must have Uppercase (A-Z) and Lowercase (a-z)', req2),
                                _buildRequirementItem('Must have at least one symbol or number', req3),
                                _buildRequirementItem("Can't contain spaces", req4),
                                _buildRequirementItem("Can't include your name or email prefix", req5),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 5. Confirm Password
                          _buildField(
                            label: 'Confirm Password',
                            isRequired: true,
                            hintText: 'Re-enter password',
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: const Color(0xFF64748B),
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Please confirm your password';
                              if (v != _passwordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Terms & Conditions Checkbox
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _agreeToTerms,
                                  activeColor: const Color(0xFF4F46E5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (val) {
                                    setState(() {
                                      _agreeToTerms = val ?? false;
                                      if (_agreeToTerms) _termsError = null;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    text: "Sumasang-ayon ako sa ",
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), height: 1.3),
                                    children: [
                                      TextSpan(
                                        text: "Terms & Conditions",
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                                      ),
                                      TextSpan(
                                        text: " (Ang prints na hindi kukunin sa loob ng 30 araw ay ida-dispose).",
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_termsError != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 30, top: 4),
                              child: Text(_termsError!, style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 11)),
                            ),
                          const SizedBox(height: 20),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () async {
                                      setState(() {
                                        _termsError = _agreeToTerms ? null : 'You must agree to the Terms & Conditions.';
                                      });

                                      if (_formKey.currentState!.validate() && _agreeToTerms) {
                                        await _sendRegisterOtp();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4F46E5),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Text('Send Verification Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF94A3B8),
                                    side: const BorderSide(color: Color(0xFF1E293B)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Already have account
                          Center(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                );
                              },
                              child: const Text.rich(
                                TextSpan(
                                  text: "Already have an account? ",
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                  children: [
                                    TextSpan(
                                      text: 'Log In',
                                      style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                        : Form(
                      key: _otpFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enter OTP Verification Code',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'A 6-digit verification code was sent to your email:\n$_recipientEmail',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                          ),
                          const SizedBox(height: 22),

                          // OTP Input Field
                          TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.white),
                            decoration: InputDecoration(
                              hintText: '000000',
                              hintStyle: const TextStyle(color: Color(0xFF475569)),
                              counterText: '',
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF1E293B)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().length != 6) ? 'Please enter valid 6-digit OTP' : null,
                          ),
                          const SizedBox(height: 16),

                          // Countdown Timer & Resend Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _secondsRemaining > 0 ? 'Resend code in ${_secondsRemaining}s' : 'Code expired',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                              TextButton(
                                onPressed: _canResend && !_isLoading ? _sendRegisterOtp : null,
                                child: Text(
                                  'Resend OTP',
                                  style: TextStyle(
                                    color: _canResend ? const Color(0xFF818CF8) : const Color(0xFF475569),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Verify Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyOtpAndComplete,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Verify OTP & Complete Sign Up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: TextButton(
                              onPressed: () => setState(() => _regStep = 1),
                              child: const Text('← Back to Registration Form', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
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