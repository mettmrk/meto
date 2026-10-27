import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskType {
  login, // تسجيل الدخول يومياً
  sendMessage, // إرسال رسائل
  sendGift, // إرسال هدية
  joinRoom, // الانضمام لغرفة صوتية
  watchStory, // مشاهدة قصة
  addPost, // نشر منشور
  followUser, // متابعة مستخدم
  changeProfile, // تغيير الصورة الشخصية
  playLudo, // لعب لودو
  sitOnChair, // الجلوس على الكرسي
  commentPost, // كتابة تعليق
  likePost, // الإعجاب بمنشور
  spinWheel, // فر عجلة الحظ
  playCarRace, // لعب سباق السيارات
  playBombHunt, // لعب البحث عن القنبلة
  playTicTacToe, // لعب إكس أو
  shareApp, // مشاركة التطبيق
}

enum RewardType { diamonds, coins }

class DailyTask {
  final String id;
  final String title;
  final String description;
  final String icon; // emoji
  final int rewardAmount;
  final int expReward;
  final RewardType rewardType;
  final int requiredCount;
  final TaskType type;

  const DailyTask({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.rewardAmount,
    this.expReward = 10,
    required this.rewardType,
    required this.requiredCount,
    required this.type,
  });
}

class UserTaskProgress {
  final String taskId;
  final int currentCount;
  final bool isCompleted;
  final bool isClaimed;
  final DateTime? lastResetDate;

  const UserTaskProgress({
    required this.taskId,
    required this.currentCount,
    required this.isCompleted,
    required this.isClaimed,
    this.lastResetDate,
  });

  factory UserTaskProgress.fromMap(Map<String, dynamic> map) {
    return UserTaskProgress(
      taskId: map['taskId'] as String? ?? '',
      currentCount: (map['currentCount'] as num?)?.toInt() ?? 0,
      isCompleted: map['isCompleted'] as bool? ?? false,
      isClaimed: map['isClaimed'] as bool? ?? false,
      lastResetDate: map['lastResetDate'] != null
          ? (map['lastResetDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'currentCount': currentCount,
      'isCompleted': isCompleted,
      'isClaimed': isClaimed,
      'lastResetDate': lastResetDate != null
          ? Timestamp.fromDate(lastResetDate!)
          : null,
    };
  }

  UserTaskProgress copyWith({
    int? currentCount,
    bool? isCompleted,
    bool? isClaimed,
    DateTime? lastResetDate,
  }) {
    return UserTaskProgress(
      taskId: taskId,
      currentCount: currentCount ?? this.currentCount,
      isCompleted: isCompleted ?? this.isCompleted,
      isClaimed: isClaimed ?? this.isClaimed,
      lastResetDate: lastResetDate ?? this.lastResetDate,
    );
  }
}
