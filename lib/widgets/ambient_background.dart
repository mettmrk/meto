import 'dart:math';
import 'package:flutter/material.dart';

class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 20,
      ), // Long duration for smooth movement
    )..repeat();

    // Generate random particles
    for (int i = 0; i < 20; i++) {
      _particles.add(_generateParticle());
    }
  }

  _Particle _generateParticle() {
    return _Particle(
      x: _random.nextDouble(), // 0.0 to 1.0
      y: _random.nextDouble(), // 0.0 to 1.0
      speed: 0.2 + _random.nextDouble() * 0.5, // Different speeds
      size: 1.0 + _random.nextDouble() * 3.0, // Different sizes
      opacity: 0.1 + _random.nextDouble() * 0.4, // Different opacities
      offset:
          _random.nextDouble() * 2 * pi, // Random starting phase for pulsing
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _ParticlePainter(
                particles: _particles,
                time: _controller.value,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  double x;
  double y;
  double speed;
  double size;
  double opacity;
  double offset;

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.offset,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;

  _ParticlePainter({required this.particles, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      // Calculate continuous Y position based on time
      // We want particles to float UP
      double currentY = (particle.y - (time * particle.speed)) % 1.0;
      if (currentY < 0) currentY += 1.0;

      // Add a slight horizontal drift using Sine wave
      double currentX =
          (particle.x + sin((time * 2 * pi) + particle.offset) * 0.05) % 1.0;

      // Pulse opacity
      double pulse = sin((time * 2 * pi * 2) + particle.offset); // Faster pulse
      double currentOpacity = (particle.opacity + (pulse * 0.1)).clamp(
        0.0,
        1.0,
      );

      paint.color = Colors.white.withValues(alpha: currentOpacity);

      // Draw particle
      canvas.drawCircle(
        Offset(currentX * size.width, currentY * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
