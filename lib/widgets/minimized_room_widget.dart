import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/voice_room_service.dart';
import '../screens/voice_room_screen.dart';
import '../main.dart';
import 'dart:math' as math;

class MinimizedRoomWidget extends StatefulWidget {
  const MinimizedRoomWidget({super.key});

  @override
  State<MinimizedRoomWidget> createState() => _MinimizedRoomWidgetState();
}

class _MinimizedRoomWidgetState extends State<MinimizedRoomWidget>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(0, 0);
  bool _isDragging = false;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Selector<
      VoiceRoomService,
      ({
        bool isJoined,
        bool isMinimized,
        String? currentRoomId,
        bool isBroadcaster,
        bool isMuted,
      })
    >(
      selector: (context, service) => (
        isJoined: service.isJoined,
        isMinimized: service.isMinimized,
        currentRoomId: service.currentRoomId,
        isBroadcaster: service.isBroadcaster,
        isMuted: service.isMuted,
      ),
      shouldRebuild: (prev, next) {
        // Only rebuild if these structural properties change.
        // This avoids rebuilding on volume updates or other ephemeral changes.
        return prev.isJoined != next.isJoined ||
            prev.isMinimized != next.isMinimized ||
            prev.currentRoomId != next.currentRoomId ||
            prev.isBroadcaster != next.isBroadcaster ||
            prev.isMuted != next.isMuted;
      },
      builder: (context, data, child) {
        if (!data.isJoined || !data.isMinimized || data.currentRoomId == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          right: 16 - _position.dx,
          bottom: 110 - _position.dy,
          child: GestureDetector(
            onPanStart: (_) => _isDragging = false,
            onPanUpdate: (details) {
              if (details.delta.distance > 0.1) _isDragging = true;
              setState(() {
                _position += details.delta;
                final double maxX = size.width - 120;
                final double maxY = size.height - 200;
                _position = Offset(
                  _position.dx.clamp(-maxX, 100),
                  _position.dy.clamp(-maxY, 100),
                );
              });
            },
            onPanEnd: (_) => setState(() => _isDragging = false),
            onPanCancel: () => setState(() => _isDragging = false),
            onTap: () {
              if (!_isDragging) {
                // Fetch service without listening to avoid loops
                final service = Provider.of<VoiceRoomService>(
                  context,
                  listen: false,
                );
                service.setMinimized(false);
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) =>
                        VoiceRoomScreen(
                          roomId: service.currentRoomId!,
                          initialRoomData: service.currentRoomData,
                        ),
                  ),
                );
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 130,
                height: 95,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF00BFA5).withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(data.currentRoomId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    String? imageUrl;
                    String roomName = 'غرفة نشطة';
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final roomData =
                          snapshot.data!.data() as Map<String, dynamic>;
                      imageUrl = roomData['imageUrl'];
                      roomName = roomData['name'] ?? roomName;
                    }

                    return Stack(
                      children: [
                        // 1. Audio Visualizer Background (Visual only, ignored for taps)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedBuilder(
                                animation: _waveController,
                                builder: (context, child) {
                                  return CustomPaint(
                                    painter: _WavePainter(
                                      animationValue: _waveController.value,
                                      color: const Color(
                                        0xFF00BFA5,
                                      ).withValues(alpha: 0.2),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // 2. Content
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Room Image
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child:
                                        (imageUrl != null &&
                                            imageUrl.isNotEmpty)
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.asset(
                                            'assets/images/user_placeholder.png',
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Text Marquee
                                Container(
                                  height: 14,
                                  width: 110,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: const BoxDecoration(),
                                  child: AnimatedBuilder(
                                    animation: _waveController,
                                    builder: (context, child) {
                                      double relativePosition =
                                          _waveController.value;
                                      double start = 1.0;
                                      double end = -1.0;
                                      double current =
                                          start +
                                          (end - start) * relativePosition;

                                      return Align(
                                        alignment: Alignment(current, 0),
                                        child: Text(
                                          roomName,
                                          maxLines: 1,
                                          overflow: TextOverflow.visible,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Tajawal',
                                            shadows: [
                                              Shadow(
                                                color: Colors.black,
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (data.isBroadcaster)
                                  Icon(
                                    data.isMuted ? Icons.mic_off : Icons.mic,
                                    color: data.isMuted
                                        ? Colors.redAccent
                                        : const Color(0xFF00BFA5),
                                    size: 12,
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // 3. Large Close Button (Dedicated Hit Area)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final service = Provider.of<VoiceRoomService>(
                                context,
                                listen: false,
                              );
                              service.leaveRoom();
                              service.setMinimized(false);
                            },
                            child: Container(
                              alignment: Alignment.topLeft,
                              padding: const EdgeInsets.all(8),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    int barCount = 12;
    double barWidth = size.width / barCount;

    for (int i = 0; i < barCount; i++) {
      double phase = (i / barCount) * math.pi * 2;
      double heightFactor =
          0.2 +
          (0.8 * (0.5 + 0.5 * math.sin(animationValue * math.pi * 4 + phase)));
      double barHeight = size.height * 0.3 * heightFactor;

      canvas.drawRect(
        Rect.fromLTWH(
          i * barWidth + 2,
          (size.height / 2) - (barHeight / 2),
          barWidth - 4,
          barHeight,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => true;
}
