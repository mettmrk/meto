import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'domino_screen.dart';
import '../services/domino_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'store_screen.dart';

class DominoBetSelectionScreen extends StatefulWidget {
  final int playerCount;
  const DominoBetSelectionScreen({Key? key, this.playerCount = 2})
    : super(key: key);

  @override
  State<DominoBetSelectionScreen> createState() =>
      _DominoBetSelectionScreenState();
}

class _DominoBetSelectionScreenState extends State<DominoBetSelectionScreen> {
  int _selectedBet = 500;
  String _selectedMode = 'points'; // 'points' or 'multiplier'

  final List<int> _betTiers = [
    500,
    2000,
    10000,
    50000,
    100000,
    250000,
    1000000,
  ];

  void _increaseBet() {
    int currentIndex = _betTiers.indexOf(_selectedBet);
    if (currentIndex < _betTiers.length - 1) {
      setState(() {
        _selectedBet = _betTiers[currentIndex + 1];
      });
    }
  }

  void _decreaseBet() {
    int currentIndex = _betTiers.indexOf(_selectedBet);
    if (currentIndex > 0) {
      setState(() {
        _selectedBet = _betTiers[currentIndex - 1];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A237E), // Deep Blue
              Color(0xFF006064), // Deep Teal
            ],
          ),
        ),
        child: Stack(
          children: [
            // Stars Background
            const Positioned.fill(
              child: CustomPaint(painter: _StarBackgroundPainter()),
            ),

            // Close Button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Column(
              children: [
                const SizedBox(height: 60),
                // Logo with "2" and Dominoes
                _buildDynamicLogo(),
                const SizedBox(height: 40),

                const SizedBox(height: 20),
                // Heading for Bet Selection
                Text(
                  "اختر الرهان",
                  style: GoogleFonts.tajawal(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                // Bet Selection Section
                _buildSectionBox(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(Icons.remove, _decreaseBet),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatBet(_selectedBet),
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(width: 12),
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Colors.amberAccent, Colors.orangeAccent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: const Icon(
                                  Icons.monetization_on_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildControlButton(Icons.add, _increaseBet),
                    ],
                  ),
                ),

                const Spacer(),

                // Start Button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 40,
                  ),
                  child: GestureDetector(
                    onTap: _joinGame,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD54F), Color(0xFFFBC02D)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "ابدأ",
                        style: GoogleFonts.tajawal(
                          color: const Color(0xFF5D4037),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Right Icon (Speaker/Flower)
            Positioned(
              bottom: 20,
              right: 20,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBet(int value) {
    if (value >= 1000000) {
      return "${(value / 1000000).toStringAsFixed(1)}M";
    } else if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}K";
    }
    return value.toString();
  }

  Widget _buildDynamicLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow behind
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: 20,
              ),
            ],
          ),
        ),
        // Glow effect for the moon/dominoes
        Opacity(
          opacity: 0.6,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Colors.white.withOpacity(0.2), Colors.transparent],
              ),
            ),
          ),
        ),
        // Dominoes Image
        Image.asset(
          'assets/images/domino.png',
          height: 140,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => const SizedBox(height: 100),
        ),
        // Big "2" with 3D Effect
        Text(
          "2",
          style: GoogleFonts.outfit(
            fontSize: 110,
            fontWeight: FontWeight.w900,
            color: const Color.fromARGB(255, 241, 206, 4),
            shadows: [
              // Bright Top Highlight
              Shadow(
                color: Colors.white.withOpacity(0.8),
                offset: const Offset(-2, -2),
                blurRadius: 2,
              ),
              // Main 3D Depth (Extrusion)
              const Shadow(
                color: Color(0xFFB8860B), // Dark Golden Rod
                offset: Offset(2, 2),
                blurRadius: 0,
              ),
              const Shadow(
                color: Color(0xFF996515), // Golden Brown
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
              const Shadow(
                color: Color(0xFF704214), // Sepia
                offset: Offset(6, 6),
                blurRadius: 0,
              ),
              // Final Soft Drop Shadow
              Shadow(
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(8, 8),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionBox({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  Future<void> _joinGame() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.amber)),
    );

    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      String? realName = user?.displayName;
      String? realPhoto = user?.photoURL;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null) {
            // Check balance first
            final int currentCoins = userData['coins'] ?? 0;
            if (currentCoins < _selectedBet) {
              if (mounted) Navigator.pop(context); // Close loading
              if (mounted) {
                _showInsufficientBalanceDialog();
              }
              return;
            }

            realName = userData['nickname'] ?? userData['username'] ?? realName;
            realPhoto = userData['profileImage'] ?? realPhoto;
          }
        }
      }

      final roomId = await DominoService().joinOrCreateRoom(
        betAmount: _selectedBet,
        gameMode: _selectedMode,
        playerCount: widget.playerCount,
        name: realName,
        photo: realPhoto,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DominoScreen(
            betAmount: _selectedBet,
            gameMode: _selectedMode,
            playerCount: widget.playerCount,
            roomId: roomId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "خطأ في الاتصال: $e\nتأكد من إعداد قواعد Firebase Database (Read/Write) لمسار 'domino_rooms'.",
            style: const TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A237E), Color(0xFF006064)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white24, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with Glow
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.amberAccent, Colors.orangeAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.monetization_on_rounded,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "عذراً! رصيدك غير كافٍ",
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "أنت بحاجة إلى ${_selectedBet} عملة للمشاركة في هذا الرهان. قم بزيارة المتجر للحصول على المزيد من العملات.",
                style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        if (uid != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  StoreScreen(userId: uid, initialTab: 2),
                            ), // Tab 2 is for Gold/Coins
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD54F), Color(0xFFFBC02D)],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "اشحن الآن",
                          style: GoogleFonts.tajawal(
                            color: const Color(0xFF5D4037),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "لاحقاً",
                  style: GoogleFonts.tajawal(
                    color: Colors.white54,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFBC02D)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _StarBackgroundPainter extends CustomPainter {
  const _StarBackgroundPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.4);
    final random = Random(42);
    for (int i = 0; i < 80; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.2;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
