import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/index.dart';

class ShopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _shopCollection = 'shop_items';
  final String _inventoryCollection = 'user_inventory';
  final String _usersCollection = 'users';

  static final Map<String, int> _hardcodedPacksPrices = {
    'pack_emoji_premium': 1500,
    'pack_funny_cats': 800,
    'pack_love_vibe': 1200,
    'pack_party_time': 1000,
    'pack_funny_express': 900,
    'pack_dance_party': 1100,
    'pack_drama_sad': 850,
    'pack_cool_vibes': 1300,
  };

  /// جلب عناصر المتجر حسب النوع
  Stream<List<ShopItem>> getShopItems(ShopItemType type) {
    Stream<List<ShopItem>> shopStream = _firestore
        .collection(_shopCollection)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ShopItem.fromMap(doc.data(), doc.id))
              .where((item) => item.type == type)
              .toList();
        });

    // If type is FRAME, also fetch from 'etar_Profile' and merge
    if (type == ShopItemType.frame) {
      Stream<List<ShopItem>> profileFramesStream = _firestore
          .collection('etar_Profile')
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              // Map etar_Profile data to ShopItem
              return ShopItem(
                id: doc.id,
                name: data['name'] ?? '',
                imageUrl: data['image'] ?? data['lottieUrl'] ?? '',
                price: int.tryParse(data['price']?.toString() ?? '0') ?? 0,
                type: ShopItemType.frame,
                metadata: {'lottieUrl': data['lottieUrl']},
              );
            }).toList();
          });

      // Manual merge without Rx
      StreamController<List<ShopItem>> controller =
          StreamController<List<ShopItem>>.broadcast();
      List<ShopItem> list1 = [];
      List<ShopItem> list2 = [];
      bool hasList1 = false;
      bool hasList2 = false;

      void emit() {
        if (controller.isClosed) return;
        // Deduplicate logic
        final Map<String, ShopItem> uniqueItems = {};
        if (hasList1) {
          for (var item in list1) {
            uniqueItems[item.id] = item;
          }
        }
        if (hasList2) {
          for (var item in list2) {
            // Keep shop_item if exists, else add profile frame
            if (!uniqueItems.containsKey(item.id)) {
              uniqueItems[item.id] = item;
            }
          }
        }
        controller.add(uniqueItems.values.toList());
      }

      StreamSubscription? sub1;
      StreamSubscription? sub2;

      controller.onListen = () {
        sub1 = shopStream.listen((data) {
          list1 = data;
          hasList1 = true;
          emit();
        });
        sub2 = profileFramesStream.listen((data) {
          list2 = data;
          hasList2 = true;
          emit();
        });
      };

      controller.onCancel = () {
        sub1?.cancel();
        sub2?.cancel();
      };

      return controller.stream;
    }

    // New: Fetch from ludo_assets as well
    Stream<List<ShopItem>> ludoAssetsStream = _firestore
        .collection('ludo_assets')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                ShopItemType itemType = ShopItemType.ludoBoard;
                final category = data['category']?.toString();
                if (category == 'hall') itemType = ShopItemType.ludoHall;
                if (category == 'dice') itemType = ShopItemType.ludoDice;
                if (category == 'piece') itemType = ShopItemType.ludoPiece;

                return ShopItem(
                  id: doc.id,
                  name: data['name'] ?? '',
                  imageUrl: data['image'] ?? '',
                  price: int.tryParse(data['price']?.toString() ?? '0') ?? 0,
                  type: itemType,
                  currency: data['currency'] == 'meto'
                      ? Currency.meto
                      : Currency.diamonds,
                );
              })
              .where((item) => item.type == type)
              .toList();
        });

    // Merge shopStream and ludoAssetsStream
    StreamController<List<ShopItem>> controller =
        StreamController<List<ShopItem>>.broadcast();
    List<ShopItem> list1 = [];
    List<ShopItem> list2 = [];
    bool hasList1 = false;
    bool hasList2 = false;

    void emit() {
      if (controller.isClosed) return;
      final Map<String, ShopItem> uniqueItems = {};
      if (hasList1) for (var item in list1) uniqueItems[item.id] = item;
      if (hasList2) for (var item in list2) uniqueItems[item.id] = item;
      controller.add(uniqueItems.values.toList());
    }

    StreamSubscription? sub1;
    StreamSubscription? sub2;

    controller.onListen = () {
      sub1 = shopStream.listen((data) {
        list1 = data;
        hasList1 = true;
        emit();
      });
      sub2 = ludoAssetsStream.listen((data) {
        list2 = data;
        hasList2 = true;
        emit();
      });
    };

    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
    };

    return controller.stream;
  }

  /// جلب تيار من الخلفيات التي يمتلكها المستخدم
  Stream<List<RoomBackground>> getOwnedBackgroundsStream(String userId) {
    return _firestore
        .collection(_inventoryCollection)
        .where('userId', isEqualTo: userId)
        .where('itemType', isEqualTo: 0) // 0 is backgrounds
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return RoomBackground(
              id: data['itemId']?.toString() ?? '',
              name: data['itemName']?.toString() ?? '',
              image:
                  data['imageUrl']?.toString() ??
                  '', // نستخدم الرابط المخزن في الجرد
              price: 0, // أصبحت مملوكة فلا يهم السعر
            );
          }).toList();
        });
  }

  /// جلب تيار من معرفات العناصر التي يمتلكها المستخدم حسب النوع
  Stream<Set<String>> getOwnedItemIdsByTypeStream(
    String userId,
    ShopItemType type,
  ) {
    return _firestore
        .collection(_inventoryCollection)
        .where('userId', isEqualTo: userId)
        .where('itemType', isEqualTo: type.index)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => doc.data()['itemId']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
        });
  }

  /// جلب تيار من معرفات العناصر التي يمتلكها المستخدم
  Stream<Set<String>> getOwnedItemIdsStream(String userId) {
    return _firestore
        .collection(_inventoryCollection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => doc.data()['itemId']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
        });
  }

  /// عملية شراء عنصر من المتجر
  Future<String?> purchaseShopItem(String userId, ShopItem item) async {
    try {
      return await _firestore.runTransaction<String?>((transaction) async {
      // 1. Fetch source of truth (Hardcoded Registry or DB)
      ShopItem verifiedItem;

      final String packId = item.id.trim();
      final int? hardcodedPrice = _hardcodedPacksPrices[packId];

      if (hardcodedPrice != null) {
        // Option A: It's a validated hardcoded pack
        verifiedItem = ShopItem(
          id: packId,
          name: item.name,
          imageUrl: item.imageUrl,
          price: hardcodedPrice,
          type: item.type,
          currency: Currency.diamonds, // Hardcoded for stickers for now
          metadata: item.metadata,
        );
      } else {
        // Option B: It's a regular item from Firestore
        DocumentSnapshot? itemDoc;

        // Try shop_items first
        itemDoc = await transaction.get(
          _firestore.collection(_shopCollection).doc(item.id),
        );

        if (!itemDoc.exists) {
          // Try etar_Profile if it's a frame
          if (item.type == ShopItemType.frame) {
            itemDoc = await transaction.get(
              _firestore.collection('etar_Profile').doc(item.id),
            );
          }
        }

        if (!itemDoc.exists) {
          // Try ludo_assets
          itemDoc = await transaction.get(
            _firestore.collection('ludo_assets').doc(item.id),
          );
        }

        if (!itemDoc.exists)
          return 'العنصر (${item.id}) غير متوفر في المتجر حالياً';

        verifiedItem = ShopItem.fromMap(
          itemDoc.data() as Map<String, dynamic>,
          itemDoc.id,
        );
      }

      DocumentReference userRef = _firestore
          .collection(_usersCollection)
          .doc(userId);
      DocumentSnapshot userSnapshot = await transaction.get(userRef);

      if (!userSnapshot.exists) return 'المستخدم غير موجود';

      // 0. التحقق مما إذا كان العنصر مملوكاً بالفعل
      DocumentReference inventoryRef = _firestore
          .collection(_inventoryCollection)
          .doc('${userId}_${verifiedItem.id}');
      DocumentSnapshot inventorySnapshot = await transaction.get(inventoryRef);
      if (inventorySnapshot.exists) {
        return 'أنت تمتلك هذا العنصر بالفعل';
      }

      int currentDiamonds = userSnapshot.get('diamonds') ?? 0;
      int currentMeto =
          userSnapshot.get('meto_chips') ?? userSnapshot.get('coins') ?? 0;

      if (verifiedItem.currency == Currency.meto) {
        if (currentMeto < verifiedItem.price) {
          return 'رصيدك من عملة ميتو غير كافٍ شحن رصيد ميتو من متجر ميتو بالاعلى';
        }
        transaction.update(userRef, {
          'meto_chips': FieldValue.increment(-verifiedItem.price),
        });
      } else {
        if (currentDiamonds < verifiedItem.price) {
          return 'رصيدك من الماس غير كافٍ اشحن رصيد الماس من متجر ميتو بالاعلى';
        }
        transaction.update(userRef, {
          'diamonds': FieldValue.increment(-verifiedItem.price),
        });
      }

      // 2. إضافة إلى حقيبة المستخدم (Inventory)
      transaction.set(inventoryRef, {
        'userId': userId,
        'itemId': item.id,
        'itemName': item.name,
        'itemType': item.type.index,
        'imageUrl': item.imageUrl, // تخزين الرابط للوصول السريع
        'purchasedAt': FieldValue.serverTimestamp(),
      });

      // 3. تحديثات خاصة حسب نوع العنصر
      if (item.type == ShopItemType.verification) {
        String? tier = item.metadata?['tier'];
        // Fallback if metadata is missing
        if (tier == null) {
          if (item.name.contains('أزرق')) {
            tier = 'blue';
          } else if (item.name.contains('ذهبي'))
            tier = 'gold';
          else if (item.name.contains('VIP'))
            tier = 'vip';
        }

        transaction.update(userRef, {
          'isVerified': true,
          'verificationTier': tier,
          'verificationIcon': item.imageUrl,
        });
      } else if (item.type == ShopItemType.specialId) {
        String? newId = item.metadata?['specialId']?.toString();
        if (newId != null && newId.isNotEmpty) {
          // Auto-equip: Set as main displayId and save the image
          transaction.update(userRef, {
            'displayId': newId,
            'referralCode': newId,
            'displayIdImage': item.imageUrl, // Save the image URL
            'ownedSpecialIds': FieldValue.arrayUnion([newId]),
            'ownedSpecialIdImages': FieldValue.arrayUnion([item.imageUrl]),
          });
        }
      } else if (item.type == ShopItemType.frame) {
        transaction.update(userRef, {
          'ownedFrames': FieldValue.arrayUnion([item.imageUrl]),
        });
      } else if (item.type == ShopItemType.decoration) {
        transaction.update(userRef, {
          'ownedDecorations': FieldValue.arrayUnion([item.imageUrl]),
          'profileDecoration': item.imageUrl, // Auto-equip decoration
        });
      } else if (item.type == ShopItemType.wallHanging) {
        transaction.update(userRef, {
          'ownedWallHangings': FieldValue.arrayUnion([item.imageUrl]),
          'activeWallHanging': item.imageUrl, // Auto-equip
        });
      } else if (item.type == ShopItemType.cardBorder) {
        transaction.update(userRef, {
          'ownedCardBorders': FieldValue.arrayUnion([item.imageUrl]),
          'profileCardBorder': item.imageUrl, // Auto-equip
        });
      } else if (item.type == ShopItemType.roomCardBorder) {
        transaction.update(userRef, {
          'ownedRoomCardBorders': FieldValue.arrayUnion([item.imageUrl]),
          'activeRoomCardBorder': item.imageUrl, // Auto-equip
        });
      } else if (item.type == ShopItemType.entrance) {
        transaction.update(userRef, {
          'roomEntrance': item.imageUrl, // Auto-equip entrance
        });
      } else if (item.type == ShopItemType.ludoPiece) {
        // No longer auto-equipping on purchase to allow user choice
      } else if (item.type == ShopItemType.ludoBoard) {
        // No longer auto-equipping on purchase to allow user choice
      } else if (item.type == ShopItemType.ludoDice) {
        // No longer auto-equipping on purchase to allow user choice
      }

      return null; // Success
      });
    } catch (e) {
      return e.toString();
    }
  }

  /// الحصول على كافة الخلفيات المتوفرة في المتجر (للعرض في الغرفة)
  Stream<List<RoomBackground>> getAllShopBackgroundsStream() {
    return _firestore
        .collection(_shopCollection)
        // لا نستخدم فلترة هنا لضمان جلب كل العناصر بغض النظر عن نوع بيانات الحقل 'type'
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                // فلترة العناصر من نوع خلفية فقط (0)
                final typeStr = data['type']?.toString() ?? '0';
                if (typeStr != '0') return null;

                return RoomBackground(
                  id: doc.id,
                  name: data['name']?.toString() ?? '',
                  image:
                      data['imageUrl']?.toString() ??
                      data['image']?.toString() ??
                      '',
                  price: int.tryParse(data['price']?.toString() ?? '0') ?? 0,
                );
              })
              .where((bg) => bg != null)
              .cast<RoomBackground>()
              .toList();
        });
  }

  /// تجهيز عنصر (مثل زينة البروفايل أو التوثيق)
  Future<void> equipShopItem(String userId, ShopItem item) async {
    if (item.type == ShopItemType.decoration) {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'profileDecoration': item.imageUrl,
      });
    } else if (item.type == ShopItemType.verification) {
      String? tier = item.metadata?['tier'];
      // Fallback if metadata is missing
      if (tier == null) {
        if (item.name.contains('أزرق')) {
          tier = 'blue';
        } else if (item.name.contains('ذهبي')) {
          tier = 'gold';
        } else if (item.name.contains('VIP')) {
          tier = 'vip';
        }
      }

      await _firestore.collection(_usersCollection).doc(userId).update({
        'isVerified': true,
        'verificationTier': tier,
        'verificationIcon': item.imageUrl,
      });
    } else if (item.type == ShopItemType.entrance) {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'roomEntrance': item.imageUrl,
      });
    } else if (item.type == ShopItemType.ludoPiece) {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'ludoTokenTheme': item.id,
      });
    } else if (item.type == ShopItemType.ludoBoard) {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'ludoBoardTheme': item.id,
      });
    } else if (item.type == ShopItemType.ludoDice) {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'ludoDiceTheme': item.id,
      });
    } else if (item.type == ShopItemType.wallHanging) {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'activeWallHanging': item.imageUrl,
      });
    } else if (item.type == ShopItemType.cardBorder) {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'profileCardBorder': item.imageUrl,
      });
    } else if (item.type == ShopItemType.roomCardBorder) {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'activeRoomCardBorder': item.imageUrl,
      });
    } else if (item.type == ShopItemType.ludoHall) {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'ludoHallTheme': item.id,
      });
    }
  }
}
