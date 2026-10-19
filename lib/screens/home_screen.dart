import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF070A14),
      body: Stack(
        children: [
          // Ambient Glow Background
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.18),
                    const Color(0xFF6366F1).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
            right: -100,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    const Color(0xFF06B6D4).withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- TOP NAVIGATION BAR ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Brand Logo
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.print_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'KCZ Printing',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),

                        // Auth Action Buttons (Login & Sign Up)
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFE2E8F0),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                              ),
                              child: const Text(
                                'Sign up',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // --- HERO TITLE & SUBTITLE ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Text(
                          'Elevate Your\nPrinting Experience',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: const Text(
                            'Unlock your printing potential in a fully connected environment, powered by Kez C-Em Zek Printing Shop',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- CENTER SPHERE GRAPHIC WITH FLOATING GLASS CARDS ---
                  SizedBox(
                    height: 340,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Animated Futuristic Wireframe Sphere
                        AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            return CustomPaint(
                              size: const Size(360, 280),
                              painter: _FuturisticSpherePainter(progress: _animController.value),
                            );
                          },
                        ),

                        // Center Top Pill: "Sign Up & Print"
                        Positioned(
                          top: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0F172A),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Sign Up & Print',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Left Floating Glass Card: "Print Services"
                        Positioned(
                          left: 16,
                          bottom: 70,
                          child: _buildGlassCard(
                            width: 155,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Print Services',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.north_east_rounded,
                                        color: Colors.white,
                                        size: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Unparalleled\nQuality Proofing',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '100% Guaranteed',
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Right Floating Glass Card: "Live Tracking"
                        Positioned(
                          right: 16,
                          bottom: 40,
                          child: _buildGlassCard(
                            width: 155,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Order Tracking',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.north_east_rounded,
                                        color: Colors.white,
                                        size: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '99.4%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Gradient progress bar
                                Container(
                                  width: double.infinity,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: 0.94,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF818CF8), Color(0xFFEC4899)],
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- QUICK HIGHLIGHT CARDS ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PLATFORM CAPABILITIES',
                          style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Everything you need for hassle-free printing',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureCard(
                          icon: Icons.upload_file_rounded,
                          title: 'Instant Online File Proofing',
                          desc: 'Upload PDF, DOCX, or images directly. Get accurate page counts and real-time total calculation before payment.',
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureCard(
                          icon: Icons.track_changes_rounded,
                          title: 'Live Stage-by-Stage Tracking',
                          desc: 'Monitor your print job in real time: Pending, Printing, Ready for Pick-up, and Completed.',
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureCard(
                          icon: Icons.contactless_rounded,
                          title: 'RFID Loyalty & SMS Alerts',
                          desc: 'Tap your customer RFID card at the store counter to earn loyalty points and receive SMS pickup notifications.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Bottom Call-To-Action Banner
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF312E81)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Ready to submit your first print job?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create an account in less than a minute with safe OTP email verification.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF475569)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('Sign In'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Footer
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Text(
                      '© 2026 Kez C-Em Zek Printing Shop. All rights reserved.',
                      style: TextStyle(color: Color(0xFF475569), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildGlassCard({required double width, required Widget child}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1224).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  static Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1224),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: const Color(0xFF818CF8), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter to draw futuristic glowing 3D orbital curves (matching the screenshot)
class _FuturisticSpherePainter extends CustomPainter {
  final double progress;
  _FuturisticSpherePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);
    final radiusX = size.width * 0.44;
    final radiusY = size.height * 0.38;

    final paintGlow = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final paintStroke = Paint()
      ..color = const Color(0xFF4F46E5).withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final paintHighlight = Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Outer soft glow aura
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF4338CA).withValues(alpha: 0.20),
          const Color(0xFF1D4ED8).withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radiusX * 1.1));
    canvas.drawCircle(center, radiusX * 0.95, auraPaint);

    // Number of orbital rings
    const int ringCount = 7;
    for (int i = 0; i < ringCount; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);

      // Rotate each ellipse by distinct angles
      final double angle = (i * (math.pi / ringCount)) + (progress * 2 * math.pi * 0.05);
      canvas.rotate(angle);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: radiusX * (1.6 - (i * 0.1)),
        height: radiusY * (0.85 + (i * 0.08)),
      );

      // Draw blur glow then crisp stroke
      canvas.drawOval(rect, paintGlow);
      canvas.drawOval(rect, i % 2 == 0 ? paintHighlight : paintStroke);

      canvas.restore();
    }

    // Additional cross-diagonal ellipse
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 4);
    final diagRect = Rect.fromCenter(
      center: Offset.zero,
      width: radiusX * 1.8,
      height: radiusY * 0.7,
    );
    canvas.drawOval(diagRect, paintHighlight);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FuturisticSpherePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}