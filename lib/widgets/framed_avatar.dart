import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/index.dart';
import '../services/gift_service.dart';
import 'package:lottie/lottie.dart';
import 'safe_svga_player.dart';
import 'circular_video_player.dart';

import 'package:cached_network_image/cached_network_image.dart';

class FramedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? userId;
  final Color? borderColor;
  final double borderWidth;
  final String? manualFrame; // For temporary gift frames
  final String? manualFrameId; // For passing a permanent frame ID directly
  final bool useProfileFrameFallback;
  final bool disableAnimation;
  final bool disableFrame;
  final String? manualAnimatedPhoto; // For previewing animated photos
  final Widget? overlay;
  final bool fallbackBorderWhenNoFrame;


  const FramedAvatar({
    super.key,
    this.imageUrl,
    required this.radius,
    this.userId,
    this.borderColor,
    this.borderWidth = 0,
    this.manualFrame,
    this.manualFrameId,
    this.useProfileFrameFallback = true,
    this.disableAnimation = false,
    this.disableFrame = false,
    this.manualAnimatedPhoto,
    this.overlay,
    this.fallbackBorderWhenNoFrame = false,
  });


  /// Maps frame IDs to asset paths
  static String getFrameAsset(String frameId) {
    if (frameId.isEmpty || _isInvalidPath(frameId)) {
      return 'assets/images/frames/frame_3.png';
    }

    // Accept full/relative paths that contain an assets segment (e.g. "meto/assets/images/rom.png")
    final normalized = frameId.replaceAll('\\', '/');
    final idx = normalized.indexOf('assets/');
    if (idx != -1) {
      return normalized.substring(idx);
    }

    if (frameId.startsWith('assets/') || frameId.startsWith('http')) {
      return frameId;
    }

    if (frameId.startsWith('etar_')) {
      // Fallback for missing etar assets
      return 'assets/images/frames/frame_3.png';
    }

    if (frameId == 'frame_bronze_tribal' ||
        frameId == 'frame_silver_sapphire' ||
        frameId == 'frame_gold_crown') {
      return 'assets/images/$frameId.png';
    }

    if (frameId.startsWith('frame_')) {
      return 'assets/images/frames/$frameId.png';
    }

    switch (frameId) {
      case 'rom':
      case 'rom.png':
        return 'assets/images/rom.png';
      case 'gold_crown':
        return 'assets/images/frame_gold_crown.png';
      case 'silver_sapphire':
        return 'assets/images/frame_silver_sapphire.png';
      case 'bronze_tribal':
        return 'assets/images/frame_bronze_tribal.png';
      case 'dragon_red':
        return 'assets/images/frames/frame_11.png';
      case 'phoenix':
        return 'assets/images/frames/frame_12.png';
      case 'dragon_blue':
        return 'assets/images/frames/frame_13.png';
      case 'neon_pink':
        return 'assets/images/frames/frame_15.png';
      case 'neon_blue':
        return 'assets/images/frames/frame_18.png';
      default:
        return 'assets/images/frames/frame_3.png';
    }
  }

  static bool _isInvalidPath(String path) {
    if (path.startsWith('http')) return false; // URLs can be very long
    return path.contains('NoSuchMethodError') ||
        path.contains('Exception') ||
        path.contains('Bad state') ||
        path.contains('ticker') ||
        path.length > 1000;
  }

  // --- Static Cache to reduce network calls ---
  static final Map<String, String> _userFrameCache = {};
  static final Map<String, String> _animatedPhotoCache = {};
  static final Map<String, DateTime> _cacheTime = {};

  /// Manually update or clear the cache for a specific user
  static void updateUserFrameCache(String userId, String? frameId, {String? animatedPhoto}) {
    if (frameId == null) {
      _userFrameCache.remove(userId);
      _cacheTime.remove(userId);
    } else {
      _userFrameCache[userId] = frameId;
      _cacheTime[userId] = DateTime.now();
    }
    if (animatedPhoto == null) {
      _animatedPhotoCache.remove(userId);
    } else {
      _animatedPhotoCache[userId] = animatedPhoto;
    }
  }
  @override
  Widget build(BuildContext context) {
    final double baseSize = radius * 2;
    // Standard size for static frames to avoid occlusion
    final double frameSize = baseSize * 1.55;

    Widget avatarWidget = Center(
      child: Container(
        width: baseSize,
        height: baseSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: borderWidth > 0
              ? Border.all(
                  color: borderColor ?? Colors.teal.shade200,
                  width: borderWidth,
                )
              : null,
        ),
        child: ClipOval(
          child: (imageUrl != null &&
                  imageUrl!.isNotEmpty &&
                  !_isInvalidPath(imageUrl!))
              ? (imageUrl!.startsWith('assets/')
                  ? Image.asset(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => _buildPlaceholder(radius),
                    )
                  : (imageUrl!.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (c, u, e) => _buildPlaceholder(radius),
                        )
                      : Image.file(
                          File(imageUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => _buildPlaceholder(radius),
                        )))
              : _buildPlaceholder(radius),
        ),
      ),
    );

    // Helper to apply fallback border
    Widget applyFallbackBorder(Widget avatar) {
      if (fallbackBorderWhenNoFrame) {
        return Container(
          width: baseSize,
          height: baseSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).primaryColor,
              width: 2.5,
            ),
          ),
          child: avatar,
        );
      }
      return avatar;
    }

    // 0. Animated Profile Photo (SVGA/GIF) - Add this layer
    // If user has an animated photo, it will be placed OVER or INSTEAD of the static one
    // Let's check for profilePhotoAnimation via local fetching or passing
    if (manualAnimatedPhoto != null && manualAnimatedPhoto!.isNotEmpty && !disableAnimation) {
       avatarWidget = _buildAnimatedAvatar(manualAnimatedPhoto!, baseSize, borderWidth, borderColor, radius);
    }

    // For efficiency, I will update the StreamBuilder below to fetch it.
    
    // However, if we already have it passed or cached, we can use it.


    // 0. Animated Ring Frame (ring_* IDs) - HIGHEST PRIORITY
    final effectiveFrame = manualFrame ?? manualFrameId;
    if (effectiveFrame != null &&
        effectiveFrame.startsWith('ring_') &&
        !disableAnimation) {
      return AnimatedRingFrame(
        key: ValueKey(effectiveFrame),
        ringId: effectiveFrame,
        avatarSize: baseSize,
        child: avatarWidget,
      );
    }

    // 1. Manual Gift Frame (Priority)
    if (manualFrame != null &&
        manualFrame!.isNotEmpty &&
        !_isInvalidPath(manualFrame!)) {
      return _buildFinalFrame(manualFrame!, baseSize, avatarWidget, frameSize);
    }

    // 2. Manual Frame ID (Second Priority)
    if (manualFrameId != null &&
        manualFrameId!.isNotEmpty &&
        !_isInvalidPath(manualFrameId!)) {
      return _buildFinalFrame(
        manualFrameId!,
        baseSize,
        avatarWidget,
        frameSize,
      );
    }

    // 3. User ID Fetch (Default - with local caching)
    if (userId == null) {
      return SizedBox(
        width: baseSize,
        height: baseSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            applyFallbackBorder(avatarWidget),
            if (overlay != null) overlay!,
          ],
        ),
      );
    }

    // --- ENHANCEMENT: Check Animated Photo Cache regardless of Frame settings ---
    if (_animatedPhotoCache.containsKey(userId)) {
      final cachedAnimated = _animatedPhotoCache[userId!];
      if (cachedAnimated != null && cachedAnimated.isNotEmpty && !disableAnimation && (manualAnimatedPhoto == null || manualAnimatedPhoto!.isEmpty)) {
         avatarWidget = _buildAnimatedAvatar(cachedAnimated, baseSize, borderWidth, borderColor, radius);
      }
    }

    // Fast-path: If animations are disabled and profile frames are not required/disabled,
    // bypass the Firestore StreamBuilder completely to avoid frame drops during entry transitions.
    if (disableAnimation && (useProfileFrameFallback == false || disableFrame)) {
      return SizedBox(
        width: baseSize,
        height: baseSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            applyFallbackBorder(avatarWidget),
            if (overlay != null) overlay!,
          ],
        ),
      );
    }

    // If frames are disabled, we still need to fetch/listen for potential animated photo updates
    // if we don't have a manual one.
    if ((useProfileFrameFallback == false || disableFrame) && userId != null && userId!.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            final animatedPhoto = data?['profilePhotoAnimation'] as String?;
            if (animatedPhoto != null && animatedPhoto.isNotEmpty) {
              _animatedPhotoCache[userId!] = animatedPhoto;
              if (!disableAnimation && (manualAnimatedPhoto == null || manualAnimatedPhoto!.isEmpty)) {
                return SizedBox(
                  width: baseSize,
                  height: baseSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildAnimatedAvatar(animatedPhoto, baseSize, borderWidth, borderColor, radius),
                      if (overlay != null) overlay!,
                    ],
                  ),
                );
              }
            }
          }
          return SizedBox(
            width: baseSize,
            height: baseSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                applyFallbackBorder(avatarWidget),
                if (overlay != null) overlay!,
              ],
            ),
          );
        },
      );
    }

    // 4. Frame Logic (Only reached if userId != null and frames ARE enabled)
    // Check Cache first for Frame
    if (_userFrameCache.containsKey(userId)) {
      final lastFetched = _cacheTime[userId!];
      if (lastFetched != null &&
          DateTime.now().difference(lastFetched).inMinutes < 5) {
        return _buildFinalFrame(
          _userFrameCache[userId!]!,
          baseSize,
          avatarWidget,
          frameSize,
        );
      }
    }

    if (userId == null || userId!.isEmpty) {
      return SizedBox(
        width: baseSize,
        height: baseSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            applyFallbackBorder(avatarWidget),
            if (overlay != null) overlay!,
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        String? frameId;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          
          frameId = data?['profileFrame'] as String?;
          final animatedPhoto = data?['profilePhotoAnimation'] as String?;
          
          if (frameId != null) {
            _userFrameCache[userId!] = frameId;
          }
          if (animatedPhoto != null) {
            _animatedPhotoCache[userId!] = animatedPhoto;
          }
          _cacheTime[userId!] = DateTime.now();

          // If there is an animated photo, rebuild avatarWidget with animation
          // but prioritize manualAnimatedPhoto if provided (for live preview)
          if (manualAnimatedPhoto == null || manualAnimatedPhoto!.isEmpty) {
            if (animatedPhoto != null && animatedPhoto.isNotEmpty && !disableAnimation) {
               avatarWidget = _buildAnimatedAvatar(animatedPhoto, baseSize, borderWidth, borderColor, radius);
            }
          }

        } else {
          frameId = _userFrameCache[userId!];
        }

        if (frameId == null || frameId.isEmpty || _isInvalidPath(frameId)) {
          return SizedBox(
            width: baseSize,
            height: baseSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                applyFallbackBorder(avatarWidget),
                if (overlay != null) overlay!,
              ],
            ),
          );
        }

        return _buildFinalFrame(frameId, baseSize, avatarWidget, frameSize);
      },
    );
  }

  Widget _buildPlaceholder(double radius) {
    return Container(
      color: Colors.grey.shade100,
      child: Icon(
        Icons.person_rounded,
        size: radius,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildFinalFrame(
    String frameId,
    double baseSize,
    Widget avatarWidget,
    double frameSize,
  ) {
    if (frameId.startsWith('http')) {
      return _buildFrameStack(baseSize, avatarWidget, frameSize, frameId);
    }

    // Use cached data as initialData for instant first-frame rendering (no delay)
    // The stream then updates in background if cache is stale
    final initialData = GiftService.getCachedFrames();

    return StreamBuilder<List<ProfileFrame>>(
      stream: GiftService().getAllFramesStream(),
      initialData: initialData,
      builder: (context, frameSnapshot) {
        // Start with the proven local asset path as the guaranteed fallback
        String frameSource = getFrameAsset(frameId);

        if (frameSnapshot.hasData && frameSnapshot.data!.isNotEmpty) {
          final frames = frameSnapshot.data!;
          final found = frames.where((f) => f.id == frameId);
          if (found.isNotEmpty) {
            final frameModel = found.first;
            if (frameModel.image != null &&
                frameModel.image!.isNotEmpty &&
                !_isInvalidPath(frameModel.image!)) {
              frameSource = frameModel.image!;
            } else if (frameModel.asset.isNotEmpty &&
                !_isInvalidPath(frameModel.asset)) {
              frameSource = frameModel.asset;
            }
          }
        }

        return _buildFrameStack(baseSize, avatarWidget, frameSize, frameSource);
      },
    );
  }

  Widget _buildFrameStack(
    double baseSize,
    Widget avatarWidget,
    double frameSize,
    String source,
  ) {
    if (source.isEmpty || _isInvalidPath(source)) {
      return SizedBox(width: baseSize, height: baseSize, child: avatarWidget);
    }

    final double effectiveSize = source.contains('.json') ? baseSize : frameSize;

    return SizedBox(
      width: baseSize,
      height: baseSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          avatarWidget,
          if (overlay != null) overlay!,
          Positioned(
            width: effectiveSize,
            height: effectiveSize,
            top: (baseSize - effectiveSize) / 2,
            left: (baseSize - effectiveSize) / 2,
            child: IgnorePointer(
              child: source.contains('.json')
                  ? Lottie.network(
                      source,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const SizedBox.shrink(),
                    )
                  : (source.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: source,
                          fit: BoxFit.contain,
                          errorWidget: (c, u, e) => const SizedBox.shrink(),
                        )
                      : Image.asset(
                          source,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => const SizedBox.shrink(),
                        )),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Ring Frame Widget
// ─────────────────────────────────────────────────────────────────────────────

/// A stateful widget that draws a rotating gradient ring around the avatar.
/// Triggered when [ringId] starts with 'ring_'.
class AnimatedRingFrame extends StatefulWidget {
  final String ringId;
  final double avatarSize;
  final Widget child;

  const AnimatedRingFrame({
    super.key,
    required this.ringId,
    required this.avatarSize,
    required this.child,
  });

  @override
  State<AnimatedRingFrame> createState() => _AnimatedRingFrameState();
}

class _AnimatedRingFrameState extends State<AnimatedRingFrame>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static int _durationMs(String id) {
    switch (id) {
      case 'ring_fire':        return 1200;
      case 'ring_lightning':   return 700;
      case 'ring_neon':        return 1000;
      case 'ring_galaxy':      return 3000;
      case 'ring_ice':         return 2500;
      case 'ring_rainbow':     return 2000;
      case 'ring_rose':        return 2800;
      case 'ring_gold':        return 1800;
      case 'ring_diamond':     return 1500;
      case 'ring_emerald':     return 2200;
      default:                 return 2000;
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _durationMs(widget.ringId)),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringSize = widget.avatarSize * 1.12;
    final offset = (widget.avatarSize - ringSize) / 2;

    return SizedBox(
      width: widget.avatarSize,
      height: widget.avatarSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned(
            width: ringSize,
            height: ringSize,
            top: offset,
            left: offset,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => CustomPaint(
                  size: Size(ringSize, ringSize),
                  painter: _RingFramePainter(
                    ringId: widget.ringId,
                    progress: _ctrl.value,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingFramePainter extends CustomPainter {
  final String ringId;
  final double progress;

  _RingFramePainter({required this.ringId, required this.progress});

  // ── Color schemes ─────────────────────────────────────────────────
  static const Map<String, List<Color>> _colors = {
    'ring_fire': [
      Color(0xFFFF4500), Color(0xFFFF8C00), Color(0xFFFFD700),
      Color(0xFFFF0000), Color(0xFFFF4500),
    ],
    'ring_galaxy': [
      Color(0xFF6A0DAD), Color(0xFF3B0083), Color(0xFF8B00FF),
      Color(0xFF0047AB), Color(0xFF9400D3), Color(0xFF6A0DAD),
    ],
    'ring_gold': [
      Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFF176),
      Color(0xFFDAA520), Color(0xFFFFD700),
    ],
    'ring_ice': [
      Color(0xFF00CFFF), Color(0xFFE0FFFF), Color(0xFF87CEEB),
      Color(0xFFB0E0E6), Color(0xFF00CFFF),
    ],
    'ring_neon': [
      Color(0xFF00FF41), Color(0xFF00FFFF), Color(0xFF7FFF00),
      Color(0xFF00FF7F), Color(0xFF00FF41),
    ],
    'ring_rainbow': [
      Color(0xFFFF0000), Color(0xFFFF7F00), Color(0xFFFFFF00),
      Color(0xFF00FF00), Color(0xFF0000FF), Color(0xFF8B00FF),
      Color(0xFFFF0000),
    ],
    'ring_rose': [
      Color(0xFFFF69B4), Color(0xFFFF1493), Color(0xFFFFB6C1),
      Color(0xFFDB7093), Color(0xFFFF69B4),
    ],
    'ring_lightning': [
      Color(0xFFFFFF00), Color(0xFFFFFFFF), Color(0xFFFFD700),
      Color(0xFFFFA500), Color(0xFFFFFF00),
    ],
    'ring_diamond': [
      Color(0xFF00FFFF), Color(0xFFFFFFFF), Color(0xFF87CEEB),
      Color(0xFFADD8E6), Color(0xFF00FFFF),
    ],
    'ring_emerald': [
      Color(0xFF50C878), Color(0xFF00FF7F), Color(0xFF2E8B57),
      Color(0xFF00FA9A), Color(0xFF50C878),
    ],
  };

  // ── Thickness per ring ─────────────────────────────────────────────
  static const Map<String, double> _thickness = {
    'ring_fire': 5.0, 'ring_lightning': 4.0, 'ring_neon': 5.5,
    'ring_galaxy': 3.5, 'ring_ice': 3.5, 'ring_rainbow': 5.0,
    'ring_rose': 3.0, 'ring_gold': 5.0, 'ring_diamond': 3.5,
    'ring_emerald': 4.0,
  };

  static const _glowRings = {'ring_fire', 'ring_neon', 'ring_lightning', 'ring_gold'};
  static const _dotRings  = {'ring_ice', 'ring_diamond', 'ring_galaxy'};

  @override
  void paint(Canvas canvas, Size size) {
    final colors = _colors[ringId] ?? _colors['ring_gold']!;
    final thick  = _thickness[ringId] ?? 4.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - thick / 2;

    final angle = progress * 2 * math.pi;
    final gradient = SweepGradient(
      startAngle: angle,
      endAngle: angle + 2 * math.pi,
      colors: colors,
    );
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Glow layer
    if (_glowRings.contains(ringId)) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = gradient.createShader(rect)
          ..strokeWidth = thick * 2.8
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    // Main ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = thick
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Sparkle dots
    if (_dotRings.contains(ringId)) {
      const dotCount = 7;
      for (int i = 0; i < dotCount; i++) {
        final a = angle + (i / dotCount) * 2 * math.pi;
        final dx = center.dx + radius * math.cos(a);
        final dy = center.dy + radius * math.sin(a);
        canvas.drawCircle(
          Offset(dx, dy),
          2.2,
          Paint()
            ..color = colors[i % colors.length].withOpacity(0.9)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingFramePainter old) => old.progress != progress;
}

Widget _buildAnimatedAvatar(String source, double baseSize, double borderWidth, Color? borderColor, double radius) {
  return Center(
    child: Container(
      width: baseSize,
      height: baseSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? Colors.teal.shade200,
                width: borderWidth,
              )
            : null,
      ),
      child: ClipOval(
        child: source.toLowerCase().contains('.svga')
            ? SafeSVGA(
                resUrl: source,
                width: baseSize,
                height: baseSize,
                fit: BoxFit.cover,
              )
            : (source.toLowerCase().contains('.mp4')

                ? CircularVideoPlayer(
                    source: source,
                    size: baseSize,
                    fit: BoxFit.cover,
                  )
                : (source.startsWith('http')
                    ? Image.network(
                        source,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            Container(color: Colors.grey.shade100),
                      )
                    : Image.file(
                        File(source),
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            Container(color: Colors.grey.shade100),
                      ))),
      ),

    ),
  );
}

