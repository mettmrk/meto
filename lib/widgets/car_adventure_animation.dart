import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class CarAdventureAnimation extends StatefulWidget {
  final VoidCallback onComplete;

  const CarAdventureAnimation({super.key, required this.onComplete});

  @override
  State<CarAdventureAnimation> createState() => _CarAdventureAnimationState();
}

class _CarAdventureAnimationState extends State<CarAdventureAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _repeatCount = 0;
  static const int _maxRepeats = 1; // تكرار الحركة مرة واحدة فقط

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _repeatCount++;
        if (_repeatCount < _maxRepeats) {
          _controller.forward(from: 0);
        } else {
          if (mounted) widget.onComplete();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.7), // خلفية داكنة للتركيز
        child: Center(
          child: Lottie.asset(
            'assets/lottie/car_adventure.json',
            controller: _controller,
            onLoaded: (composition) {
              _controller.duration = composition.duration;
              _controller.forward(from: 0);
            },
            fit: BoxFit.contain, // عرض الحركة كاملة بدون قص
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Car Adventure Error: $error');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) widget.onComplete();
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
