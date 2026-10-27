import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _socialLoading; // 'google' | 'facebook' | 'guest'

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(
              0.4,
              1.0,
              curve: Curves.fastLinearToSlowEaseIn,
            ),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: color.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Authentication Logic ──────────────────────────────────────────────────
  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('يرجى ملء جميع الحقول للمتابعة', Colors.orangeAccent);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = AuthService();
      final result = await authService.signIn(email: email, password: password);

      if (result != null && result['sessionId'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sessionId', result['sessionId']);
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      _showSnackBar(e.toString(), Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar(
        'يرجى إدخال بريدك الإلكتروني أولاً لإرسال رابط استعادة كلمة المرور',
        Colors.orangeAccent,
      );
      return;
    }

    // إظهار مؤشر الانتظار
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );

    try {
      await AuthService().resetPassword(email: email);
      if (mounted) Navigator.pop(context); // إغلاق المؤشر
      _showSnackBar(
        'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني بنجاح',
        Colors.greenAccent,
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // إغلاق المؤشر
      _showSnackBar(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _handleSocialLogin(
    String type,
    Future<dynamic> Function() loginMethod,
  ) async {
    setState(() => _socialLoading = type);
    try {
      final result = await loginMethod();
      if (result != null && mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      _showSnackBar(e.toString(), Colors.redAccent);
    } finally {
      if (mounted) setState(() => _socialLoading = null);
    }
  }

  // ─── Building the UI ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020817), // Ultra Deep Space Blue
      body: Stack(
        children: [
          // 1. Dynamic Mesh Background
          _buildVibrantBackground(),

          // 2. Main Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Logo Section (App Icon)
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildAnimatedLogo(),
                  ),

                  const SizedBox(height: 24),

                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'مرحبا بك في ميتو',
                          style: GoogleFonts.cairo(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'سجل دخولك لتكتشف عالم الاستثمار الحقيقي ومتعة التواصل والتسلية',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Login Form Section
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildGlassLoginCard(),
                    ),
                  ),

                  const SizedBox(height: 35),

                  // Social Media Authentication
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildSocialSection(),
                  ),

                  const SizedBox(height: 40),

                  // Footer Section
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildFooterSection(),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVibrantBackground() {
    final primaryColor = Theme.of(context).primaryColor;
    return Stack(
      children: [
        Positioned(
          top: -150,
          right: -100,
          child: _buildBlurCircle(
            400,
            primaryColor.withOpacity(0.25),
          ),
        ),
        Positioned(
          bottom: -100,
          left: -150,
          child: _buildBlurCircle(
            450,
            primaryColor.withOpacity(0.2),
          ),
        ),
        Positioned(
          top: 300,
          left: -50,
          child: _buildBlurCircle(
            250,
            primaryColor.withOpacity(0.15),
          ),
        ),
      ],
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return Container(
      height: 110,
      width: 110,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(0, 99, 101, 241),
            Color.fromARGB(0, 169, 85, 247),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(0),
        decoration: const BoxDecoration(
          color: Color.fromARGB(0, 226, 226, 223),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/app_icon.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.rocket_launch_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassLoginCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(35),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(35),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              _buildModernTextField(
                controller: _emailController,
                hintText: 'البريد الإلكتروني',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              _buildModernTextField(
                controller: _passwordController,
                hintText: 'كلمة المرور',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                isPasswordVisible: _isPasswordVisible,
                onToggle: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: Text(
                    'نسيت كلمة المرور؟',
                    style: GoogleFonts.cairo(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildLoginButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool? isPasswordVisible,
    VoidCallback? onToggle,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      child: TextField(

        controller: controller,
        obscureText: isPassword && (isPasswordVisible != true),
        keyboardType: keyboardType,
        style: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.cairo(
            color: Colors.white.withOpacity(0.3),
            fontSize: 15,
          ),

          prefixIcon: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 22,
          ),

          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible == true
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: const Color.fromARGB(
                      255,
                      58,
                      57,
                      57,
                    ).withOpacity(0.3),
                    size: 20,
                  ),
                  onPressed: onToggle,
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 18,
          ),
        ),

      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 26,
                width: 26,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                'تسجيل الدخول',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildSocialSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.white.withOpacity(0.1),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'أو المتابعة عبر',
                style: GoogleFonts.cairo(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.white.withOpacity(0.1),
                thickness: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCircularSocialBtn(
              icon: const _GoogleIcon(),
              loading: _socialLoading == 'google',
              onTap: () =>
                  _handleSocialLogin('google', AuthService().signInWithGoogle),
            ),
            const SizedBox(width: 25),
            _buildCircularSocialBtn(
              icon: const Icon(
                Icons.facebook_rounded,
                color: Color(0xFF1877F2),
                size: 32,
              ),
              loading: _socialLoading == 'facebook',
              onTap: () => _handleSocialLogin(
                'facebook',
                AuthService().signInWithFacebook,
              ),
            ),
            const SizedBox(width: 25),
            _buildCircularSocialBtn(
              icon: const Icon(
                Icons.person_pin_circle_rounded,
                color: Color(0xFF10B981),
                size: 32,
              ),
              loading: _socialLoading == 'guest',
              onTap: () =>
                  _handleSocialLogin('guest', AuthService().signInAnonymously),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircularSocialBtn({
    required Widget icon,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : icon,
        ),
      ),
    );
  }

  Widget _buildFooterSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'ليس لديك حساب؟ ',
          style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.5)),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/signup'),
          child: Text(
            'سجل الآن مجاناً',
            style: GoogleFonts.cairo(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Custom Painted Google Icon ──────────────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeW = w * 0.16;
    final center = Offset(w / 2, h / 2);
    final r = w * 0.38;
    final arcRect = Rect.fromCircle(center: center, radius: r);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    // Blue arc
    canvas.drawArc(
      arcRect,
      -math.pi * 0.25,
      math.pi * 0.75,
      false,
      paint..color = const Color(0xFF4285F4),
    );
    // Red arc
    canvas.drawArc(
      arcRect,
      -math.pi * 1.25,
      math.pi * 0.5,
      false,
      paint..color = const Color(0xFFEA4335),
    );
    // Yellow arc
    canvas.drawArc(
      arcRect,
      math.pi * 0.75,
      math.pi * 0.5,
      false,
      paint..color = const Color(0xFFFBBC05),
    );
    // Green arc
    canvas.drawArc(
      arcRect,
      math.pi * 0.5,
      math.pi * 0.25,
      false,
      paint..color = const Color(0xFF34A853),
    );

    // Horizontal bar
    final barY = center.dy;
    canvas.drawLine(
      Offset(center.dx, barY),
      Offset(center.dx + r + strokeW / 2, barY),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
