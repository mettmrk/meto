import 'dart:math' as math;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:just_audio/just_audio.dart';
import '../services/reward_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../services/task_service.dart';
import '../models/task_model.dart';

class RouletteScreen extends StatefulWidget {
  const RouletteScreen({super.key});

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _glowController;
  final RewardService _rewardService = RewardService();
  bool _isSpinning = false;
  bool _isLanding = false;
  double _currentRotation = 0.0;
  Curve _currentCurve = Curves.linear;
  String? _statusMessage;
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _visibleCoins = 0;
  int _visibleDiamonds = 0;
  int _visibleMetoChips = 0;
  int _visibleFreeSpins = 0;
  bool _hasDailyFreeSpin = true;
  StreamSubscription? _userSub;

  // الترتيب حسب الصورة الجديدة (9 أقسام) يبدأ من الأعلى (السهم يشير لأسفل) وباتجاه عقارب الساعة
  final List<Map<String, dynamic>> _items = [
    {'type': 'diamonds', 'amount': 20, 'label': '20 ماسة'}, // 0: الأعلى (ماسات وذهب)
    {'type': 'red_box', 'amount': 0, 'label': 'الصندوق الأحمر'}, // 1: الصندوق الأحمر
    {'type': 'empty', 'amount': 0, 'label': 'صندوق فارغ'}, // 2: الصندوق البني المفتوح
    {'type': 'mixed', 'amount': 0, 'label': 'عملات وماس'}, // 3: عملات خضراء وماس
    {'type': 'yellow_box', 'amount': 0, 'label': 'الصندوق الأصفر'}, // 4: الصندوق الأصفر
    {'type': 'rocket', 'amount': 100, 'label': '100 ميتو'}, // 5: الصاروخ
    {'type': 'free_spin', 'amount': 1, 'label': 'فرة مجانية'}, // 6: الأسهم الخضراء
    {'type': 'meto_chips', 'amount': 5, 'label': '5 ميتو'}, // 7: العملات الخضراء
    {'type': 'points', 'amount': 1000, 'label': '1000 ذهب'}, // 8: العملات الذهبية
  ];

  Tween<double>? _spinTween;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isLanding) {
        setState(() {
          _isSpinning = false;
          _isLanding = false;
        });
        _glowController.stop();
        _glowController.reset();
        _audioPlayer.stop();
        if (_statusMessage != null) _showResultDialog(_statusMessage!);
      }
    });
    _loadSound();
    _fetchInitialData();
  }

  void _fetchInitialData() {
    final uid = auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((doc) {
            if (doc.exists && mounted) {
              final data = doc.data()!;
              final user = User.fromMap(data, uid);

              final lastSpinTs = data['lastRouletteSpin'] as Timestamp?;
              bool dailyFreeSpin = true;
              if (lastSpinTs != null) {
                final lastSpin = lastSpinTs.toDate();
                final now = DateTime.now();
                if (lastSpin.year == now.year &&
                    lastSpin.month == now.month &&
                    lastSpin.day == now.day) {
                  dailyFreeSpin = false;
                }
              }

              _visibleCoins = user.coins;
              _visibleDiamonds = user.diamonds;
              _visibleMetoChips = user.meto_chips;
              _visibleFreeSpins = user.freeSpins;
              _hasDailyFreeSpin = dailyFreeSpin;

              if (!_isSpinning) {
                setState(() {});
              }
            }
          });
    }
  }

  Future<void> _loadSound() async {
    try {
      await _audioPlayer.setAsset('assets/sounds/roulette.mp3');
    } catch (e) {
      debugPrint('Sound Error: $e');
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _controller.dispose();
    _glowController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _spin() async {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _isLanding = false;
      _statusMessage = null;
      // تحديث لحظي: إذا كانت الفرة مجانية (يومية)، عطّلها فوراً ليتغير لون الزر
      if (_hasDailyFreeSpin) {
        _hasDailyFreeSpin = false;
      } else if (_visibleFreeSpins > 0) {
        _visibleFreeSpins--;
      }
    });
    _glowController.repeat(reverse: true);

    try {
      await _audioPlayer.seek(Duration.zero);
      _audioPlayer.play();
    } catch (_) {}
    _controller.reset();
    _currentCurve = Curves.linear;
    _controller.duration = const Duration(seconds: 8);
    _spinTween = Tween<double>(
      begin: _currentRotation,
      end: _currentRotation + (16 * 2 * math.pi),
    );
    _controller.forward();

    try {
      final uid = auth.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw 'يجب تسجيل الدخول';

      final result = await _rewardService.spinRoulette(uid);
      final rewardType = result['rewardType'];
      final amount = result['amount'];
      final originalRewardType = result['originalRewardType'] ?? rewardType;

      int targetIndex = _items.indexWhere((item) => item['type'] == originalRewardType);

      if (targetIndex == -1) targetIndex = 2; // الافتراضي صندوق فارغ (Index 2)

      final currentValue = _controller.value;
      final currentAngle = _spinTween!.transform(currentValue);

      _controller.stop();
      _controller.reset();

      final double sectorAngle = (2 * math.pi) / _items.length;
      double finalAngle = -(targetIndex * sectorAngle);

      double minRotation = currentAngle + (4 * 2 * math.pi);
      int fullTurns = ((minRotation - finalAngle) / (2 * math.pi)).ceil();
      finalAngle += (fullTurns * 2 * math.pi);

      _currentCurve = Curves.easeOutCubic;
      _controller.duration = const Duration(seconds: 5);
      _spinTween = Tween<double>(begin: currentAngle, end: finalAngle);
      _currentRotation = finalAngle;
      _isLanding = true;
      _controller.forward();

      _prepareStatusMessage(
        rewardType,
        amount,
        result['isSurprise'] ?? false,
        result['payoutType'] ?? '',
      );

      TaskService().incrementTaskProgress(uid, TaskType.spinWheel);
    } catch (e) {
      _controller.stop();
      _controller.reset();
      setState(() {
        _isSpinning = false;
        _isLanding = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  void _prepareStatusMessage(
    String type,
    int amount,
    bool isSurprise,
    String payout,
  ) {
    if (type == 'empty') {
      _statusMessage = 'حظاً أوفر، الصندوق فارغ! 😔';
    } else if (isSurprise) {
      String currency = 'ذهب';
      if (payout == 'diamonds') currency = 'ماسة';
      if (payout == 'meto_chips') currency = 'عملة ميتو';
      _statusMessage = '🎁 مبروك! حصلت على $amount $currency';
    } else if (type == 'free_spin') {
      _statusMessage = '🔄 لفة إضافية مجانية!';
    } else {
      String currency = 'ذهب';
      if (payout == 'diamonds') currency = 'ماسة';
      if (payout == 'meto_chips' || type == 'meto_chips' || type == 'rocket')
        currency = 'عملة ميتو';
      _statusMessage = '🎉 ربحت $amount $currency!';
    }
  }

  void _showResultDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً', style: TextStyle(color: Colors.amber)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF009688),
      appBar: AppBar(
        title: const Text('عجلة الحظ', style: TextStyle(color: Colors.amber)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<User?>(
        stream: UserService().getUserStream(
          auth.FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData && !_isSpinning) {
            final user = snapshot.data!;
            _visibleCoins = user.coins;
            _visibleDiamonds = user.diamonds;
            _visibleMetoChips = user.meto_chips;
            _visibleFreeSpins = user.freeSpins;
          }

          return Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 60,
                      color: Colors.amber,
                    ),
                    SizedBox(
                      height: 380,
                      width: 380,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isSpinning)
                            AnimatedBuilder(
                              animation: _glowController,
                              builder: (context, _) {
                                return Container(
                                  width: 380 + (_glowController.value * 30),
                                  height: 380 + (_glowController.value * 30),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(
                                          0.3 + (_glowController.value * 0.3),
                                        ),
                                        blurRadius:
                                            30 + (_glowController.value * 25),
                                        spreadRadius:
                                            5 + (_glowController.value * 10),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              final value = CurvedAnimation(
                                parent: _controller,
                                curve: _currentCurve,
                              ).value;
                              final rotation =
                                  _spinTween?.transform(value) ??
                                  _currentRotation;
                              return Transform.rotate(
                                angle: rotation,
                                child: child,
                              );
                            },
                            child: Image.asset(
                              'assets/images/roolet.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                    Builder(
                      builder: (context) {
                        bool isFree =
                            _hasDailyFreeSpin || _visibleFreeSpins > 0;
                        return IgnorePointer(
                          ignoring:
                              _isSpinning || (!isFree && _visibleCoins < 500),
                          child: Opacity(
                            opacity:
                                (_isSpinning ||
                                    (!isFree && _visibleCoins < 500))
                                ? 0.4
                                : 1.0,
                            child: GestureDetector(
                              onTap: _spin,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 60,
                                  vertical: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: isFree
                                      ? const Color(0xFF2ECC71)
                                      : Colors.amber,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isFree
                                          ? const Color(
                                              0xFF2ECC71,
                                            ).withOpacity(0.5)
                                          : Colors.amber.withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isFree)
                                      const Icon(
                                        Icons.monetization_on,
                                        color: Colors.black,
                                        size: 20,
                                      ),
                                    if (!isFree) const SizedBox(width: 8),
                                    Text(
                                      isFree ? 'مجاناً' : '500',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: isFree
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 15,
                left: 15,
                right: 15,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBalance(
                      Icons.monetization_on,
                      '$_visibleCoins',
                      Colors.amber,
                    ),
                    const SizedBox(width: 10),
                    _buildBalance(
                      Icons.diamond,
                      '$_visibleDiamonds',
                      Colors.blueAccent,
                    ),
                    const SizedBox(width: 10),
                    _buildBalance(
                      'assets/images/coinsmeto.png',
                      '$_visibleMetoChips',
                      const Color(0xFF00BFA5),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalance(dynamic iconOrImage, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconOrImage is String)
            Image.asset(iconOrImage, width: 18, height: 18)
          else if (iconOrImage is IconData)
            Icon(iconOrImage, color: color, size: 18),
          const SizedBox(width: 5),
          Text(
            val,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
