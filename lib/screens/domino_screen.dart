// ignore_for_file: curly_braces_in_flow_control_structures, unused_element_parameter, invalid_return_type_for_catch_error, duplicate_ignore

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbauth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:mmmm/services/user_service.dart';
import '../models/user_model.dart' as app;
import '../services/domino_service.dart';
import 'package:mmmm/widgets/sticker_selection_bottom_sheet.dart';
import 'package:animated_emoji/animated_emoji.dart';
import 'package:mmmm/widgets/domino_player_profile_bottom_sheet.dart';
import 'package:mmmm/widgets/voice_volume_meter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/voice_room_service.dart';
import 'chat_screen.dart';
import 'package:lottie/lottie.dart';

class DominoTile {
  final int sideA;
  final int sideB;
  bool isReversed;
  int? owner;
  int playOrder;

  DominoTile(
    this.sideA,
    this.sideB, {
    this.isReversed = false,
    this.owner,
    this.playOrder = 0,
  });

  bool get isDouble => sideA == sideB;

  Map<String, dynamic> toMap() {
    return {
      'sideA': sideA,
      'sideB': sideB,
      'isReversed': isReversed,
      'owner': owner,
      'playOrder': playOrder,
    };
  }

  factory DominoTile.fromMap(Map<dynamic, dynamic> map) {
    return DominoTile(
      (map['sideA'] as num).toInt(),
      (map['sideB'] as num).toInt(),
      isReversed: map['isReversed'] ?? false,
      owner: map['owner'] != null ? (map['owner'] as num).toInt() : null,
      playOrder: (map['playOrder'] as num? ?? 0).toInt(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DominoTile &&
        ((other.sideA == sideA && other.sideB == sideB) ||
            (other.sideA == sideB && other.sideB == sideA));
  }

  @override
  int get hashCode {
    // Ensure symmetric hashCode for (A,B) and (B,A)
    return sideA < sideB
        ? Object.hash(sideA, sideB)
        : Object.hash(sideB, sideA);
  }

  @override
  String toString() => isReversed ? '[$sideB|$sideA]' : '[$sideA|$sideB]';
}

class TilePlacement {
  final DominoTile tile;
  final double cx;
  final double cy;
  final int turns;
  final int index;
  final bool isPreview;
  final bool isLeftPreview;
  final bool isUpPreview;
  final bool isDownPreview;
  final int potentialScore;

  TilePlacement(
    this.tile,
    this.cx,
    this.cy,
    this.turns,
    this.index, {
    this.isPreview = false,
    this.isLeftPreview = false,
    this.isUpPreview = false,
    this.isDownPreview = false,
    this.potentialScore = 0,
  });
}

class DominoScreen extends StatefulWidget {
  final int betAmount;
  final String gameMode;
  final int playerCount;
  final String? roomId;

  const DominoScreen({
    Key? key,
    required this.betAmount,
    this.gameMode = 'points',
    this.playerCount = 2,
    this.roomId,
  }) : super(key: key);

  @override
  State<DominoScreen> createState() => _DominoScreenState();
}

class _DominoScreenState extends State<DominoScreen> {
  // قائمة بونيارد (السحب) التي ستحتوي على جميع القطع
  List<DominoTile> boneyard = [];

  // قائمة لتمثيل القطع الملعوبة على الطاولة
  List<DominoTile> board = [];

  // تتبع الأطراف المفتوحة على الطاولة (من اليمين واليسار)
  int? leftEnd;
  int? rightEnd;
  int? upEnd; // For 4-way play
  int? downEnd;
  List<DominoTile> upBranch = [];
  List<DominoTile> downBranch = [];

  // جذر سلسلة الدومينو للمحافظة على مكان القطعة الأولى
  int rootIndex = 0;

  // For Muggins/All Fives mode
  DominoTile? spinner;

  // حفظ دور اللاعب الحالي (مثلاً 0 للاعب الأول، 1 للاعب الثاني)
  int currentPlayer = 0;

  // تعريف رسالة الحالة
  String statusMessage = "";
  bool _isAutoDrawing = false;

  List<List<DominoTile>> playersHands = [];

  // Scorer Variables
  bool _isShowingRoundOverDialog = false;
  bool _isShowingGameOverDialog = false;
  List<int> playerScores = [];
  final int winningScore = 101;
  bool isGameOver = false;
  int roundNumber = 1;

  int playOrderCounter = 0;
  DominoTile? selectedTile;

  final Map<int, String?> _activeStickers = {};
  final Map<int, String?> _activeChats = {};
  final Map<int, double> _playerVolumes = {};
  final Map<int, String> _playerNames = {};
  final Map<int, String?> _playerPhotos = {};
  final Map<int, String> _playerUids = {};
  final Set<String> _mutedUserUids = {};

  // Chat Variables
  bool _isChatInputOpen = false;
  int _unreadChatCount = 0;
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  List<DominoGameLogEntry> _gameLog = [];

  // User data
  app.User? _currentUser;

  // Turn Timer and AutoPlay
  Timer? _turnTimer;
  double _turnProgress = 0.0;
  bool _isAutoPlay = false; // User's preference to play automatically
  bool _isOpponentOffline =
      false; // Whether the current turn's player is offline
  final Set<int> _autoPlayPlayers = {}; // اللاعبين في وضع الاوتو
  bool _justForcedMove = false; // تتبع ما إذا كان الكلاينت النشط فرض لعب الخصم

  // Online Mode state
  String? _roomId;
  bool _isOnline = false;
  int _myPlayerIndex = 0;
  StreamSubscription? _roomSubscription;
  bool _isMatchmaking = false;
  bool _betDeducted = false;
  bool _matchFoundTransition = false;
  int _countdownSeconds = 3;
  Timer? _countdownTimer;
  bool _isMuted = false;
  double _musicVolume = 0.85;
  double _sfxVolume = 0.85;
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer(); // Added for background music
  bool _hasReceivedWinnings = false;
  bool _hasUpdatedStats = false;
  bool _justPlayedLocally = false;

  Timer? _abnormalExitTimer;
  DateTime? _abnormalExitStart;

  @override
  void initState() {
    playersHands = List.generate(widget.playerCount, (_) => []);
    playerScores = List.generate(widget.playerCount, (_) => 0);
    for (int i = 0; i < widget.playerCount; i++) {
      _activeStickers[i] = null;
      _activeChats[i] = null;
    }

    super.initState();
    _abnormalExitTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkAbnormalExit(),
    );
    _loadCurrentUser();
    _loadAudioPreferences();
    if (widget.roomId != null) {
      // Join Voice Room for online match
      Future.delayed(Duration.zero, () {
        if (mounted) {
          final voiceService = Provider.of<VoiceRoomService>(
            context,
            listen: false,
          );
          voiceService.joinGameChannel(widget.roomId!);
        }
      });
      _initOnlineGame(widget.roomId!);
    } else {
      _initializeGame(resetScores: true);
    }
  }

  void _initOnlineGame(String roomId) {
    setState(() {
      _roomId = roomId;
      _isOnline = true;
      _isMatchmaking = true;
    });

    _roomSubscription = DominoService().streamRoom(roomId).listen((event) {
      _handleRoomUpdate(event);
    });
  }

  void _startMatchCountdown() {
    _countdownSeconds = 3;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
        } else {
          timer.cancel();
          _isMatchmaking = false;
          _matchFoundTransition = false;
        }
      });
    });
  }

  void _handleRoomUpdate(DatabaseEvent event) {
    if (event.snapshot.value == null || !mounted) return;

    final roomData = Map<String, dynamic>.from(event.snapshot.value as Map);
    final players = roomData['players'] as Map?;
    final state = roomData['state'] as Map?;
    final String status = roomData['status'] ?? 'waiting';

    if (players == null || state == null) return;

    // ── Determine MY player index FIRST (synchronously, before setState) ──
    final myUid = fbauth.FirebaseAuth.instance.currentUser?.uid;
    int? myIdx;
    players.forEach((uid, data) {
      if (uid == myUid) {
        myIdx = (data['index'] as num?)?.toInt();
      }
    });

    // Safety: Clamp index to valid room capacity if necessary,
    // or just ensure we don't use indices outside of our List bounds.
    if (myIdx != null) {
      // For standard 2-player Dominoes, we expect 0 or 1.
      if (myIdx! >= 0 && myIdx! < 10) {
        // arbitrary safety cap
        _myPlayerIndex = myIdx!;
      }
    }

    bool transitionedToPlaying = false;
    setState(() {
      if (_isMatchmaking && status == 'playing' && !_matchFoundTransition) {
        _matchFoundTransition = true;
        transitionedToPlaying = true;
        _startMatchCountdown();
      }
      // Only stop matchmaking if we are not in the transition delay
      if (!_matchFoundTransition) {
        _isMatchmaking = (status == 'waiting');
      }

      // ── Explicit Exit Detection ──
      if (status == 'playing' &&
          !isGameOver &&
          players.length < widget.playerCount) {
        _onOpponentSurrender(message: "لقد غادر الخصم المباراة! لقد انتصرت.");
      }

      // ── NEW: Deduct coins only when match is found ──
      if (status == 'playing' &&
          !_betDeducted &&
          _isOnline &&
          widget.betAmount > 0) {
        _betDeducted = true;
        final myUid = fbauth.FirebaseAuth.instance.currentUser?.uid;
        if (myUid != null) {
          UserService()
              .updateUser(
                uid: myUid,
                data: {'coins': FieldValue.increment(-widget.betAmount)},
              )
              .then((_) {
                debugPrint('[DominoBet] Coins deducted as match started.');
              })
              // ignore: invalid_return_type_for_catch_error
              .catchError((e) => debugPrint('[DominoBet] Deduction error: $e'));
        }
      }

      // Update all players info and track offline status by index
      final Map<int, bool> offlineStatus = {};
      players.forEach((uid, data) {
        int idx = (data['index'] as num?)?.toInt() ?? 0;
        _playerNames[idx] = data['name'] ?? "لاعب ${idx + 1}";
        _playerPhotos[idx] = data['photo'];
        _playerUids[idx] = uid;
        offlineStatus[idx] = data['online'] == false;
      });

      _isOpponentOffline =
          (currentPlayer != _myPlayerIndex) &&
          (offlineStatus[currentPlayer] == true);

      if (status == 'playing') {
        int prevPlayer = currentPlayer;
        currentPlayer = (state['currentPlayerIndex'] as num?)?.toInt() ?? 0;

        if (currentPlayer != prevPlayer) {
          if (!_justForcedMove) {
            _autoPlayPlayers.remove(prevPlayer);
          }
          _justForcedMove = false;
        }

        // Re-check after updating currentPlayer
        _isOpponentOffline =
            (currentPlayer != _myPlayerIndex) &&
            (offlineStatus[currentPlayer] == true);

        final scores = state['playerScores'] as List?;
        if (scores != null) {
          playerScores = scores.map((e) => (e as num).toInt()).toList();
        }
        // Ensure correct length based on player count
        while (playerScores.length < widget.playerCount) {
          playerScores.add(0);
        }

        int limit = widget.gameMode == 'multiplier' ? 100 : winningScore;
        bool scoreLimitReached = playerScores.any((s) => s >= limit);
        bool remoteGameOver =
            (state['isGameOver'] ?? false) || scoreLimitReached;

        if (!remoteGameOver && isGameOver && _isShowingRoundOverDialog) {
          _isShowingRoundOverDialog = false;
          Future.delayed(Duration.zero, () {
            // Safer way to pop only if a dialog is showing
            Navigator.of(context, rootNavigator: true).pop();
          });
        }

        final roundStatus = state['lastRoundStatus'] as Map?;
        if (roundStatus != null) {
          bool remoteRoundOver = roundStatus['isRoundOver'] ?? false;
          int? winnerIndex = (roundStatus['winnerIndex'] as num?)?.toInt();
          int p = (roundStatus['roundPoints'] as num?)?.toInt() ?? 0;
          bool isFinished =
              (roundStatus['isGameFinished'] ?? false) || scoreLimitReached;

          if (remoteRoundOver &&
              !_isShowingRoundOverDialog &&
              !remoteGameOver) {
            _isShowingRoundOverDialog = true;
            _showRoundOverDialog(
              winnerIndex ?? 0,
              p,
              isFinished,
              isRemote: true,
            );
          } else if (remoteGameOver && !_isShowingGameOverDialog) {
            int w = (playerScores[0] >= playerScores[1]) ? 0 : 1;
            // Best winner logic for 4 players
            if (widget.playerCount > 2) {
              int maxS = -1;
              for (int i = 0; i < playerScores.length; i++) {
                if (playerScores[i] > maxS) {
                  maxS = playerScores[i];
                  w = i;
                }
              }
            }
            _showGameOverDialog(w);
          }
        }

        isGameOver = remoteGameOver;

        // Sync Ends
        final ends = state['ends'] as Map?;
        if (ends != null) {
          leftEnd = ends['left'] != null ? (ends['left'] as num).toInt() : null;
          rightEnd = ends['right'] != null
              ? (ends['right'] as num).toInt()
              : null;
          upEnd = ends['up'] != null ? (ends['up'] as num).toInt() : null;
          downEnd = ends['down'] != null ? (ends['down'] as num).toInt() : null;
        }

        // Sync Board
        final boardList = state['board'] as List?;
        if (boardList != null) {
          final newBoard = boardList
              .map((e) => DominoTile.fromMap(e as Map))
              .toList();
          if (newBoard.length > board.length) {
            if (_justPlayedLocally) {
              _justPlayedLocally = false;
            } else {
              _playDominoSound();
            }
          }
          board = _dedupeTiles(newBoard);
        }

        // Sync All Hands
        final allHands = state['playerHands'] as List?;
        if (allHands != null) {
          playersHands = allHands.map((h) {
            final hList = h as List?;
            if (hList == null) return <DominoTile>[];
            return _dedupeTiles(hList.map((e) => DominoTile.fromMap(e as Map)));
          }).toList();
        }
        // Ensure at least 2 elements to prevent RangeError in UI
        while (playersHands.length < 2) {
          playersHands.add([]);
        }

        // Sync Boneyard with real values
        if (state['boneyard'] != null) {
          boneyard = _dedupeTiles(
            (state['boneyard'] as List).map(
              (e) => DominoTile.fromMap(e as Map),
            ),
          );
        }

        // Sync Branches
        final ub = state['upBranch'] as List?;
        if (ub != null) {
          upBranch = _dedupeTiles(ub.map((e) => DominoTile.fromMap(e as Map)));
        } else {
          upBranch.clear();
        }
        final db = state['downBranch'] as List?;
        if (db != null) {
          downBranch = _dedupeTiles(
            db.map((e) => DominoTile.fromMap(e as Map)),
          );
        } else {
          downBranch.clear();
        }

        // Spinner
        if (state['spinner'] != null) {
          spinner = DominoTile.fromMap(state['spinner'] as Map);
        } else {
          spinner = null;
        }

        rootIndex = (state['rootIndex'] as num?)?.toInt() ?? 0;
        playOrderCounter = (state['playOrderCounter'] as num?)?.toInt() ?? 0;
        _sanitizeCollections();

        // Sync Interactions (Chat)
        final dynamic interactionsRaw = roomData['interactions'];
        if (interactionsRaw != null && interactionsRaw is Map) {
          final newLog = <DominoGameLogEntry>[];
          interactionsRaw.forEach((key, data) {
            if (data is Map) {
              String uid = data['senderId']?.toString() ?? key.toString();
              if (!_mutedUserUids.contains(uid)) {
                newLog.add(
                  DominoGameLogEntry(
                    type: data['type'] == 'sticker' ? 'sticker' : 'chat',
                    content: data['content'].toString(),
                    senderId: uid,
                    timestamp: (data['timestamp'] as num?)?.toInt() ?? 0,
                  ),
                );
              }
            }
          });
          newLog.sort((a, b) => a.timestamp.compareTo(b.timestamp));

          if (newLog.length > _gameLog.length) {
            if (!_isChatInputOpen) {
              _unreadChatCount += (newLog.length - _gameLog.length);
            }
            final addedMessages = newLog.sublist(_gameLog.length);
            for (var msg in addedMessages) {
              int idx = -1;
              _playerUids.forEach((key, value) {
                if (value == msg.senderId) idx = key;
              });

              if (idx != -1) {
                if (msg.type == 'chat') {
                  _activeChats[idx] = msg.content;
                  final currentContent = msg.content;
                  Future.delayed(const Duration(seconds: 4), () {
                    if (mounted && _activeChats[idx] == currentContent) {
                      setState(() => _activeChats[idx] = null);
                    }
                  });
                } else if (msg.type == 'sticker') {
                  _activeStickers[idx] = msg.content;
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted) {
                      setState(() => _activeStickers[idx] = null);
                    }
                  });
                }
              }
            }
            _gameLog = newLog;
            if (_chatScrollController.hasClients) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_chatScrollController.hasClients) {
                  _chatScrollController.animateTo(
                    _chatScrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
            }
          } else {
            _gameLog = newLog;
          }
        }
      }

      // ── Surrender / Abandonment / Offline Detection ──
      if (status != 'waiting' && !isGameOver) {
        players.forEach((uid, data) {
          if (uid != myUid) {
            bool left = data['left'] == true;
            bool online = data['online'] != false;

            // Track if current turn's player is offline (for 1v1)
            // In 1v1, the only 'other' player is the opponent.
            _isOpponentOffline = !online;

            if (left) {
              _onOpponentSurrender(
                message: "لقد غادر الخصم المباراة! لقد انتصرت.",
              );
            }
            // Note: The 60-second offline check is now handled by _checkAbnormalExit continuously.
          }
        });
      }
    });

    // After every Firebase update during gameplay, restart the timer
    // if it just became this player's turn.
    if (status == 'playing' &&
        !transitionedToPlaying &&
        !isGameOver &&
        !_isShowingRoundOverDialog &&
        !_isShowingGameOverDialog) {
      // Restart timer if it's my turn OR if it's an offline opponent's turn
      bool isMyTurn = currentPlayer == _myPlayerIndex;
      bool isOpponentOffline = false;

      // Check if current player (who is NOT me) is offline
      players.forEach((uid, data) {
        if (data['index'] == currentPlayer && uid != myUid) {
          if (data['online'] == false) isOpponentOffline = true;
        }
      });

      if (isMyTurn || isOpponentOffline) {
        _stopTurnTimer();
        _startTurnTimer();
      }
    }

    if (transitionedToPlaying) {
      // Only the host initializes and pushes state.
      // The guest waits for Firebase to deliver the state via _handleRoomUpdate.
      if (_myPlayerIndex == 0) {
        _initializeGame();
      } else if (_isShowingRoundOverDialog && _isShowingGameOverDialog) {
        statusMessage = "🔒 قفل وتعادل في مجموع النقاط، لا نقاط لهذه الجولة.";
      } else {
        // Guest: start timer after Firebase delivers initial hands.
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _stopTurnTimer();
            _startTurnTimer();
          }
        });
      }
    }
  }

  void _onOpponentSurrender({String? message}) {
    if (isGameOver) return;
    setState(() {
      isGameOver = true;
    });

    _showGameOverDialog(
      _myPlayerIndex,
      message: message ?? "انسحب الخصم من المباراة! أنت الفائز.",
    );
  }

  void _checkAbnormalExit() {
    if (isGameOver || !_isOnline || _isMatchmaking) return;

    // Check if any opponent is offline or in auto-play
    bool isOpponentDisconnected =
        _isOpponentOffline ||
        _autoPlayPlayers.any((idx) => idx != _myPlayerIndex);

    if (isOpponentDisconnected) {
      if (_abnormalExitStart == null) {
        _abnormalExitStart = DateTime.now();
      } else {
        if (DateTime.now().difference(_abnormalExitStart!).inSeconds >= 60) {
          _onOpponentSurrender(
            message: "انتهى الوقت المسموح لعودة الخصم! لقد انتصرت.",
          );
          _abnormalExitTimer?.cancel();
        }
      }
    } else {
      _abnormalExitStart = null;
    }
  }

  Future<void> _loadCurrentUser() async {
    final fbUser = fbauth.FirebaseAuth.instance.currentUser;
    if (fbUser == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(fbUser.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _currentUser = app.User.fromMap(doc.data()!, fbUser.uid);
      });
    }
  }

  Future<void> _loadAudioPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMuted = prefs.getBool('domino_game_muted') ?? false;
    } catch (e) {
      debugPrint("Domino Audio Prefs Load Error: $e");
    }

    if (!mounted) return;
    _initMusic();
  }

  Future<void> _saveMutedPreference(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('domino_game_muted', value);
    } catch (e) {
      debugPrint("Domino Audio Prefs Save Error: $e");
    }
  }

  void _initMusic() {
    _musicPlayer
        .setAsset('assets/sounds/domino.mp3')
        .then((_) {
          _musicPlayer.setLoopMode(LoopMode.all);
          _musicPlayer.setVolume(_isMuted ? 0.0 : _musicVolume);
          if (!_isMuted) _musicPlayer.play();
        })
        .catchError((e) {
          debugPrint("Domino Music Load Error: $e");
        });
  }

  final double tW = 40.0;
  final double tH = 80.0;

  void _stopTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
    if (mounted) {
      setState(() {
        _turnProgress = 0.0;
      });
    }
  }

  void _playDominoSound() async {
    if (_isMuted || _sfxVolume == 0.0) return;
    try {
      final tempPlayer = AudioPlayer();
      await tempPlayer.setAsset('assets/sounds/dominorme.mp3');
      await tempPlayer.setVolume(_isMuted ? 0.0 : _sfxVolume);
      tempPlayer.play().then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          tempPlayer.dispose();
        });
      });
    } catch (e) {
      debugPrint('[DominoSFX] Error playing dominorme: $e');
    }
  }

  void _startTurnTimer() {
    _stopTurnTimer();
    if (isGameOver || _isShowingRoundOverDialog) return;

    // In online mode, we auto-play for ourselves OR if we are the 'active' online player
    // and the opponent whose turn it is is offline.
    bool isMyTurn = currentPlayer == _myPlayerIndex;
    // (We need to check offline status of currentPlayer here too)
    // Actually, we already set this logic in handleRoomUpdate to trigger startTurnTimer.
    // Here we just need to ensure we don't return early if we are supposed to manage the opponent's turn.
    if (_isOnline && !isMyTurn) {
      // Find if opponent is offline. We'll use a local state or check Firebase room data again?
      // Since _startTurnTimer is called from handleRoomUpdate, we can pass it or check a flag.
      // Let's just re-check if we are the 'active' substitute.
      // In 1v1, if I'm online and it's NOT my turn, and I'm here, I'm the substitute.
    }

    // Check if we have playable tiles. If not, auto-draw (unless it's AI turn in local mode)
    if (_isOnline || currentPlayer == 0) {
      bool hasPlayable = playersHands[currentPlayer].any((t) => canPlayTile(t));
      if (!hasPlayable && playersHands[currentPlayer].isNotEmpty) {
        bool isMyTurn = currentPlayer == _myPlayerIndex;
        bool shouldManageOpponent =
            !isMyTurn &&
            (_autoPlayPlayers.contains(currentPlayer) || _isOpponentOffline);

        if (isMyTurn || shouldManageOpponent) {
          if (boneyard.isNotEmpty) {
            setState(() => statusMessage = "جاري السحب آلياً...");
            Future.delayed(
              const Duration(milliseconds: 500),
              () => _autoDrawForHuman(forceOpponent: shouldManageOpponent),
            );
            return; // Don't start the normal turn timer yet
          } else {
            // No moves and no tiles to draw -> skip turn automatically
            setState(() => statusMessage = "لا يوجد لعب! تخطي آلي...");
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                _nextTurn();
                if (_isOnline) _pushStateToFirebase();
              }
            });
            return;
          }
        }
      }
    }

    // In local mode, only auto-play for human (0)
    if (!_isOnline && currentPlayer != 0) return;

    _turnProgress = 1.0;
    bool isMyTurnForTimer = currentPlayer == _myPlayerIndex;

    // إذا كان دور الخصم، نعطيه مهلة 13 ثانية، إلا إذا كان في وضع الاوتو فنعطيه ثانية واحدة فقط للعب الفوري
    int durationSeconds = 13;
    if (isMyTurnForTimer) {
      durationSeconds = 10;
    } else if (_autoPlayPlayers.contains(currentPlayer) || _isOpponentOffline) {
      durationSeconds = 1;
    }

    final duration = Duration(seconds: durationSeconds);
    const interval = Duration(milliseconds: 100);
    int totalSteps = duration.inMilliseconds ~/ interval.inMilliseconds;
    int currentStep = totalSteps;

    _turnTimer = Timer.periodic(interval, (timer) {
      currentStep--;
      if (mounted) {
        setState(() {
          _turnProgress = currentStep / totalSteps;
        });
      }

      if (currentStep <= 0) {
        _stopTurnTimer();
        if (mounted) {
          // Only set user's _isAutoPlay to true if it was actually their turn that timed out
          if (currentPlayer == _myPlayerIndex) {
            setState(() {
              _isAutoPlay = true;
            });
          }
          _playAutomaticMoveForHuman(forceOpponent: true);
        }
      }
    });

    // If it's my turn and I have auto-play ON, OR if it's the opponent's turn and they are offline
    bool shouldAutoPlayNow =
        (currentPlayer == _myPlayerIndex && _isAutoPlay) ||
        (currentPlayer != _myPlayerIndex && _isOpponentOffline);

    if (shouldAutoPlayNow) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && shouldAutoPlayNow) {
          _playAutomaticMoveForHuman();
        }
      });
    }
  }

  void _playAutomaticMoveForHuman({bool forceOpponent = false}) {
    if (isGameOver || !mounted) return;

    if (forceOpponent) {
      _justForcedMove = true;
      _autoPlayPlayers.add(currentPlayer);
    }

    // Check again before playing
    bool isMyTurn = currentPlayer == _myPlayerIndex;
    if (isMyTurn && !_isAutoPlay) return;
    if (!isMyTurn && !_isOpponentOffline && !forceOpponent) return;

    // Find first playable tile for whoever's turn it is
    DominoTile? tileToPlay;
    for (var tile in playersHands[currentPlayer]) {
      if (canPlayTile(tile)) {
        tileToPlay = tile;
        break;
      }
    }

    if (tileToPlay != null) {
      if (board.isEmpty) {
        playTile(currentPlayer, tileToPlay, playOnLeft: true, isManual: false);
        return;
      }

      // Check all 4 ways in multiplier mode
      if (widget.gameMode == 'multiplier' && spinner != null) {
        if (tileToPlay.sideA == upEnd || tileToPlay.sideB == upEnd) {
          playTile(currentPlayer, tileToPlay, playOnUp: true, isManual: false);
          return;
        }
        if (tileToPlay.sideA == downEnd || tileToPlay.sideB == downEnd) {
          playTile(
            currentPlayer,
            tileToPlay,
            playOnDown: true,
            isManual: false,
          );
          return;
        }
      }

      if (tileToPlay.sideA == leftEnd || tileToPlay.sideB == leftEnd) {
        playTile(currentPlayer, tileToPlay, playOnLeft: true, isManual: false);
      } else {
        playTile(currentPlayer, tileToPlay, playOnLeft: false, isManual: false);
      }
    } else {
      // No playable tile found, start auto-drawing
      if (boneyard.isNotEmpty) {
        _autoDrawForHuman(forceOpponent: forceOpponent);
      } else {
        // Skip turn if boneyard also empty
        _nextTurn();
        if (_isOnline) _pushStateToFirebase();
      }
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _turnTimer?.cancel();
    _countdownTimer?.cancel();
    _abnormalExitTimer?.cancel();
    _sfxPlayer.dispose();
    _musicPlayer.dispose();

    // Leave Voice Room on exit
    if (_isOnline && _roomId != null) {
      try {
        final voiceService = Provider.of<VoiceRoomService>(
          context,
          listen: false,
        );
        voiceService.leaveGameChannel();
      } catch (e) {
        debugPrint("Error leaving voice room: $e");
      }
    }
    super.dispose();
  }

  // 2. إنشاء جميع قطع الدومينو الـ 28 القياسية
  void _generateTiles() {
    boneyard.clear();
    for (int i = 0; i <= 6; i++) {
      for (int j = i; j <= 6; j++) {
        boneyard.add(DominoTile(i, j));
      }
    }
  }

  int _handPipTotal(List<DominoTile> hand) {
    return hand.fold(0, (sum, tile) => sum + tile.sideA + tile.sideB);
  }

  String _tileKey(DominoTile tile) {
    final low = math.min(tile.sideA, tile.sideB);
    final high = math.max(tile.sideA, tile.sideB);
    return '$low|$high';
  }

  List<DominoTile> _dedupeTiles(Iterable<DominoTile> tiles) {
    final seen = <String>{};
    final result = <DominoTile>[];
    for (final tile in tiles) {
      final key = _tileKey(tile);
      if (seen.add(key)) {
        result.add(tile);
      }
    }
    return result;
  }

  void _sanitizeCollections() {
    final used = <String>{};

    List<DominoTile> takeUnique(Iterable<DominoTile> tiles) {
      final result = <DominoTile>[];
      for (final tile in tiles) {
        final key = _tileKey(tile);
        if (used.add(key)) {
          result.add(tile);
        }
      }
      return result;
    }

    board = takeUnique(board);
    upBranch = takeUnique(upBranch);
    downBranch = takeUnique(downBranch);
    playersHands = playersHands.map(takeUnique).toList();
    boneyard = takeUnique(boneyard);

    if (selectedTile != null) {
      final key = _tileKey(selectedTile!);
      final stillOwned = playersHands.any(
        (hand) => hand.any((t) => _tileKey(t) == key),
      );
      if (!stillOwned) {
        selectedTile = null;
      }
    }
  }

  int _compareOpeningTiles(DominoTile a, DominoTile b) {
    if (a.isDouble != b.isDouble) return a.isDouble ? 1 : -1;

    if (a.isDouble && b.isDouble) {
      return a.sideA.compareTo(b.sideA);
    }

    final sumComparison = (a.sideA + a.sideB).compareTo(b.sideA + b.sideB);
    if (sumComparison != 0) return sumComparison;

    final maxComparison = math
        .max(a.sideA, a.sideB)
        .compareTo(math.max(b.sideA, b.sideB));
    if (maxComparison != 0) return maxComparison;

    return math.min(a.sideA, a.sideB).compareTo(math.min(b.sideA, b.sideB));
  }

  DominoTile _findBestOpeningTile(List<DominoTile> hand) {
    DominoTile bestTile = hand.first;
    for (final tile in hand.skip(1)) {
      if (_compareOpeningTiles(tile, bestTile) > 0) {
        bestTile = tile;
      }
    }
    return bestTile;
  }

  ({int playerIndex, DominoTile tile}) _determineOpeningPlay({
    int preferredPlayer = 0,
  }) {
    final player0Tile = _findBestOpeningTile(playersHands[0]);
    final player1Tile = _findBestOpeningTile(playersHands[1]);
    final comparison = _compareOpeningTiles(player0Tile, player1Tile);

    if (comparison > 0) {
      return (playerIndex: 0, tile: player0Tile);
    }
    if (comparison < 0) {
      return (playerIndex: 1, tile: player1Tile);
    }

    final tiedPlayerIndex = preferredPlayer.clamp(0, playersHands.length - 1);
    return (
      playerIndex: tiedPlayerIndex,
      tile: _findBestOpeningTile(playersHands[tiedPlayerIndex]),
    );
  }

  void _placeOpeningTile(int playerIndex, DominoTile tile) {
    tile.owner = playerIndex;
    tile.playOrder = playOrderCounter++;
    tile.isReversed = false;

    board.add(tile);
    leftEnd = tile.sideA;
    rightEnd = tile.sideB;
    rootIndex = 0;
    playersHands[playerIndex].remove(tile);

    if (widget.gameMode == 'multiplier' && tile.isDouble) {
      spinner = tile;
      upEnd = tile.sideA;
      downEnd = tile.sideA;
    }

    currentPlayer = (playerIndex + 1) % playersHands.length;
    statusMessage =
        "بدأ اللاعب ${playerIndex + 1} بـ ${tile.toString()}، دور اللاعب ${currentPlayer + 1}";
  }

  // 3. خلط القطع وتوزيعها
  void _initializeGame({
    bool resetScores = false,
    int startingPlayer = 0,
    bool forceAsHost = false,
  }) {
    if (_isOnline && _myPlayerIndex != 0 && !forceAsHost) {
      _stopTurnTimer();
      setState(() {
        board = [];
        upBranch = [];
        downBranch = [];
        leftEnd = null;
        rightEnd = null;
        upEnd = null;
        downEnd = null;
        spinner = null;
        rootIndex = 0;
        playOrderCounter = 0;
        _isShowingRoundOverDialog = false;
        _isShowingGameOverDialog = false;
        selectedTile = null;
        statusMessage = "بانتظار بدء الجولة الجديدة...";
      });
      return;
    }

    _generateTiles();

    // خلط القطع بشكل عشوائي
    boneyard.shuffle(math.Random());

    // تهيئة أيدي اللاعبين
    playersHands = List.generate(widget.playerCount, (_) => []);

    // تهيئة الطاولة
    board = [];
    upBranch = [];
    downBranch = [];
    leftEnd = null;
    rightEnd = null;
    upEnd = null;
    downEnd = null;
    spinner = null;
    rootIndex = 0;
    playOrderCounter = 0;
    selectedTile = null;
    _isShowingRoundOverDialog = false;
    _isShowingGameOverDialog = false;

    // الفائز بالجولة السابقة يبدأ
    if (resetScores) {
      playerScores = List.generate(widget.playerCount, (_) => 0);
      roundNumber = 1;
    } else {
      roundNumber++;
    }

    statusMessage = "تبدأ الجولة الجديدة...";

    // التوزيع: في حالة لاعبين يتم توزيع 7 قطع لكل منهما بشكل افتراضي
    int numberOfPlayers = widget.playerCount;
    int tilesPerPlayer = 7;

    for (int i = 0; i < tilesPerPlayer; i++) {
      for (int p = 0; p < numberOfPlayers; p++) {
        if (boneyard.isNotEmpty) {
          playersHands[p].add(boneyard.removeLast());
        }
      }
    }

    // تحديث واجهة المستخدم بعد إعادة التوزيع
    if (resetScores) {
      final openingPlay = _determineOpeningPlay(
        preferredPlayer: startingPlayer,
      );
      _placeOpeningTile(openingPlay.playerIndex, openingPlay.tile);
    } else {
      currentPlayer = startingPlayer.clamp(0, playersHands.length - 1);
      statusMessage = "الجولة الجديدة بدأت، دور اللاعب ${currentPlayer + 1}";
    }

    if (mounted) {
      setState(() {});
    }

    if (_isOnline) {
      _pushStateToFirebase();
      if (currentPlayer == _myPlayerIndex || _isOpponentOffline) {
        _startTurnTimer();
      }
    } else {
      _startTurnTimer();
      if (currentPlayer == 1) {
        Future.delayed(const Duration(milliseconds: 1500), _playAITurn);
      }
    }
  }

  void _pushStateToFirebase() {
    if (_roomId == null) return;

    DominoService().updateGameState(_roomId!, {
      'state/board': board.map((e) => e.toMap()).toList(),
      'state/boneyard': boneyard.map((e) => e.toMap()).toList(),
      'state/playerHands': playersHands
          .map((h) => h.map((e) => e.toMap()).toList())
          .toList(),
      'state/playerScores': playerScores,
      'state/currentPlayerIndex': currentPlayer,
      'state/isGameOver': isGameOver,
      'state/ends': {
        'left': leftEnd,
        'right': rightEnd,
        'up': upEnd,
        'down': downEnd,
      },
      'state/upBranch': upBranch.map((e) => e.toMap()).toList(),
      'state/downBranch': downBranch.map((e) => e.toMap()).toList(),
      'state/lastRoundStatus/isRoundOver': _isShowingRoundOverDialog,
      'state/spinner': spinner?.toMap(),
      'state/rootIndex': rootIndex,
      'state/playOrderCounter': playOrderCounter,
    });
  }

  // 4. التحقق من صحة الحركة (Game Rule: Can Play Tile?)
  bool canPlayTile(DominoTile tile) {
    // إذا كانت الطاولة فارغة، يمكن لعب أي قطعة
    if (board.isEmpty) return true;

    // إذا كان أحد أطراف القطعة يطابق أحد الأطراف المفتوحة للطاولة
    bool matchesMain =
        tile.sideA == leftEnd ||
        tile.sideB == leftEnd ||
        tile.sideA == rightEnd ||
        tile.sideB == rightEnd;

    if (widget.gameMode == 'multiplier' && spinner != null) {
      bool matchesExtra =
          tile.sideA == upEnd ||
          tile.sideB == upEnd ||
          tile.sideA == downEnd ||
          tile.sideB == downEnd;
      return matchesMain || matchesExtra;
    }

    return matchesMain;
  }

  // وظيفة لعب القطعة (سلسلة عمودية مرنة)
  void playTile(
    int playerIndex,
    DominoTile tile, {
    bool playOnLeft = true,
    bool playOnUp = false,
    bool playOnDown = false,
    bool isManual = true,
  }) {
    if (isManual && playerIndex == _myPlayerIndex) {
      _isAutoPlay = false;
    }
    // In online mode, we only allow playing if it's my turn
    // OR if I'm playing as a substitute for an offline opponent.
    if (_isOnline && playerIndex != _myPlayerIndex) {
      // Logic for offline substitute is implicitly handled by the turn timer.
    }
    if (!canPlayTile(tile)) return;

    if (playerIndex == _myPlayerIndex ||
        (_isOnline && _isOpponentOffline && playerIndex == currentPlayer)) {
      _justPlayedLocally = true;
      _playDominoSound();
    } else if (!_isOnline) {
      _playDominoSound();
    }

    tile.owner = playerIndex;
    tile.playOrder = playOrderCounter++;

    _stopTurnTimer();

    int winningLimit = widget.gameMode == 'multiplier' ? 100 : winningScore;

    setState(() {
      if (board.isEmpty) {
        leftEnd = tile.sideA;
        rightEnd = tile.sideB;
        rootIndex = 0;
        board.add(tile);

        // Check first tile score in Multiplier Mode
        if (widget.gameMode == 'multiplier') {
          int sum = tile.sideA + tile.sideB;
          if (sum > 0 && sum % 5 == 0) {
            playerScores[playerIndex] += sum;
            statusMessage =
                "🎉 نقاط: +$sum (المجموع: ${playerScores[playerIndex]}) 🎉";
          }
          if (tile.isDouble) {
            spinner = tile;
            upEnd = tile.sideA;
            downEnd = tile.sideA;
          }
        }
      } else {
        bool played = false;
        // Logic for 4-way play in multiplier mode
        if (widget.gameMode == 'multiplier' && spinner != null) {
          if (playOnUp && (tile.sideA == upEnd || tile.sideB == upEnd)) {
            _addTileToUp(tile);
            played = true;
          } else if (playOnDown &&
              (tile.sideA == downEnd || tile.sideB == downEnd)) {
            _addTileToDown(tile);
            played = true;
          }
        }

        if (!played) {
          bool canLeft = (tile.sideA == leftEnd || tile.sideB == leftEnd);
          bool canRight = (tile.sideA == rightEnd || tile.sideB == rightEnd);

          if (playOnLeft && canLeft) {
            if (tile.sideB == leftEnd) {
              tile.isReversed = false;
              leftEnd = tile.sideA;
            } else {
              tile.isReversed = true;
              leftEnd = tile.sideB;
            }
            board.insert(0, tile);
            rootIndex++;
          } else if (canRight) {
            if (tile.sideA == rightEnd) {
              tile.isReversed = false;
              rightEnd = tile.sideB;
            } else {
              tile.isReversed = true;
              rightEnd = tile.sideA;
            }
            board.add(tile);
          }

          if (widget.gameMode == 'multiplier' &&
              tile.isDouble &&
              spinner == null) {
            spinner = tile;
            upEnd = tile.sideA;
            downEnd = tile.sideA;
          }
        }
      }

      // Calculate All Fives Score
      if (widget.gameMode == 'multiplier') {
        _checkAllFivesScoring(playerIndex);
      }

      playersHands[playerIndex].remove(tile);
      selectedTile = null;

      if (playerScores[playerIndex] >= winningLimit) {
        isGameOver = true;
      }
    });

    bool handEmpty = playersHands[playerIndex].isEmpty;
    if (handEmpty || isGameOver) {
      if (_isOnline) {
        _pushStateToFirebase();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 220), () {
          if (!mounted) return;
          _handleRoundEnd(playerIndex);
        });
      });
    } else {
      _nextTurn();
      if (_isOnline) {
        _pushStateToFirebase();
      }
    }
  }

  int _calculatePotentialScore({
    int? nextLeft,
    int? nextRight,
    int? nextUp,
    int? nextDown,
  }) {
    int sum = 0;
    if (nextLeft != null)
      sum += nextLeft;
    else if (leftEnd != null)
      sum += leftEnd!;

    if (nextRight != null)
      sum += nextRight;
    else if (rightEnd != null)
      sum += rightEnd!;

    if (nextUp != null)
      sum += nextUp;
    else if (upEnd != null)
      sum += upEnd!;

    if (nextDown != null)
      sum += nextDown;
    else if (downEnd != null)
      sum += downEnd!;

    return (sum > 0 && sum % 5 == 0) ? sum : 0;
  }

  void _checkAllFivesScoring(int playerIndex) {
    int sum = 0;

    // Check all 4 potential ends
    if (leftEnd != null) sum += leftEnd!;
    if (rightEnd != null) sum += rightEnd!;
    if (upEnd != null) sum += upEnd!;
    if (downEnd != null) sum += downEnd!;

    // In many rules, a double at an end counts for its full sum
    // (though in simplified versions it's just the side value)
    // The user's rule "طرف بياض والطرف الاخر اصبح خمسه" implies 0 + 5 = 5

    if (sum > 0 && sum % 5 == 0) {
      playerScores[playerIndex] += sum;
      statusMessage =
          "🎉 نقاط: +$sum (المجموع: ${playerScores[playerIndex]}) 🎉";

      // Also check if game finished
      if (playerScores[playerIndex] >= 100) {
        setState(() {
          isGameOver = true;
          statusMessage = "🎉 فاز اللاعب ${playerIndex + 1} بالمباراة! 🎉";
        });
      }
    }
  }

  void _addTileToUp(DominoTile tile) {
    if (tile.sideA == upEnd) {
      tile.isReversed = true;
      upEnd = tile.sideB;
    } else {
      tile.isReversed = false;
      upEnd = tile.sideA;
    }
    upBranch.add(tile);
  }

  void _addTileToDown(DominoTile tile) {
    if (tile.sideA == downEnd) {
      tile.isReversed = false;
      downEnd = tile.sideB;
    } else {
      tile.isReversed = true;
      downEnd = tile.sideA;
    }
    downBranch.add(tile);
  }

  void _nextTurn() {
    if (isGameOver || _isShowingRoundOverDialog) return;

    if (playersHands[currentPlayer].isEmpty) {
      _handleRoundEnd(currentPlayer);
      return;
    }

    if (_isGameBlocked()) {
      _handleBlockedGame();
      return;
    }

    setState(() {
      selectedTile = null;
      currentPlayer = (currentPlayer + 1) % playersHands.length;
      statusMessage = "دور اللاعب ${currentPlayer + 1}";
    });

    _startTurnTimer();
    if (_isOnline) {
      // In online mode, we wait for Firebase updates if it's not our turn.
      // But if it IS our turn, we must check if we can play or need to draw.
      if (currentPlayer == _myPlayerIndex) {
        bool hasPlayable = playersHands[currentPlayer].any(
          (t) => canPlayTile(t),
        );
        if (!hasPlayable) {
          if (boneyard.isEmpty) {
            setState(() => statusMessage = "لا تملك لعباً! تخطي تلقائي...");
            Future.delayed(const Duration(milliseconds: 2000), () {
              if (mounted && currentPlayer == _myPlayerIndex) {
                _nextTurn();
                _pushStateToFirebase();
              }
            });
          } else {
            // Auto draw in online mode
            setState(() => statusMessage = "جاري السحب تلقائياً...");
            Future.delayed(
              const Duration(milliseconds: 800),
              _autoDrawForHuman,
            );
          }
        }
      }
    } else if (currentPlayer == 1) {
      Future.delayed(const Duration(milliseconds: 1500), _playAITurn);
    } else {
      // تفقد إمكانية اللعب للاعب البشري (سحب تلقائي سريع)
      bool hasPlayable = playersHands[0].any((t) => canPlayTile(t));
      if (!hasPlayable) {
        if (boneyard.isNotEmpty) {
          setState(() => statusMessage = "جاري السحب حتى تجد قطعة...");
          Future.delayed(const Duration(milliseconds: 500), _autoDrawForHuman);
        } else {
          setState(() => statusMessage = "لا تملك لعباً! تخطي تلقائي...");
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && currentPlayer == 0) _nextTurn();
          });
        }
      }
    }
  }

  void _autoDrawForHuman({bool forceOpponent = false}) {
    if (isGameOver || _isShowingRoundOverDialog || !mounted) {
      _isAutoDrawing = false;
      return;
    }

    // Safety guard: only execute auto-draw / turn-skipping for the local player on their own turn.
    // This prevents concurrent drawing or skipping loops on different devices.
    if (currentPlayer != _myPlayerIndex && !forceOpponent) {
      _isAutoDrawing = false;
      return;
    }

    // If an auto-draw loop is already in progress, guard against creating concurrent loops
    if (_isAutoDrawing) return;

    if (playersHands[currentPlayer].any((t) => canPlayTile(t))) {
      _isAutoDrawing = false;
      setState(
        () => statusMessage = forceOpponent
            ? "سحب الخصم قطعة"
            : "تم العثور على قطعة! دورك الآن.",
      );
      if (_isOnline) _pushStateToFirebase();
      return;
    }

    if (boneyard.isNotEmpty) {
      _isAutoDrawing = true;
      setState(() => _drawTile(isManual: false));

      // Draw card by card at a regular, paced speed (1000ms delay)
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _isAutoDrawing = false;
          _autoDrawForHuman(forceOpponent: forceOpponent);
        }
      });
    } else {
      _isAutoDrawing = false;
      _nextTurn();
      if (_isOnline) _pushStateToFirebase();
    }
  }

  bool _isGameBlocked() {
    if (boneyard.isNotEmpty) return false;
    for (var hand in playersHands) {
      if (hand.any((t) => canPlayTile(t))) {
        return false;
      }
    }
    return true;
  }

  void _handleBlockedGame() {
    int p0Points = _handPipTotal(playersHands[0]);
    int p1Points = _handPipTotal(playersHands[1]);

    int winnerIndex;
    int points;

    if (p0Points < p1Points) {
      winnerIndex = 0;
      points = widget.gameMode == 'multiplier'
          ? p1Points
          : (p1Points - p0Points);
    } else if (p1Points < p0Points) {
      winnerIndex = 1;
      points = widget.gameMode == 'multiplier'
          ? p0Points
          : (p0Points - p1Points);
    } else {
      // Tie -> let's say the one with fewer tiles or just tied 0 points.
      winnerIndex = -1;
      points = 0;
    }

    setState(() {
      int limit = widget.gameMode == 'multiplier' ? 100 : winningScore;
      if (winnerIndex >= 0) {
        playerScores[winnerIndex] += points;
      }
      if (winnerIndex >= 0 && playerScores[winnerIndex] >= limit) {
        statusMessage =
            "🎉 فاز اللاعب ${winnerIndex + 1} بالمباراة النتيجة (${playerScores[winnerIndex]}) 🎉";
        isGameOver = true;
      } else {
        statusMessage =
            "🔒 اللعبة مقفلة! فاز اللاعب ${winnerIndex + 1} بفارق $points نقطة 🎉";
      }
    });

    if (_isOnline) {
      final updates = <String, dynamic>{};
      updates['state/playerScores'] = playerScores;
      updates['state/isGameOver'] = isGameOver;
      updates['state/lastRoundStatus'] = {
        'winnerIndex': winnerIndex,
        'roundPoints': points,
        'isRoundOver': true,
        'isGameFinished': isGameOver,
        'isBlocked': true,
      };
      DominoService().updateGameState(_roomId!, updates);
    }
    _isShowingRoundOverDialog = true;

    _showBlockedGameDialog(winnerIndex, points, p0Points, p1Points, isGameOver);
  }

  void _showBlockedGameDialog(
    int winnerIndex,
    int points,
    int p0Points,
    int p1Points,
    bool isGameFinished,
  ) {
    if (isGameFinished && winnerIndex >= 0) {
      _showGameOverDialog(winnerIndex);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _RoundOverDialog(
          roundNumber: roundNumber,
          winnerIndex: winnerIndex,
          roundPoints: points,
          playerScores: playerScores,
          playersHands: playersHands,
          currentUser: _currentUser,
          isGameFinished: isGameFinished,
          isBlocked: true,
          betAmount: widget.betAmount,
          gameMode: widget.gameMode,
          playerCount: widget.playerCount,
          playerNames: _playerNames,
          playerPhotos: _playerPhotos,
          myPlayerIndex: _myPlayerIndex,
          overrideMessage: winnerIndex < 0
              ? "الجولة مقفلة والنتيجة تعادل، لا تُحتسب نقاط."
              : "انتهت الجولة بالقفل، والفائز يحصل على فارق النقاط فقط.",
          onContinue: () {
            _isShowingRoundOverDialog = false;
            _initializeGame(
              resetScores: isGameFinished,
              startingPlayer: winnerIndex,
            );
          },
        );
      },
    );
  }

  void _handleRoundEnd(int winnerIndex) {
    if (_isShowingRoundOverDialog) return;

    _stopTurnTimer();
    int points = 0;
    for (int i = 0; i < playersHands.length; i++) {
      if (i != winnerIndex) {
        for (var tile in playersHands[i]) {
          points += tile.sideA + tile.sideB;
        }
      }
    }

    setState(() {
      int limit = widget.gameMode == 'multiplier' ? 100 : winningScore;
      playerScores[winnerIndex] += points;

      if (playerScores[winnerIndex] >= limit) {
        statusMessage =
            "🎉 فاز اللاعب ${winnerIndex + 1} بالمباراة النتيجة (${playerScores[winnerIndex]}) 🎉";
        isGameOver = true;
      } else {
        statusMessage =
            "🎉 فاز اللاعب ${winnerIndex + 1} بهذه الجولة (+$points نقطة) 🎉";
      }
    });

    if (_isOnline) {
      final updates = <String, dynamic>{};
      updates['state/playerScores'] = playerScores;
      updates['state/isGameOver'] = isGameOver;
      updates['state/lastRoundStatus'] = {
        'winnerIndex': winnerIndex,
        'roundPoints': points,
        'isRoundOver': true,
        'isGameFinished': isGameOver,
      };
      DominoService().updateGameState(_roomId!, updates);

      // Fallback: If host is sleeping, guest forces start after 8 seconds
      if (_myPlayerIndex != 0) {
        Future.delayed(const Duration(seconds: 8), () {
          if (mounted && _isShowingRoundOverDialog) {
            _isShowingRoundOverDialog = false;
            try {
              Navigator.of(context, rootNavigator: true).pop();
            } catch (_) {}
            _initializeGame(
              resetScores: isGameOver,
              startingPlayer: winnerIndex,
              forceAsHost: true,
            );
          }
        });
      }
    }

    if (isGameOver) {
      _showGameOverDialog(winnerIndex);
    } else {
      _showRoundOverDialog(winnerIndex, points, isGameOver);
    }
  }

  void _showRoundOverDialog(
    int winnerIndex,
    int points,
    bool isGameFinished, {
    bool isRemote = false,
  }) {
    if (_isShowingRoundOverDialog && !isGameFinished && !isRemote) return;
    if (!isGameFinished) _isShowingRoundOverDialog = true;
    if (isGameFinished) {
      _isShowingRoundOverDialog =
          false; // Reset flag to avoid popping screen in _showGameOverDialog
      _showGameOverDialog(winnerIndex);
      return;
    }
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return _RoundOverDialog(
            roundNumber: roundNumber,
            winnerIndex: winnerIndex,
            roundPoints: points,
            playerScores: playerScores,
            playersHands: playersHands,
            currentUser: _currentUser,
            isGameFinished: isGameFinished,
            isBlocked: false,
            betAmount: widget.betAmount,
            gameMode: widget.gameMode,
            playerCount: widget.playerCount,
            playerNames: _playerNames,
            playerPhotos: _playerPhotos,
            myPlayerIndex: _myPlayerIndex,
            onContinue: () {
              _isShowingRoundOverDialog = false;
              _initializeGame(
                resetScores: isGameFinished,
                startingPlayer: winnerIndex,
              );
            },
          );
        },
      );
    });
  }

  Future<void> _showGameOverDialog(int winnerIndex, {String? message}) async {
    if (_isShowingGameOverDialog) return;
    _isShowingGameOverDialog = true;

    // Update Stats for all online players (Each player updates their own stats)
    if (_isOnline && !_hasUpdatedStats) {
      _hasUpdatedStats = true;
      final myUid = fbauth.FirebaseAuth.instance.currentUser?.uid;
      if (myUid != null) {
        bool iWon = false;
        if (widget.playerCount == 2) {
          iWon = (winnerIndex == _myPlayerIndex);
        } else {
          // Team game: 0&2 vs 1&3
          iWon = (winnerIndex % 2 == _myPlayerIndex % 2);
        }

        final statsData = {
          'gamesPlayed': FieldValue.increment(1),
          'wins': FieldValue.increment(iWon ? 1 : 0),
          'losses': FieldValue.increment(iWon ? 0 : 1),
          'gameStats.domino.played': FieldValue.increment(1),
          'gameStats.domino.wins': FieldValue.increment(iWon ? 1 : 0),
          'gameStats.domino.losses': FieldValue.increment(iWon ? 0 : 1),
        };

        UserService().updateUser(uid: myUid, data: statsData).catchError((e) {
          debugPrint('[DominoStats] Update error: $e');
        });
      }
    }

    // Award prize to the winner in online mode
    if (_isOnline && !_hasReceivedWinnings && winnerIndex == _myPlayerIndex) {
      _hasReceivedWinnings = true;
      final int prize = (widget.betAmount * 1.8).toInt();
      final myUid = fbauth.FirebaseAuth.instance.currentUser?.uid;
      if (myUid != null) {
        UserService()
            .updateUser(
              uid: myUid,
              data: {'coins': FieldValue.increment(prize)},
            )
            .then((_) {
              debugPrint('[DominoWin] Awarded prize of $prize to winner.');
            })
            .catchError((e) => debugPrint('[DominoWin] Award error: $e'));
      }
    }

    // If a round over dialog was already showing, close it first.
    if (_isShowingRoundOverDialog) {
      _isShowingRoundOverDialog = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    Future.delayed(Duration.zero, () async {
      if (!mounted) return;

      final bool? result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.85),
        builder: (context) {
          return _GameOverDialog(
            winnerIndex: winnerIndex,
            playerScores: playerScores,
            currentUser: _currentUser,
            myPlayerIndex: _myPlayerIndex,
            betAmount: widget.betAmount,
            gameMode: widget.gameMode,
            playerCount: widget.playerCount,
            playerNames: _playerNames,
            playerPhotos: _playerPhotos,
            message: message,
            onPlayAgain: () =>
                Navigator.of(context, rootNavigator: true).pop(true),
            onExit: () => Navigator.of(context, rootNavigator: true).pop(false),
          );
        },
      );

      if (mounted) {
        if (result == true) {
          _isShowingGameOverDialog = false; // Reset only if playing again
          _handlePlayAgain();
        } else {
          // Properly exit back to the lobby (Bet Selection)
          if (_roomId != null) {
            DominoService().leaveRoom(_roomId!);
          }
          if (mounted) {
            // Use this.context to ensure we are popping the screen's navigator
            Navigator.of(this.context).pop();
          }
        }
      }
    });
  }

  Future<void> _handlePlayAgain() async {
    if (_isOnline) {
      // In online mode, we need to find a new room
      setState(() {
        _isMatchmaking = true;
        isGameOver = false;
        _roomId = null;
        board.clear();
        playersHands = [[], []];
        playerScores = List.generate(widget.playerCount, (_) => 0);
        roundNumber = 1;
        _isShowingRoundOverDialog = false;
        _hasReceivedWinnings = false;
        _hasUpdatedStats = false;
      });

      _roomSubscription?.cancel();

      try {
        // Refresh room joining
        final newRoomId = await DominoService().joinOrCreateRoom(
          betAmount: widget.betAmount,
          gameMode: widget.gameMode,
          name: _currentUser?.nickname ?? _currentUser?.username,
          photo: _currentUser?.profileImage,
        );

        if (mounted) {
          _initOnlineGame(newRoomId);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("ÙØ´Ù„ ÙÙŠ Ø§Ù„Ø§Ù†Ø¶Ù…Ø§Ù… Ù„Ù„Ø¹Ø¨Ø©: $e"),
            ),
          );
        }
      }
    } else {
      _initializeGame(resetScores: true);
    }
  }

  void _showStickers(int playerIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StickerSelectionBottomSheet(
        onSelect: (stickerId) {
          if (_isOnline) {
            DominoService().updateGameState(_roomId!, {
              'state/stickers/$playerIndex': stickerId,
            });
            DominoService().sendInteraction(_roomId!, 'sticker', stickerId);
          }

          // Apply locally for instant feedback
          setState(() {
            _activeStickers[playerIndex] = stickerId;
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _activeStickers[playerIndex] = null;
              });
            }
          });
        },
      ),
    );
  }

  void _showOpponentProfile(int index) {
    final uid = _playerUids[index];
    if (uid == null) return;

    DominoPlayerProfileBottomSheet.show(
      context,
      uid: uid,
      name: _playerNames[index] ?? "لاعب ${index + 1}",
      photo: _playerPhotos[index],
      isMuted: _mutedUserUids.contains(uid),
      onMuteChanged: (isMuted) {
        setState(() {
          if (isMuted) {
            _mutedUserUids.add(uid);
          } else {
            _mutedUserUids.remove(uid);
          }
        });
        // ÙƒØªÙ…/Ø¥Ù„ØºØ§Ø¡ ÙƒØªÙ… Ø§Ù„Ø¨Ø« Ø§Ù„ØµÙˆØªÙŠ Ø§Ù„ÙØ¹Ù„ÙŠ Ù…Ø­Ù„ÙŠØ§Ù‹ Ø¹Ø¨Ø± Agora
        final agoraUid = VoiceRoomService.getAgoraUid(uid);
        if (agoraUid != 0) {
          final voiceService = Provider.of<VoiceRoomService>(
            context,
            listen: false,
          );
          voiceService.muteRemoteAudioStreamLocally(agoraUid, isMuted);
        }
      },
      onSendMessage: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => ChatScreen(
              receiverId: uid,
              receiverName: _playerNames[index] ?? "لاعب ${index + 1}",
              receiverImage: _playerPhotos[index],
            ),
          ),
        );
      },
    );
  }

  void _playAITurn() {
    if (playersHands[1].isEmpty || currentPlayer != 1) return;

    for (var tile in playersHands[1]) {
      if (canPlayTile(tile)) {
        bool onLeft = tile.sideA == leftEnd || tile.sideB == leftEnd;

        if (widget.gameMode == 'multiplier' && spinner != null) {
          bool onUp = tile.sideA == upEnd || tile.sideB == upEnd;
          bool onDown = tile.sideA == downEnd || tile.sideB == downEnd;

          if (onUp) {
            playTile(1, tile, playOnUp: true);
            return;
          }
          if (onDown) {
            playTile(1, tile, playOnDown: true);
            return;
          }
        }

        if (onLeft) {
          playTile(1, tile, playOnLeft: true);
        } else {
          playTile(1, tile, playOnLeft: false);
        }
        return;
      }
    }

    if (boneyard.isNotEmpty) {
      _drawTile();
      Future.delayed(const Duration(milliseconds: 1000), _playAITurn);
    } else {
      _nextTurn();
    }
  }

  void _drawTile({bool isManual = true}) {
    if (isManual && currentPlayer == _myPlayerIndex) {
      _isAutoPlay = false;
    }
    if (_isOnline && currentPlayer != _myPlayerIndex) {
      // Allow drawing if substituting for an offline player
    }
    if (boneyard.isEmpty) return;
    setState(() {
      playersHands[currentPlayer].add(boneyard.removeLast());
    });

    if (_isOnline) {
      _pushStateToFirebase();
    }
  }

  List<TilePlacement> _calculateLayout(double maxWidth) {
    if (board.isEmpty) return [];

    List<TilePlacement> placements = [];
    double startX = 0.0;
    double startY = 0.0;
    // Use the correctly tracked rootIndex from state
    DominoTile rootTile = board[rootIndex];
    double rootCx = startX;
    double rootCy = startY;

    // In Multiplier mode, the spinner is HORIZONTAL (3 turns), just like non-doubles on a horizontal chain.
    bool tIsSpinner(DominoTile t) =>
        widget.gameMode == 'multiplier' && t == spinner;
    int rootTurns = (rootTile.isDouble && !tIsSpinner(rootTile)) ? 0 : 3;

    placements.add(
      TilePlacement(rootTile, rootCx, rootCy, rootTurns, rootIndex),
    );

    double length(DominoTile t) => (t.isDouble && !tIsSpinner(t)) ? tW : tH;

    double cpX = startX + length(rootTile) / 2;
    double cpY = startY;
    int dir = 1; // RIGHT
    double maxExtent = (maxWidth * 0.8).clamp(280.0, 400.0);
    double lastTurnX = cpX;
    double lastTurnY = cpY;

    // Build FORWARDS
    for (int i = rootIndex + 1; i < board.length; i++) {
      DominoTile t = board[i];
      int newDir = dir;

      if (dir == 2 && (cpY - lastTurnY) > maxExtent) {
        newDir = 1;
      } else if (dir == 1 && (cpX - lastTurnX) > maxExtent) {
        newDir = 0;
      } else if (dir == 0 && (cpY - lastTurnY) < -maxExtent) {
        newDir = 3;
      } else if (dir == 3 && (cpX - lastTurnX) < -maxExtent) {
        newDir = 2;
      }

      if (newDir != dir) {
        DominoTile prevTile = board[i - 1];
        double halfThick = prevTile.isDouble ? tH / 2 : tW / 2;

        if (dir == 0)
          cpY += tW / 2;
        else if (dir == 1)
          cpX -= tW / 2;
        else if (dir == 2)
          cpY -= tW / 2;
        else if (dir == 3)
          cpX += tW / 2;

        if (newDir == 0)
          cpY -= halfThick;
        else if (newDir == 1)
          cpX += halfThick;
        else if (newDir == 2)
          cpY += halfThick;
        else if (newDir == 3)
          cpX -= halfThick;

        dir = newDir;
        lastTurnX = cpX;
        lastTurnY = cpY;
      }

      double dx = 0, dy = 0;
      if (dir == 0)
        dy = -1;
      else if (dir == 1)
        dx = 1;
      else if (dir == 2)
        dy = 1;
      else if (dir == 3)
        dx = -1;

      double len = length(t);
      double cx = cpX + dx * len / 2;
      double cy = cpY + dy * len / 2;

      int turns = 0;
      if (t.isDouble && !tIsSpinner(t)) {
        turns = (dir == 0 || dir == 2) ? 1 : 0;
      } else {
        if (dir == 0)
          turns = 2;
        else if (dir == 1)
          turns = 3;
        else if (dir == 2)
          turns = 0;
        else if (dir == 3)
          turns = 1;
      }

      placements.add(TilePlacement(t, cx, cy, turns, i));
      cpX += dx * len;
      cpY += dy * len;
    }

    if (selectedTile != null &&
        (selectedTile!.sideA == rightEnd || selectedTile!.sideB == rightEnd)) {
      int tDir = dir;
      double tCpX = cpX;
      double tCpY = cpY;
      int newDir = tDir;
      if (tDir == 2 && (tCpY - lastTurnY) > maxExtent)
        newDir = 1;
      else if (tDir == 1 && (tCpX - lastTurnX) > maxExtent)
        newDir = 0;
      else if (tDir == 0 && (tCpY - lastTurnY) < -maxExtent)
        newDir = 3;
      else if (tDir == 3 && (tCpX - lastTurnX) < -maxExtent)
        newDir = 2;

      if (newDir != tDir) {
        double halfThick = board.last.isDouble ? tH / 2 : tW / 2;
        if (tDir == 0)
          tCpY += tW / 2;
        else if (tDir == 1)
          tCpX -= tW / 2;
        else if (tDir == 2)
          tCpY -= tW / 2;
        else if (tDir == 3)
          tCpX += tW / 2;
        if (newDir == 0)
          tCpY -= halfThick;
        else if (newDir == 1)
          tCpX += halfThick;
        else if (newDir == 2)
          tCpY += halfThick;
        else if (newDir == 3)
          tCpX -= halfThick;
        tDir = newDir;
      }
      double dx = 0, dy = 0;
      if (tDir == 0)
        dy = -1;
      else if (tDir == 1)
        dx = 1;
      else if (tDir == 2)
        dy = 1;
      else if (tDir == 3)
        dx = -1;
      double len = selectedTile!.isDouble ? tW : tH;
      double cx = tCpX + dx * len / 2;
      double cy = tCpY + dy * len / 2;
      int turns = 0;
      if (selectedTile!.isDouble && !tIsSpinner(selectedTile!)) {
        turns = (tDir == 0 || tDir == 2) ? 1 : 0;
      } else {
        if (tDir == 0)
          turns = 2;
        else if (tDir == 1)
          turns = 3;
        else if (tDir == 2)
          turns = 0;
        else if (tDir == 3)
          turns = 1;
      }
      placements.add(
        TilePlacement(
          selectedTile!,
          cx,
          cy,
          turns,
          board.length,
          isPreview: true,
          isLeftPreview: false,
          potentialScore: widget.gameMode == 'multiplier'
              ? _calculatePotentialScore(
                  nextRight: selectedTile!.sideA == rightEnd
                      ? selectedTile!.sideB
                      : selectedTile!.sideA,
                )
              : 0,
        ),
      );
    }

    // Build BACKWARDS
    cpX = startX - length(rootTile) / 2;
    cpY = startY;
    dir = 3; // LEFT
    lastTurnX = cpX;
    lastTurnY = cpY;

    for (int i = rootIndex - 1; i >= 0; i--) {
      DominoTile t = board[i];
      int newDir = dir;

      if (dir == 0 && (cpY - lastTurnY) < -maxExtent) {
        newDir = 3;
      } else if (dir == 3 && (cpX - lastTurnX) < -maxExtent) {
        newDir = 2;
      } else if (dir == 2 && (cpY - lastTurnY) > maxExtent) {
        newDir = 1;
      } else if (dir == 1 && (cpX - lastTurnX) > maxExtent) {
        newDir = 0;
      }

      if (newDir != dir) {
        DominoTile prevTile = board[i + 1];
        double halfThick = prevTile.isDouble ? tH / 2 : tW / 2;

        if (dir == 0)
          cpY += tW / 2;
        else if (dir == 1)
          cpX -= tW / 2;
        else if (dir == 2)
          cpY -= tW / 2;
        else if (dir == 3)
          cpX += tW / 2;

        if (newDir == 0)
          cpY -= halfThick;
        else if (newDir == 1)
          cpX += halfThick;
        else if (newDir == 2)
          cpY += halfThick;
        else if (newDir == 3)
          cpX -= halfThick;

        dir = newDir;
        lastTurnX = cpX;
        lastTurnY = cpY;
      }

      double dx = 0, dy = 0;
      if (dir == 0)
        dy = -1;
      else if (dir == 1)
        dx = 1;
      else if (dir == 2)
        dy = 1;
      else if (dir == 3)
        dx = -1;

      double len = length(t);
      double cx = cpX + dx * len / 2;
      double cy = cpY + dy * len / 2;

      int turns = 0;
      if (t.isDouble && !tIsSpinner(t)) {
        turns = (dir == 0 || dir == 2) ? 1 : 0;
      } else {
        if (dir == 0)
          turns = 0;
        else if (dir == 1)
          turns = 1;
        else if (dir == 2)
          turns = 2;
        else if (dir == 3)
          turns = 3;
      }

      placements.add(TilePlacement(t, cx, cy, turns, i));
      cpX += dx * len;
      cpY += dy * len;
    }

    if (selectedTile != null &&
        (selectedTile!.sideA == leftEnd || selectedTile!.sideB == leftEnd)) {
      int tDir = dir;
      double tCpX = cpX;
      double tCpY = cpY;
      int newDir = tDir;
      if (tDir == 0 && (tCpY - lastTurnY) < -maxExtent)
        newDir = 3;
      else if (tDir == 3 && (tCpX - lastTurnX) < -maxExtent)
        newDir = 2;
      else if (tDir == 2 && (tCpY - lastTurnY) > maxExtent)
        newDir = 1;
      else if (tDir == 1 && (tCpX - lastTurnX) > maxExtent)
        newDir = 0;

      if (newDir != tDir) {
        double halfThick = board.first.isDouble ? tH / 2 : tW / 2;
        if (tDir == 0)
          tCpY += tW / 2;
        else if (tDir == 1)
          tCpX -= tW / 2;
        else if (tDir == 2)
          tCpY -= tW / 2;
        else if (tDir == 3)
          tCpX += tW / 2;
        if (newDir == 0)
          tCpY -= halfThick;
        else if (newDir == 1)
          tCpX += halfThick;
        else if (newDir == 2)
          tCpY += halfThick;
        else if (newDir == 3)
          tCpX -= halfThick;
        tDir = newDir;
      }
      double dx = 0, dy = 0;
      if (tDir == 0)
        dy = -1;
      else if (tDir == 1)
        dx = 1;
      else if (tDir == 2)
        dy = 1;
      else if (tDir == 3)
        dx = -1;
      double len = selectedTile!.isDouble ? tW : tH;
      double cx = tCpX + dx * len / 2;
      double cy = tCpY + dy * len / 2;
      int turns = 0;
      if (selectedTile!.isDouble && !tIsSpinner(selectedTile!)) {
        turns = (tDir == 0 || tDir == 2) ? 1 : 0;
      } else {
        if (tDir == 0)
          turns = 0;
        else if (tDir == 1)
          turns = 1;
        else if (tDir == 2)
          turns = 2;
        else if (tDir == 3)
          turns = 3;
      }
      placements.add(
        TilePlacement(
          selectedTile!,
          cx,
          cy,
          turns,
          -1,
          isPreview: true,
          isLeftPreview: true,
          potentialScore: widget.gameMode == 'multiplier'
              ? _calculatePotentialScore(
                  nextLeft: selectedTile!.sideA == leftEnd
                      ? selectedTile!.sideB
                      : selectedTile!.sideA,
                )
              : 0,
        ),
      );
    }

    // 4. MULTIPLIER MODE: BRANCHES (3rd and 4th direction)
    if (widget.gameMode == 'multiplier' && spinner != null) {
      TilePlacement? spinnerPlacement;
      try {
        spinnerPlacement = placements.firstWhere((p) => p.tile == spinner);
      } catch (_) {}

      if (spinnerPlacement != null) {
        double scx = spinnerPlacement.cx;
        double scy = spinnerPlacement.cy;

        // UP Branch
        double buCpX = scx;
        // spinner visual height is tW (40) because it's horizontal
        double buCpY = scy - tW / 2;
        for (var t in upBranch) {
          double loopLen = length(t);
          placements.add(
            TilePlacement(
              t,
              buCpX,
              buCpY - loopLen / 2,
              t.isDouble ? 1 : 0,
              -2,
            ),
          );
          buCpY -= loopLen;
        }
        if (selectedTile != null &&
            (selectedTile!.sideA == upEnd || selectedTile!.sideB == upEnd)) {
          double len = length(selectedTile!);
          placements.add(
            TilePlacement(
              selectedTile!,
              buCpX,
              buCpY - len / 2,
              selectedTile!.isDouble ? 1 : 0,
              -1,
              isPreview: true,
              isUpPreview: true,
              potentialScore: widget.gameMode == 'multiplier'
                  ? _calculatePotentialScore(
                      nextUp: selectedTile!.sideA == upEnd
                          ? selectedTile!.sideB
                          : selectedTile!.sideA,
                    )
                  : 0,
            ),
          );
        }

        // DOWN Branch
        double bdCpX = scx;
        double bdCpY = scy + tW / 2;
        for (var t in downBranch) {
          double loopLen = length(t);
          placements.add(
            TilePlacement(
              t,
              bdCpX,
              bdCpY + loopLen / 2,
              t.isDouble ? 1 : 0,
              -3,
            ),
          );
          bdCpY += loopLen;
        }
        if (selectedTile != null &&
            (selectedTile!.sideA == downEnd ||
                selectedTile!.sideB == downEnd)) {
          double len = length(selectedTile!);
          placements.add(
            TilePlacement(
              selectedTile!,
              bdCpX,
              bdCpY + len / 2,
              selectedTile!.isDouble ? 1 : 0,
              -1,
              isPreview: true,
              isDownPreview: true,
              potentialScore: widget.gameMode == 'multiplier'
                  ? _calculatePotentialScore(
                      nextDown: selectedTile!.sideA == downEnd
                          ? selectedTile!.sideB
                          : selectedTile!.sideA,
                    )
                  : 0,
            ),
          );
        }
      }
    }

    placements.sort((a, b) {
      if (a.isPreview && !b.isPreview) return 1;
      if (!a.isPreview && b.isPreview) return -1;
      return a.tile.playOrder.compareTo(b.tile.playOrder);
    });
    return placements;
  }

  @override
  Widget build(BuildContext context) {
    if (_isMatchmaking) {
      return _buildMatchmakingUI();
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool shouldPop = await _showExitConfirmationDialog() ?? false;
        if (shouldPop && context.mounted) {
          if (_roomId != null) {
            DominoService().leaveRoom(_roomId!);
          }
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: () {
            if (_isAutoPlay) {
              setState(() {
                _isAutoPlay = false;
              });
              _startTurnTimer();
            }
          },
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // Background Table Layer
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/dominoo.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Subtle Pattern Layer (Squares/Grid)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: CustomPaint(painter: _TablePatternPainter()),
                ),
              ),
              SafeArea(
                child: Stack(
                  children: [
                    // Profiles and Hands for other players
                    Column(
                      children: [_buildTopHeader(), const SizedBox(height: 5)],
                    ),

                    if (widget.playerCount == 2) ...[
                      // Opponent Top
                      Positioned(
                        left: 15,
                        top: 70,
                        child: _buildOtherHand(
                          (_myPlayerIndex + 1) % 2,
                          horizontal: true,
                        ),
                      ),
                      Positioned(
                        right: 15,
                        top: 85,
                        child: _buildOtherProfile((_myPlayerIndex + 1) % 2),
                      ),
                    ] else ...[
                      // 4 Players Layout
                      // Player 1 (Right)
                      Positioned(
                        right: 10,
                        top: MediaQuery.of(context).size.height * 0.3,
                        child: Column(
                          children: [
                            _buildOtherProfile((_myPlayerIndex + 1) % 4),
                            const SizedBox(height: 5),
                            _buildOtherHand(
                              (_myPlayerIndex + 1) % 4,
                              horizontal: false,
                            ),
                          ],
                        ),
                      ),
                      // Player 2 (Top)
                      Positioned(
                        left: 15,
                        top: 70,
                        child: _buildOtherHand(
                          (_myPlayerIndex + 2) % 4,
                          horizontal: true,
                        ),
                      ),
                      Positioned(
                        right: 15,
                        top: 85,
                        child: _buildOtherProfile((_myPlayerIndex + 2) % 4),
                      ),
                      // Player 3 (Left)
                      Positioned(
                        left: 10,
                        top: MediaQuery.of(context).size.height * 0.3,
                        child: Column(
                          children: [
                            _buildOtherProfile((_myPlayerIndex + 3) % 4),
                            const SizedBox(height: 5),
                            _buildOtherHand(
                              (_myPlayerIndex + 3) % 4,
                              horizontal: false,
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ساحة اللعب المركزية
                    Positioned.fill(
                      top: 150, // More top padding for the profile
                      bottom: 120,
                      child: board.isEmpty
                          ? const Center(
                              child: Text(
                                '...',
                                style: TextStyle(
                                  color: Colors.white10,
                                  fontSize: 30,
                                ),
                              ),
                            )
                          : Center(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  List<TilePlacement> pts = _calculateLayout(
                                    constraints.maxWidth,
                                  );
                                  double minX = 0, maxX = 0, minY = 0, maxY = 0;
                                  if (pts.isNotEmpty) {
                                    minX = pts.first.cx;
                                    maxX = pts.first.cx;
                                    minY = pts.first.cy;
                                    maxY = pts.first.cy;
                                    for (var pt in pts) {
                                      double rotW = (pt.turns % 2 == 0)
                                          ? tW
                                          : tH;
                                      double rotH = (pt.turns % 2 == 0)
                                          ? tH
                                          : tW;
                                      if (pt.cx - rotW / 2 < minX)
                                        minX = pt.cx - rotW / 2;
                                      if (pt.cx + rotW / 2 > maxX)
                                        maxX = pt.cx + rotW / 2;
                                      if (pt.cy - rotH / 2 < minY)
                                        minY = pt.cy - rotH / 2;
                                      if (pt.cy + rotH / 2 > maxY)
                                        maxY = pt.cy + rotH / 2;
                                    }
                                  }
                                  // Symmetric Scaling:
                                  // We calculate a box that is perfectly symmetric around the root (0,0).
                                  // This ensures the root tile stays at the exact pixel center of the container.
                                  double boardW = maxX - minX;
                                  double boardH = maxY - minY;
                                  double centerX = (minX + maxX) / 2;
                                  double centerY = (minY + maxY) / 2;

                                  double containerW = constraints.maxWidth;
                                  double containerH = constraints.maxHeight;

                                  // Give some padding around the actual tiles
                                  double padding = 80.0;
                                  double fitScale = math.min(
                                    containerW / (boardW + padding),
                                    containerH / (boardH + padding),
                                  );
                                  if (fitScale > 1.2)
                                    fitScale =
                                        1.2; // Allow slightly larger than original
                                  if (fitScale < 0.1) fitScale = 0.1;

                                  // Stable virtual coordinate system center
                                  const double vCenter = 5000.0;
                                  const double vSize = 10000.0;

                                  return InteractiveViewer(
                                    constrained: false,
                                    boundaryMargin: const EdgeInsets.all(2000),
                                    minScale: 0.1,
                                    maxScale: 3.0,
                                    transformationController:
                                        TransformationController(
                                          Matrix4.identity()
                                            ..scale(fitScale)
                                            ..translate(
                                              (containerW / fitScale) / 2 -
                                                  (centerX + vCenter),
                                              (containerH / fitScale) / 2 -
                                                  (centerY + vCenter),
                                            ),
                                        ),
                                    child: SizedBox(
                                      width: vSize,
                                      height: vSize,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: pts.map((tp) {
                                          double rotW = (tp.turns % 2 == 0)
                                              ? tW
                                              : tH;
                                          double rotH = (tp.turns % 2 == 0)
                                              ? tH
                                              : tW;

                                          double cx = tp.cx + vCenter;
                                          double cy = tp.cy + vCenter;

                                          return AnimatedPositioned(
                                            key: ValueKey(
                                              'tile_${tp.tile.playOrder}_${tp.tile.sideA}_${tp.tile.sideB}_${tp.isPreview}_${tp.isLeftPreview}_${tp.isUpPreview}_${tp.isDownPreview}',
                                            ),
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            left: cx - rotW / 2,
                                            top: cy - rotH / 2,
                                            child: tp.isPreview
                                                ? GestureDetector(
                                                    onTap: () {
                                                      playTile(
                                                        _myPlayerIndex,
                                                        selectedTile!,
                                                        playOnLeft:
                                                            tp.isLeftPreview,
                                                        playOnUp:
                                                            tp.isUpPreview,
                                                        playOnDown:
                                                            tp.isDownPreview,
                                                      );
                                                    },
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        RotatedBox(
                                                          quarterTurns:
                                                              tp.turns,
                                                          child:
                                                              _buildDominoWidget(
                                                                tp.tile,
                                                                isBoard: true,
                                                                isHorizontal:
                                                                    false,
                                                                isPreview: true,
                                                              ),
                                                        ),
                                                        if (widget.gameMode ==
                                                                'multiplier' &&
                                                            tp.potentialScore >
                                                                0)
                                                          Positioned(
                                                            top: -12,
                                                            right: -12,
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    4,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .amber[700],
                                                                shape: BoxShape
                                                                    .circle,
                                                                border: Border.all(
                                                                  color: Colors
                                                                      .white,
                                                                  width: 1.5,
                                                                ),
                                                                boxShadow: const [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .black26,
                                                                    blurRadius:
                                                                        3,
                                                                    offset:
                                                                        Offset(
                                                                          0,
                                                                          2,
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                              constraints:
                                                                  const BoxConstraints(
                                                                    minWidth:
                                                                        24,
                                                                    minHeight:
                                                                        24,
                                                                  ),
                                                              alignment:
                                                                  Alignment
                                                                      .center,
                                                              child: Text(
                                                                "${tp.potentialScore}",
                                                                style: GoogleFonts.outfit(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  )
                                                : TweenAnimationBuilder<double>(
                                                    tween: Tween<double>(
                                                      begin: 0.0,
                                                      end: 1.0,
                                                    ),
                                                    duration: const Duration(
                                                      milliseconds: 500,
                                                    ),
                                                    curve: Curves.easeOutCubic,
                                                    builder: (context, val, child) {
                                                      // Calculate the direction the tile should come from
                                                      // relative to the current player's view.
                                                      double dx = 0;
                                                      double dy = 0;
                                                      int owner =
                                                          tp.tile.owner ?? 0;

                                                      if (widget.playerCount ==
                                                          2) {
                                                        if (owner ==
                                                            _myPlayerIndex) {
                                                          dy =
                                                              200; // From bottom
                                                        } else {
                                                          dy = -200; // From top
                                                        }
                                                      } else {
                                                        // 4-player logic
                                                        int rel =
                                                            (owner -
                                                                _myPlayerIndex +
                                                                4) %
                                                            4;
                                                        if (rel == 0)
                                                          dy = 200; // Bottom
                                                        else if (rel == 1)
                                                          dx = 200; // Right
                                                        else if (rel == 2)
                                                          dy = -200; // Top
                                                        else if (rel == 3)
                                                          dx = -200; // Left
                                                      }

                                                      return Transform.translate(
                                                        offset: Offset(
                                                          dx * (1.0 - val),
                                                          dy * (1.0 - val),
                                                        ),
                                                        child: Transform.scale(
                                                          scale:
                                                              0.5 + 0.5 * val,
                                                          child: Opacity(
                                                            opacity: val.clamp(
                                                              0.0,
                                                              1.0,
                                                            ),
                                                            child: child,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: Hero(
                                                      tag:
                                                          'domino_${tp.tile.sideA}_${tp.tile.sideB}',
                                                      child: RotatedBox(
                                                        quarterTurns: tp.turns,
                                                        child:
                                                            _buildDominoWidget(
                                                              tp.tile,
                                                              isBoard: true,
                                                              isHorizontal:
                                                                  false,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),

                    // معلومات اللاعب (أسفل اليسار)
                    Positioned(
                      bottom: 120,
                      left: 15,
                      child: _buildPlayerProfile(
                        _myPlayerIndex,
                        _currentUser?.nickname ??
                            _currentUser?.username ??
                            "أنت",
                      ),
                    ),

                    // يد اللاعب (في الأسفل)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: _buildPlayerHand(),
                    ),

                    // Draw/Skip Button removed as requested (auto-draw is active)
                    // Positioned(
                    //   bottom: 120,
                    //   right: 20,
                    //   child: _buildDrawSkipButton(),
                    // ),
                    if (_isChatInputOpen)
                      Positioned.fill(child: _buildChatInputPanel()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatInputPanel() {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => _isChatInputOpen = false);
      },
      behavior:
          HitTestBehavior.translucent, // Allow taps through transparent areas
      child: Container(
        color: Colors.transparent, // Allow interaction behind it
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: Container(color: Colors.transparent)),
              Expanded(
                child: GestureDetector(
                  onTap: () {}, // Prevent closing when clicking message area
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF130B2E).withValues(alpha: 0.95),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      border: Border.all(color: Colors.white10, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        // Handle/Top Bar
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Title/Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "الدردشة",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _isChatInputOpen = false),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.amber, // Primary app color
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white12),
                        // Message History (Filtered)
                        Expanded(
                          child: Builder(
                            builder: (ctx) {
                              final chatEntries = _gameLog
                                  .where((e) => e.type == 'chat')
                                  .toList();

                              if (chatEntries.isEmpty) {
                                return const Center(
                                  child: Text(
                                    "لا توجد رسائل بعد",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                controller: _chatScrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                itemCount: chatEntries.length,
                                itemBuilder: (ctx, i) =>
                                    _buildLogRow(chatEntries[i], isLarge: true),
                              );
                            },
                          ),
                        ),
                        // Input Section
                        _buildChatFormSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatFormSection() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0620), // Darker base for input area
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white, // Explicitly white background
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatInputController,
                      style: const TextStyle(
                        color: Colors.black, // Black text for high contrast
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: "اكتب رسالة...",
                        hintStyle: TextStyle(
                          color: Colors.black54,
                          fontFamily: 'Tajawal',
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: (val) => _sendChatMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.sentiment_satisfied_alt,
                      color: Colors.black54, // Dark icon for contrast
                    ),
                    onPressed: () {
                      _showStickers(_myPlayerIndex);
                      setState(() => _isChatInputOpen = false);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendChatMessage,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B4EE0), Color(0xFF9575CD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B4EE0).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendChatMessage() {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    if (_isOnline) {
      DominoService().sendInteraction(_roomId!, 'chat', text);
      setState(() {
        _activeChats[_myPlayerIndex] = text;
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _activeChats[_myPlayerIndex] == text) {
          setState(() => _activeChats[_myPlayerIndex] = null);
        }
      });
    }
    _chatInputController.clear();
    setState(() => _isChatInputOpen = false); // Close window after sending
  }

  Widget _buildLogRow(DominoGameLogEntry entry, {bool isLarge = false}) {
    bool isMe = entry.senderId == fbauth.FirebaseAuth.instance.currentUser?.uid;
    String senderName = "لاعب";
    Color playerColor = Colors.amber; // Default Domino color fallback

    _playerUids.forEach((idx, uid) {
      if (uid == entry.senderId) {
        senderName = _playerNames[idx] ?? "لاعب";
        // Give some color distinction based on index
        if (idx == 0) playerColor = Colors.blueAccent;
        if (idx == 1) playerColor = Colors.redAccent;
        if (idx == 2) playerColor = Colors.greenAccent;
        if (idx == 3) playerColor = Colors.orangeAccent;
      }
    });

    if (isMe) {
      senderName = _currentUser?.nickname ?? _currentUser?.username ?? "أنت";
      playerColor = Colors.cyanAccent;
    }

    String timeLabel = "الآن";
    try {
      final diff = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(entry.timestamp),
      );
      if (diff.inMinutes == 0) {
        timeLabel = "الآن";
      } else if (diff.inMinutes < 60) {
        timeLabel = "قبل ${diff.inMinutes} دقيقة";
      } else {
        timeLabel = "قبل ${diff.inHours} ساعة";
      }
    } catch (e) {}

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Name and Label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: playerColor,
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  senderName,
                  style: TextStyle(
                    color: playerColor,
                    fontWeight: FontWeight.bold,
                    fontSize: isLarge ? 15 : 12,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeLabel,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          ),
          // Message Bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: EdgeInsets.only(left: isMe ? 50 : 0, right: isMe ? 0 : 50),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF00B4DB),
                        Color(0xFF0083B0),
                      ], // Premium Cyan/Blue Gradient
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFF1E2A38),
                        Color(0xFF131B24),
                      ], // Sleek Dark Gradient
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 20),
              ),
              border: Border.all(
                color: isMe
                    ? Colors.cyanAccent.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isMe ? const Color(0xFF0083B0) : Colors.black)
                      .withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    entry.content,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: isLarge ? 17 : 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'الإعدادات',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Mute Toggle
                  ListTile(
                    leading: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.cyanAccent,
                    ),
                    title: Text(
                      'كتم الصوت',
                      style: GoogleFonts.tajawal(color: Colors.white),
                    ),
                    trailing: Switch(
                      value: _isMuted,
                      activeColor: Colors.cyanAccent,
                      onChanged: (val) {
                        setState(() {
                          _isMuted = val;
                          if (_isMuted) {
                            _musicPlayer.pause();
                          } else {
                            _musicPlayer.play();
                          }
                        });
                        _saveMutedPreference(val);
                        setModalState(() {});
                      },
                    ),
                  ),
                  // Microphone Toggle
                  Consumer<VoiceRoomService>(
                    builder: (context, voice, _) {
                      return ListTile(
                        leading: Icon(
                          voice.isGameMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.amberAccent,
                        ),
                        title: Text(
                          'الميكروفون',
                          style: GoogleFonts.tajawal(color: Colors.white),
                        ),
                        trailing: Switch(
                          value: !voice.isGameMuted,
                          activeColor: Colors.amberAccent,
                          onChanged: (val) {
                            voice.setGameMute(!val);
                            setModalState(() {});
                          },
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  // Background Music Volume
                  _buildVolumeSlider(
                    context: context,
                    title: "الموسيقى الخلفية",
                    icon: Icons.music_note,
                    value: _musicVolume,
                    enabled: !_isMuted,
                    onChanged: (val) {
                      setState(() {
                        _musicVolume = val;
                        _musicPlayer.setVolume(_isMuted ? 0.0 : _musicVolume);
                      });
                      setModalState(() {});
                    },
                  ),
                  // Match SFX Volume
                  _buildVolumeSlider(
                    context: context,
                    title: "صوت المباراة (رمي البطاقات)",
                    icon: Icons.casino,
                    value: _sfxVolume,
                    enabled: !_isMuted,
                    onChanged: (val) {
                      setState(() {
                        _sfxVolume = val;
                      });
                      setModalState(() {});
                    },
                  ),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  // Leave Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        _handleManualExit();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'مغادرة المباراة',
                        style: GoogleFonts.tajawal(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVolumeSlider({
    required BuildContext context,
    required String title,
    required IconData icon,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: enabled ? Colors.cyanAccent : Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.tajawal(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${(value * 100).toInt()}%",
                        style: TextStyle(
                          color: enabled ? Colors.cyanAccent : Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.cyanAccent,
                      inactiveTrackColor: Colors.white10,
                      thumbColor: Colors.white,
                      overlayColor: Colors.cyanAccent.withOpacity(0.2),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                    ),
                    child: Slider(
                      value: value,
                      onChanged: enabled ? onChanged : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showExitConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'تأكيد الخروج',
          textAlign: TextAlign.right,
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في الخروج من المباراة؟ سيتم اعتبارك خاسراً وسيتم خصم مبلغ الرهان.',
          textAlign: TextAlign.right,
          style: GoogleFonts.tajawal(color: Colors.white70),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'إلغاء',
                    style: GoogleFonts.tajawal(color: Colors.cyanAccent),
                  ),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                    elevation: 0,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'خروج',
                    style: GoogleFonts.tajawal(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleManualExit() async {
    final bool shouldPop = await _showExitConfirmationDialog() ?? false;
    if (shouldPop && mounted) {
      if (_isOnline && _roomId != null) {
        await DominoService().leaveRoom(_roomId!);
      }
      Navigator.of(context).pop();
    }
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              // Settings, Theme, Shop Icons (Smaller)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSmallHeaderIcon(
                    icon: Icons.settings,
                    onTap: _showSettingsDialog,
                  ),
                ],
              ),
              const Spacer(),
              // Goal Points & Boneyard Count (Combined Premium Capsule)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B2A22), Color(0xFF111E17)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Goal Indicator
                    const Icon(
                      Icons.gps_fixed_rounded,
                      color: Color(0xFFFFD54F),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.gameMode == 'multiplier'
                          ? "100"
                          : winningScore.toString(),
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    // Divider
                    Container(
                      height: 12,
                      width: 1,
                      color: Colors.white24,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    // Draw count (Boneyard)
                    const Icon(
                      Icons.style_rounded,
                      color: Colors.cyanAccent,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${boneyard.length}",
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Currency (Gold & Diamonds) - Compact & Premium Row
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCurrencyDisplay(
                    icon: Icons.monetization_on,
                    value: _currentUser?.coins ?? 0,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  _buildCurrencyDisplay(
                    icon: Icons.diamond,
                    value: _currentUser?.diamonds ?? 0,
                    color: Colors.cyanAccent,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallHeaderIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }

  Widget _buildCurrencyDisplay({
    required IconData icon,
    required int value,
    required Color color,
  }) {
    bool isDiamond = icon == Icons.diamond;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isDiamond
              ? const Icon(
                  Icons.diamond_rounded,
                  color: Colors.cyanAccent,
                  size: 16,
                )
              : Image.asset(
                  'assets/images/drhim.png',
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                ),
          const SizedBox(width: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatCurrency(value),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  Widget _buildOtherProfile(int index) {
    String? photo = _playerPhotos[index];
    String name = _playerNames[index] ?? "لاعب ${index + 1}";

    return GestureDetector(
      onTap: () => _showOpponentProfile(index),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // The bubble floats below the card for opponents
          if (_activeChats[index] != null)
            Positioned(
              top: 83, // Moved slightly further
              child: _buildChatBubbleWidget(
                _activeChats[index]!,
                isOpponent: true,
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFFD4E157),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C4336).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.greenAccent.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: CircleAvatar(
                              backgroundColor: const Color(0xFFFFF176),
                              backgroundImage: photo != null
                                  ? (photo.startsWith('http')
                                        ? NetworkImage(photo)
                                        : AssetImage(photo) as ImageProvider)
                                  : null,
                              child: photo == null
                                  ? const Icon(Icons.face, size: 16)
                                  : null,
                            ),
                          ),
                        ),
                        if (currentPlayer == index)
                          Positioned.fill(
                            child: CircularProgressIndicator(
                              value: _turnProgress,
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _autoPlayPlayers.contains(index)
                                    ? Colors.redAccent
                                    : Colors.greenAccent,
                              ),
                              backgroundColor: Colors.white10,
                            ),
                          ),
                        if (_activeStickers[index] != null)
                          Positioned.fill(
                            child: Center(
                              child: _buildStickerWidget(
                                _activeStickers[index]!,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Consumer<VoiceRoomService>(
                      builder: (context, voice, _) {
                        String? pUid = _playerUids[index];
                        int volumeLevel = pUid != null
                            ? voice.getUserVolume(pUid)
                            : 0;
                        bool isMuted = (_playerVolumes[index] ?? 1.0) == 0.0;
                        return GestureDetector(
                          onTap: () {
                            if (pUid == null) return;
                            double currentVol = _playerVolumes[index] ?? 1.0;
                            bool isMuting = currentVol > 0;
                            setState(() {
                              _playerVolumes[index] = isMuting ? 0.0 : 1.0;
                            });
                            try {
                              int agoraUid = VoiceRoomService.getAgoraUid(pUid);
                              voice.muteRemoteAudioStreamLocally(
                                agoraUid,
                                isMuting,
                              );
                            } catch (e) {
                              print("Error muting opponent: $e");
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                VoiceVolumeMeter(
                                  volumeLevel: volumeLevel,
                                  isMuted: isMuted,
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFD89B54),
                                        Color(0xFF8B511A),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.black87,
                                      width: 1.2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black45,
                                        offset: Offset(0, 1.5),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isMuted
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 55,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2A22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "النقاط",
                            style: TextStyle(color: Colors.white, fontSize: 8),
                          ),
                          Text(
                            "${(index < playerScores.length) ? playerScores[index] : 0}",
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtherHand(int index, {bool horizontal = true}) {
    if (index >= playersHands.length) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: horizontal
          ? Wrap(
              spacing: 2,
              children: playersHands[index]
                  .map((_) => _buildCardBack(16, 24))
                  .toList(),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: playersHands[index]
                  .take(4)
                  .map(
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _buildCardBack(24, 16, rotate: true),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildCardBack(double w, double h, {bool rotate = false}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black12),
      ),
    );
  }

  Widget _buildStickerWidget(String stickerId) {
    final emojiData = StickerSelectionBottomSheet.getEmojiData(stickerId);
    if (emojiData == null) return const SizedBox.shrink();
    return AnimatedEmoji(emojiData, size: 60, repeat: true);
  }

  Widget _buildChatBubbleWidget(String text, {bool isOpponent = false}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150, minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF00B4DB),
            Color(0xFF0083B0),
          ], // Premium Cyan/Blue Gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: Radius.circular(
            isOpponent ? 2 : 16,
          ), // Tail pointing up if opponent
          bottomLeft: const Radius.circular(16),
          bottomRight: Radius.circular(
            isOpponent ? 16 : 2,
          ), // Tail pointing down if me
        ),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0083B0).withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.tajawal(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPlayerProfile(int index, String name) {
    final displayName =
        _currentUser?.nickname ?? _currentUser?.username ?? name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end, // Aligns to left in RTL
      children: [
        // Name outside the box
        Padding(
          padding: const EdgeInsets.only(
            right: 8,
            bottom: 6,
          ), // Padding on far left (right in RTL)
          child: Text(
            displayName,
            style: const TextStyle(
              color: Color(0xFFD4E157), // Yellowish green
              fontSize: 14,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 2,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
        ),
        // Main Container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2C4336).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Score and Actions Column (Renders Right in RTL)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score box
                  Container(
                    width: 90, // fixed width roughly fitting
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2A22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "النقاط",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${playerScores[index]}",
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Action Buttons
                  Row(
                    children: [
                      // Mic Icon
                      Consumer<VoiceRoomService>(
                        builder: (context, voice, _) {
                          bool isMe = index == _myPlayerIndex;
                          bool isTalking = voice.isUserTalking(
                            _playerUids[index],
                          );

                          return _buildSquareActionIcon(
                            isMe
                                ? (voice.isGameMuted
                                      ? Icons.mic_off
                                      : Icons.mic)
                                : (isTalking ? Icons.mic : Icons.mic_off),
                            onTap: isMe
                                ? () => voice.setGameMute(!voice.isGameMuted)
                                : null,
                            color: isTalking
                                ? Colors.greenAccent
                                : (isMe && !voice.isGameMuted
                                      ? Colors.white
                                      : Colors.black54),
                            bgColor: isTalking
                                ? Colors.green.withOpacity(0.5)
                                : (isMe && !voice.isGameMuted
                                      ? Colors.green
                                      : const Color(0xFFB0BEC5)),
                            size: 14,
                            padding: 4,
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      _buildSquareActionIcon(
                        Icons.sentiment_very_satisfied,
                        onTap: () => _showStickers(_myPlayerIndex),
                        color: const Color(0xFF5D4037),
                        bgColor: const Color(0xFFFFCA28),
                        size: 14,
                        padding: 4,
                      ),
                      const SizedBox(width: 4),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildSquareActionIcon(
                            Icons.chat_bubble,
                            onTap: () {
                              setState(() {
                                _isChatInputOpen = !_isChatInputOpen;
                                if (_isChatInputOpen) {
                                  _unreadChatCount = 0;
                                }
                              });
                            },
                            color: const Color(0xFF5D4037),
                            bgColor: const Color(0xFFFFCA28),
                            size: 14,
                            padding: 4,
                          ),
                          if (_unreadChatCount > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  _unreadChatCount > 9
                                      ? '+9'
                                      : '$_unreadChatCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // Avatar with progress and gift (Renders Middle-Left in RTL)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.greenAccent.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(1.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.amber[200],
                        backgroundImage:
                            _currentUser?.profileImage != null &&
                                _currentUser!.profileImage!.isNotEmpty
                            ? (() {
                                String img = _currentUser!.profileImage!;
                                String cleanPath = img
                                    .replaceFirst('file:///', '')
                                    .replaceFirst('file://', '');
                                return cleanPath.startsWith('http')
                                    ? NetworkImage(cleanPath)
                                    : AssetImage(cleanPath) as ImageProvider;
                              })()
                            : null,
                        child:
                            (_currentUser?.profileImage == null ||
                                _currentUser!.profileImage!.isEmpty)
                            ? Icon(
                                Icons.person,
                                color: Colors.blueGrey[800],
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                  ),
                  // Progress Arc Placeholder
                  if (currentPlayer == index)
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        value: _turnProgress,
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isAutoPlay ? Colors.redAccent : Colors.greenAccent,
                        ),
                        backgroundColor: Colors.white10,
                      ),
                    ),
                  // Gift Icon
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.amber[700],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 2),
                        ],
                      ),
                      child: const Icon(
                        Icons.card_giftcard,
                        color: Colors.white,
                        size: 8,
                      ),
                    ),
                  ),
                  if (_activeStickers[_myPlayerIndex] != null)
                    Positioned.fill(
                      child: Center(
                        child: _buildStickerWidget(
                          _activeStickers[_myPlayerIndex]!,
                        ),
                      ),
                    ),
                  if (_activeChats[_myPlayerIndex] != null)
                    Positioned(
                      bottom: 85, // Moved slightly further
                      child: _buildChatBubbleWidget(
                        _activeChats[_myPlayerIndex]!,
                      ),
                    ),
                ],
              ),

              // Real-time voice meter for local player
              Consumer<VoiceRoomService>(
                builder: (context, voice, _) {
                  String? pUid = _playerUids[_myPlayerIndex];
                  int volumeLevel = pUid != null
                      ? voice.getUserVolume(pUid)
                      : 0;
                  bool isMuted = voice.isGameMuted;

                  return GestureDetector(
                    onTap: () {
                      voice.setGameMute(!voice.isGameMuted);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VoiceVolumeMeter(
                            volumeLevel: volumeLevel,
                            isMuted: isMuted,
                          ),
                          const SizedBox(height: 2),
                          // Wooden speaker icon
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFD89B54), Color(0xFF8B511A)],
                              ),
                              border: Border.all(
                                color: Colors.black87,
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  offset: Offset(0, 1.5),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                isMuted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSquareActionIcon(
    IconData icon, {
    VoidCallback? onTap,
    Color? color,
    Color? bgColor,
    double size = 18,
    double padding = 6,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bgColor != null
                ? [
                    bgColor.withValues(alpha: 0.9),
                    bgColor.withValues(alpha: 0.6),
                  ]
                : [const Color(0xFFCFD8DC), const Color(0xFF90A4AE)],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 2,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color ?? Colors.black87, size: size),
      ),
    );
  }

  Widget _buildPlayerHand() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: playersHands[_myPlayerIndex].asMap().entries.map((entry) {
            final index = entry.key;
            final tile = entry.value;
            bool isPlayable =
                currentPlayer == _myPlayerIndex && canPlayTile(tile);
            return GestureDetector(
              key: ValueKey('hand_tile_${tile.sideA}_${tile.sideB}_$index'),
              onTap: () {
                if (currentPlayer == _myPlayerIndex && isPlayable) {
                  if (board.isEmpty) {
                    playTile(_myPlayerIndex, tile, playOnLeft: true);
                    return;
                  }

                  bool canTop = tile.sideA == leftEnd || tile.sideB == leftEnd;
                  bool canBottom =
                      tile.sideA == rightEnd || tile.sideB == rightEnd;

                  if (canTop && canBottom) {
                    setState(() {
                      if (identical(selectedTile, tile)) {
                        selectedTile = null;
                      } else {
                        selectedTile = tile;
                      }
                    });
                  } else {
                    setState(() {
                      selectedTile = null;
                    });
                    playTile(_myPlayerIndex, tile, playOnLeft: canTop);
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(
                    0,
                    identical(selectedTile, tile) ? -10 : 0,
                    0,
                  ),
                  child: _buildDominoWidget(
                    tile,
                    isBoard: false,
                    isPlayable: isPlayable,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDominoWidget(
    DominoTile tile, {
    bool isBoard = false,
    bool isHorizontal = false,
    bool isPlayable = true,
    bool isPreview = false,
  }) {
    double w = isBoard ? tW : 40;
    double h = isBoard ? tH : 80;

    if (isPreview) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.yellow, width: 2),
        ),
      );
    }

    Widget domino = Opacity(
      opacity: isPlayable ? 1.0 : 0.4,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 3,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: _buildDots(tile.isReversed ? tile.sideB : tile.sideA),
              ),
            ),
            Container(height: 1.5, color: Colors.black54),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: _buildDots(tile.isReversed ? tile.sideA : tile.sideB),
              ),
            ),
          ],
        ),
      ),
    );

    if (isHorizontal) return RotatedBox(quarterTurns: 1, child: domino);
    return domino;
  }

  Widget _buildDots(int count) {
    return CustomPaint(
      size: Size.infinite,
      painter: DominoPainter(count: count),
    );
  }
}

class DominoPainter extends CustomPainter {
  final int count;
  DominoPainter({required this.count});

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;

    final Map<int, Color> colors = {
      1: Colors.red,
      2: Colors.orange,
      3: Colors.green,
      4: Colors.brown,
      5: Colors.blue[800]!,
      6: Colors.purple[800]!,
    };

    final paint = Paint()
      ..color = colors[count] ?? Colors.black87
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final r = w * 0.12;
    final lX = w * 0.25;
    final rX = w * 0.75;
    final mX = w * 0.5;
    final tY = h * 0.25;
    final bY = h * 0.75;
    final mY = h * 0.5;

    void dot(double x, double y) => canvas.drawCircle(Offset(x, y), r, paint);

    switch (count) {
      case 1:
        dot(mX, mY);
        break;
      case 2:
        dot(lX, tY);
        dot(rX, bY);
        break;
      case 3:
        dot(lX, tY);
        dot(mX, mY);
        dot(rX, bY);
        break;
      case 4:
        dot(lX, tY);
        dot(rX, tY);
        dot(lX, bY);
        dot(rX, bY);
        break;
      case 5:
        dot(lX, tY);
        dot(rX, tY);
        dot(mX, mY);
        dot(lX, bY);
        dot(rX, bY);
        break;
      case 6:
        dot(lX, tY);
        dot(rX, tY);
        dot(lX, mY);
        dot(rX, mY);
        dot(lX, bY);
        dot(rX, bY);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension on _DominoScreenState {
  Widget _buildMatchmakingUI() {
    final int maxPlayers = widget.playerCount;

    // Prepare avatars list for positions
    List<Widget> avatars = [];
    for (int i = 0; i < maxPlayers; i++) {
      String? photo = _playerPhotos[i];
      String name = _playerNames[i] ?? "جاري البحث...";
      bool found = _playerNames.containsKey(i);
      Color teamColor = (i == 0 || i == 2)
          ? Colors.blueAccent
          : Colors.redAccent;
      avatars.add(_buildMatchmakingAvatar(name, photo, teamColor, found));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_roomId != null && _isMatchmaking) {
          await DominoService().removeFromPool(
            widget.betAmount,
            widget.gameMode,
            widget.playerCount,
          );
          await DominoService().deleteRoom(_roomId!);
        }
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A0E1A), // Midnight Space Blue
                Color(0xFF0F172A), // Slate Navy Dark Blue
                Color(0xFF050814), // Dark Space Abyss
              ],
            ),
          ),
          child: Stack(
            children: [
              // Background Stars/Particles
              Positioned.fill(
                child: Opacity(
                  opacity: 0.3,
                  child: Image.asset(
                    'assets/images/stars_bg.png',
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const SizedBox(),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    // Center Domino Graphic with spinning frame
                    Center(
                      child: _MatchmakingRotatingFrame(
                        size: 90,
                        child: Image.asset(
                          'assets/images/domi.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.casino,
                            color: Colors.white24,
                            size: 60,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _matchFoundTransition
                          ? "تم العثور على خصم!"
                          : "البحث عن خصوم...",
                      style: GoogleFonts.tajawal(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _matchFoundTransition
                            ? Colors.greenAccent
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _matchFoundTransition
                          ? "تبدأ المباراة خلال $_countdownSeconds..."
                          : "الرهان المختار: ${widget.betAmount} في نمط ${_getGameModeName()}",
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        color: _matchFoundTransition
                            ? Colors.white
                            : Colors.white54,
                        fontWeight: _matchFoundTransition
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Flags and Avatars Area
                    Expanded(
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          // Crossed Poles
                          Positioned(
                            top: 20,
                            child: Row(
                              children: [
                                Transform.rotate(
                                  angle: -math.pi / 8,
                                  child: Container(
                                    width: 2,
                                    height: 280,
                                    color: Colors.white10,
                                  ),
                                ),
                                const SizedBox(width: 30),
                                Transform.rotate(
                                  angle: math.pi / 8,
                                  child: Container(
                                    width: 2,
                                    height: 280,
                                    color: Colors.white10,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Team Flags
                          Positioned(
                            top: 10,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Team 1 (Left/Blue)
                                _MatchmakingFlag(
                                  imagePath: 'assets/images/gams/blu1x.png',
                                  alignLeft: true,
                                  playerAvatars: [
                                    avatars[0],
                                    if (maxPlayers == 4 && avatars.length > 2)
                                      avatars[2],
                                  ],
                                ),
                                const SizedBox(width: 40),
                                // Team 2 (Right/Red)
                                _MatchmakingFlag(
                                  imagePath: 'assets/images/gams/red2x.png',
                                  alignLeft: false,
                                  playerAvatars: [
                                    if (avatars.length > 1) avatars[1],
                                    if (maxPlayers == 4 && avatars.length > 3)
                                      avatars[3],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom info and Cancel button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const _PulseDot(),
                        const SizedBox(width: 10),
                        Text(
                          " جاري البحث عن الخصم",
                          style: GoogleFonts.tajawal(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_roomId != null) {
                              // Clean up from matchmaking pool and delete the room entirely
                              await DominoService().removeFromPool(
                                widget.betAmount,
                                widget.gameMode,
                                widget.playerCount,
                              );
                              await DominoService().deleteRoom(_roomId!);
                            }
                            if (mounted) Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.05),
                            side: const BorderSide(color: Colors.white12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            "إلغاء البحث",
                            style: GoogleFonts.tajawal(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGameModeName() {
    return widget.gameMode == 'points' ? "النقاط" : "المضاعة";
  }

  Widget _buildMatchmakingAvatar(
    String name,
    String? photo,
    Color color,
    bool found,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: found ? 75 : 55,
              height: found ? 75 : 55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (found ? color : Colors.white10).withOpacity(
                      found ? 0.3 : 0.05,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            if (!found) _MatchmakingFlagScanner(),
            _AvatarSpinningRing(isSearching: !found, color: color),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: found ? color : Colors.white24,
                  width: 2,
                ),
                image: photo != null
                    ? DecorationImage(
                        image: _getAvatarProvider(photo),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: Colors.grey[900],
              ),
              child: photo == null
                  ? const Icon(Icons.person, color: Colors.white24, size: 30)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 80),
          child: Text(
            name,
            style: GoogleFonts.tajawal(
              color: found ? Colors.white : Colors.white38,
              fontSize: 11,
              fontWeight: found ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  ImageProvider _getAvatarProvider(String photo) {
    if (photo.startsWith('assets/')) return AssetImage(photo);
    if (photo.startsWith('http')) return NetworkImage(photo);
    return AssetImage(photo);
  }
}

// ── Matchmaking Helper Widgets ──

class _MatchmakingFlagScanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Container(
          width: 45 + (20 * value),
          height: 45 + (20 * value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.cyanAccent.withOpacity(1.0 - value),
              width: 1.0,
            ),
          ),
        );
      },
    );
  }
}

class _AvatarSpinningRing extends StatefulWidget {
  final bool isSearching;
  final Color color;
  const _AvatarSpinningRing({required this.isSearching, required this.color});
  @override
  State<_AvatarSpinningRing> createState() => _AvatarSpinningRingState();
}

class _AvatarSpinningRingState extends State<_AvatarSpinningRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color ringColor = widget.isSearching
        ? Colors.cyanAccent
        : widget.color;
    return RotationTransition(
      turns: _ctrl,
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: CustomPaint(painter: EnergyRingPainter(color: ringColor)),
      ),
    );
  }
}

class EnergyRingPainter extends CustomPainter {
  final Color color;
  EnergyRingPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const double gap = 0.3;
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      0,
      1.5,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      1.5 + gap,
      1.5,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      3 + gap * 2,
      1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MatchmakingFlag extends StatelessWidget {
  final String imagePath;
  final List<Widget> playerAvatars;
  final bool alignLeft;
  const _MatchmakingFlag({
    required this.imagePath,
    required this.playerAvatars,
    required this.alignLeft,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 320,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Image.asset(imagePath, width: 130, height: 320, fit: BoxFit.fill),
          Column(
            children: [
              const SizedBox(height: 70),
              ...playerAvatars.map(
                (avatar) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: avatar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchmakingRotatingFrame extends StatefulWidget {
  final Widget child;
  final double size;
  const _MatchmakingRotatingFrame({required this.child, required this.size});
  @override
  State<_MatchmakingRotatingFrame> createState() =>
      _MatchmakingRotatingFrameState();
}

class _MatchmakingRotatingFrameState extends State<_MatchmakingRotatingFrame>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        RotationTransition(
          turns: _ctrl,
          child: Container(
            width: widget.size + 10,
            height: widget.size + 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white12,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: const CircularProgressIndicator(
              value: 0.2,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(_ctrl.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withOpacity(0.5 * _ctrl.value),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundOverDialog extends StatefulWidget {
  final int roundNumber;
  final int winnerIndex;
  final int roundPoints;
  final List<int> playerScores;
  final List<List<DominoTile>> playersHands;
  final app.User? currentUser;
  final int myPlayerIndex;
  final bool isGameFinished;
  final bool isBlocked;
  final int betAmount;
  final String gameMode;
  final int playerCount;
  final Map<int, String> playerNames;
  final Map<int, String?> playerPhotos;
  final VoidCallback onContinue;
  final String? overrideMessage;

  const _RoundOverDialog({
    required this.roundNumber,
    required this.winnerIndex,
    required this.roundPoints,
    required this.playerScores,
    required this.playersHands,
    required this.currentUser,
    required this.myPlayerIndex,
    required this.isGameFinished,
    this.isBlocked = false,
    required this.betAmount,
    required this.gameMode,
    required this.playerCount,
    required this.playerNames,
    required this.playerPhotos,
    required this.onContinue,
    this.overrideMessage,
  });

  @override
  State<_RoundOverDialog> createState() => _RoundOverDialogState();
}

class _RoundOverDialogState extends State<_RoundOverDialog> {
  int _secondsRemaining = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        if (mounted) {
          // Use rootNavigator: true to ensure we close the dialog correctly
          Navigator.of(context, rootNavigator: true).pop();
          widget.onContinue();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    (widget.betAmount * 1.8).toInt();

    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: const Color(0xFF4DB6AC),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Text(
                      widget.overrideMessage ??
                          (widget.isGameFinished
                              ? "نهاية المباراة"
                              : (widget.isBlocked
                                    ? "لعبة مقفلة"
                                    : "الجولة ${widget.roundNumber}")),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.tajawal(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        ...(() {
                          final sortedIndices =
                              List.generate(widget.playerCount, (i) => i)
                                ..sort((a, b) {
                                  if (a == widget.winnerIndex) return -1;
                                  if (b == widget.winnerIndex) return 1;
                                  return widget.playerScores[b].compareTo(
                                    widget.playerScores[a],
                                  );
                                });

                          return sortedIndices.asMap().entries.map((entry) {
                            int rank = entry.key + 1;
                            int pIdx = entry.value;
                            bool isWinner = pIdx == widget.winnerIndex;
                            bool isMe = pIdx == widget.myPlayerIndex;

                            String pName = isMe
                                ? (widget.currentUser?.nickname ??
                                      widget.currentUser?.username ??
                                      "أنت")
                                : (widget.playerNames[pIdx] ??
                                      "لاعب ${pIdx + 1}");
                            String? pAvatar = isMe
                                ? widget.currentUser?.profileImage
                                : widget.playerPhotos[pIdx];

                            return Column(
                              children: [
                                _buildPlayerCard(
                                  rank: rank,
                                  isWinner: isWinner,
                                  name: pName,
                                  avatar: pAvatar,
                                  roundPoints: isWinner
                                      ? widget.roundPoints
                                      : 0,
                                  totalScore: widget.playerScores[pIdx],
                                  tiles: isWinner
                                      ? []
                                      : widget.playersHands[pIdx],
                                ),
                                if (entry.key < widget.playerCount - 1)
                                  const SizedBox(height: 12),
                              ],
                            );
                          });
                        })(),
                        const SizedBox(height: 20),
                        Text(
                          widget.isGameFinished
                              ? "s $_secondsRemaining ستنتهي المباراة بعد"
                              : "s $_secondsRemaining ستبدأ الجولة القادمة بعد",
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            color: const Color(0xFF263238),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard({
    required int rank,
    required bool isWinner,
    required String name,
    required String? avatar,
    required int roundPoints,
    required int totalScore,
    required List<DominoTile> tiles,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWinner ? const Color(0xFFFFF9C4) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 35,
            child: Text(
              "$rank",
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: isWinner
                    ? const Color(0xFFFBC02D)
                    : const Color(0xFFB0BEC5),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isWinner
                        ? const Color(0xFFFBC02D)
                        : const Color(0xFF4DB6AC),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.amber[100],
                  backgroundImage: avatar != null
                      ? (() {
                          String cp = avatar;
                          if (cp.startsWith('file:///'))
                            cp = cp.substring(8);
                          else if (cp.startsWith('file://'))
                            cp = cp.substring(7);
                          return cp.startsWith('http')
                              ? NetworkImage(cp)
                              : AssetImage(cp) as ImageProvider;
                        })()
                      : null,
                  child: avatar == null
                      ? const Icon(
                          Icons.person,
                          color: Color(0xFF455A64),
                          size: 30,
                        )
                      : null,
                ),
              ),
              if (isWinner)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBC02D),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(blurRadius: 3, color: Colors.black26),
                      ],
                    ),
                    child: const Text(
                      "WIN",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 100, 69, 41),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.tajawal(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF263238),
                        ),
                      ),
                    ),
                    if (isWinner)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5), // Rich Blue
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "EXP +1",
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildStatBar(
                  "النقاط",
                  roundPoints.toString(),
                  isWinner ? const Color(0xFFFF9100) : const Color(0xFF4DB6AC),
                ),
                const SizedBox(height: 4),
                _buildStatBar(
                  "المجموع",
                  totalScore.toString(),
                  isWinner
                      ? const Color.fromARGB(255, 15, 14, 8)
                      : const Color(0xFF263238),
                ),
              ],
            ),
          ),
          if (!isWinner && tiles.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 55),
              child: Container(
                padding: const EdgeInsets.all(4),
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black26),
                ),
                child: Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: tiles
                      .take(4)
                      .map((t) => _buildTinyTile(t))
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatBar(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: GoogleFonts.tajawal(
                fontSize: 10,
                color: const Color(0xFF263238).withOpacity(0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12, // Slightly smaller
              fontWeight: FontWeight.w900,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTinyTile(DominoTile tile) {
    return Container(
      width: 16,
      height: 32,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black87, width: 0.8),
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(1, 1)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(child: _buildTinyDots(tile.sideA)),
          Container(height: 0.8, color: Colors.black26),
          Expanded(child: _buildTinyDots(tile.sideB)),
        ],
      ),
    );
  }

  Widget _buildTinyDots(int n) {
    return CustomPaint(
      size: Size.infinite,
      painter: DominoPainter(count: n),
    );
  }
}

class _GameOverDialog extends StatefulWidget {
  final int winnerIndex;
  final List<int> playerScores;
  final app.User? currentUser;
  final int myPlayerIndex;
  final int betAmount;
  final String gameMode;
  final int playerCount;
  final Map<int, String> playerNames;
  final Map<int, String?> playerPhotos;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;
  final String? message;

  const _GameOverDialog({
    required this.winnerIndex,
    required this.playerScores,
    required this.currentUser,
    required this.myPlayerIndex,
    required this.betAmount,
    required this.gameMode,
    required this.playerCount,
    required this.playerNames,
    required this.playerPhotos,
    required this.onPlayAgain,
    required this.onExit,
    this.message,
  });

  @override
  State<_GameOverDialog> createState() => _GameOverDialogState();
}

class _GameOverDialogState extends State<_GameOverDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _buildPlayerAvatar(int pIndex, Color color) {
    String? photoPath = (pIndex == widget.myPlayerIndex)
        ? widget.currentUser?.profileImage
        : widget.playerPhotos[pIndex];

    if (photoPath != null && photoPath.isNotEmpty) {
      return Image(
        image: photoPath.startsWith('http')
            ? NetworkImage(photoPath)
            : AssetImage(photoPath) as ImageProvider,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: color,
          alignment: Alignment.center,
          child: const Icon(Icons.person, color: Colors.white),
        ),
      );
    }
    return Container(
      color: color,
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWinnerPlayer = widget.winnerIndex == widget.myPlayerIndex;

    // Determine the loser (runner-up / main opponent)
    int loserIndex = 0;
    int highestScore = -1;
    for (int i = 0; i < widget.playerCount; i++) {
      if (i != widget.winnerIndex && widget.playerScores[i] > highestScore) {
        highestScore = widget.playerScores[i];
        loserIndex = i;
      }
    }
    if (highestScore == -1) {
      loserIndex = (widget.winnerIndex + 1) % widget.playerCount;
    }

    int prizeValue = widget.betAmount > 0
        ? (widget.betAmount * 1.8).toInt()
        : 500;
    String prizeText = isWinnerPlayer
        ? "+$prizeValue"
        : "-${widget.betAmount > 0 ? widget.betAmount : 500}";

    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.95,
                constraints: const BoxConstraints(maxWidth: 420),
                child: AspectRatio(
                  aspectRatio: 1000 / 1120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Background Image
                        Positioned.fill(
                          child: Image.asset(
                            isWinnerPlayer
                                ? 'assets/images/win.png'
                                : 'assets/images/lost.png',
                            fit: BoxFit.fill,
                          ),
                        ),

                        // Lottie Fireworks overlay if user won
                        if (isWinnerPlayer)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Lottie.asset(
                                'assets/lottie/Fireworks.json',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.maxWidth;
                              final h = constraints.maxHeight;

                              return Stack(
                                children: [
                                  // Prize Capsule Text
                                  Positioned(
                                    left: w * 0.77,
                                    top: isWinnerPlayer ? h * 0.405 : h * 0.43,
                                    width: w * 0.15,
                                    height: h * 0.042,
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          prizeText,
                                          style: GoogleFonts.tajawal(
                                            color: const Color(0xFFFFD700),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.black,
                                                offset: Offset(0, 1.5),
                                                blurRadius: 2.5,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Winner Avatar
                                  Positioned(
                                    left: w * 0.273,
                                    top: isWinnerPlayer ? h * 0.485 : h * 0.51,
                                    width: w * 0.138,
                                    height: w * 0.138,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.amber.withOpacity(
                                              0.35,
                                            ),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: _buildPlayerAvatar(
                                          widget.winnerIndex,
                                          Colors.amber,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Winner Name & Score
                                  Positioned(
                                    left: w * 0.435,
                                    top: isWinnerPlayer ? h * 0.48 : h * 0.505,
                                    width: w * 0.43,
                                    height: w * 0.15,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.myPlayerIndex ==
                                                      widget.winnerIndex
                                                  ? "أنت"
                                                  : (widget.playerNames[widget
                                                            .winnerIndex] ??
                                                        "لاعب ${widget.winnerIndex + 1}"),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textDirection: TextDirection.rtl,
                                              style: GoogleFonts.tajawal(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black
                                                        .withOpacity(0.8),
                                                    offset: const Offset(
                                                      0,
                                                      1.5,
                                                    ),
                                                    blurRadius: 3,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              "النقاط: ${widget.playerScores[widget.winnerIndex]}",
                                              style: GoogleFonts.tajawal(
                                                color: Colors.amberAccent,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Loser Avatar
                                  Positioned(
                                    left: w * 0.273,
                                    top: isWinnerPlayer ? h * 0.665 : h * 0.69,
                                    width: w * 0.138,
                                    height: w * 0.138,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blueAccent
                                                .withOpacity(0.35),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: _buildPlayerAvatar(
                                          loserIndex,
                                          Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Loser Name & Score
                                  Positioned(
                                    left: w * 0.435,
                                    top: isWinnerPlayer ? h * 0.66 : h * 0.685,
                                    width: w * 0.43,
                                    height: w * 0.15,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.myPlayerIndex == loserIndex
                                                  ? "أنت"
                                                  : (widget.playerNames[loserIndex] ??
                                                        "لاعب ${loserIndex + 1}"),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textDirection: TextDirection.rtl,
                                              style: GoogleFonts.tajawal(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.black
                                                        .withOpacity(0.8),
                                                    offset: const Offset(
                                                      0,
                                                      1.5,
                                                    ),
                                                    blurRadius: 3,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              "النقاط: ${widget.playerScores[loserIndex]}",
                                              style: GoogleFonts.tajawal(
                                                color: Colors.white70,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Play Again Button Overlay
                                  Positioned(
                                    left: w * 0.085,
                                    top: h * 0.835,
                                    width: w * 0.395,
                                    height: h * 0.105,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        splashColor: Colors.orange.withOpacity(
                                          0.3,
                                        ),
                                        highlightColor: Colors.orange
                                            .withOpacity(0.15),
                                        onTap: widget.onPlayAgain,
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ),

                                  // Exit Button Overlay
                                  Positioned(
                                    left: w * 0.52,
                                    top: h * 0.835,
                                    width: w * 0.395,
                                    height: h * 0.105,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(24),
                                        splashColor: Colors.blue.withOpacity(
                                          0.3,
                                        ),
                                        highlightColor: Colors.blue.withOpacity(
                                          0.15,
                                        ),
                                        onTap: widget.onExit,
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TablePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const double radius = 35.0;
    final double hexWidth = radius * math.sqrt(3);
    final double hexHeight = radius * 1.5;

    for (double y = -radius; y < size.height + radius; y += hexHeight) {
      double xOffset = ((y / hexHeight).round() % 2 == 0) ? 0 : hexWidth / 2;
      for (double x = -hexWidth; x < size.width + hexWidth; x += hexWidth) {
        _drawHexagon(canvas, Offset(x + xOffset, y), radius, paint);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final Path path = Path();
    for (int i = 0; i < 6; i++) {
      double angle = (60 * i - 30) * math.pi / 180;
      double x = center.dx + radius * math.cos(angle);
      double y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class DominoGameLogEntry {
  final String type; // 'chat' or 'sticker'
  final String content;
  final String senderId;
  final int timestamp;

  DominoGameLogEntry({
    required this.type,
    required this.content,
    required this.senderId,
    required this.timestamp,
  });
}

// ignore_for_file: unused_element
class _ChatBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double radius = 14;
    const double tailWidth = 10;
    const double tailHeight = 8;
    final double bodyHeight = size.height - tailHeight;

    final path = Path();
    path.moveTo(radius, 0);
    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    path.lineTo(size.width, bodyHeight - radius);
    path.quadraticBezierTo(
      size.width,
      bodyHeight,
      size.width - radius,
      bodyHeight,
    );
    path.lineTo(size.width / 2 + tailWidth, bodyHeight);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width / 2 - tailWidth, bodyHeight);
    path.lineTo(radius, bodyHeight);
    path.quadraticBezierTo(0, bodyHeight, 0, bodyHeight - radius);
    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);
    path.close();

    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7B9BFF), Color(0xFF5B6FD6)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    canvas.drawPath(path, gradientPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
