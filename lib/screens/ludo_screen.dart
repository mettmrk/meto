// ignore_for_file: unused_field

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animated_emoji/animated_emoji.dart';
import 'dart:math';
import 'dart:async';
import 'package:flame/game.dart' hide Matrix4;
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mmmm/models/user_model.dart';

import 'package:mmmm/screens/ludo_ui_controller.dart';
import 'package:mmmm/services/voice_room_service.dart';
import 'package:mmmm/widgets/voice_volume_meter.dart';
import '../game/ludo_game.dart';
import '../game/ludo_x_manager.dart';
import '../models/index.dart' as model;
import '../widgets/animated_dice.dart';
import '../services/ludo_service.dart';
import '../services/shop_service.dart';
import '../services/domino_service.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/ludo_interaction_bottom_sheet.dart';
import '../widgets/sticker_selection_bottom_sheet.dart';
import '../widgets/level_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'ludo_store_screen.dart';
import '../services/user_service.dart';
import '../services/ai_service.dart';
import 'chat_screen.dart';
import 'domino_bet_selection_screen.dart';
import 'bomb_hunt_screen.dart';
import 'snakes_and_ladders_screen.dart';
import 'backgammon_screen.dart';
import 'car_zigzag_screen.dart';
import 'domino_screen.dart';
import 'shut_the_box_screen.dart';
import 'shut_the_box_lobby_screen.dart';
import 'quiz_game_screen.dart';
// New Modularized Imports
import '../game/core/ludo_constants.dart';
import '../game/models/ludo_enums.dart';
import '../game/models/ludo_models.dart';
import '../game/widgets/ludo_painters.dart';
import '../widgets/gold_coin_widget.dart';

// ── Part files ──────────────────────────────────────────────────────────────
part 'ludo_screen_preferences.dart';
part 'ludo_screen_dialogs.dart';
part 'ludo_screen_menu.dart';
part 'ludo_screen_online.dart';
part 'ludo_screen_game_logic.dart';
part 'ludo_screen_ai.dart';
part 'ludo_screen_ui_widgets.dart';

enum LudoUiState {
  menu,
  betSelection,
  twoFourSelection,
  teamUpSelection,
  privateTableSelection,
  dominoPrivateSelection,
  friendInvitation,
  matchmaking,
  playing,
  dominoSelection,
}

class LudoScreen extends StatefulWidget {
  final String? roomId;
  const LudoScreen({super.key, this.roomId});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> with TickerProviderStateMixin {
  final Random _rng = Random();
  late LudoGame _ludoGame;
  // ── Static cache: persists across Widget re-creations ─────────────────────
  /// Holds the last loaded token shape so new Widget instances don't have to
  /// wait for async SharedPreferences before applying the correct shape.
  static String _savedTokenShape = 'pawn';
  static bool _prefsLoaded = false;

  String _boardTheme = 'classic';
  String? _boardImageUrl;
  set _tokenShape(String v) => _savedTokenShape = v;
  String? _ludoTokenTheme; // Active theme from user profile
  Map<String, String>? _ludoTokenUrls; // Themed token URLs from metadata
  String? _hallTheme; // New: Active hall theme
  String? _hallImageUrl; // New: Hall image URL
  // Game Mode
  String _gameMode = 'local'; // 'local' or 'online'
  String? _roomId;
  int _myPlayerIndex = Random().nextInt(4); // Default to a random player index
  bool _matchFoundAnimation = false;
  int _matchCountdown = 3;
  bool _showTotalPotInMatchmaking = false;
  bool _hasStartedTransition = false; // Prevents double transition
  bool _hasSyncedRotation = false; // Forces initial rotation sync
  int _selectedBet = 50;
  String _teamUpMode = 'classic';
  int _teamUpBet = 500;
  int _twoFourPlayersCount = 2; // 2 or 4
  String _twoFourMode = 'classic';
  int _twoFourBet = 500;

  // Private Table State
  bool _isOfflineMode = false;
  String _privateTableMode = 'classic';
  bool _isPrivateFlow = false;

  // Domino State
  int _dominoPlayersCount = 2;
  String _dominoMode = 'points';
  int _dominoBet = 500;

  // Available Bet Tiers
  StreamSubscription? _roomSubscription;
  StreamSubscription? _userSub;
  LudoUiState _uiState = LudoUiState.menu;

  String? _ludoDiceTheme; // Active dice theme
  Map<String, String>? _ludoDiceUrls; // Remote dice face URLs

  // ── UI State (Managed via Controller for Separation) ───────────────────
  late final LudoUiController _uiController;
  final UserService _userService = UserService();
  final Map<int, int> _lastSeenInteractions = {}; // Index -> Timestamp

  bool get _showGameLog => _uiController.showGameLog;
  bool get _isChatInputOpen => _uiController.isChatInputOpen;
  Map<int, dynamic> get _activeInteractions => _uiController.activeInteractions;

  // Audio State
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _isMuted = false;

  // Game State
  late int _currentPlayer; // Start with the randomly assigned local player

  // Advanced Dice State
  List<int> _diceRolled = [];
  bool _isAiThinking = false; // Guard for bot logic
  List<int> _nextRollIsSix = [0, 0, 0, 0]; // Guaranteed 6 for next roll

  bool _isRolling = false;
  bool _canRoll = true; // Can the player roll now?
  bool _hasEarnedBonusDuringTurn =
      false; // Persistent flag for current multi-move turn
  bool _isMusicInitializing = false;

  // Audio Settings
  double _musicVolume = 0.85;
  double _diceVolume = 1.0;
  double _sfxVolume = 0.85;
  final Map<int, double> _playerVolumes = {};

  // Timer & Auto-Play
  Timer? _turnTimer;
  bool _isBlackoutActive = false;
  bool _magicToolsEnabled = false;

  int _remainingTime = kTurnDurationSeconds;

  // Custom Blue Button
  int _blueButtonClicks = 0; // Total clicks in the entire game (limit 8)
  int _blueButtonClicksThisTurn = 0; // Clicks in current turn (limit 3)
  double _reRollGraceRemaining = 0.0;
  Timer? _reRollGraceTimer;

  final Set<int> _autoPlayingIndices =
      {}; // Indices of players currently in auto-play mode

  int _currentMatchMaxPlayers = 2;
  int _privateTableMaxPlayers = 2;
  String _currentMatchMode = 'classic'; // 'classic' or 'arrow'
  bool _isTeamMode = false; // Whether this is a 2v2 team game
  List<int> _winners = []; // Indices of players who have finished
  bool _hasSeenMyWinDialog =
      false; // Prevents re-showing own win dialog (local logic)
  bool _isWinDialogShowing =
      false; // Guard against multiple dialogs building up

  // Online Players Data
  final Map<int, String> _onlinePlayerNames = {};
  final Map<int, String?> _onlinePlayerImages = {};
  final Map<int, String> _onlinePlayerUids = {};
  final Map<int, bool> _onlinePresence = {}; // pIdx -> isOnline
  final Map<int, Timer?> _disconnectTimers = {};
  String? _roomHostId;
  int _serverTimeOffset = 0; // Difference between local and server clock
  int? _matchMagicSeed; // Online match magic tiles seed
  int _lastServerHandledTime = 0;

  // Swiping Game Menus
  late final Stream<DocumentSnapshot> _settingsStream;
  late PageController _gamePageController;
  int _currentGamePageIndex = 0;

  // Bot matchmaking (client-side) — used when no players are found quickly
  Timer? _botMatchmakingTimer;
  bool _botMatchmakingScheduled = false;
  bool _botsEnabled = false;

  bool _sentHurryThisTurn = false;
  final Set<int> _botIndices = {};
  final Set<int> _leavers =
      {}; // Track players who left (online timeout or manual)
  final Set<int> _silencedPlayerIndices = {}; // Track locally silenced players
  final Map<int, LudoBotProfile> _botProfiles = {};

  // ── Music state (used by extension methods) ──────────────────────────────
  String _currentMusicAsset = '';
  bool _isSwitchingMusic = false;

  // ── Game Chat / Event Log ────────────────────────────────────────────────
  final List<LudoGameLogEntry> _gameLog = [];
  // bool _showGameLog = false; // toggle log panel visibility
  final ScrollController _logScrollController = ScrollController();
  final ScrollController _chatScrollController = ScrollController();
  final TextEditingController _chatInputController = TextEditingController();
  // bool _isChatInputOpen = false;
  int _unreadMessagesCount = 0;

  // ── Player Themes Storage ───────────────────────────────────────────
  // لكل لاعب شكل وحزمة حجراته والسمة الخاصة بالنرد
  final Map<int, String> _playerTokenShapes = {};
  final Map<int, String> _playerTokenThemes = {};
  final Map<int, Map<String, String>> _playerTokenUrlsMap = {};
  final Map<int, String> _playerDiceThemes = {};
  final Map<int, Map<String, String>> _playerDiceUrlsMap = {};

  void _addToLog(LudoGameLogEntry entry) {
    _gameLog.add(entry);
    if (_gameLog.length > kMaxLogEntries) _gameLog.removeAt(0);
    // auto-scroll if panel or chat input is open
    if (_showGameLog || _isChatInputOpen) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  ImageProvider? _getAvatarProvider(String? photo) {
    if (photo == null || photo.isEmpty) return null;
    if (photo.startsWith('assets/') || photo.contains('assets/')) {
      // Handle cases like 'file:///assets/...' or just 'assets/...'
      String path = photo;
      if (photo.contains('assets/')) {
        path = photo.substring(photo.indexOf('assets/'));
      }
      return AssetImage(path);
    }
    if (!photo.startsWith('http')) {
      // Fallback for non-url local paths
      return AssetImage(photo);
    }
    return NetworkImage(photo);
  }

  // Players: 0: Blue (User), 1: Green (AI)
  // Mapping: Player 0 -> Game Index 3 (Blue, Bottom-Left)
  //          Player 1 -> Game Index 1 (Green, Top-Right)
  final List<List<int>> _tokens = [
    [0, 0, 0, 0], // Game Index 0 (Red) - Unused
    [0, 0, 0, 0], // Game Index 1 (Green) - Player 1 (AI)
    [0, 0, 0, 0], // Game Index 2 (Yellow) - Unused
    [0, 0, 0, 0], // Game Index 3 (Blue) - Player 0 (User)
  ];

  // User Profile Data
  String _userName = "أنت";
  String? _userProfileImage;
  int _userCoins = 0;
  int _userDiamonds = 0;
  int _userLevel = 1;
  int _userLeagueRank = 0;
  int _userBestLeagueRank = 0;

  @override
  void initState() {
    super.initState();
    _settingsStream = FirebaseFirestore.instance
        .collection('app_settings')
        .doc('global')
        .snapshots();
    _gamePageController = PageController();
    _currentPlayer = _myPlayerIndex;

    // Load saved token shape for current player
    _loadPlayerTokenShape(_myPlayerIndex);

    // Create game with the CORRECT saved shape immediately (no async wait)
    // Apply to ALL 4 indices so random color assignment never breaks the shape
    _ludoGame = LudoGame(
      playerCount: 2,
      onTokenTapped: _handleTokenTap,
      boardTheme: _boardTheme,
      gameMode: _gameMode,
      currentMatchMode: _currentMatchMode,
      magicSeed: _matchMagicSeed,
      onlineRoomId: _roomId,
      localPlayerId: _myPlayerIndex.toString(),
      magicToolsEnabled: _magicToolsEnabled,
      initialShapes: {
        0: _getPlayerTokenShape(0),
        1: _getPlayerTokenShape(1),
        2: _getPlayerTokenShape(2),
        3: _getPlayerTokenShape(3),
      },
      initialThemes: _playerTokenThemes,
      initialUrlsMap: _playerTokenUrlsMap,
      onMagicEffect: _handleMagicEffect,
    );
    _uiController = LudoUiController();
    _ludoGame.updateRotation(_myPlayerIndex);

    // Load ALL preferences in one shot, then re-apply to game
    _loadAllPreferences();
    _loadAudioSettings();
    _listenToUserData();
    _initMusic();
    _initVoiceChat();

    // Sync Server Time Offset
    FirebaseDatabase.instance.ref(".info/serverTimeOffset").onValue.listen((
      event,
    ) {
      if (event.snapshot.value != null) {
        if (mounted) {
          setState(() {
            _serverTimeOffset = (event.snapshot.value as num).toInt();
          });
          debugPrint(
            "[LudoScreen] Server Time Offset synced: $_serverTimeOffset",
          );
        }
      }
    });

    // Check if we started the screen from a direct room invite/code
    if (widget.roomId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startOnlineGame(roomId: widget.roomId);
      });
    }
  }

  @override
  void dispose() {
    _gamePageController.dispose();
    _musicPlayer.dispose();
    _roomSubscription?.cancel();
    _turnTimer?.cancel();
    _botMatchmakingTimer?.cancel();
    _uiController.dispose();
    _logScrollController.dispose();
    _chatScrollController.dispose();
    _chatInputController.dispose();
    _reRollGraceTimer?.cancel();
    _disconnectTimers.values.forEach((timer) => timer?.cancel());
    _disconnectTimers.clear();
    _leaveVoiceChat();
    _userSub?.cancel();
    super.dispose();
  }

  // ── _handleMagicEffect ─────────────────────────────────────────────────────
  void _handleMagicEffect(String type, bool active) {
    if (type == 'blackout') {
      setState(() {
        _isBlackoutActive = active;
      });
      _ludoGame.syncBlackout(active);

      if (active) {
        _addToLog(
          LudoGameLogEntry(
            type: LudoGameLogType.magic,
            playerName: 'المعلم',
            playerColor: Colors.deepPurple,
            message: 'تم تفعيل تعويذة الحظ! استعد للمفاجآت ✨',
          ),
        );
      }
    }
  }

  void _quitToMenu() {
    // 1. Online cleanup
    if (_roomId != null && _gameMode == 'online') {
      if (_uiState == LudoUiState.playing && _currentMatchMaxPlayers == 2) {
        // In 1v1 game, indices are strictly 0 and 2.
        int opponentIndex = (_myPlayerIndex == 0) ? 2 : 0;
        
        final Map<String, dynamic> winUpdates = {};
        winUpdates['status'] = 'finished';
        winUpdates['state/winners'] = [opponentIndex];
        winUpdates['state/lastUpdate'] = ServerValue.timestamp;
        LudoService().updateGameState(_roomId!, winUpdates);

        // Record a loss for the local player (leaver)
        final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
        if (myUid != null) {
          _userService.updateUser(
            uid: myUid,
            data: {
              'gamesPlayed': FieldValue.increment(1),
              'wins': FieldValue.increment(0),
              'losses': FieldValue.increment(1),
              'gameStats.ludo.played': FieldValue.increment(1),
              'gameStats.ludo.wins': FieldValue.increment(0),
              'gameStats.ludo.losses': FieldValue.increment(1),
            },
          ).catchError((e) => debugPrint('[LudoStats] Quit loss error: $e'));
        }
      }
      LudoService().leaveRoom(_roomId!);
    }

    // 2. Resource cleanup
    _roomSubscription?.cancel();
    _roomSubscription = null;
    _turnTimer?.cancel();
    _turnTimer = null;
    _botMatchmakingTimer?.cancel();
    _botMatchmakingTimer = null;
    _reRollGraceTimer?.cancel();
    _reRollGraceTimer = null;
    _disconnectTimers.values.forEach((timer) => timer?.cancel());
    _disconnectTimers.clear();
    _leaveVoiceChat();

    // 3. State reset
    setState(() {
      _uiState = LudoUiState.menu;
      _roomId = null;
      _gameMode = 'local';
      _onlinePlayerNames.clear();
      _onlinePlayerImages.clear();
      _onlinePresence.clear();
      _autoPlayingIndices.clear();
      _botIndices.clear();
      _winners.clear();
      _diceRolled.clear();
      _nextRollIsSix = [0, 0, 0, 0];
      _canRoll = true;
      _isRolling = false;
      _hasSeenMyWinDialog = false;
      _isWinDialogShowing = false;
      _hasStartedTransition = false;
      _matchFoundAnimation = false;
      _matchCountdown = 3;
      _showTotalPotInMatchmaking = false;
    });

    // 4. Engine reset
    _ludoGame.reset();
  }

  @override
  Widget build(BuildContext context) {
    // Determine which UI to show based on the current state
    Widget body;
    if (_uiState == LudoUiState.menu) {
      body = _buildMainMenu();
    } else if (_uiState == LudoUiState.betSelection) {
      body = _buildBetSelectionScreen();
    } else if (_uiState == LudoUiState.dominoSelection) {
      body = _buildDominoSelectionScreen();
    } else if (_uiState == LudoUiState.twoFourSelection) {
      body = _buildTwoFourSelectionScreen();
    } else if (_uiState == LudoUiState.teamUpSelection) {
      body = _buildTeamUpSelectionScreen();
    } else if (_uiState == LudoUiState.privateTableSelection) {
      body = _buildPrivateTableSelectionScreen();
    } else if (_uiState == LudoUiState.dominoPrivateSelection) {
      body = _buildDominoPrivateSelectionScreen();
    } else if (_uiState == LudoUiState.friendInvitation) {
      body = _buildFriendInvitationScreen();
    } else if (_uiState == LudoUiState.matchmaking) {
      body = _buildConnectingOverlay();
    } else {
      // The core ludo body is reactive only to UI notifications
      // We use 'child' to keep the GameWidget stable and never rebuilt by UI changes
      body = ListenableBuilder(
        listenable: _uiController,
        child: GameWidget(game: _ludoGame),
        builder: (context, gameBoard) => _buildMainBody(gameBoard),
      );
    }

    // Protection from accidental back button press during active matches or matchmaking
    bool needsConfirmation =
        _uiState == LudoUiState.playing || _uiState == LudoUiState.matchmaking;

    return WillPopScope(
      onWillPop: () async {
        // 1. If in an active game or matchmaking, ask for confirmation
        if (needsConfirmation) {
          final bool shouldPop = await _showExitConfirmationDialog();
          if (shouldPop && mounted) {
            // Exit the match but stay in the Ludo screen (return to menu)
            _quitToMenu();
          }
          return false; // Prevent system pop, we handle state manually
        }

        // 2. If in a sub-menu (like bet selection), return to main menu
        if (_uiState != LudoUiState.menu) {
          setState(() {
            _uiState = LudoUiState.menu;
          });
          return false; // Prevent system pop
        }

        // 3. If in main menu, exit the screen and go back to App Home
        return true; // Allow system pop
      },
      child: body,
    );
  }
}

// (Internal Painters and Log classes have been moved to modular files)
