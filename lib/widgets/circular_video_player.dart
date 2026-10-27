import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CircularVideoPlayer extends StatefulWidget {
  final String source;
  final double size;
  final BoxFit fit;

  const CircularVideoPlayer({
    super.key,
    required this.source,
    required this.size,
    this.fit = BoxFit.cover,
  });

  @override
  State<CircularVideoPlayer> createState() => _CircularVideoPlayerState();
}

class _CircularVideoPlayerState extends State<CircularVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    try {
      if (widget.source.startsWith('http')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.source));
      } else {
        _controller = VideoPlayerController.file(File(widget.source));
      }

      _controller.initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.setLooping(true);
          _controller.setVolume(0); // Avatars should be silent
          _controller.play();
        }
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _isError = true;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(CircularVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _controller.dispose();
      _initialize();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Container(
        color: Colors.grey.shade100,
        child: const Icon(Icons.error_outline),
      );
    }

    if (!_controller.value.isInitialized) {
      return Container(
        color: Colors.grey.shade50,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: SizedBox.expand(
          child: FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
        ),
      ),
    );
  }
}
