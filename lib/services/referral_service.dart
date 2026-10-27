import 'package:cloud_firestore/cloud_firestore.dart';

class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';

  /// تنظيف كود الدعوة ليتعامل مع صيغ مثل "ID: 123456" أو وجود مسافات
  String _normalizeReferralCode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    // استخراج الأرقام فقط إذا وُجدت (لمعرفات رقمية)
    final digitMatches = RegExp(r'\d+').allMatches(trimmed);
    final digits = digitMatches.map((m) => m.group(0)!).join();
    if (digits.isNotEmpty) return digits;

    // إزالة بادئة ID أو رموز شبيهة
    final cleaned = trimmed
        .toUpperCase()
        .replaceAll('ID', '')
        .replaceAll(':', '')
        .trim();

    return cleaned.isEmpty ? trimmed : cleaned;
  }

  /// ربط المستخدم الجديد بصديقه الذي دعاه عن طريق كود الدعوة (المعرف الرقمي أو كود مخصص)
  Future<void> applyReferralCode({
    required String newUserId,
    required String referralCode,
  }) async {
    final code = _normalizeReferralCode(referralCode);
    if (code.isEmpty) return;

    try {
      // البحث عن صاحب الكود باستخدام displayId أولاً
      var query = await _firestore
          .collection(_usersCollection)
          .where('displayId', isEqualTo: code)
          .limit(1)
          .get();

      // في حال لم نجد شيئاً، نحاول باستخدام حقل referralCode (لمن لديهم كود مخصص)
      if (query.docs.isEmpty) {
        query = await _firestore
            .collection(_usersCollection)
            .where('referralCode', isEqualTo: code)
            .limit(1)
            .get();
      }

      if (query.docs.isEmpty) {
        // كود غير صالح، لا نفعل شيئاً (يمكن لاحقاً إظهار رسالة للمستخدم)
        return;
      }

      final inviterDoc = query.docs.first;
      final inviterId = inviterDoc.id;

      // منع أن يدعو المستخدم نفسه
      if (inviterId == newUserId) return;

      final newUserRef =
          _firestore.collection(_usersCollection).doc(newUserId);
      await _firestore.runTransaction((transaction) async {
        final newUserSnap = await transaction.get(newUserRef);
        if (!newUserSnap.exists) return;

        final data = newUserSnap.data() as Map<String, dynamic>;
        // إذا كان لديه داعٍ من قبل لا نغيّره
        if (data['referredBy'] != null) return;

        transaction.update(newUserRef, {
          'referredBy': inviterId,
        });

        // Add the new user to the inviter's team list and reward with 50 diamonds
        final inviterRef = _firestore.collection(_usersCollection).doc(inviterId);
        transaction.update(inviterRef, {
          'referredUsers': FieldValue.arrayUnion([newUserId]),
          'diamonds': FieldValue.increment(50), // مكافأة 50 ماسة
        });

        // تسجيل العملية في السجلات
        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'userId': inviterId,
          'type': 'referral_signup_reward',
          'title': 'مكافأة دعوة عضو جديد',
          'amount': 50,
          'currency': 'diamonds',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });
      });
    } catch (e) {
      // نكتفي بالطباعة في الـ debug حتى لا نكسر عملية التسجيل
      // ignore: avoid_print
      print('Error applying referral code: $e');
    }
  }

  /// احتساب مكافأة يومية لصاحب الدعوات: ٥ عملات عن كل صديق مدعو "نشط" في هذا اليوم.
  /// تعاد قيمة العملات التي تمت إضافتها بالفعل في هذا الاستدعاء.
  Future<int> rewardInviterForActiveReferrals(String inviterId) async {
    final inviterRef =
        _firestore.collection(_usersCollection).doc(inviterId);

    try {
      // نجلب أعضاء الفريق عبر referredBy لتفادي صلاحيات تحديث حسابات الآخرين
      final teamSnapshot = await _firestore
          .collection(_usersCollection)
          .where('referredBy', isEqualTo: inviterId)
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int activeCount = 0;
      for (final doc in teamSnapshot.docs) {
        final data = doc.data();
        final bool isOnline = data['isOnline'] == true;

        DateTime? lastSeen;
        final lastSeenRaw = data['lastSeen'];
        if (lastSeenRaw is Timestamp) {
          lastSeen = lastSeenRaw.toDate();
        } else if (lastSeenRaw != null) {
          lastSeen = DateTime.tryParse(lastSeenRaw.toString());
        }

        if (isOnline) {
          activeCount++;
        } else if (lastSeen != null) {
          final lastSeenDay = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);
          if (lastSeenDay.isAtSameMomentAs(today)) {
            activeCount++;
          }
        }
      }

      final int coinsToAdd = activeCount * 5;

      return await _firestore.runTransaction((transaction) async {
        final inviterSnap = await transaction.get(inviterRef);
        if (!inviterSnap.exists) return 0;

        final inviterData = inviterSnap.data() as Map<String, dynamic>;

        // منع التكرار أكثر من مرة في اليوم
        DateTime? lastReward;
        final lastRewardRaw = inviterData['lastReferralRewardDate'];
        if (lastRewardRaw is Timestamp) {
          lastReward = lastRewardRaw.toDate();
        } else if (lastRewardRaw != null) {
          lastReward = DateTime.tryParse(lastRewardRaw.toString());
        }
        if (lastReward != null) {
          final lastDay =
              DateTime(lastReward.year, lastReward.month, lastReward.day);
          if (lastDay.isAtSameMomentAs(today)) {
            return 0;
          }
        }

        transaction.update(inviterRef, {
          'coins': FieldValue.increment(coinsToAdd),
          'lastReferralRewardDate': Timestamp.fromDate(now),
        });

        if (coinsToAdd > 0) {
          final logRef = _firestore.collection('transactions').doc();
          transaction.set(logRef, {
            'userId': inviterId,
            'type': 'referral_reward',
            'title': 'مكافأة دعوات الأصدقاء',
            'amount': coinsToAdd,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'completed',
          });
        }

        return coinsToAdd;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error rewarding referrals: $e');
      return 0;
    }
  }

  Stream<int> teamCountStream(String inviterId) {
    return _firestore
        .collection(_usersCollection)
        .where('referredBy', isEqualTo: inviterId)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<List<String>> getTeamIds(String inviterId) async {
    final snap = await _firestore
        .collection(_usersCollection)
        .where('referredBy', isEqualTo: inviterId)
        .get();
    return snap.docs.map((d) => d.id).toList();
  }
}

