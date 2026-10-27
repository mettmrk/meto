import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_model.dart';
import 'dart:async';

class GameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _games => _firestore.collection('games');

  Future<String> findOrCreateGame({
    required String type,
    required String userId,
    required String userName,
  }) async {
    final waitingGames = await _games
        .where('status', isEqualTo: 'waiting')
        .where('type', isEqualTo: type)
        .limit(1)
        .get();

    if (waitingGames.docs.isNotEmpty) {
      final doc = waitingGames.docs.first;
      final game = GameModel.fromFirestore(doc);

      if (game.players.contains(userId)) {
        return game.id;
      }

      await _games.doc(doc.id).update({
        'players': FieldValue.arrayUnion([userId]),
        'playerNames.$userId': userName,
        'status': 'active',
        'currentTurn': game.players.first,
        // تهيئة القطع بالـ UID الفعلي لكل لاعب
        'data.tokens.${game.players.first}': [0, 0, 0, 0],
        'data.tokens.$userId': [0, 0, 0, 0],
      });
      return doc.id;
    } else {
      final newDoc = _games.doc();
      final game = GameModel(
        id: newDoc.id,
        type: type,
        players: [userId],
        playerNames: {userId: userName},
        currentTurn: userId,
        data: _getInitialData(type),
        scores: {userId: 0},
        status: 'waiting',
        createdAt: DateTime.now(),
      );

      await newDoc.set(game.toMap());
      return newDoc.id;
    }
  }

  Map<String, dynamic> _getInitialData(String type) {
    if (type == 'ludo') {
      return {
        'diceRolls': [],
        'sixCount': 0,
        'tokens': {}, // سيتم ملؤها عند بدء اللعبة فعلياً
        'turnStatus': 'rolling',
      };
    }
    // ... الأنواع الأخرى تبقى كما هي
    return {};
  }

  Stream<GameModel?> streamGame(String gameId) {
    return _games.doc(gameId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return GameModel.fromFirestore(doc);
    });
  }

  Future<void> makeMove(String gameId, Map<String, dynamic> updates) async {
    await _games.doc(gameId).update(updates);
  }

  Future<void> leaveGame(String gameId, String userId) async {
    await _games.doc(gameId).update({
      'status': 'finished',
      'winner': 'opponent_left',
    });
  }
}
