import '../services/password_reset_service.dart';
import '../widgets/google_sign_in_button.dart';
import 'dart:async';
import 'package:flutter/material.dart';
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
  final _verification = PasswordResetService();
  String _recipientEmail = '';

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _verification.close();
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
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
    if (_isLoading) return;
    setState(() => _isLoading = true);
    _recipientEmail = _emailController.text.trim().toLowerCase();
    try {
      await _verification.requestSignupCode(_recipientEmail);
      if (!mounted) return;
      _otpController.clear();
      _startTimer();
      setState(() => _regStep = 2);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is StateError ? error.message.toString() : 'Unable to request verification. Please try again.'),
          backgroundColor: const Color(0xFFF43F5E),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtpAndComplete() async {
    if (_isLoading || !_otpFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _verification.register({
        'email': _recipientEmail,
        'fullName': _fullNameController.text.trim(),
        'contact': _mobileController.text.trim(),
        'password': _passwordController.text,
        'confirmPassword': _confirmPasswordController.text,
        'otp': _otpController.text.trim(),
      });
      if (!mounted) return;
      _countdownTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Registration successful! You can now log in.'),
        backgroundColor: Color(0xFF10B981),
      ));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is StateError ? error.message.toString() : 'Unable to complete registration. Please retry the same code.'),
          backgroundColor: const Color(0xFFF43F5E),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            color: isMet ? const Color(0xFF10B981) : const Color(0xFF4B7A5E),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                color: isMet ? const Color(0xFF14532D) : const Color(0xFF4B7A5E),
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
            Expanded(child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF14532D)),
            )),
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
          style: const TextStyle(fontSize: 13, color: Color(0xFF14532D)),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF4B7A5E)),
            counterText: '',
            filled: true,
            fillColor: const Color(0xFFF0FDF4),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFBBF7D0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
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
          Text(subtext, style: const TextStyle(fontSize: 11, color: Color(0xFF4B7A5E))),
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

    return PopScope(canPop: !_isLoading, child: Scaffold(
      backgroundColor: const Color(0xFFF8FFF9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _regStep == 1 ? 'Create Account' : 'Verify Email OTP',
          style: const TextStyle(color: Color(0xFF14532D), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF14532D)),
          onPressed: _isLoading ? null : () {
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
                    const Color(0xFF16A34A).withValues(alpha: 0.18),
                    const Color(0xFF15803D).withValues(alpha: 0.06),
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
                      color: Colors.white.withValues(alpha: 0.97),
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
                            style: TextStyle(color: Color(0xFF14532D), fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Register to place orders and track print jobs in real time',
                            style: TextStyle(color: Color(0xFF4B7A5E), fontSize: 12),
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
                                color: const Color(0xFF4B7A5E),
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
                                  backgroundColor: const Color(0xFFBBF7D0),
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
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PASSWORD REQUIREMENTS:',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF4B7A5E), letterSpacing: 0.5),
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
                                color: const Color(0xFF4B7A5E),
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
                                  activeColor: const Color(0xFF16A34A),
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
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF4B7A5E), height: 1.3),
                                    children: [
                                      TextSpan(
                                        text: "Terms & Conditions",
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                      ),
                                      TextSpan(
                                        text: " (Unclaimed prints will be disposed of after 30 days).",
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
                                      backgroundColor: const Color(0xFF15803D),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: const Color(0xFF15803D),
                                      disabledForegroundColor: Colors.white,
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
                                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF4B7A5E),
                                    side: const BorderSide(color: Color(0xFFBBF7D0)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                              ),
                            ],
                          ),

                          GoogleSignInButton(busy: _isLoading, termsAccepted: _agreeToTerms,
                            onBusyChanged: (value) { if (mounted) setState(() => _isLoading = value); }),

                          const SizedBox(height: 18),

                          // Already have account
                          Center(
                            child: GestureDetector(
                              onTap: _isLoading ? null : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                );
                              },
                              child: const Text.rich(
                                TextSpan(
                                  text: "Already have an account? ",
                                  style: TextStyle(color: Color(0xFF4B7A5E), fontSize: 12),
                                  children: [
                                    TextSpan(
                                      text: 'Log In',
                                      style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold),
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
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'A 6-digit verification code was sent to your email:\n$_recipientEmail',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF4B7A5E), height: 1.4),
                          ),
                          const SizedBox(height: 22),

                          // OTP Input Field
                          TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: '000000',
                              hintStyle: const TextStyle(color: Color(0xFF86EFAC)),
                              counterText: '',
                              filled: true,
                              fillColor: const Color(0xFFF0FDF4),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFBBF7D0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF16A34A), width: 2),
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
                                style: const TextStyle(fontSize: 12, color: Color(0xFF4B7A5E)),
                              ),
                              TextButton(
                                onPressed: _canResend && !_isLoading ? _sendRegisterOtp : null,
                                child: Text(
                                  'Resend OTP',
                                  style: TextStyle(
                                    color: _canResend ? const Color(0xFF15803D) : const Color(0xFF86EFAC),
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
                                backgroundColor: const Color(0xFF15803D),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(0xFF15803D),
                                disabledForegroundColor: Colors.white,
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
                              child: const Text('← Back to Registration Form', style: TextStyle(color: Color(0xFF4B7A5E), fontWeight: FontWeight.w600, fontSize: 12)),
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
    ));
  }
}
