import 'dart:async';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 1; // Step 1: Identity, Step 2: OTP, Step 3: Reset Password

  // Step A Controllers
  final TextEditingController _identityController = TextEditingController();

  // Step B Controllers
  final TextEditingController _otpController = TextEditingController();
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;
  String _generatedOtp = '';
  DateTime? _otpTime;

  // Step C Controllers
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController = TextEditingController();
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

  final _formKeyA = GlobalKey<FormState>();
  final _formKeyB = GlobalKey<FormState>();
  final _formKeyC = GlobalKey<FormState>();

  String _maskedContact = '';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- STEP A HANDLER ---
  void _submitStepA() {
    if (_formKeyA.currentState!.validate()) {
      final input = _identityController.text.trim();
      _maskedContact = _maskContact(input);

      _sendDualOtp();
      _startTimer();

      setState(() {
        _currentStep = 2;
      });
    }
  }

  // --- STEP B HANDLER ---
  void _submitStepB() {
    if (_formKeyB.currentState!.validate()) {
      // Expiration check (5 minutes = 300 seconds)
      if (_otpTime != null && DateTime.now().difference(_otpTime!).inSeconds > 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expired na ang OTP. Humingi ng bagong code.')),
        );
        return;
      }

      if (_otpController.text.trim() == _generatedOtp) {
        _timer?.cancel();
        setState(() {
          _currentStep = 3;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maling OTP Code. Subukang muli.')),
        );
      }
    }
  }

  // --- STEP C HANDLER ---
  void _submitStepC() {
    if (_formKeyC.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully! Maaari ka nang mag-login.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _sendDualOtp() {
    // Generate 6-digit dummy OTP code for demo/testing
    _generatedOtp = '123456';
    _otpTime = DateTime.now();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Dual OTP Code sent to $_maskedContact (Demo Code: $_generatedOtp)'),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  String _maskContact(String value) {
    if (value.contains('@')) {
      final parts = value.split('@');
      if (parts[0].length <= 2) return value;
      return '${parts[0].substring(0, 2)}***@${parts[1]}';
    } else {
      if (value.length < 11) return value;
      return '${value.substring(0, 4)}***${value.substring(8)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('Password Recovery', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_currentStep == 1) _buildStepA(),
              if (_currentStep == 2) _buildStepB(),
              if (_currentStep == 3) _buildStepC(),
            ],
          ),
        ),
      ),
    );
  }

  // --- STEP A UI: IDENTIFICATION ---
  Widget _buildStepA() {
    return Form(
      key: _formKeyA,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Forgot Password', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          const Text('Enter your registered Email or PH Mobile Number to receive a dual verification code.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          TextFormField(
            controller: _identityController,
            decoration: _buildInputDecoration('Registered Email or Mobile (09XX...)', Icons.person_search_rounded),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Enter your email or mobile number';
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitStepA,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Send Verification Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP B UI: OTP VERIFICATION ---
  Widget _buildStepB() {
    return Form(
      key: _formKeyB,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter OTP Code', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Text('We sent a 6-digit verification code to: $_maskedContact', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: _buildInputDecoration('6-Digit Code', Icons.security_rounded).copyWith(counterText: ''),
            validator: (value) {
              if (value == null || value.trim().length != 6) return 'Enter 6-digit OTP code';
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitStepB,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Verify OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _canResend ? () { _sendDualOtp(); _startTimer(); } : null,
              child: Text(
                _canResend ? 'Resend Code' : 'Resend Code in ${_secondsRemaining}s',
                style: TextStyle(
                  color: _canResend ? const Color(0xFFE11D48) : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP C UI: SET NEW PASSWORD ---
  Widget _buildStepC() {
    return Form(
      key: _formKeyC,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Set New Password', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          const Text('Create a strong new password for your print shop account.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPass,
            decoration: _buildInputDecoration('New Password', Icons.lock_outline_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscureNewPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B)),
                onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmNewPasswordController,
            obscureText: _obscureConfirmPass,
            decoration: _buildInputDecoration('Confirm New Password', Icons.lock_reset_rounded).copyWith(
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPass ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B)),
                onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
              ),
            ),
            validator: (value) {
              if (value != _newPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitStepC,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Reset Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE11D48))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5)),
    );
  }
}