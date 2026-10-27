import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';
import 'notification_service.dart';
import '../models/notification_model.dart';

class LudoService {
  static final LudoService _instance = LudoService._internal();
  factory LudoService() => _instance;
  LudoService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DatabaseReference get _roomsRef => _db.ref('ludo_rooms');

  // Create or Join Room
  Future<String> joinOrCreateRoom({
    String? roomId,
    int betAmount = 50,
    int maxPlayers = 4,
    String mode = 'classic',
    String? name,
    String? photo,
    bool forceNewRoom = false,
    bool isTeamMode = false,
    bool magicToolsEnabled = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    print('[LudoService] Joining or creating room... Bet: $betAmount');
    String targetRoomId;

    if (roomId != null && roomId.isNotEmpty) {
      targetRoomId = roomId;
    } else if (forceNewRoom) {
      targetRoomId = _roomsRef.push().key!;
      print('[LudoService] Forced creation of new room: $targetRoomId');
    } else {
      // Find a waiting room with the same bet amount, players, and mode
      final statusBetQuery = magicToolsEnabled
          ? 'waiting_${betAmount}_${maxPlayers}_${mode}_magic'
          : 'waiting_${betAmount}_${maxPlayers}_$mode';
          
      final snapshot = await _roomsRef
          .orderByChild('status_bet')
          .equalTo(statusBetQuery)
          .limitToFirst(1)
          .get();
      if (snapshot.exists && snapshot.children.isNotEmpty) {
        targetRoomId = snapshot.children.first.key!;
        print('[LudoService] Found existing room: $targetRoomId');
      } else {
        targetRoomId = _roomsRef.push().key!;
        print(
          '[LudoService] No waiting room found. Creating new: $targetRoomId',
        );
      }
    }

    final roomRef = _roomsRef.child(targetRoomId);

    final transactionResult = await roomRef.runTransaction((Object? room) {
      Map<String, dynamic> roomMap =
          (room as Map?)?.cast<String, dynamic>() ??
          {
            'status': 'waiting',
            'betAmount': betAmount,
            'maxPlayers': maxPlayers,
            'mode': mode,
            'isTeamMode': isTeamMode,
            'shortCode': targetRoomId
                .substring(max(0, targetRoomId.length - 6))
                .toUpperCase(),
            'status_bet': (forceNewRoom || isTeamMode)
                ? 'private_${betAmount}_${maxPlayers}_$mode' + (magicToolsEnabled ? '_magic' : '')
                : 'waiting_${betAmount}_${maxPlayers}_$mode' + (magicToolsEnabled ? '_magic' : ''),
            'players': {},
            'state': _getInitialState(betAmount, mode, magicToolsEnabled),
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
        // Host always starts as Red (index 0)
        playerIndex = 0;
        // Set hostId for the very first player who creates the room
        roomMap['state']['hostId'] = user.uid;
      } else {
        if (isTeamMode) {
          // Team Mode: Standard diagonal partners (Red 0 & Yellow 2)
          if (!usedIndices.contains(2)) {
            playerIndex = 2;
          } else if (!usedIndices.contains(1)) {
            playerIndex = 1;
          } else {
            playerIndex = 3;
          }
        } else if (maxPlayers == 2) {
          // In 2 player room, host is 0, guest must be 2 (Yellow)
          playerIndex = 2;
        } else {
          // 4-player room: Host is 0 (Red).
          if (!usedIndices.contains(2)) {
            playerIndex = 2;
          } else if (!usedIndices.contains(1)) {
            playerIndex = 1;
          } else {
            playerIndex = 3;
          }
        }
      }

      players[user.uid] = {
        'uid': user.uid,
        'name': name ?? user.displayName ?? 'Player ${players.length + 1}',
        'photo': photo ?? user.photoURL,
        'index': playerIndex,
        'joinedAt': ServerValue.timestamp,
        'online': true, // Presence flag
      };

      roomMap['players'] = players;
      if (players.length >= maxPlayers) {
        // Double check: if it's 4-player mode, we strictly need 4 players
        if (maxPlayers == 4 && players.length < 4) {
          // Should theoretically not happen given the condition above, but for safety
        } else {
          roomMap['status'] = 'playing';
          roomMap['status_bet'] = 'playing_${betAmount}_${maxPlayers}_$mode';
          // Ensure hostId is set (backup)
          if (roomMap['state']['hostId'] == null) {
            roomMap['state']['hostId'] = user.uid;
          }
        }
      }

      return Transaction.success(roomMap);
    });

    // Set up presence onDisconnect
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
    }

    print(
      '[LudoService] Transaction completed. Committed: ${transactionResult.committed}',
    );
    if (!transactionResult.committed) {
      throw Exception(
        'عذراً، فشل الانضمام لهذه الطاولة. قد تكون ممتلئة باللاعبين.',
      );
    }

    return targetRoomId;
  }

  // Find Room by Short Code
  Future<String?> findRoomByShortCode(String shortCode) async {
    final snapshot = await _roomsRef
        .orderByChild('shortCode')
        .equalTo(shortCode.toUpperCase())
        .limitToFirst(1)
        .get();

    if (snapshot.exists && snapshot.children.isNotEmpty) {
      return snapshot.children.first.key;
    }
    return null;
  }

  Map<String, dynamic> _getInitialState(
    int betAmount, [
    String mode = 'classic',
    bool magicToolsEnabled = false,
  ]) {
    final state = {
      'tokens': [
        [0, 0, 0, 0], // Player 0
        [0, 0, 0, 0], // Player 1
        [0, 0, 0, 0], // Player 2
        [0, 0, 0, 0], // Player 3
      ],
      'diceRolled': [],
      'currentPlayerIndex': 0,
      'isRolling': false,
      'canRoll': true,
      'winners': [], // Track player indices in order of winning
      'betAmount': betAmount,
      'lastUpdate': ServerValue.timestamp,
    };

    if (magicToolsEnabled) {
      state['magicSeed'] = Random().nextInt(1000000);
    }

    return state;
  }

  // Stream Room Updates
  Stream<DatabaseEvent> streamRoom(String roomId) {
    return _roomsRef.child(roomId).onValue;
  }

  // Update Game State
  Future<void> updateGameState(
    String roomId,
    Map<String, dynamic> updates,
  ) async {
    updates['state/lastUpdate'] = ServerValue.timestamp;
    await _roomsRef.child(roomId).update(updates);
  }

  // Send Interaction (Chat/Stickers)
  Future<void> sendInteraction(
    String roomId,
    String type,
    String content,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _roomsRef.child('$roomId/interactions/${user.uid}').set({
      'type': type,
      'content': content,
      'timestamp': ServerValue.timestamp,
    });
  }

  // Update Player Preference (Shape/Theme)
  Future<void> updatePlayerPreference(
    String roomId, {
    String? tokenShape,
    String? boardTheme,
    String? tokenTheme,
    String? diceTheme,
    String? hallTheme,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    Map<String, dynamic> updates = {};
    if (tokenShape != null) updates['tokenShape'] = tokenShape;
    if (boardTheme != null) updates['boardTheme'] = boardTheme;
    if (tokenTheme != null) updates['tokenTheme'] = tokenTheme;
    if (diceTheme != null) updates['diceTheme'] = diceTheme;
    if (hallTheme != null) updates['hallTheme'] = hallTheme;

    if (updates.isNotEmpty) {
      await _roomsRef.child('$roomId/players/${user.uid}').update(updates);
    }
  }

  // Toggle Auto Play State
  Future<void> toggleAutoPlay(String roomId, bool isAuto) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _roomsRef.child('$roomId/players/${user.uid}/isAuto').set(isAuto);
  }

  // Delete Room
  Future<void> deleteRoom(String roomId) async {
    await _roomsRef.child(roomId).remove();
  }

  // Leave Room — marks the player as left instead of removing them,
  // so their avatar and tokens remain visible during the game.
  Future<void> leaveRoom(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final roomRef = _roomsRef.child(roomId);
    final snapshot = await roomRef.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final gameState = data['state'] as Map?;
      final status = data['status'] as String?;
      final hostId = (gameState != null)
          ? gameState['hostId'] as String?
          : null;

      // If the game hasn't started yet, close the room (host left lobby)
      if (status == 'waiting' && hostId == user.uid) {
        await roomRef.update({'status': 'closed'});
        await roomRef.child('players/${user.uid}').remove();
        return;
      }
    }

    // During active game: mark as left, keep data visible
    await roomRef.child('players/${user.uid}').update({
      'online': false,
      'left': true,
    });
  }

  /// Registers a bot as a fake player in Firebase so all clients see it
  /// and the master client can drive its moves via isAuto=true.
  Future<void> addBotPlayer({
    required String roomId,
    required String botUid, // e.g. 'bot_2_38472'
    required int index,
    required String name,
    String? photo,
  }) async {
    await _roomsRef.child('$roomId/players/$botUid').set({
      'uid': botUid,
      'name': name,
      'photo': photo,
      'index': index,
      'isAuto': true, // master will auto-play for this player
      'isBot': true, // flag so UI can recognise bots
      'online': true, // Bots are always "online"
      'joinedAt': ServerValue.timestamp,
    });
  }

  Future<void> sendInvite(String receiverId, String roomId, int betAmount) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await NotificationService().sendNotification(
      NotificationModel(
        id: '',
        receiverId: receiverId,
        senderId: user.uid,
        senderName: user.displayName ?? 'لاعب لودو',
        senderProfileImage: user.photoURL,
        type: NotificationType.ludoInvite,
        roomId: roomId,
        text: 'يدعوك للانضمام إلى طاولة لودو خاصة (رهان $betAmount)',
        createdAt: DateTime.now(),
      ),
    );
  }
}
