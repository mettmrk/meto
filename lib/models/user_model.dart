import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;

class User {
  final String uid;
  final String username;
  final String email;
  final String? profileImage; // رابط الصورة
  final String? coverImage; // صورة الغلاف
  final String? bio; // السيرة الذاتية
  final String? nickname; // الكنية
  final int followersCount;
  final int followingCount;
  final List<String> followers; // قائمة معرفات المتابعين
  final List<String> following; // قائمة معرفات المتابعين
  final DateTime createdAt;
  final String? displayId; // المعرف الرقمي المكون من 6 أرقام
  final String? originalDisplayId; // المعرف الرقمي الأصلي للحساب
  final String? displayIdImage; // رابط صورة المعرف المميز
  final List<String> blockedUsers; // قائمة المحظورين
  final List<String> mutedUsers; // قائمة المصمتين
  final List<String> blacklistedUsers; // القائمة السوداء
  final bool isOnline; // حالة الاتصال
  final DateTime? lastSeen; // آخر ظهور
  final int coins; // رصيد العملات
  final int profitPoints; // نقاط ربحية (المكافأة المتراكمة)
  final int diamonds; // ماسات
  final int meto_chips; // العملة الخضراء للعدادات
  final int pointsPerClaim; // النقاط المكتسبة في كل مرة ينتهي فيها العداد
  final bool isSubscribed; // هل المستخدم مشترك في الخدمة
  final DateTime? subscriptionExpiry; // تاريخ انتهاء الاشتراك بالعداد
  final DateTime? lastDailyRewardClaim; // تاريخ آخر استلام للمكافأة اليومية
  final int freeSpins; // عدد اللفات المجانية الإضافية
  final int level; // مستوى المستخدم
  final String? sessionId; // معرف الجلسة الحالية لتجنب تسجيل الدخول من جهازين
  final int dailyDiamonds; // الماسات المكتسبة اليوم
  final int dailyCoins; // الذهب المكتسب اليوم من العداد
  final int dailyMetoChips; // عملات ميتو المكتسبة اليوم من العداد
  final DateTime? lastDailyDiamondsReset; // تاريخ آخر إعادة تعيين للماسات اليومية
  final DateTime? lastDailyCoinsReset; // تاريخ آخر إعادة تعيين للذهب اليومي
  final DateTime? lastDailyTasksReset; // تاريخ آخر إعادة تعيين للمهام
  final int dailyPostsCount; // عدد البوستات المنشورة اليوم
  final DateTime? lastPostResetDate; // تاريخ آخر تصفير/نشر للبوستات اليومية
  final bool isBanned;
  final bool isSuspended;
  final bool isDisabled;
  final String? banReason;
  final bool isPrivate; // الحساب الخاص
  final List<String> followedRooms; // قائمة الغرف التي انضم إليها
  final int totalContributionToInviter; // إجمالي المساهمة لصاحب الفريق
  
  // لدو وإحصائيات اللعب
  final int gamesPlayed;
  final int wins;
  final int losses;
  final Map<String, dynamic> gameStats; // إحصائيات كل لعبة بشكل منفصل

  // إحصائيات بطولة الدوري
  final int leagueRank;
  final int bestLeagueRank;

  // نظام الدعوات
  final String? referralCode; // الكود الذي يشارك به المستخدم أصدقاءه
  final String? referredBy; // معرف المستخدم الذي دعاه (إن وجد)
  final List<String> referredUsers; // قائمة المستخدمين الذين قام بدعوتهم
  final DateTime?
  lastReferralRewardDate; // تاريخ آخر احتساب لمكافآت الدعوات اليومية

  final List<String> ownedFrames; // قائمة الإطارات المملوكة
  final List<String>
  ownedDecorations; // قائمة زينة البروفايل (بطاقات الملف الشخصي)

  // معلومات شخصية إضافية
  final String? city; // المدينة
  final String? country; // الدولة (علم)
  final DateTime? birthDate; // تاريخ الميلاد
  final String? gender; // الجنس (male/female)
  final String? relationshipStatus; // الحالة الاجتماعية
  final String? work; // العمل
  final String? profileFrame; // إطار الصورة الشخصية
  final String? profileDecoration; // زينة البروفايل النشطة (بطاقة الملف الشخصي)
  final String? verificationTier; // نوع التوثيق: blue, gold, vip
  final List<String> ownedEntrances; // الدخوليات المملوكة
  final int exp; // نقاط الخبرة
  final String? roomEntrance; // دخول الغرفة النشط
  final String? ludoTokenTheme; // طقم قطع لودو النشط
  final String? ludoBoardTheme; // طقم لوحة لودو النشط
  final String? profilePhotoAnimation; // رابط الصورة المتحركة (SVGA/GIF)
  final String? ludoDiceTheme; // طقم نرد لودو النشط
  final String? ludoHallTheme; // طقم قاعة لودو النشط
  final String? verificationIcon; // رابط أيقونة التوثيق النشطة
  final List<String> traits; // السمات الشخصية
  final List<String> ownedCardBorders; // حدود البطاقات المملوكة
  final String? profileCardBorder; // حد البطاقة النشط
  final List<String> ownedSpecialIds; // قائمة المعرفات المميزة المملوكة
  final List<String> ownedSpecialIdImages; // قائمة صور المعرفات المميزة المملوكة
  final List<String> ownedWallHangings; // معلقات جدارية مملوكة
  final String? activeWallHanging; // معلقة جدارية نشطة
  final List<String> ownedRoomCardBorders; // إطارات الغرف المملوكة
  final String? activeRoomCardBorder; // إطار الغرفة النشط

  // Calculate next level XP requirement
  int get nextLevelExp => level * 100;

  // Calculate progress to next level (0.0 to 1.0)
  double get levelProgress {
    if (nextLevelExp == 0) return 0.0;
    return (exp / nextLevelExp).clamp(0.0, 1.0);
  }

  bool get isVerified =>
      verificationTier != null && verificationTier!.isNotEmpty;

  User({
    required this.uid,
    required this.username,
    required this.email,
    this.profileImage,
    this.coverImage,
    this.bio,
    this.nickname,
    this.followersCount = 0,
    this.followingCount = 0,
    this.followers = const [],
    this.following = const [],
    this.blockedUsers = const [],
    this.mutedUsers = const [],
    this.blacklistedUsers = const [],
    this.ownedFrames = const [],
    this.ownedDecorations = const [],
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
    this.displayId,
    this.originalDisplayId,
    this.displayIdImage,
    this.city,
    this.country,
    this.birthDate,
    this.gender,
    this.relationshipStatus,
    this.work,
    this.profileFrame,
    this.profileDecoration,
    this.verificationTier,
    this.coins = 0,
    this.profitPoints = 0,
    this.diamonds = 0,
    this.meto_chips = 0,
    this.pointsPerClaim = 0,
    this.isSubscribed = false,
    this.subscriptionExpiry,
    this.lastDailyRewardClaim,
    this.freeSpins = 0,
    this.level = 1,
    this.sessionId,
    this.dailyDiamonds = 0,
    this.dailyCoins = 0,
    this.dailyMetoChips = 0,
    this.lastDailyDiamondsReset,
    this.lastDailyCoinsReset,
    this.lastDailyTasksReset,
    this.dailyPostsCount = 0,
    this.lastPostResetDate,
    this.exp = 0,
    this.roomEntrance,
    this.ludoTokenTheme,
    this.ludoBoardTheme,
    this.ludoDiceTheme,
    this.ludoHallTheme,
    this.verificationIcon,
    this.referralCode,
    this.referredBy,
    this.referredUsers = const [],
    this.profilePhotoAnimation,
    this.lastReferralRewardDate,
    this.isBanned = false,
    this.isSuspended = false,
    this.isDisabled = false,
    this.banReason,
    this.isPrivate = false,
    this.followedRooms = const [],
    this.traits = const [],
    this.ownedCardBorders = const [],
    this.profileCardBorder,
    this.ownedSpecialIds = const [],
    this.ownedSpecialIdImages = const [],
    this.ownedWallHangings = const [],
    this.activeWallHanging,
    this.ownedRoomCardBorders = const [],
    this.activeRoomCardBorder,
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.gameStats = const {},
    this.leagueRank = 0,
    this.bestLeagueRank = 0,
    this.totalContributionToInviter = 0,
    this.ownedEntrances = const [],
  });

  // تحسين: دالة لعرض حالة التواجد
  String get formatStatus {
    if (isOnline) return 'نشط الآن';
    if (lastSeen == null) return 'غير نشط';
    return 'نشط منذ ${timeago.format(lastSeen!, locale: 'ar')}';
  }

  // تحويل من Firestore Document
  factory User.fromMap(Map<String, dynamic> data, String uid) {
    return User(
      uid: uid,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      profileImage: data['profileImage'],
      coverImage: data['coverImage'],
      bio: data['bio'],
      nickname: data['nickname'],
      followersCount: data['followersCount'] ?? 0,
      followingCount: data['followingCount'] ?? 0,
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      mutedUsers: List<String>.from(data['mutedUsers'] ?? []),
      blacklistedUsers: List<String>.from(data['blacklistedUsers'] ?? []),
      ownedFrames: List<String>.from(data['ownedFrames'] ?? []),
      ownedDecorations: List<String>.from(data['ownedDecorations'] ?? []),
      isOnline: data['isOnline'] ?? false,
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] is Timestamp 
              ? (data['lastSeen'] as Timestamp).toDate() 
              : DateTime.tryParse(data['lastSeen'].toString()))
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp 
              ? (data['createdAt'] as Timestamp).toDate() 
              : DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      displayId: data['displayId']?.toString(),
      originalDisplayId: data['originalDisplayId']?.toString(),
      displayIdImage: data['displayIdImage'],
      city: data['city'],
      country: data['country'],
      birthDate: data['birthDate'] != null
          ? (data['birthDate'] is Timestamp 
              ? (data['birthDate'] as Timestamp).toDate() 
              : DateTime.tryParse(data['birthDate'].toString()))
          : null,
      gender: data['gender'],
      relationshipStatus: data['relationshipStatus'],
      work: data['work'],
      profileFrame: data['profileFrame'],
      profileDecoration: data['profileDecoration'],

      verificationTier:
          data['verificationTier'] ??
          (data['isVerified'] == true ? 'blue' : null),
      coins: data['coins'] ?? 0,
      profitPoints: data['profitPoints'] ?? 0,
      diamonds: data['diamonds'] ?? 0,
      meto_chips: data['meto_chips'] ?? 0,
      pointsPerClaim: data['pointsPerClaim'] ?? 0,
      isSubscribed: data['isSubscribed'] ?? false,
      subscriptionExpiry: data['subscriptionExpiry'] != null
          ? (data['subscriptionExpiry'] is Timestamp
                ? (data['subscriptionExpiry'] as Timestamp).toDate()
                : DateTime.tryParse(data['subscriptionExpiry'].toString()))
          : null,
      lastDailyRewardClaim: data['lastDailyRewardClaim'] != null
          ? (data['lastDailyRewardClaim'] is Timestamp
                ? (data['lastDailyRewardClaim'] as Timestamp).toDate()
                : DateTime.tryParse(data['lastDailyRewardClaim'].toString()))
          : null,
      freeSpins: data['freeSpins'] ?? 0,
      level: data['level'] ?? 1,
      sessionId: data['sessionId'],
      dailyDiamonds: data['dailyDiamonds'] ?? 0,
      dailyCoins: data['dailyCoins'] ?? 0,
      dailyMetoChips: data['dailyMetoChips'] ?? 0,
      lastDailyDiamondsReset: data['lastDailyDiamondsReset'] != null
          ? (data['lastDailyDiamondsReset'] is Timestamp
                ? (data['lastDailyDiamondsReset'] as Timestamp).toDate()
                : DateTime.tryParse(data['lastDailyDiamondsReset'].toString()))
          : null,
      lastDailyCoinsReset: data['lastDailyCoinsReset'] != null
          ? (data['lastDailyCoinsReset'] is Timestamp
                ? (data['lastDailyCoinsReset'] as Timestamp).toDate()
                : DateTime.tryParse(data['lastDailyCoinsReset'].toString()))
          : null,
      lastDailyTasksReset: data['lastDailyTasksReset'] != null
          ? (data['lastDailyTasksReset'] is Timestamp
                ? (data['lastDailyTasksReset'] as Timestamp).toDate()
                : DateTime.tryParse(data['lastDailyTasksReset'].toString()))
          : null,
      dailyPostsCount: data['dailyPostsCount'] ?? 0,
      lastPostResetDate: data['lastPostResetDate'] != null
          ? (data['lastPostResetDate'] is Timestamp
                ? (data['lastPostResetDate'] as Timestamp).toDate()
                : DateTime.tryParse(data['lastPostResetDate'].toString()))
          : null,
      exp: data['exp'] ?? 0,
      roomEntrance: data['roomEntrance'],
      ludoTokenTheme: data['ludoTokenTheme'],
      ludoBoardTheme: data['ludoBoardTheme'],
      ludoDiceTheme: data['ludoDiceTheme'],
      ludoHallTheme: data['ludoHallTheme'],
      profilePhotoAnimation: data['profilePhotoAnimation'],
      verificationIcon: data['verificationIcon'],
      referralCode: data['referralCode']?.toString(),
      referredBy: data['referredBy'],
      referredUsers: List<String>.from(data['referredUsers'] ?? []),
      lastReferralRewardDate: data['lastReferralRewardDate'] != null
          ? (data['lastReferralRewardDate'] is Timestamp
                ? (data['lastReferralRewardDate'] as Timestamp).toDate()
                : DateTime.tryParse(data['lastReferralRewardDate'].toString()))
          : null,
      isBanned: data['isBanned'] ?? false,
      isSuspended: data['isSuspended'] ?? false,
      isDisabled: data['isDisabled'] ?? false,
      banReason: data['banReason'],
      isPrivate: data['isPrivate'] ?? false,
      traits: List<String>.from(data['traits'] ?? []),
      ownedCardBorders: List<String>.from(data['ownedCardBorders'] ?? []),
      profileCardBorder: data['profileCardBorder'],
      ownedSpecialIds: List<String>.from(data['ownedSpecialIds'] ?? []),
      ownedSpecialIdImages: List<String>.from(data['ownedSpecialIdImages'] ?? []),
      ownedWallHangings: List<String>.from(data['ownedWallHangings'] ?? []),
      activeWallHanging: data['activeWallHanging'],
      ownedRoomCardBorders: List<String>.from(data['ownedRoomCardBorders'] ?? []),
      activeRoomCardBorder: data['activeRoomCardBorder'],
      gamesPlayed: data['gamesPlayed'] ?? 0,
      wins: data['wins'] ?? 0,
      losses: data['losses'] ?? 0,
      gameStats: Map<String, dynamic>.from(data['gameStats'] ?? {}),
      leagueRank: data['leagueRank'] ?? 0,
      bestLeagueRank: data['bestLeagueRank'] ?? 0,
      followedRooms: List<String>.from(data['followedRooms'] ?? []),
      totalContributionToInviter: data['totalContributionToInviter'] ?? 0,
      ownedEntrances: List<String>.from(data['ownedEntrances'] ?? []),
    );
  }

  // تحويل إلى Map للحفظ في Firestore
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'profileImage': profileImage,
      'coverImage': coverImage,
      'bio': bio,
      'nickname': nickname,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'followers': followers,
      'following': following,
      'blockedUsers': blockedUsers,
      'mutedUsers': mutedUsers,
      'blacklistedUsers': blacklistedUsers,
      'ownedFrames': ownedFrames,
      'ownedDecorations': ownedDecorations,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'displayId': displayId,
      'originalDisplayId': originalDisplayId,
      'displayIdImage': displayIdImage,
      'city': city,
      'country': country,
      'birthDate': birthDate?.toIso8601String(),
      'gender': gender,
      'relationshipStatus': relationshipStatus,
      'work': work,
      'profileFrame': profileFrame,
      'profileDecoration': profileDecoration,
      'verificationTier': verificationTier,
      'coins': coins,
      'profitPoints': profitPoints,
      'diamonds': diamonds,
      'meto_chips': meto_chips,
      'pointsPerClaim': pointsPerClaim,
      'isSubscribed': isSubscribed,
      'subscriptionExpiry': subscriptionExpiry?.toIso8601String(),
      'lastDailyRewardClaim': lastDailyRewardClaim?.toIso8601String(),
      'freeSpins': freeSpins,
      'level': level,
      'sessionId': sessionId,
      'dailyDiamonds': dailyDiamonds,
      'dailyCoins': dailyCoins,
      'dailyMetoChips': dailyMetoChips,
      'lastDailyDiamondsReset': lastDailyDiamondsReset?.toIso8601String(),
      'lastDailyCoinsReset': lastDailyCoinsReset?.toIso8601String(),
      'lastDailyTasksReset': lastDailyTasksReset?.toIso8601String(),
      'dailyPostsCount': dailyPostsCount,
      'lastPostResetDate': lastPostResetDate?.toIso8601String(),
      'exp': exp,
      'roomEntrance': roomEntrance,
      'ludoTokenTheme': ludoTokenTheme,
      'ludoBoardTheme': ludoBoardTheme,
      'ludoDiceTheme': ludoDiceTheme,
      'ludoHallTheme': ludoHallTheme,
      'profilePhotoAnimation': profilePhotoAnimation,
      'verificationIcon': verificationIcon,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'referredUsers': referredUsers,
      'lastReferralRewardDate': lastReferralRewardDate?.toIso8601String(),
      'isBanned': isBanned,
      'isSuspended': isSuspended,
      'isDisabled': isDisabled,
      'banReason': banReason,
      'isPrivate': isPrivate,
      'traits': traits,
      'ownedCardBorders': ownedCardBorders,
      'profileCardBorder': profileCardBorder,
      'ownedSpecialIds': ownedSpecialIds,
      'ownedSpecialIdImages': ownedSpecialIdImages,
      'ownedWallHangings': ownedWallHangings,
      'activeWallHanging': activeWallHanging,
      'ownedRoomCardBorders': ownedRoomCardBorders,
      'activeRoomCardBorder': activeRoomCardBorder,
      'gamesPlayed': gamesPlayed,
      'wins': wins,
      'losses': losses,
      'gameStats': gameStats,
      'leagueRank': leagueRank,
      'bestLeagueRank': bestLeagueRank,
      'followedRooms': followedRooms,
      'totalContributionToInviter': totalContributionToInviter,
      'ownedEntrances': ownedEntrances,
    };
  }

  // حساب العمر من تاريخ الميلاد
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      age--;
    }
    return age;
  }

  // نسخ مع تحديث البيانات
  User copyWith({
    String? uid,
    String? username,
    String? email,
    String? profileImage,
    String? coverImage,
    String? bio,
    String? nickname,
    int? followersCount,
    int? followingCount,
    List<String>? followers,
    List<String>? following,
    List<String>? blockedUsers,
    List<String>? mutedUsers,
    List<String>? blacklistedUsers,
    List<String>? ownedFrames,
    List<String>? ownedDecorations,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
    String? displayId,
    String? originalDisplayId,
    String? displayIdImage,
    String? city,
    String? country,
    DateTime? birthDate,
    String? gender,
    String? relationshipStatus,
    String? work,
    String? profileFrame,
    String? profileDecoration,
    String? verificationTier,
    int? coins,
    int? profitPoints,
    int? diamonds,
    int? meto_chips,
    int? pointsPerClaim,
    bool? isSubscribed,
    DateTime? subscriptionExpiry,
    DateTime? lastDailyRewardClaim,
    int? freeSpins,
    int? level,
    String? sessionId,
    int? exp,
    DateTime? lastDailyTasksReset,
    int? dailyPostsCount,
    DateTime? lastPostResetDate,
    String? roomEntrance,
    String? ludoTokenTheme,
    String? ludoBoardTheme,
    String? ludoDiceTheme,
    String? ludoHallTheme,
    String? profilePhotoAnimation,
    String? verificationIcon,
    Map<String, dynamic>?
    packageHistory, // Added implicitly to handle map pass-through if needed? No, user model doesn't store packageHistory field explicitly in previous code, but service reads it. I'll stick to strict fields.
    String? referralCode,
    String? referredBy,
    List<String>? referredUsers,
    DateTime? lastReferralRewardDate,
    bool? isBanned,
    bool? isSuspended,
    bool? isDisabled,
    String? banReason,
    bool? isPrivate,
    List<String>? traits,
    List<String>? ownedCardBorders,
    String? profileCardBorder,
    List<String>? ownedSpecialIds,
    List<String>? ownedSpecialIdImages,
    List<String>? ownedWallHangings,
    String? activeWallHanging,
    List<String>? ownedRoomCardBorders,
    String? activeRoomCardBorder,
    int? gamesPlayed,
    int? wins,
    int? losses,
    Map<String, dynamic>? gameStats,
    int? leagueRank,
    int? bestLeagueRank,
    int? totalContributionToInviter,
    List<String>? ownedEntrances,
  }) {
    return User(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      coverImage: coverImage ?? this.coverImage,
      bio: bio ?? this.bio,
      nickname: nickname ?? this.nickname,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      mutedUsers: mutedUsers ?? this.mutedUsers,
      blacklistedUsers: blacklistedUsers ?? this.blacklistedUsers,
      ownedFrames: ownedFrames ?? this.ownedFrames,
      ownedDecorations: ownedDecorations ?? this.ownedDecorations,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      displayId: displayId ?? this.displayId,
      originalDisplayId: originalDisplayId ?? this.originalDisplayId,
      displayIdImage: displayIdImage ?? this.displayIdImage,
      city: city ?? this.city,
      country: country ?? this.country,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      work: work ?? this.work,
      profileFrame: profileFrame ?? this.profileFrame,
      profileDecoration: profileDecoration ?? this.profileDecoration,
      verificationTier: verificationTier ?? this.verificationTier,
      coins: coins ?? this.coins,
      profitPoints: profitPoints ?? this.profitPoints,
      diamonds: diamonds ?? this.diamonds,
      meto_chips: meto_chips ?? this.meto_chips,
      pointsPerClaim: pointsPerClaim ?? this.pointsPerClaim,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      lastDailyRewardClaim: lastDailyRewardClaim ?? this.lastDailyRewardClaim,
      freeSpins: freeSpins ?? this.freeSpins,
      level: level ?? this.level,
      sessionId: sessionId ?? this.sessionId,
      dailyDiamonds: dailyDiamonds,
      dailyCoins: dailyCoins,
      dailyMetoChips: dailyMetoChips,
      lastDailyDiamondsReset: lastDailyDiamondsReset ?? lastDailyDiamondsReset,
      lastDailyCoinsReset: lastDailyCoinsReset ?? lastDailyCoinsReset,
      lastDailyTasksReset: lastDailyTasksReset ?? this.lastDailyTasksReset,
      exp: exp ?? this.exp,
      dailyPostsCount: dailyPostsCount ?? this.dailyPostsCount,
      lastPostResetDate: lastPostResetDate ?? this.lastPostResetDate,
      roomEntrance: roomEntrance ?? this.roomEntrance,
      ludoTokenTheme: ludoTokenTheme ?? this.ludoTokenTheme,
      ludoBoardTheme: ludoBoardTheme ?? this.ludoBoardTheme,
      ludoDiceTheme: ludoDiceTheme ?? this.ludoDiceTheme,
      ludoHallTheme: ludoHallTheme ?? this.ludoHallTheme,
      profilePhotoAnimation: profilePhotoAnimation ?? this.profilePhotoAnimation,
      verificationIcon: verificationIcon ?? this.verificationIcon,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      referredUsers: referredUsers ?? this.referredUsers,
      lastReferralRewardDate:
          lastReferralRewardDate ?? this.lastReferralRewardDate,
      isBanned: isBanned ?? this.isBanned,
      isSuspended: isSuspended ?? this.isSuspended,
      isDisabled: isDisabled ?? this.isDisabled,
      banReason: banReason ?? this.banReason,
      isPrivate: isPrivate ?? this.isPrivate,
      traits: traits ?? this.traits,
      ownedCardBorders: ownedCardBorders ?? this.ownedCardBorders,
      profileCardBorder: profileCardBorder ?? this.profileCardBorder,
      ownedSpecialIds: ownedSpecialIds ?? this.ownedSpecialIds,
      ownedSpecialIdImages: ownedSpecialIdImages ?? this.ownedSpecialIdImages,
      ownedWallHangings: ownedWallHangings ?? this.ownedWallHangings,
      activeWallHanging: activeWallHanging ?? this.activeWallHanging,
      ownedRoomCardBorders: ownedRoomCardBorders ?? this.ownedRoomCardBorders,
      activeRoomCardBorder: activeRoomCardBorder ?? this.activeRoomCardBorder,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      gameStats: gameStats ?? this.gameStats,
      leagueRank: leagueRank ?? this.leagueRank,
      bestLeagueRank: bestLeagueRank ?? this.bestLeagueRank,
      totalContributionToInviter: totalContributionToInviter ?? this.totalContributionToInviter,
      ownedEntrances: ownedEntrances ?? this.ownedEntrances,
    );
  }
}
