// ignore_for_file: unused_import, unused_field

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../services/task_service.dart';
import '../screens/car_zigzag_screen.dart';
import '../screens/bomb_hunt_screen.dart';
import '../screens/roulette_screen.dart';
import '../screens/ludo_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/edit_profile_screen.dart';
import 'package:share_plus/share_plus.dart';

class DailyTasksScreen extends StatefulWidget {
  final bool isTab;
  const DailyTasksScreen({super.key, this.isTab = false});

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen>
    with TickerProviderStateMixin {
  final TaskService _taskService = TaskService();
  Timer? _resetTimer;
  Duration _timeUntilReset = TaskService.getTimeUntilReset();
  String? _uid;
  bool _isInitialized = false;
  int _chestUpgradeCount = 0;
  DateTime? _lastChestUpgradeDate;

  // تأثير حركي للمعان الواجهة
  late AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid != null) {
      _initTasks();
    }
    _startResetTimer();

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  Future<void> _initTasks() async {
    await _taskService.resetTasksIfNewDay(_uid!);
    await _loadChestUpgradeData();
    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _loadChestUpgradeData() async {
    if (_uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _chestUpgradeCount = data?['chestUpgradeCount'] ?? 0;
          _lastChestUpgradeDate = (data?['lastChestUpgradeDate'] as Timestamp?)
              ?.toDate();
        });
        // إعادة تعيين العداد إذا مضى 24 ساعة
        _resetChestUpgradeIfNeeded();
      }
    } catch (e) {
      debugPrint('خطأ في تحميل بيانات الترقية: $e');
    }
  }

  void _resetChestUpgradeIfNeeded() {
    if (_lastChestUpgradeDate == null) return;
    final now = DateTime.now();
    final difference = now.difference(_lastChestUpgradeDate!);
    if (difference.inHours >= 24) {
      setState(() {
        _chestUpgradeCount = 0;
        _lastChestUpgradeDate = null;
      });
      _saveChestUpgradeData();
    }
  }

  Future<void> _saveChestUpgradeData() async {
    if (_uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).set({
        'chestUpgradeCount': _chestUpgradeCount,
        'lastChestUpgradeDate': _lastChestUpgradeDate,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('خطأ في حفظ بيانات الترقية: $e');
    }
  }

  Future<void> _upgradeChest() async {
    if (_uid == null) return;
    if (_chestUpgradeCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لقد وصلت للحد الأقصى من الترقيات اليومية'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int cost = 0;
    if (_chestUpgradeCount == 1) {
      cost = 50;
    } else if (_chestUpgradeCount == 2) {
      cost = 100;
    }

    if (cost > 0) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      final currentDiamonds = userDoc.data()?['diamonds'] ?? 0;

      if (currentDiamonds < cost) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ليس لديك ماسات كافية. متوفر: $currentDiamonds'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'ترقية صندوق الكنز',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'هل تريد ترقية الصندوق مقابل $cost ماسة؟',
            style: const TextStyle(fontFamily: 'Tajawal'),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF48C9B0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ترقية', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    try {
      setState(() {
        _chestUpgradeCount++;
        _lastChestUpgradeDate = DateTime.now();
      });

      if (cost > 0) {
        await FirebaseFirestore.instance.collection('users').doc(_uid).update({
          'diamonds': FieldValue.increment(-cost),
        });
      }

      await _saveChestUpgradeData();
      await _taskService.refreshIncompleteTasks(_uid!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cost > 0
                  ? 'تم ترقية الصندوق! تم استقطاع $cost ماسة والمهام تم تحديثها'
                  : 'تم ترقية الصندوق مجاناً والمهام تم تحديثها!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _startResetTimer() {
    _resetTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _timeUntilReset = TaskService.getTimeUntilReset();
        });
      }
    });
  }

  Future<void> _claimReward(DailyTask task) async {
    if (_uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 24,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _ChestWidget(isClaimed: false, canClaim: true, size: 100),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: Color(0xFFFFD700),
                  size: 22,
                ),
                const SizedBox(width: 4),
                Text(
                  '+${task.rewardAmount}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFF8F00),
                  size: 22,
                ),
                const SizedBox(width: 4),
                Text(
                  '+${task.expReward} XP',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                    color: Color(0xFF3E2723),
                  ),
                ),
              ],
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF48C9B0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'تأكيد الاستلام',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _taskService.claimTaskReward(_uid!, task.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _handleClaimAllTasks(
    List<DailyTask> tasks,
    Map<String, UserTaskProgress> progressMap,
  ) async {
    if (_uid == null) return;

    final claimableTasks = tasks.where((t) {
      final p = progressMap[t.id];
      return p != null && p.isCompleted && !p.isClaimed;
    }).toList();

    if (claimableTasks.isEmpty) return;

    int totalCoins = 0;
    int totalExp = 0;
    for (var t in claimableTasks) {
      totalCoins += t.rewardAmount;
      totalExp += t.expReward;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _ChestWidget(isClaimed: false, canClaim: true, size: 100),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: Color(0xFFFFD700),
                  size: 22,
                ),
                const SizedBox(width: 4),
                Text(
                  '+$totalCoins',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFF8F00),
                  size: 22,
                ),
                const SizedBox(width: 4),
                Text(
                  '+$totalExp XP',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                    color: Color(0xFF3E2723),
                  ),
                ),
              ],
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF48C9B0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'استلام الجوائز',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Future.wait(
        claimableTasks.map((task) => _taskService.claimTaskReward(_uid!, task.id))
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استلام جميع الجوائز بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الاستلام: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCompleteAllTasks(int incompleteTasks) async {
    if (_uid == null || incompleteTasks == 0) return;

    final int cost = incompleteTasks * 50; // 50 ماسة لكل مهمة غير مكتملة

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 24,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.diamond_rounded,
              size: 80,
              color: Color(0xFF48C9B0),
            ),
            const SizedBox(height: 20),
            Text(
              'إكمال $incompleteTasks مهمة متبقية',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
                color: Color(0xFF3E2723),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.diamond_rounded,
                  color: Color(0xFF48C9B0),
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '$cost ماسة',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Tajawal',
                    color: Color(0xFF48C9B0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '(50 ماسة × $incompleteTasks مهمة)',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Tajawal',
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'Tajawal',
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF48C9B0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'تأكيد',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final errorResult = await _taskService.completeAllTasksWithDiamonds(
        _uid!,
        cost,
      );
      if (mounted) {
        if (errorResult != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorResult), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إكمال جميع المهام بنجاح!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _closeScreen() {
    try {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('خطأ في الإغلاق: $e');
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14), // لون داكن عميق وفاخر
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            // إضاءات نيون خلفية (Neon Glow Effects)
            Positioned(
              top: -80,
              right: -50,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8A2BE2).withOpacity(0.15),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 100,
                      color: const Color(0xFF8A2BE2).withOpacity(0.2),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E5FF).withOpacity(0.12),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 100,
                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                    ),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // الإطار الزجاجي الأساسي للبطاقة (Glassmorphism)
                    Container(
                      margin: const EdgeInsets.only(top: 30, bottom: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04), // زجاجي شفاف
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 45),
                          Expanded(
                            child: !_isInitialized
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF00E5FF),
                                    ),
                                  )
                                : StreamBuilder<Map<String, UserTaskProgress>>(
                                    stream: _taskService
                                        .getUserTaskProgressStream(_uid!),
                                    builder: (context, snapshot) {
                                      final progressMap = snapshot.data ?? {};
                                      final activeTasks = TaskService.taskPool
                                          .where(
                                            (task) => progressMap.containsKey(
                                              task.id,
                                            ),
                                          )
                                          .toList();

                                      return Column(
                                        children: [
                                          Expanded(
                                            child: ListView.builder(
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              itemCount: activeTasks.length,
                                              itemBuilder: (context, index) {
                                                final task = activeTasks[index];
                                                final progress =
                                                    progressMap[task.id]!;
                                                return _buildTaskCard(
                                                  task,
                                                  progress,
                                                  index,
                                                );
                                              },
                                            ),
                                          ),
                                          _buildBottomActions(
                                            progressMap,
                                            activeTasks,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    // العنوان العلوي
                    Positioned(top: 0, child: _buildHeaderTitle()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTitle() {
    return SizedBox(
      width: 340, // مساحة كافية لتشمل العنوان والأزرار بالكامل
      height: 85, // لتشمل مساحة النقر العمودية أيضاً
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // شريط العنوان الزجاجي الأنيق
          Container(
            height: 60,
            width: 220,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'المهام اليومية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Tajawal',
                  letterSpacing: 1,
                  shadows: [Shadow(color: Color(0xFF00E5FF), blurRadius: 10)],
                ),
              ),
            ),
          ),
          // زر الإغلاق (X)
          Positioned(
            left: 5,
            top: 2,
            child: GestureDetector(
              onTap: _closeScreen,
              behavior: HitTestBehavior.opaque, // يغطي منطقة النقر الأكبر
              child: Padding(
                padding: const EdgeInsets.all(15.0), // يعطي مساحة نقر واسعة
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF5E5E),
                        Color(0xFFC00000),
                      ], // لون أحمر متدرج
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFFFF5E5E,
                        ).withOpacity(0.4), // وهج أحمر
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white, // أيقونة بيضاء
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          // زر المساعدة (?)
          Positioned(
            right: 5,
            top: 2,
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF131722),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    title: const Text(
                      'معلومات المهام',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    content: const Text(
                      '• قم بإنجاز المهام اليومية للحصول على الماس ونقاط الخبرة (XP).\n\n• يمكنك ترقية صندوق الكنز لزيادة قيمة الجوائز بمقابل ماسات إضافية.\n\n• يتم إعادة تعيين المهام في بداية كل يوم جديد.\n\n• إذا ضغطت على "إكمال الكل" سيتم إكمال كافة المهام المتبقية بمقابل ماس.',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8A2BE2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'حسناً',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Tajawal',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF00E5FF),
                        Color(0xFF0083B0),
                      ], // تدرج شبيه بزر تكملة
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF00E5FF,
                        ).withOpacity(0.4), // وهج أزرق جميل
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.question_mark_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(DailyTask task, UserTaskProgress progress, int index) {
    final double percent = (progress.currentCount / task.requiredCount).clamp(
      0.0,
      1.0,
    );
    final bool canClaim = progress.isCompleted && !progress.isClaimed;
    final bool claimed = progress.isClaimed;

    // تصنيف ديناميكي للمظهر
    final Color categoryColor = index % 2 == 0
        ? const Color(0xFF00E5FF) // Neon Cyan
        : const Color(0xFFFF007F); // Neon Pink

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03), // زجاجي خفيف
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: claimed
              ? Colors.white.withOpacity(0.05)
              : categoryColor.withOpacity(0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // الوهج الخفيف الجانبي
          if (!claimed)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: categoryColor.withOpacity(0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // ── الصندوق الأيسر ──
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Center(
                    child: _ChestWidget(
                      isClaimed: claimed,
                      canClaim: canClaim,
                      size: 50,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // ── التفاصيل المركزية (العنوان + الجوائز + التقدم) ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // العنوان
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: claimed
                              ? Colors.white30
                              : Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Tajawal',
                          decoration: null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // ── سطر الجوائز (الماسات + الـ XP) ──
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildRewardChip(
                            icon: task.rewardType == RewardType.diamonds
                                ? Icons.diamond_rounded
                                : Icons.monetization_on_rounded,
                            iconColor: task.rewardType == RewardType.diamonds
                                ? const Color(0xFF00E5FF)
                                : const Color(0xFFFFD700), // ذهبي
                            value: '+${task.rewardAmount}',
                            bgColor:
                                (task.rewardType == RewardType.diamonds
                                        ? const Color(0xFF00E5FF)
                                        : const Color(0xFFFFD700))
                                    .withOpacity(0.1),
                          ),
                          _buildRewardChip(
                            icon: Icons.bolt_rounded,
                            iconColor: const Color(0xFF00E5FF), // سيان
                            value: '+${task.expReward} XP',
                            bgColor: const Color(0xFF00E5FF).withOpacity(0.1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // ── شريط التقدم ──
                      SizedBox(
                        height: 12,
                        child: Stack(
                          children: [
                            // الخلفية الداكنة للشريط
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                  width: 1,
                                ),
                              ),
                            ),
                            // التقدم الفعلي الملون
                            FractionallySizedBox(
                              widthFactor: percent,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    colors: claimed || canClaim
                                        ? [
                                            const Color(0xFF8A2BE2),
                                            const Color(0xFFD500F9),
                                          ] // بنفسجي نيون للاكتمال
                                        : [
                                            categoryColor.withOpacity(0.7),
                                            categoryColor,
                                          ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (claimed || canClaim
                                                  ? const Color(0xFFD500F9)
                                                  : categoryColor)
                                              .withOpacity(0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // النص داخل الشريط (4/4)
                            Center(
                              child: Text(
                                '${progress.currentCount}/${task.requiredCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // ── زر الإجراء الأيمن ──
                _buildActionWidget(task, canClaim, claimed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ويدجت صغيرة وأنيقة لعرض الجوائز
  Widget _buildRewardChip({
    required IconData icon,
    required Color iconColor,
    required String value,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: iconColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionWidget(DailyTask task, bool canClaim, bool claimed) {
    if (claimed) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white30, size: 20),
      );
    }

    if (canClaim) {
      return _buildAnimatedButton(
        'استلام',
        const [Color(0xFF8A2BE2), Color(0xFFD500F9)],
        const Color(0xFFD500F9),
        () => _claimReward(task),
      );
    }

    return _buildAnimatedButton(
      'اذهب',
      const [Color(0xFF00E5FF), Color(0xFF0083B0)],
      const Color(0xFF00E5FF),
      () => _navigateToTaskAction(task.type),
    );
  }

  void _navigateToTaskAction(TaskType type) {
    Navigator.pop(context); // إغلاق نافذة المهام أولاً للعودة للواجهة الرئيسية

    switch (type) {
      case TaskType.addPost:
        Navigator.pushNamed(context, '/addPost');
        break;
      case TaskType.changeProfile:
        Navigator.pushNamed(context, '/editProfile');
        break;
      case TaskType.sendMessage:
      case TaskType.followUser:
        Navigator.pushNamed(context, '/search'); // ممكن إيجاد مستخدمين من البحث
        break;
      case TaskType.playCarRace:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CarZigzagScreen()),
        );
        break;
      case TaskType.playBombHunt:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BombHuntScreen()),
        );

        break;
      case TaskType.spinWheel:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RouletteScreen()),
        );
        break;
      case TaskType.playLudo:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LudoScreen()),
        );
        break;
      case TaskType.joinRoom:
      case TaskType.sitOnChair:
      case TaskType.sendGift:
      case TaskType.watchStory:
      case TaskType.likePost:
      case TaskType.commentPost:
        // هذه المهام توجد في الصفحة الرئيسية مباشرة إما بالأعلى (القصص) أو في الغرف والمنشورات بالأسفل
        // الإغلاق يكفي حالياً كونه يعيد المستخدم لهذه الشاشة.
        break;
      case TaskType.shareApp:
        _handleShareApp();
        break;
      default:
        break;
    }
  }

  Future<void> _handleShareApp() async {
    if (_uid == null) return;

    // رابط التطبيق (يمكنك تعديله للرابط الحقيقي على المتجر لاحقاً)
    const String appLink =
        "https://play.google.com/store/apps/details?id=com.mmmm.app";

    try {
      final result = await Share.share(
        'انضم إلي في تطبيق ميتو! استمتع بالغرف الصوتية والألعاب الممتعة والدردشة مع الأصدقاء.\n$appLink',
        subject: 'تحميل تطبيق ميتو',
      );

      // إذا نجحت المشاركة (على الأندرويد والـ iOS ترجع Success إذا تمت المشاركة فعلياً)
      if (result.status == ShareResultStatus.success) {
        await _taskService.incrementTaskProgress(_uid!, TaskType.shareApp);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('شكراً لمشاركتك! تم احتساب المهمة بنجاح 🌟'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (result.status == ShareResultStatus.dismissed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يجب إكمال عملية المشاركة لاحتساب المهمة'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('خطأ أثناء المشاركة: $e');
    }
  }

  Widget _buildAnimatedButton(
    String text,
    List<Color> gradientColors,
    Color glowColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            fontFamily: 'Tajawal',
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(
    Map<String, UserTaskProgress> progressMap,
    List<DailyTask> activeTasks,
  ) {
    // المهام غير المكتملة (لم تكتمل بعد)
    final incompleteTasks = activeTasks.where((t) {
      final p = progressMap[t.id];
      return p == null || !p.isCompleted;
    }).toList();
    final int incompleteCount = incompleteTasks.length;
    final int completeAllCost = incompleteCount * 50;

    // التحقق مما إذا كانت جميع المهام قد اكتملت
    final bool allCompleted =
        activeTasks.isNotEmpty &&
        activeTasks.every((t) => progressMap[t.id]?.isCompleted ?? false);

    // التحقق مما إذا كانت جميع المهام قد استلمت
    final bool allClaimed =
        activeTasks.isNotEmpty &&
        activeTasks.every((t) => progressMap[t.id]?.isClaimed ?? false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          // زر ترقية صندوق الكنز
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: (!allCompleted && _chestUpgradeCount < 3)
                  ? _upgradeChest
                  : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  gradient: (!allCompleted && _chestUpgradeCount < 3)
                      ? LinearGradient(
                          colors: [
                            const Color(0xFFFFD700).withOpacity(0.1),
                            const Color(0xFFFFA000).withOpacity(0.2),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.02),
                            Colors.white.withOpacity(0.02),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (!allCompleted && _chestUpgradeCount < 3)
                        ? const Color(0xFFFFD700).withOpacity(0.5)
                        : Colors.white.withOpacity(0.1),
                    width: 1.5,
                  ),
                  boxShadow: (!allCompleted && _chestUpgradeCount < 3)
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.15),
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!allCompleted)
                      Text(
                        'ترقية الصندوق',
                        style: TextStyle(
                          color: _chestUpgradeCount < 3
                              ? const Color(0xFFFFD700)
                              : Colors.white30,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    Text(
                      allCompleted
                          ? 'المهام مكتملة'
                          : (_chestUpgradeCount == 0
                                ? 'مجاناً'
                                : (_chestUpgradeCount < 3
                                      ? '${_chestUpgradeCount * 50} ماسة'
                                      : 'انتهت الترقيات')),
                      style: TextStyle(
                        color: (!allCompleted && _chestUpgradeCount < 3)
                            ? Colors.white
                            : Colors.white54,
                        fontSize: allCompleted ? 14 : 10,
                        fontWeight: allCompleted
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // زر إكمال الكل / استلام الكل
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: allClaimed
                  ? null
                  : (allCompleted
                        ? () => _handleClaimAllTasks(activeTasks, progressMap)
                        : () => _handleCompleteAllTasks(incompleteCount)),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  gradient: allClaimed
                      ? LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.02),
                          ],
                        )
                      : LinearGradient(
                          colors: allCompleted
                              ? [
                                  const Color(0xFF00E5FF),
                                  const Color(0xFF0083B0),
                                ] // سيان نيون للاستلام
                              : [
                                  const Color(0xFF8A2BE2),
                                  const Color(0xFFD500F9),
                                ], // بنفسجي نيون للإكمال
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: allClaimed
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: allClaimed
                      ? []
                      : [
                          BoxShadow(
                            color:
                                (allCompleted
                                        ? const Color(0xFF00E5FF)
                                        : const Color(0xFFD500F9))
                                    .withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      allClaimed
                          ? 'تم الاستلام'
                          : (allCompleted ? 'استلام الكل' : 'إكمال الكل'),
                      style: TextStyle(
                        color: allClaimed ? Colors.white30 : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    if (!allClaimed &&
                        !allCompleted &&
                        incompleteCount > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.diamond_rounded,
                            color: Colors.white,
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$completeAllCost ماسة',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ويدجت الصندوق المطور (بصور حقيقية واهتزاز سحري) ───
class _ChestWidget extends StatefulWidget {
  final bool isClaimed;
  final bool canClaim;
  final double size;

  const _ChestWidget({
    required this.isClaimed,
    required this.canClaim,
    this.size = 60,
  });

  @override
  State<_ChestWidget> createState() => _ChestWidgetState();
}

class _ChestWidgetState extends State<_ChestWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // تصميم مسار الاهتزاز السحري
    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.15), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 0.15, end: -0.15), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.15), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 0.15, end: -0.15), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.0), weight: 1),
          TweenSequenceItem(tween: ConstantTween(0.0), weight: 15),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );

    if (widget.canClaim) {
      _shakeController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ChestWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.canClaim && !oldWidget.canClaim) {
      _shakeController.repeat();
    } else if (!widget.canClaim && oldWidget.canClaim) {
      _shakeController.stop();
      _shakeController.reset();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 💡 التعديل هنا: الصندوق يظهر مفتوحاً إذا تم الاستلام (isClaimed) أو إذا اكتملت المهمة وجاهزة للاستلام (canClaim)
    final bool shouldOpen = widget.isClaimed || widget.canClaim;

    final String imagePath = shouldOpen
        ? 'assets/images/opnebox.png'
        : 'assets/images/closebox.png';

    Widget chestImage = Image.asset(
      imagePath,
      width: widget.size * 0.9,
      height: widget.size * 0.9,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // 🚨 هذا السطر سيطبع لك الخطأ في الـ Console (Terminal) إذا كان هناك مشكلة في مسار الصورة
        debugPrint('تعذر تحميل الصورة من المسار: $imagePath، السبب: $error');

        return Icon(
          shouldOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
          color: const Color(0xFFFFD54F),
          size: widget.size * 0.6,
        );
      },
    );

    // إضافة الاهتزاز للصندوق المفتوح (الجاهز للاستلام)
    if (widget.canClaim && !widget.isClaimed) {
      chestImage = AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.rotate(angle: _shakeAnimation.value, child: child);
        },
        child: chestImage,
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          if (widget.canClaim && !widget.isClaimed) ...[
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.6),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ] else if (widget.isClaimed) ...[
            BoxShadow(
              color: const Color(0xFF42E695).withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ] else ...[
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ],
      ),
      child: Center(child: chestImage),
    );
  }
}
