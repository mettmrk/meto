class Post {
  final String id;
  final String userId;
  final String username;
  final String? userProfileImage;
  final String content;
  final List<String> images;
  final String province; // المحافظة
  final String category; // نوع المفقود
  final DateTime createdAt;
  final int likesCount;
  final int dislikesCount; // لا يعجبني
  final int commentsCount;
  final List<String> likedBy;
  final List<String> dislikedBy; // قائمة غير المعجبين
  final Map<String, String>
  reactions; // userId -> type (like, love, haha, wow, sad, angry)
  final int giftsCount; // الهدايا
  final DateTime expiresAt; // تاريخ انتهاء الصلاحية
  final List<int> rewardedReactionsMilestones; // عتبات التفاعل المكافأ عليها (50, 100, 150...)
  final Map<String, String> milestoneReachedDates; // milestone -> تاريخ الوصول (لمنع التكرار اليومي)

  // حقول المشاركة (Repost)
  final bool isShared;
  final String? originalPostId;
  final String? originalUserId;
  final String? originalUsername;

  Post({
    required this.id,
    required this.userId,
    required this.username,
    this.userProfileImage,
    required this.content,
    this.images = const [],
    required this.province,
    required this.category,
    required this.createdAt,
    required this.expiresAt,
    this.likesCount = 0,
    this.dislikesCount = 0,
    this.commentsCount = 0,
    this.likedBy = const [],
    this.dislikedBy = const [],
    this.reactions = const {},
    this.giftsCount = 0,
    this.isShared = false,
    this.originalPostId,
    this.originalUserId,
    this.originalUsername,
    this.rewardedReactionsMilestones = const [],
    this.milestoneReachedDates = const {},
  });

  factory Post.fromMap(Map<String, dynamic> data, String id) {
    return Post(
      id: id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      userProfileImage: data['userProfileImage'],
      content: data['content'] ?? '',
      images: List<String>.from(data['images'] ?? []),
      province: data['province'] ?? 'غير محدد',
      category: data['category'] ?? 'منوعات',
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      expiresAt: data['expiresAt'] != null
          ? DateTime.parse(data['expiresAt'])
          : DateTime.now().add(const Duration(hours: 48)),
      likesCount: data['likesCount'] ?? 0,
      dislikesCount: data['dislikesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      dislikedBy: List<String>.from(data['dislikedBy'] ?? []),
      // Reactions map: userId -> reactionType
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      giftsCount: data['giftsCount'] ?? 0,
      isShared: data['isShared'] ?? false,
      originalPostId: data['originalPostId'],
      originalUserId: data['originalUserId'],
      originalUsername: data['originalUsername'],
      rewardedReactionsMilestones: List<int>.from(data['rewardedReactionsMilestones'] ?? []),
      milestoneReachedDates: Map<String, String>.from(data['milestoneReachedDates'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'userProfileImage': userProfileImage,
      'content': content,
      'images': images,
      'province': province,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'likesCount': likesCount,
      'dislikesCount': dislikesCount,
      'commentsCount': commentsCount,
      'likedBy': likedBy,
      'dislikedBy': dislikedBy,
      'reactions': reactions,
      'giftsCount': giftsCount,
      'isShared': isShared,
      'originalPostId': originalPostId,
      'originalUserId': originalUserId,
      'originalUsername': originalUsername,
      'rewardedReactionsMilestones': rewardedReactionsMilestones,
      'milestoneReachedDates': milestoneReachedDates,
    };
  }
}
