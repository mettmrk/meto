import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mmmm/widgets/framed_avatar.dart';
import 'safe_svga_player.dart';

import '../widgets/level_badge.dart';

class VVIPEntranceAnimation extends StatefulWidget {
  final String imageUrl;
  final String name;
  final String lottieUrl;
  final VoidCallback onComplete;

  const VVIPEntranceAnimation({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.lottieUrl,
    required this.onComplete,
  });

  @override
  State<VVIPEntranceAnimation> createState() => _VVIPEntranceAnimationState();
}

class _VVIPEntranceAnimationState extends State<VVIPEntranceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(2.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutQuart)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-2.0, 0.0),
        ).chain(CurveTween(curve: Curves.easeInOutQuart)),
        weight: 50,
      ),
    ]).animate(_controller);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutQuart),
      ),
    );

    // Initial start if not manual
    if (!widget.lottieUrl.toLowerCase().contains('.mp4')) {
      // Start lottie based animation shortly after init
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          if (widget.lottieUrl.toLowerCase().contains('.jpg') ||
              widget.lottieUrl.toLowerCase().contains('.png')) {
            // Static image entrance duration
            _controller.animateTo(
              0.5,
              duration: const Duration(milliseconds: 1300),
            );
            Future.delayed(const Duration(seconds: 4), () {
              if (mounted) {
                _controller
                    .animateTo(
                      1.0,
                      duration: const Duration(milliseconds: 1000),
                    )
                    .then((_) {
                      if (mounted) widget.onComplete();
                    });
              }
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isNetwork = widget.lottieUrl.startsWith('http');
    final bool isImage =
        widget.lottieUrl.toLowerCase().contains('.jpg') ||
        widget.lottieUrl.toLowerCase().contains('.jpeg') ||
        widget.lottieUrl.toLowerCase().contains('.png') ||
        widget.lottieUrl.toLowerCase().contains('.webp');
    final bool isSVGA = widget.lottieUrl.toLowerCase().contains('.svga');

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Stack(
          children: [
            // 1. The Entrance Effect (Lottie or Image)
            Positioned.fill(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: IgnorePointer(
                  child: isImage
                      ? Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            margin: const EdgeInsets.only(top: 240),
                            width: 360,
                            height: 120,
                            child: isNetwork
                                ? Image.network(
                                    widget.lottieUrl,
                                    fit: BoxFit.contain,
                                  )
                                : Image.asset(
                                    widget.lottieUrl,
                                    fit: BoxFit.contain,
                                  ),
                          ),
                        )
                      : (isSVGA
                            ? SafeSVGA(
                                resUrl: isNetwork ? widget.lottieUrl : null,
                                assetsName: !isNetwork ? widget.lottieUrl : null,
                                fit: BoxFit.contain,
                              )
                            : (isNetwork
                                  ? Lottie.network(
                                      widget.lottieUrl,
                                      fit: BoxFit.contain,
                                      onLoaded: (composition) {
                                        Future.delayed(
                                          const Duration(milliseconds: 500),
                                          () {
                                            if (mounted) _controller.forward();
                                          },
                                        );
                                        Future.delayed(composition.duration, () {
                                          if (mounted) widget.onComplete();
                                        });
                                      },
                                    )
                                  : Lottie.asset(
                                      widget.lottieUrl,
                                      fit: BoxFit.contain,
                                      onLoaded: (composition) {
                                        Future.delayed(
                                          const Duration(milliseconds: 500),
                                          () {
                                            if (mounted) _controller.forward();
                                          },
                                        );
                                        Future.delayed(composition.duration, () {
                                          if (mounted) widget.onComplete();
                                        });
                                      },
                                    ))),
                ),
              ),
            ),

            // 2. The User Info Overlay
            if (isImage)
              Positioned(
                top: 240,
                left: 0,
                right: 0,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Center(
                    child: SizedBox(
                      width: 360,
                      height: 120,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 18,
                            top: 31,
                            child: Container(
                              width: 58,
                              height: 58,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: FramedAvatar(
                                  userId: "",
                                  imageUrl: widget.imageUrl,
                                  radius: 29,
                                  useProfileFrameFallback: false,
                                  disableAnimation: true, // Prevent jitter
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 5,
                            right: 30,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Text(
                                widget.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Tajawal',
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 250),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade900.withValues(alpha: 0.8),
                            Colors.blueAccent.withValues(alpha: 0.9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 25,
                              backgroundImage: widget.imageUrl.startsWith('http')
                                  ? NetworkImage(widget.imageUrl)
                                  : AssetImage(widget.imageUrl) as ImageProvider,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "وصول ملكي",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                              Text(
                                widget.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          const LevelBadge(level: 10, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
