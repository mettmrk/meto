import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../services/reward_service.dart';
import 'store_screen.dart';
import 'daily_leaderboard_screen.dart';
import 'agents_screen.dart';

/// ألوان الصفحة في مكان واحد لسهولة التعديل
class _C {
  static const bg1 = Color(0xFF02181B);
  static const bg2 = Color(0xFF04262A);
  static const bg3 = Color(0xFF011416);
  static const card = Color(0xFF062326);
  static const cyan = Color(0xFF00E5FF);
  static const teal = Color(0xFF00BFA5);
  static const tealDark = Color(0xFF00796B);
  static const gold = Color(0xFFFFC107);
  static const goldSoft = Color(0xFFFFD54F);
}

class DailyRewardScreen extends StatefulWidget {
  const DailyRewardScreen({super.key});

  @override
  State<DailyRewardScreen> createState() => _DailyRewardScreenState();
}

class _DailyRewardScreenState extends State<DailyRewardScreen>
    with TickerProviderStateMixin {
  /// إذا كانت الصفحة داخل شريط تنقل سفلي يغطي المحتوى (extendBody)
  /// ارفع هذه القيمة (مثلاً 90) حتى لا تختفي البطاقات خلف الشريط.
  static const double _bottomInset = 8;

  static const Duration _cycle = Duration(hours: 24);

  final RewardService _rewardService = RewardService();
  late final AnimationController _bgController;
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final AnimationController _rotationController;
  Stream<Map<String, dynamic>>? _counterStream;

  Timer? _timer;
  late final Timer _tipTimer;
  bool _isLoading = true;
  Duration _serverTimeOffset = Duration.zero;

  final ValueNotifier<int> _tipNotifier = ValueNotifier(0);
  final ValueNotifier<int> _tickNotifier = ValueNotifier(0);

  final List<String> _premiumTips = const [
    "كلما كان فريقك أكبر كلما زادت أرباح التعدين الجماعي",
    "قم بتطوير العداد للحصول على مكافآت أكثر مضاعفة.",
    "عمر العداد 6 أشهر، استغل كل يوم لزيادة أرباحك.",
    "جميع العدادات قابلة للشراء مرة واحدة فقط كل (6 أشهر)",
    "يمكن شراء باقة المبتدئين مرتين خلال فترة (6 أشهر).",
    "نظام التعدين الذكي يعمل بدقة عالية لضمان أفضل عائد لك.",
  ];

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _tipTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _tipNotifier.value = (_tipNotifier.value + 1) % _premiumTips.length;
      }
    });

    final uid = auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _counterStream = _rewardService.getCounterState(uid);
      _rewardService.cleanupExpiredTransactions(uid);
    }

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) _tickNotifier.value++;
    });

    _syncServerTime();
  }

  Future<void> _syncServerTime() async {
    try {
      // وقت سيرفر Firebase (حماية من التلاعب بساعة الجهاز)
      final serverTime = await _rewardService.getServerTime();
      final localTime = DateTime.now().toUtc();
      _serverTimeOffset = serverTime.difference(localTime);
    } catch (e) {
      debugPrint("Server time sync error (fallback to local time): $e");
      _serverTimeOffset = Duration.zero;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _entranceController.forward();
      }
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _timer?.cancel();
    _tipTimer.cancel();
    _tickNotifier.dispose();
    _tipNotifier.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Duration _elapsed(DateTime start) =>
      DateTime.now().add(_serverTimeOffset).difference(start);

  double _progressOf(bool active, DateTime? start) {
    if (!active || start == null) return 0.0;
    return (_elapsed(start).inMilliseconds / _cycle.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  String _formatNumber(num number) {
    String f(num n, String s) =>
        '${n.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}$s';
    if (number >= 1000000000000) return f(number / 1000000000000, 't');
    if (number >= 1000000000) return f(number / 1000000000, 'b');
    if (number >= 1000000) return f(number / 1000000, 'm');
    if (number >= 1000) return f(number / 1000, 'k');
    return number.toString();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _counterStream == null) {
      return const Scaffold(
        backgroundColor: _C.bg3,
        body: Center(child: CircularProgressIndicator(color: _C.cyan)),
      );
    }

    final uid = auth.FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _C.bg3,
      body: Stack(
        children: [
          _buildBackground(),
          StreamBuilder<Map<String, dynamic>>(
            stream: _counterStream,
            builder: (context, snapshot) {
              final data = snapshot.data ?? {};
              final bool isActive = data['isCounterActive'] ?? false;
              final DateTime? startTime = (data['counterStartTime'] as dynamic)
                  ?.toDate();
              final int coins = data['coins'] ?? 0;
              final int metoChips = data['meto_chips'] ?? 0;
              final int perMetoChips = data['pointsPerClaim'] ?? 0;
              const int perGold = 1000;

              // تشغيل دوران النجوم الملونة حول الدائرة باستمرار
              if (!_rotationController.isAnimating) {
                _rotationController.repeat();
              }

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, _bottomInset),
                  child: Column(
                    children: [
                      _fade(0, _buildAppBar(uid)),
                      const SizedBox(height: 10),
                      _fade(1, _buildTipSection()),
                      const SizedBox(height: 10),
                      _fade(2, _buildActionButtonsRow(uid)),

                      // المفاعل يأخذ كل المساحة المتاحة ويتناسب معها
                      Expanded(
                        child: _fade(
                          3,
                          LayoutBuilder(
                            builder: (context, c) {
                              final available = math.min(
                                c.maxWidth,
                                c.maxHeight,
                              );
                              final side = (available * 0.92)
                                  .clamp(260.0, 310.0)
                                  .toDouble();
                              return Center(
                                child: _buildReactor(
                                  side: side,
                                  isActive: isActive,
                                  startTime: startTime,
                                  perMetoChips: perMetoChips,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      _fade(
                        4,
                        _buildMainButton(
                          uid: uid,
                          isActive: isActive,
                          startTime: startTime,
                        ),
                      ),

                      _fade(
                        5,
                        ValueListenableBuilder<int>(
                          valueListenable: _tickNotifier,
                          builder: (context, _, __) {
                            final p = _progressOf(isActive, startTime);
                            return _buildStatCardsRow(
                              sessionMetoChips: perMetoChips * p,
                              metoChips: metoChips,
                              sessionGold: perGold * p,
                              coins: coins,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Background
  // ---------------------------------------------------------------------------

  Widget _buildBackground() {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_C.bg1, _C.bg2, _C.bg3],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: EnhancedMeshPainter(animation: _bgController.value),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top section
  // ---------------------------------------------------------------------------

  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color bg,
    required Color iconColor,
    Color? borderColor,
    Color? glow,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: borderColor == null ? null : Border.all(color: borderColor),
          boxShadow: glow == null
              ? null
              : [
                  BoxShadow(
                    color: glow,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }

  Widget _buildAppBar(String uid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _C.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.cyan.withValues(alpha: 0.14), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconBtn(
                icon: Icons.history_rounded,
                onTap: () => _showTransactionHistory(uid),
                bg: const Color(0xFF0A2E33),
                iconColor: Colors.white70,
                borderColor: Colors.white.withValues(alpha: 0.08),
              ),
              const SizedBox(width: 8),
              _iconBtn(
                icon: Icons.storefront_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StoreScreen(userId: uid)),
                ),
                bg: _C.tealDark,
                iconColor: Colors.white,
                glow: _C.teal.withValues(alpha: 0.3),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'العداد اليومي',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Tajawal',
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.cyan,
                      boxShadow: [
                        BoxShadow(
                          color: _C.cyan.withValues(alpha: 0.8),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'نظام التعدين الذكي',
                    style: TextStyle(
                      color: _C.cyan,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ],
              ),
            ],
          ),
          _iconBtn(
            icon: Icons.emoji_events_rounded,
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => DraggableScrollableSheet(
                  initialChildSize: 0.85,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (context, scrollController) =>
                      const DailyTasksScreen(),
                ),
              );
            },
            bg: const Color(0xFF2A2308),
            iconColor: _C.gold,
            borderColor: Colors.amber.withValues(alpha: 0.4),
            glow: Colors.amber.withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }

  Widget _buildTipSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.card.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF004D40).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _tipNotifier,
              builder: (context, i, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: Text(
                  _premiumTips[i],
                  key: ValueKey(i),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2F14),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: _C.goldSoft,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required VoidCallback onTap,
    required Color borderColor,
    required List<Widget> children,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: _C.card.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtonsRow(String uid) {
    const labelStyle = TextStyle(
      color: Colors.white,
      fontSize: 12.5,
      fontWeight: FontWeight.bold,
      fontFamily: 'Tajawal',
    );
    return Row(
      children: [
        _pillButton(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AgentsScreen()),
          ),
          borderColor: const Color(0xFFFFB300).withValues(alpha: 0.5),
          children: const [
            Icon(Icons.support_agent_rounded, color: _C.gold, size: 18),
            SizedBox(width: 8),
            Text('الوكلاء المعتمدون', style: labelStyle),
          ],
        ),
        const SizedBox(width: 10),
        _pillButton(
          onTap: () => _showCounterTierInfo(uid),
          borderColor: _C.tealDark,
          children: const [
            Icon(Icons.info_outline_rounded, color: Colors.white54, size: 15),
            SizedBox(width: 6),
            Text('العداد القياسي', style: labelStyle),
            SizedBox(width: 6),
            Icon(Icons.bolt_rounded, color: _C.cyan, size: 18),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Reactor — تصميم متطور وفخم ومطابق للصورة الأصلية بدقة
  // ---------------------------------------------------------------------------

  Widget _buildReactor({
    required double side,
    required bool isActive,
    required DateTime? startTime,
    required int perMetoChips,
  }) {
    // قطر القرص المركزي الداخلي متطابق مع الحافة الداخلية لحوض شريط التقدم
    final inner = side * 0.72;

    return ValueListenableBuilder<int>(
      valueListenable: _tickNotifier,
      builder: (context, _, __) {
        bool isFinished = false;
        double progress = 0.0;
        int remH = 24, remM = 0, remS = 0;

        if (isActive && startTime != null) {
          final remaining = _cycle - _elapsed(startTime);
          progress = _progressOf(true, startTime);
          if (remaining.inSeconds <= 0) {
            isFinished = true;
            progress = 1.0;
            remH = 0;
            remM = 0;
            remS = 0;
          } else {
            remH = remaining.inHours;
            remM = remaining.inMinutes.remainder(60);
            remS = remaining.inSeconds.remainder(60);
          }
        }

        final isRunning = isActive && !isFinished;
        final accent = isFinished ? _C.gold : _C.cyan;
        final perHour = perMetoChips / 24;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!isActive || isFinished) {
              _handleMainAction(
                auth.FirebaseAuth.instance.currentUser?.uid ?? '',
                isActive,
                isFinished,
              );
            } else {
              HapticFeedback.lightImpact();
            }
          },
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ═══ 1. القرص الداخلي باللون الرمادي الفخم ═══
                Container(
                  width: inner,
                  height: inner,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.2),
                      colors: [
                        isFinished
                            ? const Color.fromARGB(255, 41, 60, 47)
                            : const Color.fromARGB(255, 64, 81, 83),
                        const Color.fromARGB(255, 40, 50, 51),
                        const Color.fromARGB(255, 33, 37, 35),
                      ],
                      stops: const [0.0, 0.65, 1.0],
                    ),
                  ),
                ),

                // ═══ 2. قرص العداد مع المسار وشريط التقدم السميك والنجوم الدوارة ═══
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _rotationController,
                    _pulseController,
                  ]),
                  builder: (_, __) => CustomPaint(
                    size: Size(side, side),
                    painter: CounterDialPainter(
                      progress: progress,
                      isRunning: isRunning,
                      isFinished: isFinished,
                      pulse: _pulseController.value,
                      rotation: _rotationController.value,
                    ),
                  ),
                ),

                // ═══ 3. المحتوى المركزي (شارة الحالة - الساعة الرملية - كبسولة الوقت - النسبة) ═══
                _buildCoreContent(
                  side: side,
                  inner: inner,
                  isActive: isActive,
                  isFinished: isFinished,
                  isRunning: isRunning,
                  accent: accent,
                  progress: progress,
                  remH: remH,
                  remM: remM,
                  remS: remS,
                  perHour: perHour,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // المحتوى الداخلي للدائرة (شارة الحالة - الساعة الرملية - كبسولة الوقت - النسبة)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCoreContent({
    required double side,
    required double inner,
    required bool isActive,
    required bool isFinished,
    required bool isRunning,
    required Color accent,
    required double progress,
    required int remH,
    required int remM,
    required int remS,
    required double perHour,
  }) {
    final statusText = !isActive
        ? 'جاهز للتعدين'
        : (isFinished ? 'اكتمل التعدين ✓' : 'جاري التعدين');

    return SizedBox(
      width: inner * 0.85,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── 1. شارة الحالة العلوية ───
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF07383E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accent.withValues(
                    alpha: 0.4 + (isRunning ? 0.3 * _pulseController.value : 0),
                  ),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(
                      alpha: isRunning ? 0.25 * _pulseController.value : 0.08,
                    ),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(
                            alpha: isRunning
                                ? 0.5 + 0.5 * _pulseController.value
                                : 0.5,
                          ),
                          blurRadius: isRunning ? 6 : 3,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: inner * 0.035),

          // ─── 2. الساعة الرملية المتحركة ───
          SizedBox(
            width: inner * 0.27,
            height: inner * 0.27,
            child: isFinished
                ? Lottie.asset(
                    'assets/lottie/Fireworks.json',
                    fit: BoxFit.cover,
                  )
                : Lottie.asset(
                    'assets/lottie/DeadlineLoading.json',
                    fit: BoxFit.contain,
                  ),
          ),

          SizedBox(height: inner * 0.03),

          // ─── 3. كبسولة العداد الرقمي بلون الذهب وحجم أنيق ومتناسق ───
          _buildTimerPill(
            remH: remH,
            remM: remM,
            remS: remS,
            isFinished: isFinished,
            isActive: isActive,
            inner: inner,
          ),

          SizedBox(height: inner * 0.025),

          // ─── 4. نسبة التقدم ومعدل التعدين بالساعة ───
          _buildRateSubtitle(
            isRunning: isRunning,
            isActive: isActive,
            isFinished: isFinished,
            progress: progress,
            perHour: perHour,
            accent: accent,
            inner: inner,
          ),
        ],
      ),
    );
  }

  // كبسولة عداد كهرباء تدور من الأسفل للأعلى
  Widget _buildTimerPill({
    required int remH,
    required int remM,
    required int remS,
    required bool isFinished,
    required bool isActive,
    required double inner,
  }) {
    if (isFinished) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1402),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFB300).withValues(alpha: 0.6),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB300).withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          'انتهى الوقت!',
          style: TextStyle(
            color: Color(0xFFFFD54F),
            fontSize: 14.5,
            fontWeight: FontWeight.w900,
            fontFamily: 'Tajawal',
          ),
        ),
      );
    }

    // ضبط الوقت ضمن الحدود المنطقية: 24 ساعة، 60 دقيقة، 60 ثانية
    final dH = (isActive ? remH : 24).clamp(0, 24);
    final dM = (isActive ? remM : 0).clamp(0, 59);
    final dS = (isActive ? remS : 0).clamp(0, 59);

    const digitStyle = TextStyle(
      color: Color(0xFFFFB300),
      fontSize: 13,
      fontWeight: FontWeight.w900,
      fontFamily: 'monospace',
      height: 1.1,
    );
    const sepStyle = TextStyle(
      color: Color(0xFFFFB300),
      fontSize: 13,
      fontWeight: FontWeight.w700,
      fontFamily: 'monospace',
      height: 1.1,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF092226),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFB300).withValues(alpha: 0.45),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // تبديل الساعات مكان الثواني والثواني مكان الساعات
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDigitPair(dH, digitStyle), // الساعات
            const Text(' : ', style: sepStyle),
            _buildDigitPair(dM, digitStyle), // الدقائق
            const Text(' : ', style: sepStyle),
            _buildDigitPair(dS, digitStyle), // الثواني
          ],
        ),
      ),
    );
  }

  // بناء زوج من الأرقام (عشرات وآحاد) مع ضمان قراءتهما وترتيبهما الصحيح من اليسار لليمين (59 وليس 95)
  Widget _buildDigitPair(int value, TextStyle style) {
    final tens = (value ~/ 10).clamp(0, 9);
    final units = (value % 10).clamp(0, 9);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OdometerDigit(digit: tens, style: style),
          _OdometerDigit(digit: units, style: style),
        ],
      ),
    );
  }

  // سطر نسبة التقدم ومعدل التعدين المطابق للصورة تماماً
  Widget _buildRateSubtitle({
    required bool isRunning,
    required bool isActive,
    required bool isFinished,
    required double progress,
    required double perHour,
    required Color accent,
    required double inner,
  }) {
    if (isRunning) {
      final pct = (progress * 100).toStringAsFixed(1);
      final rate = perHour.toStringAsFixed(1);
      return Text(
        '$pct% • $rate+ / ساعة',
        style: const TextStyle(
          color: Color(0xFF80CBC4),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Tajawal',
        ),
      );
    } else if (!isActive) {
      return Text(
        'اضغط لبدء التعدين',
        style: TextStyle(
          color: _C.cyan.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal',
        ),
      );
    } else {
      return const Text(
        'اضغط لجمع مكافأتك',
        style: TextStyle(
          color: _C.goldSoft,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          fontFamily: 'Tajawal',
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Main CTA button — يظهر فقط عند الحاجة لإجراء (البدء أو الاستلام)
  // ---------------------------------------------------------------------------

  Widget _buildMainButton({
    required String uid,
    required bool isActive,
    required DateTime? startTime,
  }) {
    return ValueListenableBuilder<int>(
      valueListenable: _tickNotifier,
      builder: (context, _, __) {
        final finished =
            isActive &&
            startTime != null &&
            _cycle - _elapsed(startTime) <= Duration.zero;
        final running = isActive && !finished;

        // عند تشغيل التعدين لا نحتاج لزر كبير يشوه الصفحة، فالتصميم مطابق للصورة
        if (running) {
          return const SizedBox.shrink();
        }

        final label = !isActive ? 'بدء التعدين' : 'استلام المكافأة';
        final icon = !isActive
            ? Icons.play_arrow_rounded
            : Icons.card_giftcard_rounded;
        final colors = finished
            ? const [Color(0xFFFFB300), Color(0xFFFF8F00)]
            : const [Color(0xFF00BFA5), Color(0xFF00897B)];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => _handleMainAction(uid, isActive, finished),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 50,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: colors),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Stat cards
  // ---------------------------------------------------------------------------

  Widget _statCard({
    required Color borderColor,
    required Color glowColor,
    required Widget badge,
    required Widget icon,
    required String label,
    required String value,
    required String total,
    required String totalLabel,
    required Color totalColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: glowColor,
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [badge, icon],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  total,
                  style: TextStyle(
                    color: totalColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Tajawal',
                  ),
                ),
                Text(
                  totalLabel,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg, EdgeInsets pad) {
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal',
        ),
      ),
    );
  }

  Widget _buildStatCardsRow({
    required double sessionMetoChips,
    required int metoChips,
    required double sessionGold,
    required int coins,
  }) {
    return Row(
      children: [
        _statCard(
          borderColor: const Color(0xFF6D5A12),
          glowColor: Colors.amber.withValues(alpha: 0.07),
          badge: _badge(
            '+1,000 / يوم',
            const Color(0xFF2A2308),
            _C.goldSoft,
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          ),
          icon: SizedBox(
            width: 26,
            height: 26,
            child: Lottie.asset(
              'assets/lottie/Fake 3D vector coin.json',
              fit: BoxFit.contain,
            ),
          ),
          label: 'تجميع الذهب المكتسب',
          value: sessionGold.toStringAsFixed(4),
          total: _formatNumber(coins),
          totalLabel: 'إجمالي الذهب',
          totalColor: _C.goldSoft,
        ),
        const SizedBox(width: 10),
        _statCard(
          borderColor: _C.cyan.withValues(alpha: 0.4),
          glowColor: _C.cyan.withValues(alpha: 0.08),
          badge: _badge(
            'يعدن',
            const Color(0xFF003B3F),
            _C.cyan,
            const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          ),
          icon: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _C.teal, width: 1),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/coinsmeto.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          label: 'عملات MeTo المكتسبة',
          value: sessionMetoChips.toStringAsFixed(2),
          total: _formatNumber(metoChips),
          totalLabel: 'إجمالي الرصيد',
          totalColor: _C.cyan,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _handleMainAction(
    String uid,
    bool isActive,
    bool isFinished,
  ) async {
    try {
      HapticFeedback.mediumImpact();
      if (!isActive) {
        await _rewardService.startCounter(uid);
      } else if (isFinished) {
        await _claimReward(uid);
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _claimReward(String uid) async {
    try {
      // claimReward يجلب وقت السيرفر داخلياً (حماية من التلاعب)
      final rewards = await _rewardService.claimReward(uid);
      if (mounted) {
        _showRewardDialog(rewards['coins']!, rewards['meto_chips']!);
      }
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCounterTierInfo(String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: _C.cyan, width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_rounded, color: _C.cyan, size: 24),
                SizedBox(width: 8),
                Text(
                  'العداد القياسي',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'يعمل العداد القياسي بدقة عالية لتعدين عملات MeTo والذهب تلقائياً كل 24 ساعة. يمكنك ترقية العداد للحصول على مضاعفة الأرباح من خلال المتجر.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.6,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StoreScreen(userId: uid)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.tealDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'ترقية العداد من المتجر',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showRewardDialog(int coins, int metoChips) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
              ),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: _C.teal.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _C.teal.withValues(alpha: 0.2),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Image.asset(
                    'assets/images/coinsmeto.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'تم تجميع الأرباح بنجاح!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'تمت إضافة المكافأة إلى محفظتك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 15,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 15,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _rewardStat(
                        '+${_formatNumber(coins)}',
                        'ذهب',
                        Colors.amberAccent,
                        'assets/images/drhim.png',
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      _rewardStat(
                        '+${_formatNumber(metoChips)}',
                        'ميتو',
                        _C.teal,
                        'assets/images/coinsmeto.png',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _C.teal.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text(
                      'رائع، استمر في التعدين',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
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

  Widget _rewardStat(String val, String label, Color col, String image) {
    return Column(
      children: [
        Image.asset(image, width: 45, height: 45, fit: BoxFit.contain),
        const SizedBox(height: 12),
        Text(
          val,
          style: TextStyle(
            color: col,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            fontFamily: 'Tajawal',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Tajawal',
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  void _showTransactionHistory(String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF002B28),
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(25),
              child: Text(
                'سجل أرباح العداد اليومي',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('transactions')
                    .where('userId', isEqualTo: uid)
                    .where(
                      'type',
                      whereIn: ['counter_reward', 'team_mining_bonus'],
                    )
                    .orderBy('timestamp', descending: true)
                    .limit(30)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _C.teal),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد أرباح مسجلة حالياً',
                        style: TextStyle(
                          color: Colors.white38,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    itemBuilder: (context, index) {
                      final data =
                          snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;
                      final ts = (data['timestamp'] as Timestamp?)?.toDate();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _C.teal.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.timer_outlined,
                                color: Colors.greenAccent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] ?? 'مكافأة العداد اليومي',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                  if (data['fromUserName'] != null)
                                    Text(
                                      'من: ${data['fromUserName']}',
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  if (ts != null)
                                    Text(
                                      '${ts.day}/${ts.month}/${ts.year} - ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        fontSize: 10,
                                      ),
                                    ),
                                  const Text(
                                    'ستُحذف تلقائياً بعد 30 يوم',
                                    style: TextStyle(
                                      color: Colors.orangeAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if ((data['coinsAdded'] ?? 0) > 0)
                                  Text(
                                    '+${data['coinsAdded']} ذهب',
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                if ((data['metoChipsAdded'] ?? 0) > 0 ||
                                    (data['type'] == 'team_mining_bonus' &&
                                        data['amount'] != null))
                                  Text(
                                    '+${data['metoChipsAdded'] ?? data['amount']} ميتو',
                                    style: const TextStyle(
                                      color: _C.teal,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Entrance animation
  // ---------------------------------------------------------------------------

  Widget _fade(int index, Widget child) {
    final interval = Interval(
      (index * 0.1).clamp(0.0, 1.0),
      (index * 0.1 + 0.5).clamp(0.0, 1.0),
      curve: Curves.easeOutCubic,
    );
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, _) {
        final v = interval.transform(_entranceController.value);
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - v)),
            child: child,
          ),
        );
      },
    );
  }
}

// =============================================================================
// Painters
// =============================================================================

/// إضاءات ناعمة متحركة في الخلفية
class EnhancedMeshPainter extends CustomPainter {
  final double animation;
  EnhancedMeshPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation * 2 * math.pi;

    final p1 = Paint()
      ..color = _C.cyan.withValues(alpha: 0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);
    canvas.drawCircle(
      Offset(size.width * (0.5 + 0.25 * math.sin(t)), size.height * 0.3),
      170,
      p1,
    );

    final p2 = Paint()
      ..color = _C.teal.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 110);
    canvas.drawCircle(
      Offset(size.width * (0.2 + 0.15 * math.cos(t)), size.height * 0.85),
      230,
      p2,
    );
  }

  @override
  bool shouldRepaint(covariant EnhancedMeshPainter old) =>
      old.animation != animation;
}

/// رسام قرص العداد ومسار التقدم السميك المتوهج والمؤشر والنجوم الدوارة
class CounterDialPainter extends CustomPainter {
  final double progress;
  final bool isRunning;
  final bool isFinished;
  final double pulse;
  final double rotation;

  CounterDialPainter({
    required this.progress,
    required this.isRunning,
    required this.isFinished,
    required this.pulse,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // نصف قطر مسار شريط التقدم وعرضه
    final trackRadius = size.width * 0.370;
    const double barWidth = 12.0;

    // المدارات الثلاثة متقاربة من بعض للجمالية (فارق صغير بين كل مسار)
    final innerOrbitRadius = size.width * 0.340; // مدار النجمة الخضراء (داخلي)
    final middleOrbitRadius = size.width * 0.400; // مدار النجمة الحمراء (أوسط)
    final outerOrbitRadius = size.width * 0.440; // مدار النجمة الزرقاء (خارجي)

    // ─── 1. رسم مسارات النجوم الثلاثة متقاربة وأنيقة ───
    final orbitFaintPaint = Paint()
      ..color = _C.cyan.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, outerOrbitRadius, orbitFaintPaint);
    canvas.drawCircle(center, middleOrbitRadius, orbitFaintPaint);
    canvas.drawCircle(center, innerOrbitRadius, orbitFaintPaint);

    // ─── 2. حوض مسار شريط التقدم (أرضية رمادية داكنة محفورة بدون خطوط إضافية) ───
    final grooveFloorPaint = Paint()
      ..color = const Color(0xFF191D23).withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = barWidth;
    canvas.drawCircle(center, trackRadius, grooveFloorPaint);

    // ─── 3. شريط التقدم السميك والمتوهج (Progress Bar) ───
    final sweepAngle = (progress.clamp(0.0, 1.0)) * 2 * math.pi;
    final accentColor = isFinished ? const Color(0xFFFFB300) : _C.cyan;

    if (sweepAngle > 0.03) {
      final rect = Rect.fromCircle(center: center, radius: trackRadius);
      final colors = isFinished
          ? const [
              Color(0xFFFF8F00),
              Color(0xFFFFB300),
              Color(0xFFFFD54F),
              Color(0xFFFF8F00),
            ]
          : const [
              Color(0xFF00BFA5),
              Color(0xFF00E5FF),
              Color(0xFF18FFFF),
              Color(0xFF00E5FF),
            ];

      final sweepShader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        colors: colors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

      // (أ) توهج نيون عريض ومكثف خلف شريط التقدم
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        Paint()
          ..shader = sweepShader
          ..style = PaintingStyle.stroke
          ..strokeWidth = barWidth + 8.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );

      // (ب) القوس الرئيسي لشريط التقدم
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        Paint()
          ..shader = sweepShader
          ..style = PaintingStyle.stroke
          ..strokeWidth = barWidth
          ..strokeCap = StrokeCap.round,
      );

      // (ج) خط لمعان زجاجي 3D وسطي
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );

      // (د) نقطة بداية الشريط المفرغة عند الساعة 12:00
      final startPos = Offset(center.dx, center.dy - trackRadius);
      canvas.drawCircle(
        startPos,
        3.2,
        Paint()..color = const Color(0xFF00383D),
      );
      canvas.drawCircle(
        startPos,
        3.2,
        Paint()
          ..color = accentColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // (هـ) رأس شريط التقدم المضيء عند نقطة النهاية الحالية
      final tipAngle = -math.pi / 2 + sweepAngle;
      final tipPos = Offset(
        center.dx + trackRadius * math.cos(tipAngle),
        center.dy + trackRadius * math.sin(tipAngle),
      );

      // توهج رأس التقدم
      canvas.drawCircle(
        tipPos,
        10.5,
        Paint()
          ..color = accentColor.withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // خرزة الرأس
      canvas.drawCircle(
        tipPos,
        5.2,
        Paint()
          ..color = isFinished
              ? const Color(0xFFFFD54F)
              : const Color(0xFF18FFFF),
      );
      // نقطة مركزية بيضاء ساطعة
      canvas.drawCircle(tipPos, 2.4, Paint()..color = Colors.white);
    } else {
      // ─── عند نسبة 0% يظهر شريط التقدم ككبسولة عند الساعة 12:00 ───
      final capsulePos = Offset(center.dx, center.dy - trackRadius);
      _drawZeroProgressCapsule(
        canvas: canvas,
        center: capsulePos,
        accentColor: accentColor,
      );
    }

    // ─── 4. النجوم الملونة الثلاث تدور كل واحدة عكس الأخرى ───
    final baseAngle = rotation * 2 * math.pi;

    // 1. النجمة الزرقاء في المسار الخارجي (تدور مع عقارب الساعة كما في الصورة)
    _drawOrbitingStar(
      canvas: canvas,
      center: center,
      radius: outerOrbitRadius,
      angle: baseAngle * 1.9 - 1.2,
      color: const Color.fromARGB(255, 16, 77, 243),
      starSize: 5.0,
    );

    // 2. النجمة الحمراء في المسار الأوسط (تدور عكس عقارب الساعة كما في الصورة)
    _drawOrbitingStar(
      canvas: canvas,
      center: center,
      radius: middleOrbitRadius,
      angle: -baseAngle * 1.0 + 2.2,
      color: const Color(0xFFFF1744),
      starSize: 4.2,
    );

    // 3. النجمة الخضراء في المسار الداخلي (تدور مع عقارب الساعة عكس الحمراء)
    _drawOrbitingStar(
      canvas: canvas,
      center: center,
      radius: innerOrbitRadius,
      angle: baseAngle * 1.15 + 0.6,
      color: const Color(0xFF00E676),
      starSize: 4.0,
    );
  }

  /// رسم كبسولة شريط التقدم عند نسبة 0%
  void _drawZeroProgressCapsule({
    required Canvas canvas,
    required Offset center,
    required Color accentColor,
  }) {
    final capsuleRect = Rect.fromCenter(
      center: center,
      width: 27.0,
      height: 13.0,
    );
    final rrect = RRect.fromRectAndRadius(
      capsuleRect,
      const Radius.circular(6.5),
    );

    // توهج الكبسولة
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = accentColor.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // خلفية الكبسولة
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF003D44));

    // إطار الكبسولة
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    // النقطة اليسرى المفرغة
    canvas.drawCircle(
      Offset(center.dx - 4.5, center.dy),
      2.8,
      Paint()..color = const Color(0xFF00282C),
    );
    canvas.drawCircle(
      Offset(center.dx - 4.5, center.dy),
      2.8,
      Paint()
        ..color = accentColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // الزر الأيمن المضيء الساطع (Thumb)
    canvas.drawCircle(
      Offset(center.dx + 4.5, center.dy),
      4.6,
      Paint()
        ..color = accentColor.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      Offset(center.dx + 4.5, center.dy),
      3.6,
      Paint()..color = Colors.white,
    );
  }

  /// رسم نجمة ملونة متوهجة تدور حول الدائرة
  void _drawOrbitingStar({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double angle,
    required Color color,
    required double starSize,
  }) {
    final pos = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );

    // توهج نجمي ناعم ونابض
    final glowPulse = 0.65 + 0.25 * pulse;
    canvas.drawCircle(
      pos,
      starSize * 2.4,
      Paint()
        ..color = color.withValues(alpha: glowPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // جسم النجمة الملون
    canvas.drawCircle(pos, starSize, Paint()..color = color);

    // مركز أبيض ساطع يعطي بريقاً نجمياً
    canvas.drawCircle(pos, starSize * 0.45, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CounterDialPainter old) =>
      old.progress != progress ||
      old.isRunning != isRunning ||
      old.isFinished != isFinished ||
      old.pulse != pulse ||
      old.rotation != rotation;
}

/// رقم واحد يدور من الأسفل للأعلى مثل عداد الكهرباء عند كل تغيير
class _OdometerDigit extends StatelessWidget {
  final int digit;
  final TextStyle style;

  const _OdometerDigit({required this.digit, required this.style});

  @override
  Widget build(BuildContext context) {
    final fs = style.fontSize ?? 13.0;
    final charWidth = fs * 0.75;
    final charHeight = fs * 1.35;
    return ClipRect(
      child: SizedBox(
        width: charWidth,
        height: charHeight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final isIncoming = child.key == ValueKey(digit);
            return SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, isIncoming ? 1.0 : -1.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          child: Text(
            '$digit',
            key: ValueKey(digit),
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      ),
    );
  }
}
