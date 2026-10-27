import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import 'framed_avatar.dart';

class HostEntranceBanner extends StatefulWidget {
  final String text;
  final String userId;
  final String? manualFrame;
  final VoidCallback onDismiss;

  const HostEntranceBanner({
    super.key,
    required this.text,
    required this.userId,
    this.manualFrame,
    required this.onDismiss,
  });

  @override
  State<HostEntranceBanner> createState() => _HostEntranceBannerState();
}

class _HostEntranceBannerState extends State<HostEntranceBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(-1.5, 0.0), // Start from left now
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _startAnimation();
  }

  void _startAnimation() async {
    await _controller.forward();
    await Future.delayed(const Duration(seconds: 4)); // Show for 4 seconds
    if (mounted) {
      await _controller.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
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
    final String name = widget.text;

    return SlideTransition(
      position: _offsetAnimation,
      child: Center(
        child: SizedBox(
          width: 300, // Adjusted for better aspect ratio
          height: 240, // Adjusted for better aspect ratio
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main Banner Background
              Positioned.fill(
                child: Image.asset(
                  'assets/images/in_admin/inadmin.png',
                  fit: BoxFit.contain,
                ),
              ),

              // Content Layout (Name - Centered in the purple area)
              Positioned(
                left: 110, // Move more to the right to clear the tiger
                right: 75,
                top: 95, // Center vertically in the banner strip
                child: Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
                  ),
                ),
              ),

              // Circular Avatar Container (Sits on 'tiger face' on the LEFT)
              Positioned(
                left: 8, // Perfectly aligned with the tiger face on the left
                top: 75, // Aligned vertically with the decorative frame
                child: StreamBuilder<User?>(
                  initialData: UserService().getUserSync(widget.userId),
                  stream: UserService().getUserStream(widget.userId),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    return Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                      child: FramedAvatar(
                        userId: widget.userId,
                        imageUrl: user?.profileImage,
                        radius: 25, // 50px diameter
                        manualFrame: widget.manualFrame,
                        useProfileFrameFallback: false,
                        disableAnimation: true, // Disable heavy avatar anim during entry slide transition
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
