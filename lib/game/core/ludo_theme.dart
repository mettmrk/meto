import 'package:flutter/material.dart';

/// يمثل نمط الألوان والتصميم لطاولة لودو معينة
class LudoThemeStyles {
  /// لون الخلفية الأساسي للوحة
  final Color bg;

  /// ألوان اللاعبين الأربعة المخصصة لهذا النمط
  final Color p0, p1, p2, p3;

  /// لون مسار المشي العادي
  final Color path;

  /// لون حدود المربعات
  final Color border;

  /// هل يحتوي النمط على تأثيرات إضاءة (Neon)؟
  final bool isNeon;

  /// هل هو نمط ملكي (فاخر)؟
  final bool isRoyal;

  LudoThemeStyles({
    required this.bg,
    required this.p0,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.path,
    required this.border,
    this.isNeon = false,
    this.isRoyal = false,
  });
}

/// يحتوي هذا الكلاس على مجموعة الأنماط (Themes) المتاحة في اللعبة
class LudoThemes {
  /// قاموس يحتوي على جميع الأنماط المعرفة، حيث المفتاح هو اسم النمط
  static final Map<String, LudoThemeStyles> all = {
    'classic': LudoThemeStyles(
      bg: const Color(0xFFFDFBF7),
      p0: const Color(0xFFF44336),
      p1: const Color(0xFF4CAF50),
      p2: const Color(0xFFFFC107),
      p3: const Color(0xFF2196F3),
      path: const Color(0xFFFDFBF7),
      border: const Color(0xFFB0BEC5),
    ),
    'neon': LudoThemeStyles(
      bg: const Color(0xFF0F0E1E),
      p0: const Color(0xFFFF1D5E),
      p1: const Color(0xFF00FF88),
      p2: const Color(0xFFFFE100),
      p3: const Color(0xFF00E5FF),
      path: const Color(0xFF16152B),
      border: const Color(0xFF322F5A),
      isNeon: true,
    ),
    'royal': LudoThemeStyles(
      bg: const Color(0xFF2B2D42),
      p0: const Color(0xFFEF233C),
      p1: const Color(0xFF06D6A0),
      p2: const Color(0xFFFFD166),
      p3: const Color(0xFF4361EE),
      path: const Color(0xFFEDF2F4),
      border: const Color(0xFF8D99AE),
      isRoyal: true,
    ),
    'midnight': LudoThemeStyles(
      bg: const Color(0xFF0D0D2B),
      p0: const Color(0xFFFF6B6B),
      p1: const Color(0xFF4ECDC4),
      p2: const Color(0xFFF7D794),
      p3: const Color(0xFF5D3FD3),
      path: const Color(0xFF1A1A40),
      border: const Color(0xFF2E2E62),
    ),
    'volcano': LudoThemeStyles(
      bg: const Color(0xFF1A0A0A),
      p0: const Color(0xFFFF4D00),
      p1: const Color(0xFF00E600),
      p2: const Color(0xFFFFD700),
      p3: const Color(0xFF0635CF),
      path: const Color(0xFF2C2C2C),
      border: const Color(0xFF4A4A4A),
      isNeon: true,
    ),
    'board1': LudoThemeStyles(
      bg: const Color(0xFF0F0E1E),
      p0: const Color(0xFFFF1D5E),
      p1: const Color(0xFF00FF88),
      p2: const Color(0xFFFFE100),
      p3: const Color(0xFF00E5FF),
      path: const Color(0xFF16152B),
      border: const Color(0xFF322F5A),
      isNeon: true,
    ),
    'board2': LudoThemeStyles(
      bg: const Color(0xFFECEFF1), // Light Grey/White Marble
      p0: const Color(0xFFF44336),
      p1: const Color(0xFF4CAF50),
      p2: const Color(0xFFFFC107),
      p3: const Color(0xFF2196F3),
      path: const Color(0xFFECEFF1),
      border: const Color(0xFFCFD8DC),
      isRoyal: true,
    ),
    'ice': LudoThemeStyles(
      bg: const Color(0xFFE1F5FE),
      p0: const Color(0xFF0288D1),
      p1: const Color(0xFF00BCD4),
      p2: const Color(0xFF4FC3F7),
      p3: const Color(0xFF81D4FA),
      path: const Color(0xFFE1F5FE),
      border: const Color(0xFFB3E5FC),
      isNeon: true,
    ),
    'board3': LudoThemeStyles(
      bg: const Color(0xFFFFF8E1),
      p0: const Color(0xFFFFC107),
      p1: const Color(0xFFFFD54F),
      p2: const Color(0xFFFFE082),
      p3: const Color(0xFFFFB300),
      path: const Color(0xFFFFF8E1),
      border: const Color(0xFFFFD54F),
      isRoyal: true,
    ),
    'river': LudoThemeStyles(
      bg: const Color(0xFFFFF8E1),
      p0: const Color(0xFFFFC107),
      p1: const Color(0xFFFFD54F),
      p2: const Color(0xFFFFE082),
      p3: const Color(0xFFFFB300),
      path: const Color(0xFFFFF8E1),
      border: const Color(0xFFFFD54F),
      isRoyal: true,
    ),
    'board4': LudoThemeStyles(
      bg: const Color(0xFF006064),
      p0: const Color(0xFFF44336),
      p1: const Color(0xFF4CAF50),
      p2: const Color(0xFFFFC107),
      p3: const Color(0xFF03A9F4),
      path: const Color(0xFF00838F),
      border: const Color(0xFF0097A7),
    ),
    'board5': LudoThemeStyles(
      bg: const Color(0xFF311B92),
      p0: const Color(0xFFF44336),
      p1: const Color(0xFF4CAF50),
      p2: const Color(0xFFFFC107),
      p3: const Color(0xFF9C27B0),
      path: const Color(0xFF4527A0),
      border: const Color(0xFF5E35B1),
    ),
    'board6': LudoThemeStyles(
      bg: const Color(0xFF1B5E20),
      p0: const Color(0xFFF44336),
      p1: const Color(0xFF00C853),
      p2: const Color(0xFFFFC107),
      p3: const Color(0xFF03A9F4),
      path: const Color(0xFF2E7D32),
      border: const Color(0xFF388E3C),
    ),
    'board7': LudoThemeStyles(
      bg: const Color(0xFF1B5E20),
      p0: const Color(0xFFF44336),
      p1: const Color(0xFF00C853),
      p2: const Color(0xFFFFC107),
      p3: const Color(0xFF03A9F4),
      path: const Color(0xFF2E7D32),
      border: const Color(0xFF388E3C),
    ),
    'board8': LudoThemeStyles(
      bg: const Color(0xFF0D47A1),
      p0: const Color(0xFFD32F2F),
      p1: const Color(0xFF388E3C),
      p2: const Color(0xFFFFA000),
      p3: const Color(0xFF1976D2),
      path: const Color(0xFF1565C0),
      border: const Color(0xFFFFD54F),
      isRoyal: true,
    ),
  };
}
