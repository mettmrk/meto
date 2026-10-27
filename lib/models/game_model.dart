import 'package:cloud_firestore/cloud_firestore.dart';

class GameModel {
  final String id;
  final String type; // 'tictactoe', 'rps'
  final List<String> players; // [uid1, uid2]
  final Map<String, String> playerNames; // {uid1: "Ali", uid2: "Ahmed"}
  final String currentTurn; // uid of current player
  final Map<String, dynamic> data; // Game specific data (board, moves)
  final Map<String, int> scores; // {uid1: 0, uid2: 0}
  final String status; // 'waiting', 'active', 'finished'
  final String? winner; // uid or 'draw'
  final DateTime createdAt;

  GameModel({
    required this.id,
    required this.type,
    required this.players,
    required this.playerNames,
    required this.currentTurn,
    required this.data,
    required this.scores,
    required this.status,
    this.winner,
    required this.createdAt,
  });

  factory GameModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return GameModel(
      id: doc.id,
      type: map['type'] ?? '',
      players: List<String>.from(map['players'] ?? []),
      playerNames: Map<String, String>.from(map['playerNames'] ?? {}),
      currentTurn: map['currentTurn'] ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      scores: Map<String, int>.from(map['scores'] ?? {}),
      status: map['status'] ?? 'waiting',
      winner: map['winner'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'players': players,
      'playerNames': playerNames,
      'currentTurn': currentTurn,
      'data': data,
      'scores': scores,
      'status': status,
      'winner': winner,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
