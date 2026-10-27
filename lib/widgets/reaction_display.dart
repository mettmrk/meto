import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:animated_emoji/animated_emoji.dart';
import 'sticker_selection_bottom_sheet.dart';

class ReactionDisplay extends StatefulWidget {
  final String reactionType;
  final VoidCallback? onComplete;

  const ReactionDisplay({
    super.key,
    required this.reactionType,
    this.onComplete,
  });

  @override
  State<ReactionDisplay> createState() => _ReactionDisplayState();
}

class _ReactionDisplayState extends State<ReactionDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _loopCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Duration per loop
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _loopCount++;
        // Play 3 times total (0, 1, 2) then disappear
        if (_loopCount < 3) {
          _controller.forward(from: 0);
        } else {
          widget.onComplete?.call();
        }
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emojiData = StickerSelectionBottomSheet.getEmojiData(
      widget.reactionType,
    );

    if (emojiData != null) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double val = _controller.value;
          // Stationary on the chair (yOffset = 0)
          double yOffset = 0;

          // No pulsing, fixed scale
          double scale = 1.0;

          // Only fade out on the last loop
          bool isLastLoop = _loopCount >= 2;
          double opacity = isLastLoop
              ? (1.0 - (val > 0.8 ? (val - 0.8) * 5 : 0))
              : 1.0;

          return Transform.translate(
            offset: Offset(0, yOffset),
            child: Transform.scale(
              scale: scale,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..scale(
                    (widget.reactionType == 'kiss_right' ||
                            widget.reactionType == 'spit_right')
                        ? -1.0
                        : 1.0,
                    1.0,
                  ),
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: AnimatedEmoji(
                    emojiData,
                    size: 60,
                    repeat: true,
                    key: const ValueKey('reaction_emoji'),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // Network Sticker Support (Lottie or Image)
    if (widget.reactionType.startsWith('http')) {
      return widget.reactionType.contains('.json')
          ? Lottie.network(
              widget.reactionType,
              width: 80,
              height: 80,
              repeat: true,
              errorBuilder: (context, error, stackTrace) =>
                  _buildImageFallback(),
            )
          : _buildImageFallback();
    }

    // Fallback for Lottie if any remain
    return Lottie.asset(
      'assets/reactions/${widget.reactionType}.json',
      controller: _controller,
      onLoaded: (composition) {
        _controller.duration = composition.duration;
        _controller.forward(from: 0);
      },
      width: 60,
      height: 60,
      errorBuilder: (context, error, stackTrace) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) widget.onComplete?.call();
        });
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildImageFallback() {
    return Image.network(
      widget.reactionType,
      width: 80,
      height: 80,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        widget.onComplete?.call();
        return const SizedBox.shrink();
      },
    );
  }
}
