import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';

class GameMenuBackground extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFF0A0A1A);

  @override
  Future<void> onLoad() async {
    // Add neon grid lines
    add(NeonGrid());

    // Add floating geometric neon shapes
    for (var i = 0; i < 6; i++) {
      add(FloatingNeonShape());
    }

    // Add a few 3D wireframe cubes
    for (var i = 0; i < 3; i++) {
      add(Floating3DCube());
    }

    // Add Scanlines Overlay
    add(Scanlines());
  }
}

class Scanlines extends Component with HasGameRef<GameMenuBackground> {
  final Paint _paint = Paint()
    ..color = Colors.white.withOpacity(0.02)
    ..strokeWidth = 1.0;

  double _scroll = 0;

  @override
  void update(double dt) {
    _scroll = (_scroll + 20 * dt) % 20;
  }

  @override
  void render(Canvas canvas) {
    final size = gameRef.size;

    // Horizontal scanlines
    for (double y = _scroll; y < size.y; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), _paint);
    }

    // Vignette
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final gradient = RadialGradient(
      colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
      stops: const [0.6, 1.0],
    );

    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }
}

class Floating3DCube extends PositionComponent
    with HasGameRef<GameMenuBackground> {
  late List<Vector3> _vertices;
  late List<List<int>> _edges;
  double _angleX = 0;
  double _angleY = 0;
  late double _rotationSpeedX;
  late double _rotationSpeedY;
  late Color _color;
  late Vector2 _drift;

  @override
  void onMount() {
    super.onMount();
    final random = Random();

    position = Vector2(
      random.nextDouble() * gameRef.size.x,
      random.nextDouble() * gameRef.size.y,
    );

    // Cube vertices
    _vertices = [
      Vector3(-1, -1, -1),
      Vector3(1, -1, -1),
      Vector3(1, 1, -1),
      Vector3(-1, 1, -1),
      Vector3(-1, -1, 1),
      Vector3(1, -1, 1),
      Vector3(1, 1, 1),
      Vector3(-1, 1, 1),
    ];

    // Connections
    _edges = [
      [0, 1], [1, 2], [2, 3], [3, 0], // Back
      [4, 5], [5, 6], [6, 7], [7, 4], // Front
      [0, 4], [1, 5], [2, 6], [3, 7], // Connecting
    ];

    _rotationSpeedX = (random.nextDouble() - 0.5) * 1.5;
    _rotationSpeedY = (random.nextDouble() - 0.5) * 1.5;
    _color = [
      Colors.cyanAccent,
      Colors.purpleAccent,
      Colors.blueAccent,
    ][random.nextInt(3)];
    _drift = Vector2(
      (random.nextDouble() - 0.5) * 20,
      (random.nextDouble() - 0.5) * 20,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _angleX += _rotationSpeedX * dt;
    _angleY += _rotationSpeedY * dt;

    position += _drift * dt;
    if (x < -50) x = gameRef.size.x + 50;
    if (x > gameRef.size.x + 50) x = -50;
    if (y < -50) y = gameRef.size.y + 50;
    if (y > gameRef.size.y + 50) y = -50;
  }

  @override
  void render(Canvas canvas) {
    final scale = 40.0;
    final projected = _vertices.map((v) {
      // Rotate
      var vec = v.clone();

      // X rotation
      var y1 = vec.y * cos(_angleX) - vec.z * sin(_angleX);
      var z1 = vec.y * sin(_angleX) + vec.z * cos(_angleX);
      vec.y = y1;
      vec.z = z1;

      // Y rotation
      var x2 = vec.x * cos(_angleY) + vec.z * sin(_angleY);
      var z2 = -vec.x * sin(_angleY) + vec.z * cos(_angleY);
      vec.x = x2;
      vec.z = z2;

      // Perspective projection
      final perspective = 3.0 / (3.0 - (vec.z / 2.0));
      return Offset(vec.x * scale * perspective, vec.y * scale * perspective);
    }).toList();

    final paint = Paint()
      ..color = _color.withOpacity(0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = _color.withOpacity(0.1)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    for (final edge in _edges) {
      canvas.drawLine(projected[edge[0]], projected[edge[1]], glowPaint);
      canvas.drawLine(projected[edge[0]], projected[edge[1]], paint);
    }
  }
}

class NeonGrid extends Component {
  final Paint _gridPaint = Paint()
    ..color = const Color(0xFF00B8D4).withValues(alpha: 0.15)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  @override
  void render(Canvas canvas) {
    final size = (parent as GameMenuBackground).size;
    final spacing = 40.0;

    // Draw vertical lines
    for (double x = 0; x <= size.x; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), _gridPaint);
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.y; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), _gridPaint);
    }
  }
}

class FloatingNeonShape extends PositionComponent
    with HasGameRef<GameMenuBackground> {
  late Paint _paint;
  late double _rotationSpeed;
  late double _bobbingSpeed;
  late double _bobbingOffset;
  late double _initialY;
  late List<Offset> _points;
  late Color _neonColor;

  static final List<Color> _colors = [
    const Color(0xFFFF00FF), // Magenta
    const Color(0xFF00FFFF), // Cyan
    const Color(0xFF7000FF), // Purple
    const Color(0xFFFFD700), // Gold
  ];

  @override
  void onMount() {
    super.onMount();
    final random = Random();

    size = Vector2.all(40 + random.nextDouble() * 40);
    position = Vector2(
      random.nextDouble() * gameRef.size.x,
      random.nextDouble() * gameRef.size.y,
    );

    _initialY = y;
    _neonColor = _colors[random.nextInt(_colors.length)];
    _paint = Paint()
      ..color = _neonColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    _rotationSpeed = (random.nextDouble() - 0.5) * 2;
    _bobbingSpeed = 0.5 + random.nextDouble();
    _bobbingOffset = random.nextDouble() * pi * 2;

    // Create random wireframe shape (triangle or square)
    final sides = 3 + random.nextInt(3);
    _points = [];
    final radius = size.x / 2;
    for (var i = 0; i < sides; i++) {
      final angle = (i / sides) * pi * 2;
      _points.add(Offset(cos(angle) * radius, sin(angle) * radius));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    angle += _rotationSpeed * dt;

    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    y = _initialY + sin(time * _bobbingSpeed + _bobbingOffset) * 20;

    // Screen wrap
    if (x > gameRef.size.x + size.x) x = -size.x;
    if (x < -size.x) x = gameRef.size.x + size.x;
    position.x += 10 * dt; // Slow drift
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    // Draw background glow
    final glowPaint = Paint()
      ..color = _neonColor.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final path = Path()..addPolygon(_points, true);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, _paint);

    canvas.restore();
  }
}
