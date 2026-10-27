import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';

class BackgammonService {
  static final BackgammonService _instance = BackgammonService._internal();
  factory BackgammonService() => _instance;
  BackgammonService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DatabaseReference get _roomsRef => _db.ref('ludo_rooms');

  // Create or Join Room
  Future<String> joinOrCreateRoom({String? roomId, int betAmount = 50}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    String targetRoomId;

    if (roomId != null && roomId.isNotEmpty) {
      targetRoomId = roomId;
    } else {
      // Find a waiting room with the same bet amount
      final snapshot = await _roomsRef
          .orderByChild('status_bet')
          .equalTo('bg_waiting_$betAmount')
          .limitToFirst(1)
          .get();
      if (snapshot.exists && snapshot.children.isNotEmpty) {
        targetRoomId = snapshot.children.first.key!;
      } else {
        targetRoomId = _roomsRef.push().key!;
      }
    }

    final roomRef = _roomsRef.child(targetRoomId);

    final transactionResult = await roomRef.runTransaction((Object? room) {
      Map<String, dynamic> roomMap =
          (room as Map?)?.cast<String, dynamic>() ??
          {
            'status': 'waiting',
            'betAmount': betAmount,
            'status_bet': 'bg_waiting_$betAmount',
            'players': {},
            'state': _getInitialState(),
            'createdAt': ServerValue.timestamp,
          };

      Map<String, dynamic> players = Map.from(roomMap['players'] ?? {});

      if (players.containsKey(user.uid)) {
        return Transaction.success(roomMap);
      }

      if (players.length >= 2) {
        return Transaction.abort();
      }

      int playerIndex;
      // 1 for White, 2 for Black
      if (players.isEmpty) {
        playerIndex = Random().nextBool() ? 1 : 2;
      } else {
        int firstIdx = (players.values.first as Map)['index'] as int;
        playerIndex = firstIdx == 1 ? 2 : 1;
      }

      players[user.uid] = {
        'uid': user.uid,
        'name': user.displayName ?? 'Player ${players.length + 1}',
        'photo': user.photoURL,
        'index': playerIndex,
        'joinedAt': ServerValue.timestamp,
        'online': true,
      };

      roomMap['players'] = players;
      if (players.length >= 2) {
        roomMap['status'] = 'playing';
        roomMap['status_bet'] = 'bg_playing_$betAmount';
        if (roomMap['state']['hostId'] == null) {
          roomMap['state']['hostId'] = user.uid;
        }
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
            .child('online')
            .onDisconnect()
            .set(false);
      }
    }

    return targetRoomId;
  }

  Map<String, dynamic> _getInitialState() {
    return {
      'board': List.filled(24, 0),
      'whiteBar': 0,
      'blackBar': 0,
      'whiteOff': 0,
      'blackOff': 0,
      'currentPlayer': 1,
      'dice': [0, 0],
      'isGameOver': false,
      'winner': null,
      'lastUpdate': ServerValue.timestamp,
      'readyToInitialize': true, // To tell clients to set up 2-5-3-5
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

  Future<void> syncBoardState(
    String roomId, {
    required List<int> board,
    required int whiteBar,
    required int blackBar,
    required int whiteOff,
    required int blackOff,
    required int currentPlayer,
    required List<int> dice,
    required List<int> availableMoves,
  }) async {
    await _roomsRef.child('$roomId/state').update({
      'board': board,
      'whiteBar': whiteBar,
      'blackBar': blackBar,
      'whiteOff': whiteOff,
      'blackOff': blackOff,
      'currentPlayer': currentPlayer,
      'dice': dice,
      'availableMoves': availableMoves,
      'lastUpdate': ServerValue.timestamp,
    });
  }

  Future<void> performMove(
    String roomId, {
    required List<int> board,
    required int whiteBar,
    required int blackBar,
    required int whiteOff,
    required int blackOff,
    required List<int> availableMoves,
    required Map<String, dynamic> additionalUpdates,
  }) async {
    final updates = {
      'state/board': board,
      'state/whiteBar': whiteBar,
      'state/blackBar': blackBar,
      'state/whiteOff': whiteOff,
      'state/blackOff': blackOff,
      'state/availableMoves': availableMoves,
      'state/lastUpdate': ServerValue.timestamp,
      ...additionalUpdates,
    };
    await _roomsRef.child(roomId).update(updates);
  }

  Future<void> switchTurn(String roomId, {required int nextPlayer}) async {
    await _roomsRef.child('$roomId/state').update({
      'currentPlayer': nextPlayer,
      'dice': [0, 0],
      'availableMoves': [],
      'lastUpdate': ServerValue.timestamp,
    });
  }

  Future<void> declareWinner(String roomId, int winnerIndex) async {
    await _roomsRef.child(roomId).update({
      'status': 'finished',
      'state/isGameOver': true,
      'state/winner': winnerIndex,
      'state/lastUpdate': ServerValue.timestamp,
    });
  }

  Future<void> leaveRoom(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _roomsRef.child('$roomId/players/${user.uid}').remove();
  }
}
