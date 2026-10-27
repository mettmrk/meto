import 'package:flutter/material.dart';

class LevelBadge extends StatelessWidget {
  final int level;
  final double size;

  const LevelBadge({
    super.key,
    required this.level,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the image level (1-90 available)
    final int displayLevel = level.clamp(1, 90);
    final String imagePath = 'assets/images/level/$displayLevel.png';

    return Image.asset(
      imagePath,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.stars, size: size, color: Colors.amber);
      },
    );
  }
}
