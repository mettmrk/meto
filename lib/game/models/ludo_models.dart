import 'dart:ui';
import 'ludo_enums.dart';
import 'dart:math';
import '../core/ludo_constants.dart';

/// يحتوي هذا الملف على هياكل البيانات (Classes) المستخدمة لتمثيل الكائنات داخل اللعبة.

/// يمثل الملف الشخصي للاعب آلي (Bot)
class LudoBotProfile {
  /// اسم البوت
  final String name;

  /// مسار صورة البوت (Avatar)
  final String? botImage;

  /// رقم البذور الخاص بالصورة الافتراضية
  final int avatarSeed;

  /// عدد الانتصارات الوهمية لعرضها في ملفه
  final int fakeWins;

  /// المستوى الوهمي للبوت
  final int fakeLevel;

  /// شخصية البوت في اللعب
  final LudoBotPersonality personality;

  /// مستوى صعوبة البوت
  final LudoBotDifficulty difficulty;

  const LudoBotProfile({
    required this.name,
    this.botImage,
    this.avatarSeed = 0,
    this.fakeWins = 0,
    this.fakeLevel = 1,
    this.personality = LudoBotPersonality.balanced,
    this.difficulty = LudoBotDifficulty.medium,
  });

  /// إنشاء ملف شخصي لبوت عشوائي مع بيانات منطقية بناءً على الصعوبة
  factory LudoBotProfile.random(Random rng) {
    final name = kBotNamesPool[rng.nextInt(kBotNamesPool.length)];
    final image = kBotImagesPool[rng.nextInt(kBotImagesPool.length)];
    final personality = LudoBotPersonality
        .values[rng.nextInt(LudoBotPersonality.values.length)];
    final difficulty =
        LudoBotDifficulty.values[rng.nextInt(LudoBotDifficulty.values.length)];

    int minWins, maxWins, minLevel, maxLevel;
    switch (difficulty) {
      case LudoBotDifficulty.easy:
        minWins = 5;
        maxWins = 50;
        minLevel = 1;
        maxLevel = 5;
        break;
      case LudoBotDifficulty.medium:
        minWins = 80;
        maxWins = 300;
        minLevel = 8;
        maxLevel = 20;
        break;
      case LudoBotDifficulty.hard:
        minWins = 300;
        maxWins = 700;
        minLevel = 25;
        maxLevel = 45;
        break;
      case LudoBotDifficulty.pro:
        minWins = 700;
        maxWins = 2000;
        minLevel = 50;
        maxLevel = 99;
        break;
    }

    return LudoBotProfile(
      name: name,
      botImage: image,
      avatarSeed: rng.nextInt(8),
      fakeWins: minWins + rng.nextInt(maxWins - minWins + 1),
      fakeLevel: minLevel + rng.nextInt(maxLevel - minLevel + 1),
      personality: personality,
      difficulty: difficulty,
    );
  }
}

/// يمثل حركة محتملة يمكن للبوت القيام بها، مع تقييم لنتائجها
class LudoBotMove {
  /// فهرس الحجر المراد تحريكه
  final int tokenIdx;

  /// فهرس النرد المستخدم
  final int diceIdx;

  /// قيمة النرد
  final int diceValue;

  /// الموقع الحالي للحجر
  final int fromPos;

  /// الموقع المستهدف بعد الحركة
  final int toPos;

  /// هل تؤدي هذه الحركة لقتل حجر الخصم؟
  final bool canCapture;

  /// هل تؤدي الحركة للوصول للمنزل النهائي؟
  final bool isHome;

  /// هل الحركة هي خروج من القاعدة (Deployment)؟
  final bool isDeploy;

  /// هل سيهبط الحجر في مربع آمن؟
  final bool landsSafe;

  /// هل كان الحجر مهدداً من الخصم قبل هذه الحركة؟
  final bool wasThreatened;

  /// عدد أحجار البوت التي لا تزال في القاعدة
  final int tokensInBase;

  /// عدد أحجار البوت القريبة من النهاية (أكبر من 40)
  final int advancedTokens;

  const LudoBotMove({
    required this.tokenIdx,
    required this.diceIdx,
    required this.diceValue,
    required this.fromPos,
    required this.toPos,
    required this.canCapture,
    required this.isHome,
    required this.isDeploy,
    required this.landsSafe,
    required this.wasThreatened,
    this.tokensInBase = 0,
    this.advancedTokens = 0,
  });
}

/// يمثل إدخالاً واحداً في سجل أحداث اللعبة
class LudoGameLogEntry {
  /// نوع الحدث
  final LudoGameLogType type;

  /// اسم اللاعب الذي قام بالحدث
  final String playerName;

  /// لون اللاعب
  final Color playerColor;

  /// الرسالة النصية للحدث
  final String message;

  /// وقت وقوع الحدث
  final DateTime timestamp;

  LudoGameLogEntry({
    required this.type,
    required this.playerName,
    required this.playerColor,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// الأيقونة المرتبطة بنوع الحدث
  String get icon => switch (type) {
    LudoGameLogType.move => '🎲',
    LudoGameLogType.capture => '💥',
    LudoGameLogType.sixBonus => '🎉',
    LudoGameLogType.win => '🏆',
    LudoGameLogType.chat => '💬',
    LudoGameLogType.sticker => '🎭',
    LudoGameLogType.turnChange => '🔄',
    LudoGameLogType.start => '🚀',
    LudoGameLogType.magic => '✨',
    LudoGameLogType.diamondReRoll => '💎',
  };

  /// الوقت بصيغة HH:mm للعرض في السجل
  String get timeLabel {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
