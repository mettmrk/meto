import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/index.dart';
import '../models/gift_model.dart';

class PostGiftsSummaryBottomSheet extends StatefulWidget {
  final String postId;
  const PostGiftsSummaryBottomSheet({super.key, required this.postId});

  @override
  State<PostGiftsSummaryBottomSheet> createState() =>
      _PostGiftsSummaryBottomSheetState();
}

class _PostGiftsSummaryBottomSheetState
    extends State<PostGiftsSummaryBottomSheet> {
  final GiftService _giftService = GiftService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _gifts = [];
  int _totalDiamonds = 0;
  int _totalMeto = 0;

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts() async {
    final gifts = await _giftService.getPostGifts(widget.postId);
    int diamonds = 0;
    int meto = 0;

    for (var gift in gifts) {
      final earnings = (gift['receiverEarnings'] as num? ?? 0).toInt();
      final currency = gift['currency'] as String? ?? 'coins';

      if (currency == 'diamonds') {
        diamonds += earnings;
      } else if (currency == 'meto') {
        meto += earnings;
      }
    }

    if (mounted) {
      setState(() {
        _gifts = gifts;
        _totalDiamonds = diamonds;
        _totalMeto = meto;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.6, // Slightly taller for more content
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0E).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // ── Background Decorative Blobs ──
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.cyanAccent.withValues(alpha: 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: 100,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withValues(alpha: 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // ── Main Layout ──
          Column(
            children: [
              const SizedBox(height: 12),
              // Drag Indicator
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.white24, Colors.white10],
                  ),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 25),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'هدايا المنشور',
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'إجمالي الهدايا المستلمة: ${_gifts.length}',
                          style: GoogleFonts.tajawal(
                            fontSize: 10,
                            color: Colors.white38,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Summary Stats Card (Premium Design)
              if (_totalDiamonds > 0 || _totalMeto > 0) _buildSummaryStatBar(),

              const SizedBox(height: 20),

              // List of Gifts
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _gifts.isEmpty
                    ? _buildEmptyState()
                    : _buildGiftsList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF14141A),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(
              'الألماس',
              _totalDiamonds,
              Colors.cyanAccent,
              icon: Icons.diamond,
            ),
            _buildDivider(),
            _buildStatItem(
              'ميتو',
              _totalMeto,
              const Color.fromARGB(255, 53, 226, 82),
              imagePath: 'assets/images/coinsmeto.png',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 30, width: 1, color: Colors.white10);
  }

  Widget _buildStatItem(String label, int value, Color color,
      {IconData? icon, String? imagePath}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null)
              Image.asset(imagePath, width: 14, height: 14)
            else if (icon != null)
              Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Text(
              intl.NumberFormat.compact().format(value),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.tajawal(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildGiftsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _gifts.length,
      itemBuilder: (context, index) {
        final gift = _gifts[index];
        final timestamp = gift['timestamp'] as Timestamp?;
        final timeStr = timestamp != null
            ? intl.DateFormat('hh:mm a').format(timestamp.toDate())
            : '--:--';

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (index * 50)),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: _buildGiftCard(gift, timeStr),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGiftCard(Map<String, dynamic> gift, String timeStr) {
    final bool isDiamond = gift['currency'] == 'diamonds';
    final bool isMeto = gift['currency'] == 'meto';
    final String? senderImage = gift['senderProfileImage'] as String?;

    Color accentColor = isDiamond
        ? Colors.cyanAccent
        : (isMeto ? const Color.fromARGB(255, 58, 207, 44) : Colors.amber);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Sender Avatar with Ring
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                backgroundImage: senderImage != null && senderImage.isNotEmpty
                    ? NetworkImage(senderImage)
                    : null,
                child: senderImage == null || senderImage.isEmpty
                    ? const Icon(Icons.person, color: Colors.white24, size: 20)
                    : null,
              ),
            ],
          ),
          const SizedBox(width: 15),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gift['giftName'] ?? 'هدية',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'بواسطة: ',
                      style: GoogleFonts.tajawal(
                        color: Colors.white24,
                        fontSize: 11,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        gift['senderName'] ?? 'مستخدم',
                        style: GoogleFonts.tajawal(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: GoogleFonts.outfit(
                    color: Colors.white12,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Gift Visual Preview
          _buildGiftPreviewWidget(gift),

          const SizedBox(width: 12),

          // Earning Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+${gift['receiverEarnings']}',
                  style: GoogleFonts.outfit(
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMeto)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Image.asset('assets/images/coinsmeto.png', width: 8, height: 8),
                      ),
                    Text(
                      isDiamond ? 'Diamond' : (isMeto ? 'Meto' : 'Gold'),
                      style: GoogleFonts.outfit(
                        color: accentColor.withValues(alpha: 0.5),
                        fontSize: 6,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
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
  }

  Widget _buildGiftPreviewWidget(Map<String, dynamic> giftMap) {
    // Try to find the gift definition to use better rendering
    final giftId = giftMap['giftId'];
    final giftDef = predefinedGifts.firstWhere(
      (g) => g.id == giftId,
      orElse: () => Gift(
        id: giftId ?? '',
        name: giftMap['giftName'] ?? '',
        icon: giftMap['giftIcon'] ?? '🎁',
        price: 0,
        image: (giftMap['giftIcon']?.toString().startsWith('http') ?? false)
            ? giftMap['giftIcon']
            : null,
      ),
    );

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        shape: BoxShape.circle,
      ),
      child: _buildGiftImage(giftDef),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.02),
            ),
            child: Icon(
              Icons.redeem_rounded,
              size: 50,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'لا توجد هدايا بعد',
            style: GoogleFonts.tajawal(
              color: Colors.white38,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'كن أول من يرسل هدية لصاحب المنشور!',
            style: GoogleFonts.tajawal(color: Colors.white12, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: Colors.cyanAccent,
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildGiftImage(Gift gift) {
    if (gift.lottieUrl != null && gift.lottieUrl!.isNotEmpty && !gift.lottieUrl!.toLowerCase().contains('.mp4')) {
      return Lottie.network(
        gift.lottieUrl!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            _buildStaticGiftImage(gift),
      );
    }
    return _buildStaticGiftImage(gift);
  }

  Widget _buildStaticGiftImage(Gift gift) {
    if (gift.image != null && gift.image!.startsWith('http')) {
      return Image.network(
        gift.image!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildGiftIcon(gift),
      );
    }
    if (gift.image != null && gift.image!.startsWith('assets')) {
      return Image.asset(
        gift.image!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildGiftIcon(gift),
      );
    }
    return _buildGiftIcon(gift);
  }

  Widget _buildGiftIcon(Gift gift) {
    return Center(child: Text(gift.icon, style: const TextStyle(fontSize: 20)));
  }
}
