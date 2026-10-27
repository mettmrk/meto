import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_room_service.dart';
import '../services/gift_service.dart';
import '../models/index.dart';
import 'package:lottie/lottie.dart';
import 'framed_avatar.dart';

class FrameSelectionBottomSheet extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final String? targetUserAvatar;

  const FrameSelectionBottomSheet({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserAvatar,
  });

  @override
  State<FrameSelectionBottomSheet> createState() =>
      _FrameSelectionBottomSheetState();
}

class _ProfileFrameItem {
  final String id;
  final String name;
  final String asset;
  final String color;

  _ProfileFrameItem({
    required this.id,
    required this.name,
    required this.asset,
    required this.color,
  });
}

class _AnimatedFrameItem {
  final String id;
  final String name;
  final String lottieUrl;
  final int price;

  _AnimatedFrameItem({
    required this.id,
    required this.name,
    required this.lottieUrl,
    required this.price,
  });
}

class _FrameSelectionBottomSheetState extends State<FrameSelectionBottomSheet>
    with SingleTickerProviderStateMixin {
  static int _lastSelectedIndex = 0;
  late TabController _tabController;
  String _selectedFrameId = 'frame_3';
  int _userDiamonds = 0;
  bool _isLoading = true;
  bool _sendToAll = false;

  final List<_ProfileFrameItem> _staticFrames = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _lastSelectedIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _lastSelectedIndex = _tabController.index;
    });
    _setupFrames();
    _loadBalance();
    _selectedFrameId = 'frame_3';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setupFrames() {
    // Basic Frames
    _staticFrames.add(
      _ProfileFrameItem(
        id: 'frame_3',
        name: 'تاج الإمبراطور',
        color: 'gold',
        asset: 'assets/images/frame_gold_crown.png',
      ),
    );
    _staticFrames.add(
      _ProfileFrameItem(
        id: 'frame_2',
        name: 'الماس السماوي',
        color: 'blue',
        asset: 'assets/images/frame_silver_sapphire.png',
      ),
    );
    _staticFrames.add(
      _ProfileFrameItem(
        id: 'frame_1',
        name: 'القبلية البرونزية',
        color: 'bronze',
        asset: 'assets/images/frame_bronze_tribal.png',
      ),
    );

    // Etar Frames
    final etarNames = [
      'أميرة الأرجوان',
      'غابة الزمرد',
      'قلب الياقوت',
      'حلقة السحر',
      'حلقة الطبيعة',
      'حلقة النار',
      'ملك الجليد',
      'تاج النور',
      'نجم الليل',
      'فارس الظلام',
      'بصمة الفخر',
      'عقد الزهور',
      'جوهرة البحر',
      'وهج الشمس',
      'سحاب الحلم',
      'روح الصحراء',
      'نبض الحياة',
      'تراث الأصالة',
    ];

    for (int i = 1; i <= 8; i++) {
      _staticFrames.add(
        _ProfileFrameItem(
          id: 'etar_$i',
          name: i <= etarNames.length ? etarNames[i - 1] : 'إطار $i',
          asset: 'assets/images/etar/$i.png',
          color: i % 2 == 0 ? 'cyan' : 'gold',
        ),
      );
    }
  }

  Future<void> _loadBalance() async {
    final service = Provider.of<VoiceRoomService>(context, listen: false);
    final myId = service.currentUserId;
    if (myId != null) {
      final diamonds = await GiftService().getUserDiamonds(myId);
      if (mounted) {
        setState(() {
          _userDiamonds = diamonds;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight * 0.55,
      decoration: const BoxDecoration(
        color: Color(0xFF071015), // Deep dark background from image
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _buildTopBar(),
          _buildCategoryTabs(),
          Expanded(
            child: StreamBuilder<List<ProfileFrame>>(
              stream: GiftService().getRoomFramesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  );
                }

                final allFrames = snapshot.hasData
                    ? snapshot.data!
                    : <ProfileFrame>[];

                // 1. Static Frames (Category: static)
                final staticFrames = allFrames.isNotEmpty
                    ? allFrames
                          .where(
                            (f) =>
                                f.category == 'static' ||
                                (!f.isAnimated && f.category == 'static'),
                          )
                          .toList()
                    : predefinedFrames;

                // 2. Animated Frames (Category: animated)
                final dynamicAnimated = allFrames
                    .where((f) => f.category == 'animated')
                    .map(
                      (f) => _AnimatedFrameItem(
                        id: f.id,
                        name: f.name,
                        lottieUrl: f.lottieUrl ?? f.image ?? '',
                        price: f.price,
                      ),
                    )
                    .toList();

                final animatedFrames = [
                  ..._predefinedAnimatedFrames(),
                  ...dynamicAnimated,
                ];

                // 3. Stickers (Category: sticker)
                final dynamicStickers = allFrames
                    .where((f) => f.category == 'sticker')
                    .map(
                      (f) => {
                        'id': f.lottieUrl ?? f.image ?? '',
                        'name': f.name,
                        'price': f.price,
                      },
                    )
                    .toList();

                final stickerReactions = [
                  ...[
                    {
                      'id':
                          'https://fonts.gstatic.com/s/e/notoemoji/latest/1f4a9/lottie.json',
                      'name': 'قرف',
                      'price': 150,
                    },
                    {
                      'id':
                          'https://fonts.gstatic.com/s/e/notoemoji/latest/1f47f/lottie.json',
                      'name': 'شيطان',
                      'price': 150,
                    },
                    {
                      'id':
                          'https://fonts.gstatic.com/s/e/notoemoji/latest/1f98b/lottie.json',
                      'name': 'فراشة',
                      'price': 150,
                    },
                    {
                      'id':
                          'https://fonts.gstatic.com/s/e/notoemoji/latest/1f339/lottie.json',
                      'name': 'وردة',
                      'price': 150,
                    },
                    {
                      'id':
                          'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60d/lottie.json',
                      'name': 'قلب',
                      'price': 150,
                    },
                    {
                      'id':
                          'https://fonts.gstatic.com/s/e/notoemoji/latest/1f525/lottie.json',
                      'name': 'شعلة',
                      'price': 150,
                    },
                    {
                      'id':
                          'https://fonts.gstatic.com/s/e/notoemoji/latest/1f929/lottie.json',
                      'name': 'نجوم',
                      'price': 150,
                    },
                    {
                      'id':
                          'https://fonts.gstatic.com/s/e/notoemoji/latest/1f60e/lottie.json',
                      'name': 'نظارة',
                      'price': 150,
                    },
                    {
                      'id':
                          'https://fonts.gstatic.com/s/e/notoemoji/latest/1f61b/lottie.json',
                      'name': 'لسان',
                      'price': 150,
                    },
                  ],
                  ...dynamicStickers,
                ];

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFramesGrid(staticFrames),
                    _buildAnimatedFramesGrid(animatedFrames),
                    _buildStickersGrid(stickerReactions),
                  ],
                );
              },
            ),
          ),
          _buildEnhancedBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Target User Avatar (Replaces Backpack)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundImage:
                  widget.targetUserAvatar != null &&
                      widget.targetUserAvatar!.isNotEmpty
                  ? (widget.targetUserAvatar!.startsWith('assets/')
                            ? AssetImage(widget.targetUserAvatar!)
                            : NetworkImage(widget.targetUserAvatar!))
                        as ImageProvider
                  : const AssetImage('assets/images/user_placeholder.png')
                        as ImageProvider,
            ),
          ),
          // Diamond Balance
          _buildBalanceChip(),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return TabBar(
      controller: _tabController,
      indicatorColor: Colors.white,
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white54,
      labelStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        fontFamily: 'Tajawal',
      ),
      dividerColor: Colors.transparent,
      tabs: const [
        Tab(text: 'أطار ثابت'),
        Tab(text: 'اطار متحرك'),
        Tab(text: 'ملصقـات'),
      ],
    );
  }

  /// Premium animated RING frames (circular around the avatar)
  List<_AnimatedFrameItem> _predefinedAnimatedFrames() {
    return [
      _AnimatedFrameItem(
        id: 'ring_fire',
        name: 'حلقة النار',
        lottieUrl: 'ring_fire',
        price: 150,
      ),
      _AnimatedFrameItem(
        id: 'ring_galaxy',
        name: 'حلقة المجرة',
        lottieUrl: 'ring_galaxy',
        price: 150,
      ),
      _AnimatedFrameItem(
        id: 'ring_gold',
        name: 'حلقة ذهبية',
        lottieUrl: 'ring_gold',
        price: 150,
      ),
      _AnimatedFrameItem(
        id: 'ring_diamond',
        name: 'حلقة الماس',
        lottieUrl: 'ring_diamond',
        price: 150,
      ),
      _AnimatedFrameItem(
        id: 'ring_ice',
        name: 'حلقة الجليد',
        lottieUrl: 'ring_ice',
        price: 150,
      ),
      _AnimatedFrameItem(
        id: 'ring_neon',
        name: 'حلقة نيون',
        lottieUrl: 'ring_neon',
        price: 150,
      ),
      _AnimatedFrameItem(
        id: 'ring_rainbow',
        name: 'حلقة قوس قزح',
        lottieUrl: 'ring_rainbow',
        price: 150,
      ),
      _AnimatedFrameItem(
        id: 'ring_rose',
        name: 'حلقة وردية',
        lottieUrl: 'ring_rose',
        price: 150,
      ),
      _AnimatedFrameItem(
        id: 'ring_lightning',
        name: 'حلقة صاعقة',
        lottieUrl: 'ring_lightning',
        price: 150,
      ),
      _AnimatedFrameItem(
        id: 'ring_emerald',
        name: 'حلقة زمرد',
        lottieUrl: 'ring_emerald',
        price: 150,
      ),
    ];
  }

  Widget _buildAnimatedFramesGrid(List<_AnimatedFrameItem> frames) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 25,
        childAspectRatio: 0.75,
      ),
      itemCount: frames.length,
      itemBuilder: (context, index) {
        final frame = frames[index];
        final isSelected = _selectedFrameId == frame.id;
        return _buildAnimatedFrameGridItem(frame, isSelected);
      },
    );
  }

  Widget _buildAnimatedFrameGridItem(
    _AnimatedFrameItem frame,
    bool isSelected,
  ) {
    final previewAvatarSize = 44.0;
    return GestureDetector(
      onTap: () => setState(() => _selectedFrameId = frame.id),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF14202A)
                    : const Color(0xFF0D1B2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.amberAccent.withValues(alpha: 0.8)
                      : Colors.white12,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.amberAccent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Live animated ring preview around a small avatar circle
                  AnimatedRingFrame(
                    ringId: frame.id,
                    avatarSize: previewAvatarSize,
                    child: Container(
                      width: previewAvatarSize,
                      height: previewAvatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image:
                              widget.targetUserAvatar != null &&
                                  widget.targetUserAvatar!.isNotEmpty
                              ? (widget.targetUserAvatar!.startsWith('assets/')
                                        ? AssetImage(widget.targetUserAvatar!)
                                        : NetworkImage(
                                            widget.targetUserAvatar!,
                                          ))
                                    as ImageProvider
                              : const AssetImage(
                                      'assets/images/user_placeholder.png',
                                    )
                                    as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            frame.name,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${frame.price}',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.diamond_rounded,
                color: Colors.cyanAccent,
                size: 9,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFramesGrid(List<ProfileFrame> frames) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 25,
        childAspectRatio: 0.75,
      ),
      itemCount: frames.length,
      itemBuilder: (context, index) {
        final frame = frames[index];
        final isSelected = _selectedFrameId == frame.id;
        return _buildFrameGridItem(frame, isSelected);
      },
    );
  }

  Widget _buildFrameGridItem(ProfileFrame frame, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFrameId = frame.id),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF14202A)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.blue.withValues(alpha: 0.6)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Avatar Preview
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image:
                            widget.targetUserAvatar != null &&
                                widget.targetUserAvatar!.isNotEmpty
                            ? (widget.targetUserAvatar!.startsWith('assets/')
                                      ? AssetImage(widget.targetUserAvatar!)
                                      : NetworkImage(widget.targetUserAvatar!))
                                  as ImageProvider
                            : const AssetImage(
                                    'assets/images/user_placeholder.png',
                                  )
                                  as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // The Frame (Remote Lottie, Remote Image, or Local Asset)
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: _buildFrameDisplay(frame),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Price Display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${frame.price}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.diamond_rounded,
                color: Colors.cyanAccent,
                size: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStickersGrid(List<Map<String, dynamic>> stickers) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 25,
        childAspectRatio: 0.75,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];
        final isSelected = _selectedFrameId == sticker['id'];
        return GestureDetector(
          onTap: () => setState(() => _selectedFrameId = sticker['id']),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF14202A)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.blue.withValues(alpha: 0.6)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: (sticker['id'] as String).contains('.json')
                          ? Lottie.network(
                              sticker['id']!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildStickerErrorPlaceholder(
                                  sticker['name'],
                                );
                              },
                            )
                          : Image.network(
                              sticker['id']!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildStickerErrorPlaceholder(
                                  sticker['name'],
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${sticker['price']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.diamond_rounded,
                    color: Colors.cyanAccent,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStickerErrorPlaceholder(String? name) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.emoji_emotions_outlined,
          color: Colors.white24,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          name ?? '',
          style: const TextStyle(color: Colors.white24, fontSize: 8),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFrameDisplay(ProfileFrame frame) {
    if (frame.lottieUrl != null && frame.lottieUrl!.isNotEmpty) {
      return Lottie.network(
        frame.lottieUrl!,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => _buildImageFrame(frame),
      );
    }
    return _buildImageFrame(frame);
  }

  Widget _buildImageFrame(ProfileFrame frame) {
    if (frame.image != null && frame.image!.startsWith('http')) {
      return Image.network(
        frame.image!,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) {
          if (frame.asset.isNotEmpty) {
            return Image.asset(frame.asset, fit: BoxFit.contain);
          }
          return const Icon(Icons.broken_image, color: Colors.white24);
        },
      );
    }
    if (frame.asset.isNotEmpty) {
      return Image.asset(
        frame.asset,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) =>
            const Icon(Icons.person_outline, color: Colors.white24),
      );
    }
    return const Icon(Icons.check_box_outline_blank, color: Colors.white24);
  }

  Widget _buildBalanceChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Darker chip bg
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_circle, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Text(
            '$_userDiamonds',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.diamond_rounded, color: Colors.cyanAccent, size: 18),
        ],
      ),
    );
  }

  Widget _buildEnhancedBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      decoration: const BoxDecoration(
        color: Color(0xFF0F171B),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LEFT SIDE: Send Button & Quantity
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Send Button
              GestureDetector(
                onTap: _isLoading ? null : _handleSend,
                child: Container(
                  height: 48,
                  width: 90, // Slightly narrower
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'إرسـال',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16, // Slightly smaller
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              // Quantity Selector
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Text(
                      '1',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),

          // RIGHT SIDE: User Target Info
          Flexible(
            child: GestureDetector(
              onTap: () => setState(() => _sendToAll = !_sendToAll),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _sendToAll
                      ? Colors.blue.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _sendToAll
                        ? Colors.blue.withValues(alpha: 0.4)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _sendToAll
                                ? 'الكل على المقاعد'
                                : widget.targetUserName,
                            style: TextStyle(
                              color: _sendToAll ? Colors.blue : Colors.white,
                              fontSize: 12, // Slightly smaller
                              fontWeight: _sendToAll
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontFamily: 'Tajawal',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Icon(
                            _sendToAll
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            color: _sendToAll ? Colors.blue : Colors.white54,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32, // Slightly smaller
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _sendToAll
                            ? Colors.blue.withValues(alpha: 0.2)
                            : Colors.transparent,
                        image: _sendToAll
                            ? null
                            : DecorationImage(
                                image:
                                    widget.targetUserAvatar != null &&
                                        widget.targetUserAvatar!.isNotEmpty
                                    ? (widget.targetUserAvatar!.startsWith(
                                                'assets/',
                                              )
                                              ? AssetImage(
                                                  widget.targetUserAvatar!,
                                                )
                                              : NetworkImage(
                                                  widget.targetUserAvatar!,
                                                ))
                                          as ImageProvider
                                    : const AssetImage(
                                            'assets/images/user_placeholder.png',
                                          )
                                          as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                      ),
                      child: _sendToAll
                          ? const Icon(
                              Icons.groups_rounded,
                              color: Colors.blue,
                              size: 18,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSend() async {
    final service = Provider.of<VoiceRoomService>(context, listen: false);

    // Calculate cost
    int unitPrice = 99; // Default
    bool isSticker = _selectedFrameId.startsWith('http');

    // Find the actual price from the lists
    if (isSticker) {
      // Find sticker price (stickerReactions is in build, so we might need to find it here or rely on specific logic)
      // Since all stickers now should have a consistent base price or we can just use 150 for 'All'
      unitPrice = 150;
    } else {
      // Try to find frame price
      try {
        final allFrames = predefinedFrames;
        final f = allFrames.firstWhere((f) => f.id == _selectedFrameId);
        unitPrice = f.price;
      } catch (_) {
        unitPrice = 99;
      }
    }

    int cost = unitPrice;
    if (_sendToAll) {
      if (isSticker) {
        // Special request: 150 diamonds for sending sticker to ALL
        cost = 150;
      } else {
        final occupiedSeatsCount = service.seats
            .where((s) => s != null && s['userId'] != null)
            .length;
        cost = unitPrice * occupiedSeatsCount;
      }

      if (cost == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يوجد مستخدمون لإرسال الإطارات لهم'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    // Check Balance
    if (_userDiamonds < cost) {
      if (mounted) {
        Navigator.pop(context); // Close sheet
        Navigator.pushNamed(context, '/wallet'); // Go to wallet
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_selectedFrameId.startsWith('http')) {
        // Handle sending sticker as a persistent frame-like effect (5 mins)
        if (_sendToAll) {
          await service.sendFrameToAllSeats(_selectedFrameId);
        } else {
          await service.sendFrame(widget.targetUserId, _selectedFrameId);
        }
      } else {
        // Handle regular frames
        if (_sendToAll) {
          await service.sendFrameToAllSeats(_selectedFrameId);
        } else {
          await service.sendFrame(widget.targetUserId, _selectedFrameId);
        }
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Handle race condition or other errors
        if (e.toString().contains('رصيد') || e.toString().contains('balance')) {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/wallet');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
