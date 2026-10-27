import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/index.dart';
import 'dart:async';
import 'notification_service.dart';
import '../models/notification_model.dart';
import 'task_service.dart';
import 'package:mmmm/services/user_service.dart';
import '../models/task_model.dart';

/// خدمة Firestore لإدارة البوستات
class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _postsCollection = 'posts';

  // Static cache for data only
  static List<Post>? _cachedPosts;

  List<Post>? get cachedPosts => _cachedPosts;

  /// التحقق من حد البوستات اليومي (3 بوستات كل 24 ساعة) وتصفيره عند الساعة 00:00 (بتوقيت العراق UTC+3)
  Future<void> checkAndIncrementPostLimit(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    
    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists) {
        throw 'المستخدم غير موجود';
      }
      
      final userData = userSnap.data()!;
      final int dailyPostsCount = userData['dailyPostsCount'] ?? 0;
      
      // حساب التاريخ بتوقيت العراق (UTC+3) لضمان الدقة وتجنب التلاعب بالمنطقة الزمنية للجهاز
      final nowIraq = DateTime.now().toUtc().add(const Duration(hours: 3));
      final todayDateStr = "${nowIraq.year}-${nowIraq.month.toString().padLeft(2, '0')}-${nowIraq.day.toString().padLeft(2, '0')}";
      
      String? lastResetDateStr;
      if (userData['lastPostResetDate'] != null) {
        if (userData['lastPostResetDate'] is Timestamp) {
          final lastResetDate = (userData['lastPostResetDate'] as Timestamp).toDate().toUtc().add(const Duration(hours: 3));
          lastResetDateStr = "${lastResetDate.year}-${lastResetDate.month.toString().padLeft(2, '0')}-${lastResetDate.day.toString().padLeft(2, '0')}";
        } else if (userData['lastPostResetDate'] is String) {
          final String dateStr = userData['lastPostResetDate'] as String;
          if (dateStr.length >= 10) {
            lastResetDateStr = dateStr.substring(0, 10);
          }
        }
      }

      if (lastResetDateStr == null || lastResetDateStr != todayDateStr) {
        // يوم جديد! إعادة تعيين العداد إلى 1 وتحديث التاريخ
        transaction.update(userRef, {
          'dailyPostsCount': 1,
          'lastPostResetDate': FieldValue.serverTimestamp(),
        });
      } else {
        // نفس اليوم، التحقق من الحد الأقصى
        if (dailyPostsCount >= 3) {
          throw 'لقد وصلت إلى الحد الأقصى للمنشورات اليوم (3 منشورات كل 24 ساعة). سيتم تجديد الصلاحية في تمام الساعة 00:00.';
        }
        transaction.update(userRef, {
          'dailyPostsCount': dailyPostsCount + 1,
        });
      }
    });
  }

  /// إنشاء بوست جديد (معدل للمفقودات)
  Future<String> createPost({
    required String userId,
    required String username,
    required String content,
    required String province,
    required String category,
    List<String>? images,
    String? userProfileImage,
  }) async {
    try {
      // التحقق من حد البوستات وزيادته
      await checkAndIncrementPostLimit(userId);

      final post = Post(
        id: '',
        userId: userId,
        username: username,
        content: content,
        province: province,
        category: category,
        images: images ?? [],
        userProfileImage: userProfileImage,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 48)),
      );

      final docRef = await _firestore
          .collection(_postsCollection)
          .add(post.toMap());

      return docRef.id;
    } catch (e) {
      throw e.toString();
    }
  }

  /// تحديث بوست موجود
  Future<void> updatePost({
    required String postId,
    required String content,
    String? province,
    String? category,
  }) async {
    try {
      final updates = <String, dynamic>{'content': content};
      if (province != null) updates['province'] = province;
      if (category != null) updates['category'] = category;

      await _firestore.collection(_postsCollection).doc(postId).update(updates);
    } catch (e) {
      throw 'خطأ في تحديث البوست: $e';
    }
  }

  /// التدفق الحي للبوستات (مع فلترة البوستات النشطة فقط وتحسين الأداء)
  Stream<List<Post>> getPostsStream() {
    // We remove the static stream cache to ensure each listener gets a fresh, active connection.
    // This prevents "dead" or stale streams when navigating back/forth.
    final now = DateTime.now().toIso8601String();

    return _firestore
        .collection(_postsCollection)
        .where('expiresAt', isGreaterThan: now)
        .orderBy('expiresAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map((doc) => Post.fromMap(doc.data(), doc.id))
              .toList();
          _cachedPosts = posts; // Keep data cache for initialData
          return posts;
        });
  }

  /// تنظيف المنشورات المنتهية الصلاحية من قاعدة البيانات
  Future<void> cleanupExpiredPosts() async {
    try {
      final now = DateTime.now().toIso8601String();
      final expiredSnapshot = await _firestore
          .collection(_postsCollection)
          .where('expiresAt', isLessThan: now)
          .get();

      if (expiredSnapshot.docs.isEmpty) return;

      for (var doc in expiredSnapshot.docs) {
        await deletePost(doc.id);
      }
      print('تم تنظيف ${expiredSnapshot.docs.length} منشورات منتهية الصلاحية');
    } catch (e) {
      print('خطأ أثناء تنظيف المنشورات: $e');
    }
  }

  /// البحث عن البوستات بالكلمات المفتاحية
  Future<List<Post>> searchPosts(String query) async {
    try {
      final snapshot = await _firestore
          .collection(_postsCollection)
          .where('content', isGreaterThanOrEqualTo: query)
          .where('content', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => Post.fromMap(doc.data(), doc.id))
          .where((post) => post.expiresAt.isAfter(now))
          .toList();
    } catch (e) {
      throw 'خطأ في البحث عن البوستات: $e';
    }
  }

  /// التفاعل: إعجاب وتفاعلات متنوعة
  Future<void> toggleReaction(
    String postId,
    String userId,
    String username,
    String? profileImage,
    String postOwnerId,
    String reactionType,
  ) async {
    final docRef = _firestore.collection(_postsCollection).doc(postId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final reactions = Map<String, String>.from(data['reactions'] ?? {});
    final likedBy = List<String>.from(data['likedBy'] ?? []);
    final dislikedBy = List<String>.from(data['dislikedBy'] ?? []);

    final previousReaction = reactions[userId];

    if (previousReaction == reactionType) {
      // إزالة التفاعل إذا تم الضغط عليه مرة أخرى
      reactions.remove(userId);
      likedBy.remove(userId);
      await docRef.update({
        'reactions': reactions,
        'likedBy': likedBy,
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      // إضافة أو تحديث التفاعل
      reactions[userId] = reactionType;

      // تحديث قائمة المعجبين (للتوافق القديم)
      if (!likedBy.contains(userId)) {
        likedBy.add(userId);
      }

      // إزالة من قائمة "لا يعجبني" إذا كان موجوداً
      if (dislikedBy.contains(userId)) {
        dislikedBy.remove(userId);
      }

      await docRef.update({
        'reactions': reactions,
        'likedBy': likedBy,
        'dislikedBy': dislikedBy,
        // إذا كان تحديث (كان لديه تفاعل سابق)، العدد الكلي لا يتغير، فقط النوع
        // إذا كان جديد، يزيد العدد
        'likesCount': previousReaction == null
            ? FieldValue.increment(1)
            : FieldValue.increment(0),
        'dislikesCount':
            data.containsKey('dislikedBy') &&
                (data['dislikedBy'] as List).contains(userId)
            ? FieldValue.increment(-1)
            : FieldValue.increment(0),
      });

      // إرسال إشعار فقط عند التفاعل الجديد
      if (previousReaction == null && userId != postOwnerId) {
        String notificationText;
        switch (reactionType) {
          case 'love':
            notificationText = 'أحب منشورك ❤️';
            break;
          case 'haha':
            notificationText = 'ضحك على منشورك 😂';
            break;
          case 'wow':
            notificationText = 'انبهر بمنشورك 😮';
            break;
          case 'sad':
            notificationText = 'حزن على منشورك 😢';
            break;
          case 'angry':
            notificationText = 'غضب من منشورك 😡';
            break;
          default:
            notificationText = 'أعجب بمنشورك 👍';
        }

        await NotificationService().sendNotification(
          NotificationModel(
            id: '',
            receiverId: postOwnerId,
            senderId: userId,
            senderName: username,
            senderProfileImage: profileImage,
            type: NotificationType.like,
            postId: postId,
            text: notificationText,
            createdAt: DateTime.now(),
          ),
        );
      }

      if (previousReaction == null) {
        TaskService().incrementTaskProgress(userId, TaskType.likePost);
      }
    }
  }

  // Legacy method wrapper if needed, but we will replace usages
  Future<void> toggleLike(
    String postId,
    String userId,
    String username,
    String? profileImage,
    String postOwnerId,
  ) async {
    await toggleReaction(
      postId,
      userId,
      username,
      profileImage,
      postOwnerId,
      'like',
    );
  }

  /// التفاعل: لا يعجبني
  Future<void> toggleDislike(String postId, String userId) async {
    final docRef = _firestore.collection(_postsCollection).doc(postId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final likedBy = List<String>.from(doc['likedBy'] ?? []);
    final dislikedBy = List<String>.from(doc['dislikedBy'] ?? []);

    if (dislikedBy.contains(userId)) {
      dislikedBy.remove(userId);
      await docRef.update({
        'dislikedBy': dislikedBy,
        'dislikesCount': FieldValue.increment(-1),
      });
    } else {
      dislikedBy.add(userId);
      likedBy.remove(userId);
      await docRef.update({
        'dislikedBy': dislikedBy,
        'dislikesCount': FieldValue.increment(1),
        'likedBy': likedBy,
        'likesCount':
            doc.data()!.containsKey('likedBy') &&
                (doc['likedBy'] as List).contains(userId)
            ? FieldValue.increment(-1)
            : FieldValue.increment(0),
      });
    }
  }

  /// إرسال هدية
  Future<void> sendGift(String postId) async {
    await _firestore.collection(_postsCollection).doc(postId).update({
      'giftsCount': FieldValue.increment(1),
    });
  }

  /// جلب بوستات مستخدم معين
  Future<List<Post>> getUserPosts(String? userId) async {
    if (userId == null) return [];
    try {
      final snapshot = await _firestore
          .collection(_postsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      final now = DateTime.now();
      final posts = snapshot.docs
          .map((doc) => Post.fromMap(doc.data(), doc.id))
          .where((post) => post.expiresAt.isAfter(now))
          .toList();

      // Sort in memory: newest first (expiresAt descending)
      posts.sort((a, b) => b.expiresAt.compareTo(a.expiresAt));

      return posts;
    } catch (e) {
      throw 'خطأ في جلب بوستات المستخدم: $e';
    }
  }

  /// حذف بوست
  Future<void> deletePost(String postId) async {
    try {
      final batch = _firestore.batch();

      // 1. جلب وحذف جميع التعليقات المرتبطة بالبوست
      final commentsSnapshot = await _firestore
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .get();

      for (var doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 2. حذف البوست نفسه
      final postRef = _firestore.collection(_postsCollection).doc(postId);
      batch.delete(postRef);

      await batch.commit();
    } catch (e) {
      throw 'خطأ في حذف البوست: $e';
    }
  }

  /// جلب بوست واحد بواسطة المعرف
  Future<Post?> getPost(String postId) async {
    try {
      final doc = await _firestore
          .collection(_postsCollection)
          .doc(postId)
          .get();
      if (doc.exists) {
        return Post.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw 'خطأ في جلب البوست: $e';
    }
  }

  /// إبلاغ عن منشور
  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
  }) async {
    try {
      final postDoc = await _firestore.collection(_postsCollection).doc(postId).get();
      if (!postDoc.exists) throw 'المنشور غير موجود';
      
      final postData = postDoc.data()!;
      final postOwnerId = postData['userId'];

      // Fetch names for visualization
      final reporter = await UserService().getUser(reporterId);
      final owner = await UserService().getUser(postOwnerId);

      await _firestore.collection('post_reports').add({
        'postId': postId,
        'postOwnerId': postOwnerId,
        'postContent': postData['content'],
        'reporterId': reporterId,
        'reporterName': reporter?.nickname ?? reporter?.username ?? 'مبلغ مجهول',
        'targetName': owner?.nickname ?? owner?.username ?? 'هدف مجهول',
        'reason': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'خطأ في إرسال البلاغ: $e';
    }
  }

  /// إضافة تعليق
  Future<void> addComment({
    required String postId,
    required String postOwnerId,
    required String userId,
    required String username,
    String? userProfileImage,
    required String content,
    String? parentId,
    String? parentCommentOwnerId,
    String? replyTo,
  }) async {
    try {
      final comment = Comment(
        id: '',
        postId: postId,
        userId: userId,
        username: username,
        userProfileImage: userProfileImage,
        content: content,
        createdAt: DateTime.now(),
        parentId: parentId,
        replyTo: replyTo,
      );

      await _firestore.collection('comments').add(comment.toMap());

      await _firestore.collection(_postsCollection).doc(postId).update({
        'commentsCount': FieldValue.increment(1),
      });

      // 1. إشعار لصاحب المنشور (إذا لم يكن هو المعلق)
      if (userId != postOwnerId) {
        await NotificationService().sendNotification(
          NotificationModel(
            id: '',
            receiverId: postOwnerId,
            senderId: userId,
            senderName: username,
            senderProfileImage: userProfileImage,
            type: NotificationType.comment,
            postId: postId,
            text: 'علق على منشورك: $content',
            createdAt: DateTime.now(),
          ),
        );
      }

      // 2. إشعار لصاحب التعليق الأصلي (في حال كان رداً)
      if (parentId != null &&
          parentCommentOwnerId != null &&
          userId != parentCommentOwnerId) {
        await NotificationService().sendNotification(
          NotificationModel(
            id: '',
            receiverId: parentCommentOwnerId,
            senderId: userId,
            senderName: username,
            senderProfileImage: userProfileImage,
            type: NotificationType.reply,
            postId: postId,
            commentId: parentId,
            text: 'رد على تعليقك: $content',
            createdAt: DateTime.now(),
          ),
        );
      }
      
      TaskService().incrementTaskProgress(userId, TaskType.commentPost);
    } catch (e) {
      throw 'خطأ في إضافة التعليق: $e';
    }
  }

  /// تحديث تعليق
  Future<void> updateComment(String commentId, String content) async {
    try {
      await _firestore.collection('comments').doc(commentId).update({
        'content': content,
      });
    } catch (e) {
      throw 'خطأ في تحديث التعليق: $e';
    }
  }

  /// حذف تعليق
  Future<void> deleteComment(String commentId, String postId) async {
    try {
      await _firestore.collection('comments').doc(commentId).delete();
      await _firestore.collection(_postsCollection).doc(postId).update({
        'commentsCount': FieldValue.increment(-1),
      });
    } catch (e) {
      throw 'خطأ في حذف التعليق: $e';
    }
  }

  /// جلب تعليقات بوست معين
  Stream<List<Comment>> getCommentsStream(String postId) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Comment.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  /// التفاعل مع التعليق (إعجاب)
  Future<void> toggleCommentLike(String commentId, String userId) async {
    final docRef = _firestore.collection('comments').doc(commentId);
    final doc = await docRef.get();
    final likedBy = List<String>.from(doc['likedBy'] ?? []);

    if (likedBy.contains(userId)) {
      likedBy.remove(userId);
      await docRef.update({
        'likedBy': likedBy,
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      likedBy.add(userId);
      await docRef.update({
        'likedBy': likedBy,
        'likesCount': FieldValue.increment(1),
      });
    }
  }

  /// مشاركة بوست إلى المتابعين (Repost)
  Future<void> sharePost({
    required Post originalPost,
    required String currentUserId,
    required String currentUsername,
    String? currentUserProfileImage,
  }) async {
    try {
      // التحقق من حد البوستات وزيادته
      await checkAndIncrementPostLimit(currentUserId);

      final sharedPost = Post(
        id: '',
        userId: currentUserId,
        username: currentUsername,
        userProfileImage: currentUserProfileImage,
        content: originalPost.content,
        images: originalPost.images,
        province: originalPost.province,
        category: originalPost.category,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 48)),
        isShared: true,
        originalPostId: originalPost.id,
        originalUserId: originalPost.userId,
        originalUsername: originalPost.username,
      );

      await _firestore.collection(_postsCollection).add(sharedPost.toMap());
    } catch (e) {
      throw e.toString();
    }
  }

  // ==================== نظام مكافآت التفاعلات (50 تفاعل = 2 عملة ميتو) ====================

  Timer? _midnightTimer;

  /// بدء مؤقت التسوية عند منتصف الليل بتوقيت العراق (UTC+3)
  void startMidnightSettlementTimer() {
    _midnightTimer?.cancel();

    final nowUtc = DateTime.now().toUtc();
    final nowIraq = nowUtc.add(const Duration(hours: 3));

    // حساب منتصف الليل القادم بتوقيت العراق
    var nextMidnightIraq = DateTime(nowIraq.year, nowIraq.month, nowIraq.day + 1, 0, 0, 0);
    final durationUntilMidnight = nextMidnightIraq.difference(nowIraq);

    print('[PostService] ⏰ التسوية القادمة بعد: ${durationUntilMidnight.inMinutes} دقيقة');

    _midnightTimer = Timer(durationUntilMidnight, () async {
      print('[PostService] 🕛 حان وقت التسوية - منتصف الليل بتوقيت العراق');
      await processDailyPostReactionRewards();
      // إعادة جدولة للمنتصف التالي
      startMidnightSettlementTimer();
    });
  }

  /// معالجة مكافآت التفاعلات اليومية لجميع البلاغات النشطة
  /// كل 50 تفاعل فريد = 2 عملة ميتو لصاحب البلاغ
  /// لا يتكرر المكسب لنفس العتبة في نفس اليوم
  Future<void> processDailyPostReactionRewards() async {
    try {
      final now = DateTime.now().toIso8601String();
      final nowIraq = DateTime.now().toUtc().add(const Duration(hours: 3));
      final todayStr = "${nowIraq.year}-${nowIraq.month.toString().padLeft(2, '0')}-${nowIraq.day.toString().padLeft(2, '0')}";

      // جلب جميع البوستات النشطة
      final postsSnapshot = await _firestore
          .collection(_postsCollection)
          .where('expiresAt', isGreaterThan: now)
          .get();

      int totalRewardsGiven = 0;

      for (final postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        final reactions = Map<String, String>.from(postData['reactions'] ?? {});
        final int totalReactions = reactions.length;

        if (totalReactions < 50) continue; // لا يوجد ما يكفي من التفاعلات

        final postOwnerId = postData['userId'] as String?;
        if (postOwnerId == null || postOwnerId.isEmpty) continue;

        final rewardedMilestones = List<int>.from(postData['rewardedReactionsMilestones'] ?? []);
        final milestoneReachedDates = Map<String, String>.from(postData['milestoneReachedDates'] ?? {});

        // حساب العتبات الجديدة (50, 100, 150, ...)
        final int maxMilestone = (totalReactions ~/ 50) * 50;
        List<int> newMilestones = [];

        for (int m = 50; m <= maxMilestone; m += 50) {
          // إذا لم تتم مكافأة هذه العتبة اليوم
          if (!rewardedMilestones.contains(m) || milestoneReachedDates['$m'] != todayStr) {
            if (!rewardedMilestones.contains(m)) {
              newMilestones.add(m);
            }
          }
        }

        if (newMilestones.isEmpty) continue;

        // استخدام Transaction لضمان عدم التكرار
        await _firestore.runTransaction((transaction) async {
          final freshPostDoc = await transaction.get(postDoc.reference);
          if (!freshPostDoc.exists) return;

          final freshData = freshPostDoc.data()!;
          final freshRewardedMilestones = List<int>.from(freshData['rewardedReactionsMilestones'] ?? []);
          final freshMilestoneDates = Map<String, String>.from(freshData['milestoneReachedDates'] ?? {});

          List<int> actualNewMilestones = [];
          for (int m in newMilestones) {
            if (!freshRewardedMilestones.contains(m)) {
              actualNewMilestones.add(m);
            }
          }

          if (actualNewMilestones.isEmpty) return;

          final int rewardAmount = actualNewMilestones.length * 2; // 2 عملة لكل 50 تفاعل

          // تحديث البوست بالعتبات المكافأ عليها
          freshRewardedMilestones.addAll(actualNewMilestones);
          for (int m in actualNewMilestones) {
            freshMilestoneDates['$m'] = todayStr;
          }

          transaction.update(postDoc.reference, {
            'rewardedReactionsMilestones': freshRewardedMilestones,
            'milestoneReachedDates': freshMilestoneDates,
          });

          // إضافة العملات إلى محفظة صاحب البلاغ
          final userRef = _firestore.collection('users').doc(postOwnerId);
          transaction.update(userRef, {
            'meto_chips': FieldValue.increment(rewardAmount),
          });

          totalRewardsGiven += rewardAmount;
        });
      }

      if (totalRewardsGiven > 0) {
        print('[PostService] ✅ تم توزيع $totalRewardsGiven عملة ميتو كمكافآت تفاعلات');
      } else {
        print('[PostService] ℹ️ لا توجد مكافآت تفاعلات جديدة اليوم');
      }
    } catch (e) {
      print('[PostService] ❌ خطأ في معالجة مكافآت التفاعلات: $e');
    }
  }
}

