import 'package:flutter/material.dart';
import 'framed_avatar.dart';

class OwnerEntranceBanner extends StatefulWidget {
  final String text;
  final String userId;
  final String?
  imageUrl; // NEW: Pass image URL directly to avoid StreamBuilder delay
  final String? manualFrame;
  final String bannerType; // 'owner', 'mod', or 'deputy'
  final VoidCallback onDismiss;

  const OwnerEntranceBanner({
    super.key,
    required this.text,
    required this.userId,
    this.imageUrl,
    this.manualFrame,
    this.bannerType = 'owner',
    required this.onDismiss,
  });

  @override
  State<OwnerEntranceBanner> createState() => _OwnerEntranceBannerState();
}

class _OwnerEntranceBannerState extends State<OwnerEntranceBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(
            3.0,
            0.0,
          ), // Increased from 2.0 to start further off-screen
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-3.0, 0.0), // Adjusted to match entry
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50,
      ),
    ]).animate(_controller);

    _startAnimation();
  }

  void _startAnimation() async {
    // 1. Slide In (First half of TweenSequence)
    await _controller.animateTo(
      0.5,
      duration: const Duration(milliseconds: 1300),
    );

    // 2. Stay for 4 seconds
    await Future.delayed(const Duration(seconds: 4));

    // 3. Slide Out (Second half of TweenSequence)
    if (mounted) {
      await _controller.animateTo(
        1.0,
        duration: const Duration(milliseconds: 1000),
      );
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String nameText = widget.text.trim();
    // Clean the text to get only the name
    String cleanName = nameText
        .replaceAll(' دخل الغرفة', '')
        .replaceAll(' دخل', '')
        .trim();

    String displayText = cleanName;
    if (widget.bannerType == 'mod') {
      displayText = 'المشرف $cleanName';
    } else if (widget.bannerType == 'deputy') {
      displayText = 'النائب $cleanName';
    }
    String _getAssetPath() {
      switch (widget.bannerType) {
        case 'mod':
        case 'deputy':
          return 'assets/images/in_admin/mshrf.png';
        case 'owner':
        default:
          return 'assets/images/in_admin/inadmin.png';
      }
    }

    return SlideTransition(
      position: _slideAnimation,
      child: Center(
        child: SizedBox(
          width: 400, // Increased from 360
          height: 140, // Increased from 120
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Background Image
              Positioned.fill(
                child: Image.asset(
                  _getAssetPath(),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              // 2. Name in the ribbon
              Positioned(
                left: 10,
                right: 50,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text(
                    displayText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10, // Slightly larger
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Tajawal',
                      overflow: TextOverflow.ellipsis,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
              // 3. Avatar in the circle (Adjusted position and size)
              Positioned(
                left: 48, // Adjusted to move right
                top: 48, // Adjusted to center vertically in larger banner
                child: Container(
                  width: 44, // Decreased from 53
                  height: 44, // Decreased from 53
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFD700).withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: FramedAvatar(
                      userId: widget.userId,
                      imageUrl: widget.imageUrl,
                      radius: 22,
                      useProfileFrameFallback: false, // Cleaner look for banner
                      disableAnimation: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
