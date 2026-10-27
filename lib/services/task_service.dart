import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== مخزن جميع المهام المتاحة (Task Pool) ==========
  static const List<DailyTask> taskPool = [
    DailyTask(
      id: 'task_login',
      title: 'سجّل دخولك اليوم',
      description: 'افتح التطبيق وسجّل دخولك',
      icon: '🌟',
      rewardAmount: 500,
      rewardType: RewardType.coins,
      requiredCount: 1,
      type: TaskType.login,
      expReward: 10,
    ),
    DailyTask(
      id: 'task_send_message',
      title: 'أرسل 3 رسائل',
      description: 'أرسل 3 رسائل لأصدقائك',
      icon: '💬',
      rewardAmount: 1000,
      rewardType: RewardType.coins,
      requiredCount: 3,
      type: TaskType.sendMessage,
      expReward: 15,
    ),
    DailyTask(
      id: 'task_send_gift',
      title: 'أرسل هدية',
      description: 'أرسل هدية لأحد في الغرفة',
      icon: '🎁',
      rewardAmount: 500,
      rewardType: RewardType.coins,
      requiredCount: 1,
      type: TaskType.sendGift,
      expReward: 30,
    ),
    DailyTask(
      id: 'task_join_room',
      title: 'انضم لغرفة صوتية',
      description: 'ادخل أي غرفة صوتية',
      icon: '🎤',
      rewardAmount: 1000,
      rewardType: RewardType.coins,
      requiredCount: 1,
      type: TaskType.joinRoom,
      expReward: 20,
    ),
    DailyTask(
      id: 'task_watch_story',
      title: 'شاهد قصة',
      description: 'شاهد قصة من قصص الأصدقاء',
      icon: '📖',
      rewardAmount: 500,
      rewardType: RewardType.coins,
      requiredCount: 1,
      type: TaskType.watchStory,
      expReward: 10,
    ),
    DailyTask(
      id: 'task_add_post',
      title: 'انشر منشوراً',
      description: 'شارك منشوراً مع أصدقائك',
      icon: '📝',
      rewardAmount: 1000,
      rewardType: RewardType.coins,
      requiredCount: 1,
      type: TaskType.addPost,
      expReward: 25,
    ),
    DailyTask(
      id: 'task_follow_user',
      title: 'اتّبع مستخدماً',
      description: 'اتّبع شخصاً جديداً لتوسيع شبكتك',
      icon: '👤',
      rewardAmount: 500,
      rewardType: RewardType.coins,
      requiredCount: 1,
      type: TaskType.followUser,
      expReward: 15,
    ),
    DailyTask(
      id: 'task_play_ludo',
      title: 'العب مباراة لودو',
      description: 'العب مباراة لودو مع الأصدقاء',
      icon: '🎲',
      rewardAmount: 1000,
      rewardType: RewardType.coins,
      requiredCount: 1,
      type: TaskType.playLudo,
      expReward: 25,
    ),
    DailyTask(
      id: 'task_change_profile',
      title: 'غيّر مظهرك',
      description: 'غيّر صورة ملفك الشخصي',
      icon: '🖼️',
      rewardAmount: 500,
      rewardType: RewardType.coins,
      requiredCount: 1,
      type: TaskType.changeProfile,
      expReward: 10,
    ),
    DailyTask(
      id: 'task_sit_on_chair',
      title: 'الجلوس على المايك',
      description: 'الجلوس على الكرسي لمدة نصف ساعة',
      icon: '🪑',
      rewardAmount: 1000,
      rewardType: RewardType.coins,
      requiredCount: 30,
      type: TaskType.sitOnChair,
      expReward: 20,
    ),
    DailyTask(
      id: 'task_comment_posts',
      title: 'كتابة تعليقات',
      description: 'كتابة تعليق في 5 منشورات مختلفة',
      icon: '💬',
      rewardAmount: 500,
      rewardType: RewardType.coins,
      requiredCount: 5,
      type: TaskType.commentPost,
      expReward: 30,
    ),
    DailyTask(
      id: 'task_like_posts',
      title: 'الإعجاب بالمنشورات',
      description: 'إعطاء لايك على 10 منشورات',
      icon: '❤️',
      rewardAmount: 1000,
      rewardType: RewardType.coins,
      requiredCount: 10,
      type: TaskType.likePost,
      expReward: 30,
    ),
    DailyTask(
      id: 'task_spin_wheel',
      title: 'فر عجلة الحظ',
      description: 'فر عجلة الحظ 4 مرات متتالية',
      icon: '🎡',
      rewardAmount: 500,
      rewardType: RewardType.coins,
      requiredCount: 4,
      type: TaskType.spinWheel,
      expReward: 30,
    ),
    DailyTask(
      id: 'task_play_car_race',
      title: 'اكمل مباراتين سباق السيارات',
      description: 'العب مباراتين في سباق السيارات اليوم',
      icon: '🏎️',
      rewardAmount: 1000,
      rewardType: RewardType.coins,
      requiredCount: 2,
      type: TaskType.playCarRace,
      expReward: 30,
    ),
    DailyTask(
      id: 'task_play_bomb_hunt',
      title: 'البحث عن القنبلة',
      description: 'العب لعبة البحث عن القنبلة في الغرفة',
      icon: '💣',
      rewardAmount: 500,
      rewardType: RewardType.coins,
      requiredCount: 1,
      type: TaskType.playBombHunt,
      expReward: 30,
    ),
    DailyTask(
      id: 'task_share_app',
      title: 'شارك التطبيق',
      description: 'شارك التطبيق ٣ مرات مع أصدقائك',
      icon: '🔗',
      rewardAmount: 50,
      rewardType: RewardType.diamonds,
      requiredCount: 3,
      type: TaskType.shareApp,
      expReward: 70,
    ),
  ];

  static List<DailyTask> get defaultTasks => taskPool;

  // ========== جلب تقدم المستخدم (Stream) ==========
  Stream<Map<String, UserTaskProgress>> getUserTaskProgressStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyTasks')
        .snapshots()
        .map((snapshot) {
          final map = <String, UserTaskProgress>{};
          for (final doc in snapshot.docs) {
            map[doc.id] = UserTaskProgress.fromMap(doc.data());
          }
          return map;
        });
  }

  // ========== مراقبة وجود مكافآت غير مستلمة ==========
  Stream<bool> hasClaimableRewardsStream(String uid) {
    return getUserTaskProgressStream(uid).map((tasksMap) {
      for (final task in taskPool) {
        final progress = tasksMap[task.id];
        if (progress != null &&
            progress.isCompleted &&
            !progress.isClaimed &&
            progress.currentCount >= task.requiredCount) {
          return true;
        }
      }
      return false;
    });
  }

  // ========== تغيير المهام غير المكتملة (مع التكلفة والحدود) ==========
  Future<String?> refreshIncompleteTasks(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);
    final tasksRef = userRef.collection('dailyTasks');

    try {
      // 1. Fetch current tasks OUTSIDE transaction (Queries are not supported inside transactions)
      final tasksSnapshot = await tasksRef.get();
      final currentTaskIds = tasksSnapshot.docs.map((doc) => doc.id).toSet();

      // Filter tasks that are not completed
      final incompleteTasks = tasksSnapshot.docs.where((doc) {
        final data = doc.data();
        return !(data['isCompleted'] as bool? ?? false);
      }).toList();

      if (incompleteTasks.isEmpty) {
        return 'كل المهام الحالية مكتملة أو لا توجد مهام لتغييرها';
      }

      await _firestore.runTransaction((transaction) async {
        final userSnap = await transaction.get(userRef);
        if (!userSnap.exists) throw 'المستخدم غير موجود';

        final userData = userSnap.data()!;
        final refreshCount =
            (userData['dailyRefreshCount'] as num?)?.toInt() ?? 0;
        final userDiamonds = (userData['diamonds'] as num?)?.toInt() ?? 0;

        // التحقق من الحد الأقصى (3 مرات يومياً)
        if (refreshCount >= 3) {
          throw 'وصلت للحد الأقصى لتغيير المهام اليوم';
        }

        // تحديد التكلفة
        int cost = 0;
        if (refreshCount == 1)
          cost = 50;
        else if (refreshCount == 2)
          cost = 100;

        if (userDiamonds < cost) {
          throw 'رصيد الماس غير كافٍ. تحتاج إلى $cost ماسة';
        }

        // المهام المتاحة في الحوض وغير موجودة حالياً عند المستخدم
        final availablePool = taskPool
            .where((t) => !currentTaskIds.contains(t.id))
            .toList();

        if (availablePool.isEmpty) {
          return 'لا توجد مهام جديدة متاحة في الحوض حالياً';
        }

        availablePool.shuffle();

        // تحديث بيانات المستخدم (الماس وعدد التغييرات)
        transaction.update(userRef, {
          'diamonds': userDiamonds - cost,
          'dailyRefreshCount': refreshCount + 1,
        });

        // تغيير المهام
        int count = 0;
        for (final doc in incompleteTasks) {
          if (count >= availablePool.length) break;

          final newTask = availablePool[count];

          // حذف المهمة القديمة
          transaction.delete(doc.reference);

          // إضافة المهمة الجديدة
          transaction.set(tasksRef.doc(newTask.id), {
            'taskId': newTask.id,
            'currentCount': 0,
            'isCompleted': false,
            'isClaimed': false,
            'lastResetDate': FieldValue.serverTimestamp(),
          });

          count++;
        }
        return null; // Success
      });
      return null; // Success outside transaction scope
    } catch (e) {
      print('Error refreshing tasks: $e');
      return e.toString();
    }
  }

  // ========== إعادة تعيين المهام إذا بدأ يوم جديد (UTC) ==========
  Future<void> resetTasksIfNewDay(String uid) async {
    final today = DateTime.now().toUtc();
    final todayDate = DateTime.utc(today.year, today.month, today.day);
    final userRef = _firestore.collection('users').doc(uid);
    final tasksRef = userRef.collection('dailyTasks');

    try {
      final bool? needsResetResult = await _firestore.runTransaction<bool?>((
        transaction,
      ) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) return false;

        final userData = userDoc.data()!;
        final lastReset = userData['lastDailyTasksReset'] != null
            ? (userData['lastDailyTasksReset'] as Timestamp).toDate().toUtc()
            : null;

        bool needsReset = false;
        if (lastReset == null) {
          needsReset = true;
        } else {
          final lastResetDate = DateTime.utc(
            lastReset.year,
            lastReset.month,
            lastReset.day,
          );
          needsReset = lastResetDate.isBefore(todayDate);
        }

        if (!needsReset) return false;

        // تحديث تاريخ إعادة التعيين وتصفير عداد التغيير
        transaction.update(userRef, {
          'lastDailyTasksReset': FieldValue.serverTimestamp(),
          'dailyRefreshCount': 0,
        });

        // إعادة تعيين نقاط لوحة الشرف اليومية
        final lastDiamondReset = userData['lastDailyDiamondsReset'] != null
            ? (userData['lastDailyDiamondsReset'] as Timestamp).toDate().toUtc()
            : null;

        bool needsDiamondReset = false;
        if (lastDiamondReset == null) {
          needsDiamondReset = true;
        } else {
          final dResetDate = DateTime.utc(
            lastDiamondReset.year,
            lastDiamondReset.month,
            lastDiamondReset.day,
          );
          if (dResetDate.isBefore(todayDate)) {
            needsDiamondReset = true;
          }
        }

        if (needsDiamondReset) {
          transaction.update(userRef, {
            'dailyDiamonds': 0,
            'dailyCoins': 0,
            'dailyMetoChips': 0,
            'lastDailyDiamondsReset': FieldValue.serverTimestamp(),
            'lastDailyCoinsReset': FieldValue.serverTimestamp(),
          });
        }
        return needsReset;
      });

      if (needsResetResult != true) return;

      // بعد نجاح المعاملة (تحديث التاريخ)، نقوم بتغيير المهام
      final oldTasksSnapshot = await tasksRef.get();
      final batch = _firestore.batch();

      for (var doc in oldTasksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final pool = List<DailyTask>.from(taskPool);
      pool.shuffle();
      final selectedTasks = pool.take(6).toList();

      for (final task in selectedTasks) {
        batch.set(tasksRef.doc(task.id), {
          'taskId': task.id,
          'currentCount': 0,
          'isCompleted': false,
          'isClaimed': false,
          'lastResetDate': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (selectedTasks.any((t) => t.type == TaskType.login)) {
        final loginTask = selectedTasks.firstWhere(
          (t) => t.type == TaskType.login,
        );
        await tasksRef.doc(loginTask.id).update({
          'currentCount': 1,
          'isCompleted': true,
        });
      }
    } catch (e) {
      print('Error resetting tasks: $e');
    }
  }

  // ========== زيادة تقدم مهمة معينة ==========
  Future<void> incrementTaskProgress(String uid, TaskType taskType) async {
    await resetTasksIfNewDay(uid);

    final tasksSnapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyTasks')
        .get();

    // البحث عن المهمة النشطة من هذا النوع عند المستخدم
    String? activeTaskId;
    DailyTask? activeTaskDef;

    for (var doc in tasksSnapshot.docs) {
      final taskId = doc.id;
      final taskDef = taskPool.firstWhere(
        (t) => t.id == taskId,
        orElse: () => taskPool.first,
      );
      if (taskDef.type == taskType) {
        activeTaskId = taskId;
        activeTaskDef = taskDef;
        break;
      }
    }

    if (activeTaskId == null || activeTaskDef == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyTasks')
        .doc(activeTaskId);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      final currentCount = (data['currentCount'] as num?)?.toInt() ?? 0;
      final isCompleted = data['isCompleted'] as bool? ?? false;

      if (isCompleted) return;

      final newCount = currentCount + 1;
      final newCompleted = newCount >= activeTaskDef!.requiredCount;

      transaction.update(docRef, {
        'currentCount': newCount,
        'isCompleted': newCompleted,
      });
    });
  }

  // ========== استلام مكافأة مهمة ==========
  Future<int> claimTaskReward(String uid, String taskId) async {
    final task = taskPool.firstWhere(
      (t) => t.id == taskId,
      orElse: () => taskPool.first,
    );
    if (task.id != taskId) throw 'المهمة غير موجودة';

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('dailyTasks')
        .doc(taskId);

    final userRef = _firestore.collection('users').doc(uid);

    return await _firestore.runTransaction((transaction) async {
      final taskSnap = await transaction.get(docRef);
      final userSnap = await transaction.get(userRef);

      if (!taskSnap.exists) throw 'المهمة غير موجودة';

      final data = taskSnap.data()!;
      final isCompleted = data['isCompleted'] as bool? ?? false;
      final isClaimed = data['isClaimed'] as bool? ?? false;

      if (!isCompleted) throw 'المهمة غير مكتملة بعد';
      if (isClaimed) throw 'تم استلام المكافأة مسبقاً';

      if (!userSnap.exists) throw 'المستخدم غير موجود';

      final userData = userSnap.data()!;
      final rewardAmount = task.rewardAmount;
      final expReward = task.expReward;

      int currentExp = (userData['exp'] as num?)?.toInt() ?? 0;
      int currentLevel = (userData['level'] as num?)?.toInt() ?? 1;

      int newExp = currentExp + expReward;
      int newLevel = currentLevel;
      int requiredExp = newLevel * 100;

      while (newExp >= requiredExp) {
        newExp -= requiredExp;
        newLevel++;
        requiredExp = newLevel * 100;
      }

      final updates = <String, dynamic>{'exp': newExp, 'level': newLevel};

      if (task.rewardType == RewardType.diamonds) {
        final currentDiamonds = (userData['diamonds'] as num?)?.toInt() ?? 0;
        updates['diamonds'] = currentDiamonds + rewardAmount;
      } else {
        final currentCoins = (userData['coins'] as num?)?.toInt() ?? 0;
        updates['coins'] = currentCoins + rewardAmount;
      }

      transaction.update(userRef, updates);
      transaction.update(docRef, {'isClaimed': true});

      return rewardAmount;
    });
  }

  // ========== إكمال جميع المهام (بالماسات) ==========
  Future<String?> completeAllTasksWithDiamonds(String uid, int cost) async {
    final userRef = _firestore.collection('users').doc(uid);
    final tasksRef = userRef.collection('dailyTasks');

    try {
      final tasksSnapshot = await tasksRef.get();
      final incompleteOrUnclaimedTasks = tasksSnapshot.docs.where((doc) {
        final data = doc.data();
        final isCompleted = data['isCompleted'] as bool? ?? false;
        final isClaimed = data['isClaimed'] as bool? ?? false;
        return !isCompleted || !isClaimed;
      }).toList();

      if (incompleteOrUnclaimedTasks.isEmpty) {
        return 'كل المهام مكتملة ومستلمة بالفعل';
      }

      await _firestore.runTransaction((transaction) async {
        final userSnap = await transaction.get(userRef);
        if (!userSnap.exists) throw 'المستخدم غير موجود';

        final userData = userSnap.data()!;
        final userDiamonds = (userData['diamonds'] as num?)?.toInt() ?? 0;

        if (userDiamonds < cost) {
          throw 'ليس لديك ماسات كافية، تحتاج إلى $cost ماسة';
        }

        transaction.update(userRef, {'diamonds': userDiamonds - cost});

        for (final doc in incompleteOrUnclaimedTasks) {
          final taskId = doc.id;
          final taskDef = taskPool.firstWhere(
            (t) => t.id == taskId,
            orElse: () => taskPool.first,
          );
          transaction.update(doc.reference, {
            'isCompleted': true,
            'currentCount': taskDef.requiredCount,
          });
        }
      });
      return null;
    } catch (e) {
      print('Error completing all tasks: $e');
      return e.toString();
    }
  }

  // ========== جلب لوحة الشرف اليومية ==========
  Stream<List<Map<String, dynamic>>> getDailyLeaderboard() {
    return _firestore
        .collection('users')
        .orderBy('dailyCoins', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'uid': doc.id,
              'username': data['username'] ?? 'مستخدم',
              'nickname': data['nickname'],
              'profileImage': data['profileImage'],
              'dailyCoins': data['dailyCoins'] ?? 0,
              'level': data['level'] ?? 1,
            };
          }).toList();
        });
  }

  // ========== جلب بيانات المستخدم (Stream) ==========
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserDataStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  static Duration getTimeUntilReset() {
    final now = DateTime.now().toUtc();
    final nextMidnight = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    return nextMidnight.difference(now);
  }
}
