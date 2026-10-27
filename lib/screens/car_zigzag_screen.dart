import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/task_service.dart';
import '../models/task_model.dart';

class CarZigzagScreen extends StatefulWidget {
  const CarZigzagScreen({super.key});

  @override
  State<CarZigzagScreen> createState() => _CarZigzagScreenState();
}

class _CarZigzagScreenState extends State<CarZigzagScreen>
    with SingleTickerProviderStateMixin {
  // ── Game State ──────────────────────────────────────────
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  int _shieldCount = 0;
  int _goldCollected = 0;

  // ── Collectibles ────────────────────────────────────────
  int _diamondsCollected = 0;
  int _metoCoinsCollected = 0;
  int _lastMetoCoinScore =
      0; // Track last score threshold for meto coin spawning

  // 4 lanes: 0 = far left, 1 = left-center, 2 = right-center, 3 = far right
  int _playerLane = 1;
  double _currentLanePos = 1.0; // Smoothed visual position
  final double _playerY = 0.75; // relative y position (0=top, 1=bottom)

  // ── Obstacles ───────────────────────────────────────────
  final List<_Obstacle> _obstacles = [];
  final List<_Coin> _coins = [];
  final List<_PowerUp> _powerUps = []; // shields, diamonds, meto coins
  final List<_Particle> _particles = [];

  // ── Timing ──────────────────────────────────────────────
  Timer? _gameTimer;
  Timer? _obstacleTimer;
  Timer? _coinTimer;
  Timer? _powerUpTimer;
  double _speed = 0.008; // Slower initial speed
  double _obstacleInterval = 1.6; // More time between obstacles

  late AnimationController _bgController;

  final Random _rng = Random();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── Images ──────────────────────────────────────────────
  ui.Image? _playerImage;
  ui.Image? _metoCoinImage;
  final List<ui.Image> _carImages = [];

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initAudio();
    _loadGameImages();
  }

  Future<void> _loadGameImages() async {
    try {
      _playerImage = await _loadAssetImage('assets/images/car/player.png');
      for (int i = 1; i <= 5; i++) {
        final img = await _loadAssetImage('assets/images/car/$i.png');
        _carImages.add(img);
      }
      _metoCoinImage = await _loadAssetImage('assets/images/coinsmeto.png');
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error loading car images: $e");
    }
  }

  Future<ui.Image> _loadAssetImage(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setAsset('assets/sounds/zikzak.mp3');
      await _audioPlayer.setLoopMode(LoopMode.all);
      await _audioPlayer.setVolume(1.0); // Set full volume
    } catch (e) {
      debugPrint("Error loading audio: $e");
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _obstacleTimer?.cancel();
    _coinTimer?.cancel();
    _bgController.dispose();
    _audioPlayer.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ── Start / Restart ──────────────────────────────────────
  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _score = 0;
      _lives = 3;
      _shieldCount = 0;
      _diamondsCollected = 0;
      _metoCoinsCollected = 0;
      _lastMetoCoinScore = 0;
      _playerLane = 2; // Start in a middle lane
      _currentLanePos = 2.0;
      _speed = 0.008;
      _obstacleInterval = 1.6;
      _obstacles.clear();
      _coins.clear();
      _powerUps.clear();
      _goldCollected = 0;
      _particles.clear();
    });
    _startTimers();
    _audioPlayer.seek(Duration.zero);
    _audioPlayer.play();
  }

  void _startTimers() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), _gameTick);

    _obstacleTimer?.cancel();
    _scheduleObstacle();

    _coinTimer?.cancel();
    _scheduleCoin();

    _powerUpTimer?.cancel();
    _schedulePowerUp();
  }

  void _scheduleObstacle() {
    _obstacleTimer?.cancel();
    _obstacleTimer = Timer(
      Duration(milliseconds: (_obstacleInterval * 1000).toInt()),
      () {
        if (!mounted || !_isPlaying) return;
        final lane = _rng.nextInt(4);
        setState(() {
          final imgIdx = _carImages.isNotEmpty
              ? _rng.nextInt(_carImages.length)
              : 0;
          _obstacles.add(
            _Obstacle(lane: lane.toDouble(), y: -0.1, imageIndex: imgIdx),
          );
        });
        _scheduleObstacle();
      },
    );
  }

  void _updateDifficulty() {
    // Step-based difficulty at score milestones
    if (_score < 2000) {
      _speed = 0.008;
      _obstacleInterval = 1.6;
    } else if (_score < 4000) {
      _speed = 0.012;
      _obstacleInterval = 1.4;
    } else if (_score < 6000) {
      _speed = 0.016;
      _obstacleInterval = 1.2;
    } else if (_score < 7000) {
      _speed = 0.020;
      _obstacleInterval = 1.0;
    } else if (_score < 8000) {
      _speed = 0.024;
      _obstacleInterval = 0.85;
    } else {
      _speed = 0.028;
      _obstacleInterval = 0.7;
    }
  }

  void _scheduleCoin() {
    _coinTimer?.cancel();
    // Rare scattered bonus coins (every 3-7 seconds)
    _coinTimer = Timer(
      Duration(milliseconds: 3000 + _rng.nextInt(4000)),
      () {
        if (!mounted || !_isPlaying) return;
        final lane = _rng.nextInt(4);
        setState(() {
          _coins.add(_Coin(lane: lane, y: -0.1));
        });
        _scheduleCoin();
      },
    );
  }

  void _schedulePowerUp() {
    _powerUpTimer?.cancel();
    _powerUpTimer = Timer(
      Duration(milliseconds: 4000 + _rng.nextInt(6000)),
      () {
        if (!mounted || !_isPlaying) return;
        final lane = _rng.nextInt(4);
        // Random: shield or diamond only
        final types = [PowerUpType.shield, PowerUpType.diamond];
        final type = types[_rng.nextInt(types.length)];
        setState(() {
          _powerUps.add(_PowerUp(lane: lane, y: -0.1, type: type));
        });
        _schedulePowerUp();
      },
    );
  }

  void _spawnMetoCoin() {
    final lane = _rng.nextInt(4);
    _powerUps.add(_PowerUp(lane: lane, y: -0.1, type: PowerUpType.metoCoin));
  }

  void _gameTick(Timer _) {
    if (!_isPlaying || _isGameOver) return;
    setState(() {
      // Move obstacles
      for (final o in _obstacles) {
        o.y += _speed;
        // Car #5 drifting logic (Very slow drift across the road)
        if (o.imageIndex == 4) {
          o.lane = o.initialLane + sin(o.y * 1.6 + o.initialLane) * 0.9;
          o.lane = o.lane.clamp(0.0, 3.0);
        }
      }
      // Move coins
      for (final c in _coins) {
        c.y += _speed;
      }
      // Move power-ups
      for (final p in _powerUps) {
        p.y += _speed;
      }
      // Move particles
      for (final p in _particles) {
        p.y += p.vy;
        p.x += p.vx;
        p.life -= 0.04;
        p.size -= 0.05;
      }
      _particles.removeWhere((p) => p.life <= 0 || p.size <= 0);

      // Smooth horizontal movement
      _currentLanePos += (_playerLane - _currentLanePos) * 0.22;

      // Remove off-screen
      _obstacles.removeWhere((o) => o.y > 1.15);
      _coins.removeWhere((c) => c.y > 1.15);
      _powerUps.removeWhere((p) => p.y > 1.15);

      // Score tick
      _score++;
      if (_score > _highScore) _highScore = _score;
      _updateDifficulty();

      // Spawn meto coin every 2000 points
      final currentThreshold = (_score ~/ 2000) * 2000;
      if (currentThreshold > 0 && currentThreshold > _lastMetoCoinScore) {
        _lastMetoCoinScore = currentThreshold;
        _spawnMetoCoin();
      }

      // Collision detection
      _checkCollisions();
    });
  }

  void _checkCollisions() {
    // Obstacle collision
    for (final o in List.of(_obstacles)) {
      if ((o.lane - _currentLanePos).abs() < 0.7 &&
          (o.y - _playerY).abs() < 0.08) {
        _obstacles.remove(o);
        if (_shieldCount > 0) {
          _shieldCount--;
          _spawnCoinEffect(_playerLane, _playerY);
          HapticFeedback.mediumImpact();
        } else {
          _lives--;
          _spawnExplosion(_playerLane, _playerY);
          HapticFeedback.heavyImpact();
          if (_lives <= 0) {
            _gameOver();
          }
        }
        break;
      }
    }
    // Coin collection
    for (final c in List.of(_coins)) {
      if ((c.lane - _currentLanePos).abs() < 0.6 &&
          (c.y - _playerY).abs() < 0.06) {
        _coins.remove(c);
        _score += 50;
        _goldCollected++; // Track for daily reward
        HapticFeedback.lightImpact();
        _spawnCoinEffect(c.lane, c.y);
        break;
      }
    }
    // Power-up collection
    for (final p in List.of(_powerUps)) {
      if ((p.lane - _currentLanePos).abs() < 0.75 &&
          (p.y - _playerY).abs() < 0.1) {
        _powerUps.remove(p);
        HapticFeedback.lightImpact();
        _spawnCoinEffect(p.lane, p.y);
        switch (p.type) {
          case PowerUpType.shield:
            _shieldCount++;
            break;
          case PowerUpType.diamond:
            _diamondsCollected++;
            _score += 100;
            break;
          case PowerUpType.metoCoin:
            _metoCoinsCollected++;
            _score += 200;
            break;
        }
        break;
      }
    }
  }

  void _spawnExplosion(int lane, double y) {
    for (int i = 0; i < 12; i++) {
      _particles.add(
        _Particle(
          lane: lane,
          y: y,
          vx: (_rng.nextDouble() - 0.5) * 0.04,
          vy: (_rng.nextDouble() - 0.5) * 0.04,
          color: [Colors.orange, Colors.red, Colors.yellow][_rng.nextInt(3)],
          life: 1.0,
          size: 8 + _rng.nextDouble() * 8,
        ),
      );
    }
  }

  void _spawnCoinEffect(int lane, double y) {
    for (int i = 0; i < 6; i++) {
      _particles.add(
        _Particle(
          lane: lane,
          y: y,
          vx: (_rng.nextDouble() - 0.5) * 0.02,
          vy: -_rng.nextDouble() * 0.03,
          color: Colors.yellow,
          life: 1.0,
          size: 5 + _rng.nextDouble() * 5,
        ),
      );
    }
  }

  void _gameOver() {
    _isPlaying = false;
    _isGameOver = true;
    _gameTimer?.cancel();
    _obstacleTimer?.cancel();
    _coinTimer?.cancel();
    _powerUpTimer?.cancel();
    _audioPlayer.stop();
    HapticFeedback.vibrate();
    _saveRewardsToWallet();
  }

  Future<void> _saveRewardsToWallet() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_diamondsCollected <= 0 && _metoCoinsCollected <= 0 && _goldCollected <= 0) return;

    try {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month}-${now.day}";
      final statsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('game_stats')
          .doc('car_zigzag_daily');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final statsSnapshot = await transaction.get(statsRef);
        int dailyDiamonds = 0;
        int dailyMeto = 0;
        int dailyGold = 0;

        if (statsSnapshot.exists) {
          final data = statsSnapshot.data()!;
          final lastReset = data['last_reset_date'] as String?;
          if (lastReset == todayStr) {
            dailyDiamonds = data['diamonds_count'] ?? 0;
            dailyMeto = data['meto_count'] ?? 0;
            dailyGold = data['gold_count'] ?? 0;
          }
        }

        // Calculate how much can be added
        final int canAddDiamonds = (10 - dailyDiamonds).clamp(0, _diamondsCollected);
        final int canAddMeto = (10 - dailyMeto).clamp(0, _metoCoinsCollected);
        // User requested 1000 gold per day
        final int canAddGold = (1000 - dailyGold).clamp(0, _goldCollected * 100); // 100 gold per coin collected

        if (canAddDiamonds <= 0 && canAddMeto <= 0 && canAddGold <= 0) {
          debugPrint("[CarZigzag] Daily limits reached. No rewards saved.");
          return;
        }

        // Update Wallet
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final walletUpdates = <String, dynamic>{};
        if (canAddDiamonds > 0) {
          walletUpdates['diamonds'] = FieldValue.increment(canAddDiamonds);
        }
        if (canAddMeto > 0) {
          walletUpdates['meto_chips'] = FieldValue.increment(canAddMeto);
        }
        if (canAddGold > 0) {
          walletUpdates['coins'] = FieldValue.increment(canAddGold);
        }
        transaction.update(userRef, walletUpdates);

        // Update Daily Stats
        transaction.set(statsRef, {
          'last_reset_date': todayStr,
          'diamonds_count': dailyDiamonds + canAddDiamonds,
          'meto_count': dailyMeto + canAddMeto,
          'gold_count': dailyGold + canAddGold,
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint("[CarZigzag] Saved: $canAddDiamonds Diamonds, $canAddMeto Meto, $canAddGold Gold.");
      });
      
      TaskService().incrementTaskProgress(uid, TaskType.playCarRace);
    } catch (e) {
      debugPrint('Error saving game rewards with limits: $e');
    }
  }

  void _moveLeft() {
    if (!_isPlaying) return;
    if (_playerLane > 0) {
      setState(() => _playerLane--);
      HapticFeedback.selectionClick();
    }
  }

  void _moveRight() {
    if (!_isPlaying) return;
    if (_playerLane < 3) {
      setState(() => _playerLane++);
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Gradient Layer
          Positioned.fill(
            child: Container(
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
            ),
          ),
          // Dark Overlay for readability
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
          // Game canvas
          GestureDetector(
            onHorizontalDragEnd: (d) {
              if (d.primaryVelocity != null) {
                if (d.primaryVelocity! < -100) _moveLeft();
                if (d.primaryVelocity! > 100) _moveRight();
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final roadWidth = w * 0.85; // Wider road for 4 lanes
                final roadLeft = (w - roadWidth) / 2;
                final laneWidth = roadWidth / 4;

                return AnimatedBuilder(
                  animation: _bgController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(w, h),
                      painter: _GamePainter(
                        bgOffset: _bgController.value,
                        roadLeft: roadLeft,
                        roadWidth: roadWidth,
                        laneWidth: laneWidth,
                        laneCount: 4, // Added to handle dynamic lanes
                        playerLane: _currentLanePos, // Pass smooth position
                        playerY: _playerY,
                        obstacles: _obstacles,
                        coins: _coins,
                        powerUps: _powerUps,
                        particles: _particles,
                        isPlaying: _isPlaying,
                        speed: _speed,
                        playerImage: _playerImage,
                        obstacleImages: _carImages,
                        metoCoinImage: _metoCoinImage,
                        hasShield: _shieldCount > 0,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // HUD ─────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  // Score
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '$_score',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF00E5FF),
                          fontFamily: 'Tajawal',
                          shadows: [
                            Shadow(color: Color(0xFF00E5FF), blurRadius: 12),
                          ],
                        ),
                      ),
                      Text(
                        'أفضل: $_highScore',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                  // Lives
                  Row(
                    children: List.generate(
                      3,
                      (i) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: i < _lives ? Colors.red : Colors.white10,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Start screen
          if (!_isPlaying && !_isGameOver) _buildStartScreen(),

          // Game Over screen
          if (_isGameOver) _buildGameOverScreen(),

          // Control buttons
          if (_isPlaying)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlBtn(Icons.arrow_back_ios_rounded, _moveLeft),
                    _buildControlBtn(
                      Icons.arrow_forward_ios_rounded,
                      _moveRight,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black54,
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF00E5FF), size: 36),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
              blurRadius: 40,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏎️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            const Text(
              'زك زك',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Color(0xFF00E5FF),
                fontFamily: 'Tajawal',
                shadows: [Shadow(color: Color(0xFF00E5FF), blurRadius: 16)],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'سباق السيارات',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'تجنب العوائق واجمع العملات!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white54,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 28),
            // Instruction row
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _instructionChip('👈 سحب لليسار'),
                _instructionChip('سحب لليمين 👉'),
              ],
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _startGame,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Text(
                  'ابدأ اللعب',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A0A).withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 40,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💥', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            const Text(
              'انتهت اللعبة!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.redAccent,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 16),
            _scoreRow('نتيجتك', '$_score', const Color(0xFF00E5FF)),
            const SizedBox(height: 6),
            _scoreRow(
              'أفضل نتيجة',
              '$_highScore',
              _score >= _highScore ? Colors.amber : Colors.white54,
            ),
            // Collectibles summary
            if (_diamondsCollected > 0 || _metoCoinsCollected > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'الغنائم',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        if (_diamondsCollected > 0)
                          _collectibleChip(
                            '💎',
                            '$_diamondsCollected',
                            const Color(0xFF00BCD4),
                          ),
                        if (_metoCoinsCollected > 0)
                          _collectibleChip(
                            '🪙',
                            '$_metoCoinsCollected',
                            const Color(0xFFFFD700),
                            imagePath: 'assets/images/coinsmeto.png',
                          ),
                      ],
                    ),
                    if (_diamondsCollected > 0 || _metoCoinsCollected > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'تم إضافتها إلى محفظتك ✅',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.greenAccent.withValues(alpha: 0.8),
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _actionBtn(
                  icon: Icons.replay_rounded,
                  label: 'مجدداً',
                  gradient: const [Color(0xFF00B4D8), Color(0xFF0077B6)],
                  glowColor: const Color(0xFF00E5FF),
                  onTap: _startGame,
                ),
                _actionBtn(
                  icon: Icons.home_rounded,
                  label: 'خروج',
                  gradient: const [Color(0xFF7B2D00), Color(0xFF4A0000)],
                  glowColor: Colors.red,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _collectibleChip(String emoji, String count, Color color, {String? imagePath}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imagePath != null)
            Image.asset(imagePath, width: 22, height: 22)
          else
            Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            count,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white70,
          fontFamily: 'Tajawal',
        ),
      ),
    );
  }

  Widget _scoreRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white54,
            fontFamily: 'Tajawal',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: valueColor,
            fontFamily: 'Tajawal',
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required Color glowColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data Models ──────────────────────────────────────────────────────────────

enum PowerUpType { shield, diamond, metoCoin }

class _Obstacle {
  double lane;
  double y;
  int imageIndex;
  final double initialLane;
  _Obstacle({required this.lane, required this.y, this.imageIndex = 0})
    : initialLane = lane.toDouble();
}

class _Coin {
  int lane;
  double y;
  _Coin({required this.lane, required this.y});
}

class _PowerUp {
  int lane;
  double y;
  PowerUpType type;
  _PowerUp({required this.lane, required this.y, required this.type});
}

class _Particle {
  int lane;
  double y;
  double x;
  double vx;
  double vy;
  Color color;
  double life;
  double size;
  _Particle({
    required this.lane,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.life,
    required this.size,
    double? x,
  }) : x = x ?? 0;
}

// ── Custom Painter ───────────────────────────────────────────────────────────

class _GamePainter extends CustomPainter {
  final double bgOffset;
  final double roadLeft;
  final double roadWidth;
  final double laneWidth;
  final double playerLane; // Changed from int
  final double playerY;
  final List<_Obstacle> obstacles;
  final List<_Coin> coins;
  final List<_PowerUp> powerUps;
  final List<_Particle> particles;
  final bool isPlaying;
  final double speed;
  final ui.Image? playerImage;
  final ui.Image? metoCoinImage;
  final List<ui.Image> obstacleImages;
  final bool hasShield;
  final int laneCount;

  static const Color _roadColor = Color(0xFF1A1A2E);
  static const Color _lineColor = Color(0xFFFFD700);
  static const Color _playerColor = Color(0xFF00E5FF);
  static const Color _obstacleColor = Color(0xFFFF1744);
  static const Color _grassColor = Color(0xFF0D3320);
  static const Color _grassColor2 = Color(0xFF0F4228);

  _GamePainter({
    required this.bgOffset,
    required this.roadLeft,
    required this.roadWidth,
    required this.laneWidth,
    required this.playerLane,
    required this.playerY,
    required this.obstacles,
    required this.coins,
    required this.powerUps,
    required this.particles,
    required this.isPlaying,
    required this.speed,
    this.playerImage,
    this.metoCoinImage,
    required this.obstacleImages,
    required this.hasShield,
    required this.laneCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawRoad(canvas, size);
    _drawObstacles(canvas, size);
    _drawCoins(canvas, size);
    _drawPowerUps(canvas, size);
    _drawParticles(canvas, size);
    if (isPlaying) _drawPlayer(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    // Sky gradient
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF000D1A), Color(0xFF001F3F)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // Stars
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    final rng = Random(42);
    for (int i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.5;
      final twinkle = (sin((bgOffset * 6.28 + i) * 3) + 1) / 2;
      canvas.drawCircle(
        Offset(x, y),
        1.2 * twinkle,
        starPaint..color = Colors.white.withValues(alpha: 0.3 + 0.5 * twinkle),
      );
    }

    // Grass left
    final grassPaint = Paint()..color = _grassColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, roadLeft, size.height), grassPaint);

    // Grass right
    canvas.drawRect(
      Rect.fromLTWH(
        roadLeft + roadWidth,
        0,
        size.width - roadLeft - roadWidth,
        size.height,
      ),
      grassPaint,
    );

    // Grass decoration (stripes)
    final stripePaint = Paint()..color = _grassColor2;
    const stripeCount = 6;
    for (int i = 0; i < stripeCount; i++) {
      final stripeY = ((bgOffset * 2 + i / stripeCount) % 1.0) * size.height;
      canvas.drawRect(Rect.fromLTWH(0, stripeY, roadLeft, 30), stripePaint);
      canvas.drawRect(
        Rect.fromLTWH(
          roadLeft + roadWidth,
          stripeY,
          size.width - roadLeft - roadWidth,
          30,
        ),
        stripePaint,
      );
    }
  }

  void _drawRoad(Canvas canvas, Size size) {
    // Main road surface
    final roadPaint = Paint()..color = _roadColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(roadLeft, 0, roadWidth, size.height),
        const Radius.circular(0),
      ),
      roadPaint,
    );

    // Road edge lights
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(roadLeft, 0),
      Offset(roadLeft, size.height),
      edgePaint,
    );
    canvas.drawLine(
      Offset(roadLeft + roadWidth, 0),
      Offset(roadLeft + roadWidth, size.height),
      edgePaint,
    );

    // Road edge glow
    final glowEdgePaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.1)
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(
      Offset(roadLeft, 0),
      Offset(roadLeft, size.height),
      glowEdgePaint,
    );
    canvas.drawLine(
      Offset(roadLeft + roadWidth, 0),
      Offset(roadLeft + roadWidth, size.height),
      glowEdgePaint,
    );

    // Lane dashes
    final dashPaint = Paint()
      ..color = _lineColor.withValues(alpha: 0.5)
      ..strokeWidth = 2.5;
    const dashLen = 30.0;
    const dashGap = 20.0;

    for (int lane = 1; lane < laneCount; lane++) {
      final laneX = roadLeft + laneWidth * lane;
      double y =
          -(dashLen) +
          (bgOffset * (dashLen + dashGap) * 4) % (dashLen + dashGap);
      while (y < size.height) {
        canvas.drawLine(
          Offset(laneX, y),
          Offset(laneX, y + dashLen),
          dashPaint,
        );
        y += dashLen + dashGap;
      }
    }
  }

  void _drawPlayer(Canvas canvas, Size size) {
    final cx = roadLeft + laneWidth * playerLane + laneWidth / 2;
    final cy = size.height * playerY;

    // Glow under car
    final glowPaint = Paint()
      ..color = _playerColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 20), width: 50, height: 16),
      glowPaint,
    );

    // Shield glow effect
    if (hasShield) {
      final shieldGlow = Paint()
        ..color = const Color(0xFF4CAF50).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(Offset(cx, cy), 42, shieldGlow);
      final shieldRing = Paint()
        ..color = const Color(0xFF4CAF50).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset(cx, cy), 38, shieldRing);
    }

    if (playerImage != null) {
      _drawImageCar(canvas, cx, cy, playerImage!);
    } else {
      _drawCar(canvas, cx, cy, _playerColor, isPlayer: true);
    }
  }

  void _drawCar(
    Canvas canvas,
    double cx,
    double cy,
    Color color, {
    bool isPlayer = false,
  }) {
    final bodyPaint = Paint()..color = color;
    final darkPaint = Paint()..color = color.withValues(alpha: 0.6);
    final windowPaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.8);
    final tirePaint = Paint()..color = Colors.grey.shade800;
    final wheelPaint = Paint()..color = Colors.grey.shade400;

    final carW = isPlayer ? 46.0 : 42.0;
    final carH = isPlayer ? 84.0 : 76.0;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + carH / 2 + 4),
        width: carW + 10,
        height: 12,
      ),
      shadowPaint,
    );

    // Car body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: carW, height: carH),
      const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Hood top (darker)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy - carH * 0.25),
          width: carW - 6,
          height: carH * 0.3,
        ),
        const Radius.circular(6),
      ),
      darkPaint,
    );

    // Windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy - carH * 0.15),
          width: carW - 10,
          height: carH * 0.18,
        ),
        const Radius.circular(4),
      ),
      windowPaint,
    );

    // Front lights
    final lightPaint = Paint()..color = Colors.yellow.withValues(alpha: 0.9);
    canvas.drawCircle(
      Offset(cx - carW / 2 + 5, cy - carH / 2 + 5),
      4,
      lightPaint,
    );
    canvas.drawCircle(
      Offset(cx + carW / 2 - 5, cy - carH / 2 + 5),
      4,
      lightPaint,
    );

    // Rear lights
    final rearLightPaint = Paint()..color = Colors.red.withValues(alpha: 0.9);
    canvas.drawCircle(
      Offset(cx - carW / 2 + 5, cy + carH / 2 - 5),
      4,
      rearLightPaint,
    );
    canvas.drawCircle(
      Offset(cx + carW / 2 - 5, cy + carH / 2 - 5),
      4,
      rearLightPaint,
    );

    // Tires
    for (final dx in [-carW / 2 - 4, carW / 2 + 4]) {
      for (final dy in [-carH * 0.3, carH * 0.3]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx + dx, cy + dy),
              width: 8,
              height: 14,
            ),
            const Radius.circular(3),
          ),
          tirePaint,
        );
        canvas.drawCircle(Offset(cx + dx, cy + dy), 3, wheelPaint);
      }
    }

    // Player glow
    if (isPlayer) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(bodyRect, glowPaint);
    }
  }

  void _drawObstacles(Canvas canvas, Size size) {
    for (final o in obstacles) {
      final cx = roadLeft + laneWidth * o.lane + laneWidth / 2;
      final cy = size.height * o.y;

      if (obstacleImages.isNotEmpty && o.imageIndex < obstacleImages.length) {
        // Removed tilting/wobbling for car #5 at user request
        _drawImageCar(
          canvas,
          cx,
          cy,
          obstacleImages[o.imageIndex],
          rotation: 0,
        );
      } else {
        _drawCar(canvas, cx, cy, _obstacleColor);
      }
    }
  }

  void _drawImageCar(
    Canvas canvas,
    double cx,
    double cy,
    ui.Image image, {
    double rotation = 0,
  }) {
    const carW = 46.0;
    const carH = 88.0;

    canvas.save();
    canvas.translate(cx, cy);
    if (rotation != 0) {
      canvas.rotate(rotation);
    }

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    // Draw shadow slightly offset and smaller if rotating
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, carH / 2),
        width: carW + 12,
        height: 14,
      ),
      shadowPaint,
    );

    final destRect = Rect.fromCenter(
      center: Offset(0, 0),
      width: carW,
      height: carH,
    );
    paintImage(
      canvas: canvas,
      rect: destRect,
      image: image,
      fit: BoxFit.contain,
    );
    canvas.restore();
  }
  
  void _drawCoins(Canvas canvas, Size size) {
    final coinPaintBody = Paint()..color = Colors.amber;
    final coinGlowPaintBody = Paint()
      ..color = Colors.amber.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    for (final c in coins) {
      final cx = roadLeft + laneWidth * c.lane + laneWidth / 2;
      final cy = size.height * c.y;
      canvas.drawCircle(Offset(cx, cy), 12, coinGlowPaintBody);
      canvas.drawCircle(Offset(cx, cy), 8, coinPaintBody);
      
      final tp = TextPainter(
        text: const TextSpan(
          text: '✦',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }


  void _drawPowerUps(Canvas canvas, Size size) {
    for (final p in powerUps) {
      final cx = roadLeft + laneWidth * p.lane + laneWidth / 2;
      final cy = size.height * p.y;

      switch (p.type) {
        case PowerUpType.shield:
          // Shield: green circle with icon
          final glow = Paint()
            ..color = const Color(0xFF4CAF50).withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
          canvas.drawCircle(Offset(cx, cy), 18, glow);
          final bg = Paint()..color = const Color(0xFF2E7D32);
          canvas.drawCircle(Offset(cx, cy), 14, bg);
          final tp = TextPainter(
            text: const TextSpan(text: '🛡️', style: TextStyle(fontSize: 16)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
          break;
        case PowerUpType.diamond:
          // Diamond: cyan glow
          final glow = Paint()
            ..color = const Color(0xFF00BCD4).withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
          canvas.drawCircle(Offset(cx, cy), 18, glow);
          final bg = Paint()..color = const Color(0xFF006064);
          canvas.drawCircle(Offset(cx, cy), 14, bg);
          final tp = TextPainter(
            text: const TextSpan(text: '💎', style: TextStyle(fontSize: 16)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
          break;
        case PowerUpType.metoCoin:
          // Meto coin: distinctly green glow with pulsing
          final pulse = (sin(bgOffset * 6.28 * 3) + 1) / 2;
          final glow = Paint()
            ..color = const Color(
              0xFF4CAF50, // Distinct Green
            ).withValues(alpha: 0.35 + pulse * 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
          canvas.drawCircle(Offset(cx, cy), 20, glow);

          if (metoCoinImage != null) {
            paintImage(
              canvas: canvas,
              rect: Rect.fromCenter(center: Offset(cx, cy), width: 55, height: 55),
              image: metoCoinImage!,
              fit: BoxFit.contain,
            );
          } else {
            final bg = Paint()..color = const Color(0xFF1B5E20); // Darker Green inside
            canvas.drawCircle(Offset(cx, cy), 15, bg);
            final tp = TextPainter(
              text: const TextSpan(text: '🪙', style: TextStyle(fontSize: 18)),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
          }
          break;
      }
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    for (final p in particles) {
      final cx =
          roadLeft + laneWidth * p.lane + laneWidth / 2 + p.x * size.width;
      final cy = size.height * p.y;
      final paint = Paint()..color = p.color.withValues(alpha: p.life);
      canvas.drawCircle(Offset(cx, cy), max(0, p.size), paint);
    }
  }

  @override
  bool shouldRepaint(_GamePainter old) => true;
}
