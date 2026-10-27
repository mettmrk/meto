import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'dart:io';
import '../services/preload_service.dart';

/// A wrapper around SVGA player that uses manual parsing and try-catch
/// to avoid crashing or printing red errors when the SVGA data is corrupted.
class SafeSVGA extends StatefulWidget {
  final String? resUrl;
  final String? assetsName;
  final BoxFit fit;
  final double? width;
  final double? height;

  const SafeSVGA({
    super.key,
    this.resUrl,
    this.assetsName,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
  });

  @override
  State<SafeSVGA> createState() => _SafeSVGAState();
}

class _SafeSVGAState extends State<SafeSVGA>
    with SingleTickerProviderStateMixin {
  bool _isError = false;
  SVGAAnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    if (widget.resUrl != null) {
      _loadFromUrl();
    }
  }

  @override
  void didUpdateWidget(SafeSVGA oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resUrl != oldWidget.resUrl) {
      if (mounted) {
        setState(() {
          _isError = false;
        });
      }
      if (widget.resUrl != null) {
        _loadFromUrl();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadFromUrl() async {
    try {
      final SVGAParser parser = SVGAParser();
      MovieEntity? videoItem;

      final cachedPath = await PreloadService().getCachedFilePath(
        widget.resUrl!,
      );
      if (cachedPath != null) {
        final bytes = await File(cachedPath).readAsBytes();
        // SVGA parser can decode from bytes buffer
        // Note: decodeFromBuffer is standard in SVGA, but if not available we will catch and fallback
        try {
          videoItem = await parser.decodeFromBuffer(bytes.toList());
        } catch (e) {
          videoItem = await parser.decodeFromURL(widget.resUrl!);
        }
      } else {
        videoItem = await parser.decodeFromURL(widget.resUrl!);
      }

      if (mounted && _controller != null) {
        _controller!.videoItem = videoItem;
        _controller!.forward().whenComplete(() => _controller!.repeat());
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("[SafeSVGA] Skip bad animation: $e");
      if (mounted) {
        setState(() => _isError = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) return const SizedBox.shrink();

    // Use standard easy player for assets (usually safe and handles its own controller)
    if (widget.assetsName != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: SVGAEasyPlayer(assetsName: widget.assetsName!, fit: widget.fit),
      );
    }

    // Use manual image if parsed and controller is ready
    if (_controller != null && _controller!.videoItem != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: SVGAImage(_controller!),
      );
    }

    // Still loading or empty
    return SizedBox(width: widget.width, height: widget.height);
  }
}
