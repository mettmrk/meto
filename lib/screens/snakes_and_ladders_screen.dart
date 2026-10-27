import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/game_service.dart';
import '../models/game_model.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

class SnakesAndLaddersScreen extends StatefulWidget {
  const SnakesAndLaddersScreen({super.key});

  @override
  State<SnakesAndLaddersScreen> createState() => _SnakesAndLaddersScreenState();
}

class _SnakesAndLaddersScreenState extends State<SnakesAndLaddersScreen>
    with TickerProviderStateMixin {
  final GameService _gameService = GameService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _gameId;
  String? _currentUserId;
  StreamSubscription<GameModel?>? _gameSubscription;
  GameModel? _gameModel;

  int _diceValue = 1;
  bool _isRolling = false;
  late AnimationController _diceController;
  late Animation<double> _diceAnimation;

  // تعريف أماكن السلالم والثعابين
  final Map<int, int> _ladders = {
    3: 40,
    7: 17,
    9: 33,
    24: 87,
    30: 49,
    59: 64,
    71: 91,
    80: 100,
  };

  final Map<int, int> _snakes = {
    8: 4,
    42: 19,
    44: 15,
    69: 12,
    93: 68,
    96: 65,
    98: 63,
  };

  @override
  void initState() {
    super.initState();
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _diceAnimation = CurvedAnimation(
      parent: _diceController,
      curve: Curves.easeInOutBack,
    );
    _initializeGame();
  }

  @override
  void dispose() {
    _diceController.dispose();
    _gameSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeGame() async {
    final user = _auth.currentUser;
    if (user == null) return;
    _currentUserId = user.uid;

    final gameId = await _gameService.findOrCreateGame(
      type: 'snakes_ladders',
      userId: user.uid,
      userName: user.displayName ?? 'لاعب',
    );

    setState(() => _gameId = gameId);
    _gameSubscription = _gameService.streamGame(gameId).listen((game) {
      if (game != null && mounted) {
        setState(() {
          _gameModel = game;
          if (game.data['positions'] == null && game.status == 'active') {
            _initializePositions(game);
          }
        });
      }
    });
  }

  void _initializePositions(GameModel game) {
    Map<String, int> positions = {};
    for (var uid in game.players) {
      positions[uid] = 0; // يبدأ اللاعب في منطقة الانتظار (خارج اللوحة)
    }
    _gameService.makeMove(game.id, {'data.positions': positions});
  }

  Future<void> _rollDice() async {
    if (_gameModel == null ||
        _gameModel!.currentTurn != _currentUserId ||
        _isRolling ||
        _gameModel!.status != 'active') {
      return;
    }

    setState(() => _isRolling = true);

    // محاكاة رمي النرد بأنيميشن
    _diceController.forward(from: 0.0);

    int finalRoll = 1;
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        _diceValue = math.Random().nextInt(6) + 1;
      });
      if (timer.tick >= 10) {
        timer.cancel();
        finalRoll = math.Random().nextInt(6) + 1;
        setState(() => _diceValue = finalRoll);
        _finishTurn(finalRoll);
      }
    });
  }

  Future<void> _finishTurn(int roll) async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isRolling = false);
    await _movePlayer(roll);
  }

  Future<void> _movePlayer(int steps) async {
    if (_gameModel == null || _currentUserId == null) return;

    Map<String, dynamic> positions = Map<String, dynamic>.from(
      _gameModel!.data['positions'] ?? {},
    );
    int currentPos = positions[_currentUserId] ?? 0;

    // معالجة الدخول للوحة (تحتاج رقم 1)
    if (currentPos == 0) {
      if (steps == 1) {
        positions[_currentUserId!] = 1;
        await _gameService.makeMove(_gameId!, {'data.positions': positions});
      } else {
        // إذا لم يحصل على 1، ينتهي دوره فوراً
        _switchToNextTurn();
      }
      return;
    }

    // حركة خطوة بخطوة للمربعات العادية
    int targetPos = currentPos + steps;
    if (targetPos > 100) {
      _switchToNextTurn();
      return;
    }

    for (int i = 1; i <= steps; i++) {
      int stepPos = currentPos + i;
      positions[_currentUserId!] = stepPos;
      await _gameService.makeMove(_gameId!, {'data.positions': positions});
      // تأخير بسيط جداً فقط للسماح للـ UI بالتحديث
      await Future.delayed(const Duration(milliseconds: 10));
    }

    // بعد انتهاء الخطوات، نتحقق من وجود سلم أو ثعبان
    int finalPos = targetPos;
    if (_ladders.containsKey(finalPos)) {
      int start = finalPos;
      int end = _ladders[finalPos]!;

      // صعود الدرج بشكل تدريجي (نقرات) وبطئ
      // سنقسم المسافة إلى 5 خطوات تقريبية ليظهر التأثير
      int stepsToClimb = 5;
      for (int s = 1; s <= stepsToClimb; s++) {
        double ratio = s / stepsToClimb;
        int intermediatePos = (start + (end - start) * ratio).round();
        positions[_currentUserId!] = intermediatePos;
        await _gameService.makeMove(_gameId!, {'data.positions': positions});
        await Future.delayed(
          const Duration(milliseconds: 300),
        ); // سرعة أبطأ للصعود
      }
      finalPos = end;
    } else if (_snakes.containsKey(finalPos)) {
      finalPos = _snakes[finalPos]!;
      positions[_currentUserId!] = finalPos;
      await Future.delayed(
        const Duration(milliseconds: 100),
      ); // النزول من الثعبان أسرع قليلاً
      await _gameService.makeMove(_gameId!, {'data.positions': positions});
    }

    // التحقق من الفوز أو تغيير الدور
    if (finalPos == 100) {
      await _gameService.makeMove(_gameId!, {
        'status': 'finished',
        'winner': _currentUserId,
      });
    } else {
      _switchToNextTurn();
    }
  }

  void _switchToNextTurn() {
    if (_gameModel == null || _currentUserId == null) return;
    String nextTurn = _gameModel!.players.firstWhere(
      (id) => id != _currentUserId,
    );
    _gameService.makeMove(_gameId!, {'currentTurn': nextTurn});
  }

  @override
  Widget build(BuildContext context) {
    // إضافة Directionality لضمان محاذاة الواجهة العربية (RTL) بشكل مثالي
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
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
            child: _gameModel == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  )
                : Column(
                    children: [
                      _buildHeader(),
                      _buildPlayersInfo(),
                      const SizedBox(height: 10),
                      Expanded(child: Center(child: _buildAdvancedBoard())),
                      _buildControls(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'الحية والدرج',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.white,
              shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 10)],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPlayersInfo() {
    if (_gameModel == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _gameModel!.players.map((uid) {
          bool isTurn = _gameModel!.currentTurn == uid;
          bool isMe = uid == _currentUserId;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isTurn
                  ? Colors.white.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isTurn
                    ? (isMe ? Colors.cyanAccent : Colors.pinkAccent)
                    : Colors.white12,
              ),
              boxShadow: isTurn
                  ? [
                      BoxShadow(
                        color: (isMe ? Colors.cyanAccent : Colors.pinkAccent)
                            .withOpacity(0.2),
                        blurRadius: 15,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMe ? Colors.cyanAccent : Colors.pinkAccent,
                    boxShadow: [
                      BoxShadow(
                        color: (isMe ? Colors.cyanAccent : Colors.pinkAccent),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _gameModel!.playerNames[uid] ?? 'لاعب',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isTurn ? FontWeight.bold : FontWeight.normal,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdvancedBoard() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          image: const DecorationImage(
            image: AssetImage('assets/images/slim.png'),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double boardSize = constraints.maxWidth;
            double cellSize = boardSize / 10;

            return Stack(
              children: [
                // تمت إزالة رسم الشبكة والسلالم والثعابين برمجياً للاعتماد على الصورة

                // رسم حجار اللاعبين
                if (_gameModel?.data['positions'] != null)
                  ..._gameModel!.players.map((uid) {
                    int pos = _gameModel!.data['positions'][uid] ?? 0;
                    bool isMe = uid == _currentUserId;

                    double rightPos;
                    double topPos;

                    if (pos == 0) {
                      // تموضع اللاعبين في منطقة الانتظار (أسفل اللوحة)
                      int playerIndex = _gameModel!.players.indexOf(uid);
                      rightPos = (playerIndex * 30.0) + 20;
                      topPos = boardSize + 10;
                    } else {
                      int idx = pos - 1;
                      int row = 9 - (idx ~/ 10);
                      int col = (idx ~/ 10) % 2 == 0
                          ? 9 - (idx % 10)
                          : (idx % 10);

                      rightPos = (col * cellSize) + (cellSize / 2) - 12;
                      topPos = (row * cellSize) + (cellSize / 2) - 12;

                      // إضافة إزاحة بسيطة إذا كان الخصم في نفس المربع
                      if (!isMe) {
                        rightPos += 8;
                        topPos += 8;
                      }
                    }

                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.linear,
                      right: rightPos,
                      top: topPos,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isMe ? Colors.cyanAccent : Colors.pinkAccent,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isMe ? Colors.cyanAccent : Colors.pinkAccent)
                                      .withOpacity(0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildControls() {
    bool isMyTurn = _gameModel?.currentTurn == _currentUserId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 30, top: 10),
      child: Column(
        children: [
          if (_gameModel?.status == 'active')
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                isMyTurn ? 'دورك! ارمِ النرد' : 'انتظر دور الخصم...',
                key: ValueKey(isMyTurn),
                style: TextStyle(
                  color: isMyTurn ? Colors.cyanAccent : Colors.white54,
                  fontFamily: 'Tajawal',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if (_gameModel?.status == 'finished')
            Text(
              _gameModel?.winner == _currentUserId
                  ? '🎉 مبروك! لقد فزت'
                  : '💔 حظ أوفر',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: _rollDice,
            child: AnimatedBuilder(
              animation: _diceAnimation,
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(_diceAnimation.value * math.pi * 2)
                    ..rotateY(_diceAnimation.value * math.pi * 2),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.white, Color(0xFFE0E0E0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                        // تم التصحيح بإزالة inset مع الإبقاء على التأثير المضيء باستخدام لون أبيض شفاف
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 5,
                          offset: const Offset(-2, -2),
                        ),
                      ],
                    ),
                    child: CustomPaint(painter: DiceDotsPainter(_diceValue)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          if (_gameModel?.status == 'waiting')
            const Text(
              'بانتظار لاعب آخر...',
              style: TextStyle(color: Colors.white54, fontFamily: 'Tajawal'),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// Custom Painters للسلالم، الثعابين، والنرد
// ---------------------------------------------------------

class BoardPainter extends CustomPainter {
  final Map<int, int> snakes;
  final Map<int, int> ladders;
  final double cellSize;

  BoardPainter(this.snakes, this.ladders, this.cellSize);

  Offset getCenterOffset(int pos) {
    int idx = pos - 1;
    int row = 9 - (idx ~/ 10);
    // تم عكس العمود ليتناسب مع RTL
    int col = (idx ~/ 10) % 2 == 0 ? 9 - (idx % 10) : (idx % 10);
    return Offset(
      (col * cellSize) + (cellSize / 2),
      (row * cellSize) + (cellSize / 2),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ladderPaint = Paint()
      ..color = Colors.amber.withOpacity(0.8)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rungPaint = Paint()
      ..color = Colors.amberAccent.withOpacity(0.9)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    ladders.forEach((start, end) {
      Offset p1 = getCenterOffset(start);
      Offset p2 = getCenterOffset(end);

      double angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      double offset = 8;
      Offset p1L = Offset(
        p1.dx + math.cos(angle + math.pi / 2) * offset,
        p1.dy + math.sin(angle + math.pi / 2) * offset,
      );
      Offset p2L = Offset(
        p2.dx + math.cos(angle + math.pi / 2) * offset,
        p2.dy + math.sin(angle + math.pi / 2) * offset,
      );
      Offset p1R = Offset(
        p1.dx + math.cos(angle - math.pi / 2) * offset,
        p1.dy + math.sin(angle - math.pi / 2) * offset,
      );
      Offset p2R = Offset(
        p2.dx + math.cos(angle - math.pi / 2) * offset,
        p2.dy + math.sin(angle - math.pi / 2) * offset,
      );

      canvas.drawLine(p1L, p2L, ladderPaint);
      canvas.drawLine(p1R, p2R, ladderPaint);

      // تم تصحيح حساب المسافة لرسم الدرجات بشكل دقيق
      int rungs = (p1 - p2).distance ~/ 15;
      for (int i = 1; i <= rungs; i++) {
        double t = i / (rungs + 1);
        Offset rL = Offset(
          ui.lerpDouble(p1L.dx, p2L.dx, t)!,
          ui.lerpDouble(p1L.dy, p2L.dy, t)!,
        );
        Offset rR = Offset(
          ui.lerpDouble(p1R.dx, p2R.dx, t)!,
          ui.lerpDouble(p1R.dy, p2R.dy, t)!,
        );
        canvas.drawLine(rL, rR, rungPaint);
      }
    });

    final snakeBodyPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    snakes.forEach((head, tail) {
      Offset pHead = getCenterOffset(head);
      Offset pTail = getCenterOffset(tail);

      Path path = Path();
      path.moveTo(pHead.dx, pHead.dy);

      Offset controlPoint1 = Offset(pHead.dx + 40, (pHead.dy + pTail.dy) / 2);
      Offset controlPoint2 = Offset(pTail.dx - 40, (pHead.dy + pTail.dy) / 2);

      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        pTail.dx,
        pTail.dy,
      );

      snakeBodyPaint.shader = ui.Gradient.linear(pHead, pTail, [
        Colors.redAccent,
        Colors.purple.shade900,
      ]);

      canvas.drawPath(path, snakeBodyPaint);

      canvas.drawCircle(pHead, 10, Paint()..color = Colors.red);
      canvas.drawCircle(
        Offset(pHead.dx - 3, pHead.dy - 2),
        2,
        Paint()..color = Colors.black,
      );
      canvas.drawCircle(
        Offset(pHead.dx + 3, pHead.dy - 2),
        2,
        Paint()..color = Colors.black,
      );
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DiceDotsPainter extends CustomPainter {
  final int value;
  DiceDotsPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;
    double w = size.width;
    double h = size.height;
    double r = w * 0.1;

    void drawDot(double x, double y) =>
        canvas.drawCircle(Offset(x, y), r, paint);

    if (value == 1 || value == 3 || value == 5) drawDot(w / 2, h / 2);
    if (value == 2 || value == 3 || value == 4 || value == 5 || value == 6) {
      drawDot(w * 0.25, h * 0.25);
      drawDot(w * 0.75, h * 0.75);
    }
    if (value == 4 || value == 5 || value == 6) {
      drawDot(w * 0.75, h * 0.25);
      drawDot(w * 0.25, h * 0.75);
    }
    if (value == 6) {
      drawDot(w * 0.25, h / 2);
      drawDot(w * 0.75, h / 2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
