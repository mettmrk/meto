import 'package:json_annotation/json_annotation.dart';

part 'jackaroo_model.g.dart';

enum JackarooCard {
  ace(1),
  two(2),
  three(3),
  four(4),
  five(5),
  six(6),
  seven(7),
  eight(8),
  nine(9),
  ten(10),
  jack(11),
  queen(12),
  king(13);

  final int value;
  const JackarooCard(this.value);
}

class JackarooMove {
  final int playerIndex;
  final List<int> marbleIndices; // Usually 1, but 2 for Card 7
  final List<int> steps; // Steps per marble
  final int? targetMarbleIndex; // For Jack (Swap)
  final int? targetPlayerIndex; // For Jack (Swap)
  final bool isExitBase;

  JackarooMove({
    required this.playerIndex,
    required this.marbleIndices,
    required this.steps,
    this.targetMarbleIndex,
    this.targetPlayerIndex,
    this.isExitBase = false,
  });
}

enum JackarooMarbleStatus {
  @JsonValue('base')
  base, // Still in the starting area (Parking)
  @JsonValue('track')
  track, // On the main 52-hole circular track
  @JsonValue('safe')
  safe, // In the 4-hole safe/finish zone
}

@JsonSerializable()
class JackarooMarble {
  final int playerIndex; // 0 to 3
  final int marbleIndex; // 0 to 3
  JackarooMarbleStatus status;
  int position; // Index on track (0-51) or safe zone (0-3)

  JackarooMarble({
    required this.playerIndex,
    required this.marbleIndex,
    this.status = JackarooMarbleStatus.base,
    this.position = -1,
  });

  factory JackarooMarble.fromJson(Map<String, dynamic> json) =>
      _$JackarooMarbleFromJson(json);
  Map<String, dynamic> toJson() => _$JackarooMarbleToJson(this);
}

@JsonSerializable()
class JackarooGameState {
  final String roomId;
  final List<int> playerIndices; // List of active player indices (0, 1, 2, 3)
  int currentPlayerIndex;
  
  // The 52 circular holes on the board
  // Value is marble UID (e.g., "p0_m1") or null if empty
  final Map<int, String?> mainTrack;

  // The 4 safe holes for each player (0-3)
  // Key is player index, value is list of 4 holes
  final Map<int, List<String?>> safeZones;

  // All marbles in the game
  final List<JackarooMarble> marbles;

  JackarooGameState({
    required this.roomId,
    required this.playerIndices,
    this.currentPlayerIndex = 0,
    required this.mainTrack,
    required this.safeZones,
    required this.marbles,
  });

  factory JackarooGameState.initial(String roomId) {
    // Initialize 76 main track holes (19 per arm × 4 arms)
    final track = <int, String?>{};
    for (int i = 0; i < 76; i++) {
      track[i] = null;
    }

    // Initialize 4 safe zones (4 holes each)
    final zones = <int, List<String?>>{};
    for (int p = 0; p < 4; p++) {
      zones[p] = List.filled(4, null);
    }

    // Initialize 16 marbles (4 per player)
    final allMarbles = <JackarooMarble>[];
    for (int p = 0; p < 4; p++) {
      for (int m = 0; m < 4; m++) {
        allMarbles.add(JackarooMarble(playerIndex: p, marbleIndex: m));
      }
    }

    return JackarooGameState(
      roomId: roomId,
      playerIndices: [0, 1, 2, 3],
      mainTrack: track,
      safeZones: zones,
      marbles: allMarbles,
    );
  }

  factory JackarooGameState.fromJson(Map<String, dynamic> json) =>
      _$JackarooGameStateFromJson(json);
  Map<String, dynamic> toJson() => _$JackarooGameStateToJson(this);

  /// Identify moves based on drawn card
  List<JackarooMove> getAvailableMoves(int playerIdx, JackarooCard card) {
    final moves = <JackarooMove>[];
    final playerMarbles = marbles.where((m) => m.playerIndex == playerIdx).toList();

    for (var mIdx = 0; mIdx < playerMarbles.length; mIdx++) {
      final marble = playerMarbles[mIdx];

      // Rule: Exit Base (Ace or King)
      if (marble.status == JackarooMarbleStatus.base) {
        if (card == JackarooCard.ace || card == JackarooCard.king) {
          moves.add(JackarooMove(
            playerIndex: playerIdx,
            marbleIndices: [mIdx],
            steps: [0],
            isExitBase: true,
          ));
        }
        continue;
      }

      // Rule: Card 4 (Move 4 steps backwards)
      if (card == JackarooCard.four) {
        if (marble.status == JackarooMarbleStatus.track) {
          moves.add(JackarooMove(
            playerIndex: playerIdx,
            marbleIndices: [mIdx],
            steps: [-4],
          ));
        }
      } 
      // Rule: Card 7 (Split Movement)
      else if (card == JackarooCard.seven) {
        if (marble.status != JackarooMarbleStatus.base) {
          moves.add(JackarooMove(
            playerIndex: playerIdx,
            marbleIndices: [mIdx],
            steps: [7], 
          ));
        }
      }
      // Rule: Jack (Swap positions)
      else if (card == JackarooCard.jack) {
        if (marble.status == JackarooMarbleStatus.track) {
          for (var otherMarble in marbles) {
            if (otherMarble != marble && otherMarble.status == JackarooMarbleStatus.track) {
              moves.add(JackarooMove(
                playerIndex: playerIdx,
                marbleIndices: [mIdx],
                steps: [0],
                targetPlayerIndex: otherMarble.playerIndex,
                targetMarbleIndex: otherMarble.marbleIndex,
              ));
            }
          }
        }
      }
      // Standard Cards (Move Forward)
      else {
        if (marble.status != JackarooMarbleStatus.base) {
          moves.add(JackarooMove(
            playerIndex: playerIdx,
            marbleIndices: [mIdx],
            steps: [card.value],
          ));
        }
      }
    }
    return moves;
  }

  /// Apply Move and Collision System
  void applyMove(JackarooMove move) {
    for (int i = 0; i < move.marbleIndices.length; i++) {
      final mIdx = move.marbleIndices[i];
      final marble = marbles.firstWhere(
        (m) => m.playerIndex == move.playerIndex && m.marbleIndex == mIdx,
      );
      final steps = move.steps[i];

      int oldPos = marble.position;
      int newPos = -1;

      // 1. Handle Base Exit
      if (move.isExitBase) {
        // 0, 13, 26, 39 — 52 ÷ 4 = 13
        newPos = move.playerIndex * 13;
        marble.status = JackarooMarbleStatus.track;
      } 
      // 2. Handle Jack Swap
      else if (move.targetPlayerIndex != null) {
        final otherMarble = marbles.firstWhere(
          (m) => m.playerIndex == move.targetPlayerIndex && 
                 m.marbleIndex == move.targetMarbleIndex,
        );
        newPos = otherMarble.position;
        
        // Update other marble to my old position
        otherMarble.position = oldPos;
        mainTrack[oldPos] = "p${otherMarble.playerIndex}_m${otherMarble.marbleIndex}";
      }
      // 3. Standard Move (including backwards for Card 4)
      else {
        newPos = (oldPos + steps + 52) % 52;
      }

      // COLLISION SYSTEM: Check if someone is already there
      if (mainTrack[newPos] != null && move.targetPlayerIndex == null) {
        final collisionUid = mainTrack[newPos]!;
        for (var m in marbles) {
          if ("p${m.playerIndex}_m${m.marbleIndex}" == collisionUid) {
            m.status = JackarooMarbleStatus.base;
            m.position = -1;
            break;
          }
        }
      }

      // Update Track Map & Marble Position
      if (oldPos != -1 && move.targetPlayerIndex == null) {
        mainTrack[oldPos] = null;
      }
      
      marble.position = newPos;
      mainTrack[newPos] = "p${marble.playerIndex}_m${marble.marbleIndex}";
    }
    currentPlayerIndex = (currentPlayerIndex + 1) % playerIndices.length;
  }
}
