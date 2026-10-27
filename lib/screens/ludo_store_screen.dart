import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'dart:ui';
import '../models/index.dart'; // تأكد من وجود الموديلات
import '../services/shop_service.dart';
import '../services/user_service.dart';
import 'wallet_screen.dart';
import '../models/gift_model.dart';

class LudoStoreScreen extends StatefulWidget {
  const LudoStoreScreen({super.key});

  @override
  State<LudoStoreScreen> createState() => _AdvancedLudoStoreScreenState();
}

class _AdvancedLudoStoreScreenState extends State<LudoStoreScreen> {
  final ShopService _shopService = ShopService();
  int _selectedTabIndex = 0; // 0: Pieces, 1: Boards, 2: Dice

  // للتحكم في حركة الخلفية (Parallax)
  ValueNotifier<Offset> _scrollOffset = ValueNotifier(Offset.zero);
  bool _isPurchasing = false;

  @override
  Widget build(BuildContext context) {
    final userId = auth.FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF020111), // أسود فضائي عميق
      body: Stack(
        children: [
          // 1. خلفية متحركة (Parallax Background)
          _buildParallaxBackground(),

          // 2. المحتوى الرئيسي (الجداول)
          SafeArea(
            bottom: false,
            child: userId == null
                ? _buildLoginRequired()
                : Column(
                    children: [
                      StreamBuilder<User?>(
                        stream: UserService().getUserStream(userId),
                        initialData: UserService().getUserSync(userId),
                        builder: (context, userStreamSnapshot) {
                          final currentUser = userStreamSnapshot.data;
                          final isLoading = userStreamSnapshot.connectionState == ConnectionState.waiting && currentUser == null;
                          return _buildAdvancedHeader(currentUser, isLoading: isLoading);
                        },
                      ),
                      Expanded(
                        child: StreamBuilder<Set<String>>(
                          stream: _shopService.getOwnedItemIdsStream(userId),
                          builder: (context, ownedSnapshot) {
                            final ownedIds = ownedSnapshot.data ?? {};

                            return StreamBuilder<User?>(
                              stream: UserService().getUserStream(userId),
                              initialData: UserService().getUserSync(userId),
                              builder: (context, userStreamSnapshot) {
                                final currentUser = userStreamSnapshot.data;

                                // تحديد نوع العناصر بناءً على التبويب المختار
                                ShopItemType currentType;
                                switch (_selectedTabIndex) {
                                  case 0:
                                    currentType = ShopItemType.ludoPiece;
                                    break;
                                  case 1:
                                    currentType = ShopItemType.ludoBoard;
                                    break;
                                  case 2:
                                    currentType = ShopItemType.ludoDice;
                                    break;
                                  case 3:
                                    currentType = ShopItemType.ludoHall;
                                    break;
                                  default:
                                    currentType = ShopItemType.ludoPiece;
                                }

                                return _buildItemsGrid(
                                  currentType,
                                  ownedIds,
                                  currentUser,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),

          // 3. شريط التنقل السفلي العائم (Floating Bottom Nav)
          _buildFloatingBottomNav(),
        ],
      ),
    );
  }

  // --- بناء الخلفية المتحركة ---
  Widget _buildParallaxBackground() {
    return ValueListenableBuilder<Offset>(
      valueListenable: _scrollOffset,
      builder: (context, offset, child) {
        return Stack(
          children: [
            // الطبقة البعيدة (نجوم/سديم)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F0C29), // Deep Navy
                      Color(0xFF302B63), // Deep Violet
                      Color(0xFF24243E), // Deep Space Blue
                    ],
                  ),
                ),
              ),
            ),
            // الطبقة القريبة (جزيئات عائمة)
            Positioned(
              top: -50 + (offset.dy * 0.05),
              left: -50 + (offset.dx * 0.05),
              child: _buildParticles(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParticles() {
    // يمكنك استخدام حزمة flutter_particles للحصول على تأثير أفضل،
    // هنا سنستخدم دائرة بسيطة كتوهج خلفي
    return Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFF6C22BD).withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  // --- بناء الهيدر الاحترافي ---
  Widget _buildAdvancedHeader(User? currentUser, {bool isLoading = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const Text(
                'متجر الأساطير',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Color(0xFFE040FB), blurRadius: 10),
                  ],
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBalanceChip(
                  icon: Icons.diamond_rounded,
                  color: Colors.blue,
                  value: isLoading ? null : (currentUser?.diamonds ?? 0),
                ),
                const SizedBox(width: 10),
                _buildBalanceChip(
                  icon: Icons.stars_rounded,
                  color: Colors.yellow,
                  value: isLoading ? null : (currentUser?.coins ?? 0),
                ),
                const SizedBox(width: 10),
                _buildBalanceChip(
                  icon: Icons.token_rounded,
                  color: Colors.green,
                  value: isLoading ? null : (currentUser?.meto_chips ?? 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int value) {
    if (value >= 1000000) {
      double val = value / 1000000;
      return val % 1 == 0 ? "${val.toInt()}M" : "${val.toStringAsFixed(1)}M";
    } else if (value >= 10000) {
      double val = value / 1000;
      return val % 1 == 0 ? "${val.toInt()}k" : "${val.toStringAsFixed(1)}k";
    }
    return value.toString();
  }

  Widget _buildBalanceChip({
    required IconData icon,
    required Color color,
    int? value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.black.withOpacity(0.4),
        border: Border.all(color: color.withOpacity(0.6), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          value == null
              ? const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _formatCurrency(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
        ],
      ),
    );
  }

  // --- بناء شبكة العناصر ---
  Widget _buildItemsGrid(
    ShopItemType type,
    Set<String> ownedIds,
    User? currentUser,
  ) {
    return StreamBuilder<List<ShopItem>>(
      stream: _shopService.getShopItems(type),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final items = snapshot.data!;

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              // تحديث قيمة الـ Parallax عند التمرير
              _scrollOffset.value = Offset(0, notification.metrics.pixels);
            }
            return true;
          },
          child: GridView.builder(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 100,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.5, // Adjusted for 4 columns, more height
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _buildGameCard(items[index], ownedIds, currentUser);
            },
          ),
        );
      },
    );
  }

  // --- بناء البطاقة الملكية (The Masterpiece) ---
  Widget _buildGameCard(
    ShopItem item,
    Set<String> ownedIds,
    User? currentUser,
  ) {
    final bool isOwned = ownedIds.contains(item.id);
    bool isEquipped = false;
    if (currentUser != null && isOwned) {
      if (item.type == ShopItemType.ludoPiece)
        isEquipped = currentUser.ludoTokenTheme == item.id;
      else if (item.type == ShopItemType.ludoBoard)
        isEquipped = currentUser.ludoBoardTheme == item.id;
      else if (item.type == ShopItemType.ludoDice)
        isEquipped = currentUser.ludoDiceTheme == item.id;
      else if (item.type == ShopItemType.ludoHall)
        isEquipped = currentUser.ludoHallTheme == item.id;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        // تأثير الظل ثلاثي الأبعاد
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 5,
            offset: const Offset(2, 2),
          ),
          BoxShadow(
            color: isEquipped
                ? const Color(0xFFFFD700).withOpacity(0.2)
                : const Color(0xFF6C22BD).withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 1. خلفية البطاقة (تدرج لوني عميق)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A2A50), Color(0xFF101025)],
                ),
              ),
            ),

            // 2. حدود البطاقة المضيئة (Neon Border)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEquipped
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF6C22BD).withOpacity(0.5),
                  width: isEquipped ? 2 : 1,
                ),
              ),
            ),

            // 3. محتوى البطاقة
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // صورة العنصر مع توهج خلفي
                Expanded(
                  flex: 3,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: isEquipped
                                  ? const Color(0xFFFFD700).withOpacity(0.2)
                                  : const Color(0xFF00D2FF).withOpacity(0.1),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: item.imageUrl.startsWith('http')
                            ? Image.network(
                                item.imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image,
                                  color: Colors.white24,
                                ),
                              )
                            : Image.asset(
                                item.imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image,
                                  color: Colors.white24,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // تفاصيل العنصر
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    color: Colors.black.withOpacity(0.3), // أرضية داكنة للنص
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Flexible(
                          child: Text(
                            item.name.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Flexible(
                          child: _buildGameButton(
                            item,
                            isOwned,
                            isEquipped,
                            currentUser,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 4. تأثير اللمعان (Shine Effect overlay) — ignored by pointer so buttons work
            Positioned.fill(child: IgnorePointer(child: _buildShineEffect())),
          ],
        ),
      ),
    );
  }

  // تأثير لمعان يتحرك عبر البطاقة
  Widget _buildShineEffect() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-1.2, -1.2),
          end: const Alignment(1.2, 1.2),
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.1), // شريط اللمعان
            Colors.white.withOpacity(0.0),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
        ),
      ),
    );
  }

  // --- بناء الزر بستايل الألعاب ---
  Widget _buildGameButton(
    ShopItem item,
    bool isOwned,
    bool isEquipped,
    User? currentUser,
  ) {
    Color btnColor = isEquipped
        ? const Color(0xFFFFD700)
        : (isOwned ? const Color(0xFF00D2FF) : const Color(0xFFE040FB));

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: btnColor.withOpacity(0.5),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ), // توهج الزر
          const BoxShadow(
            color: Colors.white24,
            blurRadius: 1,
            offset: Offset(0, -2),
            spreadRadius: -1,
          ), // إضاءة علوية للزر
        ],
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [btnColor, btnColor.withOpacity(0.8)],
        ),
      ),
      child: ElevatedButton(
        onPressed: isOwned
            ? () => _handleEquip(item, currentUser)
            : () => _showPurchaseDialog(item),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: isOwned
            ? Text(
                isEquipped ? 'مجهز' : 'تجهيز',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.currency == Currency.meto
                        ? Icons.token_rounded
                        : Icons.diamond,
                    size: 10,
                    color: item.currency == Currency.meto
                        ? Colors.green
                        : Colors.blue,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _formatCurrency(item.price),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // --- بناء شريط التنقل السفلي العائم (Glassmorphism Nav) ---
  Widget _buildFloatingBottomNav() {
    return Positioned(
      bottom: 20,
      left: 30,
      right: 30,
      child: Container(
        height: 75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: Container(
            // Premium high-performance glassmorphism without BackdropFilter to prevent GPU strain and distortion
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.casino, 'القطع'),
                _buildNavItem(1, Icons.fullscreen, 'الطاولات'),
                _buildNavItem(2, Icons.grid_view_rounded, 'النرد'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: isSelected
            ? BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFE040FB), Colors.transparent],
                ),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white60,
              size: 28,
            ),
            if (isSelected) const SizedBox(height: 2),
            if (isSelected)
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleEquip(ShopItem item, User? currentUser) async {
    if (currentUser == null) return;
    try {
      await _shopService.equipShopItem(currentUser.uid, item);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showPurchaseDialog(ShopItem item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تأكيد الشراء',
          style: TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
        ),
        content: Text(
          'هل تريد شراء ${item.name} مقابل ${item.price} ${item.currency == Currency.meto ? 'عملة ميتو' : 'ماسة'}؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isPurchasing
                ? null
                : () async {
                    setState(() => _isPurchasing = true);
                    Navigator.pop(dialogContext);
                    try {
                      final user = auth.FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        final errorMsg = await _shopService.purchaseShopItem(user.uid, item);
                        if (mounted) {
                          if (errorMsg != null) {
                            if (errorMsg.contains('غير كافٍ')) {
                              _showLowBalanceDialog();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('فشل عملية الشراء: $errorMsg'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم الشراء بنجاح!'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        final errorStr = e.toString();
                        if (errorStr.contains('غير كافٍ')) {
                          _showLowBalanceDialog();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('فشل عملية الشراء: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _isPurchasing = false);
                      }
                    }
                  },
            child: _isPurchasing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Text(
                    'شراء',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  // دمج بقية الدوال (Empty state, handleEquip, showPurchaseDialog) من كودك الأصلي
  void _showLowBalanceDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFF00D2FF).withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D2FF).withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE040FB).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFFE040FB),
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "رصيدك غير كافٍ",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "لا تمتلك ما يكفي من الرصيد لإتمام هذه العملية. هل ترغب في الانتقال لصفحة الشحن الآن؟",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text(
                        "ليس الآن",
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF00D2FF,
                            ).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          final user = auth.FirebaseAuth.instance.currentUser;
                          if (user != null && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    WalletScreen(userId: user.uid),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          "شحن الآن",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
  }

  Widget _buildLoginRequired() {
    return const Center(
      child: Text("يرجى تسجيل الدخول", style: TextStyle(color: Colors.white54)),
    );
  }
}
