import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/index.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';
import 'task_service.dart';
import '../models/task_model.dart';

/// خدمة Firestore لإدارة المستخدمين
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';

  // Static Cache for user data
  static final Map<String, User> _userCache = {};
  static final Map<String, DateTime> _userCacheTime = {};

  /// Get cached user synchronously if available
  User? getUserSync(String uid) => _userCache[uid];

  /// تحديث رمز الجهاز (FCM Token) لاستقبال الإشعارات
  Future<void> updateFCMToken(String uid) async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection(_usersCollection).doc(uid).update({
          'fcmToken': token,
        });

        // Subscribe to global topic for admin notifications
        await FirebaseMessaging.instance.subscribeToTopic('all_users');
      }
    } catch (error) {
      print('Error updating FCM token: $error');
      // No re-throw here to avoid breaking login/init flows
    }
  }

  // متابعة المستخدم ذو المعرف رقم 1 تلقائياً
  Future<void> _autoFollowFirstUser(User newUser) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('displayId', isEqualTo: '1')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final adminUserDoc = querySnapshot.docs.first;
        final adminUserId = adminUserDoc.id;

        await followUser(
          currentUserId: newUser.uid,
          currentUsername: newUser.username,
          currentUserProfileImage: newUser.profileImage,
          userToFollowId: adminUserId,
        );
      }
    } catch (e) {
      print('Error auto-following admin user: $e');
    }
  }

  /// إنشاء ملف مستخدم جديد مع معرف رقمي فريد يبدأ من 1
  Future<void> createUser({
    required String uid,
    required String username,
    required String email,
    String? nickname,
    String? profileImage,
    String? sessionId,
    String? gender,
    String? country,
  }) async {
    try {
      // استخدام Transaction لضمان الحصول على معرف رقمي متسلسل وفريد
      final displayId = await _firestore.runTransaction<String>((
        transaction,
      ) async {
        DocumentReference counterRef = _firestore
            .collection('metadata')
            .doc('user_counter');
        DocumentSnapshot counterSnapshot = await transaction.get(counterRef);

        int nextId;
        if (!counterSnapshot.exists || counterSnapshot.data() == null) {
          nextId = 1;
        } else {
          final data = counterSnapshot.data() as Map<String, dynamic>;
          nextId = (data['currentId'] ?? 870018) + 1;
        }

        transaction.set(counterRef, {
          'currentId': nextId,
        }, SetOptions(merge: true));
        return nextId.toString();
      });

      final user = User(
        uid: uid,
        username: username,
        nickname: nickname,
        email: email,
        profileImage: profileImage,
        createdAt: DateTime.now(),
        displayId: displayId,
        originalDisplayId: displayId,
        sessionId: sessionId,
        referralCode: displayId,
        gender: gender,
        country: country,
      );

      await _firestore.collection(_usersCollection).doc(uid).set(user.toMap());

      // Auto-follow user with ID 1
      if (displayId != '1') {
        _autoFollowFirstUser(user);
      }
    } catch (error) {
      print('Error creating user profile: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// الحصول على بيانات مستخدم (تحديث لحظي مع تخزين مؤقت للبيانات)
  Stream<User?> getUserStream(String uid) {
    return _firestore.collection(_usersCollection).doc(uid).snapshots().map((
      doc,
    ) {
      if (doc.exists) {
        final user = User.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        _userCache[uid] = user;
        _userCacheTime[uid] = DateTime.now();
        return user;
      }
      return null;
    });
  }

  /// الحصول على بيانات مستخدم (مع تخزين مؤقت)
  Future<User?> getUser(String uid) async {
    // Check cache (5 minutes validity)
    if (_userCache.containsKey(uid)) {
      final lastFetched = _userCacheTime[uid];
      if (lastFetched != null &&
          DateTime.now().difference(lastFetched).inMinutes < 5) {
        return _userCache[uid];
      }
    }

    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();

      if (doc.exists) {
        final user = User.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        _userCache[uid] = user;
        _userCacheTime[uid] = DateTime.now();
        return user;
      }
      return null;
    } catch (error) {
      print('Error fetching user: $error');
      return _userCache[uid]; // Return cached version on error if exists
    }
  }

  /// تحديث بيانات المستخدم
  Future<void> updateUser({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update(data);
    } catch (error) {
      print('Error updating user: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// تعيين المستخدم كنشط (متصل)
  Future<void> setUserOnline(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'isOnline': true,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      print('Error setting user online: $error');
      // No re-throw to avoid UI issues
    }
  }

  /// تعيين المستخدم كغير نشط (غير متصل)
  Future<void> setUserOffline(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'isOnline': false,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      print('Error setting user offline: $error');
      // No re-throw
    }
  }

  /// تحديث حالة الاتصال
  Future<void> updateOnlineStatus(String uid, bool isOnline) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      print('Error updating online status: $error');
      // No re-throw
    }
  }

  /// البحث عن مستخدمين بالاسم أو بالمعرف الرقمي
  Future<List<User>> searchUsers(
    String searchQuery, {
    String? currentUserId,
  }) async {
    try {
      Query query = _firestore.collection(_usersCollection);

      // إذا كان البحث عبارة عن أرقام فقط ومكون من 6 أرقام، نفترض أنه بحث بالـ ID
      if (RegExp(r'^[0-9]+$').hasMatch(searchQuery)) {
        query = query.where('displayId', isEqualTo: searchQuery);
      } else {
        query = query
            .where('username', isGreaterThanOrEqualTo: searchQuery)
            .where('username', isLessThan: '${searchQuery}z');
      }

      final querySnapshot = await query
          .limit(20)
          .get(); // زيادة الحد للسماح بالفلترة

      var users = querySnapshot.docs
          .map(
            (doc) => User.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();

      if (currentUserId != null) {
        final currentUser = await getUser(currentUserId);
        if (currentUser != null) {
          users = users.where((u) {
            // لا تظهر المستخدم إذا قمت بحظره
            if (currentUser.blockedUsers.contains(u.uid)) return false;
            // لا تظهر المستخدم إذا قام هو بحظرك (يحتاج التحقق من الطرف الآخر، لكن للسرعة نكتفي بهذا حالياً)
            // ملاحظة: لتحقق أدق، يجب قراءة مستند المستخدم الآخر، وهذا مكلف في البحث.
            // عادةً يتم تخزين "blockedBy" في مستند المستخدم الحالي أيضاً للتسهيل.
            return true;
          }).toList();
        }
      }

      return users.take(10).toList(); // إرجاع 10 نتائج فقط بعد الفلترة
    } catch (error) {
      print('Error searching users: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// الحصول على قائمة المتابعين
  Future<List<User>> getFollowers(String uid) async {
    try {
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();
      final followers = List<String>.from(userDoc['followers'] ?? []);

      List<User> followersList = [];
      for (String followerId in followers) {
        final follower = await getUser(followerId);
        if (follower != null) {
          followersList.add(follower);
        }
      }
      return followersList;
    } catch (error) {
      print('Error fetching followers: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// تحديث حالة الاتصال (نشط/غير نشط)
  Future<void> updatePresence(String uid, bool isOnline) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating presence: $e');
    }
  }

  /// الحصول على المستخدمين النشطين حالياً (عالمياً)
  Future<List<User>> getOnlineUsers({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection(_usersCollection)
          .where('isOnline', isEqualTo: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => User.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error fetching online users: $e');
      return [];
    }
  }

  /// الحصول على قائمة المتابعة
  Future<List<User>> getFollowing(String uid) async {
    try {
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();
      final following = List<String>.from(userDoc['following'] ?? []);

      List<User> followingList = [];
      for (String followingId in following) {
        final followingUser = await getUser(followingId);
        if (followingUser != null) {
          followingList.add(followingUser);
        }
      }
      return followingList;
    } catch (error) {
      print('Error fetching following: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// متابعة مستخدم
  Future<void> followUser({
    required String currentUserId,
    required String currentUsername,
    String? currentUserProfileImage,
    required String userToFollowId,
  }) async {
    try {
      final targetUser = await getUser(userToFollowId);
      final currentUser = await getUser(currentUserId);

      if (targetUser == null || currentUser == null) return;

      // التحقق مما إذا كان يتابعه بالفعل
      if (targetUser.followers.contains(currentUserId)) {
        return; // يتابع بالفعل، لا تفعل شيئاً
      }

      // التحقق من الحظر أو القائمة السوداء
      if (targetUser.blockedUsers.contains(currentUserId) ||
          targetUser.blacklistedUsers.contains(currentUserId)) {
        throw 'لا يمكنك متابعة هذا المستخدم';
      }
      if (currentUser.blockedUsers.contains(userToFollowId)) {
        throw 'يجب إلغاء الحظر أولاً لمتابعة هذا المستخدم';
      }

      // إضافة إلى قائمة المتابعة للمستخدم الحالي
      await _firestore.collection(_usersCollection).doc(currentUserId).update({
        'following': FieldValue.arrayUnion([userToFollowId]),
        'followingCount': FieldValue.increment(1),
      });

      // إضافة إلى قائمة المتابعين للمستخدم الآخر
      await _firestore.collection(_usersCollection).doc(userToFollowId).update({
        'followers': FieldValue.arrayUnion([currentUserId]),
        'followersCount': FieldValue.increment(1),
      });

      // إرسال إشعار
      await NotificationService().sendNotification(
        NotificationModel(
          id: '',
          receiverId: userToFollowId,
          senderId: currentUserId,
          senderName: currentUsername,
          senderProfileImage: currentUserProfileImage,
          type: NotificationType.follow,
          text: 'قام بمتابعتك',
          createdAt: DateTime.now(),
        ),
      );

      // وزيادة تقدم المهمة اليومية
      await TaskService().incrementTaskProgress(
        currentUserId,
        TaskType.followUser,
      );
    } catch (error) {
      print('Error following user: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// إلغاء المتابعة
  Future<void> unfollowUser({
    required String currentUserId,
    required String userToUnfollowId,
  }) async {
    try {
      final targetUser = await getUser(userToUnfollowId);
      final currentUser = await getUser(currentUserId);

      if (targetUser == null || currentUser == null) return;

      // التحقق مما إذا كان لا يتابعه أصلاً
      if (!targetUser.followers.contains(currentUserId)) {
        return; // لا يتابعه، لا تفعل شيئاً
      }

      // حذف من قائمة المتابعة للمستخدم الحالي
      await _firestore.collection(_usersCollection).doc(currentUserId).update({
        'following': FieldValue.arrayRemove([userToUnfollowId]),
        'followingCount': FieldValue.increment(-1),
      });

      // حذف من قائمة المتابعين للمستخدم الآخر
      await _firestore
          .collection(_usersCollection)
          .doc(userToUnfollowId)
          .update({
            'followers': FieldValue.arrayRemove([currentUserId]),
            'followersCount': FieldValue.increment(-1),
          });
    } catch (error) {
      print('Error unfollowing user: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// حظر مستخدم
  Future<void> blockUser({
    required String currentUserId,
    required String userToBlockId,
  }) async {
    try {
      final batch = _firestore.batch();
      final currentUserRef = _firestore
          .collection(_usersCollection)
          .doc(currentUserId);
      final targetUserRef = _firestore
          .collection(_usersCollection)
          .doc(userToBlockId);

      // 1. إضافة للمحظورين
      batch.update(currentUserRef, {
        'blockedUsers': FieldValue.arrayUnion([userToBlockId]),
      });

      // 2. إلغاء المتابعة من الطرفين
      batch.update(currentUserRef, {
        'following': FieldValue.arrayRemove([userToBlockId]),
        'followers': FieldValue.arrayRemove([userToBlockId]),
      });
      batch.update(targetUserRef, {
        'followers': FieldValue.arrayRemove([currentUserId]),
        'following': FieldValue.arrayRemove([currentUserId]),
      });

      await batch.commit();
    } catch (error) {
      print('Error blocking user: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// أصمات مستخدم
  Future<void> muteUser({
    required String currentUserId,
    required String userToMuteId,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(currentUserId).update({
        'mutedUsers': FieldValue.arrayUnion([userToMuteId]),
      });
    } catch (error) {
      print('Error muting user: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// إضافة للقائمة السوداء
  Future<void> blacklistUser({
    required String currentUserId,
    required String userToBlacklistId,
  }) async {
    try {
      final batch = _firestore.batch();
      final currentUserRef = _firestore
          .collection(_usersCollection)
          .doc(currentUserId);
      final targetUserRef = _firestore
          .collection(_usersCollection)
          .doc(userToBlacklistId);

      // 1. إضافة للقائمة السوداء
      batch.update(currentUserRef, {
        'blacklistedUsers': FieldValue.arrayUnion([userToBlacklistId]),
      });

      // 2. منع متابعتي (إلغاء متابعته لي إذا كان يتابعني)
      batch.update(currentUserRef, {
        'followers': FieldValue.arrayRemove([userToBlacklistId]),
      });
      batch.update(targetUserRef, {
        'following': FieldValue.arrayRemove([currentUserId]),
      });

      await batch.commit();
    } catch (error) {
      print('Error blacklisting user: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// إبلاغ عن مستخدم
  Future<void> reportUser({
    required String currentUserId,
    required String userToReportId,
    required String reason,
  }) async {
    try {
      // Fetch names for better admin visualization
      final reporter = await getUser(currentUserId);
      final target = await getUser(userToReportId);

      await _firestore.collection('reports').add({
        'reporterId': currentUserId,
        'reporterName':
            reporter?.nickname ?? reporter?.username ?? 'مبلغ مجهول',
        'reportedUserId': userToReportId,
        'targetName': target?.nickname ?? target?.username ?? 'هدف مجهول',
        'reason': reason,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      print('Error reporting user: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// رفع الحظر
  Future<void> unblockUser({
    required String currentUserId,
    required String userToUnblockId,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayRemove([userToUnblockId]),
      });
    } catch (error) {
      print('Error unblocking user: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// إلغاء الأصمات
  Future<void> unmuteUser({
    required String currentUserId,
    required String userToUnmuteId,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(currentUserId).update({
        'mutedUsers': FieldValue.arrayRemove([userToUnmuteId]),
      });
    } catch (error) {
      print('Error unmuting user: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// إزالة من القائمة السوداء
  Future<void> removeBlacklistUser({
    required String currentUserId,
    required String userToRemoveId,
  }) async {
    try {
      await _firestore.collection(_usersCollection).doc(currentUserId).update({
        'blacklistedUsers': FieldValue.arrayRemove([userToRemoveId]),
      });
    } catch (error) {
      print('Error removing from blacklist: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// حذف حساب المستخدم
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).delete();
    } catch (error) {
      print('Error deleting account: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// إرسال تذكرة دعم فني (طلب استئناف)
  Future<void> submitSupportTicket({
    required String uid,
    required String username,
    required String reason,
    required String type, // 'ban', 'suspend', 'disable'
  }) async {
    await _firestore.collection('support_tickets').add({
      'userId': uid,
      'userName': username,
      'issueDescription': reason,
      'type': type,
      'status': 'pending', // pending, accepted, rejected
      'adminFeedback': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// الحصول على آخر تذكرة دعم للمستخدم
  Stream<QuerySnapshot> getUserSupportTicketsStream(String uid) {
    return _firestore
        .collection('support_tickets')
        .where('userId', isEqualTo: uid)
        .snapshots();
  }

  /// تحديث خصوصية الحساب
  Future<void> updateUserPrivacy(bool isPrivate) async {
    final uid = auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'isPrivate': isPrivate,
      });
    }
  }
}
