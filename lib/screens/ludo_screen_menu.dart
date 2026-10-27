// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api
part of 'ludo_screen.dart';

class JaggedBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 15);

    // Create a more irregular jagged bottom
    double x = 0;
    final random = Random(42);
    while (x < size.width) {
      double nextX = x + 10 + random.nextDouble() * 10;
      if (nextX > size.width) nextX = size.width;

      double y = size.height - (random.nextDouble() * 15);
      path.lineTo(nextX, y);
      x = nextX;
    }

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Main menu and mode selection screen methods.
extension LudoScreenMenu on _LudoScreenState {
  BoxDecoration _buildScreenDecoration() {
    return const BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/images/ludo_purple_bg.png'),
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildMainMenu() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        width: double.infinity,
        height: double.infinity,
        decoration: _buildScreenDecoration(),
        child: Stack(
          children: [
            // Luxury Atmospheric Background (Overlay for depth)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3)),
              ),
            ),
            // Subtle Particle/Glow Layer
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: RepaintBoundary(
                  child: CustomPaint(painter: StarBackgroundPainter()),
                ),
              ),
            ),
            // Central Soft Glow
            Center(
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF148E60).withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: SafeArea(
                child: Column(
                  children: [
                    // ── Glassmorphic Header ─────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTopActions(),
                              const SizedBox(width: 12),
                              _buildCurrencyBar(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Main Content (PageView) ────────────────────────────────
                    Expanded(
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: _settingsStream,
                        builder: (context, snapshot) {
                          final data =
                              snapshot.data?.data() as Map<String, dynamic>? ??
                              {};

                          final bool isDominoEnabled =
                              data['isDominoEnabled'] ?? true;
                          final bool isOtherGamesEnabled =
                              data['isOtherGamesEnabled'] ?? true;

                          return PageView(
                            controller: _gamePageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentGamePageIndex = index;
                              });
                            },
                            children: [
                              _buildGameMenuPage(
                                title: "",
                                showLogo: true,
                                content: _buildLudoMetoContent(),
                              ),

                              _buildGameMenuPage(
                                title: "",
                                content: isDominoEnabled
                                    ? _buildDominoContent()
                                    : _buildLockedContent('دومينو'),
                              ),
                              _buildGameMenuPage(
                                title: "",
                                content: isOtherGamesEnabled
                                    ? _buildComingTawlaa()
                                    : _buildLockedContent('ألعاب أخرى'),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // ── Bottom Navigation Bar ──────────────────────────────────
                    _buildBottomNavigationBar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.black26,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        constraints: const BoxConstraints(),
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 22),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildGameMenuPage({
    required String title,
    required Widget content,
    bool showLogo = false,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            if (showLogo) _buildLudoLogoWithMoon(),
            if (title.trim().isNotEmpty) ...[
              const SizedBox(height: 0),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Tajawal',
                  letterSpacing: 1.2,
                  shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 10)],
                ),
              ),
            ],
            const SizedBox(height: 0),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildLudoLogoWithMoon() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 3D Rendered Platform Effect
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(1.1),
            alignment: Alignment.center,
            child: Container(
              width: 180, // Unified with Jackaroo
              height: 180, // Unified with Jackaroo
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFF148E60), const Color(0xFF03140C)],
                ),
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: const Color(0xFF148E60).withOpacity(0.2),
                    blurRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          // Minimalist Logo Floating above
          Positioned(
            bottom: 20, // Adjusted to 10
            child: Hero(
              tag: 'ludo_logo',
              child: Image.asset(
                'assets/images/ludoo.png',
                height: 120, // Unified to 120
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => Text(
                  'LUDO',
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(0, 6),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLudoMetoContent() {
    return Column(
      children: [
        Row(
          children: [
            // تكوين فريق
            Expanded(
              child: _buildLudoModeCard(
                title: 'تكوين فريق',
                colors: const [Color(0xFF9E77ED), Color(0xFF7F56D9)],
                fullImagePath: 'assets/images/gams/tkwen.png',
                icon: Icons.groups_rounded,
                height: 115, // Reduced from 120
                titleFontSize: 14,
                onTap: () {
                  setState(() => _uiState = LudoUiState.teamUpSelection);
                },
              ),
            ),
            const SizedBox(width: 14),
            // 2 و 4 لاعبين
            Expanded(
              child: _buildLudoModeCard(
                title: '2 و 4 لاعبين',
                colors: const [Color(0xFFFFC107), Color(0xFFFF8F00)],
                fullImagePath: 'assets/images/gams/2or4.png',
                icon: Icons.casino_rounded,
                height: 115, // Reduced from 110
                titleFontSize: 14,
                onTap: () {
                  setState(() => _uiState = LudoUiState.twoFourSelection);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            // طاولة خاصة & بدون الإنترنت
            Expanded(
              child: _buildLudoModeCard(
                title: 'طاولة خاصة\n& بدون الإنترنت',
                colors: const [Color(0xFF29B6F6), Color(0xFF0277BD)],
                fullImagePath: 'assets/images/gams/kass.png',
                icon: Icons.phonelink_off_rounded,
                height: 105,
                titleFontSize: 12,
                onTap: () {
                  setState(() => _uiState = LudoUiState.privateTableSelection);
                },
              ),
            ),
            const SizedBox(width: 15),
            //Placeholder for alignment or another card
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildComingTawlaa() {
    return Column(
      children: [
        _buildOthers3DLogo(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final bool wasPlaying = _musicPlayer.playing;
                  if (wasPlaying) await _musicPlayer.pause();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BackgammonScreen(),
                    ),
                  );
                  if (wasPlaying && !_isMuted && mounted) _musicPlayer.play();
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The 3D Depth Layer
                    Positioned(
                      top: 4,
                      left: 0,
                      right: 0,
                      bottom: -6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF7B1FA2).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              offset: const Offset(0, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // The main card surface
                    Container(
                      height: 115,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9E77ED),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/tawle.jpg',
                          width: double.infinity,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final bool wasPlaying = _musicPlayer.playing;
                  if (wasPlaying) await _musicPlayer.pause();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BombHuntScreen(),
                    ),
                  );
                  if (wasPlaying && !_isMuted && mounted) _musicPlayer.play();
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The 3D Depth Layer
                    Positioned(
                      top: 4,
                      left: 0,
                      right: 0,
                      bottom: -6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              offset: const Offset(0, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // The main card surface
                    Container(
                      height: 115,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/boom.jpg',
                          width: double.infinity,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final bool wasPlaying = _musicPlayer.playing;
                  if (wasPlaying) await _musicPlayer.pause();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SnakesAndLaddersScreen(),
                    ),
                  );
                  if (wasPlaying && !_isMuted && mounted) _musicPlayer.play();
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The 3D Depth Layer
                    Positioned(
                      top: 4,
                      left: 0,
                      right: 0,
                      bottom: -6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFC62828).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              offset: const Offset(0, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // The main card surface
                    Container(
                      height: 115,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF5350),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/snack.png',
                          width: double.infinity,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // Ludo X selection or start logic
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The 3D Depth Layer
                    Positioned(
                      top: 4,
                      left: 0,
                      right: 0,
                      bottom: -6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              offset: const Offset(0, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // The main card surface
                    Container(
                      height: 115,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB74D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/loxx.png',
                          width: double.infinity,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final bool wasPlaying = _musicPlayer.playing;
                  if (wasPlaying) await _musicPlayer.pause();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CarZigzagScreen(),
                    ),
                  );
                  if (wasPlaying && !_isMuted && mounted) _musicPlayer.play();
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The 3D Depth Layer
                    Positioned(
                      top: 4,
                      left: 0,
                      right: 0,
                      bottom: -6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B5E20).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              offset: const Offset(0, 4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // The main card surface
                    Container(
                      height: 115,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF66BB6A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/zkzk.png',
                          width: double.infinity,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final bool wasPlaying = _musicPlayer.playing;
                  if (wasPlaying) await _musicPlayer.pause();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuizGameScreen(),
                    ),
                  );
                  if (wasPlaying && !_isMuted && mounted) _musicPlayer.play();
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The 3D Depth Layer
                    Positioned(
                      top: 4, left: 0, right: 0, bottom: -6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF6A1B9A).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), offset: const Offset(0, 4), blurRadius: 8)],
                        ),
                      ),
                    ),
                    // The main card surface
                    Container(
                      height: 115,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFAB47BC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          color: const Color(0xFF8E24AA),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.quiz_rounded, color: Colors.white, size: 40),
                                SizedBox(height: 4),
                                Text('مسابقة ثقافية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Tajawal', fontSize: 13, shadows: [Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2)])),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final bool wasPlaying = _musicPlayer.playing;
                  if (wasPlaying) await _musicPlayer.pause();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ShutTheBoxLobbyScreen(),
                    ),
                  );
                  if (wasPlaying && !_isMuted && mounted) _musicPlayer.play();
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The 3D Depth Layer
                    Positioned(
                      top: 4, left: 0, right: 0, bottom: -6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), offset: const Offset(0, 4), blurRadius: 8)],
                        ),
                      ),
                    ),
                    // The main card surface
                    Container(
                      height: 115,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF42A5F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/kloosbx.png',
                          width: double.infinity,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            // Placeholder for alignment
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildLockedContent(String gameName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_clock_rounded, size: 100, color: Colors.amber),
          const SizedBox(height: 20),
          Text(
            'لعبة $gameName قريباً',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Tajawal',
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'هذه اللعبة مغلقة حالياً من قبل الإدارة',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
              fontFamily: 'Tajawal',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOthers3DLogo() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 3D Rendered Platform Effect
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(1.1),
            alignment: Alignment.center,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFF148E60), const Color(0xFF03140C)],
                ),
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: const Color(0xFF148E60).withOpacity(0.2),
                    blurRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          // 3D Logo Floating above
          Positioned(
            bottom: 10,
            child: Hero(
              tag: 'others_logo',
              child: Image.asset(
                'assets/images/others.png',
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => Text(
                  'OTHERS',
                  style: GoogleFonts.outfit(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(0, 6),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomino3DLogo() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 3D Rendered Platform Effect
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(1.1),
            alignment: Alignment.center,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFF148E60), const Color(0xFF03140C)],
                ),
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: const Color(0xFF148E60).withOpacity(0.2),
                    blurRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          // 3D Logo Floating above
          Positioned(
            bottom: 10,
            child: Hero(
              tag: 'domino_logo',
              child: Image.asset(
                'assets/images/domi.png',
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => Text(
                  'DOMINO',
                  style: GoogleFonts.outfit(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(0, 6),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDominoContent() {
    return Column(
      children: [
        _buildDomino3DLogo(),
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: () async {
              final bool wasPlaying = _musicPlayer.playing;
              if (wasPlaying) await _musicPlayer.pause();

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const DominoBetSelectionScreen(playerCount: 2),
                ),
              );

              if (wasPlaying && !_isMuted && mounted) {
                _musicPlayer.play().catchError(
                  (e) => debugPrint('Play error: $e'),
                );
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  bottom: -6,
                  child: Container(
                    width: 200, // Fixed width for centering
                    decoration: BoxDecoration(
                      color: const Color(0xFF004D40).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 200, // Fixed width for centering
                  height: 140,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/images/1a1.png',
                      fit: BoxFit.fill,
                      errorBuilder: (c, e, s) => Container(
                        color: Colors.teal,
                        child: const Center(
                          child: Text(
                            "١ مقابل ١",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDominoSelectionScreen() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: _buildScreenDecoration(),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: StarBackgroundPainter()),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        _buildSelectionCircularButton(
                          icon: Icons.close,
                          color: const Color(0xFFD32F2F),
                          onTap: _backToMenu,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Text(
                      "١ مقابل ١",
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // Game mode selection removed per user request
                          _buildSelectionPanel(
                            title: "الرهان",
                            showHelp: false,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildBetControlButton(Icons.add, () {
                                      final tiers = [
                                        500,
                                        2000,
                                        10000,
                                        50000,
                                        100000,
                                        250000,
                                        1000000,
                                      ];
                                      int currentIndex = tiers.indexOf(
                                        _dominoBet,
                                      );
                                      if (currentIndex != -1 &&
                                          currentIndex < tiers.length - 1) {
                                        setState(
                                          () => _dominoBet =
                                              tiers[currentIndex + 1],
                                        );
                                      }
                                    }),
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white12,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            _formatCurrency(_dominoBet),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const GoldCoin(size: 26),
                                        ],
                                      ),
                                    ),
                                    _buildBetControlButton(Icons.remove, () {
                                      final tiers = [
                                        500,
                                        2000,
                                        10000,
                                        50000,
                                        100000,
                                        250000,
                                        1000000,
                                      ];
                                      int currentIndex = tiers.indexOf(
                                        _dominoBet,
                                      );
                                      if (currentIndex != -1 &&
                                          currentIndex > 0) {
                                        setState(
                                          () => _dominoBet =
                                              tiers[currentIndex - 1],
                                        );
                                      }
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.help_outline,
                                      color: Colors.white.withOpacity(0.5),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "الخبرة ${_getBetXpPercent(_dominoBet)}%",
                                      style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    child: _buildStartDominoButton(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartDominoButton() {
    return GestureDetector(
      onTap: () {
        _startDominoGame(
          betAmount: _dominoBet,
          mode: _dominoMode,
          playerCount: _dominoPlayersCount,
        );
      },
      child: Container(
        width: double.infinity,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFF9A825)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        ),
        child: const Text(
          "ابدأ",
          style: TextStyle(
            color: Color(0xFF4E342E),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            fontFamily: 'Tajawal',
          ),
        ),
      ),
    );
  }

  Future<void> _startDominoGame({
    required int betAmount,
    required String mode,
    required int playerCount,
  }) async {
    // Robust balance check
    if (_userCoins < betAmount) {
      final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
      if (myUid != null) {
        try {
          final freshUser = await UserService().getUser(myUid);
          if (freshUser != null) {
            _userCoins = freshUser.coins;
          }
        } catch (e) {
          debugPrint('[DominoBalance] Error fetching fresh balance: $e');
        }
      }
    }

    if (_userCoins < betAmount) {
      _showInsufficientFundsDialog();
      return;
    }

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.amber)),
    );

    try {
      // Note: Deduction removed from here as per user request.
      // It will happen in DominoScreen when the game actually starts.

      String roomId = await DominoService().joinOrCreateRoom(
        betAmount: betAmount,
        gameMode: mode,
        playerCount: playerCount,
        name: _userName,
        photo: _userProfileImage,
      );

      Navigator.pop(context); // Remove loading indicator
      final bool wasPlaying = _musicPlayer.playing;
      if (wasPlaying) await _musicPlayer.pause();

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DominoScreen(
            betAmount: betAmount,
            gameMode: mode,
            playerCount: playerCount,
            roomId: roomId,
          ),
        ),
      );

      if (wasPlaying && !_isMuted && mounted) {
        _musicPlayer.play().catchError((e) => debugPrint('Play error: $e'));
      }
    } catch (e) {
      Navigator.pop(context); // Remove loading indicator
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في الانضمام: $e')));
    }
  }

  Widget _buildLudoModeCard({
    required String title,
    required List<Color> colors,
    IconData? icon,
    String? fullImagePath,
    required double height,
    String? centerText,
    bool showShine = false,
    double titleFontSize = 18,
    Color textColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The 3D Depth Layer
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            bottom: -6,
            child: Container(
              decoration: BoxDecoration(
                color: colors.last.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          // The main card surface
          Container(
            height: height,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: colors.first,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                // Soft colored glow shadow
                BoxShadow(
                  color: colors.last.withOpacity(0.3),
                  offset: const Offset(0, 10),
                  blurRadius: 15,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.first.withOpacity(0.95), colors.last],
                  ),
                ),
                child: fullImagePath != null
                    ? Image.asset(
                        fullImagePath,
                        fit: BoxFit.fill,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Stack(
                        children: [
                          // Top inner highlight
                          Positioned(
                            top: 0,
                            left: 2,
                            right: 2,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          // Glossy top overlay
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: height * 0.45,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.12),
                                    Colors.white.withOpacity(0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Subtle pattern overlay
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.08,
                              child: CustomPaint(
                                painter: RhombusPainter(color: Colors.black),
                              ),
                            ),
                          ),
                          // Center icon or text decoration
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 30),
                              child: icon != null
                                  ? Icon(
                                      icon,
                                      size: height * 0.35,
                                      color: Colors.white.withOpacity(0.15),
                                    )
                                  : Text(
                                      centerText ?? "",
                                      style: TextStyle(
                                        fontSize: height * 0.4,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white.withOpacity(0.1),
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                            ),
                          ),
                          // Bottom title
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Tajawal',
                                  height: 1.1,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (showShine)
                            const _ShineEffectWrapper(child: SizedBox.expand()),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetSelectionScreen() {
    final bets = [50, 100, 300, 700, 1000];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: _buildScreenDecoration(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _backToMenu,
                    ),
                    const Expanded(
                      child: Text(
                        'اختر مبلغ الرهان',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bets.length,
                  itemBuilder: (context, index) {
                    final bet = bets[index];
                    return Card(
                      color: Colors.white.withOpacity(0.1),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const GoldCoin(size: 26),
                        title: Text(
                          '$bet كوينز',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedBet = bet;
                            _uiState = _isPrivateFlow
                                ? LudoUiState.friendInvitation
                                : LudoUiState.matchmaking;
                          });
                          _startOnlineGame(
                            maxPlayers: _currentMatchMaxPlayers,
                            mode: _isPrivateFlow
                                ? _privateTableMode
                                : _currentMatchMode,
                            isPrivate: _isPrivateFlow,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTwoFourSelectionScreen() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: _buildScreenDecoration(),
        child: Stack(
          children: [
            // Background Stars
            Positioned.fill(
              child: CustomPaint(painter: StarBackgroundPainter()),
            ),

            SafeArea(
              child: Column(
                children: [
                  // ── Top Bar ───────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        _buildSelectionCircularButton(
                          icon: Icons.close,
                          color: const Color(0xFFD32F2F),
                          onTap: _backToMenu,
                        ),
                      ],
                    ),
                  ),

                  // ── Player Selection ───────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPlayerCountTab(
                          4,
                          "4 لاعبين",
                          'assets/images/ludoo.png',
                        ),
                        const SizedBox(width: 32),
                        _buildPlayerCountTab(
                          2,
                          "1 مقابل 1",
                          'assets/images/ludoo.png',
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // ── Pattern Selection ──────────────────────────────
                          _buildSelectionPanel(
                            title: "حدد النمط",
                            showHelp: true,
                            child: GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 3.4,
                              children: [
                                _buildTwoFourModeButton(
                                  "الكلاسيكي",
                                  "classic",
                                  Icons.check,
                                ),
                                _buildTwoFourModeButton(
                                  "السهم",
                                  "arrow",
                                  Icons.check,
                                  isHot: true,
                                ),
                                _buildTwoFourModeButton(
                                  "الماستر",
                                  "master",
                                  Icons.check,
                                ),
                                _buildTwoFourModeButton(
                                  "السريع",
                                  "fast",
                                  Icons.check,
                                ),
                              ],
                            ),
                          ),

                          // ── Magic Tools ────────────────────────────────────
                          _buildSelectionPanel(
                            title: "أدوات سحرية",
                            showHelp: true,
                            child: Row(
                              children: [
                                Image.asset(
                                  'assets/images/dice/3d/1.png',
                                  width: 44,
                                  height: 44,
                                  errorBuilder: (c, e, s) => const Icon(
                                    Icons.casino,
                                    color: Colors.amber,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  "أدوات سحرية",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: _magicToolsEnabled,
                                  onChanged: (val) =>
                                      setState(() => _magicToolsEnabled = val),
                                  activeColor: Colors.amber,
                                  activeTrackColor: Colors.amber.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Betting Panel ──────────────────────────────────
                          _buildSelectionPanel(
                            title: "الرهان",
                            showHelp: false,
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildBetControlButton(Icons.add, () {
                                      final tiers = [
                                        500,
                                        2000,
                                        10000,
                                        50000,
                                        100000,
                                        250000,
                                        1000000,
                                      ];
                                      int currentIndex = tiers.indexOf(
                                        _twoFourBet,
                                      );
                                      if (currentIndex != -1 &&
                                          currentIndex < tiers.length - 1) {
                                        setState(
                                          () => _twoFourBet =
                                              tiers[currentIndex + 1],
                                        );
                                      }
                                    }),
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white12,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            _formatCurrency(_twoFourBet),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const GoldCoin(size: 26),
                                        ],
                                      ),
                                    ),
                                    _buildBetControlButton(Icons.remove, () {
                                      final tiers = [
                                        500,
                                        2000,
                                        10000,
                                        50000,
                                        100000,
                                        250000,
                                        1000000,
                                      ];
                                      int currentIndex = tiers.indexOf(
                                        _twoFourBet,
                                      );
                                      if (currentIndex != -1 &&
                                          currentIndex > 0) {
                                        setState(
                                          () => _twoFourBet =
                                              tiers[currentIndex - 1],
                                        );
                                      }
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Exp Bonus
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.help_outline,
                                      color: Colors.white.withOpacity(0.5),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "الخبرة ${_getBetXpPercent(_twoFourBet)}%",
                                      style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),

                  // ── Start Game Button ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    child: _buildStartGameButton(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartGameButton() {
    return GestureDetector(
      onTap: () {
        _startOnlineGame(
          mode: _twoFourMode,
          maxPlayers: _twoFourPlayersCount,
          betAmount: _twoFourBet,
          isPrivate: false,
          isTeamMode: false,
        );
      },
      child: Container(
        width: double.infinity,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFF9A825)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        ),
        child: const Text(
          "ابدأ",
          style: TextStyle(
            color: Color(0xFF4E342E), // Dark brown/black for contrast
            fontSize: 24,
            fontWeight: FontWeight.w900,
            fontFamily: 'Tajawal',
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCountTab(int count, String label, String imageAsset) {
    bool isSelected = _twoFourPlayersCount == count;
    return GestureDetector(
      onTap: () => setState(() => _twoFourPlayersCount = count),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Background Glow for selection
          if (isSelected)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),

          Container(
            width: 110,
            height: 90,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF0288D1).withOpacity(0.8)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isSelected ? Colors.cyanAccent : Colors.white12,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      imageAsset,
                      width: 50,
                      height: 50,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.casino,
                        color: Colors.amber,
                        size: 40,
                      ),
                    ),
                    Text(
                      '$count',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          const Shadow(
                            color: Colors.black,
                            blurRadius: 10,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          ),

          // Selector Pointer Arrow
          if (isSelected)
            const Positioned(
              bottom: -10,
              child: Icon(
                Icons.arrow_drop_up,
                color: Colors.cyanAccent,
                size: 30,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTwoFourModeButton(
    String label,
    String value,
    IconData? icon, {
    bool isHot = false,
  }) {
    bool isSelected = _twoFourMode == value;
    return GestureDetector(
      onTap: () => setState(() => _twoFourMode = value),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                    )
                  : const LinearGradient(
                      colors: [Colors.white10, Colors.white12],
                    ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isSelected ? Colors.cyanAccent : Colors.white12,
                width: 2,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
          if (isSelected && icon != null)
            const Positioned(
              left: 4,
              top: 4,
              child: Icon(Icons.check, color: Colors.amber, size: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamUpSelectionScreen() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: _buildScreenDecoration(),
        child: Stack(
          children: [
            // Background Stars/Glow
            Positioned.fill(
              child: CustomPaint(painter: StarBackgroundPainter()),
            ),

            SafeArea(
              child: Column(
                children: [
                  // ── Top Bar ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSelectionCircularButton(
                          icon: Icons.close,
                          color: const Color(0xFFE57373),
                          onTap: _backToMenu,
                        ),
                        _buildSelectionCircularButton(
                          icon: Icons.description_outlined,
                          color: const Color(0xFF64B5F6),
                          onTap: () {
                            // Show game rules
                          },
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          // ── VS Graphic ─────────────────────────────────────
                          _buildVSGraphic(),

                          // ── Mode Selection Panel ───────────────────────────
                          _buildSelectionPanel(
                            title: "حدد النمط",
                            showHelp: true,
                            child: GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 3.5,
                              children: [
                                _buildModeButton(
                                  "الكلاسيكي",
                                  "classic",
                                  Icons.check,
                                ),
                                _buildModeButton(
                                  "السهم",
                                  "arrow",
                                  Icons.check,

                                  isHot: true,
                                ),
                                _buildModeButton(
                                  "الماستر",
                                  "master",
                                  Icons.check,
                                ),
                                _buildModeButton("السريع", "fast", Icons.check),
                              ],
                            ),
                          ),

                          // ── Magic Tools Panel ──────────────────────────────
                          _buildSelectionPanel(
                            title: "أدوات سحرية",
                            showHelp: true,
                            child: Row(
                              children: [
                                Image.asset(
                                  'assets/images/dice/3d/1.png',
                                  width: 32,
                                  height: 32,
                                  errorBuilder: (c, e, s) => const Icon(
                                    Icons.casino,
                                    color: Colors.amber,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "أدوات سحرية",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: _magicToolsEnabled,
                                  onChanged: (val) =>
                                      setState(() => _magicToolsEnabled = val),
                                  activeColor: Colors.amber,
                                  activeTrackColor: Colors.amber.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Bet Selection Panel ────────────────────────────
                          _buildSelectionPanel(
                            title: "مبلغ الرهان",
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildBetControlButton(Icons.add, () {
                                      final tiers = [
                                        500,
                                        2000,
                                        10000,
                                        50000,
                                        100000,
                                        250000,
                                        1000000,
                                      ];
                                      int currentIndex = tiers.indexOf(
                                        _teamUpBet,
                                      );
                                      if (currentIndex != -1 &&
                                          currentIndex < tiers.length - 1) {
                                        setState(
                                          () => _teamUpBet =
                                              tiers[currentIndex + 1],
                                        );
                                      } else if (currentIndex == -1) {
                                        setState(() => _teamUpBet = tiers[0]);
                                      }
                                    }),
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 15,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            _formatCurrency(_teamUpBet),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const GoldCoin(size: 22),
                                        ],
                                      ),
                                    ),
                                    _buildBetControlButton(Icons.remove, () {
                                      final tiers = [
                                        500,
                                        2000,
                                        10000,
                                        50000,
                                        100000,
                                        250000,
                                        1000000,
                                      ];
                                      int currentIndex = tiers.indexOf(
                                        _teamUpBet,
                                      );
                                      if (currentIndex != -1 &&
                                          currentIndex > 0) {
                                        setState(
                                          () => _teamUpBet =
                                              tiers[currentIndex - 1],
                                        );
                                      }
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildSelectionCircularButton(
                                      icon: Icons.help_outline,
                                      size: 16,
                                      iconSize: 12,
                                      color: Colors.white38,
                                      onTap: () {},
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "الخبرة ${_getBetXpPercent(_teamUpBet)}%",
                                      style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ── Action Buttons ─────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildBigActionButton(
                                    "إنشاء",
                                    const [
                                      Color(0xFFFFA000),
                                      Color(0xFFFF6F00),
                                    ],
                                    () {
                                      _startOnlineGame(
                                        mode: _teamUpMode,
                                        maxPlayers: 4,
                                        betAmount: _teamUpBet,
                                        isPrivate: true,
                                        isTeamMode: true,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildBigActionButton(
                                    "فردي",
                                    const [
                                      Color(0xFFFFD54F),
                                      Color(0xFFFBC02D),
                                    ],
                                    () {
                                      _startOnlineGame(
                                        mode: _teamUpMode,
                                        maxPlayers: 4,
                                        betAmount: _teamUpBet,
                                        isPrivate: false,
                                        isTeamMode: true,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildVSGraphic() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Image.asset(
        'assets/images/ludoo.png',
        height: 120,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) =>
            const Icon(Icons.casino, size: 100, color: Colors.amber),
      ),
    );
  }

  Widget _buildSelectionPanel({
    required String title,
    required Widget child,
    bool showHelp = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F).withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showHelp)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.help_outline,
                    color: Colors.white.withOpacity(0.5),
                    size: 20,
                  ),
                ),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildModeButton(
    String label,
    String value,
    IconData? icon, {
    bool isHot = false,
  }) {
    bool isSelected = _teamUpMode == value;
    return GestureDetector(
      onTap: () => setState(() => _teamUpMode = value),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white10,
                        Colors.white10.withOpacity(0.05),
                      ],
                    ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.cyanAccent : Colors.white12,
                width: 2,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
          if (isSelected && icon != null)
            Positioned(
              left: 4,
              top: 4,
              child: Icon(icon, color: Colors.orange, size: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildBetControlButton(IconData icon, VoidCallback onTap) {
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

  Widget _buildBigActionButton(
    String label,
    List<Color> colors,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 55,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: colors[1].withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        ),
      ),
    );
  }

  /// Returns the XP experience percentage for a given bet amount.
  /// Scales logarithmically from 10% (at 500 coins) to 400% (at 1,000,000 coins).
  int _getBetXpPercent(int bet) {
    const Map<int, int> xpMap = {
      500: 10,
      2000: 50,
      10000: 100,
      50000: 175,
      100000: 230,
      250000: 310,
      1000000: 400,
    };
    // Return exact match if found
    if (xpMap.containsKey(bet)) return xpMap[bet]!;
    // Clamp to bounds
    if (bet <= 500) return 10;
    if (bet >= 1000000) return 400;
    // Logarithmic interpolation for any value between tiers
    final double logBet = (bet / 500).toDouble();
    final double logMax = (1000000 / 500).toDouble();
    final double ratio = (logBet > 0 && logMax > 0)
        ? (logBet.toString().length / logMax.toString().length)
        : 0;
    return (10 + (390 * ratio)).round().clamp(10, 400);
  }

  Widget _buildSelectionCircularButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 40,
    double iconSize = 24,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }

  Widget _buildPrivateTableSelectionScreen() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: _buildScreenDecoration(),
        child: Stack(
          children: [
            // 1. Stars & Atmosphere
            Positioned.fill(
              child: CustomPaint(painter: StarBackgroundPainter()),
            ),

            // 2. Crescent Moon Background Element
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: 0.2,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 250,
                        height: 250,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white70,
                        ),
                      ),
                      Positioned(
                        left: 40,
                        top: 0,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF0F0C29), // Same as bg
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // 3. Close Button (Hexagonal Badge)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: GestureDetector(
                          onTap: _backToMenu,
                          child: _buildHexagonCloseButton(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 4. Main Toggle Cards (Offline vs Private Table)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildCreationModeToggle(
                              title: 'بدون إنترنت',
                              isSelected: _isOfflineMode,
                              icon: Icons.phonelink_off_rounded,
                              onTap: () =>
                                  setState(() => _isOfflineMode = true),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildCreationModeToggle(
                              title: 'طاولة خاصة',
                              isSelected: !_isOfflineMode,
                              icon: Icons.groups_rounded,
                              onTap: () =>
                                  setState(() => _isOfflineMode = false),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // 5. Mode Selection Section
                    _buildPrivateSettingsBox(
                      title: 'حدد النمط',
                      content: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildGameModeButton(
                                  'الكلاسيكي',
                                  'classic',
                                  _privateTableMode == 'classic',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildGameModeButton(
                                  'السهم',
                                  'arrow',
                                  _privateTableMode == 'arrow',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildGameModeButton(
                                  'السريع',
                                  'quick',
                                  _privateTableMode == 'quick',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildGameModeButton(
                                  'الماستر',
                                  'master',
                                  _privateTableMode == 'master',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    // 6. Magic Tools Section
                    _buildPrivateSettingsBox(
                      title: 'أدوات سحرية',
                      showDice: true,
                      content: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () => setState(
                              () => _magicToolsEnabled = !_magicToolsEnabled,
                            ),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: _magicToolsEnabled
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.cyanAccent,
                                      size: 20,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),
                    const Text(
                      'لا توجد عملات دخول وخبرات في هذا الوضع',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontFamily: 'Tajawal',
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 7. Action Buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: _buildPremiumCreationButton('إنشاء', () {
                        if (_isOfflineMode) {
                          _startOfflineGame();
                        } else {
                          // Direct creation for Online Private Table
                          _startOnlineGame(
                            mode: _privateTableMode,
                            maxPlayers: 4,
                            betAmount: 0, // No coins in this mode as per text
                            isPrivate: true,
                          );
                        }
                      }),
                    ),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 20,
                        left: 20,
                        right: 20,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSmallJoinButton(),
                          const Text(
                            'انضم إلى غرفة صديقك',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHexagonCloseButton() {
    return Container(
      width: 48,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFE53935), // Red
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFFD54F),
          width: 2,
        ), // Yellow border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.close,
        color: Colors.white,
        size: 24,
        weight: 1000,
      ),
    );
  }

  Widget _buildCreationModeToggle({
    required String title,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 85,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade600 : Colors.black26,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.white12,
            width: 2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white38,
              size: 30,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateSettingsBox({
    required String title,
    required Widget content,
    bool showDice = false,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.help_outline, color: Colors.white54, size: 20),
              Row(
                children: [
                  if (showDice) ...[
                    const Icon(Icons.casino, color: Colors.amber, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildGameModeButton(String label, String value, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _privateTableMode = value),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF29B6F6), Color(0xFF0277BD)],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Tajawal',
              ),
            ),
            if (isSelected)
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCreationButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.brown,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallJoinButton() {
    return GestureDetector(
      onTap: _showJoinRoomDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'انضم',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        ),
      ),
    );
  }

  void _showJoinRoomDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1C3C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(
          "انضمام لغرفة",
          style: GoogleFonts.tajawal(
            color: const Color(0xFFFFD700),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "أدخل رمز الغرفة المكون من 6 أرقام",
              style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: "",
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: Colors.cyanAccent,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    "إلغاء",
                    style: GoogleFonts.tajawal(color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final code = controller.text.trim();
                    if (code.length == 6) {
                      Navigator.pop(ctx);
                      _startOnlineGame(roomId: code, isPrivate: true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("يرجى إدخال 6 أرقام")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    "انضمام",
                    style: GoogleFonts.tajawal(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDominoPrivateSelectionScreen() {
    return _buildSelectionScreen(
      title: 'طاولة دومينو خاصة',
      options: [
        {'label': 'طاولة خاصة', 'value': 'create'},
        {'label': 'مع الكمبيوتر', 'value': 'computer'},
      ],
      onSelect: (val) async {
        final bool wasPlaying = _musicPlayer.playing;
        if (wasPlaying) await _musicPlayer.pause();

        if (val == 'computer') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DominoScreen(
                betAmount: 0,
                playerCount: 2,
                roomId: null,
              ),
            ),
          );
        } else {
          // Go to bet selection for online private table
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const DominoBetSelectionScreen(playerCount: 2),
            ),
          );
        }

        if (wasPlaying && !_isMuted && mounted) {
          _musicPlayer.play().catchError((e) => debugPrint('Play error: $e'));
        }
      },
    );
  }

  Widget _buildSelectionScreen({
    required String title,
    required List<Map<String, dynamic>> options,
    required Function(dynamic) onSelect,
  }) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: _buildScreenDecoration(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _backToMenu,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: options.map((opt) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 10,
                        ),
                        child: _buildYellowButton(
                          opt['label'],
                          () => onSelect(opt['value']),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendInvitationScreen() {
    final String lobbyTitle = _isTeamMode ? 'تكوين فريق' : 'طاولة خاصة';
    final String lobbyDesc = _isTeamMode
        ? 'ادعُ صديقاً ليكون شريكك في الفريق للمنافسة'
        : 'شارك رقم هذه الغرفة مع الأصدقاء وقم بدعوتهم';

    final shortCode = (_roomId != null && _roomId!.length >= 6)
        ? _roomId!.substring(_roomId!.length - 6).toUpperCase()
        : '......';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: _buildScreenDecoration(),
        child: Stack(
          children: [
            // Stars
            Positioned.fill(
              child: CustomPaint(painter: StarBackgroundPainter()),
            ),

            // Large Moon behind the title
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.05),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    ClipPath(
                      clipper: CrescentClipper(),
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              Colors.white.withOpacity(0.8),
                              Colors.white.withOpacity(0.2),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Close Button
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: GestureDetector(
                        onTap: _backToMenu,
                        child: _buildHexagonCloseButton(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Title
                  Text(
                    lobbyTitle,
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFFFFEB3B),
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        const Shadow(
                          color: Colors.black54,
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                        const Shadow(
                          color: Colors.orangeAccent,
                          offset: Offset(0, 0),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Room ID (only for private table)
                  if (!_isTeamMode)
                    Text(
                      'رقم الغرفة: $shortCode',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Instruction Text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      lobbyDesc,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Player Slots
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _isTeamMode
                            ? [
                                // Team Up Mode: Only 2 slots (Host + Partner)
                                _buildInvitationPlayerSlot(
                                  pIdx: 0,
                                  uid: _onlinePlayerUids[0],
                                  name: _onlinePlayerNames[0],
                                  photo: _onlinePlayerImages[0],
                                ),
                                const SizedBox(width: 40),
                                _buildInvitationPlayerSlot(
                                  pIdx: 2, // Partner color (Yellow)
                                  uid: _onlinePlayerUids[2],
                                  name: _onlinePlayerNames[2],
                                  photo: _onlinePlayerImages[2],
                                ),
                              ]
                            : [
                                // Private Table Mode: 4 slots
                                _buildInvitationPlayerSlot(
                                  pIdx: 0,
                                  uid: _onlinePlayerUids[0],
                                  name: _onlinePlayerNames[0],
                                  photo: _onlinePlayerImages[0],
                                ),
                                const SizedBox(width: 8),
                                _buildInvitationPlayerSlot(
                                  pIdx: 1,
                                  uid: _onlinePlayerUids[1],
                                  name: _onlinePlayerNames[1],
                                  photo: _onlinePlayerImages[1],
                                ),
                                const SizedBox(width: 8),
                                _buildInvitationPlayerSlot(
                                  pIdx: 2,
                                  uid: _onlinePlayerUids[2],
                                  name: _onlinePlayerNames[2],
                                  photo: _onlinePlayerImages[2],
                                ),
                                const SizedBox(width: 8),
                                _buildInvitationPlayerSlot(
                                  pIdx: 3,
                                  uid: _onlinePlayerUids[3],
                                  name: _onlinePlayerNames[3],
                                  photo: _onlinePlayerImages[3],
                                ),
                              ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Bottom Status
                  Text(
                    _isTeamMode
                        ? 'بانتظار انضمام الشريك...'
                        : 'جاري انتظار البدء...',
                    style: GoogleFonts.tajawal(
                      color: const Color(0xFFB2EBF2),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(flex: 1),

                  // Host Action Button
                  if (_roomHostId ==
                      auth.FirebaseAuth.instance.currentUser?.uid)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 40,
                        left: 20,
                        right: 20,
                      ),
                      child: _buildPremiumCreationButton(
                        _isTeamMode ? 'بحث عن مباراة' : 'ابدأ اللعبة',
                        () {
                          if (_isTeamMode) {
                            // Team Up Start Logic: Needs at least 2 players in the team
                            if (_onlinePlayerNames.length < 2) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("يجب انضمام شريك لبدء البحث"),
                                ),
                              );
                              return;
                            }
                            // Logic for searching match in 2v2
                            LudoService().updateGameState(_roomId!, {
                              'status': 'matching',
                              'status_bet': 'matching_${_selectedBet}_4_team',
                            });
                          } else {
                            // Private Table Start Logic
                            if (_onlinePlayerNames.length < 2) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "يجب انضمام لاعب واحد على الأقل",
                                  ),
                                ),
                              );
                              return;
                            }
                            LudoService().updateGameState(_roomId!, {
                              'status': 'playing',
                              'status_bet':
                                  'playing_${_selectedBet}_${_currentMatchMaxPlayers}_$_currentMatchMode',
                            });
                          }
                        },
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

  Widget _buildInvitationPlayerSlot({
    required int pIdx,
    String? uid,
    String? name,
    String? photo,
  }) {
    final bool isEmpty = uid == null;

    return SizedBox(
      width: 90,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Frame Glow
              Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isEmpty
                          ? Colors.white10
                          : _getPlayerGlowColor(pIdx),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Avatar Border
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isEmpty ? Colors.white24 : const Color(0xFFFFD54F),
                    width: 2.5,
                  ),
                  color: Colors.black45,
                ),
                child: GestureDetector(
                  onTap: isEmpty ? _showActiveFriendsInvitation : null,
                  child: isEmpty
                      ? const Icon(Icons.add, color: Colors.white24, size: 30)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(35),
                          child: photo != null
                              ? Image(
                                  image: _getAvatarProvider(photo)!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 40,
                                ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Name Banner
          Stack(
            alignment: Alignment.center,
            children: [
              ClipPath(
                clipper: JaggedBottomClipper(),
                child: Container(
                  width: 85,
                  height: 65,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.blue.shade300, Colors.blue.shade800],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Text(
                      isEmpty ? "دعوة" : (name ?? "لاعب"),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                        color: const Color(0xFFFFEB3B), // Yellow name
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "استعد",
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPlayerGlowColor(int pIdx) {
    switch (pIdx) {
      case 0:
        return Colors.amberAccent;
      case 1:
        return Colors.pinkAccent;
      case 2:
        return Colors.cyanAccent;
      case 3:
        return Colors.orangeAccent;
      default:
        return Colors.white54;
    }
  }

  void _showActiveFriendsInvitation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildActiveFriendsBottomSheet(),
    );
  }

  Widget _buildActiveFriendsBottomSheet() {
    final currentUid = auth.FirebaseAuth.instance.currentUser?.uid;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1C3C), Color(0xFF0F0C29)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Colors.white10, width: 2)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 15),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "الأصدقاء المتصلون الآن",
            style: GoogleFonts.tajawal(
              color: const Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: _buildUserListTab(
              UserService().getFollowing(currentUid ?? ""),
              onlyOnline: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListTab(
    Future<List<User>> future, {
    bool onlyOnline = false,
  }) {
    return FutureBuilder<List<User>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amber),
          );
        }

        final users = snapshot.data ?? [];
        // Filter out current user
        final currentUid = auth.FirebaseAuth.instance.currentUser?.uid;
        var filteredUsers = users.where((u) => u.uid != currentUid).toList();

        // New: Filter for online only if requested
        if (onlyOnline) {
          filteredUsers = filteredUsers.where((u) => u.isOnline).toList();
        }

        if (filteredUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.people_outline,
                  color: Colors.white24,
                  size: 80,
                ),
                const SizedBox(height: 20),
                Text(
                  "لا يوجد مستخدمين متاحين حالياً",
                  style: GoogleFonts.tajawal(
                    color: Colors.white38,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          physics: const BouncingScrollPhysics(),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final friend = filteredUsers[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 5,
                ),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.blueGrey.shade900,
                      backgroundImage: _getAvatarProvider(friend.profileImage),
                    ),
                    if (friend.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1A1C3C),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  friend.username,
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  friend.isOnline ? "نشط الآن" : "غير متصل",
                  style: GoogleFonts.tajawal(
                    color: friend.isOnline
                        ? Colors.greenAccent
                        : Colors.white38,
                    fontSize: 12,
                  ),
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    LudoService().sendInvite(
                      friend.uid,
                      _roomId!,
                      _selectedBet,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("تم إرسال الدعوة لـ ${friend.username}"),
                        backgroundColor: Colors.blueAccent,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: Text(
                    "دعوة",
                    style: GoogleFonts.tajawal(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startOfflineGame() {
    // Check balance before starting offline game
    if (_userCoins < _selectedBet) {
      _showInsufficientFundsDialog();
      return;
    }

    // Deduct bet amount from user's coins if any
    final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null && _selectedBet > 0) {
      UserService()
          .updateUser(
            uid: myUid,
            data: {'coins': FieldValue.increment(-_selectedBet)},
          )
          .catchError((e) => debugPrint('[LudoBet] Local deduction error: $e'));

      debugPrint(
        '[LudoBet] Local match: Deducted $_selectedBet coins from $myUid',
      );
    }

    setState(() {
      _gameMode = 'local';
      _uiState = LudoUiState.playing;
      _myPlayerIndex =
          0; // Local player always starts as Red (0) for consistency

      // Clear previous match data
      _botIndices.clear();
      _botProfiles.clear();
      _winners.clear();
      _leavers.clear();
      _diceRolled = [];
      _unreadMessagesCount = 0;
      _sentHurryThisTurn = false;
      _blueButtonClicks = 0;

      // Setup a local bot to play against
      _setupLocalBotProfile();

      // Reset positions and board
      _reinitGameWithTheme();
    });

    _startTurnTimer(isFirstTurn: true);
    _switchMusicTrack();
  }

  Widget _buildYellowButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFCA28), Color(0xFFFF9800)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.yellowAccent.withOpacity(0.5)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(0, 4),
              blurRadius: 4,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        ),
      ),
    );
  }

  Widget _buildTopActions() {
    return Row(
      children: [
        _buildTopIconButton(
          icon: Icons.settings,
          color: Colors.grey[400]!,
          onTap: _showAudioSettingsDialog,
        ),
        const SizedBox(width: 8),
        _buildTopIconButton(
          icon: Icons.palette_outlined,
          color: Colors.cyanAccent,
          onTap: _showCustomizationDialog,
        ),
        const SizedBox(width: 8),
        _buildTopIconButton(
          icon: Icons.shopping_cart,
          color: Colors.amber[400]!,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LudoStoreScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCurrencyBar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCurrencyBox(
          icon: Icons.monetization_on_rounded,
          iconColor: Colors.amber,
          value: _formatCurrency(_userCoins),
          isDiamond: false,
        ),
        const SizedBox(width: 6),
        _buildCurrencyBox(
          icon: Icons.diamond_rounded,
          iconColor: Colors.cyanAccent,
          value: _userDiamonds.toString(),
          isDiamond: true,
        ),
      ],
    );
  }

  Widget _buildCurrencyBox({
    required IconData icon,
    required Color iconColor,
    required String value,
    bool isDiamond = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 15),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 5),
          Icon(
            Icons.add_circle_outline_rounded,
            size: 14,
            color: Colors.white.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int value) {
    if (value >= 1000000) {
      return "${(value / 1000000).toStringAsFixed(1)}M";
    } else if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}K";
    }
    return value.toString();
  }




  Widget _buildBottomNavigationBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pagination Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 4,
                  width: _currentGamePageIndex == index ? 16 : 4,
                  decoration: BoxDecoration(
                    color: _currentGamePageIndex == index
                        ? Colors.white
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),

            const SizedBox(height: 6),
            // Icons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavItem(
                  index: 0,
                  title: "لودو",
                  icon: Icons.casino_rounded,
                  activeColor: Colors.white,
                ),
                _buildBottomNavItem(
                  index: 1,
                  title: "دومينو",
                  icon: Icons.grid_view_rounded,
                  activeColor: Colors.white,
                ),
                _buildBottomNavItem(
                  index: 2,
                  title: "اخرى",
                  icon: Icons.more_horiz_rounded,
                  activeColor: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required String title,
    required IconData icon,
    required Color activeColor,
  }) {
    final bool isActive = _currentGamePageIndex == index;
    return GestureDetector(
      onTap: () {
        _gamePageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : Colors.white24,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: isActive ? activeColor : Colors.white24,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RhombusPainter extends CustomPainter {
  final Color color;
  RhombusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const double rhombusSize = 50;
    const double spacing = 15;

    for (
      double i = -rhombusSize;
      i < size.width + rhombusSize;
      i += rhombusSize + spacing
    ) {
      for (
        double j = -rhombusSize;
        j < size.height + rhombusSize;
        j += (rhombusSize + spacing) / 2
      ) {
        final double offsetX =
            (j / ((rhombusSize + spacing) / 2)).floor() % 2 == 0
            ? 0
            : (rhombusSize + spacing) / 2;
        final Path path = Path();
        path.moveTo(i + offsetX, j);
        path.lineTo(i + offsetX + rhombusSize / 2, j + rhombusSize / 2);
        path.lineTo(i + offsetX, j + rhombusSize);
        path.lineTo(i + offsetX - rhombusSize / 2, j + rhombusSize / 2);
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShineEffectWrapper extends StatefulWidget {
  final Widget child;
  const _ShineEffectWrapper({required this.child});

  @override
  _ShineEffectWrapperState createState() => _ShineEffectWrapperState();
}

class _ShineEffectWrapperState extends State<_ShineEffectWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _controller.forward();
    });

    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _controller.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            if (!_controller.isAnimating && _controller.isDismissed) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(
              child: ClipRRect(
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  alignment: Alignment(_controller.value * 6 - 3, 0),
                  child: Transform.rotate(
                    angle: 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(0.5),
                            Colors.white.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class StarBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.3);
    final random = Random(42);
    for (int i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class CrescentClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.addOval(Rect.fromLTRB(0, 0, size.width, size.height));

    Path mask = Path();
    // Offset the inner circle to create a crescent
    mask.addOval(
      Rect.fromLTRB(
        size.width * 0.2,
        -size.height * 0.1,
        size.width * 1.2,
        size.height * 0.9,
      ),
    );

    return Path.combine(PathOperation.difference, path, mask);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
