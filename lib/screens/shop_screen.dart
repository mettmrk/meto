import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:lottie/lottie.dart';
import '../models/index.dart';
import '../services/shop_service.dart';
import '../services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShopScreen extends StatefulWidget {
  final int initialIndex;
  const ShopScreen({super.key, this.initialIndex = 0});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ShopService _shopService = ShopService();

  // للبانر الإعلاني
  final PageController _adsController = PageController();
  dynamic _adsTimer;

  Set<String> _seenItemIds = {};
  SharedPreferences? _prefs;

  // ألوان التطبيق الأساسية
  Color get primaryGreen => Theme.of(context).primaryColor;
  final Color darkBg = const Color(0xFF0F111A);
  final Color cardColor = const Color(0xFF1E2230);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 9,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _loadSeenItems();

    // تشغيل التقليب التلقائي للبانر
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _startAdsTimer();
      }
    });
  }

  Future<void> _loadSeenItems() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _seenItemIds = _prefs?.getStringList('seen_shop_items')?.toSet() ?? {};
    });
  }

  Future<void> _markAsSeen(String id) async {
    if (!_seenItemIds.contains(id)) {
      setState(() {
        _seenItemIds.add(id);
      });
      await _prefs?.setStringList('seen_shop_items', _seenItemIds.toList());
    }
  }

  void _startAdsTimer() {
    // We use Future to mimic timer behavior recursively without explicit dart:async Timer import to avoid conflicts
    _adsTimer = true;
    _runAdsLoop();
  }

  void _runAdsLoop() async {
    if (!mounted || _adsTimer == null) return;
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted || _adsTimer == null) return;

    if (_adsController.hasClients) {
      int nextPage = _adsController.page!.round() + 1;
      if (nextPage > 2) nextPage = 0; // 3 ads

      _adsController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 800),
        curve: Curves.fastOutSlowIn,
      );
    }
    _runAdsLoop();
  }

  @override
  void dispose() {
    _adsTimer = null;
    _adsController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'متجر ميتو',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF00695C), primaryGreen],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'خلفيات'),
            Tab(text: 'الإطارات'),
            Tab(text: 'ID مميز'),
            Tab(text: 'التوثيق'),
            Tab(text: 'الملصقات'),
            Tab(text: 'الملف'),
            Tab(text: 'دخوليات'),
            Tab(text: 'معلقات'),
            Tab(text: 'إطار الغرفة'),
          ],
        ),
      ),
      body: StreamBuilder<auth.User?>(
        stream: auth.FirebaseAuth.instance.authStateChanges(),
        builder: (context, userSnapshot) {
          final userId = userSnapshot.data?.uid;
          if (userId == null)
            return const Center(
              child: Text(
                'يرجى تسجيل الدخول',
                style: TextStyle(color: Colors.white),
              ),
            );

          return StreamBuilder<Set<String>>(
            stream: _shopService.getOwnedItemIdsStream(userId),
            builder: (context, ownedSnapshot) {
              final ownedIds = ownedSnapshot.data ?? {};

              return StreamBuilder<User?>(
                stream: UserService().getUserStream(userId),
                initialData: UserService().getUserSync(userId),
                builder: (context, userStreamSnapshot) {
                  final currentUser = userStreamSnapshot.data;
                  final isLoading = userStreamSnapshot.connectionState == ConnectionState.waiting && currentUser == null;

                  return Column(
                    children: [
                      // عرض الأرصدة في الأعلى
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: darkBg.withOpacity(0.5),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 15),
                              _buildShopBalanceChip(
                                icon: Icons.diamond_rounded,
                                color: Colors.blue,
                                value: isLoading ? null : (currentUser?.diamonds ?? 0),
                                label: 'ألماس',
                              ),
                              const SizedBox(width: 10),
                              _buildShopBalanceChip(
                                image: 'assets/images/drhim.png',
                                color: Colors.yellow,
                                value: isLoading ? null : (currentUser?.coins ?? 0),
                                label: 'ذهب',
                              ),
                              const SizedBox(width: 10),
                              _buildShopBalanceChip(
                                image: 'assets/images/coinsmeto.png',
                                color: Colors.green,
                                value: isLoading ? null : (currentUser?.meto_chips ?? 0),
                                label: 'ميتو',
                              ),
                              const SizedBox(width: 15),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: List.generate(9, (index) {
                            ShopItemType tabType;
                            if (index == 7) {
                              tabType = ShopItemType.wallHanging;
                            } else if (index == 8) {
                              tabType = ShopItemType.roomCardBorder;
                            } else {
                              tabType = ShopItemType.values[index];
                            }
                            return _buildCategoryGrid(
                              tabType,
                              Icons.category,
                              ownedIds,
                              currentUser,
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryGrid(
    ShopItemType type,
    IconData icon,
    Set<String> ownedIds,
    User? currentUser,
  ) {
    return StreamBuilder<List<ShopItem>>(
      stream: _shopService.getShopItems(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        List<ShopItem> items = snapshot.data ?? [];

        // إضافة باقات ملصقات افتراضية إذا كان النوع هو ملصقات
        if (type == ShopItemType.sticker) {
          items.addAll(_getSampleStickerPacks());
        }

        if (items.isEmpty) return _buildEmptyState();

        // عرض 3 عناصر في السطر لتصغير الحجم (Grid 3 Columns)
        return Column(
          children: [
            if (type == ShopItemType.sticker) _buildFunnyPackBanner(),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.65, // ليكون شكل البطاقة طولي وأنيق
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => _buildSmallItemCard(
                  items[index],
                  ownedIds.contains(items[index].id),
                  currentUser,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<ShopItem> _getSampleStickerPacks() {
    return [
      ShopItem(
        id: 'pack_emoji_premium',
        name: 'باقة الإيموجي المميزة',
        imageUrl:
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f929/lottie.json',
        price: 1500,
        type: ShopItemType.sticker,
        currency: Currency.diamonds,
        metadata: {
          'isPack': true,
          'count': 6,
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f929/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f92a/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f911/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60e/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60d/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f973/lottie.json',
          ],
        },
      ),
      ShopItem(
        id: 'pack_funny_cats',
        name: 'باقة القطط المضحكة',
        imageUrl:
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f63b/lottie.json',
        price: 800,
        type: ShopItemType.sticker,
        currency: Currency.diamonds,
        metadata: {
          'isPack': true,
          'count': 4,
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f63b/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f63a/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f63c/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f63d/lottie.json',
          ],
        },
      ),
      ShopItem(
        id: 'pack_love_vibe',
        name: 'باقة مشاعر الحب',
        imageUrl:
            'https://fonts.gstatic.com/s/e/notoemoji/latest/2764_fe0f/lottie.json',
        price: 1200,
        type: ShopItemType.sticker,
        currency: Currency.diamonds,
        metadata: {
          'isPack': true,
          'count': 5,
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/2764_fe0f/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f496/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f498/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f49d/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f49e/lottie.json',
          ],
        },
      ),
      ShopItem(
        id: 'pack_party_time',
        name: 'باقة وقت الحفلة',
        imageUrl:
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f973/lottie.json',
        price: 1000,
        type: ShopItemType.sticker,
        currency: Currency.diamonds,
        metadata: {
          'isPack': true,
          'count': 3,
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f973/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f389/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f38a/lottie.json',
          ],
        },
      ),
      ShopItem(
        id: 'pack_funny_express',
        name: 'باقة الضحك القصوى',
        imageUrl:
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f923/lottie.json',
        price: 900,
        type: ShopItemType.sticker,
        currency: Currency.diamonds,
        metadata: {
          'isPack': true,
          'count': 5,
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f923/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f602/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f61c/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f61d/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f92b/lottie.json',
          ],
        },
      ),
      ShopItem(
        id: 'pack_dance_party',
        name: 'باقة الرقص والحفلة',
        imageUrl:
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f483/lottie.json',
        price: 1100,
        type: ShopItemType.sticker,
        currency: Currency.diamonds,
        metadata: {
          'isPack': true,
          'count': 6,
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f483/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f483_1f3fb/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f483_1f3fc/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f483_1f3fd/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f483_1f3fe/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f483_1f3ff/lottie.json',
          ],
        },
      ),
      ShopItem(
        id: 'pack_drama_sad',
        name: 'باقة الدراما',
        imageUrl:
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f62d/lottie.json',
        price: 850,
        type: ShopItemType.sticker,
        currency: Currency.diamonds,
        metadata: {
          'isPack': true,
          'count': 4,
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f62d/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f622/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f97a/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f494/lottie.json',
          ],
        },
      ),
      ShopItem(
        id: 'pack_cool_vibes',
        name: 'باقة الأكشن والكول',
        imageUrl:
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60e/lottie.json',
        price: 1300,
        type: ShopItemType.sticker,
        currency: Currency.diamonds,
        metadata: {
          'isPack': true,
          'count': 4,
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60e/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f911/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f525/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f4a5/lottie.json',
          ],
        },
      ),
    ];
  }

  Widget _buildSmallItemCard(ShopItem item, bool isOwned, User? currentUser) {
    bool isEquipped = false;
    if (currentUser != null) {
      if (item.type == ShopItemType.decoration)
        isEquipped = currentUser.profileDecoration == item.imageUrl;
      else if (item.type == ShopItemType.verification)
        isEquipped = currentUser.verificationIcon == item.imageUrl;
      else if (item.type == ShopItemType.wallHanging)
        isEquipped = currentUser.activeWallHanging == item.imageUrl;
    }

    bool isPack = item.id.startsWith('pack_');

    // منطق المنتج الجديد: إذا كان تم إنشاؤه في آخر 7 أيام ولم يتم رؤيته بعد
    bool isNew = false;
    if (item.createdAt != null && !_seenItemIds.contains(item.id)) {
      final diff = DateTime.now().difference(item.createdAt!);
      if (diff.inDays < 7) {
        isNew = true;
      }
    }

    return GestureDetector(
      onTap: () {
        if (isNew) _markAsSeen(item.id);
        if (isOwned) {
          _handleEquip(item, currentUser!);
        } else {
          _showPurchaseDialog(context, item);
        }
      },
      child: Stack(
        children: [
          _NewItemAnimatedBorder(
            isNew: isNew,
            isEquipped: isEquipped,
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _buildItemImage(item),
                    ),
                  ),
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.metadata != null && item.metadata!['count'] != null)
                    Text(
                      '${item.metadata!['count']} ملصق',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 7,
                      ),
                    ),
                  const SizedBox(height: 1),
                  if (!isOwned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${item.price}',
                            style: TextStyle(
                              color: item.currency == Currency.meto
                                  ? primaryGreen
                                  : Colors.blueAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (item.currency == Currency.meto)
                            Transform.translate(
                              offset: const Offset(0, -1),
                              child: Image.asset(
                                'assets/images/coinsmeto.png',
                                width: 12,
                                height: 12,
                              ),
                            )
                          else
                            Transform.translate(
                              offset: const Offset(0, -0.5),
                              child: const Icon(
                                Icons.diamond_rounded,
                                color: Colors.blueAccent,
                                size: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                    child: SizedBox(
                      width: double.infinity,
                      height: 24,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEquipped
                              ? Colors.green
                              : (isOwned ? Colors.orange : primaryGreen),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (isNew) _markAsSeen(item.id);
                          if (isOwned) {
                            _handleEquip(item, currentUser!);
                          } else {
                            _showPurchaseDialog(context, item);
                          }
                        },
                        child: Text(
                          isOwned ? (isEquipped ? 'مفعل' : 'مملوك') : 'شراء',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isPack)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'باقة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (isNew)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  'جديد',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context, ShopItem item) {
    if (item.type == ShopItemType.background) {
      _showBackgroundPurchaseDialog(context, item);
      return;
    }

    showDialog(
      context: context,
      // نستخدم barrierColor لإعطاء تعتيم جميل للخلفية
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        // نزيل الخلفية الشفافة من النافذة نفسها
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            // نستخدم لون التطبيق الثابت للنافذة
            color: cardColor,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: primaryGreen.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'تأكيد الشراء',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Stack لوضع الأنيميشن خلف الصورة فقط
              Stack(
                alignment: Alignment.center,
                children: [
                  // الأنيميشن
                  SizedBox(
                    width: 180, // حجم أكبر للأنيميشن
                    height: 180,
                    child: Lottie.asset(
                      'assets/lottie/Reward light effect.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                  // صورة العنصر بحجم أكبر
                  Container(
                    height: 120, // تم تكبير الصورة
                    width: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      // خلفية شفافة قليلاً لدمجها مع الأنيميشن
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: _buildItemImage(item, size: 120),
                  ),
                ],
              ),

              const SizedBox(height: 15),
              Text(
                item.name,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color:
                        (item.currency == Currency.meto
                                ? primaryGreen
                                : Colors.blueAccent)
                            .withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.price}',
                      style: TextStyle(
                        color: item.currency == Currency.meto
                            ? primaryGreen
                            : Colors.blueAccent,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (item.currency == Currency.meto)
                      Transform.translate(
                        offset: const Offset(0, -2),
                        child: Image.asset(
                          'assets/images/coinsmeto.png',
                          width: 24,
                          height: 24,
                        ),
                      )
                    else
                      Transform.translate(
                        offset: const Offset(0, -1),
                        child: const Icon(
                          Icons.diamond_rounded,
                          color: Colors.blueAccent,
                          size: 24,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // زر التأكيد
              SizedBox(
                height: 45,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _processPurchase(item);
                  },
                  child: const Text(
                    'تأكيد الشراء',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBackgroundPurchaseDialog(BuildContext context, ShopItem item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 45, vertical: 24),
        child: Container(
          width: double.infinity,
          height:
              MediaQuery.of(context).size.height *
              0.55, // تم تصغير النافذة بناءً على الطلب (55% من الشاشة)
          decoration: BoxDecoration(
            color: darkBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryGreen.withOpacity(0.8),
              width: 2.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // صورة الخلفية بكامل النافذة
              Positioned.fill(child: _buildItemImage(item, fit: BoxFit.cover)),

              // ظلال شفافة فوق وتحت لضمان وضوح النصوص
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.9),
                      ],
                      stops: const [0.0, 0.2, 0.6, 1.0],
                    ),
                  ),
                ),
              ),

              // العنوان العلوي
              const Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'معاينة الخلفية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ),
              ),

              // النصوص والأزرار بالأسفل فوق الصورة
              Positioned(
                bottom: 12,
                left: 20,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              (item.currency == Currency.meto
                                      ? primaryGreen
                                      : Colors.blueAccent)
                                  .withOpacity(0.5),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${item.price}',
                            style: TextStyle(
                              color: item.currency == Currency.meto
                                  ? primaryGreen
                                  : Colors.blueAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (item.currency == Currency.meto)
                            Image.asset(
                              'assets/images/coinsmeto.png',
                              width: 20,
                              height: 20,
                            )
                          else
                            const Icon(
                              Icons.diamond_rounded,
                              color: Colors.blueAccent,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 3,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _processPurchase(item);
                        },
                        child: const Text(
                          'تأكيد الشراء',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleEquip(ShopItem item, User user) async {
    try {
      await _shopService.equipShopItem(user.uid, item);
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $errorMsg')));
      }
    }
  }

  void _processPurchase(ShopItem item) async {
    try {
      final uid = auth.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final errorMsg = await _shopService.purchaseShopItem(uid, item);
      if (mounted) {
        if (errorMsg != null) {
          if (errorMsg.contains('غير كافٍ')) {
            _showLowBalanceDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل عملية الشراء: $errorMsg'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم الشراء بنجاح!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (e.toString().contains('غير كافٍ'))
        _showLowBalanceDialog();
      else if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل: $e')));
    }
  }

  void _showLowBalanceDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('رصيد ناقص', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('شحن'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(
    ShopItem item, {
    double? size,
    BoxFit fit = BoxFit.contain,
  }) {
    // التحقق مما إذا كان العنصر يحتوي على أنيميشن (Lottie)
    bool isAnimated =
        item.type == ShopItemType.sticker ||
        (item.metadata != null && item.metadata!['lottieUrl'] != null);

    String imageUrl = item.imageUrl;
    String? lottieUrl = item.metadata?['lottieUrl'] as String?;

    if (isAnimated && (lottieUrl != null || imageUrl.endsWith('.json'))) {
      String path = lottieUrl ?? imageUrl;
      if (path.startsWith('http')) {
        return Lottie.network(
          path,
          fit: fit,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.style_outlined,
            color: Colors.white10,
            size: size ?? 24,
          ),
        );
      } else {
        return Lottie.asset(path, fit: fit, width: size, height: size);
      }
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: fit,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.image_outlined, color: Colors.white10, size: size ?? 24),
      );
    } else {
      return Image.asset(imageUrl, fit: fit, width: size, height: size);
    }
  }

  Widget _buildFunnyPackBanner() {
    final List<Map<String, dynamic>> ads = [
      {
        'id': 'pack_cool_vibes',
        'name': 'باقة الكول والأكشن',
        'desc': 'ملصقات حماسية لكولك المفضل',
        'price': 1300,
        'lottie':
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60e/lottie.json',
        'colors': [
          Colors.purple.withValues(alpha: 0.8),
          Colors.deepPurple.shade900,
        ],
      },
      {
        'id': 'pack_dance_party',
        'name': 'باقة الرقص والحفلة',
        'desc': 'ملصقات بشرية راقصة بألوان وعروق مختلفة',
        'price': 1100,
        'lottie':
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f57a_1f3fb/lottie.json',
        'colors': [Colors.orange.withValues(alpha: 0.8), Colors.red.shade900],
      },
      {
        'id': 'pack_drama_sad',
        'name': 'باقة الدراما',
        'desc': 'عبر عن مشاعرك الحزينة والدرامية بصمت',
        'price': 850,
        'lottie':
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f62d/lottie.json',
        'colors': [Colors.blue.withValues(alpha: 0.8), Colors.indigo.shade900],
      },
    ];

    return Container(
      margin: const EdgeInsets.all(15),
      height: 140,
      child: PageView.builder(
        controller: _adsController,
        itemCount: ads.length,
        itemBuilder: (context, index) {
          final ad = ads[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: ad['colors'],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: ad['colors'][1].withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // خلفية شفافة من الأنميشن
                Positioned(
                  left: -20,
                  bottom: -20,
                  child: Opacity(
                    opacity: 0.4,
                    child: SizedBox(
                      width: 140,
                      height: 140,
                      child: Lottie.network(
                        ad['lottie'],
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                      begin: Alignment
                          .centerRight, // Arabic is RTL, so text is on the right
                      end: Alignment.centerLeft,
                    ),
                  ),
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'وصل حديثاً!',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ad['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ad['desc'],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${ad['price']}',
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.diamond_rounded,
                                  color: Colors.blueAccent,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              final item = ShopItem(
                                id: ad['id'],
                                name: ad['name'],
                                imageUrl: ad['lottie'],
                                price: ad['price'],
                                type: ShopItemType.sticker,
                                currency: Currency.diamonds,
                                metadata: {'isPack': true, 'count': 6},
                              );
                              _showPurchaseDialog(context, item);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'شراء',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() => const Center(
    child: Text('قريباً...', style: TextStyle(color: Colors.white24)),
  );
  Widget _buildShopBalanceChip({
    IconData? icon,
    String? image,
    required Color color,
    int? value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -1),
            child: image != null
                ? Image.asset(image, width: 14, height: 14)
                : Icon(icon!, color: color, size: 14),
          ),
          const SizedBox(width: 6),
          value == null
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _formatNumber(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _NewItemAnimatedBorder extends StatefulWidget {
  final bool isNew;
  final bool isEquipped;
  final Widget child;

  const _NewItemAnimatedBorder({
    required this.isNew,
    required this.isEquipped,
    required this.child,
  });

  @override
  State<_NewItemAnimatedBorder> createState() => _NewItemAnimatedBorderState();
}

class _NewItemAnimatedBorderState extends State<_NewItemAnimatedBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.isNew && !widget.isEquipped) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_NewItemAnimatedBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isNew && !widget.isEquipped) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEquipped) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber, width: 1.5),
        ),
        child: widget.child,
      );
    }

    if (!widget.isNew) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.amber.withOpacity(0.3 + (_animation.value * 0.7)),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.2 * _animation.value),
                blurRadius: 8 * _animation.value,
                spreadRadius: 1 * _animation.value,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
