import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PreloadService {
  static final PreloadService _instance = PreloadService._internal();
  factory PreloadService() => _instance;
  PreloadService._internal();

  bool _isPreloading = false;

  /// Call this when the app starts or when the user enters the room list.
  /// It silently downloads Lottie JSON, SVGA, and MP4 gifts into the local cache.
  Future<void> preloadGiftAnimations() async {
    if (_isPreloading) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("PreloadService: User is not authenticated. Skipping gift preload.");
      return;
    }
    _isPreloading = true;

    try {
      final snapshot = await FirebaseFirestore.instance.collection('gifts').get();
      final cacheManager = DefaultCacheManager();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String? lottieUrl = data['lottieUrl'];
        if (lottieUrl != null && lottieUrl.isNotEmpty && lottieUrl.startsWith('http')) {
          try {
            final fileInfo = await cacheManager.getFileFromCache(lottieUrl);
            if (fileInfo == null) {
              // Not in cache, download it silently
              debugPrint("Preloading gift animation: $lottieUrl");
              await cacheManager.downloadFile(lottieUrl);
            }
          } catch (e) {
            debugPrint("Failed to preload $lottieUrl: $e");
          }
        }
      }
      debugPrint("Gift animations preload complete!");
    } catch (e) {
      debugPrint("Error in preloadGiftAnimations: $e");
    } finally {
      _isPreloading = false;
    }
  }

  /// Use this helper anywhere to get a File or fallback to network string.
  /// Used to ensure VideoPlayer, SVGA, and Lottie use the cached file if available.
  Future<String?> getCachedFilePath(String url) async {
    if (url.isEmpty || !url.startsWith('http')) return null;
    try {
      final fileInfo = await DefaultCacheManager().getFileFromCache(url);
      if (fileInfo != null && await fileInfo.file.exists()) {
        return fileInfo.file.path;
      }
    } catch (e) {
      debugPrint("Error checking cache for $url: $e");
    }
    return null;
  }
}
