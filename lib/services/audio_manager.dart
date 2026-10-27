import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// مدير مشغل الصوت العالمي لضمان تشغيل بصمة واحدة فقط في المرة الواحدة
/// Global Audio Manager to ensure only one voice message plays at a time (WhatsApp style)
class GlobalAudioManager {
  static final GlobalAudioManager _instance = GlobalAudioManager._internal();
  factory GlobalAudioManager() => _instance;
  GlobalAudioManager._internal();

  AudioPlayer? _currentPlayer;
  final ValueNotifier<String?> _activeAudioUrl = ValueNotifier<String?>(null);

  ValueNotifier<String?> get activeAudioUrl => _activeAudioUrl;

  Future<void> play(AudioPlayer player, String url) async {
    // إذا كان هناك مشغل آخر يعمل، قم بإيقافه
    if (_currentPlayer != null && _currentPlayer != player) {
      await _currentPlayer!.pause();
    }
    
    _currentPlayer = player;
    _activeAudioUrl.value = url;
    await player.play();
  }

  Future<void> pause(AudioPlayer player) async {
    if (_currentPlayer == player) {
      await player.pause();
      // لا نصفر activeAudioUrl هنا ليبقى المؤشر على الحالة الحالية
    }
  }

  void stopIfPlaying(AudioPlayer player) {
    if (_currentPlayer == player) {
      _currentPlayer = null;
      _activeAudioUrl.value = null;
    }
  }

  void disposePlayer(AudioPlayer player) {
    if (_currentPlayer == player) {
      _currentPlayer = null;
      _activeAudioUrl.value = null;
    }
  }
}
