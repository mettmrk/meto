// ignore_for_file: unnecessary_import, curly_braces_in_flow_control_structures
import 'ludo_game.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:firebase_database/firebase_database.dart';

// ==========================================
// 1. النماذج والأنواع الأساسية (Models & Enums)
// ==========================================
enum MagicTileType { normal, rocket, dice }

class LudoXEffectResult {
  final int newProgress;
  final String message;
  final MagicTileType type;

  LudoXEffectResult({
    required this.newProgress,
    required this.message,
    required this.type,
  });
}

// ==========================================
// 2. مدير منطق "لودو إكس" (Game Logic Manager)
// ==========================================
class LudoXManager {
  final LudoGame? ludoGame;
  LudoNetworkManager? networkManager; // 🌟 تمت إضافته لربط السحر بالشبكة

  final Random _random = Random();
  final Map<int, MagicTileType> magicTiles = {};
  final List<MagicItemComponent> magicItemComponents = [];

  LudoXManager({this.ludoGame, this.networkManager});

  void generateMagicTiles({int? seed}) {
    // 🔑 في وضع الأونلاين، لا نولّد العناصر بدون بذرة محددة من السيرفر
    // لضمان أن جميع اللاعبين يرون نفس الترتيب
    if (seed == null && (ludoGame?.gameMode == 'online')) {
      // سننتظر البذرة القادمة من Firebase عبر _handleRoomUpdate
      return;
    }

    magicTiles.clear();
    final random = seed != null ? Random(seed) : Random();
    List<int> availableIndices = List.generate(52, (index) => index);

    // استثناء المربعات الآمنة
    availableIndices.removeWhere(
      (i) => [0, 8, 13, 21, 26, 34, 39, 47].contains(i),
    );
    availableIndices.shuffle(random);

    // توزيع الأدوات السحرية
    for (int i = 0; i < 3; i++) {
      if (availableIndices.isNotEmpty)
        magicTiles[availableIndices.removeLast()] = MagicTileType.rocket;
    }
    for (int i = 0; i < 2; i++) {
      if (availableIndices.isNotEmpty)
        magicTiles[availableIndices.removeLast()] = MagicTileType.dice;
    }

    _syncMagicItemComponents();
  }

  void updateTilesDirectly(Map<int, MagicTileType> newTiles) {
    magicTiles.clear();
    magicTiles.addAll(newTiles);
    _syncMagicItemComponents();
  }

  void _syncMagicItemComponents() {
    if (ludoGame == null) return;

    // إزالة العناصر القديمة من اللعبة
    for (var comp in magicItemComponents) {
      if (comp.isMounted || comp.parent != null) {
        comp.removeFromParent();
      }
    }
    magicItemComponents.clear();

    magicTiles.forEach((index, itemType) {
      if (itemType != MagicTileType.normal) {
        Point<num> p = PathUtils.globalTrack[index];
        final cellSize = ludoGame!.cellSize;
        Rect r = ludoGame!.getCellRect(p.y.toInt(), p.x.toInt());

        var comp = MagicItemComponent(
          itemType: itemType,
          position: Vector2(r.center.dx, r.center.dy), // Anchor is Center!
          size: Vector2(cellSize * 0.70, cellSize * 0.70), // أصغر حجماً لتناسب حجم المربعات بشكل ممتاز
        );
        magicItemComponents.add(comp);

        // إضافتهم إلى اللوحة مباشرة لكي يتحركوا ويلتفوا معها
        ludoGame!.gameWrapper.add(comp);
      }
    });
  }

  LudoXEffectResult? getEffect(
    int playerIndex,
    int currentProgress,
    List<List<int>> allTokens,
  ) {
    if (currentProgress <= 0 || currentProgress > 51) return null;

    int startOffset = [0, 13, 26, 39][playerIndex];
    int globalIdx = (currentProgress - 1 + startOffset) % 52;

    MagicTileType? tileType = magicTiles[globalIdx];
    if (tileType == null || tileType == MagicTileType.normal) return null;

    LudoXEffectResult? result;

    switch (tileType) {
      case MagicTileType.rocket:
        result = _handleRocket(currentProgress);
        break;
      case MagicTileType.dice:
        result = LudoXEffectResult(
          newProgress: currentProgress,
          message: 'التقطت النرد السحري! 🎲 الرمية القادمة مضمونة 6!',
          type: MagicTileType.dice,
        );
        break;
      default:
        return null;
    }

    // نقل الأداة عشوائياً بعد الاستخدام
    _relocateTile(globalIdx);
    return result;
  }

  void _relocateTile(int oldGlobalIdx) {
    MagicTileType? type = magicTiles.remove(oldGlobalIdx);
    if (type == null) return;

    List<int> availableIndices = List.generate(52, (index) => index);
    availableIndices.removeWhere(
      (i) => [0, 8, 13, 21, 26, 34, 39, 47].contains(i),
    );
    availableIndices.removeWhere((i) => magicTiles.containsKey(i));

    if (availableIndices.isNotEmpty) {
      availableIndices.shuffle();
      magicTiles[availableIndices.first] = type;
    }
    _syncMagicItemComponents();
  }

  LudoXEffectResult _handleRocket(int currentProgress) {
    int steps = _random.nextInt(8) + 1; // 1 to 8 steps
    int newProgress = (currentProgress + steps).clamp(1, 51);
    return LudoXEffectResult(
      newProgress: newProgress,
      message: 'انطلقت بالصاروخ! 🚀 طرت للأمام $steps خطوات!',
      type: MagicTileType.rocket,
    );
  }
}

// ==========================================
// 3. المكونات البصرية والحركية (Flame Components)
// ==========================================
class TokenComponent extends SpriteComponent {
  final String playerId;

  TokenComponent({required this.playerId, Vector2? position, Vector2? size})
    : super(position: position, size: size);

  void applyRocketEffect(Vector2 newTargetPosition) {
    add(
      MoveToEffect(
        newTargetPosition,
        EffectController(duration: 0.6, curve: Curves.easeInOut),
      ),
    );
  }
}

class MagicItemComponent extends PositionComponent
    with TapCallbacks, HasGameRef<LudoGame> {
  final MagicTileType itemType;

  MagicItemComponent({required this.itemType, Vector2? position, Vector2? size})
    : super(position: position, size: size) {
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    priority = 5; // 🌟 لجعلها تظهر فوق اللوحة
    String emoji;
    switch (itemType) {
      case MagicTileType.dice:
        emoji = '🎲';
        break;
      case MagicTileType.rocket:
        emoji = '🚀';
        break;
      default:
        emoji = '❓';
    }

    add(
      TextComponent(
        text: emoji,
        textRenderer: TextPaint(style: TextStyle(fontSize: size.x * 0.75)),
        anchor: Anchor.center,
        position: size / 2, // توصيط الإيموجي في المربع
      ),
    );
  }

  // 🌟 إبقاء الأداة السحرية مستقيمة حتى لو دارت اللوحة
  @override
  void update(double dt) {
    super.update(dt);
    angle = -gameRef.gameWrapper.angle; // Always upright
  }

  // 🌟 عند الضغط على الأداة في الشاشة
  @override
  void onTapDown(TapDownEvent event) {
    print('تم التقاط: ${itemType.name}');
    removeFromParent(); // إخفاء الأداة لتبدو وكأن اللاعب التقطها
  }
}

// --- Network Logic ---==========================================
// 4. مدير التزامن والشبكة (Firebase Network Manager)
// ==========================================
class LudoNetworkManager {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final String roomId;
  final String myPlayerId; // This should be the player Index (0-3) as string
  final LudoGame gameRef;
  LudoNetworkManager({
    required this.roomId,
    required this.myPlayerId,
    required this.gameRef,
  }) {
    _listenToMagicEffects();
  }

  void _listenToMagicEffects() {
    // Correct path to match LudoService
    _db.child('ludo_rooms/$roomId/state/active_effect').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      debugPrint('[LudoNetworkManager] Effect Update: $data (Me: $myPlayerId)');
      if (data != null) {
        final targetPlayer = data['target_player']?.toString();
        final sender = data['sender']?.toString();

        bool amIAffected = false;
        if (targetPlayer == 'all' && sender != myPlayerId) {
          amIAffected = true;
        } else if (targetPlayer == myPlayerId) {
          amIAffected = true;
        }

        if (amIAffected) {
          debugPrint('[LudoNetworkManager] 💡 إطفاء النور عليّ!');
          gameRef.onMagicEffect?.call('blackout', true);
        } else {
          debugPrint('[LudoNetworkManager] 💡 عاد النور!');
          gameRef.onMagicEffect?.call('blackout', false);
        }
      } else {
        debugPrint('[LudoNetworkManager] 💡 التأثير انتهى، عاد النور!');
        gameRef.onMagicEffect?.call('blackout', false);
      }
    });
  }

  Future<void> attackWithLamp() async {
    debugPrint(
      '[LudoNetworkManager] 💡 تفعيل المصباح العجيب! الهجوم على الجميع!',
    );
    // Attack all opponents
    await _db.child('ludo_rooms/$roomId/state/active_effect').set({
      'type': 'blackout',
      'target_player': 'all',
      'sender': myPlayerId,
      'timestamp': ServerValue.timestamp,
    });

    // Auto-remove after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      clearEffect();
    });
  }

  Future<void> clearEffect() async {
    await _db.child('ludo_rooms/$roomId/state/active_effect').remove();
  }
}
