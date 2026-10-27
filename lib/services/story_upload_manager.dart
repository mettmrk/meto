import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/story_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';

class StoryUploadManager {
  static final StoryUploadManager _instance = StoryUploadManager._internal();
  static StoryUploadManager get instance => _instance;

  StoryUploadManager._internal();

  final ValueNotifier<bool> isUploading = ValueNotifier<bool>(false);

  Future<void> uploadStory({
    required File file,
    String? caption,
    required bool isVideo,
  }) async {
    if (isUploading.value) return;

    isUploading.value = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not logged in';

      final userData = await UserService().getUser(user.uid);

      final mediaUrl = await StorageService().uploadStoryMedia(
        userId: user.uid,
        file: file,
      );

      await StoryService().createStory(
        userId: user.uid,
        username: userData?.nickname ?? userData?.username ?? 'مستخدم',
        userProfileImage: userData?.profileImage,
        storyImage: isVideo ? null : mediaUrl,
        storyVideo: isVideo ? mediaUrl : null,
        caption: caption,
      );

      print('Story uploaded successfully');
    } catch (e) {
      print('Error uploading story: $e');
      // Maybe show a notification or toast?
      // Since UI is gone, we can't show SnackBar easily without context.
    } finally {
      isUploading.value = false;
    }
  }
}
