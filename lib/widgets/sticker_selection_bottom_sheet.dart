import 'package:animated_emoji/animated_emoji.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../services/voice_room_service.dart';
import '../services/shop_service.dart';
import '../models/index.dart';
import '../screens/shop_screen.dart';

class StickerSelectionBottomSheet extends StatefulWidget {
  final Function(String id)? onSelect;
  const StickerSelectionBottomSheet({super.key, this.onSelect});

  static final Map<String, AnimatedEmojiData> _emojiMap = {
    'haha': AnimatedEmojis.joy,
    'love': AnimatedEmojis.heartEyes,
    'kiss': AnimatedEmojis.kissingHeart,
    'kiss_right': AnimatedEmojis.kissingHeart,
    'spit_right': AnimatedEmojis.angry,
    'fire': AnimatedEmojis.fire,
    'sad': AnimatedEmojis.cry,
    'angry': AnimatedEmojis.angry,
    'like': AnimatedEmojis.thumbsUp,
    'clap': AnimatedEmojis.clap,
    'rose': AnimatedEmojis.rose,
    'bomb': AnimatedEmojis.bomb,
    'smile': AnimatedEmojis.smile,
    'laugh': AnimatedEmojis.laughing,
    'wink': AnimatedEmojis.wink,
    'party': AnimatedEmojis.partyingFace,
    'rocket': AnimatedEmojis.rocket,
    'ghost': AnimatedEmojis.ghost,
    'sparkles': AnimatedEmojis.sparkles,
    'muscle': AnimatedEmojis.muscle,
    'eyes': AnimatedEmojis.eyes,
  };

  static AnimatedEmojiData? getEmojiData(String id) {
    return _emojiMap[id];
  }

  @override
  State<StickerSelectionBottomSheet> createState() =>
      _StickerSelectionBottomSheetState();
}

class _StickerSelectionBottomSheetState
    extends State<StickerSelectionBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ShopService _shopService = ShopService();

  static final List<Map<String, dynamic>> _defaultStickers = [
    {'id': 'haha', 'name': 'ضحك', 'emoji': AnimatedEmojis.joy},
    {'id': 'love', 'name': 'حب', 'emoji': AnimatedEmojis.heartEyes},
    {'id': 'kiss_right', 'name': 'قبلة', 'emoji': AnimatedEmojis.kissingHeart},
    {'id': 'fire', 'name': 'نار', 'emoji': AnimatedEmojis.fire},
    {'id': 'sad', 'name': 'حزين', 'emoji': AnimatedEmojis.cry},
    {'id': 'angry', 'name': 'غاضب', 'emoji': AnimatedEmojis.angry},
    {'id': 'like', 'name': 'لايك', 'emoji': AnimatedEmojis.thumbsUp},
    {'id': 'clap', 'name': 'تصفيق', 'emoji': AnimatedEmojis.clap},
    {'id': 'rose', 'name': 'وردة', 'emoji': AnimatedEmojis.rose},
    {'id': 'bomb', 'name': 'قنبلة', 'emoji': AnimatedEmojis.bomb},
    {'id': 'smile', 'name': 'مبتسم', 'emoji': AnimatedEmojis.smile},
    {'id': 'laugh', 'name': 'مفطس', 'emoji': AnimatedEmojis.laughing},
    {'id': 'wink', 'name': 'غمزة', 'emoji': AnimatedEmojis.wink},
    {'id': 'party', 'name': 'حفلة', 'emoji': AnimatedEmojis.partyingFace},
    {'id': 'rocket', 'name': 'صاروخ', 'emoji': AnimatedEmojis.rocket},
    {'id': 'ghost', 'name': 'شبح', 'emoji': AnimatedEmojis.ghost},
    {'id': 'sparkles', 'name': 'بريق', 'emoji': AnimatedEmojis.sparkles},
    {'id': 'muscle', 'name': 'قوة', 'emoji': AnimatedEmojis.muscle},
    {'id': 'eyes', 'name': 'عيون', 'emoji': AnimatedEmojis.eyes},
  ];


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = auth.FirebaseAuth.instance.currentUser?.uid;

    return Container(
      height: 500,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 15),
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF00FFD1),
            labelColor: const Color(0xFF00FFD1),
            unselectedLabelColor: Colors.white38,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'الأساسية'),
              Tab(text: 'باقاتي'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStickerGrid(_defaultStickers, isEmoji: true),
                uid == null 
                  ? const Center(child: Text('سجل الدخول لرؤية باقاتك', style: TextStyle(color: Colors.white24)))
                  : _buildOwnedPacksStream(uid),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnedPacksStream(String uid) {
    return StreamBuilder<List<ShopItem>>(
      stream: _shopService.getShopItems(ShopItemType.sticker),
      builder: (context, shopSnapshot) {
        return StreamBuilder<Set<String>>(
          stream: _shopService.getOwnedItemIdsStream(uid),
          builder: (context, ownedSnapshot) {
            if (ownedSnapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            
            final ownedIds = ownedSnapshot.data ?? {};
            final allStickersItems = shopSnapshot.data ?? [];
            
            // فلترة الباقات المملوكة فقط
            final ownedPacks = allStickersItems.where((item) => ownedIds.contains(item.id)).toList();
            
            // إضافة الباقات الافتراضية التي أضفناها في الكود (لأنه قد لا تكون في فايربيس بعد)
            // نتحقق من وجود "pack_" كبداية للـ ID كدليل على أنها باقة
            final mockPacks = _getMockOwnedPacks(ownedIds);
            final totalPacks = [...ownedPacks, ...mockPacks];

            if (totalPacks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: Colors.white10, size: 64),
                    const SizedBox(height: 16),
                    const Text('لا تملك أي باقات ملصقات حالياً', style: TextStyle(color: Colors.white24)),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen(initialIndex: 4)));
                      },
                      child: const Text('اذهب للمتجر', style: TextStyle(color: Color(0xFF00FFD1))),
                    ),
                  ],
                ),
              );
            }

            // تجميع كل الملصقات من كل الباقات المملوكة
            List<Map<String, dynamic>> packStickers = [];
            for (var pack in totalPacks) {
              final stickersUrls = pack.metadata?['stickers'] as List<dynamic>?;
              if (stickersUrls != null) {
                for (var url in stickersUrls) {
                  packStickers.add({
                    'id': 'remote_${url.hashCode}',
                    'name': pack.name,
                    'url': url.toString(),
                    'isLottie': url.toString().contains('.json'),
                  });
                }
              }
            }

            return _buildStickerGrid(packStickers, isEmoji: false);
          },
        );
      },
    );
  }

  List<ShopItem> _getMockOwnedPacks(Set<String> ownedIds) {
    final allPossiblePacks = [
      ShopItem(
        id: 'pack_emoji_premium',
        name: 'باقة الإيموجي المميزة',
        imageUrl: '',
        price: 0,
        type: ShopItemType.sticker,
        metadata: {
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f929/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f92a/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f911/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60e/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60d/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f973/lottie.json',
          ]
        },
      ),
      ShopItem(
        id: 'pack_funny_cats',
        name: 'باقة القطط المضحكة',
        imageUrl: '',
        price: 0,
        type: ShopItemType.sticker,
        metadata: {
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f63b/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f63a/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f63c/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f63d/lottie.json',
          ]
        },
      ),
      ShopItem(
        id: 'pack_love_vibe',
        name: 'باقة مشاعر الحب',
        imageUrl: '',
        price: 0,
        type: ShopItemType.sticker,
        metadata: {
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/2764_fe0f/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f496/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f498/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f49d/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f49e/lottie.json',
          ]
        },
      ),
      ShopItem(
        id: 'pack_party_time',
        name: 'باقة وقت الحفلة',
        imageUrl: '',
        price: 0,
        type: ShopItemType.sticker,
        metadata: {
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f973/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f389/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f38a/lottie.json',
          ]
        },
      ),
      ShopItem(
        id: 'pack_funny_express',
        name: 'باقة الضحك القصوى',
        imageUrl: '',
        price: 0,
        type: ShopItemType.sticker,
        metadata: {
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f923/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f602/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f61c/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f61d/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f92b/lottie.json',
          ]
        },
      ),
      ShopItem(
        id: 'pack_dance_party',
        name: 'باقة الرقص والحفلة',
        imageUrl: '',
        price: 0,
        type: ShopItemType.sticker,
        metadata: {
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f483/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f483_1f3fb/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f483_1f3fc/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f483_1f3fd/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f483_1f3fe/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f483_1f3ff/lottie.json',
          ]
        },
      ),
      ShopItem(
        id: 'pack_drama_sad',
        name: 'باقة الدراما',
        imageUrl: '',
        price: 0,
        type: ShopItemType.sticker,
        metadata: {
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f62d/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f622/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f97a/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f494/lottie.json',
          ]
        },
      ),
      ShopItem(
        id: 'pack_cool_vibes',
        name: 'باقة الأكشن والكول',
        imageUrl: '',
        price: 0,
        type: ShopItemType.sticker,
        metadata: {
          'stickers': [
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60e/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f911/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f525/lottie.json',
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f4a5/lottie.json',
          ]
        },
      ),
    ];
    return allPossiblePacks.where((p) => ownedIds.contains(p.id)).toList();
  }

  Widget _buildStickerGrid(List<Map<String, dynamic>> stickers, {required bool isEmoji}) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];
        return GestureDetector(
          onTap: () {
            final id = isEmoji ? sticker['id'] : sticker['url'];
            if (widget.onSelect != null) {
              widget.onSelect!(id);
            } else {
              context.read<VoiceRoomService>().sendSticker(id);
            }
            Navigator.pop(context);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: isEmoji 
                    ? AnimatedEmoji(sticker['emoji'] as AnimatedEmojiData, size: 40)
                    : (sticker['isLottie'] 
                        ? Lottie.network(
                            sticker['url'], 
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.style, color: Colors.white24, size: 30),
                          )
                        : Image.network(
                            sticker['url'], 
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.white24, size: 30),
                          )),
                ),
                const SizedBox(height: 4),
                Text(
                  isEmoji ? sticker['name'] : 'ملصق',
                  style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Tajawal'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
