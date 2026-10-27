// ignore_for_file: unnecessary_import

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/index.dart';
import '../utils/room_level_system.dart';
import 'notification_service.dart';
import '../models/notification_model.dart';

class GiftService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';
  final String _transactionsCollection = 'gift_transactions';
  final String _giftsCollection = 'gifts';
  final String _framesCollection = 'frames';
  final String _profileFramesCollection = 'etar_Profile';
  final String _backgroundsCollection = 'backgrounds';

  // Cache for frames
  static List<ProfileFrame>? _cachedProfileFrames;
  static List<ProfileFrame>? _cachedRoomFrames;
  static DateTime? _lastProfileFrameFetch;

  /// Returns all cached frames without fetching (for instant UI rendering)
  static List<ProfileFrame>? getCachedFrames() {
    if (_cachedProfileFrames == null && _cachedRoomFrames == null) return null;
    return [...(_cachedProfileFrames ?? []), ...(_cachedRoomFrames ?? [])];
  }

  /// الحصول على قائمة الهدايا من فيرسبت
  Stream<List<Gift>> getGiftsStream() {
    return _firestore.collection(_giftsCollection).snapshots().map((snapshot) {
      try {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          // Use the Firestore document ID as fallback if 'id' field is missing or empty
          if (data['id'] == null || data['id'].toString().isEmpty) {
            data['id'] = doc.id;
          }
          return Gift.fromMap(data);
        }).toList();
      } catch (e) {
        print('Error mapping gifts: $e');
        return [];
      }
    });
  }

  /// مزامنة الهدايا المحلية إلى قاعدة البيانات (مع تنظيف القديم)
  Future<void> syncGiftsToFirestore() async {
    try {
      print('جاري بدء مزامنة الهدايا...');
      // 1. جلب جميع الهدايا الحالية لحذفها
      final existingGifts = await _firestore.collection(_giftsCollection).get();
      if (existingGifts.docs.isNotEmpty) {
        final deleteBatch = _firestore.batch();
        for (var doc in existingGifts.docs) {
          deleteBatch.delete(doc.reference);
        }
        await deleteBatch.commit();
        print('تم مسح ${existingGifts.docs.length} هدية قديمة بنجاح');
      } else {
        print('لا توجد هدايا قديمة لمسحها');
      }

      // 2. إضافة الهدايا الجديدة
      final addBatch = _firestore.batch();
      for (var gift in predefinedGifts) {
        final docRef = _firestore.collection(_giftsCollection).doc(gift.id);
        addBatch.set(docRef, gift.toMap());
      }
      await addBatch.commit();
      print('تمت مزامنة ${predefinedGifts.length} هدية جديدة بنجاح');
    } catch (e) {
      print('خطأ أثناء مزامنة الهدايا: $e');
    }
  }

  /// تحديث صور الهدايا في Firestore لتستخدم روابط الـ Storage الحقيقية
  Future<void> updateGiftsWithStorageUrls() async {
    final storage = FirebaseStorage.instance;
    final snapshot = await _firestore.collection(_giftsCollection).get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String giftId = doc.id;
      final String currentIcon = data['icon'] ?? '';

      // إذا كان المسار محلي ويبدأ بـ assets، نقوم باستبداله
      if (currentIcon.contains('assets/images/icon/')) {
        final String fileName = currentIcon.split('/').last; // يجلب "1 (1).png"
        try {
          final String downloadUrl = await storage
              .ref('icon/$fileName')
              .getDownloadURL();

          await _firestore.collection(_giftsCollection).doc(giftId).update({
            'image': downloadUrl,
            // 'icon': downloadUrl, // يمكن تحديثه أيضاً إذا كان الودجيت يعتمد عليه
          });
          print('تم تحديث $giftId بالرابط الجديد');
        } catch (e) {
          print('فشل جلب الرابط للملف $fileName: $e');
        }
      }
    }
  }

  /// جلب تيار إطارات الملف الشخصي من Firestore (etar_Profile)
  Stream<List<ProfileFrame>> getProfileFramesStream() {
    // Return live stream directly to ensure real-time updates
    return _firestore.collection(_profileFramesCollection).snapshots().map((
      snapshot,
    ) {
      try {
        final frames = snapshot.docs
            .map((doc) => ProfileFrame.fromMap(doc.data(), doc.id))
            .toList();
        _cachedProfileFrames = frames;
        _lastProfileFrameFetch = DateTime.now();
        return frames;
      } catch (e) {
        print('Error mapping profile frames: $e');
        return _cachedProfileFrames ?? [];
      }
    });
  }

  /// جلب تيار إطارات الغرف من Firestore (frames)
  /// تستخدم داخل الغرف للإهداء المؤقت
  Stream<List<ProfileFrame>> getRoomFramesStream() {
    // Return live stream directly
    return _firestore.collection(_framesCollection).snapshots().map((snapshot) {
      try {
        final frames = snapshot.docs
            .map((doc) => ProfileFrame.fromMap(doc.data(), doc.id))
            .toList();
        _cachedRoomFrames = frames;
        return frames;
      } catch (e) {
        print('Error mapping room frames: $e');
        return _cachedRoomFrames ?? [];
      }
    });
  }

  /// دمج جميع الإطارات (الشخصية + الغرف) لعرضها في الصورة الرمزية
  Stream<List<ProfileFrame>> getAllFramesStream() {
    // We create a new stream for each listener to avoid single-subscription issues.
    // Since snapshots() are already broadcast-capable, this works cleanly for multiple widgets.
    return _firestore
        .collection(_profileFramesCollection)
        .snapshots()
        .map((profileSnapshot) {
          final pFrames = profileSnapshot.docs
              .map((doc) => ProfileFrame.fromMap(doc.data(), doc.id))
              .toList();
          _cachedProfileFrames = pFrames;
          return pFrames;
        })
        .asyncMap((pFrames) async {
          // Secondary fetch for room frames or return cached if possible
          final roomSnapshot = await _firestore
              .collection(_framesCollection)
              .get();
          final rFrames = roomSnapshot.docs
              .map((doc) => ProfileFrame.fromMap(doc.data(), doc.id))
              .toList();
          _cachedRoomFrames = rFrames;
          return [...pFrames, ...rFrames];
        })
        .asBroadcastStream();
  }

  /// الحصول على قائمة إطارات الملف الشخصي بشكل مباشر (Cached if available)
  Future<List<ProfileFrame>> getProfileFramesOnce() async {
    if (_cachedProfileFrames != null &&
        _lastProfileFrameFetch != null &&
        DateTime.now().difference(_lastProfileFrameFetch!).inMinutes < 10) {
      return _cachedProfileFrames!;
    }

    final snapshot = await _firestore
        .collection(_profileFramesCollection)
        .get();
    final frames = snapshot.docs
        .map((doc) => ProfileFrame.fromMap(doc.data(), doc.id))
        .toList();
    _cachedProfileFrames = frames;
    _lastProfileFrameFetch = DateTime.now();
    return frames;
  }

  /// مزامنة الإطارات المحلية إلى Firestore
  Future<void> syncFramesToFirestore() async {
    final batch = _firestore.batch();
    for (var frame in predefinedFrames) {
      final docRef = _firestore.collection(_framesCollection).doc(frame.id);
      batch.set(docRef, frame.toMap());
    }
    await batch.commit();
  }

  /// جلب تيار الخلفيات من Firestore
  Stream<List<RoomBackground>> getBackgroundsStream() {
    return _firestore.collection(_backgroundsCollection).snapshots().map((
      snapshot,
    ) {
      try {
        return snapshot.docs
            .map((doc) => RoomBackground.fromMap(doc.data(), doc.id))
            .toList();
      } catch (e) {
        print('Error mapping backgrounds: $e');
        return [];
      }
    });
  }

  /// مزامنة الخلفيات المحلية إلى Firestore
  Future<void> syncBackgroundsToFirestore() async {
    final batch = _firestore.batch();
    for (var bg in predefinedBackgrounds) {
      final docRef = _firestore.collection(_backgroundsCollection).doc(bg.id);
      batch.set(docRef, bg.toMap());
    }
    await batch.commit();
  }

  /// تحديث خلفية الغرفة
  Future<void> setRoomBackground(String roomId, String backgroundId) async {
    await _firestore.collection('rooms').doc(roomId).update({
      'backgroundId': backgroundId,
    });
  }

  /// شراء خلفية للغرفة بالماس
  Future<void> purchaseRoomBackground({
    required String userId,
    required String roomId,
    required RoomBackground background,
  }) async {
    try {
      final result = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        DocumentReference userRef = _firestore
            .collection(_usersCollection)
            .doc(userId);
        DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);

        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          return {'success': false, 'error': 'المستخدم غير موجود'};
        }

        int currentDiamonds = userSnapshot.get('diamonds') ?? 0;
        if (currentDiamonds < background.price) {
          return {'success': false, 'error': 'رصيدك من الماس غير كافٍ لشراء هذه الخلفية'};
        }

        // 1. خصم الماس
        transaction.update(userRef, {
          'diamonds': FieldValue.increment(-background.price),
        });

        // 2. تحديث خلفية الغرفة
        transaction.update(roomRef, {'backgroundId': background.id});

        // 3. (اختياري) تسجيل العملية في سجل المشتريات
        DocumentReference logRef = _firestore
            .collection('background_purchases')
            .doc();
        transaction.set(logRef, {
          'userId': userId,
          'roomId': roomId,
          'backgroundId': background.id,
          'backgroundName': background.name,
          'price': background.price,
          'timestamp': FieldValue.serverTimestamp(),
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

  /// إرسال هدية من مستخدم لآخر (في الغرف الصوتية)
  Future<void> sendRoomGift({
    required String senderId,
    required String receiverId,
    required String roomId,
    required Gift gift,
    required String senderName,
    String? senderProfileImage,
    int quantity = 1,
  }) async {
    try {
      final int totalCost = gift.price * quantity;
      final syncResult = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        // 1. All Reads First
        DocumentReference senderRef = _firestore
            .collection(_usersCollection)
            .doc(senderId);
        DocumentReference receiverRef = _firestore
            .collection(_usersCollection)
            .doc(receiverId);
        DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);

        DocumentSnapshot senderSnapshot = await transaction.get(senderRef);
        DocumentSnapshot receiverSnapshot = await transaction.get(receiverRef);
        DocumentSnapshot roomSnapshot = await transaction.get(roomRef);

        if (!senderSnapshot.exists) return {'success': false, 'error': 'المستخدم غير موجود'};
        if (!roomSnapshot.exists) return {'success': false, 'error': 'الغرفة غير موجودة'};

        // Fetch Room Host Display ID
        String roomDisplayId = roomId; // Default
        String? hostId = roomSnapshot.get('hostId');
        if (hostId != null) {
          DocumentReference hostRef = _firestore
              .collection(_usersCollection)
              .doc(hostId);
          DocumentSnapshot hostSnapshot = await transaction.get(hostRef);
          if (hostSnapshot.exists) {
            roomDisplayId = hostSnapshot.get('displayId') ?? hostId;
          }
        }

        // Use the currency dictated by the gift
        final String currencyField = gift.currency == Currency.diamonds
            ? 'diamonds'
            : (gift.currency == Currency.meto ? 'meto_chips' : 'coins');

        final String currencyNameAr = gift.currency == Currency.diamonds
            ? 'الماس'
            : (gift.currency == Currency.meto ? 'عملة ميتو' : 'ذهب');

        int currentBalance = senderSnapshot.get(currencyField) ?? 0;
        if (currentBalance < totalCost) {
          return {'success': false, 'error': 'رصيدك من $currencyNameAr غير كافٍ لإرسال هذه الهدية'};
        }

        String receiverName = receiverSnapshot.exists
            ? (receiverSnapshot.get('nickname') ?? 'مستخدم')
            : 'مستخدم';

        // Ensure we have sender profile image
        String? finalSenderImage = senderProfileImage;
        if (finalSenderImage == null) {
          final senderData = senderSnapshot.data() as Map<String, dynamic>?;
          finalSenderImage =
              senderData?['profileImage'] ?? senderData?['photoURL'];
        }

        // Use the manual image URL if available, otherwise fallback to icon asset
        final String effectiveGiftIcon = gift.image ?? gift.icon;

        // --- Room Level & Daily User Cap Logic ---
        double xpToAdd = 0.0;
        if (gift.currency == Currency.diamonds) {
          xpToAdd = RoomLevelSystem.calculateXP(diamonds: totalCost);
        } else {
          // General mapping for other currencies
          xpToAdd = RoomLevelSystem.calculateXP(gold: totalCost);
        }

        // IMPORTANT: Must happen before ANY transaction.update calls to respect Firestore rules
        await RoomLevelSystem.awardPointsToRoom(
          pointsToAward: xpToAdd,
          roomId: roomId,
          userId: senderId,
          activeTransaction: transaction,
        );

        // 3. All Writes
        transaction.update(senderRef, {
          currencyField: FieldValue.increment(-totalCost),
        });

        // --- Revenue Distribution Logic ---
        int receiverEarnings = 0;
        int ownerEarnings = 0;
        int staffEarnings = 0;
        int staffCount = 0;

        // Only Diamonds and Meto get shared. Gold (coins) gets 0% sharing as requested.
        if (gift.currency == Currency.diamonds ||
            gift.currency == Currency.meto) {
          receiverEarnings = (totalCost * 0.20).floor();
          ownerEarnings = (totalCost * 0.15).floor();
          staffEarnings = (totalCost * 0.02).floor();

          // 1. Pay Receiver
          transaction.update(receiverRef, {
            currencyField: FieldValue.increment(receiverEarnings),
          });

          // 2. Pay Room Owner (Host)
          if (hostId != null) {
            transaction.update(
              _firestore.collection(_usersCollection).doc(hostId),
              {currencyField: FieldValue.increment(ownerEarnings)},
            );
          }

          final roomData = roomSnapshot.data() as Map<String, dynamic>?;

          // 3. Pay Moderators and Co-Owners (Staff)
          final Map<String, dynamic> admins =
              roomData?['admins'] as Map<String, dynamic>? ?? {};
          final Map<String, dynamic> coOwners =
              roomData?['coOwners'] as Map<String, dynamic>? ?? {};

          // Unique set to avoid double paying if someone is in both maps
          final Set<String> staffIds = {...admins.keys, ...coOwners.keys};
          for (final staffId in staffIds) {
            // Don't double pay owner or receiver if they are in these lists
            if (staffId == hostId || staffId == receiverId) continue;
            staffCount++;
            transaction.update(
              _firestore.collection(_usersCollection).doc(staffId),
              {currencyField: FieldValue.increment(staffEarnings)},
            );
          }
        }

        int platformFee =
            totalCost -
            receiverEarnings -
            ownerEarnings -
            (staffEarnings * staffCount);
        if (platformFee < 0) platformFee = 0; // Safeguard

        int roomWealthIncrement = (totalCost * 0.20).floor();
        transaction.update(roomRef, {
          'wealth': FieldValue.increment(roomWealthIncrement),
        });

        // --- Challenge Points Logic ---
        final challenge =
            (roomSnapshot.data() as Map<String, dynamic>?)?['challenge']
                as Map<String, dynamic>?;
        if (challenge != null && challenge['isActive'] == true) {
          final List<dynamic> seats = roomSnapshot.get('seats') ?? [];
          bool isReceiverOnSeat = seats.any(
            (s) => s != null && s['userId'] == receiverId,
          );
          if (isReceiverOnSeat) {
            transaction.update(roomRef, {
              'challenge.points.$receiverId': FieldValue.increment(totalCost),
            });
          }
        }

        // --- PK Match Points Logic ---
        final pkMatch =
            (roomSnapshot.data() as Map<String, dynamic>?)?['pkMatch']
                as Map<String, dynamic>?;
        if (pkMatch != null && pkMatch['isActive'] == true) {
          final List<dynamic> seats = roomSnapshot.get('seats') ?? [];
          int seatIndex = seats.indexWhere(
            (s) => s != null && s['userId'] == receiverId,
          );
          if (seatIndex != -1) {
            double pkPoints = 0;
            if (gift.currency == Currency.gold) {
              pkPoints = totalCost * (70 / 10000);
            } else if (gift.currency == Currency.meto) {
              pkPoints = totalCost * (60 / 1000);
            } else if (gift.currency == Currency.diamonds) {
              pkPoints = totalCost * (60 / 1000);
            }
            int finalPkPoints = pkPoints.round();
            if (finalPkPoints < 1 && totalCost > 0) finalPkPoints = 1; // Min 1 point if something was spent

            transaction.update(roomRef, {
              'pkMatch.points.$receiverId': FieldValue.increment(finalPkPoints),
            });

            // Track Supporters
            final String side = (seatIndex == 1 || seatIndex == 2)
                ? 'leftSupporters'
                : (seatIndex == 3 || seatIndex == 4 ? 'rightSupporters' : '');

            if (side.isNotEmpty) {
              final String pointsSide = (seatIndex == 1 || seatIndex == 2)
                  ? 'leftSupporterPoints'
                  : 'rightSupporterPoints';
              transaction.update(roomRef, {
                'pkMatch.$side.$senderId': finalSenderImage ?? '',
                'pkMatch.$pointsSide.$senderId': FieldValue.increment(finalPkPoints),
              });
            }
          }
        }

        // Global Announcement for Valuable Gifts
        // Updated Thresholds: 700 Meto or 900 Diamonds
        final bool isValuable =
            (gift.currency == Currency.meto && totalCost >= 700) ||
            (gift.currency == Currency.diamonds && totalCost >= 900);

        if (isValuable) {
          DocumentReference announcementRef = _firestore
              .collection('global_announcements')
              .doc();

          // Get receiver image safely
          Map<String, dynamic>? receiverData = receiverSnapshot.exists
              ? (receiverSnapshot.data() as Map<String, dynamic>?)
              : null;
          String? receiverImage =
              receiverData?['profileImage'] ?? receiverData?['photoURL'];

          transaction.set(announcementRef, {
            'senderId': senderId,
            'senderName': senderSnapshot.get('nickname') ?? senderName,
            'senderImage': finalSenderImage,
            'receiverName': receiverName,
            'receiverImage': receiverImage,
            'giftName': gift.name,
            'giftIcon': effectiveGiftIcon,
            'quantity': quantity,
            'roomId': roomId,
            'roomDisplayId': roomDisplayId,
            'timestamp': FieldValue.serverTimestamp(),
            'currency': gift.currency.name,
            if (gift.price >= 12000) 'lottieUrl': gift.lottieUrl,
          });
        }

        DocumentReference transactionRef = _firestore
            .collection(_transactionsCollection)
            .doc();
        transaction.set(transactionRef, {
          'senderId': senderId,
          'senderName': senderName,
          'receiverId': receiverId,
          'roomId': roomId,
          'giftId': gift.id,
          'giftName': gift.name,
          'giftIcon': effectiveGiftIcon,
          'quantity': quantity,
          'price': gift.price,
          'totalCost': totalCost,
          'receiverEarnings': receiverEarnings,
          'platformFee': platformFee,
          'currency': gift.currency.name,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Add Chat Message for Gift
        DocumentReference chatMessageRef = _firestore
            .collection('rooms')
            .doc(roomId)
            .collection('messages')
            .doc();

        final Map<String, dynamic> chatMessageData = {
          'type': 'gift',
          'senderId': senderId,
          'senderName': senderName,
          'photoURL': finalSenderImage,
          'receiverId': receiverId,
          'receiverName': receiverName,
          'giftName': gift.name,
          'giftIcon': effectiveGiftIcon,
          'giftImage': gift.image,
          'lottieUrl': gift.lottieUrl,
          'price': gift.price,
          'quantity': quantity,
          'timestamp': FieldValue.serverTimestamp(),
        };

        transaction.set(chatMessageRef, chatMessageData);

        return {'success': true, 'chatMessageData': chatMessageData};
      });

      if (syncResult['success'] == false) {
        throw syncResult['error'];
      }

      final returnedChatMessageData = syncResult['chatMessageData'] as Map<String, dynamic>;

      // 4. Send Notification (Outside transaction for stability)
      NotificationService().sendNotification(
        NotificationModel(
          id: '',
          receiverId: receiverId,
          senderId: senderId,
          senderName: senderName,
          senderProfileImage: returnedChatMessageData['photoURL'],
          type: NotificationType.gift,
          text: quantity > 1
              ? 'أرسل لك هدية ${gift.name} x$quantity في الغرفة'
              : 'أرسل لك هدية ${gift.name} في الغرفة',
          createdAt: DateTime.now(),
        ),
      );

      // Synchronize REALTIME DATABASE so the chat updates instantly!
      final rtdbData = Map<String, dynamic>.from(returnedChatMessageData);
      rtdbData['timestamp'] = ServerValue.timestamp;
      await FirebaseDatabase.instance
          .ref('rooms/$roomId/messages')
          .push()
          .set(rtdbData);
    } catch (e) {
      throw e.toString();
    }
  }

  /// إرسال هدية إلى جميع المتواجدين على المقاعد
  Future<void> sendRoomGiftToAll({
    required String senderId,
    required List<String> occupiedUserIds,
    required String roomId,
    required Gift gift,
    required String senderName,
    String? senderProfileImage,
    int quantityPerUser = 1,
  }) async {
    if (occupiedUserIds.isEmpty) return;

    try {
      final int count = occupiedUserIds.length;
      final int totalQuantity = quantityPerUser * count;
      final int totalCost = gift.price * totalQuantity;

      final syncResult = await _firestore.runTransaction<Map<String, dynamic>>((transaction) async {
        // 1. Reads
        DocumentReference senderRef = _firestore
            .collection(_usersCollection)
            .doc(senderId);
        DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);

        DocumentSnapshot senderSnapshot = await transaction.get(senderRef);
        DocumentSnapshot roomSnapshot = await transaction.get(roomRef);

        if (!senderSnapshot.exists) return {'success': false, 'error': 'المستخدم غير موجود'};
        if (!roomSnapshot.exists) return {'success': false, 'error': 'الغرفة غير موجودة'};

        // Use the currency dictated by the gift
        final String currencyField = gift.currency == Currency.diamonds
            ? 'diamonds'
            : (gift.currency == Currency.meto ? 'meto_chips' : 'coins');

        final String currencyNameAr = gift.currency == Currency.diamonds
            ? 'الماس'
            : (gift.currency == Currency.meto ? 'عملة ميتو' : 'ذهب');

        int currentBalance = senderSnapshot.get(currencyField) ?? 0;
        if (currentBalance < totalCost) {
          return {'success': false, 'error': 'رصيدك غير كافٍ من $currencyNameAr لإرسال الهدايا للجميع'};
        }

        // Get Host Info for Announcement
        String roomDisplayId = roomId;
        String? hostId = roomSnapshot.get('hostId');
        if (hostId != null) {
          DocumentSnapshot hostSnapshot = await transaction.get(
            _firestore.collection(_usersCollection).doc(hostId),
          );
          if (hostSnapshot.exists) {
            roomDisplayId = hostSnapshot.get('displayId') ?? hostId;
          }
        }

        // --- Room Level & Daily User Cap Logic ---
        double xpToAdd = RoomLevelSystem.calculateXP(gold: totalCost);
        await RoomLevelSystem.awardPointsToRoom(
          pointsToAward: xpToAdd,
          roomId: roomId,
          userId: senderId,
          activeTransaction: transaction,
        );

        // 2. Writes
        transaction.update(senderRef, {
          currencyField: FieldValue.increment(-totalCost),
        });

        int roomWealthIncrement = (totalCost * 0.20).floor();
        transaction.update(roomRef, {
          'wealth': FieldValue.increment(roomWealthIncrement),
        });

        String? finalSenderImage =
            senderProfileImage ??
            (senderSnapshot.data() as Map<String, dynamic>?)?['profileImage'];

        // --- Challenge Points Logic (Group) ---
        final challenge =
            (roomSnapshot.data() as Map<String, dynamic>?)?['challenge']
                as Map<String, dynamic>?;
        if (challenge != null && challenge['isActive'] == true) {
          final List<dynamic> seats = roomSnapshot.get('seats') ?? [];
          for (String receiverId in occupiedUserIds) {
            bool isReceiverOnSeat = seats.any(
              (s) => s != null && s['userId'] == receiverId,
            );
            if (isReceiverOnSeat) {
              int individualCost = gift.price * quantityPerUser;
              transaction.update(roomRef, {
                'challenge.points.$receiverId': FieldValue.increment(
                  individualCost,
                ),
              });
            }
          }
        }

        // --- PK Match Points Logic (Group) ---
        final pkMatch =
            (roomSnapshot.data() as Map<String, dynamic>?)?['pkMatch']
                as Map<String, dynamic>?;
        if (pkMatch != null && pkMatch['isActive'] == true) {
          final List<dynamic> seats = roomSnapshot.get('seats') ?? [];
          for (String receiverId in occupiedUserIds) {
            int seatIndex = seats.indexWhere(
              (s) => s != null && s['userId'] == receiverId,
            );
            if (seatIndex != -1) {
              int individualCost = gift.price * quantityPerUser;
              double pkPoints = 0;
              if (gift.currency == Currency.gold) {
                pkPoints = individualCost * (70 / 10000);
              } else if (gift.currency == Currency.meto) {
                pkPoints = individualCost * (60 / 1000);
              } else if (gift.currency == Currency.diamonds) {
                pkPoints = individualCost * (60 / 1000);
              }
              int finalPkPoints = pkPoints.round();
              if (finalPkPoints < 1 && individualCost > 0) finalPkPoints = 1;

              transaction.update(roomRef, {
                'pkMatch.points.$receiverId': FieldValue.increment(finalPkPoints),
              });

              // Track Supporters (Group)
              final String side = (seatIndex == 1 || seatIndex == 2)
                  ? 'leftSupporters'
                  : (seatIndex == 3 || seatIndex == 4 ? 'rightSupporters' : '');

              if (side.isNotEmpty) {
                final String pointsSide = (seatIndex == 1 || seatIndex == 2)
                    ? 'leftSupporterPoints'
                    : 'rightSupporterPoints';
                transaction.update(roomRef, {
                  'pkMatch.$side.$senderId': finalSenderImage ?? '',
                  'pkMatch.$pointsSide.$senderId': FieldValue.increment(finalPkPoints),
                });
              }
            }
          }
        }

        // Announcement
        // Updated Thresholds: 700 Meto or 900 Diamonds
        final bool isValuable =
            (gift.currency == Currency.meto && totalCost >= 700) ||
            (gift.currency == Currency.diamonds && totalCost >= 900);

        if (isValuable) {
          transaction.set(_firestore.collection('global_announcements').doc(), {
            'senderId': senderId,
            'senderName': senderSnapshot.get('nickname') ?? senderName,
            'senderImage': finalSenderImage,
            'receiverName': 'الجميع ($count)',
            'giftName': gift.name,
            'giftIcon': gift.icon,
            'quantity': totalQuantity,
            'roomId': roomId,
            'roomDisplayId': roomDisplayId,
            'timestamp': FieldValue.serverTimestamp(),
            'currency': gift.currency.name,
            if (gift.price >= 12000) 'lottieUrl': gift.lottieUrl,
          });
        }

        // Chat Message
        final Map<String, dynamic> chatMessageData = {
          'type': 'gift',
          'senderId': senderId,
          'senderName': senderName,
          'photoURL': finalSenderImage,
          'receiverId': 'all',
          'receiverName': 'الجميع ($count)',
          'giftName': gift.name,
          'giftIcon': gift.icon,
          'giftImage': gift.image,
          'lottieUrl': gift.lottieUrl,
          'price': gift.price,
          'quantity': totalQuantity,
          'timestamp': FieldValue.serverTimestamp(),
        };

        transaction.set(
          _firestore
              .collection('rooms')
              .doc(roomId)
              .collection('messages')
              .doc(),
          chatMessageData,
        );

        // Loop for individual updates
        for (String receiverId in occupiedUserIds) {
          int individualCost = gift.price * quantityPerUser;

          // --- Revised Sharing Logic per Receiver ---
          int receiverEarnings = 0;
          int ownerEarnings = 0;
          int staffEarnings = 0;

          if (gift.currency == Currency.diamonds ||
              gift.currency == Currency.meto) {
            receiverEarnings = (individualCost * 0.20).floor();
            ownerEarnings = (individualCost * 0.15).floor();
            staffEarnings = (individualCost * 0.02).floor();

            // 1. Pay Receiver
            transaction.update(
              _firestore.collection(_usersCollection).doc(receiverId),
              {currencyField: FieldValue.increment(receiverEarnings)},
            );

            // 2. Pay Owner
            if (hostId != null) {
              transaction.update(
                _firestore.collection(_usersCollection).doc(hostId),
                {currencyField: FieldValue.increment(ownerEarnings)},
              );
            }

            // 3. Pay Staff
            final roomData = roomSnapshot.data() as Map<String, dynamic>?;
            final Map<String, dynamic> admins =
                roomData?['admins'] as Map<String, dynamic>? ?? {};
            final Map<String, dynamic> coOwners =
                roomData?['coOwners'] as Map<String, dynamic>? ?? {};
            final Set<String> staffIds = {...admins.keys, ...coOwners.keys};
            for (final staffId in staffIds) {
              if (staffId == hostId || staffId == receiverId) continue;
              transaction.update(
                _firestore.collection(_usersCollection).doc(staffId),
                {currencyField: FieldValue.increment(staffEarnings)},
              );
            }
          }

          transaction
              .set(_firestore.collection(_transactionsCollection).doc(), {
                'senderId': senderId,
                'senderName': senderName,
                'receiverId': receiverId,
                'roomId': roomId,
                'giftId': gift.id,
                'giftName': gift.name,
                'giftIcon': gift.icon,
                'quantity': quantityPerUser,
                'price': gift.price,
                'totalCost': individualCost,
                'currency': gift.currency.name,
                'timestamp': FieldValue.serverTimestamp(),
              });
        } // End of loop

        return {
          'success': true,
          'chatMessageData': chatMessageData,
          'finalSenderImage': finalSenderImage,
        };
      });

      if (syncResult['success'] == false) {
        throw syncResult['error'];
      }

      final Map<String, dynamic> result = syncResult;
      final returnedChatMessageData =
          result['chatMessageData'] as Map<String, dynamic>;
      final finalSenderImage = result['finalSenderImage'] as String?;

      // Send individual notifications outside transaction
      for (String receiverId in occupiedUserIds) {
        NotificationService().sendNotification(
          NotificationModel(
            id: '',
            receiverId: receiverId,
            senderId: senderId,
            senderName: senderName,
            senderProfileImage: finalSenderImage,
            type: NotificationType.gift,
            text: quantityPerUser > 1
                ? 'أرسل لك هدية ${gift.name} x$quantityPerUser في الغرفة'
                : 'أرسل لك هدية ${gift.name} في الغرفة',
            createdAt: DateTime.now(),
          ),
        );
      }

      // Synchronize REALTIME DATABASE so the chat updates instantly!
      final rtdbData = Map<String, dynamic>.from(returnedChatMessageData);
      rtdbData['timestamp'] = ServerValue.timestamp;
      await FirebaseDatabase.instance
          .ref('rooms/$roomId/messages')
          .push()
          .set(rtdbData);
    } catch (e) {
      throw e.toString();
    }
  }

  /// إرسال هدية من مستخدم لآخر (في المنشورات)
  Future<void> sendGift({
    required String senderId,
    required String receiverId,
    required String postId,
    required Gift gift,
    required String senderName,
    String? senderProfileImage,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. جلب بيانات المرسل بالتأكد من الرصيد (الماس)
        DocumentReference senderRef = _firestore
            .collection(_usersCollection)
            .doc(senderId);
        DocumentSnapshot senderSnapshot = await transaction.get(senderRef);

        if (!senderSnapshot.exists) throw 'المستخدم غير موجود';

        String currencyField;
        String currencyNameAr;

        if (gift.currency == Currency.diamonds) {
          currencyField = 'diamonds';
          currencyNameAr = 'الألماس';
        } else if (gift.currency == Currency.meto) {
          currencyField = 'meto_chips';
          currencyNameAr = 'ميتو';
        } else {
          currencyField = 'coins'; // Gold
          currencyNameAr = 'الذهب';
        }

        int currentBalance = senderSnapshot.get(currencyField) ?? 0;

        if (currentBalance < gift.price) {
          throw 'رصيدك من $currencyNameAr غير كافٍ لإرسال هذه الهدية';
        }

        // 2. تحديث الأرصدة للأطراف المعنية
        // خصم الرصيد من المرسل
        transaction.update(senderRef, {
          currencyField: FieldValue.increment(-gift.price),
        });

        // إضافة الرصيد للمستلم
        // حسب الطلب: الذهب (0%)، الماس وميتو (20%)
        int receiverEarnings = 0;
        if (gift.currency == Currency.diamonds ||
            gift.currency == Currency.meto) {
          receiverEarnings = (gift.price * 0.2).floor();
        }

        int platformFee = gift.price - receiverEarnings;

        DocumentReference receiverRef = _firestore
            .collection(_usersCollection)
            .doc(receiverId);

        if (receiverId != senderId && receiverEarnings > 0) {
          transaction.update(receiverRef, {
            currencyField: FieldValue.increment(receiverEarnings),
          });
        }

        // 3. تحديث عدد هدايا المنشور
        DocumentReference postRef = _firestore.collection('posts').doc(postId);
        transaction.update(postRef, {'giftsCount': FieldValue.increment(1)});

        // 4. تسجيل العملية في جدول العمليات
        DocumentReference transactionRef = _firestore
            .collection(_transactionsCollection)
            .doc();
        transaction.set(transactionRef, {
          'senderId': senderId,
          'senderName': senderName,
          'senderProfileImage': senderProfileImage, // New field
          'receiverId': receiverId,
          'postId': postId,
          'giftId': gift.id,
          'giftName': gift.name,
          'giftIcon': gift.icon,
          'lottieUrl': gift.lottieUrl,
          'price': gift.price,
          'receiverEarnings': receiverEarnings,
          'platformFee': platformFee,
          'currency': gift.currency.name,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 5. إرسال إشعار للمستلم
        NotificationService().sendNotification(
          NotificationModel(
            id: '',
            receiverId: receiverId,
            senderId: senderId,
            senderName: senderName,
            senderProfileImage: senderProfileImage,
            type: NotificationType.gift,
            postId: postId,
            text: 'أرسل لك هدية ${gift.name}',
            createdAt: DateTime.now(),
          ),
        );
      });
    } catch (e) {
      throw e.toString();
    }
  }

  /// الحصول على رصيد العملات (النقاط)
  Future<int> getUserCoins(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) {
        return doc.get('coins') ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// الحصول على رصيد الماس للمستخدم
  Future<int> getUserDiamonds(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) {
        return doc.get('diamonds') ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// الحصول على رصيد ميتو
  Future<int> getUserMeto(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data == null) return 0;
        // ميتو يقرأ حصراً من meto_chips لضمان الفصل التام عن الذهب
        return (data['meto_chips'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// الحصول على رصيد الذهب
  Future<int> getUserGold(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data == null) return 0;
        // الذهب يقرأ من حقل coins لضمان التوافق مع النظام القديم (العملات الصفراء)
        return (data['coins'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// شحن الماس بطريقة آمنة مع نظام تتبع العمليات
  Future<void> rechargeDiamonds(String uid, int amount, {String? price}) async {
    try {
      final transactionId = 'RECH-${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.runTransaction((transaction) async {
        DocumentReference userRef = _firestore
            .collection(_usersCollection)
            .doc(uid);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) throw 'المستخدم غير موجود';

        // 1. تحديث رصيد الماس للمستخدم بشكل ذري (Atomic)
        transaction.update(userRef, {
          'diamonds': FieldValue.increment(amount),
          'lastRechargeDate': FieldValue.serverTimestamp(),
          'totalRechargedDiamonds': FieldValue.increment(amount),
        });

        // 2. تسجيل الفاتورة في قاعدة البيانات للتدقيق (Audit Log)
        DocumentReference logRef = _firestore
            .collection('diamond_recharges')
            .doc();
        transaction.set(logRef, {
          'userId': uid,
          'transactionId': transactionId,
          'amount': amount,
          'price': price ?? 'N/A',
          'status': 'verified',
          'type': 'in_app_purchase_simulation',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw 'حدث خطأ أثناء معالجة عملية الشحن: $e';
    }
  }

  /// الحصول على قائمة الهدايا المستلمة لمنشور معين
  Future<List<Map<String, dynamic>>> getPostGifts(String postId) async {
    try {
      final snapshot = await _firestore
          .collection(_transactionsCollection)
          .where('postId', isEqualTo: postId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> requestWithdrawal({
    required String uid,
    required int metoChips,
    required String paymentDetails,
    required String userName,
    String? masterNumber,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference userRef = _firestore
            .collection(_usersCollection)
            .doc(uid);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) throw 'المستخدم غير موجود';
        int currentMeto = userSnapshot.get('meto_chips') ?? 0;

        if (currentMeto < metoChips) {
          throw 'رصيدك من عملة ميتو غير كافٍ لسحب هذا المبلغ';
        }

        // 1. خصم الرصيد
        transaction.update(userRef, {
          'meto_chips': FieldValue.increment(-metoChips),
        });

        // 2. تسجيل الطلب
        DocumentReference requestRef = _firestore
            .collection('withdrawal_requests')
            .doc();
        transaction.set(requestRef, {
          'userId': uid,
          'userName': userName,
          'metoChips': metoChips,
          'amountUsd': metoChips / 6000.0,
          'paymentDetails': paymentDetails,
          'masterNumber': masterNumber ?? '',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> transferCoins({
    required String senderId,
    required String receiverAppId,
    required int amount,
  }) async {
    try {
      if (amount <= 0) throw 'صيغة المبلغ غير صحيحة';

      // First try finding user by displayId (since users usually share displayId)
      QuerySnapshot query = await _firestore
          .collection(_usersCollection)
          .where('displayId', isEqualTo: receiverAppId)
          .limit(1)
          .get();

      String receiverId;
      DocumentReference receiverRef;

      if (query.docs.isNotEmpty) {
        receiverRef = query.docs.first.reference;
        receiverId = receiverRef.id;
      } else {
        receiverRef = _firestore
            .collection(_usersCollection)
            .doc(receiverAppId);
        receiverId = receiverRef.id;
      }

      if (senderId == receiverId) throw 'لا يمكنك التحويل لنفسك';

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot receiverSnapshot = await transaction.get(receiverRef);
        if (!receiverSnapshot.exists) throw 'حساب المستلم غير موجود';

        DocumentReference senderRef = _firestore
            .collection(_usersCollection)
            .doc(senderId);
        DocumentSnapshot senderSnapshot = await transaction.get(senderRef);

        if (!senderSnapshot.exists) throw 'حسابك غير موجود';

        bool isAgent = false;
        try {
          isAgent = senderSnapshot.get('isAgent') ?? false;
        } catch (_) {}
        if (!isAgent) throw 'ميزة التحويل متاحة فقط للوكلاء المعتمدين';

        int currentCoins = 0;
        try {
          currentCoins = senderSnapshot.get('coins') ?? 0;
        } catch (_) {}
        if (currentCoins < amount) throw 'رصيدك غير كافٍ للتحويل';

        transaction.update(senderRef, {'coins': FieldValue.increment(-amount)});
        transaction.update(receiverRef, {
          'coins': FieldValue.increment(amount),
        });

        String senderName = '';
        String receiverName = '';
        String senderDisplayId = '';
        String receiverDisplayId = '';

        final senderData = senderSnapshot.data() as Map<String, dynamic>?;
        final receiverData = receiverSnapshot.data() as Map<String, dynamic>?;

        senderName =
            senderData?['nickname'] ??
            senderData?['name'] ??
            senderData?['username'] ??
            '';
        receiverName =
            receiverData?['nickname'] ??
            receiverData?['name'] ??
            receiverData?['username'] ??
            '';
        senderDisplayId = senderData?['displayId'] ?? senderId;
        receiverDisplayId = receiverData?['displayId'] ?? receiverId;

        // سجل للمرسل
        transaction.set(_firestore.collection('coin_transfers').doc(), {
          'userId': senderId,
          'otherUserId': receiverId,
          'otherUserName': receiverName,
          'otherUserDisplayId': receiverDisplayId,
          'senderId': senderId,
          'senderName': senderName,
          'senderDisplayId': senderDisplayId,
          'receiverId': receiverId,
          'receiverName': receiverName,
          'receiverDisplayId': receiverDisplayId,
          'amount': amount,
          'type': 'sent',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // سجل للمستلم
        transaction.set(_firestore.collection('coin_transfers').doc(), {
          'userId': receiverId,
          'otherUserId': senderId,
          'otherUserName': senderName,
          'otherUserDisplayId': senderDisplayId,
          'senderId': senderId,
          'senderName': senderName,
          'senderDisplayId': senderDisplayId,
          'receiverId': receiverId,
          'receiverName': receiverName,
          'receiverDisplayId': receiverDisplayId,
          'amount': amount,
          'type': 'received',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> transferMetoChips({
    required String senderId,
    required String receiverAppId,
    required int amount,
  }) async {
    try {
      if (amount <= 0) throw 'صيغة المبلغ غير صحيحة';

      QuerySnapshot query = await _firestore
          .collection(_usersCollection)
          .where('displayId', isEqualTo: receiverAppId)
          .limit(1)
          .get();

      String receiverId;
      DocumentReference receiverRef;

      if (query.docs.isNotEmpty) {
        receiverRef = query.docs.first.reference;
        receiverId = receiverRef.id;
      } else {
        receiverRef = _firestore
            .collection(_usersCollection)
            .doc(receiverAppId);
        receiverId = receiverRef.id;
      }

      if (senderId == receiverId) throw 'لا يمكنك التحويل لنفسك';

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot receiverSnapshot = await transaction.get(receiverRef);
        if (!receiverSnapshot.exists) throw 'حساب المستلم غير موجود';

        DocumentReference senderRef = _firestore
            .collection(_usersCollection)
            .doc(senderId);
        DocumentSnapshot senderSnapshot = await transaction.get(senderRef);

        if (!senderSnapshot.exists) throw 'حسابك غير موجود';

        bool isAgent = false;
        try {
          isAgent = senderSnapshot.get('isAgent') ?? false;
        } catch (_) {}
        if (!isAgent) throw 'تحويل ميتو متاح فقط للوكلاء المعتمدين';

        int currentMeto = 0;
        try {
          currentMeto = senderSnapshot.get('meto_chips') ?? 0;
        } catch (_) {}
        if (currentMeto < amount) throw 'رصيد ميتو غير كافٍ للتحويل';

        transaction.update(senderRef, {
          'meto_chips': FieldValue.increment(-amount),
        });
        transaction.update(receiverRef, {
          'meto_chips': FieldValue.increment(amount),
        });

        final senderData = senderSnapshot.data() as Map<String, dynamic>?;
        final receiverData = receiverSnapshot.data() as Map<String, dynamic>?;

        String senderName =
            senderData?['nickname'] ??
            senderData?['name'] ??
            senderData?['username'] ??
            '';
        String receiverName =
            receiverData?['nickname'] ??
            receiverData?['name'] ??
            receiverData?['username'] ??
            '';
        String senderDisplayId = senderData?['displayId'] ?? senderId;
        String receiverDisplayId = receiverData?['displayId'] ?? receiverId;

        // سجل التحويل
        DocumentReference logRef = _firestore
            .collection('meto_transfers')
            .doc();
        transaction.set(logRef, {
          'senderId': senderId,
          'senderName': senderName,
          'senderDisplayId': senderDisplayId,
          'receiverId': receiverId,
          'receiverName': receiverName,
          'receiverDisplayId': receiverDisplayId,
          'amount': amount,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw e.toString();
    }
  }
}
