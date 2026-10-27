import 'package:flutter/material.dart';

/// يحتوي هذا الملف على جميع الثوابت المستخدمة في لعبة لودو
/// تم تجميعها هنا لسهولة التعديل والوصول إليها من أي مكان في التطبيق.

/// مبالغ الرهان المتاحة للاعبين للاختيار من بينها
const List<int> kAvailableBets = [100, 300, 600, 1000, 2000, 3000];

/// مدة الدور الواحد لكل لاعب بالثواني
const int kTurnDurationSeconds = 15;

/// تكلفة استخدام زر إعادة الرمي (Blue Button) وتتصاعد مع كل استخدام
const List<int> kBlueButtonCosts = [5, 8, 12, 18, 26, 36, 48, 64];

/// أقصى عدد من السجلات المحفوظة في سجل أحداث اللعبة (Log)
const int kMaxLogEntries = 200;

/// الألوان الأساسية المستخدمة لتمييز اللاعبين الأربعة
const Color kColorBlue = Color(0xFF2196F3);
const Color kColorRed = Color(0xFFF44336);
const Color kColorGreen = Color(0xFF4CAF50);
const Color kColorYellow = Color(0xFFFFC107);

/// ألوان خلفية وحدود مربعات اللوحة الافتراضية
const Color kCellBgColor = Color(0xFFFDFBF7);
const Color kCellBorderColor = Color(0xFFB0BEC5);

/// أشكال الأحجار الأساسية المتاحة لجميع اللاعبين محلياً
const List<String> kBasicTokenShapes = ['pawn', 'star', 'shield'];

/// مسارات ملفات الصوت المستخدمة داخل اللعبة
const String kMusicLudoX = 'assets/sounds/lodux.mp3';
const String kMusicClassic = 'assets/sounds/lodumusic.mp3';
const String kSfxDice = 'assets/sounds/dice.mp3';
const String kSfxMove = 'assets/sounds/like.wav';
const String kSfxCapture = 'assets/sounds/uhao.mp3';
const String kSfxSlide = 'assets/sounds/slide.wav';
const String kSfxThreeSix = 'assets/sounds/threeSix.wav';
const String kSfxQuit = 'assets/sounds/quit.wav';

/// قائمة الأسماء المقترحة للأعداء الآليين (Bots)
const List<String> kBotNamesPool = [
  'Ali_99',
  'حمودي',
  'Omar_X',
  'Zayn',
  'مروان',
  'احمد العراقي',
  'هدووش',
  'Faris.88',
  'كريم',
  'Basel_K',
  'Huda.7',
  'عشق الورد',
  'زوزايه',
  'زهرة البنفسج',
  'فديت',
  'لينا',
  'فوفو.88',
  'روان',
  'سارة',
  'بلبل',
  'ضحكة',
  'نورة',
  'Noor',
];

/// مسارات صور الأفاتار الخاصة بالأعداء الآليين
const List<String> kBotImagesPool = [
  'assets/images/bot_1.png.jpg',
  'assets/images/bot_2.png.jpg',
  'assets/images/bot_3.png.jpg',
  'assets/images/bot_4.png.jpg',
  'assets/images/bot_5.png.jpg',
  'assets/images/bot_6.png.webp',
  'assets/images/bot_7.png.jpg',
];

/// رسائل التنبيه العشوائية التي يرسلها البوت عندما يتأخر اللاعب في اللعب
const List<String> kBotHurryMessages = [
  ' العب بسرعة وراي شغل  😅',
  ' شبيك صفنت؟ 🤔',
  ' خلص الوقت!',
  'هيا ألعب!',
  '⏳ الوقت يمشي',
  'ركّز بالعب راح تنجلد ',
  'مبين مشغول؟ 😂',
  'العجلة من الشيطان لكن انتبه 😜',
  'شنو تلعب لودو لو بخشمك 😂',
];
