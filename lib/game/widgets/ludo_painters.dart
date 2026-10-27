import 'package:flutter/material.dart';

/// يحتوي هذا الملف على الرسامين المخصصين (Custom Painters) المستخدمين في واجهة اللعبة.

/// يرسم ذيل الفقاعة (Bubble Tail) لرسائل الدردشة المنبثقة فوق رؤوس اللاعبين
class BubbleTailPainter extends CustomPainter {
  final Color color;
  const BubbleTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BubbleTailPainter old) => old.color != color;
}

/// يرسم مؤقت العد التنازلي المربع الذي يظهر حول صورة كل لاعب عند دوره
class SquareTimerPainter extends CustomPainter {
  /// نسبة التقدم من 0.0 إلى 1.0
  final double progress;

  /// لون شريط التقدم
  final Color color;

  /// سمك الخط
  final double strokeWidth;

  /// انحناء الزوايا
  final double borderRadius;

  SquareTimerPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 3.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final bgPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. رسم المسار الخلفي (الباهت)
    canvas.drawRRect(rrect, bgPaint);

    // 2. رسم مسار التقدم الفعلي
    final path = Path();
    path.addRRect(rrect);

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      final extractPath = metric.extractPath(0.0, metric.length * progress);
      canvas.drawPath(extractPath, paint);
    }
  }

  @override
  bool shouldRepaint(SquareTimerPainter old) =>
      old.progress != progress || old.color != color;
}
