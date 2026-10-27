import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flame/game.dart' hide Matrix4;
import 'package:flame/components.dart' hide Matrix4;

class AnimatedDice extends StatefulWidget {
  final int value;
  final bool isRolling;
  final double size;
  final Color color;
  final Color dotColor;
  final String? diceTheme;
  final Map<String, String>? diceUrls;
  final VoidCallback? onTap;

  const AnimatedDice({
    super.key,
    required this.value,
    this.isRolling = false,
    this.size = 40.0,
    this.color = Colors.white,
    this.dotColor = Colors.black87,
    this.diceTheme,
    this.diceUrls,
    this.onTap,
  });

  @override
  State<AnimatedDice> createState() => _AnimatedDiceState();
}

class _AnimatedDiceState extends State<AnimatedDice> {
  late DiceGame _game;

  @override
  void initState() {
    super.initState();
    _game = DiceGame(
      targetValue: widget.value,
      isRolling: widget.isRolling,
      diceSize: widget.size,
      diceColor: widget.color,
      dotColor: widget.dotColor,
      diceTheme: widget.diceTheme,
      diceUrls: widget.diceUrls,
    );
  }

  @override
  void didUpdateWidget(AnimatedDice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRolling != oldWidget.isRolling || 
        widget.value != oldWidget.value || 
        widget.color != oldWidget.color ||
        widget.dotColor != oldWidget.dotColor ||
        widget.diceTheme != oldWidget.diceTheme ||
        widget.diceUrls != oldWidget.diceUrls) {
      _game.updateState(widget.value, widget.isRolling, widget.color, widget.dotColor, widget.diceTheme, widget.diceUrls);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: OverflowBox(
        maxWidth: widget.size * 2.2,
        maxHeight: widget.size * 2.8,
        child: SizedBox(
          width: widget.size * 2.2,
          height: widget.size * 2.8,
          child: GameWidget(game: _game),
        ),
      ),
    );
  }
}

class DiceGame extends FlameGame {
  int targetValue;
  bool isRolling;
  final double diceSize;
  Color diceColor;
  Color dotColor;
  String? diceTheme;
  Map<String, String>? diceUrls;
  
  late Dice3DComponent _diceComponent;

  DiceGame({
    required this.targetValue,
    required this.isRolling,
    required this.diceSize,
    required this.diceColor,
    required this.dotColor,
    this.diceTheme,
    this.diceUrls,
  });

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    _diceComponent = Dice3DComponent(
      size: Vector2.all(diceSize),
      color: diceColor,
      dotColor: dotColor,
      value: targetValue,
      isRolling: isRolling,
      diceTheme: diceTheme,
      diceUrls: diceUrls,
    );
    _diceComponent.position = Vector2(size.x / 2, size.y / 2);
    add(_diceComponent);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _diceComponent.position = Vector2(size.x / 2, size.y / 2);
    }
  }

  void updateState(int newValue, bool rolling, Color newColor, Color newDotColor, String? newTheme, Map<String, String>? newUrls) {
    targetValue = newValue;
    
    if (diceTheme != newTheme || diceUrls != newUrls) {
      _diceComponent.updateTheme(newTheme, newUrls);
    }
    diceTheme = newTheme;
    diceUrls = newUrls;

    if (diceColor != newColor || _diceComponent.dotColor != newDotColor) {
      diceColor = newColor;
      dotColor = newDotColor;
      _diceComponent.color = newColor;
      _diceComponent.dotColor = newDotColor;
    }

    if (isLoaded) {
      _diceComponent.value = newValue;
      
      if (rolling && !isRolling) {
        _diceComponent.startRoll();
      } else if (!rolling && isRolling) {
        _diceComponent.stopRoll();
      }
    }
    isRolling = rolling;
  }
}

class Dice3DComponent extends PositionComponent {
  Color color;
  Color dotColor;
  int value;
  bool isRolling;
  String? diceTheme;
  Map<String, String>? diceUrls;
  final Map<int, ui.Image> _faceImages = {};
  
  double rx = 0;
  double ry = 0;
  double rz = 0;
  double dy = 0;
  double shadowScale = 1.0;
  
  double _rollTime = 0;
  final double _totalRollTime = 1.0; // 1 second roll duration

  Dice3DComponent({
    required Vector2 size,
    required this.color,
    required this.dotColor,
    required this.value,
    required this.isRolling,
    this.diceTheme,
    this.diceUrls,
  }) : super(size: size, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _loadFaceImages();
  }

  void updateTheme(String? newTheme, Map<String, String>? newUrls) {
    diceTheme = newTheme;
    diceUrls = newUrls;
    _loadFaceImages();
  }

  Future<void> _loadFaceImages() async {
    _faceImages.clear();
    for (int i = 1; i <= 6; i++) {
      ImageProvider? provider;
      if (diceUrls != null && diceUrls!.containsKey(i.toString())) {
        provider = NetworkImage(diceUrls![i.toString()]!);
      } else if (diceTheme != null && diceTheme != 'classic' && diceTheme!.isNotEmpty) {
        provider = AssetImage('assets/images/dice/$diceTheme/$i.png');
      }
      
      if (provider != null) {
        try {
          final img = await _loadImageFromProvider(provider);
          _faceImages[i] = img;
        } catch (_) {
          // Fallback to dot rendering
        }
      }
    }
  }

  Future<ui.Image> _loadImageFromProvider(ImageProvider provider) async {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      if (!completer.isCompleted) completer.complete(info.image);
      stream.removeListener(listener);
    }, onError: (e, s) {
      if (!completer.isCompleted) completer.completeError(e);
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    return completer.future;
  }

  void startRoll() {
    isRolling = true;
    _rollTime = 0;
    rx = 0;
    ry = 0;
    rz = 0;
  }

  void stopRoll() {
    isRolling = false;
    rx = 0;
    ry = 0;
    rz = 0;
    dy = 0;
    shadowScale = 1.0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isRolling) {
      _rollTime += dt;
      if (_rollTime > _totalRollTime) {
        _rollTime = _totalRollTime;
      }
      
      double progress = _rollTime / _totalRollTime;
      
      // Ease out cubic for rotation
      double ease = 1 - math.pow(1 - progress, 3).toDouble();
      
      // Even slower rotations for maximum aesthetics
      rx = ease * 1 * math.pi;
      ry = ease * 1.5 * math.pi;
      rz = ease * 0.25 * math.pi;
      
      final double jumpHeight = size.x * 0.75; // Reduced jump height as requested
      final double smallJump = size.x * 0.15;

      // Physics bounce calculations
      if (progress < 0.35) {
        double p = progress / 0.35;
        double pEase = math.sin(p * math.pi / 2); // Ease out
        dy = -jumpHeight * pEase;
        shadowScale = 1.0 - 0.7 * pEase;
      } else if (progress < 0.70) {
        double p = (progress - 0.35) / 0.35;
        double pEase = 1 - math.cos(p * math.pi / 2); // Ease in
        dy = -jumpHeight * (1 - pEase);
        shadowScale = 0.3 + 0.7 * pEase;
      } else if (progress < 0.85) {
        double p = (progress - 0.70) / 0.15;
        double pEase = math.sin(p * math.pi / 2); // Ease out
        dy = -smallJump * pEase;
        shadowScale = 1.0 - 0.3 * pEase;
      } else {
        double p = (progress - 0.85) / 0.15;
        double pEase = 1 - math.cos(p * math.pi / 2); // Ease in
        dy = -smallJump * (1 - pEase);
        shadowScale = 0.7 + 0.3 * pEase;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final s = size.x;
    final half = s / 2;

    canvas.save();
    // Flame Canvas is top-left aligned by default.
    // We translate to the center of the component so all our centered math works perfectly!
    canvas.translate(half, half);

    // Draw bottom shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3 * shadowScale);
    
    canvas.save();
    canvas.translate(0, s * 0.3); // Shadow slightly below the dice
    canvas.scale(shadowScale, shadowScale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s * 1.1, height: s * 0.2), 
        const Radius.circular(100)
      ), 
      shadowPaint
    );
    canvas.restore();

    // Main 3D Rotation Matrix
    final rotationMatrix = Matrix4.identity()
      ..setEntry(3, 2, 0.002) // Perspective depth
      ..rotateX(rx)
      ..rotateY(ry)
      ..rotateZ(rz);

    int back = 7 - value;
    int left = 1, right = 6, top = 2, bottom = 5;
    if (value == 1 || value == 6) { left = 2; right = 5; top = 3; bottom = 4; }
    else if (value == 2 || value == 5) { left = 1; right = 6; top = 3; bottom = 4; }

    final faces = [
      {'val': value, 'trans': Matrix4.identity()..translate(0.0, 0.0, half)},
      {'val': back, 'trans': Matrix4.identity()..translate(0.0, 0.0, -half)..rotateY(math.pi)},
      {'val': left, 'trans': Matrix4.identity()..translate(-half, 0.0, 0.0)..rotateY(-math.pi / 2)},
      {'val': right, 'trans': Matrix4.identity()..translate(half, 0.0, 0.0)..rotateY(math.pi / 2)},
      {'val': top, 'trans': Matrix4.identity()..translate(0.0, -half, 0.0)..rotateX(math.pi / 2)},
      {'val': bottom, 'trans': Matrix4.identity()..translate(0.0, half, 0.0)..rotateX(-math.pi / 2)},
    ];

    // Z-sorting for proper 3D rendering (Draw farthest faces first, closest faces last)
    faces.sort((a, b) {
      final tA = rotationMatrix * (a['trans'] as Matrix4);
      final tB = rotationMatrix * (b['trans'] as Matrix4);
      return tA.storage[14].compareTo(tB.storage[14]);
    });

    canvas.save();
    canvas.translate(0, dy); // Apply bounce physics height

    final Paint facePaint = Paint()..color = color;

    // Draw each face
    for (var face in faces) {
      final trans = face['trans'] as Matrix4;
      final combined = rotationMatrix * trans;
      
      // Calculate dynamic lighting based on z-depth
      final light = (combined.storage[14] / half * 0.5 + 0.5).clamp(0.4, 1.0);

      canvas.save();
      // Apply 3D Matrix transform to the 2D Canvas!
      canvas.transform(combined.storage);

      final Rect faceRect = Rect.fromCenter(center: Offset.zero, width: s, height: s);
      final RRect faceRRect = RRect.fromRectAndRadius(faceRect, Radius.circular(s * 0.15));
      
      final int faceVal = face['val'] as int;

      if (_faceImages.containsKey(faceVal)) {
        // Draw the custom store image!
        final img = _faceImages[faceVal]!;
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        canvas.drawImageRect(img, src, faceRect, Paint());
      } else {
        // Fallback to solid color + dots
        canvas.drawRRect(faceRRect, facePaint);
        _drawDots(canvas, faceVal, s);
      }
      
      // Lighting tint (darken based on angle)
      canvas.drawRRect(faceRRect, Paint()..color = Colors.black.withOpacity((1 - light) * 0.7));

      canvas.restore();
    }

    canvas.restore();
    canvas.restore(); // Restore the initial center translation
  }

  void _drawDots(Canvas canvas, int val, double size) {
    double dotSize = size * 0.18;
    double spacing = size * 0.25;
    final Paint dotPaint = Paint()..color = dotColor;

    void drawDot(double dx, double dy) {
      canvas.drawCircle(Offset(dx * spacing, dy * spacing), dotSize / 2, dotPaint);
    }

    if (val % 2 == 1) drawDot(0, 0); // Center dot
    if (val > 1) { drawDot(-1, -1); drawDot(1, 1); }
    if (val > 3) { drawDot(1, -1); drawDot(-1, 1); }
    if (val == 6) { drawDot(-1, 0); drawDot(1, 0); }
  }
}
