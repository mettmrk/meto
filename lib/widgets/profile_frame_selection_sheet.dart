import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'framed_avatar.dart';
import '../models/index.dart';
import '../services/user_service.dart';
import '../services/shop_service.dart';

class ProfileFrameSelectionSheet extends StatefulWidget {
  final String? currentFrame;
  final String? profileImageUrl;

  const ProfileFrameSelectionSheet({
    super.key,
    this.currentFrame,
    this.profileImageUrl,
  });

  @override
  State<ProfileFrameSelectionSheet> createState() =>
      _ProfileFrameSelectionSheetState();
}

class _ProfileFrameSelectionSheetState extends State<ProfileFrameSelectionSheet>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final currentUid = auth.FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<User?>(
      stream: currentUid != null
          ? UserService().getUserStream(currentUid)
          : const Stream.empty(),
      initialData: currentUid != null
          ? UserService().getUserSync(currentUid)
          : null,
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;

        return Container(
          height: screenHeight * 0.5, // Reduced height as requested
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: DefaultTabController(
            length: 7,
            child: Column(
              children: [
                // Elegant Top Bar (Handle-style)
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title Section
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'متجر التزيين الحصري',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                // Tab Bar
                TabBar(
                  isScrollable: true,
                  indicatorColor: Colors.cyanAccent,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontFamily: 'Tajawal',
                  ),
                  tabs: const [
                    Tab(text: 'الإطارات'),
                    Tab(text: 'البطاقات'),
                    Tab(text: 'الدخوليات'),
                    Tab(text: 'المعلقات'),
                    Tab(text: 'الآيدي المميز'),
                    Tab(text: 'الحدود'),
                    Tab(text: 'إطار الغرفة'),
                  ],
                ),

                const Divider(color: Colors.white10, thickness: 1, height: 1),

                // Tab Bar View
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildItemsGrid(ShopItemType.frame, user),
                      _buildItemsGrid(ShopItemType.decoration, user),
                      _buildItemsGrid(ShopItemType.entrance, user),
                      _buildItemsGrid(ShopItemType.wallHanging, user),
                      _buildItemsGrid(ShopItemType.specialId, user),
                      _buildItemsGrid(ShopItemType.cardBorder, user),
                      _buildItemsGrid(ShopItemType.roomCardBorder, user),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsGrid(ShopItemType type, User? user) {
    return StreamBuilder<List<ShopItem>>(
      stream: ShopService().getShopItems(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<Set<String>>(
          stream: user != null
              ? ShopService().getOwnedItemIdsByTypeStream(user.uid, type)
              : Stream.value({}),
          builder: (context, ownedSnapshot) {
            final ownedIds = ownedSnapshot.data ?? {};
            final items = snapshot.data ?? [];
            final currentActive = _getActiveItemForType(type, user);

            final List<Map<String, dynamic>> displayItems = [
              {
                'id': null,
                'name': 'None',
                'asset': null,
                'price': 0,
                'isOwned': true,
              },
            ];

            final currentTypeOwned = _getOwnedIdsForType(type, user);

            for (var item in items) {
              displayItems.add({
                'id': item.id,
                'name': item.name,
                'asset': item.imageUrl,
                'price': item.price,
                'isOwned':
                    currentTypeOwned.contains(item.id) ||
                    currentTypeOwned.contains(item.imageUrl) ||
                    ownedIds.contains(item.id) ||
                    ownedIds.contains(item.imageUrl),
                'specialId': item.metadata?['specialId']?.toString(),
              });
            }

            // Add Custom Rewards (Competition prizes) from Inventory
            for (var ownedId in ownedIds) {
              bool inShop = items.any((si) => si.id == ownedId || si.imageUrl == ownedId);
              if (!inShop && ownedId.isNotEmpty) {
                displayItems.add({
                  'id': ownedId,
                  'name': 'جائزة حصرية',
                  'asset': ownedId,
                  'price': 0,
                  'isOwned': true,
                });
              }
            }

            // Fallback: Add items from old User Arrays if they are not in inventory yet
            for (var ownedId in currentTypeOwned) {
              bool alreadyAdded = displayItems.any((di) => di['id'] == ownedId || di['asset'] == ownedId);
              if (!alreadyAdded && ownedId.isNotEmpty) {
                displayItems.add({
                  'id': ownedId,
                  'name': 'جائزة قديمة',
                  'asset': ownedId,
                  'price': 0,
                  'isOwned': true,
                });
              }
            }

            if (type == ShopItemType.entrance) {
              displayItems.removeWhere(
                (item) => item['id'] != null && !item['isOwned'],
              );
            }

            if (type == ShopItemType.cardBorder) {
              final List<Map<String, dynamic>> colorBorders = [
                {
                  'id': 'cb_royal',
                  'name': 'المنظر الملكي',
                  'asset': 'style:royal',
                  'price': 0,
                  'isOwned': true,
                },
                {
                  'id': 'cb_neon',
                  'name': 'النيون المتوهج',
                  'asset': 'style:neon',
                  'price': 0,
                  'isOwned': true,
                },
                {
                  'id': 'cb_volcanic',
                  'name': 'البركاني الثائر',
                  'asset': 'style:volcanic',
                  'price': 0,
                  'isOwned': true,
                },
                {
                  'id': 'cb_starry',
                  'name': 'جوهرة الأميرة',
                  'asset': 'style:starry',
                  'price': 0,
                  'isOwned': true,
                },
                {
                  'id': 'cb_gold',
                  'name': 'ذهبي كلاسيك',
                  'asset': 'color:0xFFFFD700',
                  'price': 0,
                  'isOwned': true,
                },
                {
                  'id': 'cb_teal',
                  'name': 'تيل',
                  'asset': 'color:0xFF008080',
                  'price': 0,
                  'isOwned': true,
                },
                {
                  'id': 'cb_pink',
                  'name': 'وردي',
                  'asset': 'color:0xFFFF4081',
                  'price': 0,
                  'isOwned': true,
                },
                {
                  'id': 'cb_purple',
                  'name': 'بنفسجي',
                  'asset': 'color:0xFF9C27B0',
                  'price': 0,
                  'isOwned': true,
                },
                {
                  'id': 'cb_cyan',
                  'name': 'سماوي',
                  'asset': 'color:0xFF00BCD4',
                  'price': 0,
                  'isOwned': true,
                },
              ];
              displayItems.addAll(colorBorders);
            }

            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: displayItems.length,
              itemBuilder: (context, index) {
                return _buildGridItem(
                  displayItems[index],
                  user,
                  type,
                  currentActive,
                );
              },
            );
          },
        );
      },
    );
  }

  Set<String> _getOwnedIdsForType(ShopItemType type, User? user) {
    if (user == null) return {};
    switch (type) {
      case ShopItemType.frame:
        return user.ownedFrames.toSet();
      case ShopItemType.decoration:
        return user.ownedDecorations.toSet();
      case ShopItemType.wallHanging:
        return user.ownedWallHangings.toSet();
      case ShopItemType.cardBorder:
        return user.ownedCardBorders.toSet();
      case ShopItemType.roomCardBorder:
        return user.ownedRoomCardBorders.toSet();
      case ShopItemType.specialId:
        return user.ownedSpecialIdImages.toSet();
      case ShopItemType.entrance:
        return user.ownedEntrances.toSet();
      default:
        return {};
    }
  }

  String? _getActiveItemForType(ShopItemType type, User? user) {
    if (user == null) return null;
    switch (type) {
      case ShopItemType.frame:
        return user.profileFrame;
      case ShopItemType.decoration:
        return user.profileDecoration;
      case ShopItemType.wallHanging:
        return user.activeWallHanging;
      case ShopItemType.cardBorder:
        return user.profileCardBorder;
      case ShopItemType.roomCardBorder:
        return user.activeRoomCardBorder;
      case ShopItemType.specialId:
        return user.displayIdImage;
      case ShopItemType.entrance:
        return user.roomEntrance;
      default:
        return null;
    }
  }

  Widget _buildGridItem(
    Map<String, dynamic> item,
    User? user,
    ShopItemType type,
    String? activeItem,
  ) {
    final asset = item['asset'] as String?;
    final isSelected = activeItem == asset;
    final isOwned = item['isOwned'] as bool;
    final isNone = item['id'] == null;

    return GestureDetector(
      onTap: () {
        if (isOwned || isNone) {
          _handleSave(asset, type, user: user, specialId: item['specialId']);
        } else {
          final currentUser = auth.FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            _showPremiumPurchaseDialog(item, currentUser.uid, type, user: user);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? Colors.cyanAccent
                : Colors.white.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: isNone
                    ? const Icon(Icons.block, color: Colors.white38, size: 30)
                    : (type == ShopItemType.frame
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundImage:
                                      widget.profileImageUrl != null
                                      ? (widget.profileImageUrl!.startsWith(
                                                  'assets/',
                                                )
                                                ? AssetImage(
                                                    widget.profileImageUrl!,
                                                  )
                                                : NetworkImage(
                                                    widget.profileImageUrl!,
                                                  ))
                                            as ImageProvider
                                      : null,
                                ),
                                _buildFrameIcon(asset!, 40),
                              ],
                            )
                          : _buildFrameIcon(asset!, 40)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: !isOwned && !isNone
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.diamond,
                          size: 10,
                          color: Colors.cyanAccent,
                        ),
                        Text(
                          ' ${item['price']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      isNone ? 'بدون' : 'مملوك',
                      style: TextStyle(
                        color: isNone ? Colors.white30 : Colors.greenAccent,
                        fontSize: 10,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameIcon(String asset, double size) {
    if (asset.isEmpty) return const SizedBox.shrink();
    if (asset.startsWith('color:')) {
      try {
        final colorStr = asset.split(':')[1];
        final colorCode = int.tryParse(colorStr);
        if (colorCode != null) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(color: Color(colorCode), width: 3),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white10,
            ),
            child: const Center(
              child: Icon(Icons.crop_free, color: Colors.white24, size: 16),
            ),
          );
        }
      } catch (e) {}
    }

    if (asset.startsWith('style:')) {
      final style = asset.split(':')[1];
      IconData iconData = Icons.style;
      Color iconColor = Colors.white;

      if (style == 'neon') {
        iconData = Icons.wb_twilight;
        iconColor = Colors.cyanAccent;
      } else if (style == 'royal') {
        iconData = Icons.workspace_premium;
        iconColor = const Color(0xFFFFD700);
      } else if (style == 'volcanic') {
        iconData = Icons.local_fire_department;
        iconColor = const Color(0xFFFF4500);
      } else if (style == 'starry') {
        iconData = Icons.diamond;
        iconColor = const Color(0xFFFFD700);
      }

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(iconData, color: iconColor, size: size * 0.6),
      );
    }

    if (asset == 'special_rainbow') {
      return Icon(Icons.star, color: Colors.orange, size: size);
    }

    bool isNetwork = asset.startsWith('http');
    bool isLottie = asset.toLowerCase().endsWith('.json');

    if (isLottie) {
      if (isNetwork) {
        return Lottie.network(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      } else {
        // Only load if it looks like a valid asset path
        if (asset.startsWith('assets/')) {
          return Lottie.asset(asset, width: size, height: size, fit: BoxFit.contain);
        } else {
          return Icon(Icons.broken_image_rounded, color: Colors.white24, size: size * 0.5);
        }
      }
    }

    if (isNetwork) {
      return Image.network(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image_rounded, color: Colors.white24, size: size * 0.5),
      );
    } else {
      // Only load if it looks like a valid asset path
      if (asset.startsWith('assets/')) {
        return Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image_rounded, color: Colors.white24, size: size * 0.5),
        );
      } else {
        // It's probably a raw name or malformed string from DB
        return Icon(Icons.auto_awesome_rounded, color: Colors.amber.withOpacity(0.5), size: size * 0.5);
      }
    }
  }

  Future<void> _handleSave(
    String? newAsset,
    ShopItemType type, {
    User? user,
    String? specialId,
  }) async {
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    String fieldName;
    switch (type) {
      case ShopItemType.frame:
        fieldName = 'profileFrame';
        FramedAvatar.updateUserFrameCache(currentUser.uid, newAsset);
        break;
      case ShopItemType.decoration:
        fieldName = 'profileDecoration';
        break;
      case ShopItemType.wallHanging:
        fieldName = 'activeWallHanging';
        break;
      case ShopItemType.cardBorder:
        fieldName = 'profileCardBorder';
        break;
      case ShopItemType.roomCardBorder:
        fieldName = 'activeRoomCardBorder';
        try {
          final query = await FirebaseFirestore.instance
              .collection('rooms')
              .where('hostId', isEqualTo: currentUser.uid)
              .get();
          for (var doc in query.docs) {
            await doc.reference.update({
              'cardFrameImage': newAsset,
              'roomFrame': newAsset,
              'roomFrameImage': newAsset,
            });
          }
        } catch (e) {
          debugPrint('Error updating room frames: $e');
        }
        break;
      case ShopItemType.entrance:
        fieldName = 'roomEntrance';
        break;
      case ShopItemType.specialId:
        // For special IDs, we update both displayId and displayIdImage
        try {
          final updateData = <String, dynamic>{'displayIdImage': newAsset};

          if (specialId != null && specialId.isNotEmpty) {
            // Save current ID as original if not already saved
            if (user != null &&
                (user.originalDisplayId == null ||
                    user.originalDisplayId!.isEmpty)) {
              updateData['originalDisplayId'] =
                  user.originalDisplayId ?? user.displayId;
            }
            updateData['displayId'] = specialId;
            updateData['referralCode'] = specialId;
          } else if (user != null) {
            // Reverting to original ID
            final originalId = user.originalDisplayId ?? user.displayId;
            updateData['displayId'] = originalId;
            updateData['referralCode'] = originalId;
          }

          await UserService().updateUser(
            uid: currentUser.uid,
            data: updateData,
          );
          return;
        } catch (e) {
          debugPrint(e.toString());
          return;
        }
      default:
        return;
    }

    try {
      await UserService().updateUser(
        uid: currentUser.uid,
        data: {fieldName: newAsset},
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _showPremiumPurchaseDialog(
    Map<String, dynamic> item,
    String uid,
    ShopItemType type, {
    User? user,
  }) {
    final price = item['price'] as int? ?? 0;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Purchase',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return StreamBuilder<User?>(
          stream: UserService().getUserStream(uid),
          initialData: user ?? UserService().getUserSync(uid),
          builder: (context, snapshot) {
            final user = snapshot.data;
            final diamonds = user?.diamonds ?? 0;
            final canAfford = diamonds >= price;
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;

            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2C32),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'شراء الإطار',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 100,
                        width: 100,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white10,
                              radius: 40,
                              child: Icon(
                                Icons.person,
                                color: Colors.white24,
                                size: 40,
                              ),
                            ),
                            _buildFrameIcon(item['asset'], 100),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        item['name'] ?? 'عنصر مميز',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.diamond,
                            color: Colors.cyanAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$price',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'إلغاء',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      if (canAfford) {
                                        _processPurchase(
                                          item,
                                          type,
                                          price,
                                          uid,
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'رصيد غير كاف',
                                              style: TextStyle(
                                                fontFamily: 'Tajawal',
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isLoading
                                    ? Colors.cyanAccent.withValues(alpha: 0.5)
                                    : (canAfford
                                          ? Colors.cyanAccent
                                          : Colors.orange),
                                foregroundColor: Colors.black,
                                elevation: canAfford ? 8 : 2,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.black,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      canAfford ? 'تأكيد الشراء' : 'شحن الرصيد',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
    );
  }

  Future<void> _processPurchase(
    Map<String, dynamic> item,
    ShopItemType type,
    int price,
    String uid,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid);
        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) throw 'Error';
        int currentDiamonds = userSnapshot.get('diamonds') ?? 0;
        if (currentDiamonds < price) throw 'Not enough diamonds';

        String ownedField;
        switch (type) {
          case ShopItemType.frame:
            ownedField = 'ownedFrames';
            break;
          case ShopItemType.decoration:
            ownedField = 'ownedDecorations';
            break;
          case ShopItemType.wallHanging:
            ownedField = 'ownedWallHangings';
            break;
          case ShopItemType.cardBorder:
            ownedField = 'ownedCardBorders';
            break;
          case ShopItemType.roomCardBorder:
            ownedField = 'ownedRoomCardBorders';
            break;
          case ShopItemType.entrance:
            ownedField = 'ownedEntrances';
            break;
          case ShopItemType.specialId:
            ownedField = 'ownedSpecialIdImages';
            break;
          default:
            return;
        }

        final updateData = {
          'diamonds': FieldValue.increment(-price),
          ownedField: FieldValue.arrayUnion([item['id'] ?? item['asset']]),
        };

        if (type == ShopItemType.specialId && item['specialId'] != null) {
          updateData['ownedSpecialIds'] = FieldValue.arrayUnion([
            item['specialId'],
          ]);
        }

        transaction.update(userRef, updateData);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم الشراء بنجاح',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        );
      }
      _handleSave(item['asset'], type, specialId: item['specialId']);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }
}
