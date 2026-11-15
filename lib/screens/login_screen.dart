import 'forgot_password_screen.dart';
import '../services/auth_service.dart';
import '../widgets/google_sign_in_button.dart';
import 'package:flutter/material.dart';
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
      labelStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF4B7A5E)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF4B7A5E)),
      filled: true,
      fillColor: const Color(0xFFF0FDF4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFBBF7D0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
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
        backgroundColor: const Color(0xFFF0FDF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFBBF7D0)),
        ),
        title: Row(
          children: const [
            Icon(Icons.gavel_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text("Terms & Conditions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text("1. Account Responsibility", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF14532D))),
              SizedBox(height: 2),
              Text("Users are responsible for keeping account credentials confidential and providing accurate contact information for order notifications.", style: TextStyle(fontSize: 11, color: Color(0xFF4B7A5E))),
              SizedBox(height: 10),
              Text("2. Printing Orders & Proofing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF14532D))),
              SizedBox(height: 2),
              Text("Customers must verify file contents, document sizes, and spelling prior to submitting orders. Orders may be cancelled only before admin approval. New customers use GCash. Cash on Pickup unlocks after the first payment-verified, completed order.", style: TextStyle(fontSize: 11, color: Color(0xFF4B7A5E))),
              SizedBox(height: 10),
              Text("3. Unclaimed Print Items Disposal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF14532D))),
              SizedBox(height: 2),
              Text("Printed materials left unclaimed at the shop after 30 calendar days will be disposed of without refund eligibility.", style: TextStyle(fontSize: 11, color: Color(0xFF4B7A5E))),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF15803D), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("I Understand & Agree"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_isLoading || AuthService.signingIn) return;
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
    final password = _loginPasswordController.text;

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

      final profile = await AuthService.readyProfile(user);
      final isAdmin = profile['role'] == 'admin';

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
        errorMsg = 'Incorrect email or password. Use Forgot password to set or reset your app password.';
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
        SnackBar(content: Text(signInError(e)), backgroundColor: const Color(0xFFF43F5E)),
      );
    }
  }

  Future<void> _showForgotPasswordModal(BuildContext context) async {
    final changed = await showModalBottomSheet<bool>(context: context,
      isScrollControlled: true, useSafeArea: true, isDismissible: false, enableDrag: false,
      builder: (_) => SizedBox(height: MediaQuery.sizeOf(context).height * .9,
        child: ForgotPasswordScreen(initialEmail: _loginEmailController.text.trim())));
    if (changed == true && mounted && context.mounted) {
      _loginPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password updated. Sign in with your email and new app password.'),
        backgroundColor: Color(0xFF15803D)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: !_isLoading, child: Scaffold(
      backgroundColor: const Color(0xFFF8FFF9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF14532D)),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
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
                    const Color(0xFF16A34A).withValues(alpha: 0.18),
                    const Color(0xFF4ADE80).withValues(alpha: 0.06),
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
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.28),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.asset('assets/images/kcz_logo.jpg', fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome Back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF14532D),
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
                          color: Color(0xFF4B7A5E),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Glass Card Form Container
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.97),
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
                                style: TextStyle(color: Color(0xFF14532D), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _loginEmailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
                                decoration: _buildDarkInputDecoration('e.g. user@gmail.com', Icons.email_outlined),
                                validator: (v) => AppValidators.validateEmail(v),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Password',
                                style: TextStyle(color: Color(0xFF14532D), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _loginPasswordController,
                                obscureText: _obscureLoginPassword,
                                style: const TextStyle(color: Color(0xFF14532D), fontSize: 13),
                                decoration: _buildDarkInputDecoration('Enter your password', Icons.lock_outline_rounded).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureLoginPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                      color: const Color(0xFF4B7A5E),
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
                                  onPressed: _isLoading ? null : () => _showForgotPasswordModal(context),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 28),
                                  ),
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      color: Color(0xFF4ADE80),
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
                                      activeColor: const Color(0xFF16A34A),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: _isLoading ? null : (val) => setState(() => _loginAgreeTerms = val ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showTermsAndConditionsDialog(context),
                                      child: const Text.rich(
                                        TextSpan(
                                          text: "I agree to the ",
                                          style: TextStyle(fontSize: 11, color: Color(0xFF4B7A5E)),
                                          children: [
                                            TextSpan(
                                              text: "Terms & Conditions",
                                              style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold),
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
                                    backgroundColor: const Color(0xFF15803D),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(0xFF15803D),
                                    disabledForegroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                    shadowColor: const Color(0xFF16A34A).withValues(alpha: 0.5),
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
                              GoogleSignInButton(busy: _isLoading, termsAccepted: _loginAgreeTerms,
                                onBusyChanged: (value) { if (mounted) setState(() => _isLoading = value); }),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Sign Up Redirect
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(color: Color(0xFF4B7A5E), fontSize: 12.5),
                          ),
                          GestureDetector(
                            onTap: _isLoading ? null : () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterScreen()),
                              );
                            },
                            child: const Text(
                              'Sign up',
                              style: TextStyle(
                                color: Color(0xFF4ADE80),
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
    ));
  }
}
