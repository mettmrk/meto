import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui';
import 'dart:io';
import '../services/preload_service.dart';

class VipVideoOverlay extends StatefulWidget {
  final VoidCallback onFinished;
  final String videoPath;

  const VipVideoOverlay({
    super.key,
    required this.onFinished,
    this.videoPath = 'assets/videos/tsjel.mp4',
  });

  @override
  State<VipVideoOverlay> createState() => _VipVideoOverlayState();
}

class _VipVideoOverlayState extends State<VipVideoOverlay> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _fadingOut = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    try {
      final isNetwork =
          widget.videoPath.startsWith('http') ||
          widget.videoPath.startsWith('https');

      if (isNetwork) {
        final cachedPath = await PreloadService().getCachedFilePath(widget.videoPath);
        if (cachedPath != null) {
          _controller = VideoPlayerController.file(File(cachedPath));
        } else {
          _controller = VideoPlayerController.networkUrl(
            Uri.parse(widget.videoPath),
          );
        }
      } else {
        _controller = VideoPlayerController.asset(widget.videoPath);
      }

      _controller
          .initialize()
          .then((_) {
            if (!mounted) return;
            setState(() {
              _initialized = true;
            });
            _controller.play();
            _controller.addListener(_checkVideoProgress);
          })
          .catchError((e) {
            debugPrint("Video initialization error: $e");
            _finish(); // Auto-skip on error
          });
    } catch (e) {
      debugPrint("Video controller creation error: $e");
      _finish();
    }
  }

  void _checkVideoProgress() {
    if (_controller.value.position >= _controller.value.duration &&
        !_fadingOut) {
      _finish();
    }
  }

  void _finish() {
    setState(() {
      _fadingOut = true;
    });
    // Smooth fade out before removing
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_checkVideoProgress);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox.shrink();

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: _fadingOut ? 0.0 : 1.0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withValues(alpha: 0.2),
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
