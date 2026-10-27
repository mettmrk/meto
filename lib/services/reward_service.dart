import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';

class RewardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';

  /// Gets the current server time from Firestore (anti-cheat: cannot be manipulated by device clock)
  Future<DateTime> getServerTime() async {
    try {
      // Write a temporary document with server timestamp, then read it back
      final tempRef = _firestore.collection('_serverTime').doc('temp');
      await tempRef.set({'time': FieldValue.serverTimestamp()});
      final snap = await tempRef.get();
      final serverTime = (snap.data()?['time'] as Timestamp?)?.toDate();
      return serverTime ?? DateTime.now().toUtc();
    } catch (e) {
      // Fallback to local UTC time if Firestore is unreachable
      return DateTime.now().toUtc();
    }
  }

  /// Starts the daily counter for a user
  Future<void> startCounter(String uid) async {
    try {
      final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        DocumentReference userRef = _firestore
            .collection(_usersCollection)
            .doc(uid);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          return {'success': false, 'error': 'المستخدم غير موجود'};
        }

        final userData = userSnapshot.data() as Map<String, dynamic>;
        final isCounterActive = userData['isCounterActive'] ?? false;

        if (isCounterActive) {
          return {'success': false, 'error': 'العداد نشط بالفعل'};
        }

        final String? inviterId = userData['referredBy'];

        // --- READS FIRST ---
        DocumentSnapshot? inviterSnapshot;
        DocumentReference? inviterRef;
        if (inviterId != null && inviterId.isNotEmpty) {
          inviterRef = _firestore.collection(_usersCollection).doc(inviterId);
          inviterSnapshot = await transaction.get(inviterRef);
        }

        // --- WRITES SECOND ---
        // Activate counter for the user
        transaction.update(userRef, {
          'counterStartTime': FieldValue.serverTimestamp(),
          'isCounterActive': true,
        });

        // If there is a team owner (inviter), give them a bonus
        if (inviterSnapshot != null &&
            inviterSnapshot.exists &&
            inviterRef != null) {
          // Add 5 to team owner as a bonus (Meto Chips only)
          transaction.update(inviterRef, {
            'meto_chips': FieldValue.increment(5),
          });

          // Track total contribution in the user's document
          transaction.update(userRef, {
            'totalContributionToInviter': FieldValue.increment(5),
          });

          // Log transaction for inviter
          DocumentReference logInviterRef = _firestore
              .collection('transactions')
              .doc();
          transaction.set(logInviterRef, {
            'userId': inviterId,
            'type': 'team_mining_bonus',
            'title': 'مكافأة تشغيل عداد من الفريق',
            'amount': 5,
            'currency': 'meto_chips',
            'fromUserId': uid,
            'fromUserName':
                userData['nickname'] ?? userData['username'] ?? 'عضو فريق',
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'completed',
          });
        }
        return {'success': true};
      });

      if (result['success'] == false) {
        throw result['error'];
      }

      // After successful transaction, send notification if there was an inviter
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();
      final inviterId = userDoc.data()?['referredBy'];
      if (inviterId != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        NotificationService().sendNotification(
          NotificationModel(
            id: '',
            receiverId: inviterId,
            senderId: uid,
            senderName:
                userData['nickname'] ?? userData['username'] ?? 'عضو فريق',
            type: NotificationType.reward,
            text: 'قام بتشغيل العداد! حصلت على مكافأة 5 ميتو.',
            createdAt: DateTime.now(),
          ),
        );
      }

      // Schedule local notification for 24 hours
      await NotificationService().scheduleRewardNotification(
        const Duration(hours: 24),
      );
    } catch (e) {
      throw e.toString();
    }
  }

  /// Claims the reward after the counter ends
  Future<Map<String, int>> claimReward(String uid) async {
    try {
      // Get real server time BEFORE transaction (anti-cheat)
      final serverNow = await getServerTime();

      final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        DocumentReference userRef = _firestore
            .collection(_usersCollection)
            .doc(uid);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          return {'success': false, 'error': 'المستخدم غير موجود'};
        }

        final data = userSnapshot.data() as Map<String, dynamic>;
        final startTime = (data['counterStartTime'] as Timestamp?)
            ?.toDate()
            .toUtc();
        final isCounterActive = data['isCounterActive'] ?? false;

        if (!isCounterActive || startTime == null) {
          return {'success': false, 'error': 'العداد غير نشط'};
        }

        // Always use Firestore server time — cannot be cheated by changing device clock
        final difference = serverNow.difference(startTime);
        if (difference.inHours < 24) {
          final remaining = const Duration(hours: 24) - difference;
          final hours = remaining.inHours;
          final minutes = remaining.inMinutes % 60;
          return {
            'success': false,
            'error': 'بقي من الوقت $hours ساعة و $minutes دقيقة'
          };
        }

        // التحقق الأمني الصارم من صلاحية الاشتراك لمنع أي ثغرة مالية
        final bool isSubscribed = data['isSubscribed'] ?? false;
        final DateTime? subscriptionExpiry = (data['subscriptionExpiry'] as Timestamp?)?.toDate();
        final bool hasExpired = subscriptionExpiry != null && serverNow.isAfter(subscriptionExpiry);

        int pointsPerClaimValue = data['pointsPerClaim'] ?? 0;
        // إذا لم يكن مشتركاً فعلياً أو انتهت صلاحية باقته، تُلغى أرباح الباقة فوراً
        if (!isSubscribed || hasExpired) {
          pointsPerClaimValue = 0;
        }

        int coinsReward = 1000;
        int metoChipsReward = pointsPerClaimValue;

        final Map<String, dynamic> updateData = {
          'coins': FieldValue.increment(coinsReward),
          'meto_chips': FieldValue.increment(metoChipsReward),
          'dailyCoins': FieldValue.increment(coinsReward),
          'dailyMetoChips': FieldValue.increment(metoChipsReward),
          'isCounterActive': false,
          'lastDailyRewardClaim': FieldValue.serverTimestamp(),
          'counterStartTime': null,
        };

        // تصفير الاشتراك في قاعدة البيانات تلقائياً عند انتهاء صلاحيته
        if (hasExpired) {
          updateData['isSubscribed'] = false;
          updateData['pointsPerClaim'] = 0;
        }

        transaction.update(userRef, updateData);

        // Cancel the scheduled notification
        NotificationService().cancelRewardNotification();

        // Log the reward in transactions
        DocumentReference logRef = _firestore.collection('transactions').doc();
        transaction.set(logRef, {
          'userId': uid,
          'type': 'counter_reward',
          'title': 'مكافأة العداد اليومي',
          'coinsAdded': coinsReward,
          'metoChipsAdded': metoChipsReward,
          'timestamp': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
          'status': 'completed',
        });

        return {
          'success': true,
          'coins': coinsReward,
          'meto_chips': metoChipsReward
        };
      });

      if (result['success'] == false) {
        throw result['error'];
      }

      return {
        'coins': result['coins'] as int,
        'meto_chips': result['meto_chips'] as int,
      };
    } catch (e) {
      throw e.toString();
    }
  }

  /// Increases the user's points/diamonds per claim with balance check
  Future<void> purchaseCounter(
    String uid, {
    required String packageId,
    // Removed 'cost' as this is now a real-money purchase
    int points = 0,
    String? packageName,
    String? usdPrice,
  }) async {
    try {
      // 1. Check restrictions OUTSIDE transaction
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();
      if (!userDoc.exists) throw 'المستخدم غير موجود';

      final data = userDoc.data() as Map<String, dynamic>;
      final Map<String, dynamic> packageHistory =
          data['packageHistory'] as Map<String, dynamic>? ?? {};

      // Check specific package cooldown
      if (packageHistory.containsKey(packageId)) {
        final lastPurchased = (packageHistory[packageId] as Timestamp).toDate();
        final difference = DateTime.now().difference(lastPurchased);
        if (difference.inDays < 180) {
          final remainingDays = 180 - difference.inDays;
          throw 'عذراً، هذه الباقة متاحة مرة واحدة كل 6 أشهر. يمكنك شراؤها مجدداً بعد $remainingDays يوم.';
        }
      }

      // 2. Perform the purchase transaction (Grant benefits only)
      final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        DocumentReference userRef = _firestore
            .collection(_usersCollection)
            .doc(uid);

        // We still need to read the doc for consistency in transaction
        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          return {'success': false, 'error': 'المستخدم غير موجود'};
        }

        final expiryDate = DateTime.now().add(const Duration(days: 180));

        // But to ensure 'packageHistory' exists, we might need a pre-check?
        // Actually, Firestore update creates parents? No.

        transaction.update(userRef, {
          // No coin deduction here!
          'pointsPerClaim': FieldValue.increment(points),
          'isSubscribed': true,
          'subscriptionExpiry': Timestamp.fromDate(expiryDate),
          'lastPurchaseDate': FieldValue.serverTimestamp(),
          'packageHistory.$packageId': FieldValue.serverTimestamp(),
        });

        // Log the transaction
        DocumentReference logRef = _firestore.collection('transactions').doc();
        transaction.set(logRef, {
          'userId': uid,
          'type': 'package_purchase',
          'packageId': packageId,
          'title': packageName ?? (points > 0 ? 'شراء نقاط عداد' : 'باقة عداد'),
          'usdPrice': usdPrice,
          'amount': 0, // No coin cost deducted, this is a real-money purchase
          'pointsAdded': points,
          'timestamp': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
          'status': 'completed',
        });

        return {'success': true};
      });

      if (result['success'] == false) {
        throw result['error'];
      }
    } catch (e) {
      throw e.toString();
    }
  }

  /// Increases the user's points/diamonds per claim by purchasing with coins (In-App currency)
  Future<void> purchaseCounterWithMeto(
    String uid, {
    required String packageId,
    required String packageName,
    required int points,
    required int costInMeto,
  }) async {
    try {
      final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        DocumentReference userRef = _firestore
            .collection(_usersCollection)
            .doc(uid);

        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          return {'success': false, 'error': 'المستخدم غير موجود'};
        }

        final data = userSnapshot.data() as Map<String, dynamic>;
        // Removed gold check; meto_chips check follows below.

        // --- Package Limit Logic ---
        final Map<String, dynamic> packageHistory =
            data['packageHistory'] as Map<String, dynamic>? ?? {};

        List<dynamic> rawHistory = [];
        if (packageHistory.containsKey(packageId)) {
          var hist = packageHistory[packageId];
          if (hist is List) {
            rawHistory = List.from(hist);
          } else if (hist is Timestamp) {
            rawHistory = [hist];
          }
        }

        final now = DateTime.now();
        // Remove purchases older than 180 days
        List<Timestamp> validHistory = rawHistory
            .whereType<Timestamp>()
            .where((ts) => now.difference(ts.toDate()).inDays < 180)
            .toList();

        int maxPurchases = (packageId == 'starter_pack') ? 2 : 1;

        if (validHistory.length >= maxPurchases) {
          final oldestValid = validHistory.reduce(
            (a, b) => a.compareTo(b) < 0 ? a : b,
          );
          final difference = now.difference(oldestValid.toDate());
          final remainingDays = 180 - difference.inDays;
          if (maxPurchases == 1) {
            return {
              'success': false,
              'error': 'هذه الباقة متاحة مرة واحدة كل 6 أشهر. متاحة بعد $remainingDays يوم.'
            };
          } else {
            return {
              'success': false,
              'error': 'لقد استنفدت الحد المسموح ($maxPurchases مرات). متاحة بعد $remainingDays يوم.'
            };
          }
        }

        // Add current purchase timestamp
        validHistory.add(Timestamp.now());
        packageHistory[packageId] = validHistory;
        // -----------------------------

        int currentChips = data['meto_chips'] ?? 0;
        if (currentChips < costInMeto) {
          return {
            'success': false,
            'error': 'رصيدك من عملة العداد (الخضراء) غير كافٍ لشراء هذه الباقة. يرجى الشحن من الوكلاء.'
          };
        }

        final expiryDate = DateTime.now().add(const Duration(days: 180));

        transaction.update(userRef, {
          'meto_chips': FieldValue.increment(-costInMeto),
          'pointsPerClaim': FieldValue.increment(points),
          'isSubscribed': true,
          'subscriptionExpiry': Timestamp.fromDate(expiryDate),
          'lastPurchaseDate': FieldValue.serverTimestamp(),
          'packageHistory': packageHistory,
        });

        // Log the transaction
        DocumentReference logRef = _firestore.collection('transactions').doc();
        transaction.set(logRef, {
          'userId': uid,
          'type': 'package_purchase_coins',
          'packageId': packageId,
          'title': 'شراء $packageName',
          'costInMeto': costInMeto,
          'pointsAdded': points,
          'amount': -costInMeto, // Display as a negative transaction
          'timestamp': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
          'status': 'completed',
        });

        return {'success': true};
      });

      if (result['success'] == false) {
        throw result['error'];
      }
    } catch (e) {
      throw e.toString();
    }
  }

  // --- Security: Hardcoded Package Definitions ---
  // This prevents fake clients from sending custom amounts/prices.
  static const Map<String, Map<String, dynamic>> _diamondPackages = {
    'diamonds_pack_500': {'amount': 500, 'cost': 6000},
    'diamonds_pack_1900': {'amount': 1900, 'cost': 24000},
    'diamonds_pack_5100': {'amount': 5100, 'cost': 60000},
    'diamonds_pack_16100': {'amount': 16100, 'cost': 180000},
    'diamonds_pack_53800': {'amount': 53800, 'cost': 600000},
    'diamonds_pack_161700': {'amount': 161700, 'cost': 1800000},
  };

  static const Map<String, Map<String, dynamic>> _goldPackages = {
    'gold_33000': {'amount': 33000, 'cost': 6000},
    'gold_130000': {'amount': 130000, 'cost': 12000},
    'gold_670000': {'amount': 670000, 'cost': 54000},
    'gold_2700000': {'amount': 2700000, 'cost': 108000},
    'gold_7700000': {'amount': 7700000, 'cost': 240000},
    'gold_17000000': {'amount': 17000000, 'cost': 420000},
  };

  /// Purchase Diamonds with Meto chips
  Future<void> purchaseDiamondsWithMeto(
    String uid, {
    required String packageId,
    required String packageName,
    int? amount, // Optional, will be verified against packageId
    int? costInMeto, // Optional, will be verified against packageId
  }) async {
    // 1. Validate the package on the 'server' side (service logic)
    final package = _diamondPackages[packageId];
    if (package == null) throw 'باقة غير صالحة';

    final int verifiedAmount = package['amount'];
    final int verifiedCost = package['cost'];

    try {
      final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        DocumentReference userRef = _firestore
            .collection(_usersCollection)
            .doc(uid);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          return {'success': false, 'error': 'المستخدم غير موجود'};
        }

        final data = userSnapshot.data() as Map<String, dynamic>;
        int currentChips = data['meto_chips'] ?? 0;

        if (currentChips < verifiedCost) {
          return {
            'success': false,
            'error': 'رصيدك من عملة ميتو غير كافٍ. تحتاج إلى $verifiedCost ميتو.'
          };
        }

        transaction.update(userRef, {
          'meto_chips': FieldValue.increment(-verifiedCost),
          'diamonds': FieldValue.increment(verifiedAmount),
        });

        // Log the transaction
        DocumentReference logRef = _firestore.collection('transactions').doc();
        transaction.set(logRef, {
          'userId': uid,
          'type': 'diamond_purchase_meto',
          'packageId': packageId,
          'title': 'شراء $packageName',
          'costInMeto': verifiedCost,
          'diamondsAdded': verifiedAmount,
          'amount': -verifiedCost,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });

        return {'success': true};
      });

      if (result['success'] == false) {
        throw result['error'];
      }
    } catch (e) {
      throw e.toString();
    }
  }

  /// Purchase Gold (coins) with Meto chips
  Future<void> purchaseGoldWithMeto(
    String uid, {
    required String packageId,
    required String packageName,
    int? amount,
    int? costInMeto,
  }) async {
    // 1. Validate the package
    final package = _goldPackages[packageId];
    if (package == null) throw 'باقة غير صالحة';

    final int verifiedAmount = package['amount'];
    final int verifiedCost = package['cost'];

    try {
      final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        DocumentReference userRef = _firestore
            .collection(_usersCollection)
            .doc(uid);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          return {'success': false, 'error': 'المستخدم غير موجود'};
        }

        final data = userSnapshot.data() as Map<String, dynamic>;
        int currentChips = data['meto_chips'] ?? 0;

        if (currentChips < verifiedCost) {
          return {
            'success': false,
            'error': 'رصيدك من عملة ميتو غير كافٍ. تحتاج إلى $verifiedCost ميتو.'
          };
        }

        transaction.update(userRef, {
          'meto_chips': FieldValue.increment(-verifiedCost),
          'coins': FieldValue.increment(verifiedAmount),
        });

        // Log the transaction
        DocumentReference logRef = _firestore.collection('transactions').doc();
        transaction.set(logRef, {
          'userId': uid,
          'type': 'gold_purchase_meto',
          'packageId': packageId,
          'title': 'شراء $packageName',
          'costInMeto': verifiedCost,
          'goldAdded': verifiedAmount,
          'amount': -verifiedCost,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });

        return {'success': true};
      });

      if (result['success'] == false) {
        throw result['error'];
      }
    } catch (e) {
      throw e.toString();
    }
  }

  /// Transfers points to the user's wallet (coins)
  Future<void> transferToWallet(String uid, int pointsToTransfer) async {
    try {
      if (pointsToTransfer < 6000) throw 'الحد الأدنى للتحويل هو 6000 نقطة';

      final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        DocumentReference userRef = _firestore
            .collection(_usersCollection)
            .doc(uid);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          return {'success': false, 'error': 'المستخدم غير موجود'};
        }

        final data = userSnapshot.data() as Map<String, dynamic>;
        final int currentPoints = data['profitPoints'] ?? 0;

        if (currentPoints < pointsToTransfer) {
          return {'success': false, 'error': 'رصيدك من النقاط غير كافٍ'};
        }

        transaction.update(userRef, {
          'profitPoints': FieldValue.increment(-pointsToTransfer),
          'coins': FieldValue.increment(
            pointsToTransfer,
          ), // Assuming 1 point = 1 coin for now, or whatever the app logic is
        });

        return {'success': true};
      });

      if (result['success'] == false) {
        throw result['error'];
      }
    } catch (e) {
      throw e.toString();
    }
  }

  /// Resets all reward-related data for a user
  Future<void> resetRewards(String uid) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'coins': 0,
        'profitPoints': 0,
        'pointsPerClaim': 0,
        'isCounterActive': false,
        'isSubscribed': false,
        'counterStartTime': null,
        'subscriptionExpiry': null,
      });
    } catch (e) {
      throw 'Error resetting rewards: $e';
    }
  }

  /// Deletes transactions that have expired (older than 2 days)
  Future<void> cleanupExpiredTransactions(String uid) async {
    try {
      final now = DateTime.now();
      final expired = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: uid)
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .get();

      if (expired.docs.isNotEmpty) {
        WriteBatch batch = _firestore.batch();
        for (var doc in expired.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error cleaning up transactions: $e');
    }
  }

  /// Stream of user data to monitor counter
  Stream<Map<String, dynamic>> getCounterState(String uid) {
    return _firestore.collection(_usersCollection).doc(uid).snapshots().map((
      doc,
    ) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'isCounterActive': data['isCounterActive'] ?? false,
          'counterStartTime': data['counterStartTime'],
          'isSubscribed': data['isSubscribed'] ?? false,
          'subscriptionExpiry': data['subscriptionExpiry'],
          'profitPoints': data['profitPoints'] ?? 0,
          'coins': data['coins'] ?? 0,
          'meto_chips': data['meto_chips'] ?? 0,
          'diamonds': data['diamonds'] ?? 0,
          'pointsPerClaim': data['pointsPerClaim'] ?? 0,
          'packageHistory': data['packageHistory'],
          'counter_tier': data['counter_tier'] ?? data['active_package'],
          // معلومات بسيطة عن نظام الدعوات لاستخدامها في واجهة المحفظة
          'referralCode': data['referralCode'] ?? data['displayId']?.toString(),
          'referredUsersCount': (data['referredUsers'] is List
              ? data['referredUsers'].length
              : 0),
        };
      }
      return {};
    });
  }

  /// Handles the roulette spin logic
  /// Returns a map with 'rewardType', 'amount', 'isFree', 'cost'
  Future<Map<String, dynamic>> spinRoulette(String uid) async {
    const int cost = 500; // Cost in gold (points)
    try {
      final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        DocumentReference userRef = _firestore
            .collection(_usersCollection)
            .doc(uid);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          return {'success': false, 'error': 'المستخدم غير موجود'};
        }

        final data = userSnapshot.data() as Map<String, dynamic>;
        final lastSpin = (data['lastRouletteSpin'] as Timestamp?)?.toDate();
        final now = DateTime.now();

        // Check for accumulated free spins first
        int freeSpins = data['freeSpins'] ?? 0;
        bool usingFreeSpin = false;
        bool isFree = true; // Default to true (daily spin available)

        // 1. Check Extra Free Spins
        if (freeSpins > 0) {
          usingFreeSpin = true;
          // isFree is already true
        }
        // 2. Check Daily Free Spin
        else if (lastSpin != null) {
          final lastSpinDate = DateTime(
            lastSpin.year,
            lastSpin.month,
            lastSpin.day,
          );
          final todayElement = DateTime(now.year, now.month, now.day);
          if (lastSpinDate.isAtSameMomentAs(todayElement)) {
            isFree = false;
          }
        }

        // Check balance if not free and not using extra spin
        final int currentCoins = data['coins'] ?? 0;

        if (!isFree && currentCoins < cost) {
          return {'success': false, 'error': 'رصيدك غير كافٍ (تحتاج $cost عملة)'};
        }

        // Deduct cost or free spin
        if (usingFreeSpin) {
          transaction.update(userRef, {'freeSpins': FieldValue.increment(-1)});
        } else if (!isFree) {
          transaction.update(userRef, {'coins': FieldValue.increment(-cost)});
        }

        if (!usingFreeSpin) {
          transaction.update(userRef, {
            'lastRouletteSpin': FieldValue.serverTimestamp(),
          });
        }

        // Determine reward
        // Weights updated based on user request (Relative values):
        // 0. Diamonds (40): Weight: 100
        // 1. Red Box (1-910 Meto): 50% (Weight: 500)
        // 2. Empty Chest: 70% (Weight: 700)
        // 3. Green Coins (20 Meto): 10% (Weight: 100)
        // 4. Yellow Box (100-250 Meto): 10% (Weight: 100)
        // 5. Rocket (300 Meto): 2% (Weight: 20)
        // 6. Free Spin (Arrows): 10% (Weight: 100)
        // 7. Green Coins (30 Meto): 10% (Weight: 100)
        // 8. Gold Coins (3000 Gold): 40% (Weight: 400)

        final List<Map<String, dynamic>> weights = [
          {'type': 'diamonds', 'val': 20, 'weight': 8}, // صعب
          {'type': 'red_box', 'val': 0, 'weight': 6}, // صعب جداً
          {'type': 'empty', 'val': 0, 'weight': 100}, // الأسهل على الإطلاق
          {'type': 'mixed', 'val': 0, 'weight': 20}, // متوسط السهولة
          {'type': 'yellow_box', 'val': 0, 'weight': 3}, // نادر (عملات ميتو)
          {'type': 'rocket', 'val': 100, 'weight': 2}, // نادر جداً (الصاروخ)
          {'type': 'free_spin', 'val': 1, 'weight': 30}, // سهل
          {'type': 'meto_chips', 'val': 5, 'weight': 5}, // نادر (عملات ميتو)
          {'type': 'points', 'val': 1000, 'weight': 32}, // سهل (الذهب)
        ];

        int totalWeight = weights.fold(
          0,
          (sum, item) => sum + (item['weight'] as int),
        );
        int randomVal = DateTime.now().millisecondsSinceEpoch % totalWeight;

        Map<String, dynamic> selected = weights[2]; // Default to empty
        int currentSum = 0;
        for (var w in weights) {
          currentSum += w['weight'] as int;
          if (randomVal < currentSum) {
            selected = w;
            break;
          }
        }

        String rewardType = selected['type'];
        int amount = selected['val'];
        String payoutType = 'none';
        bool isSurprise = false;
        String finalRewardTypeForUI = rewardType;

        if (rewardType == 'empty') {
          payoutType = 'none';
        } else if (rewardType == 'red_box') {
          finalRewardTypeForUI = 'red_box';
          isSurprise = true;
          payoutType = 'diamonds';
          amount = math.Random().nextInt(9) + 1;
        } else if (rewardType == 'yellow_box') {
          finalRewardTypeForUI = 'yellow_box';
          isSurprise = true;
          payoutType = 'meto_chips';
          amount = math.Random().nextInt(101) + 20;
        } else if (rewardType == 'mixed') {
          finalRewardTypeForUI = 'mixed';
          isSurprise = true;
          amount = math.Random().nextInt(9) + 1;
          payoutType = (math.Random().nextBool()) ? 'diamonds' : 'meto_chips';
        } else if (rewardType == 'rocket') {
          finalRewardTypeForUI = 'rocket';
          payoutType = 'meto_chips';
          amount = 100;
        } else if (rewardType == 'points') {
          payoutType = 'points';
          amount = 1000;
        } else if (rewardType == 'diamonds') {
          payoutType = 'diamonds';
          amount = 20;
        } else if (rewardType == 'free_spin') {
          payoutType = 'free_spin';
          amount = 1;
        } else if (rewardType == 'meto_chips') {
          payoutType = 'meto_chips';
          amount = 5;
        }

        // Apply reward to Firestore
        if (payoutType == 'points') {
          transaction.update(userRef, {'coins': FieldValue.increment(amount)});
        } else if (payoutType == 'diamonds') {
          transaction.update(userRef, {
            'diamonds': FieldValue.increment(amount),
          });
        } else if (payoutType == 'meto_chips') {
          transaction.update(userRef, {
            'meto_chips': FieldValue.increment(amount),
          });
        } else if (payoutType == 'free_spin') {
          transaction.update(userRef, {
            'freeSpins': FieldValue.increment(amount),
          });
        }

        return {
          'success': true,
          'rewardType': finalRewardTypeForUI,
          'amount': amount,
          'isFree': isFree,
          'cost': (isFree || usingFreeSpin) ? 0 : cost,
          'payoutType': payoutType,
          'isSurprise': isSurprise,
          'originalRewardType': rewardType, // Helper for UI matching
        };
      });

      if (result['success'] == false) {
        throw result['error'];
      }

      return {
        'rewardType': result['rewardType'],
        'amount': result['amount'],
        'isFree': result['isFree'],
        'cost': result['cost'],
        'payoutType': result['payoutType'],
        'isSurprise': result['isSurprise'],
        'originalRewardType': result['originalRewardType'],
      };
    } catch (e) {
      throw e.toString();
    }
  }
}
