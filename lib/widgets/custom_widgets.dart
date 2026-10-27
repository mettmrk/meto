// ملف يتضمن مكونات مساعدة متعددة الاستخدام

import 'package:flutter/material.dart';
import 'dart:math' as math;

/// مكون زر تحميل
class LoadingButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final Color backgroundColor;
  final Color textColor;
  final double borderRadius;

  const LoadingButton({
    super.key,
    this.onPressed,
    required this.label,
    this.isLoading = false,
    this.backgroundColor = Colors.blue,
    this.textColor = Colors.white,
    this.borderRadius = 12,
  });

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: widget.isLoading ? null : widget.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
        child: widget.isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                widget.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor,
                ),
              ),
      ),
    );
  }
}

/// مكون حقل نص مخصص
class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final VoidCallback? onSuffixPressed;
  final String? Function(String?)? validator;
  final int maxLines;

  const CustomTextField({
    super.key,
    this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onSuffixPressed,
    this.validator,
    this.maxLines = 1,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _isObscure;

  @override
  void initState() {
    super.initState();
    _isObscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _isObscure,
      keyboardType: widget.keyboardType,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      decoration: InputDecoration(
        hintText: widget.hintText,
        labelText: widget.labelText,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        suffixIcon: widget.suffixIcon != null
            ? IconButton(
                icon: Icon(widget.suffixIcon),
                onPressed:
                    widget.onSuffixPressed ??
                    () {
                      if (widget.obscureText) {
                        setState(() {
                          _isObscure = !_isObscure;
                        });
                      }
                    },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}

/// مكون بطاقة شخصية
class UserProfileCard extends StatelessWidget {
  final String username;
  final String? profileImage;
  final String? subtitle;
  final VoidCallback? onTap;

  const UserProfileCard({
    super.key,
    required this.username,
    this.profileImage,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[300],
        child: profileImage != null
            ? Image.network(
                profileImage!,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person),
              )
            : const Icon(Icons.person),
      ),
      title: Text(username),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      onTap: onTap,
    );
  }
}

/// مكون بطاقة فارغة
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          if (actionLabel != null && onActionPressed != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onActionPressed,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// مكون الموجة الصوتية
class SoundWaveWidget extends StatefulWidget {
  final Color color;
  final double size;
  final int barCount;

  const SoundWaveWidget({
    super.key,
    this.color = const Color(0xFF00FFD1),
    this.size = 20,
    this.barCount = 3,
  });

  @override
  State<SoundWaveWidget> createState() => _SoundWaveWidgetState();
}

class _SoundWaveWidgetState extends State<SoundWaveWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size,
      width: widget.size * 1.5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(widget.barCount, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Create a more varied wave effect
              final phaseOffset = index * (math.pi / widget.barCount);
              final animationValue = _controller.value * 2 * math.pi;
              final waveValue = math.sin(animationValue + phaseOffset);

              // Ensure height factor is between 0.3 and 1.0 and changes significantly
              final heightFactor = 0.3 + (0.7 * (waveValue.abs()));

              return Container(
                width: (widget.size * 1.5) / (widget.barCount * 1.6),
                height: widget.size * heightFactor,
                decoration: BoxDecoration(
                  color: widget.color.withValues(
                    alpha: 0.8 + (0.2 * waveValue.abs()),
                  ),
                  borderRadius: BorderRadius.circular(widget.size / 10),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(
                        alpha: 0.4 * waveValue.abs(),
                      ),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// A text widget that automatically scrolls back and forth if the text is too long.
class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double width;
  final Duration duration;
  final Duration pauseDuration;

  const ScrollingText({
    super.key,
    required this.text,
    this.style,
    this.width = double.infinity,
    this.duration = const Duration(seconds: 3),
    this.pauseDuration = const Duration(seconds: 2),
  });

  @override
  State<ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> {
  late ScrollController _scrollController;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    while (!_isDisposed && mounted) {
      if (!_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      if (_scrollController.position.maxScrollExtent > 0) {
        await Future.delayed(widget.pauseDuration);
        if (_isDisposed || !mounted) break;
        try {
          if (_scrollController.hasClients) {
            await _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: widget.duration,
              curve: Curves.linear,
            );
          }
        } catch (e) {
          break;
        }

        await Future.delayed(widget.pauseDuration);
        if (_isDisposed || !mounted) break;

        try {
          if (_scrollController.hasClients) {
            await _scrollController.animateTo(
              0.0,
              duration: widget.duration,
              curve: Curves.linear,
            );
          }
        } catch (e) {
          break;
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          style: widget.style,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }
}
