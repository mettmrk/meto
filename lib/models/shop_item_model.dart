import 'package:cloud_firestore/cloud_firestore.dart';
import 'gift_model.dart';

enum ShopItemType {
  background,
  frame,
  specialId,
  verification,
  sticker,
  decoration,
  entrance,
  ludoPiece,
  ludoBoard,
  ludoDice,
  cardBorder,
  cardBackground,
  wallHanging,
  roomCardBorder,
  ludoHall,
}

class ShopItem {
  final String id;
  final String name;
  final String imageUrl;
  final int price;
  final ShopItemType type;
  final Currency currency;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  ShopItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.type,
    this.currency = Currency.diamonds,
    this.metadata,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'price': price,
      'type': type.index,
      'currency': currency.name,
      'metadata': metadata,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  factory ShopItem.fromMap(Map<String, dynamic> map, String docId) {
    int typeIndex = 0;
    if (map['category'] != null) {
      final category = map['category'].toString();
      if (category == 'hall') typeIndex = ShopItemType.ludoHall.index;
      else if (category == 'dice') typeIndex = ShopItemType.ludoDice.index;
      else if (category == 'piece') typeIndex = ShopItemType.ludoPiece.index;
      else if (category == 'board') typeIndex = ShopItemType.ludoBoard.index;
    } else {
      var rawType = map['type'];
      if (rawType is int) {
        typeIndex = rawType;
      } else if (rawType is String) {
        typeIndex = int.tryParse(rawType) ?? 0;
      }

      if (typeIndex < 0 || typeIndex >= ShopItemType.values.length) {
        typeIndex = 0;
      }
    }

    Currency currency = Currency.diamonds;
    final typeEnum = ShopItemType.values[typeIndex];

    // Force currency mapping based on user request:
    // Meto: Special ID, Verification, Entrance
    // Diamonds: Background, Frame, Sticker, Decoration
    if (typeEnum == ShopItemType.specialId ||
        typeEnum == ShopItemType.verification ||
        typeEnum == ShopItemType.entrance) {
      currency = Currency.meto;
    } else if (typeEnum == ShopItemType.background ||
        typeEnum == ShopItemType.frame ||
        typeEnum == ShopItemType.sticker ||
        typeEnum == ShopItemType.decoration) {
      currency = Currency.diamonds;
    } else {
      // Fallback to DB value if they exist for other types
      if (map['currency'] != null) {
        final currencyStr = map['currency'].toString();
        if (currencyStr == 'meto') {
          currency = Currency.meto;
        }
      }
    }

    String url = map['imageUrl']?.toString() ?? map['image']?.toString() ?? '';

    DateTime? createdAt;
    if (map['createdAt'] != null) {
      if (map['createdAt'] is Timestamp) {
        createdAt = (map['createdAt'] as Timestamp).toDate();
      } else if (map['createdAt'] is String) {
        createdAt = DateTime.tryParse(map['createdAt']);
      }
    }

    return ShopItem(
      id: docId,
      name: map['name']?.toString() ?? '',
      imageUrl: url,
      price: int.tryParse(map['price']?.toString() ?? '0') ?? 0,
      type: ShopItemType.values[typeIndex],
      currency: currency,
      metadata: map['metadata'] as Map<String, dynamic>?,
      createdAt: createdAt,
    );
  }
}
