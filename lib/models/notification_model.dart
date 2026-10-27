import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { follow, comment, reply, like, gift, ludoInvite, system, support, agency, roomInvite, reward, mining }

class NotificationModel {
  final String id;
  final String receiverId;
  final String senderId;
  final String senderName;
  final String? senderProfileImage;
  final NotificationType type;
  final String? postId;
  final String? commentId;
  final String text;
  final String? roomId; // ID for Ludo or Voice Room
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.receiverId,
    required this.senderId,
    required this.senderName,
    this.senderProfileImage,
    required this.type,
    this.postId,
    this.commentId,
    this.roomId,
    required this.text,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'receiverId': receiverId,
      'senderId': senderId,
      'senderName': senderName,
      'senderProfileImage': senderProfileImage,
      'type': type.index,
      'postId': postId,
      'commentId': commentId,
      'roomId': roomId,
      'text': text,
      'createdAt': createdAt,
      'isRead': isRead,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    // Handle admin-sent broadcast notifications which use 'title'/'body'/'target'
    final isSystem = map['target'] == 'all' || map['type'] == 'system_broadcast';
    final isSupport = map['type'] == 'support_update' || (map['type'] is int && map['type'] == 7);
    
    NotificationType finalType;
    if (isSystem) {
      finalType = NotificationType.system;
    } else if (isSupport) {
      finalType = NotificationType.support;
    } else {
      final int typeIndex = map['type'] is int ? map['type'] : (int.tryParse(map['type']?.toString() ?? '0') ?? 0);
      finalType = NotificationType.values[typeIndex % NotificationType.values.length];
    }

    return NotificationModel(
      id: id,
      receiverId: map['receiverId'] ?? '',
      senderId: map['senderId'] ?? (isSystem || isSupport ? 'system' : ''),
      senderName: map['senderName'] ?? map['title'] ?? (isSystem ? 'إشعار من الإدارة' : (isSupport ? 'الدعم الفني' : '')),
      senderProfileImage: map['senderProfileImage'],
      type: finalType,
      postId: map['postId'],
      commentId: map['commentId'],
      roomId: map['roomId'],
      text: map['text'] ?? map['body'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }
}
