import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/backgammon_theme.dart';
import '../services/backgammon_service.dart';

class BackgammonProvider with ChangeNotifier {
  // --- Theme State ---
  BackgammonThemeData currentTheme = BackgammonThemeData.obsidian();
  final List<BackgammonThemeData> availableThemes = [
    BackgammonThemeData.obsidian(),
    BackgammonThemeData.classic(),
    BackgammonThemeData.ivory(),
    BackgammonThemeData.sky(),
    BackgammonThemeData.jungle(),
    BackgammonThemeData.marble(),
    BackgammonThemeData.ruby(),
    BackgammonThemeData.pearl(),
  ];

  void setTheme(BackgammonThemeType type) {
    switch (type) {
      case BackgammonThemeType.obsidian:
        currentTheme = BackgammonThemeData.obsidian();
        break;
      case BackgammonThemeType.ivory:
        currentTheme = BackgammonThemeData.ivory();
        break;
      case BackgammonThemeType.sky:
        currentTheme = BackgammonThemeData.sky();
        break;
      case BackgammonThemeType.jungle:
        currentTheme = BackgammonThemeData.jungle();
        break;
      case BackgammonThemeType.classic:
        currentTheme = BackgammonThemeData.classic();
        break;
      case BackgammonThemeType.marble:
        currentTheme = BackgammonThemeData.marble();
        break;
      case BackgammonThemeType.ruby:
        currentTheme = BackgammonThemeData.ruby();
        break;
      case BackgammonThemeType.pearl:
        currentTheme = BackgammonThemeData.pearl();
        break;
    }
    notifyListeners();
  }

  // -------------------
  // Board: 24 points. Positive for White, negative for Black.
  List<int> board = List.filled(24, 0);
  int whiteBar = 0;
  int blackBar = 0;
  int whiteOff = 0;
  int blackOff = 0;
  bool isGameOver = false;
  int? winner;

  int currentPlayer = 1; // 1 for White, 2 for Black
  List<int> dice = [0, 0];
  List<int> availableMoves = [];
  int? selectedPoint;
  bool isBarSelected = false;
  List<int> validDestinations = [];
  Map<int, List<int>> _destinationDiceMap =
      {}; // Maps target index to sequence of dice used

  // --- Animation State ---
  int? moveStart; // null if from Bar
  int? moveEnd;
  bool isMovingFromBar = false;
  bool isMovingToOff = false;
  int movingPlayer = 1;
  double moveProgress = 0.0; // 0.0 to 1.0 (exposed for painter)
  bool isAnimating = false;
  List<int> remainingDiceSequence = [];
  int? currentJumpTarget;
  // -----------------------

  // Undo History
  final List<String> _history = []; // JSON snapshots of board state for undo

  // --- Online State ---
  String? _roomId;
  int? _myPlayerIndex; // 1 for White, 2 for Black
  int? get myPlayerIndex => _myPlayerIndex;
  bool _isOnline = false;
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  bool _isProcessingNetworkUpdate = false;

  // --- Audio State ---
  final AudioPlayer _movePlayer = AudioPlayer();
  final AudioPlayer _dicePlayer = AudioPlayer();
  final AudioPlayer _capturePlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool isMuted = false;

  void _initAudio() {
    // 1. Background Music (Asset)
    _musicPlayer
        .setAsset('assets/sounds/tawleemudic.mp3')
        .then((_) {
          _musicPlayer.setLoopMode(LoopMode.all);
          _musicPlayer.setVolume(0.85); // 85% volume
          if (!isMuted) _musicPlayer.play();
        })
        .catchError((e) {
          debugPrint("Backgammon Music Load Error: $e");
        });

    // 2. SFX - Movement
    _movePlayer
        .setAudioSource(
          AudioSource.uri(
            Uri.parse('https://www.soundjay.com/buttons/sounds/button-16.mp3'),
          ),
        )
        .catchError((e) {
          debugPrint("Move Sound error: $e");
          return null; // Implicit Duration?
        });

    // 3. SFX - Dice
    _dicePlayer.setAsset('assets/sounds/dice.mp3').catchError((e) {
      debugPrint("Dice Sound error: $e");
      return null;
    });

    // 4. SFX - Capture
    _capturePlayer
        .setAudioSource(
          AudioSource.uri(
            Uri.parse('https://www.soundjay.com/buttons/sounds/button-37.mp3'),
          ),
        )
        .catchError((e) {
          debugPrint("Capture Sound error: $e");
          return null;
        });

    // Set volumes
    _movePlayer.setVolume(1.0);
    _dicePlayer.setVolume(1.0); // Set to 100% volume
    _capturePlayer.setVolume(1.0);
  }

  void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) {
      _musicPlayer.pause();
    } else {
      _musicPlayer.play();
    }
    notifyListeners();
  }

  void playMoveSound() {
    if (isMuted) return;
    _movePlayer.seek(Duration.zero);
    _movePlayer.play();
  }

  void playDiceSound() {
    if (isMuted) return;
    _dicePlayer.seek(Duration.zero);
    _dicePlayer.play();
  }

  void playCaptureSound() {
    if (isMuted) return;
    _capturePlayer.seek(Duration.zero);
    _capturePlayer.play();
  }

  String message = "اضغط على النرد للبدء";

  BackgammonProvider() {
    _initAudio();
    resetGame();
  }

  // Initialize online mode
  void initOnline(String roomId, int myIndex) {
    _roomId = roomId;
    _myPlayerIndex = myIndex;
    _isOnline = true;
    _listenToRoom();
  }

  void _listenToRoom() {
    if (_roomId == null) return;
    _roomSubscription?.cancel();
    _roomSubscription = BackgammonService().streamRoom(_roomId!).listen((
      event,
    ) {
      if (event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final state = Map<String, dynamic>.from(data['state'] ?? {});

      if (state.isEmpty) return;

      _isProcessingNetworkUpdate = true;

      // Check if it's telling us to initialize (first join)
      if (state['readyToInitialize'] == true && _myPlayerIndex == 1) {
        // Player 1 (White) initializes the board and pushes it
        resetGame();
        BackgammonService().updateGameState(_roomId!, {
          'state/readyToInitialize': false,
          'state/board': board,
          'state/whiteBar': whiteBar,
          'state/blackBar': blackBar,
          'state/whiteOff': whiteOff,
          'state/blackOff': blackOff,
          'state/currentPlayer': currentPlayer,
          'state/dice': dice,
          'state/availableMoves': availableMoves,
        });
        _isProcessingNetworkUpdate = false;
        return;
      }

      if (state['readyToInitialize'] == true) {
        _isProcessingNetworkUpdate = false;
        return; // Wait for player 1 to setup
      }

      // Sync state
      final newBoard = List<int>.from(state['board'] ?? List.filled(24, 0));
      final newWhiteBar = state['whiteBar'] as int? ?? 0;
      final newBlackBar = state['blackBar'] as int? ?? 0;
      final newWhiteOff = state['whiteOff'] as int? ?? 0;
      final newBlackOff = state['blackOff'] as int? ?? 0;
      final newCurrentPlayer = state['currentPlayer'] as int? ?? 1;
      final newDice = List<int>.from(state['dice'] ?? [0, 0]);
      final newAvailableMoves = List<int>.from(state['availableMoves'] ?? []);
      final newIsGameOver = state['isGameOver'] == true;
      final newWinner = state['winner'] as int?;

      // We only forcefully override the local state if we are NOT animating,
      // OR if the turn actually changed, OR if a rollback is needed.
      // For a robust UI, we apply network state directly.
      bool boardChanged = _didBoardChange(
        newBoard,
        newWhiteBar,
        newBlackBar,
        newWhiteOff,
        newBlackOff,
      );

      if (boardChanged && !isAnimating) {
        board = newBoard;
        whiteBar = newWhiteBar;
        blackBar = newBlackBar;
        whiteOff = newWhiteOff;
        blackOff = newBlackOff;
      }

      currentPlayer = newCurrentPlayer;
      dice = newDice;
      availableMoves = newAvailableMoves;
      isGameOver = newIsGameOver;
      winner = newWinner;

      _updateGameMessage();

      _isProcessingNetworkUpdate = false;
      notifyListeners();
    });
  }

  bool _didBoardChange(List<int> nB, int nWb, int nBb, int nWo, int nBo) {
    if (whiteBar != nWb ||
        blackBar != nBb ||
        whiteOff != nWo ||
        blackOff != nBo)
      return true;
    for (int i = 0; i < 24; i++) {
      if (board[i] != nB[i]) return true;
    }
    return false;
  }

  void resetGame() {
    board = List.filled(24, 0);
    // Standard Setup
    board[0] = 2; // White
    board[11] = 5; // White
    board[16] = 3; // White
    board[18] = 5; // White

    board[23] = -2; // Black
    board[12] = -5; // Black
    board[7] = -3; // Black
    board[5] = -5; // Black

    whiteBar = 0;
    blackBar = 0;
    whiteOff = 0;
    blackOff = 0;

    currentPlayer = 1;
    dice = [0, 0];
    availableMoves = [];
    selectedPoint = null;
    isBarSelected = false;
    validDestinations = [];
    isGameOver = false;
    winner = null;
    message = "دور اللاعب الأبيض (سحب النرد)";
    notifyListeners();
  }

  void rollDice() {
    if (availableMoves.isNotEmpty || isGameOver) return;
    if (_isOnline && currentPlayer != _myPlayerIndex)
      return; // Prevent controlling other

    dice[0] = math.Random().nextInt(6) + 1;
    dice[1] = math.Random().nextInt(6) + 1;

    if (dice[0] == dice[1]) {
      availableMoves = [dice[0], dice[0], dice[0], dice[0]];
    } else {
      availableMoves = [dice[0], dice[1]];
    }

    _history.clear();
    _checkStuck();
    _updateGameMessage();

    // Auto-Select Bar if pieces are outside
    if ((currentPlayer == 1 && whiteBar > 0) ||
        (currentPlayer == 2 && blackBar > 0)) {
      selectBar();
    }

    if (_isOnline && _roomId != null && !_isProcessingNetworkUpdate) {
      // Sync dice roll
      BackgammonService().updateGameState(_roomId!, {
        'state/dice': dice,
        'state/availableMoves': availableMoves,
      });
    }

    notifyListeners();
  }

  void _saveHistory() {
    // Basic state snapshot
    final state = {
      'board': List<int>.from(board),
      'moves': List<int>.from(availableMoves),
      'wBar': whiteBar,
      'bBar': blackBar,
      'wOff': whiteOff,
      'bOff': blackOff,
    };
    // Use a simple string representation for historical snapshots
    _history.add(state.toString());
  }

  void undoMove() {
    if (_history.isEmpty) return;
    if (_isOnline && currentPlayer != _myPlayerIndex) return; // Online check

    // Simple parser for our custom toString format (regex could be more robust but this is a controlled env)
    final lastStateStr = _history.removeLast();
    // This is a bit hacky, but avoids adding a full json dependency if not needed
    // In a real app, use json.decode
    resetToState(lastStateStr);

    selectedPoint = null;
    isBarSelected = false;
    validDestinations = [];
    _updateGameMessage();

    if (_isOnline && _roomId != null) {
      _syncBoardWithNetwork();
    }

    notifyListeners();
  }

  void _syncBoardWithNetwork() {
    BackgammonService().syncBoardState(
      _roomId!,
      board: board,
      whiteBar: whiteBar,
      blackBar: blackBar,
      whiteOff: whiteOff,
      blackOff: blackOff,
      currentPlayer: currentPlayer,
      dice: dice,
      availableMoves: availableMoves,
    );
  }

  void resetToState(String stateStr) {
    // Crude parsing for the sake of the task
    try {
      final boardMatch = RegExp(r'board: \[(.*?)\]').firstMatch(stateStr);
      if (boardMatch != null) {
        board = boardMatch
            .group(1)!
            .split(',')
            .map((e) => int.parse(e.trim()))
            .toList();
      }
      final movesMatch = RegExp(r'moves: \[(.*?)\]').firstMatch(stateStr);
      if (movesMatch != null) {
        final movesStr = movesMatch.group(1)!;
        availableMoves = movesStr.isEmpty
            ? []
            : movesStr.split(',').map((e) => int.parse(e.trim())).toList();
      }
      final wBarMatch = RegExp(r'wBar: (\d+)').firstMatch(stateStr);
      if (wBarMatch != null) whiteBar = int.parse(wBarMatch.group(1)!);
      final bBarMatch = RegExp(r'bBar: (\d+)').firstMatch(stateStr);
      if (bBarMatch != null) blackBar = int.parse(bBarMatch.group(1)!);
      final wOffMatch = RegExp(r'wOff: (\d+)').firstMatch(stateStr);
      if (wOffMatch != null) whiteOff = int.parse(wOffMatch.group(1)!);
      final bOffMatch = RegExp(r'bOff: (\d+)').firstMatch(stateStr);
      if (bOffMatch != null) blackOff = int.parse(bOffMatch.group(1)!);
    } catch (e) {
      debugPrint("Undo error: $e");
    }
  }

  bool get canUndo => _history.isNotEmpty;

  void _checkStuck() {
    if (availableMoves.isEmpty) return;

    bool hasAnyMove = false;

    bool isBoardClosed = false;
    if (currentPlayer == 1 && whiteBar > 0) {
      isBoardClosed = true;
      for (int i = 0; i < 6; i++) {
        if (board[i] >= -1) {
          isBoardClosed = false;
          break;
        }
      }
    } else if (currentPlayer == 2 && blackBar > 0) {
      isBoardClosed = true;
      for (int i = 18; i < 24; i++) {
        if (board[i] <= 1) {
          isBoardClosed = false;
          break;
        }
      }
    }

    // 1. Check Bar Moves
    if (currentPlayer == 1 && whiteBar > 0) {
      for (int die in availableMoves.toSet()) {
        if (_canMoveTo(die - 1)) {
          hasAnyMove = true;
          break;
        }
      }
    } else if (currentPlayer == 2 && blackBar > 0) {
      for (int die in availableMoves.toSet()) {
        if (_canMoveTo(24 - die)) {
          hasAnyMove = true;
          break;
        }
      }
    } else {
      // 2. Check Board Moves & Bearing Off
      outer:
      for (int i = 0; i < 24; i++) {
        // If player owns this point
        if ((currentPlayer == 1 && board[i] > 0) ||
            (currentPlayer == 2 && board[i] < 0)) {
          // Check every available die
          for (int die in availableMoves.toSet()) {
            int target = currentPlayer == 1 ? (i + die) : (i - die);
            if (target >= 0 && target <= 23) {
              if (_canMoveTo(target)) {
                hasAnyMove = true;
                break outer;
              }
            } else if (canBearOff) {
              // Check if this piece can be borne off with this die
              int diceNeeded = currentPlayer == 1 ? (24 - i) : (i + 1);
              if (_findDiceForBearOff(i, diceNeeded) != null) {
                hasAnyMove = true;
                break outer;
              }
            }
          }
        }
      }
    }

    if (!hasAnyMove) {
      // Player is stuck! Wait a moment then skip
      if (isBoardClosed) {
        message = currentPlayer == 1
            ? "البيت مغلق تماماً! لا يمكن للأبيض الدخول"
            : "البيت مغلق تماماً! لا يمكن للأسود الدخول";
      } else {
        message = currentPlayer == 1
            ? "الأبيض محاصر! لا توجد حركات قانونية"
            : "الأسود محاصر! لا توجد حركات قانونية";
      }
      validDestinations = [];
      selectedPoint = null;
      isBarSelected = false;

      // Clear moves and schedule turn switch
      Future.delayed(const Duration(seconds: 2), () {
        if (availableMoves.isNotEmpty) {
          availableMoves = [];
          currentPlayer = (currentPlayer == 1) ? 2 : 1;
          dice = [0, 0];
          _history.clear();
          _updateGameMessage();
          notifyListeners();
        }
      });
    }
  }

  void selectBar() {
    if (availableMoves.isEmpty) return;
    if ((currentPlayer == 1 && whiteBar > 0) ||
        (currentPlayer == 2 && blackBar > 0)) {
      isBarSelected = true;
      selectedPoint = null;
      _calculateValidDestinations();

      // Aggressive One-Tap Entry (User Request)
      if (validDestinations.isNotEmpty) {
        // Find the largest possible die that leads to a valid entry
        List<int> sortedDice = List<int>.from(availableMoves.toSet().toList())
          ..sort((a, b) => b.compareTo(a));

        int? bestEntryTarget;
        for (int die in sortedDice) {
          int target = currentPlayer == 1 ? (die - 1) : (24 - die);
          if (validDestinations.contains(target)) {
            bestEntryTarget = target;
            break; // Found the largest possible entry
          }
        }

        if (bestEntryTarget != null) {
          _attemptMove(null, bestEntryTarget);
          return;
        }
      }

      notifyListeners();
    }
  }

  void selectPoint(int index) {
    if (availableMoves.isEmpty) return;

    // One-Tap Bearing Off
    if (canBearOff) {
      bool ownsPiece =
          (currentPlayer == 1 && board[index] > 0) ||
          (currentPlayer == 2 && board[index] < 0);
      if (ownsPiece && (!_isOnline || currentPlayer == _myPlayerIndex)) {
        int diceNeeded = currentPlayer == 1 ? (24 - index) : (index + 1);
        int? usedDie = _findDiceForBearOff(index, diceNeeded);
        if (usedDie != null) {
          if (currentPlayer == 1) {
            board[index]--;
            whiteOff++;
          } else {
            board[index]++;
            blackOff++;
          }
          _consumeDice(usedDie);
          playMoveSound();
          if (_isOnline && _roomId != null) _syncBoardWithNetwork();
          return;
        }
      }
    }

    // If something is already selected and we tap it again, deselect
    if (selectedPoint == index) {
      selectedPoint = null;
      validDestinations = [];
      notifyListeners();
      return;
    }

    if (isBarSelected) {
      // Tapping a point while bar is selected: try to move there
      _attemptMove(null, index);
      return;
    }

    if (selectedPoint != null) {
      // Tapping a point while another point is selected: try to move there
      _attemptMove(selectedPoint, index);
      return;
    }

    // Selecting a new piece
    if ((currentPlayer == 1 && board[index] > 0 && whiteBar == 0) ||
        (currentPlayer == 2 && board[index] < 0 && blackBar == 0)) {
      // --- Aggressive One-Tap Logic (User Request) ---
      // We prioritize the largest possible single-die jump.
      List<int> sortedDice = List<int>.from(availableMoves.toSet().toList())
        ..sort((a, b) => b.compareTo(a));

      int? bestSingleTarget;
      for (int die in sortedDice) {
        int target = currentPlayer == 1 ? (index + die) : (index - die);
        if (target >= 0 && target <= 23 && _canMoveTo(target)) {
          bestSingleTarget = target;
          break; // Found the largest possible single jump
        }
      }

      if (bestSingleTarget != null) {
        selectedPoint = index;
        isBarSelected = false;
        _calculateValidDestinations();
        _attemptMove(index, bestSingleTarget);
        return;
      }
      // ------------------------------------------------

      selectedPoint = index;
      isBarSelected = false;
      _calculateValidDestinations();

      // Fallback Auto-Move: If there's ONLY one legal move (potentially multi-die)
      if (validDestinations.length == 1) {
        _attemptMove(selectedPoint, validDestinations.first);
      } else {
        notifyListeners();
      }
    }
  }

  void bearOff() {
    if (selectedPoint == null) return;
    if (!canBearOff) return;
    if (_isOnline && currentPlayer != _myPlayerIndex) return;

    int from = selectedPoint!;
    int diceNeeded = currentPlayer == 1 ? (24 - from) : (from + 1);

    int? usedDie = _findDiceForBearOff(from, diceNeeded);

    if (usedDie != null) {
      if (currentPlayer == 1) {
        board[from]--;
        whiteOff++;
      } else {
        board[from]++;
        blackOff++;
      }
      _consumeDice(usedDie);
      if (_isOnline && _roomId != null) _syncBoardWithNetwork();
    }
  }

  void _calculateValidDestinations() {
    validDestinations = [];
    _destinationDiceMap = {};

    if (isBarSelected) {
      _recursiveFindMoves(null, availableMoves, []);
    } else if (selectedPoint != null) {
      _recursiveFindMoves(selectedPoint!, availableMoves, []);
    }

    validDestinations = _destinationDiceMap.keys.toList();
  }

  void _recursiveFindMoves(
    int? from,
    List<int> currentMoves,
    List<int> usedSoFar,
  ) {
    if (currentMoves.isEmpty) return;

    Set<int> uniqueDice = currentMoves.toSet();
    for (int die in uniqueDice) {
      int? target;
      if (from == null) {
        // Entering from bar
        target = currentPlayer == 1 ? (die - 1) : (24 - die);
      } else {
        target = currentPlayer == 1 ? (from + die) : (from - die);
      }

      if (target >= 0 && target <= 23 && _canMoveTo(target)) {
        List<int> newUsed = [...usedSoFar, die];
        // If we haven't found a shorter way or this is a new destination
        if (!_destinationDiceMap.containsKey(target) ||
            newUsed.length < _destinationDiceMap[target]!.length) {
          _destinationDiceMap[target] = newUsed;
        }

        // Try next step from this new target to support multi-move jumps
        List<int> remainingMoves = List<int>.from(currentMoves);
        remainingMoves.removeAt(remainingMoves.indexOf(die));
        _recursiveFindMoves(target, remainingMoves, newUsed);
      }
    }
  }

  bool _canMoveTo(int index) {
    if (currentPlayer == 1) {
      return board[index] >= -1;
    } else {
      return board[index] <= 1;
    }
  }

  void _attemptMove(int? from, int to) {
    if (_destinationDiceMap.containsKey(to)) {
      if (isAnimating) return;
      _saveHistory();

      List<int> diceSequence = _destinationDiceMap[to]!;
      remainingDiceSequence = List<int>.from(diceSequence);

      startNextJump(from);
    } else {
      // Invalid move, deselect
      selectedPoint = null;
      isBarSelected = false;
      validDestinations = [];
      notifyListeners();
    }
  }

  void startNextJump(int? from) {
    if (remainingDiceSequence.isEmpty) {
      _onMoveCompleted();
      return;
    }

    int die = remainingDiceSequence.removeAt(0);
    int startPos = from ?? (currentPlayer == 1 ? -1 : 24);
    int target = currentPlayer == 1 ? (startPos + die) : (startPos - die);

    isAnimating = true;
    moveStart = from;
    moveEnd = target;
    isMovingFromBar = (from == null);
    movingPlayer = currentPlayer;
    moveProgress = 0.0;
    currentJumpTarget = target;

    // We consume the die immediately from availableMoves
    availableMoves.removeAt(availableMoves.indexOf(die));

    playMoveSound();
    notifyListeners();
  }

  void updateMoveProgress(double progress) {
    moveProgress = progress;
    notifyListeners();
  }

  void _onMoveCompleted() {
    isAnimating = false;
    moveStart = null;
    moveEnd = null;
    isMovingFromBar = false;
    currentJumpTarget = null;
    remainingDiceSequence = [];

    selectedPoint = null;
    isBarSelected = false;
    validDestinations = [];

    if (availableMoves.isEmpty) {
      currentPlayer = (currentPlayer == 1) ? 2 : 1;
      dice = [0, 0];
      _history.clear(); // Clear history when turn is definitely over
    } else {
      _checkStuck();
    }

    _updateGameMessage();
    _checkWinner();

    // Auto-Select Bar if pieces remain outside and moves are available
    if (availableMoves.isNotEmpty) {
      if ((currentPlayer == 1 && whiteBar > 0) ||
          (currentPlayer == 2 && blackBar > 0)) {
        selectBar();
        if (_isOnline && _roomId != null) _syncBoardWithNetwork();
        notifyListeners();
        return;
      }
    }

    if (_isOnline && _roomId != null) {
      _syncBoardWithNetwork();
    }

    notifyListeners();
  }

  // New: Method to finalize the move after animation
  void finalizeMove(int? from, int to, bool fromBar) {
    if (fromBar) {
      if (currentPlayer == 1) {
        whiteBar--;
        if (board[to] == -1) {
          board[to] = 1;
          blackBar++;
          playCaptureSound();
        } else {
          board[to]++;
        }
      } else {
        blackBar--;
        if (board[to] == 1) {
          board[to] = -1;
          whiteBar++;
          playCaptureSound();
        } else {
          board[to]--;
        }
      }
    } else {
      if (currentPlayer == 1) {
        board[from!]--;
        if (board[to] == -1) {
          board[to] = 1;
          blackBar++;
          playCaptureSound();
        } else {
          board[to]++;
        }
      } else {
        board[from!]++;
        if (board[to] == 1) {
          board[to] = -1;
          whiteBar++;
          playCaptureSound();
        } else {
          board[to]--;
        }
      }
    }

    if (fromBar ||
        (from != null && board[to] != (currentPlayer == 1 ? 1 : -1))) {
      // Only play if it wasn't a "Hit" which plays capture sound
      // Actually startNextJump already plays move sound.
      // But finalizeMove handles the actual state change.
    }

    isAnimating = false;
    moveStart = null;
    moveEnd = null;
    isMovingFromBar = false;

    // We only send network sync inside _onMoveCompleted or when moving is fully done
    // to prevent jitter, but wait, finalizing move changes the board.
    // If we're midway through a jump (multi-jump), we should probably sync to let opponent see.
    if (_isOnline && _roomId != null) {
      _syncBoardWithNetwork();
    }

    notifyListeners();
  }

  void _consumeDice(int value) {
    availableMoves.removeAt(availableMoves.indexOf(value));
    selectedPoint = null;
    isBarSelected = false;
    validDestinations = [];

    if (availableMoves.isEmpty) {
      currentPlayer = (currentPlayer == 1) ? 2 : 1;
      dice = [0, 0];
    } else {
      _checkStuck();
    }

    _updateGameMessage();
    _checkWinner();
    notifyListeners();
  }

  int? _findDiceForBearOff(int from, int needed) {
    if (availableMoves.contains(needed)) return needed;

    // Check if it's the furthest piece and we have a higher die
    bool isFurthest = true;
    if (currentPlayer == 1) {
      for (int i = 18; i < from; i++) {
        if (board[i] > 0) isFurthest = false;
      }
    } else {
      for (int i = 5; i > from; i--) {
        if (board[i] < 0) isFurthest = false;
      }
    }

    if (isFurthest) {
      // Use the largest available die if it's larger than needed
      int maxDie = availableMoves.reduce(math.max);
      if (maxDie > needed) return maxDie;
    }
    return null;
  }

  bool get canBearOff {
    if (currentPlayer == 1) {
      if (whiteBar > 0) return false;
      for (int i = 0; i < 18; i++) {
        if (board[i] > 0) return false;
      }
    } else {
      if (blackBar > 0) return false;
      for (int i = 23; i > 5; i--) {
        if (board[i] < 0) return false;
      }
    }
    return true;
  }

  void _updateGameMessage() {
    if (whiteOff == 15) {
      isGameOver = true;
      winner = 1;
      message = "🎉 فاز اللاعب الأبيض!";
    } else if (blackOff == 15) {
      isGameOver = true;
      winner = 2;
      message = "🎉 فاز اللاعب الأسود!";
    } else if (availableMoves.isEmpty) {
      message = currentPlayer == 1
          ? "دور الأبيض (سحب النرد)"
          : "دور الأسود (سحب النرد)";
    } else {
      message = currentPlayer == 1
          ? (whiteBar > 0 ? "يجب تحريك الأبيض من البار" : "دور الأبيض: تحرك")
          : (blackBar > 0 ? "يجب تحريك الأسود من البار" : "دور الأسود: تحرك");
    }
  }

  void _checkWinner() {
    if (whiteOff == 15 || blackOff == 15) {
      availableMoves = [];
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _movePlayer.dispose();
    _dicePlayer.dispose();
    _capturePlayer.dispose();
    _musicPlayer.dispose();
    super.dispose();
  }
}
