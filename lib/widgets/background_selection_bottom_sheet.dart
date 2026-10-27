import 'package:flutter/material.dart';
import '../models/index.dart';
import '../services/gift_service.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/shop_service.dart';

class BackgroundSelectionBottomSheet extends StatefulWidget {
  final String roomId;
  final String currentBackgroundId;

  const BackgroundSelectionBottomSheet({
    super.key,
    required this.roomId,
    required this.currentBackgroundId,
  });

  @override
  State<BackgroundSelectionBottomSheet> createState() =>
      _BackgroundSelectionBottomSheetState();
}

class _BackgroundSelectionBottomSheetState
    extends State<BackgroundSelectionBottomSheet> {
  String? _selectedId;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentBackgroundId;
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF0F171B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: StreamBuilder<List<RoomBackground>>(
        stream: GiftService().getBackgroundsStream(),
        builder: (context, bgSnapshot) {
          return StreamBuilder<List<RoomBackground>>(
            stream: ShopService().getOwnedBackgroundsStream(userId),
            builder: (context, ownedSnapshot) {
              final ownedIds = (ownedSnapshot.data ?? [])
                  .map((bg) => bg.id)
                  .toSet();

              // Combine predefined, Firestore, and Owned (Shop) backgrounds
              final List<RoomBackground> allBackgrounds = [
                ...predefinedBackgrounds,
                ...(bgSnapshot.data ?? []),
                ...(ownedSnapshot.data ?? []),
              ];

              // Remove duplicates by ID
              final seenIds = <String>{};
              final uniqueBackgrounds = allBackgrounds.where((bg) {
                return seenIds.add(bg.id);
              }).toList();

              final selectedBg = uniqueBackgrounds.firstWhere(
                (bg) => bg.id == _selectedId,
                orElse: () => uniqueBackgrounds.first,
              );

              final bool isOwnedSelected = ownedIds.contains(selectedBg.id);

              return Column(
                children: [
                  _buildHeader(),
                  _buildDiamondBalance(),
                  Expanded(
                    child: uniqueBackgrounds.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد خلفيات متاحة',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 25,
                                  childAspectRatio: 0.65,
                                ),
                            itemCount: uniqueBackgrounds.length,
                            itemBuilder: (context, index) {
                              final bg = uniqueBackgrounds[index];
                              final isSelected = _selectedId == bg.id;
                              final isOwned = ownedIds.contains(bg.id);
                              return _buildBackgroundItem(
                                bg,
                                isSelected,
                                isOwned,
                              );
                            },
                          ),
                  ),
                  _buildBottomBar(selectedBg, isOwnedSelected),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDiamondBalance() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<int>(
      stream: Stream.fromFuture(GiftService().getUserDiamonds(userId)),
      builder: (context, snapshot) {
        final diamonds = snapshot.data ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'رصيدك:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontFamily: 'Tajawal',
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.diamond, size: 16, color: Colors.blueAccent),
              const SizedBox(width: 4),
              Text(
                '$diamonds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'خلفيات الغرفة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundItem(
    RoomBackground bg,
    bool isSelected,
    bool isOwned,
  ) {
    final isFree =
        bg.price == 0 && !isOwned; // Only true if it's genuinely free for all
    // Determine theme color for selection highlighting
    Color themeColor = Colors.orangeAccent;
    if (bg.id == 'default_cosmic') themeColor = const Color(0xFF00BFA5);
    if (bg.id == 'royal_oasis') themeColor = const Color(0xFFCE93D8);
    if (bg.id == 'crystal_glow') themeColor = const Color(0xFF5C6BC0);
    if (bg.id == 'royal_horizon') themeColor = const Color(0xFFFFAB40);

    final isApplied = bg.id == widget.currentBackgroundId;
    return GestureDetector(
      onTap: () => setState(() => _selectedId = bg.id),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected ? themeColor : Colors.white10,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: themeColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                         ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildPreview(bg),
                    if (bg.isNew)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.3),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Text(
                            'جديد',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      ),
                    if (isApplied)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'نشط',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    if (isSelected)
                      Container(
                        color: Colors.black38,
                        child: Center(
                          child: Icon(
                            Icons.check_circle,
                            color: themeColor,
                            size: 28,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            bg.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? themeColor : Colors.white,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 4),
          if (!isOwned) // Only show pricing/free label if NOT owned
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isFree) ...[
                  const Icon(Icons.diamond, size: 10, color: Colors.blueAccent),
                  const SizedBox(width: 3),
                ],
                Text(
                  isFree ? 'مجاني' : '${bg.price}',
                  style: TextStyle(
                    color: isFree ? Colors.greenAccent : Colors.blueAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          else
            const Text(
              'مملوك',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview(RoomBackground bg) {
    if (bg.id == 'default_cosmic') {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF004D40), Color(0xFF000000)],
          ),
        ),
      );
    }

    if (bg.id == 'royal_oasis') {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5E35B1), Color(0xFF120B38)],
          ),
        ),
      );
    }

    if (bg.id == 'crystal_glow') {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E88E5), Color(0xFF0A192F)],
          ),
        ),
      );
    }

    if (bg.id == 'royal_horizon') {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF004B91), Color(0xFF00152D)],
          ),
        ),
      );
    }

    if (bg.image.isEmpty) return Container(color: Colors.grey.shade900);

    if (bg.lottieUrl != null && bg.lottieUrl!.isNotEmpty) {
      return Lottie.network(
        bg.lottieUrl!,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(color: Colors.grey.shade900),
      );
    }

    if (bg.image.startsWith('http')) {
      return Image.network(
        bg.image,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(color: Colors.grey.shade900),
      );
    }

    return Image.asset(
      bg.image,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(color: Colors.grey.shade900),
    );
  }

  Widget _buildBottomBar(RoomBackground selectedBg, bool isOwned) {
    final bool isAlreadyApplied = _selectedId == widget.currentBackgroundId;
    final bool isFree =
        selectedBg.price == 0 ||
        isOwned; // Owned backgrounds are treated as free

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
      decoration: BoxDecoration(
        color: const Color(0xFF071015),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _isUpdating || isAlreadyApplied
                  ? null
                  : () => _handleAction(selectedBg, isOwned),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 54,
                decoration: BoxDecoration(
                  gradient: isAlreadyApplied
                      ? LinearGradient(
                          colors: [Colors.grey.shade800, Colors.grey.shade900],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFFF8C00), Color(0xFFFF4500)],
                        ),
                  borderRadius: BorderRadius.circular(27),
                  boxShadow: isAlreadyApplied
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.orange.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: _isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isAlreadyApplied
                            ? 'مطبق حالياً'
                            : (isFree
                                  ? 'استخدام الخلفية'
                                  : 'تفعيل بالماس (${selectedBg.price})'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(RoomBackground bg, bool isOwned) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isUpdating = true);
    try {
      if (bg.price > 0 && !isOwned) {
        await GiftService().purchaseRoomBackground(
          userId: userId,
          roomId: widget.roomId,
          background: bg,
        );
      } else {
        // Use the image URL as the ID if it's a dynamic/remote asset
        final idToSet = bg.image.startsWith('http') ? bg.image : bg.id;
        await GiftService().setRoomBackground(widget.roomId, idToSet);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل العملية: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
