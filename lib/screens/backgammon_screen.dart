import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/backgammon_provider.dart';
import '../services/backgammon_service.dart';
import '../models/backgammon_theme.dart';
import 'dart:math' as math;

// --- Board Alignment Constants ---
const double kBoardPaddingX = 0.054;
const double kBoardPaddingY = 0.035;
const double kBoardBarWidthFactor = 0.082;
// ---------------------------------

enum BackgammonUiState { menu, matching, playing }

class BackgammonScreen extends StatelessWidget {
  const BackgammonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BackgammonProvider(),
      child: const _BackgammonView(),
    );
  }
}

class _BackgammonView extends StatefulWidget {
  const _BackgammonView();

  @override
  State<_BackgammonView> createState() => _BackgammonViewState();
}

class _BackgammonViewState extends State<_BackgammonView>
    with TickerProviderStateMixin {
  late AnimationController _rollController;
  late AnimationController _moveController;
  bool _isRolling = false;
  List<int> _animDice = [0, 0];
  final math.Random _rand = math.Random();
  ui.Image? _boardImage;
  ui.Image? _whiteTokenImage;
  ui.Image? _blackTokenImage;

  BackgammonUiState _uiState = BackgammonUiState.menu;
  String? _roomId;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadBoardImage();
    _rollController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 600),
        )..addListener(() {
          if (_isRolling) {
            setState(() {
              _animDice = [_rand.nextInt(6) + 1, _rand.nextInt(6) + 1];
            });
          }
        });

    _moveController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 400),
          )
          ..addListener(() {
            final provider = Provider.of<BackgammonProvider>(
              context,
              listen: false,
            );
            if (provider.isAnimating) {
              provider.updateMoveProgress(_moveController.value);
            }
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              final provider = Provider.of<BackgammonProvider>(
                context,
                listen: false,
              );
              if (provider.isAnimating) {
                provider.finalizeMove(
                  provider.moveStart,
                  provider.moveEnd!,
                  provider.isMovingFromBar,
                );
                _moveController.reset();
                provider.startNextJump(provider.currentJumpTarget);
              }
            }
          });
  }

  Future<void> _loadBoardImage() async {
    ui.Image? boardImg;
    ui.Image? wImg;
    ui.Image? bImg;

    try {
      final data = await rootBundle.load('assets/images/luxury_board.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      boardImg = frame.image;
    } catch (e) {
      try {
        final data = await rootBundle.load('assets/images/tawlaa.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        boardImg = frame.image;
      } catch (e2) {
        debugPrint("Error loading both board images: $e2");
      }
    }

    try {
      final wData = await rootBundle.load('assets/images/w2.png');
      final wCodec = await ui.instantiateImageCodec(wData.buffer.asUint8List());
      final wFrame = await wCodec.getNextFrame();
      wImg = wFrame.image;
    } catch (e) {
      debugPrint("Error loading white token (w2.png): $e");
    }

    try {
      final bData = await rootBundle.load('assets/images/b1.png');
      final bCodec = await ui.instantiateImageCodec(bData.buffer.asUint8List());
      final bFrame = await bCodec.getNextFrame();
      bImg = bFrame.image;
    } catch (e) {
      debugPrint("Error loading black token (b1.png): $e");
    }

    if (mounted) {
      setState(() {
        _boardImage = boardImg;
        _whiteTokenImage = wImg;
        _blackTokenImage = bImg;
      });
    }
  }

  @override
  void dispose() {
    if (_roomId != null) {
      BackgammonService().leaveRoom(_roomId!);
    }
    _rollController.dispose();
    _moveController.dispose();
    super.dispose();
  }

  void _startRoll(BackgammonProvider provider) async {
    if (provider.availableMoves.isNotEmpty || provider.isGameOver) return;

    setState(() {
      _isRolling = true;
    });

    provider.playDiceSound();
    await _rollController.forward(from: 0);

    setState(() {
      _isRolling = false;
    });

    provider.rollDice();
  }

  void _handleBoardTap(
    BuildContext context,
    Offset localPosition,
    Size boardSize,
  ) {
    final provider = Provider.of<BackgammonProvider>(context, listen: false);
    if (provider.availableMoves.isEmpty &&
        provider.selectedPoint == null &&
        !provider.isBarSelected) {
      return;
    }

    double barWidth = boardSize.width * 0.08;
    double barLeft = (boardSize.width - barWidth) / 2;

    if (localPosition.dx >= barLeft && localPosition.dx <= barLeft + barWidth) {
      provider.selectBar();
      return;
    }

    int? tappedIndex = _getPointIndexFromOffset(localPosition, boardSize);
    if (tappedIndex != null) {
      provider.selectPoint(tappedIndex);
    }
  }

  int? _getPointIndexFromOffset(Offset offset, Size size) {
    double totalPaddingX = size.width * kBoardPaddingX;
    double usableWidth = size.width - (totalPaddingX * 2);
    double barWidth = usableWidth * kBoardBarWidthFactor;
    double pointWidth = (usableWidth - barWidth) / 12;
    double halfHeight = size.height / 2;

    double adjustedX = offset.dx - totalPaddingX;
    double adjustedY = offset.dy;

    if (adjustedX < 0 || adjustedX > usableWidth) return null;

    int col;
    if (adjustedX < (usableWidth - barWidth) / 2) {
      col = (adjustedX / pointWidth).floor();
    } else if (adjustedX > (usableWidth + barWidth) / 2) {
      col = ((adjustedX - barWidth) / pointWidth).floor();
    } else {
      return null;
    }

    if (adjustedY < halfHeight) {
      return 12 + col;
    } else {
      return 11 - col;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BackgammonProvider>(context);

    if (_uiState == BackgammonUiState.menu ||
        _uiState == BackgammonUiState.matching) {
      return _buildMenuScreen(context, provider.currentTheme);
    }

    if (provider.isGameOver && provider.winner != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showVictoryDialog(context, provider);
      });
    }

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
              Color(0xFF0A0E1A), // Midnight Space Blue
              Color(0xFF0F172A), // Slate Navy Dark Blue
              Color(0xFF050814), // Dark Space Abyss
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(provider),
              _buildInfoPanel(provider),
              _buildBearingOffIndicator(context, provider),
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double horizontalMargin = 20;
                      double availableWidth =
                          constraints.maxWidth - horizontalMargin;
                      double availableHeight = constraints.maxHeight;

                      double boardWidth = math.min(
                        availableWidth,
                        availableHeight * 0.72,
                      );
                      double boardSizeFactor = 0.75;
                      double boardHeight = boardWidth / boardSizeFactor;

                      if (boardHeight > availableHeight) {
                        boardHeight = availableHeight;
                        boardWidth = boardHeight * boardSizeFactor;
                      }

                      Size boardSize = Size(boardWidth, boardHeight);

                      if (provider.isAnimating &&
                          !_moveController.isAnimating &&
                          _moveController.value == 0.0) {
                        _moveController.forward();
                      }

                      return Center(
                        child: GestureDetector(
                          onTapUp: (details) => _handleBoardTap(
                            context,
                            details.localPosition,
                            boardSize,
                          ),
                          child: CustomPaint(
                            size: boardSize,
                            painter: BackgammonBoardPainter(
                              boardState: provider.board,
                              whiteBar: provider.whiteBar,
                              blackBar: provider.blackBar,
                              whiteOff: provider.whiteOff,
                              blackOff: provider.blackOff,
                              selectedPoint: provider.selectedPoint,
                              isBarSelected: provider.isBarSelected,
                              validDestinations: provider.validDestinations,
                              currentPlayer: provider.currentPlayer,
                              theme: provider.currentTheme,
                              backgroundImage: _boardImage,
                              whiteTokenImage: _whiteTokenImage,
                              blackTokenImage: _blackTokenImage,
                              isAnimating: provider.isAnimating,
                              moveStart: provider.moveStart,
                              moveEnd: provider.moveEnd,
                              moveProgress: provider.moveProgress,
                              isMovingFromBar: provider.isMovingFromBar,
                              movingPlayer: provider.movingPlayer,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              _buildControls(provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar(BackgammonProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.casino_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'طاولة ميتو الذكية',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: provider.toggleMute,
                icon: Icon(
                  provider.isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white70,
                ),
              ),
              PopupMenuButton<BackgammonThemeType>(
                icon: const Icon(Icons.palette_rounded, color: Colors.white70),
                color: const Color(0xFF1E2024),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                onSelected: (type) => provider.setTheme(type),
                itemBuilder: (context) => provider.availableThemes.map((theme) {
                  return PopupMenuItem<BackgammonThemeType>(
                    value: theme.type,
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.boardBaseColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: theme.boardBaseColor.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          theme.name,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showVictoryDialog(BuildContext context, BackgammonProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1C20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        title: Column(
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: Colors.amber,
              size: 60,
            ),
            const SizedBox(height: 10),
            Text(
              provider.winner == 1
                  ? "فاز اللاعب الأبيض!"
                  : "فاز اللاعب الأسود!",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Tajawal',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          provider.winner == 1
              ? "أداء مذهل! لقد أثبتت جدارتك في اللوحة."
              : "انتصار رائع وتكتيك مميز!",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontFamily: 'Tajawal',
            fontSize: 16,
          ),
        ),
        actions: [
          Center(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.amber, Colors.orange],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  provider.resetGame();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "العب مجدداً",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBearingOffIndicator(
    BuildContext context,
    BackgammonProvider provider,
  ) {
    bool allHome = provider.canBearOff;
    bool isPieceInHome =
        (provider.currentPlayer == 1 &&
            provider.selectedPoint != null &&
            provider.selectedPoint! >= 18) ||
        (provider.currentPlayer == 2 &&
            provider.selectedPoint != null &&
            provider.selectedPoint! <= 5);

    bool canExecBearOff = allHome && isPieceInHome;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: canExecBearOff ? 1.0 : 0.0,
      child: canExecBearOff
          ? GestureDetector(
              onTap: provider.bearOff,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C853), Color(0xFF64DD17)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.outbound_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      "أخرج القطعة",
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox(height: 10),
    );
  }

  Widget _buildInfoPanel(BackgammonProvider provider) {
    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPlayerIndicator(
                  1,
                  "الأبيض",
                  provider.whiteOff,
                  provider.currentPlayer == 1,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      provider.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 14,
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                _buildPlayerIndicator(
                  2,
                  "الأسود",
                  provider.blackOff,
                  provider.currentPlayer == 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerIndicator(
    int player,
    String label,
    int offCount,
    bool isCurrent,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(isCurrent ? 6 : 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        border: isCurrent
            ? Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.5)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isCurrent ? 36 : 30,
            height: isCurrent ? 36 : 30,
            decoration: BoxDecoration(
              gradient: player == 1
                  ? const RadialGradient(
                      colors: [Colors.white, Color(0xFFD6D6D6)],
                    )
                  : const RadialGradient(
                      colors: [Color(0xFF555555), Colors.black],
                    ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
                if (isCurrent)
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "$label ($offCount/15)",
            style: TextStyle(
              color: isCurrent ? Colors.amberAccent : Colors.white70,
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BackgammonProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildDie(
                _isRolling ? _animDice[0] : provider.dice[0],
                provider.currentPlayer == 1,
                isRolling: _isRolling,
              ),
              const SizedBox(width: 15),
              _buildDie(
                _isRolling ? _animDice[1] : provider.dice[1],
                provider.currentPlayer == 1,
                isRolling: _isRolling,
              ),
            ],
          ),
          Row(
            children: [
              if (provider.canUndo && !_isOnline)
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: provider.undoMove,
                    icon: const Icon(Icons.undo_rounded, color: Colors.white),
                    tooltip: "تراجع",
                  ),
                ),
              GestureDetector(
                onTap:
                    (provider.availableMoves.isEmpty &&
                        !provider.isGameOver &&
                        !_isRolling &&
                        (!_isOnline ||
                            provider.currentPlayer == provider.myPlayerIndex))
                    ? () => _startRoll(provider)
                    : null,
                child: Opacity(
                  opacity:
                      (provider.availableMoves.isEmpty &&
                          !provider.isGameOver &&
                          (!_isOnline ||
                              provider.currentPlayer == provider.myPlayerIndex))
                      ? 1.0
                      : 0.5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      "رمي النرد",
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: Colors.black87,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
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

  Widget _buildDie(int value, bool isWhite, {bool isRolling = false}) {
    Widget die = CustomPaint(
      size: const Size(54, 54),
      painter: DiePainter(value: value, isWhite: isWhite),
    );

    if (isRolling) {
      return AnimatedBuilder(
        animation: _rollController,
        builder: (context, child) {
          final double angle = _rollController.value * math.pi * 4;
          final double shake = math.sin(_rollController.value * 40) * 4;
          return Transform.translate(
            offset: Offset(shake, shake),
            child: Transform.rotate(angle: angle, child: child),
          );
        },
        child: die,
      );
    }

    return die;
  }

  // --- MENU ---
  Widget _buildMenuScreen(BuildContext context, BackgammonThemeData theme) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/luxury_board.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.6),
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "طاولة ميتو",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                    fontFamily: 'Tajawal',
                    shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 50),
                if (_uiState == BackgammonUiState.matching)
                  const Column(
                    children: [
                      CircularProgressIndicator(color: Colors.amber),
                      SizedBox(height: 20),
                      Text(
                        "جاري البحث عن متحدي...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildMenuButton(
                        "ألعب مع صديق (وجه لوجه)",
                        Icons.people,
                        _startGameLocal,
                      ),
                      const SizedBox(height: 20),
                      _buildMenuButton(
                        "تحدي أونلاين",
                        Icons.language,
                        _startMatchmaking,
                      ),
                    ],
                  ),
                const SizedBox(height: 50),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "رجوع",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                      fontFamily: 'Tajawal',
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

  Widget _buildMenuButton(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber.shade700,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startGameLocal() {
    setState(() {
      _uiState = BackgammonUiState.playing;
      _isOnline = false;
    });
    Provider.of<BackgammonProvider>(context, listen: false).resetGame();
  }

  Future<void> _startMatchmaking() async {
    setState(() => _uiState = BackgammonUiState.matching);
    try {
      final roomId = await BackgammonService().joinOrCreateRoom();
      if (!mounted) return;
      setState(() {
        _roomId = roomId;
        _isOnline = true;
      });
      BackgammonService().streamRoom(roomId).listen((event) {
        if (!mounted || _uiState == BackgammonUiState.playing) return;
        final data = event.snapshot.value as Map?;
        if (data != null && data['status'] == 'playing') {
          final players = Map<String, dynamic>.from(data['players'] ?? {});
          final me = players[FirebaseAuth.instance.currentUser?.uid];
          if (me != null) {
            Provider.of<BackgammonProvider>(
              context,
              listen: false,
            ).initOnline(roomId, me['index']);
            setState(() => _uiState = BackgammonUiState.playing);
          }
        }
      });
    } catch (e) {
      print("Matchmaking error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("فشل التسجيل: $e")));
        setState(() => _uiState = BackgammonUiState.menu);
      }
    }
  }
}

class DiePainter extends CustomPainter {
  final int value;
  final bool isWhite;
  DiePainter({required this.value, required this.isWhite});

  @override
  void paint(Canvas canvas, Size size) {
    if (value == 0) return;

    final double w = size.width;
    final double h = size.height;

    canvas.save();
    canvas.translate(w * 0.1, h * 0.1);
    final double s = w * 0.8;

    final sideColor = isWhite
        ? const Color(0xFFD6D6D6)
        : const Color(0xFF1A1A1A);
    final topColor = isWhite ? Colors.white : const Color(0xFF2A2A2A);
    final goldColor = const Color(0xFFFFD700);

    // Isometric Paths
    final topPath = Path()
      ..moveTo(s * 0.5, 0)
      ..lineTo(s, s * 0.25)
      ..lineTo(s * 0.5, s * 0.5)
      ..lineTo(0, s * 0.25)
      ..close();

    final leftPath = Path()
      ..moveTo(0, s * 0.25)
      ..lineTo(s * 0.5, s * 0.5)
      ..lineTo(s * 0.5, s)
      ..lineTo(0, s * 0.75)
      ..close();

    final rightPath = Path()
      ..moveTo(s * 0.5, s * 0.5)
      ..lineTo(s, s * 0.25)
      ..lineTo(s, s * 0.75)
      ..lineTo(s * 0.5, s)
      ..close();

    // Drop Shadow for dice
    canvas.drawShadow(topPath, Colors.black, 10, true);

    void drawFace(Path path, Color color, int seed, bool isTop) {
      canvas.drawPath(path, Paint()..color = color);
      // Soft reflection
      if (isTop) {
        canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withValues(alpha: 0.4), Colors.transparent],
            ).createShader(path.getBounds()),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    drawFace(leftPath, sideColor, 1, false);
    drawFace(rightPath, sideColor.withValues(alpha: 0.8), 2, false);
    drawFace(topPath, topColor, 3, true);

    _drawIsometricPips(canvas, value, s, goldColor);

    canvas.restore();
  }

  void _drawIsometricPips(Canvas canvas, int value, double s, Color gold) {
    Offset toIso(double px, double py) {
      double dx = (px - 0.5) * s * 0.5 + (py - 0.5) * (-s * 0.5) + s * 0.5;
      double dy = (px - 0.5) * s * 0.25 + (py - 0.5) * s * 0.25 + s * 0.25;
      return Offset(dx, dy);
    }

    final double r = s * 0.07;

    void drawPip(double px, double py) {
      Offset pos = toIso(px, py);

      // Shadow inside pip hole
      canvas.drawOval(
        Rect.fromCenter(
          center: pos + const Offset(0, 1),
          width: r * 2,
          height: r * 1.5,
        ),
        Paint()..color = Colors.black87,
      );

      // Bright Pip
      canvas.drawOval(
        Rect.fromCenter(center: pos, width: r * 2, height: r * 1.5),
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white, gold, Colors.orange.shade800],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(Rect.fromCircle(center: pos, radius: r)),
      );
    }

    const double p1 = 0.25;
    const double mid = 0.5;
    const double p2 = 0.75;

    switch (value) {
      case 1:
        drawPip(mid, mid);
        break;
      case 2:
        drawPip(p1, p1);
        drawPip(p2, p2);
        break;
      case 3:
        drawPip(p1, p1);
        drawPip(mid, mid);
        drawPip(p2, p2);
        break;
      case 4:
        drawPip(p1, p1);
        drawPip(p2, p1);
        drawPip(p1, p2);
        drawPip(p2, p2);
        break;
      case 5:
        drawPip(p1, p1);
        drawPip(p2, p1);
        drawPip(mid, mid);
        drawPip(p1, p2);
        drawPip(p2, p2);
        break;
      case 6:
        drawPip(p1, p1);
        drawPip(p2, p1);
        drawPip(p1, mid);
        drawPip(p2, mid);
        drawPip(p1, p2);
        drawPip(p2, p2);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BackgammonBoardPainter extends CustomPainter {
  final List<int> boardState;
  final int whiteBar;
  final int blackBar;
  final int whiteOff;
  final int blackOff;
  final int? selectedPoint;
  final bool isBarSelected;
  final List<int> validDestinations;
  final int currentPlayer;
  final ui.Image? backgroundImage;
  final ui.Image? whiteTokenImage;
  final ui.Image? blackTokenImage;

  final bool isAnimating;
  final int? moveStart;
  final int? moveEnd;
  final double moveProgress;
  final bool isMovingFromBar;
  final int movingPlayer;
  final BackgammonThemeData theme;

  BackgammonBoardPainter({
    required this.boardState,
    required this.whiteBar,
    required this.blackBar,
    required this.whiteOff,
    required this.blackOff,
    this.selectedPoint,
    required this.isBarSelected,
    required this.validDestinations,
    required this.currentPlayer,
    required this.theme,
    this.backgroundImage,
    this.whiteTokenImage,
    this.blackTokenImage,
    this.isAnimating = false,
    this.moveStart,
    this.moveEnd,
    this.moveProgress = 0.0,
    this.isMovingFromBar = false,
    this.movingPlayer = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Deep outer shadow for the entire board
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        fullRect.shift(const Offset(0, 15)),
        const Radius.circular(20),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    _drawThemedFrame(canvas, fullRect);

    double totalPaddingX = size.width * kBoardPaddingX;
    double totalPaddingY = size.height * kBoardPaddingY;
    double usableWidth = size.width - (totalPaddingX * 2);
    double usableHeight = size.height - (totalPaddingY * 2);

    double barWidth = usableWidth * kBoardBarWidthFactor;
    double pointWidth = (usableWidth - barWidth) / 12;
    double triangleHeight = usableHeight * 0.44;

    final boardRect = Rect.fromLTWH(
      totalPaddingX,
      totalPaddingY,
      usableWidth,
      usableHeight,
    );
    final barRect = Rect.fromLTWH(
      totalPaddingX + (usableWidth - barWidth) / 2,
      totalPaddingY,
      barWidth,
      usableHeight,
    );

    _drawThemedBase(canvas, boardRect);
    _drawThemedBar(canvas, barRect);

    // Draw Houses & Points
    for (int i = 0; i < 24; i++) {
      _drawThemedPoint(canvas, i, size, pointWidth, barWidth, triangleHeight);
    }

    // Draw Pieces
    for (int i = 0; i < 24; i++) {
      _drawPiecesOnPoint(canvas, i, size, pointWidth, barWidth);
    }

    _drawBarPieces(canvas, size, barWidth);

    if (isAnimating && moveEnd != null) {
      _drawMovingPiece(canvas, size, pointWidth, barWidth);
    }

    _drawSurfaceReflection(canvas, fullRect);
  }

  void _drawMovingPiece(
    Canvas canvas,
    Size size,
    double pWidth,
    double bWidth,
  ) {
    Offset startPos;
    if (isMovingFromBar) {
      double centerX = size.width / 2;
      double radius = bWidth * 0.4;
      if (movingPlayer == 1) {
        startPos = Offset(
          centerX,
          size.height * 0.3 - (whiteBar * radius * 1.5),
        );
      } else {
        startPos = Offset(
          centerX,
          size.height * 0.7 + (blackBar * radius * 1.5),
        );
      }
    } else {
      startPos = _getPiecePosition(
        moveStart!,
        size,
        pWidth,
        bWidth,
        isMoving: true,
      );
    }

    Offset endPos = _getPiecePosition(
      moveEnd!,
      size,
      pWidth,
      bWidth,
      isTarget: true,
    );

    // Parabolic arc for jumping
    double jumpHeight = math.sin(moveProgress * math.pi) * 40;
    Offset currentPos = Offset.lerp(startPos, endPos, moveProgress)!;
    currentPos = Offset(currentPos.dx, currentPos.dy - jumpHeight);

    double radius = math.min(
      pWidth * 0.45,
      size.height * 0.038,
    ); // Slightly bigger when jumping

    // Shadow on the ground
    canvas.drawOval(
      Rect.fromCenter(
        center:
            Offset.lerp(startPos, endPos, moveProgress)! + const Offset(0, 20),
        width: radius * 2,
        height: radius * 1.2,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5 - (jumpHeight / 100))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + (jumpHeight / 5)),
    );

    _drawPiece(
      canvas,
      currentPos,
      radius,
      movingPlayer == 1,
      isMovingAnim: true,
    );
  }

  Offset _getPiecePosition(
    int index,
    Size size,
    double pWidth,
    double bWidth, {
    bool isMoving = false,
    bool isTarget = false,
  }) {
    bool isTop = index >= 12;
    int colIndex = isTop ? (index - 12) : (11 - index);

    double totalPaddingX = size.width * kBoardPaddingX;
    double totalPaddingY = size.height * kBoardPaddingY;
    double centerX = totalPaddingX + colIndex * pWidth + pWidth / 2;
    if (colIndex >= 6) centerX += bWidth;

    double radius = math.min(pWidth * 0.42, size.height * 0.035);
    int count = boardState[index].abs();

    if (isMoving) count -= 1;

    double startY = isTop
        ? totalPaddingY + radius + 5
        : size.height - totalPaddingY - radius - 5;
    double dy = (radius * 1.8 * (isTop ? 1 : -1));

    int stackIndex = math.min(count, 4);

    return Offset(centerX, startY + (dy * stackIndex));
  }

  void _drawThemedFrame(Canvas canvas, Rect rect) {
    // Rich wooden/metallic border
    final framePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3E2723), Color(0xFF1B0000), Color(0xFF4E342E)],
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      framePaint,
    );

    // Inner gold/silver bevel
    final lipPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.amber, Colors.orangeAccent, Colors.brown],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(4), const Radius.circular(12)),
      lipPaint,
    );
  }

  void _drawThemedBase(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = theme.boardBaseColor);

    // Deep center shadow
    final depthPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: [theme.boardBaseColor.withValues(alpha: 0.1), Colors.black87],
      ).createShader(rect);
    canvas.drawRect(rect, depthPaint);
  }

  void _drawThemedBar(Canvas canvas, Rect rect) {
    final barPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
      ).createShader(rect);

    canvas.drawRect(rect, barPaint);

    if (isBarSelected) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.amber.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawThemedPoint(
    Canvas canvas,
    int index,
    Size size,
    double pWidth,
    double bWidth,
    double tHeight,
  ) {
    bool isTop = index >= 12;
    bool isLight = index % 2 != 0;
    int colIndex = isTop ? (index - 12) : (11 - index);

    double totalPaddingX = size.width * kBoardPaddingX;
    double totalPaddingY = size.height * kBoardPaddingY;
    double leftEdge = totalPaddingX + colIndex * pWidth;
    if (colIndex >= 6) leftEdge += bWidth;

    final path = Path();
    if (isTop) {
      path.moveTo(leftEdge + 2, totalPaddingY);
      path.lineTo(leftEdge + pWidth - 2, totalPaddingY);
      path.lineTo(leftEdge + pWidth / 2, totalPaddingY + tHeight);
    } else {
      path.moveTo(leftEdge + 2, size.height - totalPaddingY);
      path.lineTo(leftEdge + pWidth - 2, size.height - totalPaddingY);
      path.lineTo(leftEdge + pWidth / 2, size.height - totalPaddingY - tHeight);
    }
    path.close();

    final pointPaint = Paint()
      ..shader = LinearGradient(
        begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
        colors: isLight ? theme.pointLightGradients : theme.pointDarkGradients,
      ).createShader(path.getBounds());

    canvas.drawPath(path, pointPaint);

    // Inner shadow for depth
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    _drawSelectionHighlight(canvas, index, size, pWidth, bWidth, tHeight);
  }

  void _drawPiecesOnPoint(
    Canvas canvas,
    int index,
    Size size,
    double pWidth,
    double bWidth,
  ) {
    int count = boardState[index].abs();
    bool isAnimatingHere = isAnimating && moveStart == index;
    if (isAnimatingHere) count -= 1;

    if (count <= 0) return;

    bool isTop = index >= 12;
    bool isWhite = boardState[index] > 0;
    int colIndex = isTop ? (index - 12) : (11 - index);

    double totalPaddingX = size.width * kBoardPaddingX;
    double totalPaddingY = size.height * kBoardPaddingY;
    double centerX = totalPaddingX + colIndex * pWidth + pWidth / 2;
    if (colIndex >= 6) centerX += bWidth;

    double radius = math.min(pWidth * 0.42, size.height * 0.035);
    double startY = isTop
        ? totalPaddingY + radius + 5
        : size.height - totalPaddingY - radius - 5;
    double dy = (radius * 1.8 * (isTop ? 1 : -1));

    for (int j = 0; j < math.min(count, 5); j++) {
      _drawPiece(
        canvas,
        Offset(centerX, startY + (dy * j)),
        radius,
        isWhite,
        stackLevel: j,
        isStackLabel: j == 4 && count > 5,
        count: count - 4,
      );
    }
  }

  void _drawBarPieces(Canvas canvas, Size size, double bWidth) {
    double radius = bWidth * 0.4;
    double centerX = size.width / 2;

    for (int i = 0; i < math.min(whiteBar, 3); i++) {
      Offset pos = Offset(centerX, size.height * 0.3 - (i * radius * 1.5));
      _drawPiece(
        canvas,
        pos,
        radius,
        true,
        isStackLabel: i == 2 && whiteBar > 3,
        count: whiteBar - 2,
      );
    }

    for (int i = 0; i < math.min(blackBar, 3); i++) {
      Offset pos = Offset(centerX, size.height * 0.7 + (i * radius * 1.5));
      _drawPiece(
        canvas,
        pos,
        radius,
        false,
        isStackLabel: i == 2 && blackBar > 3,
        count: blackBar - 2,
      );
    }
  }

  // Premium Piece Drawing
  void _drawPiece(
    Canvas canvas,
    Offset center,
    double radius,
    bool isWhite, {
    int stackLevel = 0,
    bool isStackLabel = false,
    int count = 0,
    bool isMovingAnim = false,
  }) {
    ui.Image? tokenImage = isWhite ? whiteTokenImage : blackTokenImage;

    // 1. Realistic Deep Outer Shadow
    Path shadowPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawShadow(
      shadowPath,
      Colors.black,
      isMovingAnim ? 15.0 : (4.0 + (stackLevel * 1.5)),
      false,
    );

    if (tokenImage != null) {
      // Draw actual texture with circular clip just in case
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      );
      paintImage(
        canvas: canvas,
        rect: Rect.fromCircle(center: center, radius: radius),
        image: tokenImage,
        fit: BoxFit.cover,
      );
      canvas.restore();

      // Optionally add a subtle highlight/glass overlay over the texture
      Path highlightPath = Path()
        ..addOval(
          Rect.fromCenter(
            center: center - Offset(0, radius * 0.4),
            width: radius * 1.2,
            height: radius * 0.6,
          ),
        );
      Paint highlightPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.3), Colors.transparent],
        ).createShader(highlightPath.getBounds());
      canvas.drawPath(highlightPath, highlightPaint);
    } else {
      // Fallback 3D Premium Piece Drawing
      final baseColor = isWhite
          ? const Color(0xFFF5F5F5)
          : const Color(0xFF121212);
      final coreColor = isWhite ? Colors.white : const Color(0xFF2A2A2A);
      final edgeShadow = isWhite ? const Color(0xFF9E9E9E) : Colors.black;

      // 2. Main 3D Sphere/Dome Gradient
      Paint bodyPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4), // Light source from top-left
          radius: 0.9,
          colors: [coreColor, baseColor, edgeShadow],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, bodyPaint);

      // 3. Inner Carved Ring (adds depth to the piece)
      Paint innerRing = Paint()
        ..color = isWhite
            ? Colors.black.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.15;
      canvas.drawCircle(center, radius * 0.7, innerRing);

      Paint innerRingHighlight = Paint()
        ..color = isWhite ? Colors.white : Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.05;
      canvas.drawCircle(center, radius * 0.65, innerRingHighlight);

      // 4. Glossy Specular Highlight (The 'Glass' effect)
      Path highlightPath = Path()
        ..addOval(
          Rect.fromCenter(
            center: center - Offset(0, radius * 0.4),
            width: radius * 1.2,
            height: radius * 0.6,
          ),
        );
      Paint highlightPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(highlightPath.getBounds());
      canvas.drawPath(highlightPath, highlightPaint);
    }

    // Stack Count Text
    if (isStackLabel) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: "+$count",
          style: TextStyle(
            color: isWhite ? Colors.black87 : Colors.white,
            fontSize: radius * 0.9,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  void _drawSelectionHighlight(
    Canvas canvas,
    int index,
    Size size,
    double pW,
    double bW,
    double tH,
  ) {
    if (selectedPoint != index && !validDestinations.contains(index)) return;

    bool isTop = index >= 12;
    int colIndex = isTop ? (index - 12) : (11 - index);
    double totalPaddingX = size.width * kBoardPaddingX;
    double totalPaddingY = size.height * kBoardPaddingY;
    double leftEdge = totalPaddingX + colIndex * pW;
    if (colIndex >= 6) leftEdge += bW;

    final path = Path();
    if (isTop) {
      path.moveTo(leftEdge + 1, totalPaddingY);
      path.lineTo(leftEdge + pW - 1, totalPaddingY);
      path.lineTo(leftEdge + pW / 2, totalPaddingY + tH);
    } else {
      path.moveTo(leftEdge + 1, size.height - totalPaddingY);
      path.lineTo(leftEdge + pW - 1, size.height - totalPaddingY);
      path.lineTo(leftEdge + pW / 2, size.height - totalPaddingY - tH);
    }
    path.close();

    if (selectedPoint == index) {
      // Neon Glow for Selected Point
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.amber.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.amberAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    } else if (validDestinations.contains(index)) {
      bool isHit =
          (currentPlayer == 1 && boardState[index] == -1) ||
          (currentPlayer == 2 && boardState[index] == 1);
      final glowColor = isHit ? Colors.redAccent : Colors.cyanAccent;

      canvas.drawPath(
        path,
        Paint()
          ..color = glowColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = glowColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  void _drawSurfaceReflection(Canvas canvas, Rect rect) {
    // Adds a subtle glass reflection over the entire board
    final reflectionPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment(0.0, 0.0),
        colors: [Color(0x1AFFFFFF), Colors.transparent],
      ).createShader(rect);
    canvas.drawRect(rect, reflectionPaint);
  }

  @override
  bool shouldRepaint(BackgammonBoardPainter oldDelegate) => true;
}
