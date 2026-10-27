import 'package:flutter/material.dart';

class RollingDigitCounter extends StatelessWidget {
  final String value;
  final TextStyle textStyle;
  final Duration duration;

  const RollingDigitCounter({
    super.key,
    required this.value,
    required this.textStyle,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: value.split('').map((char) {
        if (RegExp(r'\d').hasMatch(char)) {
          return DigitTicker(
            digit: int.parse(char),
            textStyle: textStyle,
            duration: duration,
          );
        } else {
          return Text(char, style: textStyle);
        }
      }).toList(),
    );
  }
}

class DigitTicker extends StatefulWidget {
  final int digit;
  final TextStyle textStyle;
  final Duration duration;

  const DigitTicker({
    super.key,
    required this.digit,
    required this.textStyle,
    required this.duration,
  });

  @override
  State<DigitTicker> createState() => _DigitTickerState();
}

class _DigitTickerState extends State<DigitTicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _oldDigit = 0;

  @override
  void initState() {
    super.initState();
    _oldDigit = widget.digit;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.value = 1.0; // Start at current
  }

  @override
  void didUpdateWidget(DigitTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.digit != oldWidget.digit) {
      _oldDigit = oldWidget.digit;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double fontSize = widget.textStyle.fontSize ?? 16;
    final double height = fontSize * 1.2;

    return SizedBox(
      height: height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Stack(
            children: [
              // Sliding Column
              Transform.translate(
                offset: Offset(
                  0,
                  -_animation.value * height +
                      (_controller.isAnimating ? 0 : 0),
                ),
                child: Column(
                  children: [
                    // This is a bit complex for a simple stack.
                    // Let's use a simpler approach: AnimatedSwitcher or just show two digits.
                  ],
                ),
              ),
              // Simplified approach for reliability
              _buildDigit(context, _oldDigit, (1 - _animation.value) * height),
              _buildDigit(
                context,
                widget.digit,
                (1 - _animation.value) * height - height,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDigit(BuildContext context, int digit, double offset) {
    final double fontSize = widget.textStyle.fontSize ?? 16;
    final double height = fontSize * 1.2;
    return Transform.translate(
      offset: Offset(0, offset),
      child: SizedBox(
        height: height,
        child: Text('$digit', style: widget.textStyle),
      ),
    );
  }
}
