import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:io';
import '../services/preload_service.dart';

class FullScreenLottieGift extends StatefulWidget {
  final String lottieUrl;
  final VoidCallback onComplete;
  final int repeatCount;

  const FullScreenLottieGift({
    super.key,
    required this.lottieUrl,
    required this.onComplete,
    this.repeatCount = 1,
  });

  @override
  State<FullScreenLottieGift> createState() => _FullScreenLottieGiftState();
}

class _FullScreenLottieGiftState extends State<FullScreenLottieGift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _currentRepeat = 0;
  String? _cachedFilePath;

  @override
  void initState() {
    super.initState();
    _checkCache();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentRepeat++;
        // Play at least 2 times if it's short, or until 5 seconds pass
        if (_currentRepeat < widget.repeatCount) {
          _controller.forward(from: 0);
        } else {
          // Stay on screen for at least 5 seconds total
          Future.delayed(const Duration(seconds: 1), () {
             if (mounted) widget.onComplete();
          });
        }
      }
    });
    
    // Safety exit after 6 seconds regardless of completion
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) widget.onComplete();
    });
  }

  Future<void> _checkCache() async {
    final path = await PreloadService().getCachedFilePath(widget.lottieUrl);
    if (mounted && path != null) {
      setState(() {
        _cachedFilePath = path;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAsset = widget.lottieUrl.startsWith('assets/');

    return IgnorePointer(
      child: isAsset
          ? Lottie.asset(
              widget.lottieUrl,
              controller: _controller,
              onLoaded: (composition) {
                _controller.duration = composition.duration;
                _controller.forward(from: 0);
              },
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Lottie Asset Error: $error');
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) widget.onComplete();
                });
                return const SizedBox.shrink();
              },
            )
          : _cachedFilePath != null
              ? Lottie.file(
                  File(_cachedFilePath!),
                  controller: _controller,
                  onLoaded: (composition) {
                    _controller.duration = composition.duration;
                    _controller.forward(from: 0);
                  },
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Lottie File Error: $error');
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) widget.onComplete();
                    });
                    return const SizedBox.shrink();
                  },
                )
              : Lottie.network(
                  widget.lottieUrl,
                  controller: _controller,
                  onLoaded: (composition) {
                    _controller.duration = composition.duration;
                    _controller.forward(from: 0);
                  },
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Lottie Network Error: $error');
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) widget.onComplete();
                    });
                    return const SizedBox.shrink();
                  },
                ),
    );
  }
}
