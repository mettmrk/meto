import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/audio_manager.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final int? duration;
  final DateTime timestamp;
  final String status; // 'pending', 'sent', 'failed'
  final String? profileImage;
  final bool isRead;
  final bool isDelivered;

  const VoiceMessageBubble({
    super.key,
    required this.audioUrl,
    required this.isMe,
    this.duration,
    required this.timestamp,
    this.status = 'sent',
    this.profileImage,
    this.isRead = false,
    this.isDelivered = false,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _durationSubscription;


  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
  }

  @override
  void didUpdateWidget(VoiceMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl) {
      _setupAudioSource(widget.audioUrl).catchError((e) {
        debugPrint('Error updating audio source: $e');
        return null;
      });
    }
  }

  Future<void> _setupAudioSource(String url, {int retryCount = 0}) async {
    try {
      if (url.isEmpty) return;
      
      if (url.startsWith('http')) {
        await _player.setUrl(url);
      } else {
        // If it's a local path, use setFilePath
        await _player.setFilePath(url);
      }
    } catch (e) {
      debugPrint('Error setting up audio source (Attempt ${retryCount + 1}): $e');
      
      // If it's a Source error (often transient on network files)
      if (retryCount < 2 && url.startsWith('http')) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) return _setupAudioSource(url, retryCount: retryCount + 1);
      }
      rethrow;
    }
  }

  Future<void> _initPlayer() async {
    try {
      await _player.setVolume(1.0);
      await _setupAudioSource(widget.audioUrl);

      _durationSubscription = _player.durationStream.listen((d) {
        if (mounted) {
          setState(() => _totalDuration = d ?? Duration.zero);
        }
      });

      _positionSubscription = _player.positionStream.listen((p) {
        if (mounted) setState(() => _currentPosition = p);
      });

      _playerStateSubscription = _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _isPlaying = false;
              _player.seek(Duration.zero);
              _player.pause();
              GlobalAudioManager().stopIfPlaying(_player); // Clean up globally
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Silent error during audio pre-load: $e');
      // We no longer show a SnackBar during initialization to avoid annoying transient errors.
      // The error will be handled if the user tries to play the audio and it fails.
    }
  }

  void _showError(dynamic e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('خطأ في تشغيل البصمة: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    GlobalAudioManager().disposePlayer(_player); // Inform global manager
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await GlobalAudioManager().pause(_player);
    } else {
      try {
        // If player is idle or has error, try to load again
        if (_player.processingState == ProcessingState.idle) {
          await _setupAudioSource(widget.audioUrl);
        }
        await GlobalAudioManager().play(_player, widget.audioUrl);
      } catch (e) {
        _showError(e);
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigitMinutes = duration.inMinutes.remainder(60).toString().padLeft(2, "0");
    String twoDigitSeconds = duration.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildStatusIndicator(Color color) {
    if (widget.isRead) {
      return const Icon(Icons.done_all, size: 13, color: Colors.blue);
    }
    if (widget.isDelivered) {
      return Icon(Icons.done_all, size: 13, color: color);
    }
    
    switch (widget.status) {
      case 'pending':
        return Icon(Icons.access_time, size: 10, color: color);
      case 'sent':
        return Icon(Icons.check, size: 13, color: color);
      case 'failed':
        return Icon(Icons.error_outline, size: 10, color: Colors.red.shade300);
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatTime(DateTime timestamp) {
    int hour = timestamp.hour;
    String period = hour >= 12 ? 'م' : 'ص';
    if (hour > 12)
      hour = hour - 12;
    else if (hour == 0)
      hour = 12;
    String minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final color = Colors.white;
    final secondaryColor = Colors.white70;

    final progress = _totalDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    final barWidth = 2.5;
    final spacing = 2.0;

    // حساب العرض الكلي (ثلاث أرباع الشاشة)
    final totalWidth = MediaQuery.of(context).size.width * 0.75;
    // استبعاد مساحة الصورة وزر التشغيل والمسافات الفاصلة
    final remainingWidth = totalWidth - 85; 

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: totalWidth,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            // صورة المرسل
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: Colors.white24,
                  child: ClipOval(
                    child: widget.profileImage != null &&
                            widget.profileImage!.isNotEmpty
                        ? (widget.profileImage!.startsWith('assets/')
                            ? Image.asset(
                                widget.profileImage!,
                                width: 34,
                                height: 34,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                widget.profileImage!,
                                width: 34,
                                height: 34,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                  Icons.person,
                                  color: color.withOpacity(0.8),
                                  size: 18,
                                ),
                              ))
                        : Icon(
                            Icons.person,
                            color: color.withOpacity(0.8),
                            size: 18,
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.teal,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(1.5),
                    child: const Icon(
                      Icons.mic,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // زر التشغيل
            GestureDetector(
              onTap: _togglePlay,
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 6),
            // الجزء المتبقي (الموجة والوقت)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // الموجة الصوتية
                  GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      final percent =
                          (details.localPosition.dx / remainingWidth).clamp(0.0, 1.0);
                      final seekTo = _totalDuration.inMilliseconds * percent;
                      _player.seek(Duration(milliseconds: seekTo.toInt()));
                    },
                    onTapDown: (details) {
                      final percent =
                          (details.localPosition.dx / remainingWidth).clamp(0.0, 1.0);
                      final seekTo = _totalDuration.inMilliseconds * percent;
                      _player.seek(Duration(milliseconds: seekTo.toInt()));
                    },
                    child: Container(
                      height: 20,
                      width: remainingWidth,
                      color: Colors.transparent,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availableWidth = constraints.maxWidth;
                          final barFullWidth = barWidth + spacing;
                          final barsToDraw = (availableWidth / barFullWidth).floor();
                          
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(barsToDraw, (index) {
                              final barPercent = index / barsToDraw;
                              final isActive = barPercent <= progress;
                              final barHeight = (math.Random(index).nextDouble() * 12 + 3);

                              return Container(
                                margin: EdgeInsets.only(right: spacing),
                                width: barWidth,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: isActive ? color : color.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          );
                        }
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // صف الوقت والحالة
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(widget.timestamp),
                              style: TextStyle(
                                fontSize: 9,
                                color: secondaryColor,
                              ),
                            ),
                            if (widget.isMe) ...[
                              const SizedBox(width: 4),
                              _buildStatusIndicator(secondaryColor),
                            ],
                          ],
                        ),
                        Text(
                          _isPlaying || _currentPosition.inSeconds > 0
                              ? _formatDuration(_currentPosition)
                              : (_totalDuration.inSeconds > 0
                                  ? _formatDuration(_totalDuration)
                                  : widget.duration != null &&
                                          widget.duration! > 0
                                      ? _formatDuration(
                                          Duration(seconds: widget.duration!),
                                        )
                                      : "00:00"),
                          style: TextStyle(color: secondaryColor, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
