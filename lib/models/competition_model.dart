import 'package:cloud_firestore/cloud_firestore.dart';

enum CompetitionStatus { active, completed, cancelled, rolling }

class Competition {
  final String id;
  final String title;
  final String description;
  final String teamA;
  final String teamB;
  final String? teamAImage;
  final String? teamBImage;
  final String? winnerTeam; // teamA or teamB or null
  final List<String> votesA; // userIds
  final List<String> votesB; // userIds
  final String? winnerUserId; // Final winner from roulette
  final String? winnerName;
  final String? winnerPhoto;
  final int prizeAmount;
  final String prizeCurrency; // diamonds, meto, gold
  final CompetitionStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? rouletteStartTime;
  final DateTime? endTime;
  final String type; // voting, quiz, guess, speed, elimination
  final List<String> participants; // general list for non-voting types
  final List<String> eliminated; // UIDs of people who lost and cannot rejoin
  final List<String> rouletteParticipants; // Subset of UIDs currently on the wheel
  final Map<String, String> answers; // uid -> answer
  final List<Map<String, dynamic>> winners; // List of winners data
  final List<Map<String, dynamic>> questions; // For speed challenge
  final int? spinTargetIndex;
  final String? spinType; // 'eliminate' or 'win'
  final String? lastEliminatedName;
  final String? lastEliminatedPhoto;
  final String? exclusiveFrame;
  final String? profileDeco;
  final String? roomBg;
  final String? exclusiveEntrance;
  final String? exclusiveWallHanging;
  final String? exclusiveRoomCardFrame;

  Competition({
    required this.id,
    required this.title,
    required this.description,
    required this.teamA,
    required this.teamB,
    this.teamAImage,
    this.teamBImage,
    this.winnerTeam,
    required this.votesA,
    required this.votesB,
    this.winnerUserId,
    this.winnerName,
    this.winnerPhoto,
    required this.prizeAmount,
    required this.prizeCurrency,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.rouletteStartTime,
    required this.type,
    required this.participants,
    required this.eliminated,
    required this.rouletteParticipants,
    required this.answers,
    required this.winners,
    required this.questions,
    this.spinTargetIndex,
    this.spinType,
    this.lastEliminatedName,
    this.lastEliminatedPhoto,
    this.exclusiveFrame,
    this.profileDeco,
    this.roomBg,
    this.exclusiveEntrance,
    this.exclusiveWallHanging,
    this.exclusiveRoomCardFrame,
    this.endTime,
  });

  factory Competition.fromMap(String id, Map<String, dynamic> map) {
    return Competition(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      teamA: map['teamA'] ?? '',
      teamB: map['teamB'] ?? '',
      teamAImage: map['teamAImage'],
      teamBImage: map['teamBImage'],
      winnerTeam: map['winnerTeam'],
      votesA: List<String>.from(map['votesA'] ?? []),
      votesB: List<String>.from(map['votesB'] ?? []),
      winnerUserId: map['winnerUserId'],
      winnerName: map['winnerName'],
      winnerPhoto: map['winnerPhoto'],
      prizeAmount: map['prizeAmount'] ?? 0,
      prizeCurrency: map['prizeCurrency'] ?? 'diamonds',
      status: CompetitionStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'active'),
        orElse: () => CompetitionStatus.active,
      ),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      rouletteStartTime: (map['rouletteStartTime'] as Timestamp?)?.toDate(),
      endTime: (map['endTime'] as Timestamp?)?.toDate(),
      type: map['type'] ?? 'تصويت',
      participants: List<String>.from(map['participants'] ?? []),
      eliminated: List<String>.from(map['eliminated'] ?? []),
      rouletteParticipants: List<String>.from(map['rouletteParticipants'] ?? []),
      answers: Map<String, String>.from(map['answers'] ?? {}),
      winners: List<Map<String, dynamic>>.from(map['winners'] ?? []),
      questions: List<Map<String, dynamic>>.from(map['questions'] ?? []),
      spinTargetIndex: map['spinTargetIndex'],
      spinType: map['spinType'],
      lastEliminatedName: map['lastEliminatedName'],
      lastEliminatedPhoto: map['lastEliminatedPhoto'],
      exclusiveFrame: map['exclusiveFrame'],
      profileDeco: map['profileDeco'],
      roomBg: map['roomBg'],
      exclusiveEntrance: map['exclusiveEntrance'],
      exclusiveWallHanging: map['exclusiveWallHanging'],
      exclusiveRoomCardFrame: map['exclusiveRoomCardFrame'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'teamA': teamA,
      'teamB': teamB,
      'teamAImage': teamAImage,
      'teamBImage': teamBImage,
      'winnerTeam': winnerTeam,
      'votesA': votesA,
      'votesB': votesB,
      'winnerUserId': winnerUserId,
      'winnerName': winnerName,
      'winnerPhoto': winnerPhoto,
      'prizeAmount': prizeAmount,
      'prizeCurrency': prizeCurrency,
      'status': status.name,
      'createdAt': createdAt,
      'completedAt': completedAt,
      'rouletteStartTime': rouletteStartTime,
      'endTime': endTime,
      'type': type,
      'participants': participants,
      'eliminated': eliminated,
      'rouletteParticipants': rouletteParticipants,
      'answers': answers,
      'winners': winners,
      'questions': questions,
      'lastEliminatedName': lastEliminatedName,
      'lastEliminatedPhoto': lastEliminatedPhoto,
      'exclusiveFrame': exclusiveFrame,
      'profileDeco': profileDeco,
      'roomBg': roomBg,
      'exclusiveEntrance': exclusiveEntrance,
      'exclusiveWallHanging': exclusiveWallHanging,
      'exclusiveRoomCardFrame': exclusiveRoomCardFrame,
    };
  }
}
