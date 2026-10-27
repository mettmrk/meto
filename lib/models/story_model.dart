class Story {
  final String id;
  final String userId;
  final String username;
  final String? userProfileImage;
  final String? storyImage;
  final String? storyVideo; // للفيديوهات
  final String? caption;
  final DateTime createdAt;
  final DateTime? expiresAt; // ينتهي بعد 24 ساعة
  final List<String> viewedBy; // من شاهده
  final Map<String, String> reactions; // التفاعلات (userId: emoji)

  Story({
    required this.id,
    required this.userId,
    required this.username,
    this.userProfileImage,
    this.storyImage,
    this.storyVideo,
    this.caption,
    required this.createdAt,
    this.expiresAt,
    this.viewedBy = const [],
    this.reactions = const {},
  });

  // تحويل من Firestore Document
  factory Story.fromMap(Map<String, dynamic> data, String id) {
    return Story(
      id: id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      userProfileImage: data['userProfileImage'],
      storyImage: data['storyImage'],
      storyVideo: data['storyVideo'],
      caption: data['caption'],
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      expiresAt: data['expiresAt'] != null
          ? DateTime.parse(data['expiresAt'])
          : DateTime.now().add(const Duration(hours: 24)),
      viewedBy: List<String>.from(data['viewedBy'] ?? []),
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
    );
  }

  // تحويل إلى Map للحفظ في Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'userProfileImage': userProfileImage,
      'storyImage': storyImage,
      'storyVideo': storyVideo,
      'caption': caption,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': (expiresAt ?? DateTime.now().add(const Duration(hours: 24)))
          .toIso8601String(),
      'viewedBy': viewedBy,
      'reactions': reactions,
    };
  }

  bool isExpired() {
    return DateTime.now().isAfter(expiresAt ?? DateTime.now());
  }
}
