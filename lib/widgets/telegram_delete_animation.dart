import 'package:flutter/material.dart';
import 'dart:math' as math;

class TelegramDeleteWrapper extends StatefulWidget {
  final Widget child;
  final bool isDeleting;
  final VoidCallback onAnimationComplete;

  const TelegramDeleteWrapper({
    super.key,
    required this.child,
    required this.isDeleting,
    required this.onAnimationComplete,
  });

  @override
  State<TelegramDeleteWrapper> createState() => _TelegramDeleteWrapperState();
}

class _TelegramDeleteWrapperState extends State<TelegramDeleteWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _sizeFactor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _sizeFactor = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.fastOutSlowIn),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });
  }

  @override
  void didUpdateWidget(TelegramDeleteWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDeleting && !oldWidget.isDeleting) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.value == 0 && !widget.isDeleting) {
          return widget.child;
        }

        return SizeTransition(
          sizeFactor: _sizeFactor,
          axisAlignment: 1.0,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Stack(
                children: [
                  widget.child,
                  if (widget.isDeleting)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: DustPainter(progress: _controller.value),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DustPainter extends CustomPainter {
  final double progress;
  final List<Particle> particles;

  DustPainter({required this.progress})
      : particles = List.generate(20, (index) {
          final random = math.Random(index);
          return Particle(
            angle: random.nextDouble() * 2 * math.pi,
            distance: random.nextDouble() * 100,
            size: random.nextDouble() * 3 + 1,
            color: Colors.white.withOpacity(0.6),
          );
        });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.1) return;
    
    final paint = Paint();
    final center = Offset(size.width / 2, size.height / 2);

    for (var particle in particles) {
      final currentDist = particle.distance * progress;
      final x = center.dx + math.cos(particle.angle) * currentDist;
      final y = center.dy + math.sin(particle.angle) * currentDist;
      
      paint.color = particle.color.withOpacity((1 - progress) * 0.6);
      canvas.drawCircle(Offset(x, y), particle.size * (1 - progress), paint);
    }
  }

  @override
  bool shouldRepaint(DustPainter oldDelegate) => oldDelegate.progress != progress;
}

class Particle {
  final double angle;
  final double distance;
  final double size;
  final Color color;

  Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
}
