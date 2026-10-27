import 'package:flutter/material.dart';
import 'safe_svga_player.dart';

class SVGAGiftAnimation extends StatefulWidget {
  final String svgaUrl;
  final VoidCallback onComplete;
  final int repeatCount;

  const SVGAGiftAnimation({
    super.key,
    required this.svgaUrl,
    required this.onComplete,
    this.repeatCount = 1,
  });

  @override
  State<SVGAGiftAnimation> createState() => _SVGAGiftAnimationState();
}

class _SVGAGiftAnimationState extends State<SVGAGiftAnimation> {
  @override
  void initState() {
    super.initState();
    
    // Safety timer to ensure the animation is dismissed even if everything fails
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isNetwork = widget.svgaUrl.startsWith('http');

    return IgnorePointer(
      child: SafeSVGA(
        resUrl: isNetwork ? widget.svgaUrl : null,
        assetsName: !isNetwork ? widget.svgaUrl : null,
        fit: BoxFit.contain,
      ),
    );
  }
}
