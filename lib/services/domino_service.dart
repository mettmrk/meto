import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class DominoService {
  static final DominoService _instance = DominoService._internal();
  factory DominoService() => _instance;
  DominoService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DatabaseReference get _roomsRef => _db.ref('domino_rooms');

  Future<String> joinOrCreateRoom({
    String? roomId,
    int betAmount = 500,
    String gameMode = 'points', // 'points' or 'multiplier'
    int playerCount = 2,
    String? name,
    String? photo,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    String targetRoomId;
    if (roomId != null && roomId.isNotEmpty) {
      targetRoomId = roomId;
    } else {
      // Use a Matchmaking Pool Registry for guaranteed connection
      // We store it nested inside domino_rooms area to inherit permissions if possible,
      // but 'domino_rooms_matchmaking' is a better sibling.
      final tag = 'pool_${betAmount}_${gameMode}_$playerCount';
      final poolRef = _db.ref('domino_rooms/matchmaking_pool_registry/$tag');
      
      final poolSnap = await poolRef.get();
      String? candidateId = poolSnap.value as String?;

      if (candidateId != null) {
        // Verify room is still valid and waiting
        final roomSnap = await _roomsRef.child(candidateId).child('status').get();
        if (roomSnap.exists && roomSnap.value == 'waiting') {
          targetRoomId = candidateId;
        } else {
          // Room is gone or playing, clear pool
          await poolRef.remove();
          targetRoomId = _roomsRef.push().key!;
        }
      } else {
        targetRoomId = _roomsRef.push().key!;
      }
    }

    final roomRef = _roomsRef.child(targetRoomId);

    final transactionResult = await roomRef.runTransaction((Object? room) {
      Map<String, dynamic> roomMap = (room as Map?)?.cast<String, dynamic>() ??
          {
            'status': 'waiting',
            'betAmount': betAmount,
            'gameMode': gameMode,
            'playerCount': playerCount,
            'status_bet_count': 'waiting_${betAmount}_${gameMode}_$playerCount',
            'players': {},
            'state': _getInitialState(betAmount, gameMode, playerCount),
            'createdAt': ServerValue.timestamp,
          };

      Map<String, dynamic> players = Map.from(roomMap['players'] ?? {});

      if (players.containsKey(user.uid)) {
        return Transaction.success(roomMap);
      }

      int maxPlayers = roomMap['playerCount'] ?? 2;
      if (players.length >= maxPlayers) {
        return Transaction.abort();
      }

      // Find first available index (0..maxPlayers-1)
      int playerIndex = -1;
      List<int> usedIndices = players.values.map((p) => ((p as Map)['index'] as num?)?.toInt() ?? 0).toList();
      for (int i = 0; i < maxPlayers; i++) {
        if (!usedIndices.contains(i)) {
          playerIndex = i;
          break;
        }
      }
      if (playerIndex == -1) playerIndex = players.length; 

      if (players.isEmpty) {
        roomMap['state']['hostId'] = user.uid;
      }

      players[user.uid] = {
        'uid': user.uid,
        'name': name ?? user.displayName ?? 'Player',
        'photo': photo ?? user.photoURL,
        'index': playerIndex,
        'online': true,
        'joinedAt': ServerValue.timestamp,
      };

      roomMap['players'] = players;
      if (players.length >= maxPlayers) {
        roomMap['status'] = 'playing';
        roomMap['status_bet_count'] = 'playing_${betAmount}_${gameMode}_$maxPlayers';
      }

      return Transaction.success(roomMap);
    });

    if (transactionResult.committed) {
      _roomsRef.child(targetRoomId).child('players/${user.uid}').onDisconnect().update({
        'online': false,
        'offlineAt': ServerValue.timestamp,
      });
      
      // If I am the first player, announce room in pool
      final tag = 'pool_${betAmount}_${gameMode}_$playerCount';
      final poolRef = _db.ref('domino_rooms/matchmaking_pool_registry/$tag');
      
      final DataSnapshot roomSnapAfter = transactionResult.snapshot;
      final roomData = (roomSnapAfter.value as Map?)?.cast<String, dynamic>();
      final playersCountNow = (roomData?['players'] as Map?)?.length ?? 0;
      final maxPlayers = (roomData?['playerCount'] as num?)?.toInt() ?? 2;

      if (playersCountNow == 1) {
        await poolRef.set(targetRoomId);
      } else if (playersCountNow >= maxPlayers) {
        // Room full, clear pool for next searchers
        await poolRef.remove();
      }
    }

    if (!transactionResult.committed) {
      throw Exception('Failed to join room. Room might be full.');
    }

    return targetRoomId;
  }

  Map<String, dynamic> _getInitialState(int betAmount, String mode, int playerCount) {
    return {
      'board': [],
      'boneyard': [],
      'playerHands': List.generate(playerCount, (_) => []),
      'playerScores': List.generate(playerCount, (_) => 0),
      'currentPlayerIndex': 0,
      'isGameOver': false,
      'lastUpdate': ServerValue.timestamp,
      'ends': {'left': null, 'right': null, 'up': null, 'down': null},
      'lastRoundStatus': {
        'winnerIndex': null,
        'roundPoints': 0,
        'isRoundOver': false,
        'isGameFinished': false,
      },
    };
  }

  Stream<DatabaseEvent> streamRoom(String roomId) {
    return _roomsRef.child(roomId).onValue;
  }

  Future<void> updateGameState(String roomId, Map<String, dynamic> updates) async {
    updates['state/lastUpdate'] = ServerValue.timestamp;
    await _roomsRef.child(roomId).update(updates);
  }

  Future<void> leaveRoom(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _roomsRef.child('$roomId/players/${user.uid}').update({
      'online': false,
      'left': true,
    });
  }

  Future<void> deleteRoom(String roomId) async {
    await _roomsRef.child(roomId).remove();
  }

  Future<void> removeFromPool(int betAmount, String gameMode, int playerCount) async {
    final tag = 'pool_${betAmount}_${gameMode}_$playerCount';
    final poolRef = _db.ref('domino_rooms/matchmaking_pool_registry/$tag');
    await poolRef.remove();
  }
  Future<void> sendInteraction(
    String roomId,
    String type,
    String content,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _roomsRef.child('$roomId/interactions').push().set({
      'senderId': user.uid,
      'type': type,
      'content': content,
      'timestamp': ServerValue.timestamp,
    });
  }
}
