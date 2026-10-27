import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/story_upload_manager.dart';

class DrawingPoint {
  final Offset offset;
  final Paint paint;
  DrawingPoint(this.offset, this.paint);
}

class AddStoryScreen extends StatefulWidget {
  final File? initialFile;
  const AddStoryScreen({super.key, this.initialFile});

  @override
  State<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> {
  late TextEditingController _captionController;
  File? _selectedFile;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // Drawing variables
  final List<DrawingPoint?> _points = [];
  Color _selectedColor = Colors.teal; // Default theme color
  final double _strokeWidth = 5.0;
  bool _isDrawingMode = false;
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController();
    _selectedFile = widget.initialFile;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
      ); // Currently restricting to images for drawing simplicity, or extend to video
      // Note: If we want video support, we'd use pickVideo or check file extension.
      // For now, let's allow both if the user wants generic media, but pickImage is safer for the drawing canvas logic.
      // If we want video, user implementation suggests checking extensions.
      // Let's assume pickImage for now as basic story.
      if (file != null) {
        setState(() {
          _selectedFile = File(file.path);
          _points.clear();
        });
      }
    } catch (e) {
      debugPrint('Error picking media: $e');
    }
  }

  Future<void> _publishStory() async {
    if (_selectedFile == null) return;

    // No local loading state needed as we close immediately
    // Or we can show a quick loading status while preparing the file (drawing capture)

    setState(() {
      _isLoading = true; // Just for file preparation
    });

    try {
      File fileToUpload = _selectedFile!;

      // Check for video extensions
      final bool isVideo = [
        '.mp4',
        '.mov',
        '.avi',
      ].any((ext) => _selectedFile!.path.toLowerCase().endsWith(ext));

      if (!isVideo && _points.isNotEmpty) {
        fileToUpload = await _captureDrawing();
      }

      // Start background upload
      StoryUploadManager.instance.uploadStory(
        file: fileToUpload,
        caption: _captionController.text.trim(),
        isVideo: isVideo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري نشر الستوري... سيتم إعلامك عند الانتهاء'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في التحضير: $e')));
      }
    }
  }

  Future<File> _captureDrawing() async {
    RenderRepaintBoundary boundary =
        _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    var pngBytes = byteData!.buffer.asUint8List();

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/drawn_story_${DateTime.now().millisecondsSinceEpoch}.png';
    File file = File(path);
    await file.writeAsBytes(pngBytes);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedFile == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_a_photo_outlined,
                  size: 60,
                  color: Colors.teal.shade300,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'أضف إلى قصتك',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'شارك لحظاتك مع أصدقائك',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildOptionButton(
                    icon: Icons.camera_alt,
                    label: 'كاميرا',
                    onTap: () => _pickMedia(ImageSource.camera),
                  ),
                  const SizedBox(width: 24),
                  _buildOptionButton(
                    icon: Icons.photo_library,
                    label: 'المعرض',
                    onTap: () => _pickMedia(ImageSource.gallery),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final bool isVideo = [
      '.mp4',
      '.mov',
      '.avi',
    ].any((ext) => _selectedFile!.path.toLowerCase().endsWith(ext));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Image/Video Area
            Center(
              child: RepaintBoundary(
                key: _repaintKey,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    isVideo
                        ? const Icon(
                            Icons.play_circle_outline,
                            size: 80,
                            color: Colors.white,
                          )
                        : Image.file(_selectedFile!, fit: BoxFit.contain),
                    if (!isVideo)
                      GestureDetector(
                        onPanStart: (details) {
                          if (!_isDrawingMode) return;
                          setState(() {
                            RenderBox renderBox =
                                context.findRenderObject() as RenderBox;
                            _points.add(
                              DrawingPoint(
                                renderBox.globalToLocal(details.globalPosition),
                                Paint()
                                  ..color = _selectedColor
                                  ..strokeCap = StrokeCap.round
                                  ..strokeWidth = _strokeWidth,
                              ),
                            );
                          });
                        },
                        onPanUpdate: (details) {
                          if (!_isDrawingMode) return;
                          setState(() {
                            RenderBox renderBox =
                                context.findRenderObject() as RenderBox;
                            _points.add(
                              DrawingPoint(
                                renderBox.globalToLocal(details.globalPosition),
                                Paint()
                                  ..color = _selectedColor
                                  ..strokeCap = StrokeCap.round
                                  ..strokeWidth = _strokeWidth,
                              ),
                            );
                          });
                        },
                        onPanEnd: (details) {
                          if (!_isDrawingMode) return;
                          setState(() => _points.add(null));
                        },
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: DrawingPainter(_points),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Top Control Bar
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => setState(() {
                      _selectedFile = null;
                      _points.clear();
                    }),
                  ),
                  if (!isVideo)
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.draw,
                            color: _isDrawingMode ? Colors.amber : Colors.white,
                          ),
                          onPressed: () =>
                              setState(() => _isDrawingMode = !_isDrawingMode),
                        ),
                        IconButton(
                          icon: const Icon(Icons.undo, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              if (_points.isNotEmpty) {
                                _points.removeLast();
                                while (_points.isNotEmpty &&
                                    _points.last != null) {
                                  _points.removeLast();
                                }
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.cleaning_services_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () => setState(() => _points.clear()),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Color Palette
            if (_isDrawingMode && !isVideo)
              Positioned(
                top: 70,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _colorPicker(Colors.white),
                      _colorPicker(Colors.black),
                      _colorPicker(Colors.red),
                      _colorPicker(Colors.amber),
                      _colorPicker(Colors.teal),
                      _colorPicker(Colors.blue),
                      _colorPicker(Colors.purple),
                    ],
                  ),
                ),
              ),

            // Bottom Input Bar
            if (!_isDrawingMode)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: TextField(
                            controller: _captionController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'أضف تعليقاً...',
                              hintStyle: TextStyle(color: Colors.white70),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.teal,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: _publishStory,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.teal),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _colorPicker(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        height: 28,
        width: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _selectedColor == color ? Colors.white : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint?> points;
  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.offset,
          points[i + 1]!.offset,
          points[i]!.paint,
        );
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawCircle(
          points[i]!.offset,
          points[i]!.paint.strokeWidth / 2,
          points[i]!.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}
