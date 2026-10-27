import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String? userProfileImage;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final List<String> likedBy; // الأشخاص الذين أعجبوا بالتعليق
  final String? parentId; // إذا كان رداً على تعليق آخر
  final String? replyTo; // اسم الشخص الذي يتم الرد عليه

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    this.userProfileImage,
    required this.content,
    required this.createdAt,
    this.likesCount = 0,
    this.likedBy = const [],
    this.parentId,
    this.replyTo,
  });

  // تحويل من Firestore Document
  factory Comment.fromMap(Map<String, dynamic> data, String id) {
    return Comment(
      id: id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      userProfileImage: data['userProfileImage'],
      content: data['content'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is String
                ? DateTime.parse(data['createdAt'])
                : (data['createdAt'] as Timestamp).toDate())
          : DateTime.now(),
      likesCount: data['likesCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      parentId: data['parentId'],
      replyTo: data['replyTo'],
    );
  }

  // تحويل إلى Map للحفظ في Firestore
  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'username': username,
      'userProfileImage': userProfileImage,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'likesCount': likesCount,
      'likedBy': likedBy,
      'parentId': parentId,
      'replyTo': replyTo,
    };
  }
}
