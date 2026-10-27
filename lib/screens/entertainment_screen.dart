import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mmmm/screens/competitions_screen.dart';
import 'ludo_screen.dart';
import 'voice_room_list_screen.dart';
import 'roulette_screen.dart';
import 'other_games_screen.dart';

class EntertainmentScreen extends StatefulWidget {
  const EntertainmentScreen({super.key});

  @override
  State<EntertainmentScreen> createState() => _EntertainmentScreenState();
}

class _EntertainmentScreenState extends State<EntertainmentScreen>
    with AutomaticKeepAliveClientMixin {
  late final Future<DocumentSnapshot> _settingsFuture;

  // ── تخزين الشاشات مرة واحدة لمنع إعادة البناء في كل دخول ──────────────────
  late final LudoScreen _ludoScreen;
  late final VoiceRoomListScreen _voiceRoomListScreen;
  late final RouletteScreen _rouletteScreen;
  late final OtherGamesScreen _otherGamesScreen;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // تهيئة الـ future مرة واحدة فقط عند إنشاء الصفحة لعدم التكرار
    _settingsFuture = FirebaseFirestore.instance
        .collection('app_settings')
        .doc('global')
        .get();

    // إنشاء الشاشات مرة واحدة فقط — لمنع إعادة initState في كل دخول
    _ludoScreen = const LudoScreen();
    _voiceRoomListScreen = const VoiceRoomListScreen();
    _rouletteScreen = const RouletteScreen();
    _otherGamesScreen = const OtherGamesScreen();
  }

  /// ينتقل إلى الشاشة مع إعادة استخدام نفس الـ widget instance
  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque:
            false, // Ensures the background page is NOT destroyed and remains painted
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // مطلوب عند استخدام AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'مركز التسلية',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 231, 19, 19)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
              Theme.of(context).primaryColor.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: FutureBuilder<DocumentSnapshot>(
          future: _settingsFuture,
          builder: (context, snapshot) {
            final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final isLudoEnabled = data['isLudoEnabled'] ?? true;
            final isRoomCardEnabled = data['isRoomCardEnabled'] ?? true;
            final isRouletteEnabled = data['isRouletteEnabled'] ?? true;
            final isCompetitionsEnabled = data['isCompetitionsEnabled'] ?? true;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCompetitionsEnabled) ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CompetitionsScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 200,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFD700),
                              Color(0xFFB8860B),
                              Color(0xFFDAA520),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: -5,
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    'assets/images/competition.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.amber.withOpacity(0.1),
                                        child: const Center(
                                          child: Icon(
                                            Icons.emoji_events_rounded,
                                            color: Colors.amber,
                                            size: 60,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(26),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.2),
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.4),
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
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Text(
                    'اختر لعبة',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildGameCard(
                          context,
                          title: '',
                          imagePath: 'assets/images/games_card.png',
                          color: Colors.deepPurple,
                          isLocked: !isLudoEnabled,
                          onTap: () => _navigateTo(_ludoScreen),
                        ),
                        _buildGameCard(
                          context,
                          title: '',
                          imagePath: 'assets/images/voice_chat_card.png',
                          color: Colors.pink,
                          isLocked: !isRoomCardEnabled,
                          onTap: () => _navigateTo(_voiceRoomListScreen),
                        ),
                        _buildGameCard(
                          context,
                          title: '',
                          imagePath: 'assets/images/roulette_card.jpg',
                          color: Colors.purple,
                          isLocked: !isRouletteEnabled,
                          onTap: () => _navigateTo(_rouletteScreen),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGameCard(
    BuildContext context, {
    required String title,
    String? imageUrl,
    String? imagePath,
    IconData? icon,
    MaterialColor? color,
    VoidCallback? onTap,
    bool isLocked = false,
  }) {
    return _AnimatedGameCard(
      title: title,
      imageUrl: imageUrl,
      imagePath: imagePath,
      icon: icon,
      color: color,
      onTap: onTap,
      isLocked: isLocked,
    );
  }
}

class _AnimatedGameCard extends StatefulWidget {
  final String title;
  final String? imageUrl;
  final String? imagePath;
  final IconData? icon;
  final MaterialColor? color;
  final VoidCallback? onTap;
  final bool isLocked;

  const _AnimatedGameCard({
    required this.title,
    this.imageUrl,
    this.imagePath,
    this.icon,
    this.color,
    this.onTap,
    this.isLocked = false,
  });

  @override
  State<_AnimatedGameCard> createState() => _AnimatedGameCardState();
}

class _AnimatedGameCardState extends State<_AnimatedGameCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.color ?? Colors.teal;
    final hasImage = widget.imagePath != null || widget.imageUrl != null;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (!widget.isLocked) widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: cardColor.withValues(
                      alpha: _glowAnimation.value * 0.4,
                    ),
                    blurRadius: 25 * _glowAnimation.value,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor.shade700,
                    image: widget.imagePath != null
                        ? DecorationImage(
                            image: AssetImage(widget.imagePath!),
                            fit: BoxFit.cover,
                          )
                        : (widget.imageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(widget.imageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null),
                    gradient: !hasImage
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [cardColor.shade300, cardColor.shade600],
                          )
                        : null,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Content Overlay (Icon/Title)
                      _buildContent(),

                      // Animated Border
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            width: 2,
                            color: Colors.white.withValues(
                              alpha: 0.2 + (_glowAnimation.value * 0.3),
                            ),
                          ),
                        ),
                      ),

                      // Sparkle Effect
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _SparklePainter(
                            animationValue: _glowAnimation.value,
                            color: cardColor,
                          ),
                        ),
                      ),

                      // Lock State
                      if (widget.isLocked)
                        Container(
                          color: Colors.black.withOpacity(0.7),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: const Text(
                                'قريباً',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, size: 48, color: Colors.white),
          ),
        if (widget.title.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black45,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Custom painter for sparkle effects
class _SparklePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _SparklePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3 * animationValue)
      ..style = PaintingStyle.fill;

    // Draw small sparkles at corners
    final sparklePositions = [
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.8, size.height * 0.2),
      Offset(size.width * 0.5, size.height * 0.5),
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.8),
    ];

    for (var i = 0; i < sparklePositions.length; i++) {
      final offset = (animationValue + (i * 0.2)) % 1.0;
      final sparkleSize = 2 + (3 * offset);

      canvas.drawCircle(
        sparklePositions[i],
        sparkleSize,
        paint..color = Colors.white.withValues(alpha: 0.4 * (1 - offset)),
      );
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
