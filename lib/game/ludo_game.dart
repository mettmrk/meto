// ignore_for_file: unused_element, library_private_types_in_public_api

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'ludo_x_manager.dart';

class _LudoThemeStyles {
  final Color bg;
  final Color p0, p1, p2, p3;
  final Color path;
  final Color border;
  final bool isNeon;
  final bool isRoyal;

  _LudoThemeStyles({
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

class LudoGame extends FlameGame {
  final Function(int playerIndex, int tokenIndex) onTokenTapped;
  final int playerCount;

  // Game State
  List<List<int>> tokens = List.generate(
    4,
    (_) => List.filled(4, 0),
  ); // 0 = In Base
  int currentPlayerIndex = 0;
  int diceValue = 0;
  bool hasRolled = false;
  bool allowTokenInteraction = false;
  Set<int> activePlayers = {0, 1, 2, 3};

  BoardComponent? _board;
  final List<TokenComponent> _tokenComponents = [];
  List<TokenComponent> get tokenComponents => _tokenComponents;
  final PositionComponent _gameWrapper = PositionComponent();
  PositionComponent get gameWrapper => _gameWrapper;

  int viewerPlayerIndex = 0;
  int rotationIndex = 0;
  double totalTime = 0;
  bool isBlackoutActive = false;

  // Audio Players
  final AudioPlayer _dicePlayer = AudioPlayer();
  final List<AudioPlayer> _movePlayers = List.generate(6, (_) => AudioPlayer());
  final AudioPlayer _capturePlayer = AudioPlayer();
  final AudioPlayer _slidePlayer = AudioPlayer();
  final AudioPlayer _threeSixPlayer = AudioPlayer();
  final AudioPlayer _newTokenPlayer = AudioPlayer();
  final AudioPlayer _quitPlayer = AudioPlayer();
  bool isMuted = false;
  double _diceVolume = 0.7;
  double _sfxVolume = 0.4;
  double _lastAppliedSfxVolume = -1;

  double get sfxVolume => _sfxVolume;
  double get diceVolume => _diceVolume;

  // Configs
  String boardTheme = 'classic';
  String? boardImageUrl;
  String gameMode = 'local';
  String currentMatchMode = 'classic';
  Map<int, String> playerShapes = {0: 'pawn', 1: 'pawn', 2: 'pawn', 3: 'pawn'};

  // لكل لاعب سمته الخاصة للحجرات وروابط الصور الخاصة بها
  final Map<int, String?> playerTokenThemes = {};
  final Map<int, Map<String, String>> playerTokenUrls = {};

  final int? magicSeed;
  final String? onlineRoomId;
  final String? localPlayerId;
  final void Function(String type, bool active)? onMagicEffect;
  final bool magicToolsEnabled;

  LudoXManager? ludoXManager;

  void reset() {
    for (int p = 0; p < 4; p++) {
      for (int t = 0; t < 4; t++) {
        tokens[p][t] = 0;
      }
    }
    currentPlayerIndex = 0;
    diceValue = 0;
    hasRolled = false;
    allowTokenInteraction = false;
    activePlayers = {0, 1, 2, 3};
    totalTime = 0;
    isBlackoutActive = false;

    // Reset components
    for (var comp in _tokenComponents) {
      comp.resetState();
    }
  }

  void updateThemes({
    String? bTheme,
    String? bImageUrl,
    String? tTheme,
    Map<String, String>? tUrls,
    Map<int, String>? pShapes,
    Map<int, String>? pThemes, // New: per-player themes
    Map<int, Map<String, String>>? pUrlsMap, // New: per-player URL maps
  }) {
    if (bTheme != null) boardTheme = bTheme;
    if (bImageUrl != null) boardImageUrl = bImageUrl;
    if (pThemes != null) {
      playerTokenThemes.addAll(pThemes);
    }
    if (pUrlsMap != null) {
      playerTokenUrls.addAll(pUrlsMap);
    }
    if (pShapes != null) {
      playerShapes.addAll(pShapes);
    }

    _board?.refreshTheme();
    for (var token in _tokenComponents) {
      token.refreshSprite();
    }
  }

  // Cache for network sprites to avoid redundant downloads
  static final Map<String, ui.Image> _networkImageCache = {};
  static final Map<String, Future<ui.Image?>> _pendingDownloads = {};

  Future<ui.Image?> _fetchNetworkImage(String url) async {
    if (_networkImageCache.containsKey(url)) return _networkImageCache[url];
    if (_pendingDownloads.containsKey(url)) return _pendingDownloads[url];

    final downloadFuture = () async {
      try {
        final uri = Uri.parse(url);
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(response.bodyBytes);
          final frame = await codec.getNextFrame();
          _networkImageCache[url] = frame.image;
          return frame.image;
        }
      } catch (e) {
        debugPrint("Error downloading network image: $e");
      }
      return null;
    }();

    _pendingDownloads[url] = downloadFuture;
    final result = await downloadFuture;
    _pendingDownloads.remove(url);
    return result;
  }

  Future<void> _preloadTokens() async {
    if (playerTokenUrls.isEmpty) return;

    final List<Future> loads = [];
    for (var urls in playerTokenUrls.values) {
      urls.forEach((color, url) {
        if (url.isNotEmpty) {
          loads.add(_fetchNetworkImage(url));
        }
      });
    }

    await Future.wait(loads);
    debugPrint("LudoGame: All themed tokens preloaded.");
  }

  // Standard Colors matching the classic layout
  static const Color colorBlue = Color(0xFF2196F3); // P0
  static const Color colorRed = Color(0xFFF44336); // P1
  static const Color colorGreen = Color(0xFF4CAF50); // P2
  static const Color colorYellow = Color(0xFFFFC107); // P3
  static const Color cellBgColor = Color(0xFFFDFBF7);
  static const Color cellBorderColor = Color(0xFFB0BEC5);

  // Theme Schemes
  static final Map<String, _LudoThemeStyles> themes = {
    'classic': _LudoThemeStyles(
      bg: const Color(0xFFFDFBF7),
      p0: const Color(0xFFF44336), // Red
      p1: const Color(0xFF4CAF50), // Green
      p2: const Color(0xFFFFC107), // Yellow
      p3: const Color(0xFF2196F3), // Blue
      path: const Color(0xFFFDFBF7),
      border: const Color(0xFFB0BEC5),
    ),
    'neon': _LudoThemeStyles(
      bg: const Color(0xFF0F0E1E),
      p0: const Color(0xFFFF1D5E), // Neon Red/Pink
      p1: const Color(0xFF00FF88), // Neon Green
      p2: const Color(0xFFFFE100), // Neon Yellow
      p3: const Color(0xFF00E5FF), // Neon Blue
      path: const Color(0xFF16152B),
      border: const Color(0xFF322F5A),
      isNeon: true,
    ),
    'royal': _LudoThemeStyles(
      bg: const Color(0xFF2B2D42),
      p0: const Color(0xFFEF233C), // Red
      p1: const Color(0xFF06D6A0), // Green
      p2: const Color(0xFFFFD166), // Yellow
      p3: const Color(0xFF4361EE), // Blue
      path: const Color(0xFFEDF2F4),
      border: const Color(0xFF8D99AE),
      isRoyal: true,
    ),
    'midnight': _LudoThemeStyles(
      bg: const Color(0xFF0D0D2B),
      p0: const Color(0xFFFF6B6B), // Red
      p1: const Color(0xFF4ECDC4), // Green
      p2: const Color(0xFFF7D794), // Yellow
      p3: const Color(0xFF5D3FD3), // Blue
      path: const Color(0xFF1A1A40),
      border: const Color(0xFF2E2E62),
    ),
    'volcano': _LudoThemeStyles(
      bg: const Color(0xFF1A0A0A), // Obsidian/Deep Red Background
      p0: const Color(0xFFFF4D00), // Lava Orange
      p1: const ui.Color.fromARGB(255, 0, 230, 0), // Magma Red
      p2: const Color(0xFFFFD700), // Glowing Ember Yellow
      p3: const ui.Color.fromARGB(255, 6, 53, 207), // Dark Crust Red
      path: const Color(0xFF2C2C2C), // Smoke Grey Path
      border: const Color(0xFF4A4A4A),
      isNeon: true, // تفعيل التوهج ليعطي انطباع الحمم البركانية
    ),
    'board1': _LudoThemeStyles(
      bg: const Color(0xFF0F0E1E), // Deep Violet
      p0: const Color(0xFFFF1D5E), // Neon Red/Magenta
      p1: const Color(0xFF00FF88), // Neon Green
      p2: const Color(0xFFFFE100), // Neon Yellow
      p3: const Color(0xFF00E5FF), // Neon Cyan
      path: const Color(0xFF16152B),
      border: const Color(0xFF322F5A),
      isNeon: true,
    ),
    'board2': _LudoThemeStyles(
      bg: const Color(0xFFECEFF1), // Light Marble
      p0: const Color(0xFFF44336),
      p1: const Color(0xFF4CAF50),
      p2: const Color(0xFFFFC107),
      p3: const Color(0xFF2196F3),
      path: const Color(0xFFECEFF1),
      border: const Color(0xFFCFD8DC),
      isRoyal: true,
    ),
    'ice': _LudoThemeStyles(
      bg: const Color(0xFFE1F5FE), // Light Ice Blue
      p0: const Color(0xFF0288D1), // Deep Blue
      p1: const Color(0xFF00BCD4), // Cyan
      p2: const Color(0xFF4FC3F7), // Light Blue
      p3: const Color(0xFF81D4FA), // Lighter Blue
      path: const Color(0xFFE1F5FE),
      border: const Color(0xFFB3E5FC),
      isNeon: true, // For crystal glow effect
    ),
    'board3': _LudoThemeStyles(
      bg: const Color(0xFFFFF8E1), // Light Gold/Cream
      p0: const Color(0xFFFFC107), // Amber
      p1: const Color(0xFFFFD54F), // Light Amber
      p2: const Color(0xFFFFE082), // Pale Amber
      p3: const Color(0xFFFFB300), // Vivid Amber
      path: const Color(0xFFFFF8E1),
      border: const Color(0xFFFFD54F),
      isRoyal: true,
    ),
    'river': _LudoThemeStyles(
      bg: const Color(0xFFFFF8E1), // Light Gold/Cream
      p0: const Color(0xFFFFC107), // Amber
      p1: const Color(0xFFFFD54F), // Light Amber
      p2: const Color(0xFFFFE082), // Pale Amber
      p3: const Color(0xFFFFB300), // Vivid Amber
      path: const Color(0xFFFFF8E1),
      border: const Color(0xFFFFD54F),
      isRoyal: true,
    ),
    'board4': _LudoThemeStyles(
      bg: const Color(0xFF006064), // Deep Teal
      p0: const Color(0xFFF44336), // Red
      p1: const Color(0xFF4CAF50), // Green
      p2: const Color(0xFFFFC107), // Yellow
      p3: const Color(0xFF03A9F4), // Light Blue
      path: const Color(0xFF00838F),
      border: const Color(0xFF0097A7),
    ),
    'board5': _LudoThemeStyles(
      bg: const Color(0xFF311B92), // Deep Purple
      p0: const Color(0xFFF44336), // Red
      p1: const Color(0xFF4CAF50), // Green
      p2: const Color(0xFFFFC107), // Yellow
      p3: const Color(0xFF9C27B0), // Purple
      path: const Color(0xFF4527A0),
      border: const Color(0xFF5E35B1),
    ),
    'board6': _LudoThemeStyles(
      bg: const Color(0xFF1B5E20), // Deep Forest Green
      p0: const Color(0xFFF44336), // Red
      p1: const Color(0xFF00C853), // Vivid Green
      p2: const Color(0xFFFFC107), // Yellow
      p3: const Color(0xFF03A9F4), // Light Blue
      path: const Color(0xFF2E7D32),
      border: const Color(0xFF388E3C),
    ),
    'board7': _LudoThemeStyles(
      bg: const Color(0xFF1B5E20), // Jungle Green
      p0: const Color(0xFFF44336), // Red
      p1: const Color(0xFF00C853), // Green
      p2: const Color(0xFFFFC107), // Yellow
      p3: const Color(0xFF03A9F4), // Light Blue
      path: const Color(0xFF2E7D32),
      border: const Color(0xFF388E3C),
    ),
    'board8': _LudoThemeStyles(
      bg: const Color(0xFF0D47A1), // Royal Blue
      p0: const Color(0xFFD32F2F), // Red
      p1: const Color(0xFF388E3C), // Green
      p2: const Color(0xFFFFA000), // Gold/Amber
      p3: const Color(0xFF1976D2), // Blue
      path: const Color(0xFF1565C0),
      border: const Color(0xFFFFD54F),
      isRoyal: true,
    ),
  };
  static const int boardGridSize = 15;
  double get boardSize => size.x < size.y ? size.x : size.y;
  double get cellSize => boardSize / boardGridSize;

  LudoGame({
    required this.onTokenTapped,
    this.playerCount = 4,
    this.boardTheme = 'classic',
    this.boardImageUrl,
    this.gameMode = 'local',
    this.currentMatchMode = 'classic',
    this.magicSeed,
    this.onlineRoomId,
    this.localPlayerId,
    this.onMagicEffect,
    this.magicToolsEnabled = false,
    Map<int, String>? initialShapes,
    Map<int, String>? initialThemes,
    Map<int, Map<String, String>>? initialUrlsMap,
  }) {
    if (initialShapes != null) playerShapes.addAll(initialShapes);
    if (initialThemes != null) playerTokenThemes.addAll(initialThemes);
    if (initialUrlsMap != null) playerTokenUrls.addAll(initialUrlsMap);
  }

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2(boardSize / 2, boardSize / 2);

    _gameWrapper.position = Vector2(boardSize / 2, boardSize / 2);
    _gameWrapper.anchor = Anchor.center;
    _gameWrapper.size = Vector2(boardSize, boardSize);
    world.add(_gameWrapper);
    updateTokenPositions(animate: false);

    _board = BoardComponent();
    _gameWrapper.add(_board!);
    _gameWrapper.angle = rotationIndex * (pi / 2);

    for (int p = 0; p < 4; p++) {
      for (int t = 0; t < 4; t++) {
        var token = TokenComponent(playerIndex: p, tokenIndex: t);
        _tokenComponents.add(token);
        _gameWrapper.add(token);
      }
    }

    _preloadTokens(); // Still fire-and-forget
    await _initSFX();

    if (magicToolsEnabled) {
      ludoXManager = LudoXManager(ludoGame: this);
      if (onlineRoomId != null && localPlayerId != null) {
        ludoXManager!.networkManager = LudoNetworkManager(
          roomId: onlineRoomId!,
          myPlayerId: localPlayerId!,
          gameRef: this,
        );
      }
      ludoXManager!.generateMagicTiles(seed: magicSeed);
    }

    world.add(BlackoutComponent());
    updateTokenPositions(animate: false);
  }

  @override
  void update(double dt) {
    super.update(dt);
    totalTime += dt;
  }

  Rect getCellRect(int row, int col) {
    return Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize);
  }

  void updateTokenPositions({
    bool animate = true,
    int? pIdxFilter,
    Set<int>? leavers,
  }) {
    for (var comp in _tokenComponents) {
      if (pIdxFilter != null && comp.playerIndex != pIdxFilter) continue;
      bool isLeaver = leavers?.contains(comp.playerIndex) ?? false;
      comp.refreshPosition(
        comp._currentProgress,
        tokens[comp.playerIndex][comp.tokenIndex],
        animate: animate,
        isLeaver: isLeaver,
      );
    }
  }

  void moveToken(int pIdx, int tIdx, int steps) {
    if (tokens[pIdx][tIdx] == 0) {
      if (steps == 6) tokens[pIdx][tIdx] = 1;
    } else {
      int newPos = tokens[pIdx][tIdx] + steps;
      if (newPos <= 57) tokens[pIdx][tIdx] = newPos;
    }
    updateTokenPositions();
  }

  void syncWithScreen(
    List<List<int>> newTokens,
    int current,
    int dice,
    bool rolled, {
    Set<int>? leavers,
  }) {
    for (int p = 0; p < 4; p++) {
      for (int t = 0; t < 4; t++) {
        tokens[p][t] = newTokens[p][t];
      }
    }
    currentPlayerIndex = current;
    diceValue = dice;
    hasRolled = rolled;
    updateTokenPositions(animate: true, leavers: leavers);
  }

  void syncHighlights(List<List<bool>> highlightMask) {
    for (var comp in _tokenComponents) {
      if (comp.playerIndex < highlightMask.length &&
          comp.tokenIndex < highlightMask[comp.playerIndex].length) {
        comp.isHighlighted = highlightMask[comp.playerIndex][comp.tokenIndex];
      } else {
        comp.isHighlighted = false;
      }
    }
  }

  void syncPlayerStyles(Map<int, String> shapes) => playerShapes = shapes;

  void setFlyingToken(int pIdx, int tIdx) {
    for (var comp in _tokenComponents) {
      if (comp.playerIndex == pIdx && comp.tokenIndex == tIdx) {
        comp.isFlyingWithRocket = true;
        break;
      }
    }
  }

  void snapTokenToProgress(int pIdx, int tIdx, int progress) {
    for (var comp in _tokenComponents) {
      if (comp.playerIndex == pIdx && comp.tokenIndex == tIdx) {
        comp.snapToProgress(progress);
        break;
      }
    }
  }

  void syncActivePlayers(Set<int> active) {
    activePlayers = active;
    updateTokenPositions(animate: false);
  }

  void updateRotation(int myIndex) {
    viewerPlayerIndex = myIndex;
    rotationIndex = (3 - myIndex + 4) % 4;
    _gameWrapper.angle = rotationIndex * (pi / 2);
  }

  void syncBlackout(bool active) => isBlackoutActive = active;

  // --- Audio Logic ---
  Future<void> _initSFX() async {
    try {
      await _dicePlayer.setAsset('assets/sounds/dice.mp3');
      for (var p in _movePlayers) {
        await p.setAsset(
          'assets/sounds/like.wav',
        ); // صوت حركة الأحجار (like.wav)
      }
      await _capturePlayer.setAsset('assets/sounds/uhao.mp3');
      await _slidePlayer.setAsset('assets/sounds/slide.wav');
      await _threeSixPlayer.setAsset('assets/sounds/threeSix.wav');
      await _quitPlayer.setAsset('assets/sounds/quit.wav');

      try {
        await _newTokenPlayer.setAsset('assets/sounds/like.wav');
      } catch (innerE) {
        debugPrint('Error loading newToken sound: $innerE');
      }

      debugPrint('Ludo SFX initialized successfully');
      updateVolumes();
    } catch (e) {
      debugPrint('Ludo SFX Error: $e');
    }
  }

  void updateVolumes({double? dice, double? sfx}) {
    if (dice != null) _diceVolume = dice;
    if (sfx != null) _sfxVolume = sfx;
    _dicePlayer.setVolume(_diceVolume);
    for (var p in _movePlayers) {
      p.setVolume(_sfxVolume * 1.5); // زيادة الصوت للتأكد من سماعه
    }
    _capturePlayer.setVolume(_sfxVolume);
    _slidePlayer.setVolume(_sfxVolume * 1.5);
    _threeSixPlayer.setVolume(_sfxVolume * 1.5); // Boosted
    _newTokenPlayer.setVolume(_sfxVolume * 1.5); // Boosted
    _quitPlayer.setVolume(_sfxVolume * 1.5); // Boosted (to ensure it's heard)
    _lastAppliedSfxVolume = _sfxVolume;
  }

  int _currentMovePlayerIndex = 0;

  void playMoveSound() {
    if (isMuted || _movePlayers.isEmpty) return;
    try {
      final player = _movePlayers[_currentMovePlayerIndex];

      // لا نكرر ضبط مستوى الصوت إلا إذا تغير فعلياً لتوفير الموارد وتقليل التقطيع
      if (_sfxVolume != _lastAppliedSfxVolume) {
        player.setVolume(sfxVolume);
      }

      player.seek(Duration.zero).then((_) {
        player.play();
      });

      _currentMovePlayerIndex =
          (_currentMovePlayerIndex + 1) % _movePlayers.length;
    } catch (e) {
      debugPrint('Error playing move sound: $e');
    }
  }

  void playNewTokenSound() {
    if (isMuted) return;
    try {
      // نستخدم دالة الحركة مباشرة لضمان الثبات التام وتجنب مشاكل المشغلات المستقلة
      playMoveSound();
    } catch (e) {
      debugPrint('Error playing newToken sound: $e');
    }
  }

  void playDiceSound() {
    if (isMuted) return;
    try {
      _dicePlayer.seek(Duration.zero);
      _dicePlayer.play();
    } catch (_) {}
  }

  void playCaptureSound() {
    if (isMuted) return;
    try {
      _capturePlayer.seek(Duration.zero);
      _capturePlayer.play();
    } catch (_) {}
  }

  void playSlideSound() {
    if (!isMuted) {
      _slidePlayer.seek(Duration.zero);
      _slidePlayer.play();
    }
  }

  void playThreeSixSound() async {
    if (isMuted) return;
    try {
      // إنشاء مشغل جديد في كل مرة لحل مشكلة التعليق (Hang) بعد إيقاف المحاكي
      final tempPlayer = AudioPlayer();
      await tempPlayer.setAsset('assets/sounds/threeSix.wav');
      await tempPlayer.setVolume(sfxVolume * 1.5);

      tempPlayer.play().then((_) {
        // حذفه من الذاكرة بعد 4 ثوانٍ (مدة تشغيل الصوت تقريباً)
        Future.delayed(const Duration(seconds: 4), () {
          tempPlayer.dispose();
        });
      });
    } catch (e) {
      debugPrint('[LudoGame] Error playing threeSix: $e');
    }
  }

  void playQuitSound() {
    if (isMuted) return;
    try {
      // Ensure volume is boosted for this important notification
      _quitPlayer.setVolume(_sfxVolume * 2.5);
      _quitPlayer.seek(Duration.zero).then((_) {
        _quitPlayer.play();
      });
      debugPrint('[LudoGame] Quit sound triggered.');
    } catch (e) {
      debugPrint('[LudoGame] Error playing quit sound: $e');
    }
  }

  @override
  void onRemove() {
    _dicePlayer.dispose();
    for (var p in _movePlayers) {
      p.dispose();
    }
    _capturePlayer.dispose();
    _slidePlayer.dispose();
    _threeSixPlayer.dispose();
    _newTokenPlayer.dispose();
    _quitPlayer.dispose();
    super.onRemove();
  }
}

class BoardComponent extends PositionComponent with HasGameRef<LudoGame> {
  Sprite? _bgSprite;

  static const Map<String, String> _imageThemeAssets = {
    'classic': 'classk.jpg',
    'river': '3.jpg',
    'tawla': 'tawlaa.png',
    'board1': '1.jpg',
    'board2': '2.jpg',
    'board3': '3.jpg',
    'board4': '4.jpg',
    'board5': '5.jpg',
    'board6': '6.jpg',
    'board7': '7.jpg',
    'board8': '8.jpg',
    'ice': 'ludo_ice_board.png',
  };

  // ── ابعاد كل نمط صورة ─────────────────────────────────────────────────────
  // dx    : الإزاحة الأفقية (+ يمين / - يسار) بالبيكسل
  // dy    : الإزاحة العمودية (+ أسفل / - أعلى) بالبيكسل
  // scale : نسبة التكبير (1.0 = حجم الطاولة، 0.95 = أصغر قليلاً، 1.05 = أكبر)
  // ─────────────────────────────────────────────────────────────────────────────
  static const Map<String, Map<String, double>> _imageThemeAdjust = {
    'classic': {'dx': 0.0, 'dy': 0.0, 'scale': 1.0},
    'river': {'dx': 0.0, 'dy': 2.0, 'scale': 1.04},
    'tawla': {'dx': 0.0, 'dy': 0.0, 'scale': 1.0},
    'board1': {'dx': 0.0, 'dy': 0.0, 'scale': 1.05},
    'board2': {'dx': 0.0, 'dy': 0.0, 'scale': 1.04},
    'board3': {'dx': 0.0, 'dy': 2.0, 'scale': 1.04},
    'board4': {'dx': 0.0, 'dy': 2.2, 'scale': 1.02},
    'board5': {'dx': 1.0, 'dy': 0.0, 'scale': 1.07},
    'board6': {'dx': 0.0, 'dy': 0.0, 'scale': 1.0},
    'board7': {'dx': 0.0, 'dy': 4.0, 'scale': 1.1},
    'board8': {'dx': 0.0, 'dy': 0.0, 'scale': 1.0},
    'ice': {'dx': 0.0, 'dy': 0.0, 'scale': 1.0},
  };

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await refreshTheme();
  }

  Future<void> refreshTheme() async {
    final theme = gameRef.boardTheme;
    final url = gameRef.boardImageUrl;

    if (url != null && url.isNotEmpty) {
      final image = await gameRef._fetchNetworkImage(url);
      if (image != null) {
        _bgSprite = Sprite(image);
        return;
      }
    }

    if (theme.startsWith('http')) {
      final image = await gameRef._fetchNetworkImage(theme);
      if (image != null) {
        _bgSprite = Sprite(image);
      }
    } else {
      final asset = _imageThemeAssets[theme];
      if (asset != null) {
        _bgSprite = await gameRef.loadSprite(asset);
      } else {
        _bgSprite = null;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_bgSprite != null) {
      // Apply per-theme adjustments
      final adj =
          _imageThemeAdjust[gameRef.boardTheme] ??
          {'dx': 0.0, 'dy': 0.0, 'scale': 1.0};
      final double dx = adj['dx'] ?? 0.0;
      final double dy = adj['dy'] ?? 0.0;
      final double scale = adj['scale'] ?? 1.0;
      final double s = gameRef.boardSize;
      final double sw = s * scale;
      final double sh = s * scale;

      // Center the scaled image, then apply dx/dy offset
      final double originX = (s - sw) / 2 + dx;
      final double originY = (s - sh) / 2 + dy;

      canvas.save();
      canvas.translate(originX, originY);
      _bgSprite!.render(canvas, size: Vector2(sw, sh));
      canvas.restore();

      // Draw transparent grid overlay so tokens always align with correct cells
      // _drawTransparentOverlay(canvas); // مخفي - يمكن تفعيله للمساعدة في الضبط
      return;
    }

    // Default to Drawing a High-Quality Animated Board based on theme
    _drawThemedBoard(canvas);
  }

  /// Draws a semi-transparent game grid on top of the background image.
  /// This ensures token positions align correctly no matter what the image looks like.
  void _drawTransparentOverlay(Canvas canvas) {
    final theme = LudoGame.themes['classic']!;

    // Slightly transparent stroke for cell borders
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw path cells with transparent fill
    for (int i = 0; i < 52; i++) {
      Point p = PathUtils.globalTrack[i];
      Rect r = gameRef.getCellRect(p.y.toInt(), p.x.toInt());

      bool isStart = [0, 13, 26, 39].contains(i);
      bool isStar = [8, 21, 34, 47].contains(i);

      Color? highlightColor;
      if (isStart) {
        final colors = [theme.p0, theme.p1, theme.p2, theme.p3];
        highlightColor = colors[i ~/ 13];
      }

      // Draw subtle highlight for start and star cells only
      if (highlightColor != null) {
        canvas.drawRect(
          r,
          Paint()..color = highlightColor.withValues(alpha: 0.25),
        );
      }
      canvas.drawRect(r, strokePaint);

      if (isStart)
        _drawStarIcon(
          canvas,
          r,
          Colors.white.withValues(alpha: 0.6),
          sizeMult: 0.7,
        );
      if (isStar)
        _drawStarIcon(
          canvas,
          r,
          Colors.amber.withValues(alpha: 0.7),
          sizeMult: 0.7,
        );
    }

    // Draw home paths with colored transparency
    final homeColors = [theme.p0, theme.p1, theme.p2, theme.p3];
    for (int pIdx = 0; pIdx < 4; pIdx++) {
      final pts = PathUtils.getHomePath(pIdx);
      for (var p in pts) {
        Rect r = gameRef.getCellRect(p.y.toInt(), p.x.toInt());
        canvas.drawRect(
          r,
          Paint()..color = homeColors[pIdx].withValues(alpha: 0.30),
        );
        canvas.drawRect(r, strokePaint);
      }
    }

    // Draw base areas with colored ring
    final basePositions = [
      [0, 0],
      [0, 9],
      [9, 9],
      [9, 0],
    ];
    for (int i = 0; i < 4; i++) {
      double cs = gameRef.cellSize;
      Rect outerRect = Rect.fromLTWH(
        basePositions[i][1] * cs,
        basePositions[i][0] * cs,
        6 * cs,
        6 * cs,
      );
      // Draw subtle border ring only
      canvas.drawRRect(
        RRect.fromRectAndRadius(outerRect, const Radius.circular(12)),
        Paint()
          ..color = homeColors[i].withValues(alpha: 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // Draw center triangles with low opacity
    Rect centerRect = Rect.fromLTWH(
      6 * gameRef.cellSize,
      6 * gameRef.cellSize,
      3 * gameRef.cellSize,
      3 * gameRef.cellSize,
    );
    Offset center = centerRect.center;
    void drawTri(Offset p1, Offset p2, Offset p3, Color c) {
      Path path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = c.withValues(alpha: 0.30));
    }

    drawTri(center, centerRect.topLeft, centerRect.bottomLeft, theme.p0);
    drawTri(center, centerRect.topLeft, centerRect.topRight, theme.p1);
    drawTri(center, centerRect.topRight, centerRect.bottomRight, theme.p2);
    drawTri(center, centerRect.bottomLeft, centerRect.bottomRight, theme.p3);
  }

  void _drawThemedBoard(Canvas canvas) {
    final double s = gameRef.boardSize;
    final theme =
        LudoGame.themes[gameRef.boardTheme] ?? LudoGame.themes['classic']!;

    // 1. Draw Main Background
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), Paint()..color = theme.bg);

    if (theme.isNeon) {
      // Add subtle glow to background
      final glowPaint = Paint()
        ..color = Colors.indigo.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
      canvas.drawCircle(Offset(s / 2, s / 2), s / 2.5, glowPaint);
    }

    final strokePaint = Paint()
      ..color = theme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.isNeon ? 1.0 : 1.5;

    // 2. Draw 52 Path Cells
    for (int i = 0; i < 52; i++) {
      Point p = PathUtils.globalTrack[i];
      Rect r = gameRef.getCellRect(p.y.toInt(), p.x.toInt());

      Color cellColor = theme.path;
      bool isStar = false;
      bool isStart = false;

      if (i == 0) {
        cellColor = theme.p0;
        isStart = true;
      } else if (i == 13) {
        cellColor = theme.p1;
        isStart = true;
      } else if (i == 26) {
        cellColor = theme.p2;
        isStart = true;
      } else if (i == 39) {
        cellColor = theme.p3;
        isStart = true;
      } else if ([8, 21, 34, 47].contains(i)) {
        isStar = true;
        cellColor = theme.isNeon
            ? theme.bg.withValues(alpha: 0.8)
            : Colors.black.withValues(alpha: 0.05);
      }

      // Fill cell
      if (theme.isNeon && isStart) {
        // Glowing start cells
        canvas.drawRect(r, Paint()..color = cellColor.withValues(alpha: 0.3));
        canvas.drawRect(r.deflate(2), Paint()..color = cellColor);
      } else {
        canvas.drawRect(r, Paint()..color = cellColor);
      }

      // Draw borders
      canvas.drawRect(r, strokePaint);

      // Icons
      if (isStart) _drawStarIcon(canvas, r, Colors.white, sizeMult: 0.7);
      if (isStar) {
        _drawStarIcon(
          canvas,
          r,
          theme.isNeon ? Colors.amber : Colors.grey.shade600,
          sizeMult: 0.7,
        );
      }
    }

    // 3. Draw Home Paths
    _drawHomeColumn(canvas, 0, theme.p0, theme);
    _drawHomeColumn(canvas, 1, theme.p1, theme);
    _drawHomeColumn(canvas, 2, theme.p2, theme);
    _drawHomeColumn(canvas, 3, theme.p3, theme);

    // 4. Draw The 4 Bases
    _drawBase(canvas, 0, 0, theme.p0, theme);
    _drawBase(canvas, 0, 9, theme.p1, theme);
    _drawBase(canvas, 9, 9, theme.p2, theme);
    _drawBase(canvas, 9, 0, theme.p3, theme);

    // 5. Draw Center Triangles
    _drawCenterTriangles(canvas, theme);
  }

  void _drawBase(
    Canvas canvas,
    int r,
    int c,
    Color color,
    _LudoThemeStyles theme,
  ) {
    double cs = gameRef.cellSize;
    Rect outerRect = Rect.fromLTWH(c * cs, r * cs, 6 * cs, 6 * cs);

    if (theme.isRoyal) {
      // Elegant marble base
      canvas.drawRRect(
        RRect.fromRectAndRadius(outerRect, const Radius.circular(15)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              color,
              color.withValues(alpha: 0.8),
              color.withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(outerRect),
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(outerRect, const Radius.circular(12)),
        Paint()..color = color,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, const Radius.circular(12)),
      Paint()
        ..color = theme.isNeon ? color.withValues(alpha: 0.3) : Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Inner White Square
    Rect innerRect = outerRect.deflate(cs * 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, const Radius.circular(10)),
      Paint()..color = theme.isNeon ? theme.bg : Colors.white,
    );

    // Resting Circles
    double spotSize = cs * 1.6;
    List<Offset> spots = [
      innerRect.center + Offset(-spotSize / 1.8, -spotSize / 1.8),
      innerRect.center + Offset(spotSize / 1.8, -spotSize / 1.8),
      innerRect.center + Offset(-spotSize / 1.8, spotSize / 1.8),
      innerRect.center + Offset(spotSize / 1.8, spotSize / 1.8),
    ];

    for (var s in spots) {
      canvas.drawCircle(
        s,
        cs * 0.6,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = theme.isNeon ? 2 : 3,
      );
      canvas.drawCircle(
        s,
        cs * 0.55,
        Paint()..color = color.withValues(alpha: theme.isNeon ? 0.1 : 0.15),
      );
    }
  }

  void _drawHomeColumn(
    Canvas canvas,
    int pIdx,
    Color color,
    _LudoThemeStyles theme,
  ) {
    List<Point> pts = PathUtils.getHomePath(pIdx);
    final strokePaint = Paint()
      ..color = theme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var p in pts) {
      Rect r = gameRef.getCellRect(p.y.toInt(), p.x.toInt());
      if (theme.isNeon) {
        canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.2));
        canvas.drawRect(r.deflate(4), Paint()..color = color);
      } else {
        canvas.drawRect(r, Paint()..color = color);
      }
      canvas.drawRect(r, strokePaint);
    }
  }

  void _drawCenterTriangles(Canvas canvas, _LudoThemeStyles theme) {
    Rect r = Rect.fromLTWH(
      6 * gameRef.cellSize,
      6 * gameRef.cellSize,
      3 * gameRef.cellSize,
      3 * gameRef.cellSize,
    );
    Offset center = r.center;

    void drawTri(Offset p1, Offset p2, Offset p3, Color c) {
      Path path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();
      if (theme.isNeon) {
        canvas.drawPath(path, Paint()..color = c.withValues(alpha: 0.4));
        canvas.drawPath(
          path,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawPath(path, Paint()..color = c);
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.black26
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    drawTri(center, r.topLeft, r.bottomLeft, theme.p0);
    drawTri(center, r.topLeft, r.topRight, theme.p1);
    drawTri(center, r.topRight, r.bottomRight, theme.p2);
    drawTri(center, r.bottomLeft, r.bottomRight, theme.p3);
  }

  void _drawStarIcon(
    Canvas canvas,
    Rect rect,
    Color color, {
    double sizeMult = 0.8,
  }) {
    TextPainter tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: String.fromCharCode(Icons.star.codePoint),
      style: TextStyle(
        fontSize: rect.width * sizeMult,
        fontFamily: Icons.star.fontFamily,
        color: color,
      ),
    );
    tp.layout();
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }
}

class BlackoutComponent extends PositionComponent with HasGameRef<LudoGame> {
  @override
  Future<void> onLoad() async {
    priority = 10000;
    size = Vector2.all(5000);
    anchor = Anchor.center;
    position = Vector2(gameRef.boardSize / 2, gameRef.boardSize / 2);
  }

  @override
  void render(Canvas canvas) {
    if (!gameRef.isBlackoutActive) return;

    canvas.saveLayer(size.toRect(), Paint());
    canvas.drawRect(
      size.toRect(),
      Paint()..color = Colors.black.withValues(alpha: 0.98),
    );

    final holePaint = Paint()..blendMode = BlendMode.clear;
    final int myIdx = gameRef.viewerPlayerIndex;

    for (final token in gameRef._tokenComponents) {
      if (token.playerIndex != myIdx) continue;
      final int progress = gameRef.tokens[token.playerIndex][token.tokenIndex];
      if (progress == 0) continue;

      final localPos = absoluteToLocal(token.absolutePosition);
      final double holeRadius = token.isHighlighted
          ? gameRef.cellSize * 1.1
          : gameRef.cellSize * 0.7;

      canvas.drawCircle(Offset(localPos.x, localPos.y), holeRadius, holePaint);
      canvas.drawCircle(
        Offset(localPos.x, localPos.y),
        holeRadius,
        Paint()
          ..blendMode = BlendMode.srcOver
          ..color = token.isHighlighted
              ? Colors.yellowAccent.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            token.isHighlighted ? 10 : 5,
          ),
      );
    }
    canvas.restore();
  }
}

class TokenComponent extends SpriteComponent
    with TapCallbacks, HasGameRef<LudoGame> {
  final int playerIndex, tokenIndex;
  int _currentProgress = -1;
  int _targetProgress = -1;
  bool isFlyingWithRocket = false;

  TokenComponent({required this.playerIndex, required this.tokenIndex}) {
    anchor = Anchor.center;
  }

  void resetState() {
    _currentProgress = 0;
    _targetProgress = 0;
    refreshPosition(0, 0, animate: false);
  }

  void _updatePriority({bool isMoving = false}) {
    if (!isMounted) return;
    int p = playerIndex * 10 + tokenIndex;
    if (playerIndex == gameRef.viewerPlayerIndex) p += 2000;
    if (isMoving) p += 5000;
    priority = p;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    String currentShape = gameRef.playerShapes[playerIndex] ?? 'pawn';
    String colorName = ['red', 'green', 'yellow', 'blue'][playerIndex];

    // Check for network token URLs from the shop
    String? customUrl;
    final urls = gameRef.playerTokenUrls[playerIndex];
    if (urls != null) {
      // البحث عن المفتاح بطريقة غير حساسة لحالة الأحرف (red, Red, RED كلها تعمل)
      String targetKey = colorName.toLowerCase();
      urls.forEach((key, value) {
        if (key.toLowerCase() == targetKey) {
          customUrl = value;
        }
      });
      if (customUrl == null) {
        debugPrint(
          "No custom URL found for $colorName. Available keys: ${urls.keys}",
        );
      }
    }

    // 1. Always load local token first for immediate display
    await _loadLocalToken(colorName, currentShape);

    // 2. If a custom URL exists, try to load it in the background
    if (customUrl != null && customUrl!.isNotEmpty) {
      _applyNetworkToken(customUrl!);
    }

    double baseScale =
        1.00; // Adjusted from 1.1 to be exactly cell size at 1.0 scale
    size = Vector2.all(gameRef.cellSize * baseScale);
    _updatePriority();
    int startProgress = gameRef.tokens[playerIndex][tokenIndex];
    refreshPosition(_currentProgress, startProgress, animate: false);
  }

  Future<void> refreshSprite() async {
    String currentShape = gameRef.playerShapes[playerIndex] ?? 'pawn';
    String colorName = ['red', 'green', 'yellow', 'blue'][playerIndex];

    String? customUrl;
    final urls = gameRef.playerTokenUrls[playerIndex];
    if (urls != null) {
      String targetKey = colorName.toLowerCase();
      urls.forEach((key, value) {
        if (key.toLowerCase() == targetKey) {
          customUrl = value;
        }
      });
    }

    // 1. Load local pawn shape
    await _loadLocalToken(colorName, currentShape);

    // 2. If custom theme, load it
    if (customUrl != null && customUrl!.isNotEmpty) {
      _applyNetworkToken(customUrl!);
    }
  }

  Future<void> _applyNetworkToken(String url) async {
    try {
      final ui.Image? cachedImage = await gameRef._fetchNetworkImage(url);
      if (cachedImage != null && isMounted) {
        sprite = Sprite(cachedImage);
      }
    } catch (e) {
      debugPrint("Background token load failed: $e");
    }
  }

  Future<void> _loadLocalToken(String colorName, String shape) async {
    const basicShapes = ['pawn', 'star', 'shield'];
    String safeShape = basicShapes.contains(shape) ? shape : 'pawn';
    String assetPath = (safeShape == 'pawn')
        ? 'token_$colorName.png'
        : 'token_${safeShape}_$colorName.png';

    try {
      sprite = await gameRef.loadSprite(assetPath);
    } catch (e) {
      debugPrint(
        "Asset $assetPath not found, using default token_$colorName.png",
      );
      try {
        sprite = await gameRef.loadSprite('token_$colorName.png');
      } catch (innerE) {
        debugPrint("CRITICAL: Default asset token_$colorName.png missing!");
      }
    }
  }

  bool isHighlighted = false;
  double _pulseTime = 0;

  @override
  void update(double dt) {
    super.update(dt);
    angle = -gameRef._gameWrapper.angle; // Keep token upright
    if (isHighlighted) {
      _pulseTime += dt;
    } else {
      _pulseTime = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!gameRef.activePlayers.contains(playerIndex)) return;
    double radius = size.x / 2;

    if (isHighlighted) {
      final double pulse = (sin(_pulseTime * 5) + 1) / 2;
      canvas.drawCircle(
        Offset(radius, radius),
        radius * (1.1 + pulse * 0.1),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3 + pulse * 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        Offset(radius, radius),
        radius * (1.05 + pulse * 0.05),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5 + pulse * 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    canvas.drawCircle(
      Offset(radius + 2, radius + 2),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    super.render(canvas);
  }

  void refreshPosition(
    int oldProgress,
    int newProgress, {
    bool animate = true,
    bool isLeaver = false,
  }) {
    if (newProgress == _targetProgress) return;
    _targetProgress = newProgress;

    if (newProgress == oldProgress) return;

    if (!animate) {
      _currentProgress = newProgress;
      _finishMove(newProgress);
      return;
    }

    // التحقق من أكل الخصم (منع الصوت إذا كان الحجر يعود بسبب مغادرة اللاعب)
    if (oldProgress > 0 && newProgress == 0 && !isLeaver) {
      gameRef.playCaptureSound(); // تأكد أن لديك دالة لهذا الصوت إن أردت
    }

    // حالة نزول حجرة جديدة (تمت إزالة الصوت من هنا لتخفيف الثقل)
    if (oldProgress == 0 && newProgress == 1) {
      _currentProgress = newProgress;
      _animateToStep(1);
    }
    // حالة الطيران بالصاروخ (عند تفعيل مفتاح الطيران الصريح فقط)
    else if (isFlyingWithRocket && oldProgress > 0) {
      isFlyingWithRocket = false; // إعادة تعيين المفتاح بعد استخدامه
      removeAll(children.whereType<MoveEffect>());
      removeAll(children.whereType<SequenceEffect>());
      removeAll(children.whereType<ScaleEffect>());
      _updatePriority(isMoving: true);

      // تشغيل صوت تحليق مميز للحجر
      gameRef.playSlideSound();

      Vector2 startPos = position.clone();
      Vector2 targetPos = _getPosForProgress(newProgress);
      Vector2 midpoint = (startPos + targetPos) / 2;
      // نقطة ذروة الارتفاع (تقوس أعلى لإعطاء إحساس حقيقي بالارتفاع الفائق متناسباً مع الحجم الكبير)
      Vector2 apexPos = midpoint - Vector2(0, 120);

      double finalScale = _getTargetScale(newProgress);

      // 1. حركة الطيران المنحنية (قوس بارابولي)
      add(
        SequenceEffect(
          [
            MoveEffect.to(
              apexPos,
              EffectController(duration: 0.75, curve: Curves.easeOutCubic),
            ),
            MoveEffect.to(
              targetPos,
              EffectController(duration: 0.75, curve: Curves.easeInCubic),
            ),
          ],
          onComplete: () {
            _currentProgress = newProgress;
            _updatePriority(isMoving: false);
            _finishMove(newProgress);
          },
        ),
      );

      // 2. تأثير التكبير الفائق والهبوط المتزامن مع الطيران للقوس
      add(
        SequenceEffect([
          ScaleEffect.to(
            Vector2.all(1.8), // تكبير فائق ومبهر أثناء التحليق في الهواء
            EffectController(duration: 0.75, curve: Curves.easeOut),
          ),
          ScaleEffect.to(
            Vector2.all(finalScale), // هبوط متناسب ومتناسق إلى الحجم المستقر
            EffectController(duration: 0.75, curve: Curves.easeIn),
          ),
        ]),
      );
    }
    // حالة المشي خطوة بخطوة
    else if (newProgress > oldProgress && oldProgress > 0) {
      List<Effect> steps = [];

      const double stepDuration = 0.20;

      for (int i = oldProgress + 1; i <= newProgress; i++) {
        final int targetProgress = i;
        steps.add(
          MoveEffect.to(
            _getPosForProgress(i),
            EffectController(duration: stepDuration, curve: Curves.linear),
            onComplete: () {
              _currentProgress = targetProgress;
              // 🎵 هنا يشتغل صوت like1.wav مع كل خطوة على اللوحة
              gameRef.playMoveSound();
            },
          ),
        );
      }

      removeAll(children.whereType<MoveEffect>());
      removeAll(children.whereType<SequenceEffect>());
      removeAll(children.whereType<ScaleEffect>());
      _updatePriority(isMoving: true);

      // ── تأثير تكبير الحجر عند المشي ──
      add(
        ScaleEffect.to(
          Vector2.all(1.02), // تكبير متناسق ولطيف أثناء الخطوات
          EffectController(duration: 0.2, curve: Curves.easeOut),
        ),
      );

      add(
        SequenceEffect(
          steps,
          onComplete: () {
            _updatePriority(isMoving: false);
            _finishMove(newProgress);

            // العودة للحجم الطبيعي بعد التوقف
            double finalScale = _getTargetScale(newProgress);
            add(
              ScaleEffect.to(
                Vector2.all(finalScale),
                EffectController(duration: 0.2, curve: Curves.easeIn),
              ),
            );
          },
        ),
      );
    } else {
      _currentProgress = newProgress;
      _animateToStep(newProgress);
    }
  }

  void _finishMove(int progress) {
    position = _getPosForProgress(progress);
    _currentProgress = progress;
    scale = Vector2.all(_getTargetScale(progress));
    _updatePriority(isMoving: false);
    removeAll(children.whereType<MoveEffect>());
    removeAll(children.whereType<SequenceEffect>());
    removeAll(children.whereType<ScaleEffect>());
    isFlyingWithRocket = false; // تصفية الإشارة فور انتهاء أي حركة منعاً للتسريب
  }

  void snapToProgress(int progress) {
    removeAll(children.whereType<MoveEffect>());
    removeAll(children.whereType<SequenceEffect>());
    removeAll(children.whereType<ScaleEffect>());
    _currentProgress = progress;
    _targetProgress = progress;
    position = _getPosForProgress(progress);
    scale = Vector2.all(_getTargetScale(progress));
    _updatePriority(isMoving: false);
  }

  void _animateToStep(int progress) {
    Vector2 target = _getPosForProgress(progress);
    removeAll(children.whereType<MoveEffect>());
    removeAll(children.whereType<SequenceEffect>());
    removeAll(children.whereType<ScaleEffect>());

    _updatePriority(isMoving: true);

    const double jumpDuration = 0.25;

    add(
      MoveEffect.to(
        target,
        EffectController(duration: jumpDuration, curve: Curves.easeOut),
        onComplete: () {
          _currentProgress = progress;
          _updatePriority(isMoving: false);
        },
      ),
    );

    double targetScale = _getTargetScale(progress);
    add(
      ScaleEffect.to(
        Vector2.all(targetScale),
        EffectController(duration: 0.25, curve: Curves.easeOut),
      ),
    );
  }

  double _getTargetScale(int progress) {
    if (progress == 0) return 1.22; // بارز، مميز، وضخم داخل القاعدة قبل النزول
    if (progress == 57) return 0.78; // متناسق في النهاية
    return 0.88; // حجم متناسب وجميل جداً يملأ أغلب المربع مع هوامش أنيقة
  }

  Vector2 _getPosForProgress(int progress) {
    if (progress == 0) return _basePos();
    if (progress == 57) {
      Point p = PathUtils.getCoords(playerIndex, progress);
      Rect r = gameRef.getCellRect(p.y.toInt(), p.x.toInt());
      Vector2 center = Vector2(r.center.dx, r.center.dy);

      double offset = gameRef.cellSize * 0.22;
      double dx = 0, dy = 0;

      // Arrange in a triangle (1 at apex, 3 in row)
      // The "apex" points toward the center of the board.
      if (tokenIndex == 0) {
        // Apex token
        switch (playerIndex) {
          case 0:
            dx = offset;
            break; // Blue (Left) -> move Right
          case 1:
            dy = offset;
            break; // Red (Top) -> move Down
          case 2:
            dx = -offset;
            break; // Green (Right) -> move Left
          case 3:
            dy = -offset;
            break; // Yellow (Bottom) -> move Up
        }
      } else {
        // Base row tokens (indices 1, 2, 3)
        double rowOffset = -offset * 0.8; // Move back from center
        double sideOffset =
            (tokenIndex - 2) * (offset * 1.1); // Spread out (-1, 0, 1)

        switch (playerIndex) {
          case 0: // Blue (Left)
            dx = rowOffset;
            dy = sideOffset;
            break;
          case 1: // Red (Top)
            dy = rowOffset;
            dx = sideOffset;
            break;
          case 2: // Green (Right)
            dx = -rowOffset;
            dy = sideOffset;
            break;
          case 3: // Yellow (Bottom)
            dy = -rowOffset;
            dx = sideOffset;
            break;
        }
      }
      return center + Vector2(dx, dy);
    }

    Point p = PathUtils.getCoords(playerIndex, progress);
    Rect r = gameRef.getCellRect(p.y.toInt(), p.x.toInt());
    Vector2 baseCenter = Vector2(r.center.dx, r.center.dy);

    int sharedCount = 0;
    int myOrderIndex = 0;
    for (int oi = 0; oi < 4; oi++) {
      for (int ti = 0; ti < 4; ti++) {
        int tProg = gameRef.tokens[oi][ti];
        if (tProg > 0 && tProg <= 56) {
          Point tPoint = PathUtils.getCoords(oi, tProg);
          if (tPoint.x == p.x && tPoint.y == p.y) {
            if (oi == playerIndex && ti == tokenIndex) {
              myOrderIndex = sharedCount;
            }
            sharedCount++;
          }
        }
      }
    }

    double dx = 0, dy = 0;
    bool isAnimating = gameRef.tokens[playerIndex][tokenIndex] != progress;

    if (sharedCount > 1 || (sharedCount == 1 && isAnimating)) {
      double offsetAmt = gameRef.cellSize * 0.15;
      int idx = isAnimating ? tokenIndex : myOrderIndex;
      if (idx % 4 == 0) {
        dx = -offsetAmt;
        dy = -offsetAmt;
      } else if (idx % 4 == 1) {
        dx = offsetAmt;
        dy = -offsetAmt;
      } else if (idx % 4 == 2) {
        dx = -offsetAmt;
        dy = offsetAmt;
      } else {
        dx = offsetAmt;
        dy = offsetAmt;
      }
    }
    return baseCenter + Vector2(dx, dy);
  }

  Vector2 _basePos() {
    double s = gameRef.cellSize;
    Rect baseRect;
    if (playerIndex == 0) {
      baseRect = Rect.fromLTWH(0, 0, 6 * s, 6 * s); // Red (Top-Left)
    } else if (playerIndex == 1)
      baseRect = Rect.fromLTWH(9 * s, 0, 6 * s, 6 * s); // Green (Top-Right)
    else if (playerIndex == 2)
      baseRect = Rect.fromLTWH(
        9 * s,
        9 * s,
        6 * s,
        6 * s,
      ); // Yellow (Bottom-Right)
    else
      baseRect = Rect.fromLTWH(0, 9 * s, 6 * s, 6 * s); // Blue (Bottom-Left)

    double cx = baseRect.center.dx;
    double cy = baseRect.center.dy;
    double o = s * 1.6 / 1.8; // Match BoardComponent._drawBase offset
    List<Vector2> offsets = [
      Vector2(cx - o, cy - o),
      Vector2(cx + o, cy - o),
      Vector2(cx - o, cy + o),
      Vector2(cx + o, cy + o),
    ];
    return offsets[tokenIndex % 4];
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (gameRef.allowTokenInteraction) {
      gameRef.onTokenTapped(playerIndex, tokenIndex);
    }
  }
}

class PathUtils {
  static const List<Point> globalTrack = [
    Point(1, 6),
    Point(2, 6),
    Point(3, 6),
    Point(4, 6),
    Point(5, 6),
    Point(6, 5),
    Point(6, 4),
    Point(6, 3),
    Point(6, 2),
    Point(6, 1),
    Point(6, 0),
    Point(7, 0),
    Point(8, 0),
    Point(8, 1),
    Point(8, 2),
    Point(8, 3),
    Point(8, 4),
    Point(8, 5),
    Point(9, 6),
    Point(10, 6),
    Point(11, 6),
    Point(12, 6),
    Point(13, 6),
    Point(14, 6),
    Point(14, 7),
    Point(14, 8),
    Point(13, 8),
    Point(12, 8),
    Point(11, 8),
    Point(10, 8),
    Point(9, 8),
    Point(8, 9),
    Point(8, 10),
    Point(8, 11),
    Point(8, 12),
    Point(8, 13),
    Point(8, 14),
    Point(7, 14),
    Point(6, 14),
    Point(6, 13),
    Point(6, 12),
    Point(6, 11),
    Point(6, 10),
    Point(6, 9),
    Point(5, 8),
    Point(4, 8),
    Point(3, 8),
    Point(2, 8),
    Point(1, 8),
    Point(0, 8),
    Point(0, 7),
    Point(0, 6),
  ];

  static Point getCoords(int pIdx, int progress) {
    if (progress > 51) return getHomePath(pIdx)[progress - 52];
    int offset = [0, 13, 26, 39][pIdx];
    return globalTrack[(progress - 1 + offset) % 52];
  }

  static List<Point> getHomePath(int pIdx) {
    if (pIdx == 0) {
      return [
        Point(1, 7),
        Point(2, 7),
        Point(3, 7),
        Point(4, 7),
        Point(5, 7),
        Point(6.5, 7.5),
      ]; // Red (Left Home)
    }
    if (pIdx == 1) {
      return [
        Point(7, 1),
        Point(7, 2),
        Point(7, 3),
        Point(7, 4),
        Point(7, 5),
        Point(7.5, 6.5),
      ]; // Green
    }
    if (pIdx == 2) {
      return [
        Point(13, 7),
        Point(12, 7),
        Point(11, 7),
        Point(10, 7),
        Point(9, 7),
        Point(8.5, 7.5),
      ]; // Yellow
    }
    return [
      Point(7, 13),
      Point(7, 12),
      Point(7, 11),
      Point(7, 10),
      Point(7, 9),
      Point(7.5, 8.5),
    ]; // Blue
  }
}
