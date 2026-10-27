// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api
part of 'ludo_screen.dart';

/// Online gameplay, matchmaking, voice chat, and room management.
extension LudoScreenOnline on _LudoScreenState {
  void _initVoiceChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final voiceService = Provider.of<VoiceRoomService>(
          context,
          listen: false,
        );
        final myId = auth.FirebaseAuth.instance.currentUser?.uid;
        final voiceRoomId = _roomId ?? "ludo_local_$myId";

        debugPrint("[LudoScreen] Initializing Voice Chat for: $voiceRoomId");

        // Join specifically as broadcaster for Ludo
        await voiceService.joinGameChannel(voiceRoomId);
        await voiceService.setGameMute(true);
        // Force audio to Speakerphone
        await voiceService.setEnableSpeakerphone(true);

        debugPrint(
          "[LudoScreen] Voice Chat initialized for room: $voiceRoomId",
        );
      } catch (e) {
        debugPrint("[LudoScreen] Voice Chat Init Error: $e");
      }
    });
  }

  void _leaveVoiceChat() {
    try {
      final voiceService = Provider.of<VoiceRoomService>(
        context,
        listen: false,
      );
      voiceService.leaveGameChannel();
    } catch (e) {
      debugPrint("[LudoScreen] Voice Chat Leave Error: $e");
    }
  }

  Future<void> _toggleMic() async {
    final voiceService = Provider.of<VoiceRoomService>(context, listen: false);
    try {
      await voiceService.toggleGameMute();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString(),
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _reinitGameWithTheme() {
    // If the game is already running, just update its themes without resetting positions
    if (_uiState == LudoUiState.playing || _uiState == LudoUiState.menu) {
      _ludoGame.updateThemes(
        bTheme: _boardTheme,
        bImageUrl: _boardImageUrl,
        pShapes: {
          0: _getPlayerTokenShape(0),
          1: _getPlayerTokenShape(1),
          2: _getPlayerTokenShape(2),
          3: _getPlayerTokenShape(3),
        },
        pThemes: _playerTokenThemes,
        pUrlsMap: _playerTokenUrlsMap,
      );
      _updateGame();
      if (_uiState == LudoUiState.menu) {
        // full re-init only when in menu
      } else {
        return; // Skip the destructive part
      }
    }

    _ludoGame.reset(); // Crucial: Reset Flame engine state
    _blueButtonClicks = 0;
    _winners = [];
    _leavers.clear();
    _hasSeenMyWinDialog = false;
    _isWinDialogShowing = false;
    _diceRolled = [];
    _hasEarnedBonusDuringTurn = false;
    _reRollGraceRemaining = 0;
    _currentPlayer = 0; // Always start with player 0 (Red)
    _isAiThinking = false;
    _canRoll = true;
    _isRolling = false;
    _remainingTime = kTurnDurationSeconds;

    // Reset tokens for a fresh game session
    for (int i = 0; i < 4; i++) {
      for (int t = 0; t < 4; t++) {
        _tokens[i][t] = 0;
      }
    }

    _ludoGame = LudoGame(
      playerCount: (_gameMode == 'local' && !_botsEnabled) ? 2 : 4,
      onTokenTapped: _handleTokenTap,
      boardTheme: _boardTheme,
      gameMode: _gameMode,
      currentMatchMode: _currentMatchMode,
      magicSeed: _matchMagicSeed,
      onlineRoomId: _roomId,
      localPlayerId: _myPlayerIndex.toString(),
      magicToolsEnabled: _magicToolsEnabled,
      // Set ALL players' shapes from saved preferences
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
    _ludoGame.updateRotation(_myPlayerIndex);
    _ludoGame.updateVolumes(dice: _diceVolume, sfx: _sfxVolume);
    _ludoGame.isMuted = _isMuted;
    _updateGame();
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "تأكيد المغادرة",
          style: TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          "هل أنت متأكد من رغبتك في المغادرة؟\nسيتم اعتبارك خاسراً وتنتهي اللعبة للجميع.",
          style: TextStyle(color: Colors.white70, fontFamily: 'Tajawal'),
          textAlign: TextAlign.center,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "إلغاء",
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleForcedExit();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "تأكيد",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
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

  void _backToMenu() {
    if (!mounted) return;

    // Clean up room subscription immediately
    _roomSubscription?.cancel();
    _roomSubscription = null;

    // Cancel bot timer first to prevent more bots being added
    _botMatchmakingTimer?.cancel();
    _botMatchmakingTimer = null;
    _botMatchmakingScheduled = false;

    // Stop all game timers
    _turnTimer?.cancel();
    _turnTimer = null;
    _reRollGraceTimer?.cancel();
    _reRollGraceTimer = null;
    _disconnectTimers.values.forEach((timer) => timer?.cancel());
    _disconnectTimers.clear();

    if (_roomId != null) {
      final wasMatchmaking =
          _uiState == LudoUiState.matchmaking ||
          _uiState == LudoUiState.friendInvitation;
      if (wasMatchmaking) {
        final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
        bool isHost = (_roomHostId == myUid);
        
        if (isHost) {
          // Host: delete the room entirely
          LudoService().deleteRoom(_roomId!);
          debugPrint('[LudoScreen] Host cancelled matchmaking — room $_roomId deleted.');
        } else {
          // Guest: just leave the room
          LudoService().leaveRoom(_roomId!);
          debugPrint('[LudoScreen] Guest left matchmaking room $_roomId.');
        }
      } else {
        // During a live game: just remove the player (regular leave)
        LudoService().leaveRoom(_roomId!);
      }
    }

    setState(() {
      _uiState = LudoUiState.menu;
      _roomId = null;
      _onlinePlayerNames.clear();
      _onlinePlayerImages.clear();
      _onlinePlayerUids.clear();
      _botIndices.clear();
      _botProfiles.clear();
      _leavers.clear();
      _winners.clear();
      _autoPlayingIndices.clear();
      _matchFoundAnimation = false;
      _hasStartedTransition = false;
    });
    _switchMusicTrack();
  }

  void _handleForcedExit() {
    if (_gameMode == 'online' && _roomId != null) {
      _handlePlayerTimeoutWin(_myPlayerIndex, isSelf: true);
    }
    _backToMenu();
  }

  Future<void> _startOnlineGame({
    int maxPlayers = 4,
    String mode = 'classic',
    String? roomId,
    int? betAmount,
    bool isPrivate = false,
    bool isTeamMode = false,
  }) async {
    // Check balance before proceeding
    final int currentBet = betAmount ?? _selectedBet;
    
    // Robust balance check: if local state says 0, try fetching fresh data once
    if (_userCoins < currentBet) {
      final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
      if (myUid != null) {
        try {
          final freshUser = await UserService().getUser(myUid);
          if (freshUser != null) {
            _userCoins = freshUser.coins;
          }
        } catch (e) {
          debugPrint('[LudoBalance] Error fetching fresh balance: $e');
        }
      }
    }

    if (_userCoins < currentBet) {
      _showInsufficientFundsDialog();
      return;
    }

    // 1. Initial State Setup (Non-destructive)
    setState(() {
      _gameMode = 'online';
      _currentMatchMode = mode;
      _currentMatchMaxPlayers = maxPlayers;
      _isTeamMode = isTeamMode;
      _selectedBet = betAmount ?? _selectedBet;
      _matchFoundAnimation = false;
      _hasStartedTransition = false;
      _botsEnabled = false;
      _botMatchmakingScheduled = false;
      _sentHurryThisTurn = false;
      // Only set matchmaking state if we are NOT joining a specific room
      if (roomId == null) {
        _uiState = isPrivate ? LudoUiState.friendInvitation : LudoUiState.matchmaking;
      }
    });

    // Reset session data
    _onlinePlayerNames.clear();
    _onlinePlayerImages.clear();
    _onlinePlayerUids.clear();
    _leavers.clear();
    _winners.clear();
    _autoPlayingIndices.clear();

    _switchMusicTrack();

    // Reset previous room subscription
    _roomId = null;
    _lastServerHandledTime = 0;
    await _roomSubscription?.cancel();
    _roomSubscription = null;

    try {
      debugPrint('[LudoScreen] Starting Online Game...');
      final ludoService = LudoService();

      // ── Room ID Resolution (Full ID vs Short Code) ─────────────────────────
      String? actualRoomId = roomId;
      int roomMaxPlayers = maxPlayers;
      String roomMode = mode;
      bool roomIsTeam = isTeamMode;

      if (roomId != null && roomId.length <= 6) {
        // Try searching by shortCode first
        debugPrint('[LudoScreen] Searching for room by shortCode: $roomId');
        final foundId = await ludoService.findRoomByShortCode(roomId);
        if (foundId == null) {
          throw Exception("رمز الغرفة غير صحيح");
        }
        actualRoomId = foundId;
      }

      // If we are joining a specific room, check its status and settings first
      if (actualRoomId != null) {
        final roomSnap = await FirebaseDatabase.instance
            .ref('ludo_rooms/$actualRoomId')
            .get();
        if (!roomSnap.exists) {
          throw Exception("هذه الغرفة لم تعد متوفرة");
        }
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          roomSnap.value as Map,
        );
        final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
        final players = data['players'] as Map?;
        final bool alreadyIn =
            myUid != null && players != null && players.containsKey(myUid);

        if (data['status'] == 'finished' && !alreadyIn) {
          throw Exception("عذراً، هذه المباراة انتهت بالفعل");
        }

        // Extract official room settings to avoid overriding them with defaults
        roomMaxPlayers = (data['maxPlayers'] as num?)?.toInt() ?? maxPlayers;
        roomMode = data['mode'] as String? ?? mode;
        roomIsTeam = data['isTeamMode'] ?? isTeamMode;
        final bool roomHasMagic = (data['state'] != null && data['state']['magicSeed'] != null);

        // Apply UI state based on verified room status
        if (mounted) {
          setState(() {
            _isTeamMode = roomIsTeam;
            _magicToolsEnabled = roomHasMagic;
            _currentMatchMaxPlayers = roomMaxPlayers;
            _currentMatchMode = roomMode;
            if (data['status'] == 'waiting') {
              _uiState = LudoUiState.friendInvitation;
            } else {
              // Joining a game in progress
              _uiState = LudoUiState.matchmaking;
            }
          });
        }
        
        if (!alreadyIn && players != null && players.length >= roomMaxPlayers) {
          throw Exception("هذه الطاولة ممتلئة باللاعبين");
        }
      } else {
        // Random matchmaking or Private create: set UI state
        if (mounted) {
          setState(() {
            _uiState = isPrivate ? LudoUiState.friendInvitation : LudoUiState.matchmaking;
          });
        }
      }

      _isWinDialogShowing = false;
      _hasSeenMyWinDialog = false;
      _hasSyncedRotation = false; // Ensure room rotation syncs

      final joinedRoomId = await ludoService.joinOrCreateRoom(
        roomId: actualRoomId,
        betAmount: _selectedBet,
        maxPlayers: roomMaxPlayers,
        mode: roomMode,
        name: _userName,
        photo: _userProfileImage,
        forceNewRoom: isPrivate,
        isTeamMode: _isTeamMode,
        magicToolsEnabled: _magicToolsEnabled,
      );

      debugPrint('[LudoScreen] Joined Room: $joinedRoomId');
      if (!mounted) return;

      setState(() {
        _roomId = joinedRoomId;
        _currentMatchMode = roomMode;
        _currentMatchMaxPlayers = roomMaxPlayers;
      });
      _resetInteractions(); // Clear previous game session interactions
      _initVoiceChat(); // Re-init voice with the correct online room ID

      // Sync local preference immediately after joining
      ludoService.updatePlayerPreference(
        joinedRoomId,
        tokenShape: _getPlayerTokenShape(_myPlayerIndex),
        boardTheme: _boardTheme,
        tokenTheme: _ludoTokenTheme,
        diceTheme: _ludoDiceTheme,
        hallTheme: _hallTheme,
      );

      debugPrint('[LudoScreen] Subscribing to room updates...');
      _roomSubscription = ludoService
          .streamRoom(joinedRoomId)
          .listen(
            (event) {
              debugPrint(
                '[LudoScreen] Room Update received. Value null: ${event.snapshot.value == null}',
              );
              _handleRoomUpdate(event);
            },
            onError: (err) {
              debugPrint('[LudoScreen] Room Subscription error: $err');
            },
          );
    } catch (e) {
      debugPrint('[LudoScreen] Online Game Error: $e');
      if (!mounted) return;
      setState(() {
        _uiState = LudoUiState.menu;
      });
      _switchMusicTrack();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في الاتصال: $e')));
    }
  }

  void _startBotMatchmakingTimer() {
    if (_botMatchmakingScheduled) return;
    _botMatchmakingTimer?.cancel();
    if (_roomId == null) return;
    if (_uiState != LudoUiState.matchmaking) return;

    // Wait 20–30 s then inject a bot if still waiting for opponents
    final delaySeconds = 20 + _rng.nextInt(10);
    _botMatchmakingScheduled = true;
    debugPrint('[BotMM] Timer started: ${delaySeconds}s');
    _botMatchmakingTimer = Timer(Duration(seconds: delaySeconds), () {
      _botMatchmakingScheduled = false;
      _activateBotsIfStillWaiting();
    });
  }

  Future<void> _activateBotsIfStillWaiting() async {
    if (!mounted) return;
    if (_uiState != LudoUiState.matchmaking) return;
    if (_hasStartedTransition) return;

    final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
    if (_roomHostId != myUid) {
      debugPrint('[BotMM] I am not the host. Skipping bot creation.');
      return;
    }

    // If a real opponent already joined (2p) or room full (4p), do nothing
    if (_onlinePlayerNames.length >= _currentMatchMaxPlayers) {
      debugPrint('[BotMM] Room already full. No bot needed.');
      return;
    }

    debugPrint('[BotMM] Filling empty slots with bots.');

    // ── Build bot profiles for all empty slots ────────────────────────────────
    List<int> slotsToFill = [];
    if (_currentMatchMaxPlayers == 2) {
      slotsToFill = [(_myPlayerIndex + 2) % 4];
    } else {
      slotsToFill = [0, 1, 2, 3];
      slotsToFill.remove(_myPlayerIndex);
    }

    int botsAdded = 0;
    for (int botIdx in slotsToFill) {
      if (_onlinePlayerNames.containsKey(botIdx)) continue;

      // Small delay before each bot "joins" for realism
      await Future.delayed(Duration(milliseconds: 1200 + _rng.nextInt(1500)));
      if (!mounted || _uiState != LudoUiState.matchmaking) return;

      final profile = LudoBotProfile.random(_rng);
      final botUid =
          'bot_${botIdx}_${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(10000)}';

      await LudoService().addBotPlayer(
        roomId: _roomId!,
        botUid: botUid,
        index: botIdx,
        name: profile.name,
        photo: profile.botImage,
      );
      botsAdded++;
    }

    if (botsAdded > 0) {
      debugPrint('[BotMM] Added $botsAdded bots to fill the room.');
    }

    // Double check full count before locking
    if (_roomId != null) {
      // Small pause to allow local sync of the last bot if needed
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      LudoService()
          .updateGameState(_roomId!, {
            'status': 'playing',
            'status_bet':
                'playing_${_selectedBet}_${_currentMatchMaxPlayers}_$_currentMatchMode',
          })
          .catchError((e) => debugPrint('[BotMM] Room lock error: $e'));
    }
  }

  // ignore: unused_element
  // Kept for potential future use in 4-player online rooms with partial bots.

  void _handleRoomUpdate(DatabaseEvent event) {
    if (_isWinDialogShowing) return;

    // ── Context Guard ──
    // If we are in the menu or have no active room ID, ignore background updates.
    if (_uiState == LudoUiState.menu || _roomId == null) {
      _roomSubscription?.cancel();
      _roomSubscription = null;
      return;
    }

    if (event.snapshot.value == null) {
      // Room was deleted
      if (_uiState == LudoUiState.friendInvitation ||
          _uiState == LudoUiState.matchmaking) {
        debugPrint('[LudoScreen] Room deleted. Returning to menu.');
        _backToMenu();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إلغاء المباراة من قبل المضيف')),
          );
        }
      }
      return;
    }

    final roomData = Map<String, dynamic>.from(event.snapshot.value as Map);
    final playersData = roomData['players'] as Map?;
    final gameState = roomData['state'] as Map?;
    final bool isTeam = roomData['isTeamMode'] ?? false;

    if (gameState == null || !mounted) return;

    // ── 0. Finish Guard ──
    // If the game is already finished and we are showing the dialog, ignore further updates
    // to prevent flickering and redundant rebuilds.
    if (roomData['status'] == 'finished' && _isWinDialogShowing) return;

    if (_isTeamMode != isTeam) {
      setState(() => _isTeamMode = isTeam);
    }

    // ── 0. Close check ──────────────────────────────────────────────────────
    // If the room status is 'closed' and we are still in lobby/waiting, kick out.
    final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
    final isHost = (gameState['hostId'] as String?) == myUid;
    if (roomData['status'] == 'closed' &&
        !isHost &&
        (_uiState == LudoUiState.friendInvitation ||
            _uiState == LudoUiState.matchmaking)) {
      debugPrint('[LudoScreen] Room closed by host. Kicking to menu.');
      _backToMenu();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('قام المضيف بإغلاق الغرفة')));
      return;
    }

    // ── 1. Shielded Synchronization ──────────────────────────────────────────
    // We only sync game-critical state (turn, tokens, dice) if 'lastUpdate' changed.
    // This prevents "Interaction updates" (stickers/chat) from resetting the state
    // if the Firebase snapshot for game state is slightly delayed or stale.
    final int serverUpdate = (gameState['lastUpdate'] as num?)?.toInt() ?? 0;
    final bool isFirstSync = _lastServerHandledTime == 0;
    final bool stateChanged = serverUpdate > _lastServerHandledTime;

    // Capture "Before" state to detect meaningful changes for AI triggering
    final int oldCurrentPlayer = _currentPlayer;
    final bool oldIsRolling = _isRolling;

    setState(() {
      // ── A. Metadata & Players (Always Sync) ─────────────────────────────────
      if (gameState['magicSeed'] != null) {
        final newSeed = (gameState['magicSeed'] as num?)?.toInt() ?? 0;
        if (newSeed != _matchMagicSeed) {
          _matchMagicSeed = newSeed;
          _ludoGame.ludoXManager?.generateMagicTiles(seed: newSeed);
        }
      }

      // مزامنة مواقع العناصر السحرية الفورية بالشبكة لجميع اللاعبين والمشاهدين
      if (gameState['magicTiles'] != null) {
        try {
          final dbTiles = Map<dynamic, dynamic>.from(gameState['magicTiles'] as Map);
          final Map<int, MagicTileType> parsedTiles = {};
          dbTiles.forEach((key, val) {
            int idx = int.parse(key.toString());
            MagicTileType type = MagicTileType.values.firstWhere(
              (e) => e.name == val.toString(),
              orElse: () => MagicTileType.normal,
            );
            if (type != MagicTileType.normal) {
              parsedTiles[idx] = type;
            }
          });
          _ludoGame.ludoXManager?.updateTilesDirectly(parsedTiles);
        } catch (_) {}
      }

      // مزامنة كمية النردات السحرية المكدسة لجميع الأجهزة والخصوم والمشاهدين أونلاين
      if (gameState['nextRollIsSix'] != null) {
        try {
          final List<dynamic> raw = gameState['nextRollIsSix'] as List;
          for (int i = 0; i < 4; i++) {
            if (i < raw.length) {
              _nextRollIsSix[i] = (raw[i] as num).toInt();
            }
          }
        } catch (_) {}
      }

      final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
      _roomHostId = (gameState['hostId'] as String?);

      if (playersData != null && myUid != null) {
        Set<int> foundIndices = {};

        playersData.forEach((uid, pData) {
          final data = pData as Map;
          int? idxRaw = (data['index'] as num?)?.toInt();
          if (idxRaw == null) return; // Skip players with missing indices
          int idx = idxRaw;
          foundIndices.add(idx);
          bool isOnline = data['online'] == true;
          bool isBot = data['isBot'] == true;
          bool isLeft = data['left'] == true;

          // Track presence
          _onlinePresence[idx] = isOnline || isBot;

          // Handle explicit/graceful leavers instantly
          // Modified: Also check if they are NOT already auto-playing to avoid infinite loops
          if (isLeft && !_leavers.contains(idx) && !_autoPlayingIndices.contains(idx)) {
            if (_currentMatchMaxPlayers == 2 && idx != _myPlayerIndex && _uiState == LudoUiState.playing) {
              debugPrint('[Presence] 1v1 Opponent left. Declaring me as winner.');
              final Map<String, dynamic> winUpdates = {};
              winUpdates['status'] = 'finished';
              winUpdates['state/winners'] = [_myPlayerIndex];
              winUpdates['state/lastUpdate'] = ServerValue.timestamp;
              LudoService().updateGameState(_roomId!, winUpdates);
              _showWinDialog(_myPlayerIndex);
              return;
            }

            if (_isEffectiveMaster) {
              _handlePlayerTimeoutWin(idx);
            } else if (idx == _myPlayerIndex) {
              _handlePlayerTimeoutWin(idx, isSelf: true);
            }
          }

          // Handle Disconnection Timer (1-minute grace)
          // Modified: Don't start timers for bots, myself, or already auto-playing players
          if (!isOnline && !isBot && idx != _myPlayerIndex && !_autoPlayingIndices.contains(idx)) {
            if (!_disconnectTimers.containsKey(idx)) {
              debugPrint(
                '[Presence] Player $idx offline. Starting 60s timer.',
              );
              _disconnectTimers[idx] = Timer(const Duration(seconds: 60), () {
                _handlePlayerTimeoutWin(idx);
              });
            }
          } else {
            // Player is back or it's me/bot
            if (_disconnectTimers.containsKey(idx)) {
              debugPrint(
                '[Presence] Player $idx back online. Cancelling timer.',
              );
              _disconnectTimers[idx]?.cancel();
              _disconnectTimers.remove(idx);
            }
          }
        });

        // Any player in _onlinePlayerNames that wasn't found in playersData has disconnected completely
        // This handles cases where onDisconnect().remove() deleted their node
        if (_gameMode == 'online' && roomData['status'] == 'playing') {
          for (final idx in _onlinePlayerNames.keys) {
            if (!foundIndices.contains(idx) &&
                idx != _myPlayerIndex &&
                !_botIndices.contains(idx)) {
              _onlinePresence[idx] = false;
              if (!_disconnectTimers.containsKey(idx)) {
                debugPrint(
                  '[Presence] Player $idx entirely missing. Starting 60s timer.',
                );
                _disconnectTimers[idx] = Timer(
                  const Duration(seconds: 60),
                  () {
                    _handlePlayerTimeoutWin(idx);
                  },
                );
              }
            }
          }
        }

        final myData = playersData[myUid] as Map?;
        if (myData != null) {
          int newIdx = (myData['index'] as num?)?.toInt() ?? _myPlayerIndex;
          if (newIdx != _myPlayerIndex || !_hasSyncedRotation) {
            _myPlayerIndex = newIdx;
            _ludoGame.updateRotation(_myPlayerIndex);
            _hasSyncedRotation = true;
          }
        }
      }

      // ── B. Gameplay State (Only if lastUpdate progressed and mode is Online) ──
      if (_gameMode == 'online' && (stateChanged || isFirstSync)) {
        _lastServerHandledTime = serverUpdate;
        // Sync flying token for spectating clients
        if (gameState['flyingToken'] != null) {
          try {
            final fToken = Map<String, dynamic>.from(gameState['flyingToken'] as Map);
            int p = (fToken['p'] as num).toInt();
            int t = (fToken['t'] as num).toInt();
            // تثبيت الحجر عند مركز الصاروخ للمشاهدين أولاً لضمان انطلاق مثالي
            _ludoGame.snapTokenToProgress(p, t, _ludoGame.tokens[p][t]);
            _ludoGame.setFlyingToken(p, t);
          } catch (_) {}
        }

        // Sync Tokens
        final rawTokens = gameState['tokens'];
        if (rawTokens != null) {
          try {
            List<List<int>> incoming = List.generate(4, (i) {
              dynamic row;
              if (rawTokens is List) {
                row = (i < rawTokens.length) ? rawTokens[i] : null;
              } else if (rawTokens is Map) {
                row = rawTokens[i] ?? rawTokens['$i'];
              }

              if (row is List) {
                return row.map((t) => (t as num?)?.toInt() ?? 0).toList();
              } else if (row is Map) {
                return List.generate(
                  4,
                  (j) => ((row[j] ?? row['$j'] ?? 0) as num?)?.toInt() ?? 0,
                );
              }
              return _tokens[i].toList();
            });

            for (int i = 0; i < 4; i++) {
              _tokens[i] = incoming[i];
            }
          } catch (e) {
            debugPrint('[RoomSync] Token error: $e');
          }
        }

        // Sync Winners
        if (gameState['winners'] != null) {
          _winners = List<int>.from(
            (gameState['winners'] as List).map(
              (w) => (w as num?)?.toInt() ?? 0,
            ),
          );
          if (_winners.contains(_myPlayerIndex) && !_hasSeenMyWinDialog) {
            _hasSeenMyWinDialog = true;
            _showWinDialog(_myPlayerIndex);
          }
        }

        // Sync Leavers
        if (gameState['leavers'] != null) {
          final incomingLeavers = List<int>.from(
            (gameState['leavers'] as List).map(
              (l) => (l as num?)?.toInt() ?? 0,
            ),
          );

          // Detect new leavers to play sound
          bool newLeaverFound = false;
          for (int l in incomingLeavers) {
            if (!_leavers.contains(l)) {
              newLeaverFound = true;
              break;
            }
          }
          if (newLeaverFound) {
            _ludoGame.playQuitSound();
          }

          _leavers.clear();
          _leavers.addAll(incomingLeavers);
        }

        // Sync Turn & Dice
        int newP = (gameState['currentPlayerIndex'] as num?)?.toInt() ?? 0;
        if (newP != _currentPlayer) {
          _remainingTime = kTurnDurationSeconds;
          _sentHurryThisTurn = false;
          _currentPlayer = newP;
          _startTurnTimer();
        }

        final dData = gameState['diceRolled'] as List?;
        final newDice =
            dData?.map((d) => (d as num?)?.toInt() ?? 0).toList() ?? [];

        // 💡 Detect Bust (3 sixes) for all players to hear the sound
        if (newDice.length >= 3 &&
            newDice.sublist(newDice.length - 3).every((d) => d == 6) &&
            (_diceRolled.length < 3 || !_diceRolled.sublist(_diceRolled.length - 3).every((d) => d == 6))) {
          _ludoGame.playThreeSixSound();
        }

        _diceRolled = newDice;

        final bool newRolling = gameState['isRolling'] ?? false;
        if (newRolling && !_isRolling) {
          _ludoGame.playDiceSound();
        }
        _isRolling = newRolling;
        _canRoll = gameState['canRoll'] ?? true;

        // Sync Timer (Discrepancy Check)
        if (_gameMode == 'online') {
          int serverNow =
              DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;
          int elapsed = (serverNow - serverUpdate) ~/ 1000;
          int calcRem = (kTurnDurationSeconds - elapsed).clamp(
            0,
            kTurnDurationSeconds,
          );
          if ((calcRem - _remainingTime).abs() > 2) {
            _remainingTime = calcRem;
            if (_remainingTime > 0 &&
                (_turnTimer == null || !_turnTimer!.isActive)) {
              _startTurnTimer();
            }
          }
        }
      }

      // --- Bot/Leaver Takeover ---
      if (_uiState == LudoUiState.playing && _gameMode == 'online') {
        // If current player is a leaver, and we are the master, skip their turn immediately
        if (_leavers.contains(_currentPlayer) && _isEffectiveMaster) {
          _nextTurn();
        } else {
          // Re-trigger auto-play logic in case we just became the Effective Master
          _scheduleAutoPlayForCurrentTurn();
        }
      }

      // ── C. Matchmaking & Room Metadata (Always Sync) ───────────────────────
      if (roomData['status'] == 'finished' &&
          _uiState == LudoUiState.playing &&
          !_isWinDialogShowing) {
        int w = (gameState['forceWinner'] as num?)?.toInt() ?? -1;
        if (w == -1) {
          for (int i = 0; i < 4; i++) {
            if (_tokens[i].every((t) => t == 57)) {
              w = i;
              break;
            }
          }
        }
        if (w != -1) {
           _showWinDialog(w);
        }

        // ✅ AUTO-DELETE: If game is finished, have the Master delete the room after a delay
        // to keep Firebase clean. Delay 60s to let everyone see the win dialog.
        // We use a local flag or check if we already scheduled it.
        if (_isEffectiveMaster && _roomId != null) {
          final String roomToDelete = _roomId!;
          // We set _roomId to null locally after scheduling to avoid double-delete
          _roomId = null; 
          Future.delayed(const Duration(seconds: 60), () {
            LudoService().deleteRoom(roomToDelete);
            debugPrint('[LudoScreen] Finished room $roomToDelete deleted by Master.');
          });
        }
      }

      final String statusBet = roomData['status_bet'] ?? '';
      final bool roomIsPlaying = roomData['status'] == 'playing';
      final bool roomIsWaiting = roomData['status'] == 'waiting';

      // Team Up Sync: If lobby switches to public matchmaking, move guests to matchmaking UI too
      if (_uiState == LudoUiState.friendInvitation &&
          _isTeamMode &&
          statusBet.startsWith('waiting_')) {
        _uiState = LudoUiState.matchmaking;
      }

      if (_uiState == LudoUiState.matchmaking && roomIsWaiting) {
        final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
        if (myUid != null && _roomHostId == myUid) {
          _startBotMatchmakingTimer();
        }
      }

      // ✅ FIX: For online mode, ONLY start when Firebase server marks the room
      // as 'playing'. This ensures all clients see the same trigger and start simultaneously.
      final bool allPlayersReady = roomIsPlaying;

      if ((_uiState == LudoUiState.matchmaking ||
              _uiState == LudoUiState.friendInvitation) &&
          allPlayersReady &&
          !_hasStartedTransition) {
        _hasStartedTransition = true;
        _matchFoundAnimation = true;

        // Start a 3-second countdown.
        // Initially, the opponent's photo appears in the search area (Phase 1)
        setState(() {
          _matchCountdown = 3;
          _showTotalPotInMatchmaking = false;
        });

        Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          if (_matchCountdown > 1) {
            setState(() {
              _matchCountdown--;
              
              // When countdown reaches 2, take the bet and add it to the top pot display (Phase 2)
              if (_matchCountdown == 2) {
                _showTotalPotInMatchmaking = true;
                
                // Deduct bet amount from user's coins
                final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
                if (myUid != null && _selectedBet > 0) {
                  UserService().updateUser(
                    uid: myUid,
                    data: {'coins': FieldValue.increment(-_selectedBet)},
                  ).catchError((e) => debugPrint('[LudoBet] Deduction error: $e'));
                  
                  debugPrint('[LudoBet] Deducted $_selectedBet coins from $myUid');
                }
                
                // Play a satisfying coin collection sound!
                _ludoGame.playNewTokenSound();
              }
            });
          } else {
            timer.cancel();
            setState(() {
              _matchCountdown = 0;
              _matchFoundAnimation = false;
              _hasStartedTransition = false;
              _showTotalPotInMatchmaking = false;
              _resetInteractions();
              _reinitGameWithTheme();
              _uiState = LudoUiState.playing;
            });
            _switchMusicTrack();
            _addToLog(
              LudoGameLogEntry(
                type: LudoGameLogType.start,
                playerName: 'النظام',
                playerColor: Colors.amber,
                message: 'بدأت المباراة! حظاً موفقاً للجميع 🎲',
              ),
            );
            _startTurnTimer(isFirstTurn: true);
          }
        });
      }
      // Update participant tracking based on current room data
      if (playersData != null) {
        _onlinePlayerNames.clear();
        _onlinePlayerImages.clear();
        _onlinePlayerUids.clear();
        _autoPlayingIndices.clear();
        _botIndices.clear();
        Map<int, String> shapes = {};
        playersData.forEach((uid, data) {
          final p = Map<String, dynamic>.from(data as Map);
          int idx = (p['index'] as num?)?.toInt() ?? 0;
          _onlinePlayerNames[idx] = p['name'] ?? "بانتظار...";
          _onlinePlayerImages[idx] = p['photo'];
          _onlinePlayerUids[idx] = uid.toString();
          if (p['isAuto'] == true) {
            _autoPlayingIndices.add(idx);
          }

          if (p['isBot'] == true) {
            _botsEnabled = true;
            _botIndices.add(idx);
            if (!_botProfiles.containsKey(idx)) {
              _botProfiles[idx] = LudoBotProfile(
                name: p['name'] ?? 'Bot',
                avatarSeed: _rng.nextInt(8),
                fakeWins: 100 + _rng.nextInt(700),
                fakeLevel: 5 + _rng.nextInt(45),
                personality: LudoBotPersonality
                    .values[_rng.nextInt(LudoBotPersonality.values.length)],
              );
            }
          }

          // تحميل شكل الحجرات لكل لاعب
          if (p['tokenShape'] != null) {
            shapes[idx] = p['tokenShape'] as String;
            _playerTokenShapes[idx] = p['tokenShape'] as String;
          }

          // تحميل سمة الحجرات (الطقم)
          if (p['tokenTheme'] != null) {
            final theme = p['tokenTheme'] as String;
            if (_playerTokenThemes[idx] != theme) {
              _playerTokenThemes[idx] = theme;
              _fetchPlayerTokenUrls(idx, theme);
            }
          }

          // تحميل سمة النرد
          if (p['diceTheme'] != null) {
            final theme = p['diceTheme'] as String;
            if (_playerDiceThemes[idx] != theme) {
              _playerDiceThemes[idx] = theme;
              _fetchPlayerDiceUrls(idx, theme);
            }
          }
        });

        // مزامنة أشكال وسمات اللاعبين مع اللعبة
        _ludoGame.updateThemes(
          pShapes: _playerTokenShapes,
          pThemes: _playerTokenThemes,
          pUrlsMap: _playerTokenUrlsMap,
        );
      }

      if (_gameMode == 'online' &&
          roomData['status'] == 'playing' &&
          !_isWinDialogShowing &&
          !_winners.contains(_myPlayerIndex)) {
        // If only 1 player remains in the room, they are the winner
        if (playersData != null &&
            playersData.length == 1 &&
            playersData.containsKey(
              auth.FirebaseAuth.instance.currentUser?.uid,
            )) {
          _showWinDialog(_myPlayerIndex);
        }
      }

      _updateGame();

      // ── D. Interactions (Always Sync) ──────────────────────────────────────
      _ludoGame.allowTokenInteraction =
          !_isRolling && !_canRoll && _diceRolled.isNotEmpty;

      if (roomData['interactions'] != null) {
        final inters = Map<String, dynamic>.from(
          roomData['interactions'] as Map,
        );
        inters.forEach((uid, data) {
          final interData = Map<String, dynamic>.from(data as Map);
          int pIdx = -1;
          if (playersData != null) {
            final pInfo = playersData[uid] as Map?;
            if (pInfo != null) pIdx = (pInfo['index'] as num).toInt();
          }
          if (pIdx != -1) _handleNewInteraction(pIdx, interData);
        });
      }
    });

    // ── 2. Selective AI/Auto-Play Triggering ──────────────────────────────────
    bool turnChanged = (_currentPlayer != oldCurrentPlayer);
    bool statusPlaying = (roomData['status'] == 'playing');

    if (_uiState == LudoUiState.playing && statusPlaying) {
      // Trigger if: turn changed OR state changed OR auto-play status changed
      // (oldAutoPlayingIndices is not available here, so we check if the current player is auto)
      bool isAutoNow =
          _autoPlayingIndices.contains(_currentPlayer) ||
          _botIndices.contains(_currentPlayer);

      bool needsAction =
          turnChanged ||
          stateChanged ||
          isFirstSync ||
          isAutoNow; // If they are auto, we should always check if they need an action

      if (needsAction) {
        bool idleRoll = (_canRoll && _diceRolled.isEmpty && !_isRolling);
        bool finishedRoll =
            (oldIsRolling && !_isRolling && _diceRolled.isNotEmpty);

        if (turnChanged || idleRoll || finishedRoll || isAutoNow) {
          bool isBust =
              (_diceRolled.length >= 3 && _diceRolled.sublist(_diceRolled.length - 3).every((d) => d == 6));
          if (!isBust) {
            _scheduleAutoPlayForCurrentTurn();
            
            // Added: Auto-move for human player if only one choice exists
            if (finishedRoll && _currentPlayer == _myPlayerIndex && !isAutoNow && !_canRoll && _canMoveAny()) {
              _checkAutoMove();
            }
          }
        }
      }
    }
  }

  // --- Player Index Mapping ---
  // In online mode, we use absolute indices 0-3 matching LudoGame/Firebase
  int _playerToGameIndex(int serverIndex) {
    return serverIndex;
  }

  int _gameToPlayerIndex(int gameIndex) {
    return gameIndex;
  }

  int _toVisualIndex(int serverIdx) {
    // Both online and local use rotation logic now for consistency
    return (serverIdx + (3 - _myPlayerIndex) + 4) % 4;
  }

  Color _getPlayerColor(int pIndex) {
    switch (pIndex) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.green;
      case 2:
        return Colors.yellow;
      case 3:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // --- Player Index Mapping & Perspectives ---
  // Formula to make me always at Bottom-Left (index 3)
  // int _toVisualIndex(int serverIdx) {
  //   if (_gameMode != 'online') return serverIdx; // Local stays same for now
  //   return (serverIdx + (3 - _myPlayerIndex)) % 4;
  // }

  bool _isPlayerActive(int pIndex) {
    if (_gameMode == 'online') {
      return _onlinePlayerNames.containsKey(pIndex);
    }
    // Local mode: Check my player index and registered bot indices
    return pIndex == _myPlayerIndex || _botIndices.contains(pIndex);
  }

  String _getPlayerName(int pIndex) {
    if (_gameMode == 'online') {
      return _onlinePlayerNames[pIndex] ?? "بانتظار...";
    }
    if (pIndex == _myPlayerIndex) return _userName;

    // Local mode / Bot mode: Use profile name if exists
    return _botProfiles[pIndex]?.name ?? "بوت ${pIndex + 1}";
  }

  /// Set up a realistic-looking local bot profile when starting a local game.
  /// Called before transitioning to playing state.
  void _setupLocalBotProfile() {
    final localBotIdx = (_myPlayerIndex + 2) % 4;
    if (_botProfiles.containsKey(localBotIdx)) return; // Already set up

    final profile = LudoBotProfile.random(_rng);

    _botProfiles[localBotIdx] = profile;
    _botIndices.add(localBotIdx);
    _botsEnabled = true; // Enable social reactions in local mode too
    // Note: we do NOT add to _autoPlayingIndices — local bot is driven by _aiLogic directly

    debugPrint(
      '[LocalBot] Created: "${profile.name}" (${profile.personality.name}, ${profile.difficulty.name})',
    );
  }

  // --- Dynamic Master Logic ---
  /// Returns true if this client is the "effective master" — the online player
  /// with the lowest index. Used to decide who triggers auto-play for others.
  void _handlePlayerTimeoutWin(int offlinePIdx, {bool isSelf = false}) {
    if (!mounted || _gameMode != 'online' || _roomId == null) return;

    final Map<String, dynamic> updates = {};

    // Record a loss in Firestore if I am the one leaving/withdrawing
    if (isSelf) {
      final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
      if (myUid != null) {
        UserService().updateUser(
          uid: myUid,
          data: {
            'gamesPlayed': FieldValue.increment(1),
            'wins': FieldValue.increment(0),
            'losses': FieldValue.increment(1),
            'gameStats.ludo.played': FieldValue.increment(1),
            'gameStats.ludo.wins': FieldValue.increment(0),
            'gameStats.ludo.losses': FieldValue.increment(1),
          },
        ).catchError((e) => debugPrint('[LudoStats] Loss write error on exit: $e'));
        debugPrint('[LudoStats] Logged loss on exit for $myUid');
      }
    }

    // 1v1 immediate-win guard for timeout or exit of opponent
    if (_currentMatchMaxPlayers == 2 && offlinePIdx != _myPlayerIndex && !isSelf && _uiState == LudoUiState.playing) {
      debugPrint('[Presence] 1v1 Opponent timed out or left. Awarding victory.');
      updates['status'] = 'finished';
      updates['state/winners'] = [_myPlayerIndex];
      final String? leaverUid = _onlinePlayerUids[offlinePIdx];
      if (leaverUid != null) {
        updates['players/$leaverUid/left'] = true;
      }
      updates['state/lastUpdate'] = ServerValue.timestamp;
      LudoService().updateGameState(_roomId!, updates);
      _showWinDialog(_myPlayerIndex);
      return;
    }

    if (!_isEffectiveMaster && !isSelf) return;

    // ── Check if we should end the game (Last Human Standing) ──
    // If all human opponents have left, the remaining player(s) win instantly.
    bool opponentHumanRemains = false;
    for (int i = 0; i < 4; i++) {
      // Skip self and (in team mode) the teammate
      if (i == _myPlayerIndex) continue;
      if (_isTeamMode && (i % 2 == _myPlayerIndex % 2)) continue;
      
      // Skip indices that are not even in this match (e.g., player 1 and 3 in a 2-player game)
      if (!_onlinePlayerUids.containsKey(i) && !_botIndices.contains(i)) continue;

      bool isBot = _botIndices.contains(i);
      bool alreadyLeaver = _leavers.contains(i);
      bool isTimingOut = (i == offlinePIdx);

      // We only care if there is at least one REAL human opponent who hasn't left
      if (!isBot && !alreadyLeaver && !isTimingOut) {
        opponentHumanRemains = true;
        break;
      }
    }

    if (!opponentHumanRemains && !isSelf && _uiState == LudoUiState.playing) {
      debugPrint(
        '[Presence] All human opponents left. Ending game with win for $_myPlayerIndex',
      );

      updates['status'] = 'finished';
      List<int> winners = [_myPlayerIndex];
      if (_isTeamMode) {
        winners.add((_myPlayerIndex + 2) % 4);
      }
      updates['state/winners'] = winners;

      final String? leaverUid = _onlinePlayerUids[offlinePIdx];
      if (leaverUid != null) {
        updates['players/$leaverUid/left'] = true;
      }
      updates['state/lastUpdate'] = ServerValue.timestamp;

      LudoService().updateGameState(_roomId!, updates);

      // Local state update to show dialog immediately for the master client
      _showWinDialog(_myPlayerIndex);
      return;
    }

    debugPrint(
      '[Presence] Timeout limit reached for player $offlinePIdx. Marking as leaver.',
    );

    final String? leaverUid = _onlinePlayerUids[offlinePIdx];

    // ── Global: Convert to Auto-Play instead of removing ──
    setState(() {
      _autoPlayingIndices.add(offlinePIdx);
      _ludoGame.playQuitSound();
      _addToLog(
        LudoGameLogEntry(
          type: LudoGameLogType.turnChange,
          playerName: _getPlayerName(offlinePIdx),
          playerColor: _getPlayerColor(offlinePIdx),
          message: 'غادر اللاعب — سيقوم النظام باللعب بدلاً عنه 🤖',
        ),
      );
    });

    if (leaverUid != null) {
      updates['players/$leaverUid/isAuto'] = true;
      updates['players/$leaverUid/left'] = true;
    }

    // Update global leavers list for all clients to sync
    List<int> newLeaversList = _leavers.toList();
    if (!newLeaversList.contains(offlinePIdx)) {
      newLeaversList.add(offlinePIdx);
    }
    updates['state/leavers'] = newLeaversList;

    // If it's the leaver's turn, advance it immediately to avoid waiting
    if (_currentPlayer == offlinePIdx) {
      int nextPlayer = _getNextActivePlayerIndex((_currentPlayer + 1) % 4);
      updates['state/currentPlayerIndex'] = nextPlayer;
      updates['state/diceRolled'] = [];
      updates['state/canRoll'] = true;
      updates['state/isRolling'] = false;
    }

    updates['state/lastUpdate'] = ServerValue.timestamp;

    if (updates.isNotEmpty) {
      LudoService().updateGameState(_roomId!, updates);
    }
  }

  // --- UI Build Helpers ---

  bool get _isEffectiveMaster {
    if (_gameMode != 'online') return false;
    // Find the lowest player index that is a HUMAN and is currently online
    for (final entry in _onlinePresence.entries) {
      final int idx = entry.key;
      final bool isOnline = entry.value;
      final bool isBot = _botIndices.contains(idx);

      if (isOnline && !isBot && idx < _myPlayerIndex) {
        return false; // A real human with a lower index is online
      }
    }
    return true;
  }
}
