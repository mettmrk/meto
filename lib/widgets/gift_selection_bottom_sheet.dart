import 'package:flutter/material.dart';
import 'dart:async' as meto_async;
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'safe_svga_player.dart';
import '../models/index.dart';
import '../models/task_model.dart';
import '../services/index.dart';
import '../screens/store_screen.dart';

class GiftSelectionBottomSheet extends StatefulWidget {
  final String? receiverId;
  final String? receiverName;
  final String? postId;
  final String? roomId;
  final String senderId;
  final String senderName;
  final String? senderProfileImage;

  const GiftSelectionBottomSheet({
    super.key,
    this.receiverId,
    this.receiverName,
    this.postId,
    this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderProfileImage,
  });

  @override
  State<GiftSelectionBottomSheet> createState() =>
      _GiftSelectionBottomSheetState();
}

class _GiftSelectionBottomSheetState extends State<GiftSelectionBottomSheet>
    with SingleTickerProviderStateMixin {
  final GiftService _giftService = GiftService();
  int _userDiamonds = 0;
  int _userMeto = 0;
  int _userGold = 0;
  bool _isLoading = true;
  Gift? _selectedGift;
  late TabController _tabController;
  int _quantity = 1;
  bool _sendToAll = false;
  late Stream<List<Gift>> _giftsStream;

  String? _currentReceiverId;
  String? _currentReceiverName;

  final List<int> _suggestedQuantities = [1, 5, 10, 51, 52, 99, 188, 520, 1314];

  @override
  void initState() {
    super.initState();
    _currentReceiverId = widget.receiverId;
    _currentReceiverName = widget.receiverName;

    // Prevent self-gifting: if the pre-selected receiver is the sender, clear it
    if (_currentReceiverId != null && _currentReceiverId == widget.senderId) {
      _currentReceiverId = null;
      _currentReceiverName = null;
    }

    _tabController = TabController(
      length: GiftCategory.values.length,
      vsync: this,
    );
    _giftsStream = _giftService.getGiftsStream();
    _loadUserBalance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  meto_async.Future<void> _loadUserBalance() async {
    try {
      final diamonds = await _giftService.getUserDiamonds(widget.senderId);
      final meto = await _giftService.getUserMeto(widget.senderId);
      final gold = await _giftService.getUserGold(widget.senderId);
      if (mounted) {
        setState(() {
          _userDiamonds = diamonds;
          _userMeto = meto;
          _userGold = gold;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  meto_async.Future<void> _sendGift() async {
    if (_selectedGift == null) return;

    // Prevent self-gifting
    if (!_sendToAll &&
        _currentReceiverId != null &&
        _currentReceiverId == widget.senderId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكنك إرسال هدية لنفسك'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final service = Provider.of<VoiceRoomService>(context, listen: false);
    int totalQuantity = _quantity;

    if (_sendToAll) {
      final allUserIds = service.roomUsers
          .where((u) => u.uid != widget.senderId)
          .map((u) => u.uid)
          .toList();

      if (allUserIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد أشخاص في الغرفة لإرسال الهدايا لهم'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      totalQuantity = _quantity * allUserIds.length;
    }

    final Currency giftCurrency = _selectedGift!.currency;
    final int userBalance = giftCurrency == Currency.diamonds
        ? _userDiamonds
        : (giftCurrency == Currency.gold ? _userGold : _userMeto);

    final String currencyName = giftCurrency == Currency.diamonds
        ? 'الماس'
        : (giftCurrency == Currency.gold ? 'ذهب' : 'عملة ميتو');

    if (userBalance < (_selectedGift!.price * totalQuantity)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('رصيدك من $currencyName غير كافٍ'),
          backgroundColor: Colors.orange,
        ),
      );
      if (giftCurrency == Currency.diamonds) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoreScreen(
              userId: widget.senderId,
              initialTab: 1, // Diamonds tab
            ),
          ),
        );
      } else {
        // Redirection for Meto or Gold if needed
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoreScreen(
              userId: widget.senderId,
              initialTab: giftCurrency == Currency.meto ? 0 : 2,
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (widget.roomId != null) {
        if (_sendToAll) {
          final allUserIds = service.roomUsers
              .where((u) => u.uid != widget.senderId)
              .map((u) => u.uid)
              .toList();

          await _giftService.sendRoomGiftToAll(
            senderId: widget.senderId,
            occupiedUserIds: allUserIds,
            roomId: widget.roomId!,
            gift: _selectedGift!,
            senderName: widget.senderName,
            senderProfileImage: widget.senderProfileImage,
            quantityPerUser: _quantity,
          );
        } else {
          if (_currentReceiverId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('الرجاء اختيار مستلم أولاً'),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() => _isLoading = false);
            return;
          }
          await _giftService.sendRoomGift(
            senderId: widget.senderId,
            receiverId: _currentReceiverId!,
            roomId: widget.roomId!,
            gift: _selectedGift!,
            senderName: widget.senderName,
            senderProfileImage: widget.senderProfileImage,
            quantity: _quantity,
          );
        }
      } else if (widget.postId != null) {
        if (_currentReceiverId == null) {
          setState(() => _isLoading = false);
          return;
        }
        await _giftService.sendGift(
          senderId: widget.senderId,
          receiverId: _currentReceiverId!,
          postId: widget.postId!,
          gift: _selectedGift!,
          senderName: widget.senderName,
          senderProfileImage: widget.senderProfileImage,
        );
      }
      if (mounted) {
        // مهمة: إرسال هدية
        TaskService().incrementTaskProgress(widget.senderId, TaskType.sendGift);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (e.toString().contains('رصيد') || e.toString().contains('balance')) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoreScreen(
                userId: widget.senderId,
                initialTab: _selectedGift?.currency == Currency.diamonds
                    ? 1
                    : (_selectedGift?.currency == Currency.gold ? 2 : 0),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height:
          MediaQuery.of(context).size.height *
          0.65, // Slightly taller for better spacing
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A).withValues(alpha: 0.95),
            const Color(0xFF020617),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
            blurRadius: 40,
            spreadRadius: -10,
            offset: const Offset(0, -10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 25,
            spreadRadius: 5,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Handle Bar
          Container(
            width: 45,
            height: 4.5,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white24, Colors.white10],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header with Balance - Modernized
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: _buildModernBalanceChip(Currency.diamonds)),
                const SizedBox(width: 10),
                Flexible(child: _buildModernBalanceChip(Currency.meto)),
                const SizedBox(width: 10),
                Flexible(child: _buildModernBalanceChip(Currency.gold)),
              ],
            ),
          ),

          // Tab Bar
          _buildTabBar(),

          const SizedBox(height: 12),

          // Gift Grid
          Expanded(
            child: StreamBuilder<List<Gift>>(
              stream: _giftsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00E5FF),
                      strokeWidth: 2,
                    ),
                  );
                }

                final gifts = snapshot.data ?? [];

                if (gifts.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد هدايا حالياً',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 16,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  );
                }

                return TabBarView(
                  controller: _tabController,
                  children: GiftCategory.values.map((cat) {
                    final categoryGifts = gifts
                        .where((g) => g.category == cat)
                        .toList();
                    return _buildGiftGrid(categoryGifts, cat);
                  }).toList(),
                );
              },
            ),
          ),

          // Bottom Action Area
          _buildEnhancedSendArea(),
        ],
      ),
    );
  }

  String _formatBalance(int balance) {
    if (balance >= 1000000) {
      double value = balance / 1000000;
      return '${value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
    } else if (balance >= 10000) {
      double value = balance / 1000;
      return '${value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k';
    }
    return balance.toString();
  }

  Widget _buildModernBalanceChip(Currency currency) {
    final bool isDiamonds = currency == Currency.diamonds;
    final bool isGold = currency == Currency.gold;

    final int balance = isDiamonds
        ? _userDiamonds
        : (isGold ? _userGold : _userMeto);

    final IconData icon = isDiamonds
        ? Icons.diamond_rounded
        : (isGold ? Icons.stars_rounded : Icons.token_rounded);

    final Color color = isDiamonds
        ? const Color(0xFF00E5FF)
        : (isGold ? Colors.amber : Colors.greenAccent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _formatBalance(balance),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontFamily: 'Tajawal',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        physics: const BouncingScrollPhysics(),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: Colors.black,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal',
          fontSize: 13,
        ),
        unselectedLabelColor: Colors.white60,
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontFamily: 'Tajawal',
          fontSize: 13,
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 20),
        tabs: const [
          Tab(text: 'شائع'),
          Tab(text: 'فاخر'),
          Tab(text: 'مميز'),
          Tab(text: 'مؤثرات'),
        ],
      ),
    );
  }

  Widget _buildGiftGrid(List<Gift> filteredGifts, GiftCategory category) {
    return GridView.builder(
      key: PageStorageKey('gift_grid_${category.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: filteredGifts.length,
      itemBuilder: (context, index) {
        final gift = filteredGifts[index];
        final isSelected = _selectedGift?.id == gift.id;

        return GestureDetector(
          onTap: () => setState(() => _selectedGift = gift),
          child: Column(
            children: [
              // 1. The Card (Image)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00E5FF).withOpacity(0.15)
                        : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00E5FF)
                          : Colors.white.withOpacity(0.05),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: _buildGiftImage(gift),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // 2. Name
              Text(
                gift.name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(isSelected ? 1.0 : 0.7),
                  fontFamily: 'Tajawal',
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // 3. Price
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatBalance(gift.price),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: gift.currency == Currency.gold
                          ? Colors.amber
                          : (gift.currency == Currency.diamonds
                                ? const Color(0xFF00E5FF)
                                : Colors.greenAccent),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    gift.currency == Currency.gold
                        ? Icons.stars_rounded
                        : (gift.currency == Currency.diamonds
                              ? Icons.diamond_rounded
                              : Icons.token_rounded),
                    color: gift.currency == Currency.gold
                        ? Colors.amber
                        : (gift.currency == Currency.diamonds
                              ? const Color(0xFF00E5FF)
                              : Colors.greenAccent),
                    size: 13,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGiftImage(Gift gift) {
    // 1. Check if we have an animation
    final bool hasAnimation =
        gift.lottieUrl != null && gift.lottieUrl!.isNotEmpty;
    final bool isMp4 =
        hasAnimation && gift.lottieUrl!.toLowerCase().contains('.mp4');

    if (hasAnimation && !isMp4) {
      // Show ONLY the animation preview
      return IgnorePointer(
        child: gift.lottieUrl!.toLowerCase().contains('.svga')
            ? SafeSVGA(resUrl: gift.lottieUrl!, fit: BoxFit.contain)
            : (gift.lottieUrl!.startsWith('assets/')
                  ? Lottie.asset(
                      gift.lottieUrl!,
                      fit: BoxFit.contain,
                      repeat: true,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackIcon(gift),
                    )
                  : Lottie.network(
                      gift.lottieUrl!,
                      fit: BoxFit.contain,
                      repeat: true,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackIcon(gift),
                    )),
      );
    }

    // 2. No animation? Show the static image
    final String? imageUrl = (gift.image?.startsWith('http') ?? false)
        ? gift.image
        : (gift.icon.startsWith('http') ? gift.icon : null);

    if (gift.image != null && gift.image!.startsWith('assets/')) {
      return Image.asset(
        gift.image!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(gift),
      );
    }

    return imageUrl != null
        ? Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _buildFallbackIcon(gift),
          )
        : _buildFallbackIcon(gift);
  }

  Widget _buildFallbackIcon(Gift gift) {
    // If icon is an emoji, show it, otherwise show a default gift icon
    if (gift.icon.length <= 2) {
      return Text(gift.icon, style: const TextStyle(fontSize: 36));
    }
    return const Icon(Icons.card_giftcard, size: 40, color: Colors.amber);
  }

  Widget _buildEnhancedSendArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 25),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.5),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          // Send Button (Left) - Modern with glow
          Container(
            height: 48,
            width: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: (_selectedGift != null)
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: (_isLoading || _selectedGift == null)
                  ? null
                  : _sendGift,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'إرسال',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        fontFamily: 'Tajawal',
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Quantity Selector
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _quantity,
                dropdownColor: const Color(0xFF1E293B),
                icon: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Colors.white70,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                items: _suggestedQuantities.map((q) {
                  return DropdownMenuItem(value: q, child: Text(q.toString()));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _quantity = val);
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Recipient Selector
          if (widget.roomId != null)
            Expanded(
              child: GestureDetector(
                onTap: _sendToAll ? null : _showUserSelectionSheet,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _sendToAll
                          ? const Color(0xFF00E5FF).withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _sendToAll
                            ? Icons.groups_rounded
                            : Icons.person_rounded,
                        color: _sendToAll
                            ? const Color(0xFF00E5FF)
                            : Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _sendToAll ? 'الكل' : _currentReceiverName ?? 'اختر',
                          style: TextStyle(
                            color: _sendToAll
                                ? const Color(0xFF00E5FF)
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Colors.white60,
                        size: 20,
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

  void _showUserSelectionSheet() {
    if (widget.roomId == null) return;

    final service = Provider.of<VoiceRoomService>(context, listen: false);
    // Get all users in the room except me (self-gifting prevention)
    final allUsers = service.roomUsers
        .where((u) => u.uid != service.currentUserId)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'اختر المستلم',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              // Option to send to all seated users
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.groups_rounded, color: Colors.white),
                ),
                title: const Text(
                  'للجميع',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                onTap: () {
                  setState(() {
                    _sendToAll = true;
                    _currentReceiverId = 'all';
                    _currentReceiverName = 'للجميع';
                  });
                  Navigator.pop(context);
                },
              ),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),
              if (allUsers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    'لا يوجد أعضاء آخرين في الغرفة',
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: allUsers.length,
                    itemBuilder: (context, index) {
                      final user = allUsers[index];
                      return ListTile(
                        leading: Builder(
                          builder: (context) {
                            if (user.profileImage == null ||
                                user.profileImage!.isEmpty) {
                              return const CircleAvatar(
                                backgroundImage: AssetImage(
                                  'assets/images/user_placeholder.png',
                                ),
                              );
                            }
                            String imagePath = user.profileImage!;
                            if (imagePath.startsWith('file:///')) {
                              imagePath = imagePath.replaceFirst(
                                'file:///',
                                '',
                              );
                            }

                            return CircleAvatar(
                              backgroundImage: imagePath.startsWith('http')
                                  ? NetworkImage(imagePath)
                                  : AssetImage(imagePath) as ImageProvider,
                            );
                          },
                        ),
                        title: Text(
                          user.nickname ?? user.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _sendToAll = false;
                            _currentReceiverId = user.uid;
                            _currentReceiverName =
                                user.nickname ?? user.username;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
