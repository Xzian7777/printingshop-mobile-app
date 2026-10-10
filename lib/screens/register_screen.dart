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
// Removed unused OTP form key

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
        <div style="font-family: Arial, sans-serif; padding: 20px; border: 1px solid #e2e8f0; border-radius: 10px;">
          <h2 style="color: #e11d48;">Kez C-Em Zek Printing Shop Service</h2>
          <p>Hello,</p>
          <p>Your OTP verification code is:</p>
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

  Future<void> _sendRegisterVerificationLink() async {
    setState(() => _isLoading = true);
    _recipientEmail = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final fullName = _fullNameController.text.trim();
    final phone = _mobileController.text.trim();

    try {
      // 1. Create account in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _recipientEmail,
        password: password,
      );

      await userCredential.user?.updateDisplayName(fullName);

      // 2. Send Firebase verification link
      await userCredential.user?.sendEmailVerification();

      // 3. Save pending info in pending_users collection
      await FirebaseFirestore.instance
          .collection('pending_users')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'full_name': fullName,
        'phone': phone,
        'email': _recipientEmail,
        'role': 'customer',
        'created_at': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('pending_users')
          .doc(_recipientEmail)
          .set({
        'uid': userCredential.user!.uid,
        'full_name': fullName,
        'phone': phone,
        'email': _recipientEmail,
        'role': 'customer',
        'created_at': FieldValue.serverTimestamp(),
      });

      setState(() => _isLoading = false);
      _startTimer();
      setState(() => _regStep = 2);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification link sent to your email!'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      String msg = e.message ?? 'Registration failed.';
      if (e.code == 'email-already-in-use') {
        msg = 'This email is already registered. Please log in.';
      } else if (e.code == 'weak-password') {
        msg = 'The password is too weak.';
      } else if (e.code == 'invalid-email') {
        msg = 'The email address is invalid.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving registration data: $e'),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
    }
  }

  Future<void> _resendVerificationLink() async {
    setState(() => _isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
      } else {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: _recipientEmail,
          password: _passwordController.text.trim(),
        );
        user = credential.user;
        await user?.sendEmailVerification();
      }

      setState(() => _isLoading = false);
      _startTimer();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification link resent successfully!'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend link: $e'),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
    }
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: _recipientEmail,
          password: _passwordController.text.trim(),
        );
        user = credential.user;
      }

      if (user != null) {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;
      }

      if (user != null && user.emailVerified) {
        final pendingDoc = await FirebaseFirestore.instance
            .collection('pending_users')
            .doc(user.uid)
            .get();

        final pendingEmailDoc = await FirebaseFirestore.instance
            .collection('pending_users')
            .doc(_recipientEmail)
            .get();

        final data = pendingDoc.data() ?? pendingEmailDoc.data() ?? {};

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'full_name': data['full_name'] ?? (user.displayName ?? _fullNameController.text.trim()),
          'phone': data['phone'] ?? _mobileController.text.trim(),
          'email': user.email ?? _recipientEmail,
          'role': 'customer',
          'created_at': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance.collection('pending_users').doc(user.uid).delete();
        await FirebaseFirestore.instance.collection('pending_users').doc(_recipientEmail).delete();

        await FirebaseAuth.instance.signOut();

        _countdownTimer?.cancel();
        setState(() => _isLoading = false);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully! You can now log in.'),
            backgroundColor: Color(0xFF059669),
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
            content: Text('Your email is not verified yet. Please click the link in your email first.'),
            backgroundColor: Color(0xFFE11D48),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking verification: $e'),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
    }
  }

  Widget _buildRequirementItem(String text, bool isMet) {
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
            fillColor: Colors.white,
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          _regStep == 1 ? 'Create New Account' : 'Verify Email',
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () {
            if (_regStep == 2) {
              setState(() => _regStep = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: _regStep == 1
              ? Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B), size: 20),
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

                // Password Requirements Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                      _buildRequirementItem('Must be at least 8 characters', req1),
                      _buildRequirementItem('Must have Uppercase (A-Z) and Lowercase (a-z)', req2),
                      _buildRequirementItem('Must have at least one symbol or number', req3),
                      _buildRequirementItem("Can't contain spaces", req4),
                      _buildRequirementItem("Can't include your name or email address", req5),
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
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B), size: 20),
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
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreeToTerms,
                        activeColor: const Color(0xFFC026D3),
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
                          text: "I agree to the ",
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.3),
                          children: [
                            TextSpan(
                              text: "Terms & Conditions",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                            ),
                            TextSpan(
                              text: " (Unclaimed prints within 30 days will be disposed of).",
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_termsError != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 32, top: 4),
                    child: Text(_termsError!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 11)),
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
                              await _sendRegisterVerificationLink();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC026D3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Send Verification Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
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

                const SizedBox(height: 16),

                // Already have an account Link
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
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        children: [
                          TextSpan(
                            text: 'Log In',
                            style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Verify Your Email', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F8),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFBCFE8), width: 1.5),
                  ),
                  child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFFC026D3), size: 32),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'A verification link has been sent to:',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _recipientEmail,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Please check your email inbox (and spam folder) and click the verification link to activate your account.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkVerificationStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('I Have Verified My Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 12),

              // Resend Button
              Center(
                child: TextButton(
                  onPressed: _canResend && !_isLoading ? _resendVerificationLink : null,
                  child: Text(
                    _canResend ? 'Resend Verification Link' : 'Resend Link in ${_secondsRemaining}s',
                    style: TextStyle(
                      color: _canResend ? const Color(0xFFC026D3) : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => setState(() => _regStep = 1),
                  child: const Text('← Back to Registration Form', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}