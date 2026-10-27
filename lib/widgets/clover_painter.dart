// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'dart:math' as math;

class CloverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // --- 1. Glowing Horizontal Lines (Neon Ribbon effect) ---
    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0x0000FF00), // Transparent
          Color(0xFF32CD32), // LimeGreen
          Color(0xFF00FF00), // Bright Green
          Color(0xFF32CD32), // LimeGreen
          Color(0x0000FF00), // Transparent
        ],
        stops: [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3); // Glow

    final coreLinePaint = Paint()
      ..color =
          const Color(0xFFADFF2F) // GreenYellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final centerY = size.height * 0.4; // Position slightly up

    // Draw lines
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), linePaint);
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      coreLinePaint,
    );

    // Secondary line below
    canvas.drawLine(
      Offset(0, centerY + 8),
      Offset(size.width, centerY + 8),
      linePaint..strokeWidth = 2,
    );

    // --- 2. Draw Clovers ---
    // We will draw clovers along the line
    final random = math.Random(42); // Fixed seed for stability

    for (double i = 20; i < size.width; i += 50) {
      final x = i;
      final y = centerY + (random.nextDouble() * 10 - 5); // Slight y styling
      final scale = 0.8 + random.nextDouble() * 0.5; // Random size

      // Draw Clover at (x, y)
      _drawClover(canvas, Offset(x, y), scale);

      // Occasional Sparkle
      if (random.nextDouble() > 0.7) {
        _drawSparkle(
          canvas,
          Offset(x + random.nextDouble() * 20 - 10, y - 10),
          3 + random.nextDouble() * 3,
        );
      }
    }

    // Extra large clovers at ends
    _drawClover(canvas, Offset(20, centerY + 5), 1.5);
    _drawClover(canvas, Offset(size.width - 20, centerY + 5), 1.5);
  }

  void _drawClover(Canvas canvas, Offset center, double scale) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF90EE90), // LightGreen
          const Color(0xFF008000), // Green
          const Color(0xFF006400), // DarkGreen
        ],
        stops: [0.1, 0.6, 1.0],
        center: Alignment(-0.3, -0.3),
      ).createShader(Rect.fromCircle(center: center, radius: 10 * scale))
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color =
          const Color(0xFFADFF2F) // GreenYellow edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * scale;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    // Draw 4 leaves (Heart shapes)
    for (int i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 2);
      canvas.translate(0, -2); // Move out slightly

      final path = Path();
      // Heart shape logic
      path.moveTo(0, 0);
      path.cubicTo(-5, -5, -10, 0, 0, 10);
      path.cubicTo(10, 0, 5, -5, 0, 0);

      // Simpler lobe shape
      final rect = Rect.fromLTWH(-6, -6, 12, 12);

      final lobePath = Path();
      lobePath.addOval(Rect.fromLTWH(-5, -8, 10, 10));

      // Draw Heart-like Lobe
      final heartPath = Path();
      heartPath.moveTo(0, 0);
      heartPath.cubicTo(
        -5,
        -8,
        -10,
        -2,
        0,
        2,
      ); // Bottom tip to center is 0,0 reversed
      // actually easier to just draw circles for a cartoon clover look

      final lobeRect = Rect.fromCircle(center: const Offset(0, -5), radius: 5);
      canvas.drawOval(lobeRect, paint);
      canvas.drawOval(lobeRect, borderPaint);

      // Bright highlight on leaf
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawOval(Rect.fromLTWH(-3, -8, 3, 3), highlightPaint);

      canvas.restore();
    }

    // Center dot
    canvas.drawCircle(
      Offset.zero,
      1.5,
      borderPaint
        ..style = PaintingStyle.fill
        ..color = Colors.yellowAccent,
    );

    canvas.restore();
  }

  void _drawSparkle(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);

    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(
      center.dx,
      center.dy,
      center.dx + size * 0.8,
      center.dy,
    );
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size);
    path.quadraticBezierTo(
      center.dx,
      center.dy,
      center.dx - size * 0.8,
      center.dy,
    );
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
