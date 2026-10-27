// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

enum BackgammonThemeType {
  obsidian,
  jungle,
  classic,
  ivory,
  sky,
  marble,
  ruby,
  pearl,
}

enum BackgammonPieceShape {
  circle,
  shield,
  octagon,
  star,
  hexagon,
  diamond,
  flower,
}

class BackgammonThemeData {
  final String name;
  final BackgammonThemeType type;

  // Board & Frame
  final Color boardBaseColor;
  final List<Color> frameGradients;
  final Color accentColor;
  final List<Color> barGradients;
  final Color barSelectionGlow;

  // Points (Triangles)
  final List<Color> pointLightGradients;
  final List<Color> pointDarkGradients;

  // Piece Aesthetics - White
  final List<Color> whitePieceGradients;
  final Color whitePieceRim;
  final Color whitePieceInnerShapeColor;

  // Piece Aesthetics - Black
  final List<Color> blackPieceGradients;
  final Color blackPieceRim;
  final Color blackPieceInnerShapeColor;

  final BackgammonPieceShape innerShape;

  BackgammonThemeData({
    required this.name,
    required this.type,
    required this.boardBaseColor,
    required this.frameGradients,
    required this.accentColor,
    required this.barGradients,
    required this.barSelectionGlow,
    required this.pointLightGradients,
    required this.pointDarkGradients,
    required this.whitePieceGradients,
    required this.whitePieceRim,
    required this.whitePieceInnerShapeColor,
    required this.blackPieceGradients,
    required this.blackPieceRim,
    required this.blackPieceInnerShapeColor,
    required this.innerShape,
  });

  static BackgammonThemeData obsidian() {
    return BackgammonThemeData(
      name: "الأوبسيديان الذهبي",
      type: BackgammonThemeType.obsidian,
      boardBaseColor: const Color(
        0xFF121212,
      ), // Deeper charcoal for better contrast
      frameGradients: [const Color(0xFF2C2C2C), const Color(0xFF121212)],
      accentColor: const Color(0xFFFFD700),
      barGradients: [
        Colors.amber.shade700,
        Colors.amber.shade300,
        Colors.amber.shade700,
      ],
      barSelectionGlow: Colors.amberAccent,
      pointLightGradients: [
        Colors.amber.shade600,
        Colors.amber.shade200,
        Colors.amber.shade600,
      ],
      pointDarkGradients: [
        const Color(0xFF333333),
        const Color(0xFF1A1A1A),
      ], // Slightly brighter dark points
      whitePieceGradients: [Colors.white, Colors.grey.shade300],
      whitePieceRim: Colors.white70,
      whitePieceInnerShapeColor: Colors.amber.shade700,
      blackPieceGradients: [const Color(0xFF222222), const Color(0xFF000000)],
      blackPieceRim: Colors.amber.withValues(alpha: 0.4),
      blackPieceInnerShapeColor: Colors.amberAccent,
      innerShape: BackgammonPieceShape.star,
    );
  }

  static BackgammonThemeData ivory() {
    return BackgammonThemeData(
      name: "العاج الملكي",
      type: BackgammonThemeType.ivory,
      boardBaseColor: const Color(0xFFFFFDF5),
      frameGradients: [const Color(0xFFFDF5E6), const Color(0xFFFFFDF5)],
      accentColor: const Color(0xFFDAA520),
      barGradients: [
        const Color(0xFFDAA520),
        const Color(0xFFFFD700),
        const Color(0xFFDAA520),
      ],
      barSelectionGlow: Colors.orangeAccent,
      pointLightGradients: [const Color(0xFFF5F5DC), const Color(0xFFFFFFF0)],
      pointDarkGradients: [const Color(0xFFDAA520), const Color(0xFFB8860B)],
      whitePieceGradients: [Colors.white, Colors.grey.shade300],
      whitePieceRim: const Color(0xFFDAA520),
      whitePieceInnerShapeColor: const Color(0xFFDAA520),
      blackPieceGradients: [const Color(0xFF222222), const Color(0xFF000000)],
      blackPieceRim: Colors.white70,
      blackPieceInnerShapeColor: Colors.white,
      innerShape: BackgammonPieceShape.star,
    );
  }

  static BackgammonThemeData sky() {
    return BackgammonThemeData(
      name: "أفق السماء",
      type: BackgammonThemeType.sky,
      boardBaseColor: const Color(0xFFE3F2FD),
      frameGradients: [const Color(0xFFBBDEFB), const Color(0xFFE3F2FD)],
      accentColor: const Color(0xFF2196F3),
      barGradients: [
        const Color(0xFF1976D2),
        const Color(0xFF64B5F6),
        const Color(0xFF1976D2),
      ],
      barSelectionGlow: Colors.cyanAccent,
      pointLightGradients: [const Color(0xFF90CAF9), const Color(0xFFE3F2FD)],
      pointDarkGradients: [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
      whitePieceGradients: [Colors.white, Colors.grey.shade300],
      whitePieceRim: const Color(0xFF03A9F4),
      whitePieceInnerShapeColor: const Color(0xFF03A9F4),
      blackPieceGradients: [const Color(0xFF222222), const Color(0xFF000000)],
      blackPieceRim: Colors.cyanAccent.withValues(alpha: 0.5),
      blackPieceInnerShapeColor: Colors.white,
      innerShape: BackgammonPieceShape.star,
    );
  }

  static BackgammonThemeData jungle() {
    return BackgammonThemeData(
      name: "الزمرد الساطع",
      type: BackgammonThemeType.jungle,
      boardBaseColor: const Color(0xFFDFF0D8),
      frameGradients: [const Color(0xFFC1E2B3), const Color(0xFFDFF0D8)],
      accentColor: const Color(0xFF3C763D),
      barGradients: [
        const Color(0xFF3C763D),
        const Color(0xFF5CB85C),
        const Color(0xFF3C763D),
      ],
      barSelectionGlow: Colors.lightGreenAccent,
      pointLightGradients: [const Color(0xFFDFF0D8), const Color(0xFFF9F9F9)],
      pointDarkGradients: [const Color(0xFF2B542C), const Color(0xFF3C763D)],
      whitePieceGradients: [Colors.white, Colors.grey.shade300],
      whitePieceRim: const Color(0xFF4CAE4C),
      whitePieceInnerShapeColor: const Color(0xFF4CAE4C),
      blackPieceGradients: [const Color(0xFF222222), const Color(0xFF000000)],
      blackPieceRim: Colors.lightGreenAccent.withValues(alpha: 0.4),
      blackPieceInnerShapeColor: Colors.white,
      innerShape: BackgammonPieceShape.star,
    );
  }

  static BackgammonThemeData classic() {
    return BackgammonThemeData(
      name: "الخشب الدافئ",
      type: BackgammonThemeType.classic,
      boardBaseColor: const Color(0xFFD2B48C), // Tan/Wood
      frameGradients: [const Color(0xFF8B4513), const Color(0xFFD2B48C)],
      accentColor: const Color(0xFF5D4037),
      barGradients: [
        const Color(0xFF5D4037),
        const Color(0xFF8D6E63),
        const Color(0xFF5D4037),
      ],
      barSelectionGlow: Colors.amberAccent,
      pointLightGradients: [const Color(0xFFF5DEB3), const Color(0xFFFFF8DC)],
      pointDarkGradients: [const Color(0xFF8B4513), const Color(0xFF5D4037)],
      whitePieceGradients: [Colors.white, Colors.grey.shade300],
      whitePieceRim: Colors.brown.shade400,
      whitePieceInnerShapeColor: Colors.brown.shade800,
      blackPieceGradients: [const Color(0xFF222222), const Color(0xFF000000)],
      blackPieceRim: Colors.white38,
      blackPieceInnerShapeColor: Colors.white,
      innerShape: BackgammonPieceShape.star,
    );
  }

  static BackgammonThemeData marble() {
    return BackgammonThemeData(
      name: "مرمر لؤلؤي",
      type: BackgammonThemeType.marble,
      boardBaseColor: const Color(0xFFFDFDFD),
      frameGradients: [const Color(0xFFF0F0F0), const Color(0xFFFDFDFD)],
      accentColor: const Color(0xFFE0E0E0),
      barGradients: [
        const Color(0xFFB0BEC5),
        const Color(0xFFECEFF1),
        const Color(0xFFB0BEC5),
      ],
      barSelectionGlow: Colors.tealAccent,
      pointLightGradients: [const Color(0xFFFFCCBC), const Color(0xFFFFFFFF)],
      pointDarkGradients: [const Color(0xFF90A4AE), const Color(0xFFCFD8DC)],
      whitePieceGradients: [Colors.white, Colors.grey.shade300],
      whitePieceRim: Colors.teal.shade300,
      whitePieceInnerShapeColor: Colors.teal.shade400,
      blackPieceGradients: [const Color(0xFF222222), const Color(0xFF000000)],
      blackPieceRim: Colors.white70,
      blackPieceInnerShapeColor: Colors.white,
      innerShape: BackgammonPieceShape.star,
    );
  }

  static BackgammonThemeData ruby() {
    return BackgammonThemeData(
      name: "ياقوت مُشرق",
      type: BackgammonThemeType.ruby,
      boardBaseColor: const Color(0xFFFFEBEE),
      frameGradients: [const Color(0xFFEF9A9A), const Color(0xFFFFEBEE)],
      accentColor: const Color(0xFFD32F2F),
      barGradients: [
        const Color(0xFFC62828),
        const Color(0xFFEF5350),
        const Color(0xFFC62828),
      ],
      barSelectionGlow: Colors.redAccent,
      pointLightGradients: [const Color(0xFFFFEBEE), const Color(0xFFFFFFFF)],
      pointDarkGradients: [const Color(0xFFD32F2F), const Color(0xFFB71C1C)],
      whitePieceGradients: [Colors.white, Colors.grey.shade300],
      whitePieceRim: const Color(0xFFD32F2F),
      whitePieceInnerShapeColor: const Color(0xFFD32F2F),
      blackPieceGradients: [const Color(0xFF222222), const Color(0xFF000000)],
      blackPieceRim: Colors.white70,
      blackPieceInnerShapeColor: Colors.white,
      innerShape: BackgammonPieceShape.star,
    );
  }

  static BackgammonThemeData pearl() {
    return BackgammonThemeData(
      name: "ورد اللؤلؤ",
      type: BackgammonThemeType.pearl,
      boardBaseColor: const Color(0xFFFFF5F5),
      frameGradients: [const Color(0xFFFFE4E1), const Color(0xFFFFF5F5)],
      accentColor: const Color(0xFFFFB6C1),
      barGradients: [
        const Color(0xFFFFC0CB),
        const Color(0xFFFFD1DC),
        const Color(0xFFFFC0CB),
      ],
      barSelectionGlow: Colors.pinkAccent,
      pointLightGradients: [const Color(0xFFFFF0F5), const Color(0xFFFFFFFF)],
      pointDarkGradients: [const Color(0xFFFFB6C1), const Color(0xFFFF69B4)],
      whitePieceGradients: [Colors.white, Colors.grey.shade300],
      whitePieceRim: const Color(0xFFFF69B4),
      whitePieceInnerShapeColor: const Color(0xFFFF69B4),
      blackPieceGradients: [const Color(0xFF222222), const Color(0xFF000000)],
      blackPieceRim: Colors.white70,
      blackPieceInnerShapeColor: Colors.white,
      innerShape: BackgammonPieceShape.star,
    );
  }
}
