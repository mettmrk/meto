import 'package:flutter/material.dart';
import 'dart:math' as math;

class GoldWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // --- 1. Draw Layered Waves (Depth) ---
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final borderPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF8B4513), // Saddle Brown (Dark base)
          Color(0xFFFFD700), // Gold
          Color(0xFFFFFACD), // Lemon Chiffon (Bright highlight)
          Color(0xFFFFD700), // Gold
          Color(0xFF8B4513), // Saddle Brown
        ],
        stops: [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final path2 = Path(); // Secondary twisting wave

    final baseHeight = 0.0;
    path.moveTo(0, baseHeight);
    path2.moveTo(0, baseHeight);

    for (double i = 0; i <= size.width; i++) {
      // Primary wave
      path.lineTo(
        i,
        baseHeight +
            6 * math.sin((i / size.width * 4 * math.pi) + (math.pi / 2)),
      );
      // Secondary intricate wave (twisting around)
      path2.lineTo(
        i,
        baseHeight +
            6 *
                math.sin(
                  (i / size.width * 4 * math.pi) + (math.pi / 2) + math.pi,
                ),
      );
    }

    // Draw Shadows
    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path2, shadowPaint);

    // Draw Gold Waves
    canvas.drawPath(path, borderPaint);
    canvas.drawPath(path2, borderPaint);

    // --- 2. Hanging Chains & Gems ---
    final chainLinkPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final gemColors = [
      const Color(0xFFE0115F), // Ruby Red
      const Color(0xFF50C878), // Emerald Green
      const Color(0xFF0F52BA), // Sapphire Blue
      const Color(0xFFFFD700), // Gold
      const Color(0xFF9966CC), // Amethyst Purple
    ];

    int gemIndex = 0;

    for (double i = 25; i < size.width; i += 45) {
      final x = i;
      // Anchor on the lower wave
      final yBase =
          baseHeight +
          6.0 * math.sin((i / size.width * 4 * math.pi) + (math.pi / 2));

      // Randomized length for natural look
      final length = 10 + 20 * (0.5 + 0.5 * math.sin(i * 12.5));

      // Draw Chain
      for (double y = yBase; y < yBase + length; y += 3) {
        canvas.drawCircle(Offset(x, y), 1.0, chainLinkPaint);
      }

      // Draw Gemstone
      final gemColor = gemColors[gemIndex % gemColors.length];
      gemIndex++;

      final gemPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.9), // Glint
                gemColor,
                Colors.black.withValues(alpha: 0.3), // Shadow
              ],
              stops: [0.1, 0.5, 1.0],
              center: Alignment(-0.3, -0.3),
            ).createShader(
              Rect.fromCircle(center: Offset(x, yBase + length), radius: 5),
            );

      // Gem Shadow
      canvas.drawCircle(
        Offset(x + 1, yBase + length + 2),
        2,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      // Gem Body
      canvas.drawCircle(Offset(x, yBase + length), 5, gemPaint);

      // Sparkle (Randomly on some gems)
      if (length > 20) {
        _drawSparkle(canvas, Offset(x - 2, yBase + length - 2), 3);
      }
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1);

    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
