import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import '../utils/validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  String? _termsError;

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

  Future<void> _handleRegister() async {
    setState(() {
      _termsError = _agreeToTerms ? null : 'Kailangan mong sumang-ayon sa Terms & Conditions.';
    });

    if (_formKey.currentState!.validate() && _agreeToTerms) {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account successfully registered in Firebase!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration error: ${e.message ?? e.code}'), backgroundColor: Colors.red),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
        title: const Text(
          'Create New Account',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
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
                          onPressed: _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC026D3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Send Verification Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
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
          ),
        ),
      ),
    );
  }
}