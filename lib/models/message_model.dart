import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final bool isDelivered;
  final String type; // 'text', 'audio', 'image'
  final String? mediaUrl;
  final int? duration; // for audio
  final String status; // 'pending', 'sent', 'failed'

  // حقول الحذف والتعديل
  final List<String>
  isDeletedForMe; // قائمة معرفات المستخدمين الذين حذفوا الرسالة لديهم
  final bool isDeletedForEveryone; // هل تم حذف الرسالة للجميع
  final bool isEdited; // هل تم تعديل الرسالة
  final DateTime? editedAt; // وقت آخر تعديل

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.isDelivered = false,
    this.type = 'text',
    this.mediaUrl,
    this.duration,
    this.status = 'sent',
    this.isDeletedForMe = const [],
    this.isDeletedForEveryone = false,
    this.isEdited = false,
    this.editedAt,
  });

  factory Message.fromMap(Map<String, dynamic> data, String id) {
    return Message(
      id: id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : (data['serverTimestamp'] != null 
              ? (data['serverTimestamp'] as Timestamp).toDate() 
              : DateTime.now()),
      isRead: data['isRead'] ?? false,
      isDelivered: data['isDelivered'] ?? false,
      type: data['type'] ?? 'text',
      mediaUrl: data['mediaUrl'],
      duration: data['duration'],
      status: data['status'] ?? 'sent',
      isDeletedForMe: List<String>.from(data['isDeletedForMe'] ?? []),
      isDeletedForEveryone: data['isDeletedForEveryone'] ?? false,
      isEdited: data['isEdited'] ?? false,
      editedAt: data['editedAt'] != null
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'isDelivered': isDelivered,
      'type': type,
      'mediaUrl': mediaUrl,
      'duration': duration,
      'status': status,
      'isDeletedForMe': isDeletedForMe,
      'isDeletedForEveryone': isDeletedForEveryone,
      'isEdited': isEdited,
      'editedAt': editedAt,
    };
  }

  // دالة مساعدة لنسخ الرسالة مع تعديلات
  Message copyWith({
    String? text,
    bool? isRead,
    bool? isDelivered,
    List<String>? isDeletedForMe,
    bool? isDeletedForEveryone,
    bool? isEdited,
    DateTime? editedAt,
    String? status,
  }) {
    return Message(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      text: text ?? this.text,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      type: type,
      mediaUrl: mediaUrl,
      duration: duration,
      status: status ?? this.status,
      isDeletedForMe: isDeletedForMe ?? this.isDeletedForMe,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
    );
  }
}

class Chat {
  final String id; // This will be the combination of two UIDs: sorted_uid1_uid2
  final List<String> participants;
  final String lastMessage;
  final DateTime lastTimestamp;
  final Map<String, int> unreadCounts;
  final Map<String, bool> typingStatus;
  final Map<String, bool> recordingStatus;

  Chat({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastTimestamp,
    required this.unreadCounts,
    this.typingStatus = const {},
    this.recordingStatus = const {},
  });

  factory Chat.fromMap(Map<String, dynamic> data, String id) {
    return Chat(
      id: id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastTimestamp: data['lastTimestamp'] != null
          ? (data['lastTimestamp'] as Timestamp).toDate()
          : DateTime.now(),
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      typingStatus: Map<String, bool>.from(data['typingStatus'] ?? {}),
      recordingStatus: Map<String, bool>.from(data['recordingStatus'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'unreadCounts': unreadCounts,
      'typingStatus': typingStatus,
      'recordingStatus': recordingStatus,
    };
  }
}
