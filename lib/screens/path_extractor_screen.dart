import 'package:flutter/material.dart';

class PathExtractorScreen extends StatefulWidget {
  const PathExtractorScreen({super.key});

  @override
  State<PathExtractorScreen> createState() => _PathExtractorScreenState();
}

class _PathExtractorScreenState extends State<PathExtractorScreen> {
  // قائمة لحفظ النقاط التي تضغط عليها
  List<Offset> pathPoints = [];

  void _handleTap(TapDownDetails details, Size size) {
    // الحصول على الإحداثيات بناءً على حجم الشاشة (لجعلها متجاوبة Responsive)
    double x = details.localPosition.dx / size.width;
    double y = details.localPosition.dy / size.height;

    setState(() {
      pathPoints.add(Offset(x, y));
    });

    // طباعة الإحداثيات لتنسخها وتعطيها لي لاحقاً
    print('Point ${pathPoints.length - 1}: Offset(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)}),');
  }

  void _undoLastTap() {
    if (pathPoints.isNotEmpty) {
      setState(() {
        pathPoints.removeLast();
      });
      print('Undo last point. Current count: ${pathPoints.length}');
    }
  }

  void _clearAllTaps() {
    setState(() {
      pathPoints.clear();
    });
    print('Cleared all points.');
  }

  @override
  Widget build(BuildContext context) {
    // استخدم LayoutBuilder لمعرفة حجم الحاوية بالضبط
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _undoLastTap,
                    child: const Text('تراجع (Undo)'),
                  ),
                  Text(
                    'النقاط التي تم التقاطها: ${pathPoints.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: _clearAllTaps,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('مسح الكل', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            const Text(
              'استخراج مسار الطاولة الدقيق (76 ثقباً)\nاضغط بتأني وابدأ من الماسة الخضراء في الذراع الأيسر ولف مع عقارب الساعة',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1, // لأن طاولة جكارو مربعة
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      Size boardSize = Size(constraints.maxWidth, constraints.maxHeight);
                      return GestureDetector(
                        onTapDown: (details) => _handleTap(details, boardSize),
                        child: Stack(
                          children: [
                            // 1. صورة الطاولة
                            Image.asset(
                              'assets/images/Jkaro.png', // تم التعديل للصورة الخاصة بك
                              fit: BoxFit.contain,
                              width: boardSize.width,
                              height: boardSize.height,
                            ),
                            
                            // 2. رسم النقاط الحمراء فوق الأماكن التي ضغطت عليها لتتأكد من دقتها
                            ...pathPoints.asMap().entries.map((entry) {
                              int index = entry.key;
                              Offset point = entry.value;
                              return Positioned(
                                left: point.dx * boardSize.width - 5, // -5 لتوسيط النقطة
                                top: point.dy * boardSize.height - 5,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$index',
                                      style: const TextStyle(color: Colors.white, fontSize: 6),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    },
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
