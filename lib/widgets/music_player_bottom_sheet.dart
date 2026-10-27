import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_room_service.dart';

class MusicPlayerBottomSheet extends StatelessWidget {
  const MusicPlayerBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<VoiceRoomService>(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF004D40),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'مشغل الموسيقى',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 32),

          // Seek Bar (Visible to everyone if playing)
          if (service.musicDuration > 0)
            Column(
              children: [
                Slider(
                  value: service.musicPosition.toDouble().clamp(
                    0.0,
                    service.musicDuration.toDouble(),
                  ),
                  min: 0.0,
                  max: service.musicDuration.toDouble(),
                  activeColor: const Color(0xFF00FFD1),
                  inactiveColor: Colors.white24,
                  onChanged: service.isMusicOwner 
                      ? (val) => service.seekMusic(val)
                      : null, // Read-only for others
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(service.musicPosition),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatDuration(service.musicDuration),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),

          // Player Controls Row (Only for owner)
          if (service.isMusicOwner)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Play/Pause
                GestureDetector(
                  onTap: () {
                    if (service.isMusicPlaying) {
                      if (service.isMusicPaused) {
                        service.resumeMusic();
                      } else {
                        service.pauseMusic();
                      }
                    } else {
                      service.toggleMusic(); // Start default
                    }
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FFD1).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00FFD1),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      (service.isMusicPlaying && !service.isMusicPaused)
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: const Color(0xFF00FFD1),
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Stop Button (Only if playing)
                if (service.isMusicPlaying)
                  GestureDetector(
                    onTap: () => service.stopMusic(), // Stops completely
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent, width: 2),
                      ),
                      child: const Icon(
                        Icons.stop_rounded,
                        color: Colors.redAccent,
                        size: 28,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          // File Picker Button (Only if no one is playing or if we are the owner)
          if (!service.isMusicPlaying || service.isMusicOwner)
            ElevatedButton.icon(
              onPressed: () => service.pickAndPlayAudio(),
              icon: const Icon(Icons.folder_open_rounded, color: Colors.white),
              label: const Text(
                'اختر من الجهاز',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
            ),

          const SizedBox(height: 16),
          if (service.selectedMusicName != null && service.isMusicPlaying)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                service.selectedMusicName!,
                style: const TextStyle(
                  color: Color(0xFF00FFD1),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          Text(
            service.isMusicPlaying ? 'جاري التشغيل...' : 'متوقف',
            style: TextStyle(
              color: service.isMusicPlaying
                  ? const Color(0xFF00FFD1)
                  : Colors.white60,
              fontSize: 14,
              fontFamily: 'Tajawal',
            ),
          ),

          const SizedBox(height: 32),

          // Volume Slider (Owner controls global volume, others control local volume)
          Row(
            children: [
              const Icon(Icons.volume_down, color: Colors.white60),
              Expanded(
                child: Slider(
                  value: service.musicVolume,
                  min: 0,
                  max: 100,
                  activeColor: const Color(0xFF00FFD1),
                  inactiveColor: Colors.white12,
                  onChanged: (val) => service.setMusicVolume(val),
                ),
              ),
              const Icon(Icons.volume_up, color: Colors.white60),
            ],
          ),

          const SizedBox(height: 16),
          const Text(
            'تنبيه: سيسمع الجميع هذه الموسيقى',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return "00:00";
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
