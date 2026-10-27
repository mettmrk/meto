import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

class ShutTheBoxService {
  static final ShutTheBoxService _instance = ShutTheBoxService._internal();
  factory ShutTheBoxService() => _instance;
  ShutTheBoxService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DatabaseReference get _roomsRef => _db.ref('ludo_rooms');

  // Create or Join Room
  Future<String> joinOrCreateRoom({
    int betAmount = 50,
    int maxPlayers = 2,
    String? name,
    String? photo,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    if (betAmount > 0) {
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      bool canJoin = false;
      await FirebaseFirestore.instance
          .runTransaction((tx) async {
            final snapshot = await tx.get(userDocRef);
            if (!snapshot.exists) throw Exception("User not found");

            int metoChips = snapshot.data()?['meto_chips'] ?? 0;
            if (metoChips < betAmount) {
              throw Exception("insufficient_funds");
            }

            tx.update(userDocRef, {
              'meto_chips': FieldValue.increment(-betAmount),
            });
            canJoin = true;
          })
          .catchError((e) {
            throw Exception("insufficient_funds");
          });

      if (!canJoin) {
        throw Exception("insufficient_funds");
      }
    }

    String targetRoomId;

    // Find a waiting room with the same bet amount and max players
    final statusBetQuery = 'shutthebox_waiting_${betAmount}_$maxPlayers';

    final snapshot = await _roomsRef
        .orderByChild('status_bet')
        .equalTo(statusBetQuery)
        .limitToFirst(1)
        .get();

    if (snapshot.exists && snapshot.children.isNotEmpty) {
      targetRoomId = snapshot.children.first.key!;
    } else {
      targetRoomId = _roomsRef.push().key!;
    }

    final roomRef = _roomsRef.child(targetRoomId);

    final transactionResult = await roomRef.runTransaction((Object? room) {
      Map<String, dynamic> roomMap =
          (room as Map?)?.cast<String, dynamic>() ??
          {
            'status': 'waiting',
            'betAmount': betAmount,
            'maxPlayers': maxPlayers,
            'status_bet': 'shutthebox_waiting_${betAmount}_$maxPlayers',
            'players': {},
            'state': _getInitialState(),
            'createdAt': ServerValue.timestamp,
          };

      Map<String, dynamic> players = Map.from(roomMap['players'] ?? {});

      if (players.containsKey(user.uid)) {
        return Transaction.success(roomMap);
      }

      if (players.length >= maxPlayers) {
        return Transaction.abort();
      }

      int playerIndex;
      List<int> usedIndices = players.values
          .map((p) => ((p as Map)['index'] as num?)?.toInt() ?? 0)
          .toList();

      if (players.isEmpty) {
        // First player is Blue (index 0)
        playerIndex = 0;
      } else {
        if (maxPlayers == 2) {
          // Second player is Red (index 2)
          playerIndex = 2;
        } else {
          // 4 Players: 0, 1, 2, 3
          if (!usedIndices.contains(1)) {
            playerIndex = 1; // Green
          } else if (!usedIndices.contains(2)) {
            playerIndex = 2; // Red
          } else {
            playerIndex = 3; // Yellow
          }
        }
      }

      players[user.uid] = {
        'uid': user.uid,
        'name': name ?? user.displayName ?? 'Player ${players.length + 1}',
        'photo': photo ?? user.photoURL,
        'index': playerIndex,
        'joinedAt': ServerValue.timestamp,
        'online': true,
      };

      roomMap['players'] = players;

      if (players.length >= maxPlayers) {
        roomMap['status'] = 'playing';
        roomMap['status_bet'] = 'shutthebox_playing_${betAmount}_$maxPlayers';
      }

      return Transaction.success(roomMap);
    });

    if (transactionResult.committed) {
      final user = _auth.currentUser;
      if (user != null) {
        _roomsRef
            .child(targetRoomId)
            .child('players')
            .child(user.uid)
            .onDisconnect()
            .remove();
      }
    } else {
      if (betAmount > 0) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'meto_chips': FieldValue.increment(betAmount)});
      }
      throw Exception(
        'عذراً، فشل الانضمام لهذه الطاولة. قد تكون ممتلئة باللاعبين.',
      );
    }

    return targetRoomId;
  }

  Map<String, dynamic> _getInitialState() {
    return {
      'tiles': {
        '0': List.generate(10, (_) => false), // Player 0
        '1': List.generate(10, (_) => false), // Player 1
        '2': List.generate(10, (_) => false), // Player 2
        '3': List.generate(10, (_) => false), // Player 3
      },
      'dice1': 1,
      'dice2': 1,
      'diceRolled': false,
      'currentPlayerIndex': 0,
      'winnerIndex': -1,
      'lastUpdate': ServerValue.timestamp,
    };
  }

  Stream<DatabaseEvent> streamRoom(String roomId) {
    return _roomsRef.child(roomId).onValue;
  }

  Future<void> updateGameState(
    String roomId,
    Map<String, dynamic> updates,
  ) async {
    updates['state/lastUpdate'] = ServerValue.timestamp;
    await _roomsRef.child(roomId).update(updates);
  }

  Future<void> leaveRoom(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final roomRef = _roomsRef.child(roomId);
    final snapshot = await roomRef.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final status = data['status'] as String?;
      final players = data['players'] as Map?;

      if (status == 'waiting') {
        // If waiting and host leaves, close the room.
        if (players != null && players.keys.first == user.uid) {
          await roomRef.update({
            'status': 'closed',
            'status_bet': 'shutthebox_closed',
          });
        }
        await roomRef.child('players/${user.uid}').remove();

        // Refund
        int bet = data['betAmount'] ?? 0;
        if (bet > 0 && players != null && players.containsKey(user.uid)) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'meto_chips': FieldValue.increment(bet)});
        }
        return;
      }
    }

    // During active game: mark as left
    await roomRef.child('players/${user.uid}').update({
      'online': false,
      'left': true,
    });
  }

  Future<void> deleteRoom(String roomId) async {
    await _roomsRef.child(roomId).remove();
  }

  Future<void> awardWinner(String roomId, int winnerIndex) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _roomsRef.child(roomId).get();
    if (!snapshot.exists) return;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final players = data['players'] as Map?;
    final betAmount = data['betAmount'] as int? ?? 0;
    final maxPlayers = data['maxPlayers'] as int? ?? 2;

    if (players != null && betAmount > 0) {
      // Find the winner uid
      String? winnerUid;
      for (var entry in players.entries) {
        final pData = entry.value as Map;
        if (pData['index'] == winnerIndex) {
          winnerUid = pData['uid'];
          break;
        }
      }

      if (winnerUid == user.uid) {
        // Award prize (90% to winner, 10% app fee)
        int prize = (betAmount * maxPlayers * 0.9).toInt();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'meto_chips': FieldValue.increment(prize)});
      }
    }
  }
}
