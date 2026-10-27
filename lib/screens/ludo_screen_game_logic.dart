// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api
part of 'ludo_screen.dart';

/// Core game mechanics: timer, dice, movement, turn management.
extension LudoScreenGameLogic on _LudoScreenState {
  void _startTurnTimer({bool isFirstTurn = false}) {
    _turnTimer?.cancel();
    if (_uiState != LudoUiState.playing || _isWinDialogShowing) return;

    // Trigger AI / Auto-play check immediately when the turn starts
    _scheduleAutoPlayForCurrentTurn(immediate: isFirstTurn);

    // We no longer blindly reset _remainingTime here.
    // - In Online mode, _handleRoomUpdate sets it based on server time.
    // - In Local mode, _nextTurn and _grantBonusRoll set it.

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isWinDialogShowing) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;

          // Bots nudge the player if they're taking too long
          if (_botsEnabled &&
              _currentPlayer == _myPlayerIndex &&
              _remainingTime <= 7 &&
              !_sentHurryThisTurn) {
            _sentHurryThisTurn = true;
            final botIdx = _botIndices.isNotEmpty ? _botIndices.first : -1;
            if (botIdx != -1) {
              // Randomized hurry messages for human feel (fallback)
              final hurryPool = [
                ' العب بسرعة وراي شغل  😅',
                ' شبيك صفنت؟ 🤔',
                ' خلص الوقت!',
                'هيا ألعب!',
                '⏳ الوقت يمشي',
                'ركّز بالعب راح تنجلد ',
                'مبين مشغول؟ 😂',
                'العجلة من الشيطان لكن انتبه 😜',
                'شنو تلعب لودو لو بخشمك 😂',
              ];

              _getSmartBotComment(
                pIndex: botIdx,
                event:
                    "اللاعب ${_getPlayerName(_myPlayerIndex)} تأخر في اللعب والوقت بدأ ينفد، أريدك أن تستعجله بمزاج شخصيتك.",
              ).then((aiMsg) {
                if (!mounted) return;
                final msg = aiMsg ?? hurryPool[_rng.nextInt(hurryPool.length)];
                _handleNewInteraction(botIdx, {
                  'type': 'text',
                  'content': msg,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                });
              });
            }
          }
        } else {
          // Timeout!
          timer.cancel();
          if (_gameMode == 'online') {
            // Online: If it's ME, enable persistent auto-play
            if (_currentPlayer == _myPlayerIndex &&
                !_autoPlayingIndices.contains(_myPlayerIndex)) {
              _enableAutoPlay(); // will call _scheduleAutoPlayForCurrentTurn internally
            }
            // MASTER FALLBACK: even if it's opponent's turn and they are auto/bot or OFFLINE,
            // act immediately without waiting for another Firebase update
            else if (_isEffectiveMaster) {
              if (_autoPlayingIndices.contains(_currentPlayer) ||
                  _botIndices.contains(_currentPlayer)) {
                _scheduleAutoPlayForCurrentTurn();
              } else if (_onlinePresence.containsKey(_currentPlayer) &&
                  _onlinePresence[_currentPlayer] != true) {
                // Player completely disconnected (and not auto-playing).
                // Their own device won't skip, so the Master must force a turn skip.
                debugPrint(
                  '[Master] Player $_currentPlayer is offline. Skipping their timed-out turn.',
                );
                _nextTurn();
              }
            }
          } else {
            // Local: User timeout
            if (_currentPlayer == _myPlayerIndex &&
                !_autoPlayingIndices.contains(_myPlayerIndex)) {
              _enableAutoPlay();
            } else if (_botIndices.contains(_currentPlayer) ||
                _autoPlayingIndices.contains(_currentPlayer)) {
              // Bot or auto-human failed to move during timer? Force it now.
              _isAiThinking = false; // Reset just in case it got stuck
              _scheduleAutoPlayForCurrentTurn();
            }
          }
        }
      });
    });
  }

  void _enableAutoPlay() {
    // Add locally immediately for responsive UI and trigger
    setState(() {
      _autoPlayingIndices.add(_myPlayerIndex);
    });

    if (_gameMode == 'online' && _roomId != null) {
      LudoService().toggleAutoPlay(_roomId!, true);
    }

    // Trigger AI immediately
    _scheduleAutoPlayForCurrentTurn();
  }

  void _stopAutoPlay() {
    if (_autoPlayingIndices.contains(_myPlayerIndex)) {
      if (_gameMode == 'online' && _roomId != null) {
        LudoService().toggleAutoPlay(_roomId!, false);
      } else {
        setState(() {
          _autoPlayingIndices.remove(_myPlayerIndex);
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("أهلاً بعودتك!"),
          duration: Duration(milliseconds: 1000),
        ),
      );
    }
  }

  void _startReRollGraceTimer({int? localResult, double? customGraceTime}) {
    _reRollGraceTimer?.cancel();
    if (_uiState != LudoUiState.playing || _isWinDialogShowing) return;

    double graceTime = customGraceTime ?? 3.0; // Increased to 3 seconds

    setState(() {
      _reRollGraceRemaining = graceTime;
    });
    _reRollGraceTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted || _isWinDialogShowing) {
        timer.cancel();
        return;
      }
      setState(() {
        _reRollGraceRemaining -= 0.1;
        if (_reRollGraceRemaining <= 0) {
          _reRollGraceRemaining = 0;
          timer.cancel();
          bool isBust =
              (_diceRolled.length >= 3 && _diceRolled.sublist(_diceRolled.length - 3).every((d) => d == 6));

          if (_currentPlayer == _myPlayerIndex &&
              ((!_canRoll && !_canMoveAny()) || isBust)) {
            _nextTurn();
          }
        }
      });
    });
  }

  void _userInteraction() {
    // If the user interacts with the screen, stop auto-playing for them.
    if (_autoPlayingIndices.contains(_myPlayerIndex)) {
      _stopAutoPlay();

      // Only restart the timer if it's currently our turn
      if (_currentPlayer == _myPlayerIndex) {
        setState(() => _remainingTime = kTurnDurationSeconds);
        // Start turn timer after we resume control
        _startTurnTimer();
      }
    }
  }

  /// Schedules an immediate AI action for the current player if they are in auto-play.
  /// Called every time the turn changes or a timeout occurs.
  /// Uses a short 1.2s delay for realism, then acts without waiting for the full timer.
  void _scheduleAutoPlayForCurrentTurn({bool immediate = false}) {
    if (_uiState != LudoUiState.playing || _isWinDialogShowing) return;
    if (_isAiThinking) return;

    final bool isAuto = _autoPlayingIndices.contains(_currentPlayer);
    bool isBot = _botIndices.contains(_currentPlayer);
    bool isBust = (_diceRolled.length >= 3 && _diceRolled.sublist(_diceRolled.length - 3).every((d) => d == 6));

    if (!isAuto && !isBot) return;

    // Safety: don't auto-act for MY turn if I don't have AUTO enabled, OR if I'm busted
    if (_currentPlayer == _myPlayerIndex && (!isAuto || isBust)) return;

    // Possession check
    bool canIAct = false;
    if (_gameMode != 'online') {
      canIAct = true;
    } else {
      if (_currentPlayer == _myPlayerIndex) {
        canIAct = true;
      } else if (_isEffectiveMaster) {
        canIAct = true;
      }
    }

    if (!canIAct) return;

    _isAiThinking = true;

    final int capturedPlayer = _currentPlayer;
    final delay = immediate
        ? 0
        : _botThinkDelayMs(forPlayerIndex: capturedPlayer);

    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) {
        _isAiThinking = false;
        return;
      }

      // Re-verify turn and state
      if (_currentPlayer != capturedPlayer || _uiState != LudoUiState.playing || _isWinDialogShowing) {
        _isAiThinking = false;
        return;
      }

      // Check still auto/bot
      if (!_autoPlayingIndices.contains(_currentPlayer) &&
          !_botIndices.contains(_currentPlayer)) {
        _isAiThinking = false;
        return;
      }

      _isAiThinking =
          false; // Reset before acting so roll/move can set it again if needed

      if (_canRoll && !_isRolling && _diceRolled.isEmpty) {
        // Social interaction: 8% chance to say something when starting the turn
        if (capturedPlayer == _myPlayerIndex && _rng.nextInt(100) < 8) {
          final startPool = [
            'سأرمي بدلك 🎲',
            'اترك هذا علي 😎',
            'الحظ بجانبي اليوم! 🤞',
          ];

          _getSmartBotComment(
            pIndex: _botIndices.isNotEmpty
                ? _botIndices.first
                : _myPlayerIndex, // Using first bot or self
            event:
                "لقد بدأت دور اللاعب ${_getPlayerName(_myPlayerIndex)} وسأقوم بالرمي بدلاً عنه (لأنه فعل الرمي التلقائي).",
          ).then((aiMsg) {
            if (!mounted) return;
            final msg = aiMsg ?? startPool[_rng.nextInt(startPool.length)];
            _handleNewInteraction(_myPlayerIndex, {
              'type': 'text',
              'content': msg,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          });
        }
        _rollDice();
      } else if (_diceRolled.isNotEmpty && !_isRolling) {
        // Social interaction: 5% chance to react before moving
        if (capturedPlayer == _myPlayerIndex && _rng.nextInt(100) < 5) {
          _handleNewInteraction(_myPlayerIndex, {
            'type': 'emoji',
            'content': ['🤔', '🧐', '⚡', '🎯'][_rng.nextInt(4)],
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        }
        _aiLogic(_currentPlayer);
      }
    });
  }

  int _botThinkDelayMs({required int forPlayerIndex}) {
    // Get personality if this is a known bot
    final profile = _botProfiles[forPlayerIndex];
    final personality = profile?.personality ?? LudoBotPersonality.balanced;

    // Roll delay: 0.8–2.0 seconds (more natural)
    if (_canRoll && _diceRolled.isEmpty) {
      switch (personality) {
        case LudoBotPersonality.aggressive:
          return 700 + _rng.nextInt(600); // 0.7–1.3s
        case LudoBotPersonality.random:
          return 400 + _rng.nextInt(1800); // 0.4–2.2s
        case LudoBotPersonality.defensive:
        case LudoBotPersonality.balanced:
          return 1000 + _rng.nextInt(1000); // 1.0–2.0s
      }
    }

    // Move delay depends on number of options + personality
    int options = 0;
    try {
      options = _enumerateMoves(forPlayerIndex).length;
    } catch (_) {}

    if (options <= 1) {
      // one obvious move — faster but still deliberate
      switch (personality) {
        case LudoBotPersonality.aggressive:
          return 500 + _rng.nextInt(400); // 0.5–0.9s
        case LudoBotPersonality.random:
          return 300 + _rng.nextInt(1200); // 0.3–1.5s
        default:
          return 800 + _rng.nextInt(700); // 0.8–1.5s
      }
    }

    // Multiple options — strategic thinking
    switch (personality) {
      case LudoBotPersonality.aggressive:
        return 1000 + _rng.nextInt(800); // 1.0–1.8s
      case LudoBotPersonality.random:
        return 600 + _rng.nextInt(2000); // 0.6–2.6s
      case LudoBotPersonality.defensive:
        return 1800 + _rng.nextInt(1200); // 1.8–3.0s
      case LudoBotPersonality.balanced:
        return 1400 + _rng.nextInt(1100); // 1.4–2.5s
    }
  }

  // --- Game Logic ---

  void _updateGame() {
    int displayDice = _diceRolled.isNotEmpty ? _diceRolled.last : 0;
    int gameIndex = _playerToGameIndex(_currentPlayer);

    _ludoGame.syncWithScreen(
      _tokens,
      gameIndex,
      displayDice,
      _diceRolled.isNotEmpty,
      leavers: _leavers,
    );

    _ludoGame.allowTokenInteraction =
        !_isRolling && !_canRoll && _diceRolled.isNotEmpty;

    // Sync active players visibility
    Set<int> activeGameIndices = {};
    for (int i = 0; i < 4; i++) {
      if (_isPlayerActive(i)) {
        activeGameIndices.add(_playerToGameIndex(i));
      }
    }
    _ludoGame.syncActivePlayers(activeGameIndices);

    // Update highlights for moveable tokens
    _updateMoveableHighlights();

    if (mounted) setState(() {});
  }

  void _handleTokenTap(int gameIndex, int tokenIndex) async {
    // ── Ownership & turn guards ──────────────────────────────────────────────
    // Convert game index to player index
    int playerIndex = _gameToPlayerIndex(gameIndex);
    if (playerIndex == -1) return; // invalid

    // Guard 1: Only the token belonging to the current-turn player can be tapped
    // In team mode, allow moving teammate's token if own pieces are finished
    bool isMyToken = playerIndex == _currentPlayer;
    bool isTeammateToken =
        _isTeamMode &&
        _winners.contains(_currentPlayer) &&
        playerIndex == (_currentPlayer ^ 2);

    if (!isMyToken && !isTeammateToken) return;

    // Guard 2: Only the local human player can move their own tokens.
    //          Exception: effective master can move for a bot/auto-play slot.
    if (_gameMode == 'online') {
      final bool ownsToken = (playerIndex == _myPlayerIndex);
      final bool isBotSlot =
          _botIndices.contains(playerIndex) ||
          _autoPlayingIndices.contains(playerIndex);
      final bool canActForBot = _isEffectiveMaster && isBotSlot;

      if (!ownsToken && !canActForBot) return;
    } else {
      // Local mode: human owns _myPlayerIndex; AI owns the other slot.
      // Humans must never control the AI's tokens directly.
      final bool ownsToken = (playerIndex == _myPlayerIndex);
      final bool isBotSlot = _botIndices.contains(playerIndex);
      if (!ownsToken && !isBotSlot) return;
      // In local mode bots are driven by _aiLogic, not by tap.
      if (!ownsToken) return;
    }

    _userInteraction(); // This stops persistent auto-play for ME if I am taking action

    if (_isRolling) return;
    if (_diceRolled.isEmpty) return;

    int diceToUse = -1;
    int diceIdx = -1;

    if (_diceRolled.length == 1) {
      // Only one dice total, check if it's valid for this specific token
      bool isValid = false;
      int d = _diceRolled[0];
      int currentPos = _tokens[gameIndex][tokenIndex];
      if (currentPos == 0) {
        if (d == 6) {
          isValid = true;
        }
      } else if (!_isPathBlocked(gameIndex, currentPos, d)) {
        if (currentPos + d <= 57) {
          isValid = true;
        }
      }

      if (isValid) {
        diceIdx = 0;
        diceToUse = _diceRolled[0];
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("لا يمكن تحريك هذا الحجر بهذا الرقم"),
            duration: Duration(milliseconds: 800),
          ),
        );
        return;
      }
    } else {
      // If the token is in the base, and we have a 6, automatically use it
      int currentPos = _tokens[gameIndex][tokenIndex];
      if (currentPos == 0 && _diceRolled.contains(6)) {
        diceIdx = _diceRolled.indexOf(6);
        diceToUse = 6;
        _tryMove(playerIndex, gameIndex, tokenIndex, diceToUse, diceIdx);
        return;
      }

      // Multiple dice available - ALWAYS show selection dialog to avoid accidental moves
      // pass all dice values and which indices are valid for this token
      List<int> validDiceIndices = [];
      for (int i = 0; i < _diceRolled.length; i++) {
        int d = _diceRolled[i];
        int currPos = _tokens[gameIndex][tokenIndex];
        if (!_isPathBlocked(gameIndex, currPos, d)) {
          if (currPos == 0 && d == 6) {
            validDiceIndices.add(i);
          } else if (currPos > 0 && currPos + d <= 57)
            validDiceIndices.add(i);
        }
      }

      int? selectedIdx = await _showDiceSelectionDialog(
        validDiceIndices,
        _diceRolled,
      );
      if (selectedIdx == null) return; // User cancelled

      diceIdx = selectedIdx;
      diceToUse = _diceRolled[diceIdx];
    }

    _tryMove(playerIndex, gameIndex, tokenIndex, diceToUse, diceIdx);
  }

  Future<int?> _showDiceSelectionDialog(
    List<int> validIndices,
    List<int> allDice,
  ) async {
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent click inside from popping
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(allDice.length, (i) {
                            int value = allDice[i];
                            bool isValid = validIndices.contains(i);
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: GestureDetector(
                                onTap: isValid
                                    ? () => Navigator.of(context).pop(i)
                                    : null,
                                child: Opacity(
                                  opacity: isValid ? 1.0 : 0.4,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isValid
                                            ? [
                                                Colors.orange.shade400,
                                                Colors.orange.shade800,
                                              ]
                                            : [
                                                Colors.grey.shade600,
                                                Colors.grey.shade800,
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: isValid
                                          ? [
                                              BoxShadow(
                                                color: Colors.orange
                                                    .withOpacity(0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Text(
                                        "$value",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _rollDice() async {
    // _userInteraction(); // If I roll, stop auto play for ME - Removed as per instructions
    if (!_canRoll || _isRolling || _isWinDialogShowing) return;

    if (_gameMode == 'online') {
      final bool isMyTurn = (_currentPlayer == _myPlayerIndex);
      final bool isCurrentAuto = _autoPlayingIndices.contains(_currentPlayer);
      final bool isCurrentBot = _botIndices.contains(_currentPlayer);

      // Case 1: My turn and I am NOT in auto-play → human roll, allowed.
      if (isMyTurn && !_autoPlayingIndices.contains(_myPlayerIndex)) {
        // Proceed
      }
      // Case 2: My turn and I AM in auto-play → AI rolls for me, allowed.
      else if (isMyTurn && _autoPlayingIndices.contains(_myPlayerIndex)) {
        // Proceed
      }
      // Case 3: Not my turn – only effective master can roll for bot/auto slots.
      else if (!isMyTurn &&
          _isEffectiveMaster &&
          (isCurrentAuto || isCurrentBot)) {
        // Proceed
      }
      // Everything else: not allowed.
      else {
        return;
      }
    } else {
      // Local mode: only roll on my own turn; bot handled by _aiLogic.
      if (_currentPlayer != _myPlayerIndex &&
          !_botIndices.contains(_currentPlayer))
        return;
    }

    if (_gameMode == 'online' && _roomId != null) {
      // Push rolling state to Firebase
      LudoService().updateGameState(_roomId!, {'state/isRolling': true});
    }

    setState(() {
      _isRolling = true;
    });
    _ludoGame.playDiceSound();

    await _performRollStep();
  }

  int _getWeightedDiceResult({bool peek = false}) {
    if (_nextRollIsSix[_currentPlayer] > 0) {
      if (!peek) {
        setState(() {
          _nextRollIsSix[_currentPlayer] = _nextRollIsSix[_currentPlayer] - 1;
        });
        // مزامنة كمية النردات السحرية المتبقية بعد الاستهلاك مع الفايربيس
        if (_gameMode == 'online' && _roomId != null) {
          LudoService().updateGameState(_roomId!, {
            'state/nextRollIsSix': _nextRollIsSix,
          });
        }
      }
      return 6;
    }

    int value = _rng.nextInt(100);
    // 40% chance for a 6, 12% for other numbers
    if (value < 40) return 6;
    if (value < 52) return 5;
    if (value < 64) return 4;
    if (value < 76) return 3;
    if (value < 88) return 2;
    return 1;
  }

  Future<void> _reRollDice() async {
    // Safety: only the current player can re-roll
    if (_currentPlayer != _myPlayerIndex) return;
    if (_isRolling || _diceRolled.isEmpty) return;

    // 1. Cancel timers immediately to protect the player's turn from expiring
    double preservedGraceRemaining = _reRollGraceRemaining;
    _reRollGraceTimer?.cancel();
    _turnTimer?.cancel();

    setState(() {
      _isRolling = true;
      _reRollGraceRemaining = 0; // Freeze local grace remaining
    });

    // Also push the isRolling state to Firebase immediately to let opponents know we are processing a roll
    if (_gameMode == 'online' && _roomId != null) {
      await LudoService().updateGameState(_roomId!, {'state/isRolling': true});
    }

    int cost = kBlueButtonCosts[_blueButtonClicks];
    bool success = await _deductDiamondsForExtraTurn(cost);
    if (!success) {
      // Restore rolling state and timers if the purchase fails
      setState(() {
        _isRolling = false;
        _reRollGraceRemaining = preservedGraceRemaining;
      });

      if (_gameMode == 'online' && _roomId != null) {
        await LudoService().updateGameState(_roomId!, {
          'state/isRolling': false,
        });
      }

      _startTurnTimer();
      if (preservedGraceRemaining > 0) {
        _startReRollGraceTimer(customGraceTime: preservedGraceRemaining);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا تملك ماسات كافية!',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        );
      }
      return;
    }

    // Success! Proceed with local click counts
    setState(() {
      _blueButtonClicks++;
      _blueButtonClicksThisTurn++;
    });
    _ludoGame.playDiceSound();

    // 2. Online sync and interaction bubble
    if (_gameMode == 'online' && _roomId != null) {
      LudoService().sendInteraction(_roomId!, 'diamondReRoll', 'Used Diamonds');
    }

    // 3. Local log notification - REMOVED: do not show diamond use notification
    /*
    _addToLog(
      LudoGameLogEntry(
        type: LudoGameLogType.diamondReRoll,
        playerName: _getPlayerName(_myPlayerIndex),
        playerColor: _getPlayerColor(_myPlayerIndex),
        message: 'استخدم الماسات لإعادة رمي النرد! 💎',
      ),
    );
    */

    // 4. Animation loop
    int result = 0;
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (mounted) setState(() => result = _getWeightedDiceResult(peek: true));
    }
    result = _getWeightedDiceResult();

    if (!mounted) return;

    // 5. Update game state - Replace the last roll
    setState(() {
      _isRolling = false;
      if (_diceRolled.isNotEmpty) {
        _diceRolled.last = result;
      }
      _remainingTime = kTurnDurationSeconds;

      // Recalculate canRoll (a re-rolled 6 gives a bonus roll, unless it's the 3rd one)
      bool isBust =
          (_diceRolled.length >= 3 && _diceRolled.sublist(_diceRolled.length - 3).every((d) => d == 6));
      if (isBust) {
        _canRoll = false;
        _ludoGame.playThreeSixSound();
      } else {
        _canRoll = (result == 6);
      }
    });

    if (_currentPlayer == _myPlayerIndex) {
      _startReRollGraceTimer(); // _diceRolled already contains the new result
    }

    // 6. Online finalize
    if (_gameMode == 'online' && _roomId != null) {
      bool isBust =
          (_diceRolled.length >= 3 && _diceRolled.sublist(_diceRolled.length - 3).every((d) => d == 6));

      // If bust and has remaining clicks this turn, don't switch player yet
      // Increase global limit to effectively unlimited, keep turn limit at 3
      bool hasMoreClicks = _blueButtonClicksThisTurn < 3;

      if (isBust && !hasMoreClicks) {
        // Run out of clicks or total game limit -> Truly bust
        await LudoService().updateGameState(_roomId!, {
          'state/diceRolled': [],
          'state/isRolling': false,
          'state/canRoll': true,
          'state/currentPlayerIndex': _getNextActivePlayerIndex(
            (_currentPlayer + 1) % 4,
          ),
          'state/lastUpdate': ServerValue.timestamp,
        });
        return;
      } else {
        // Either not a bust, or can still re-roll
        await LudoService().updateGameState(_roomId!, {
          'state/diceRolled': _diceRolled,
          'state/isRolling': false,
          'state/canRoll': isBust ? false : _canRoll,
          'state/lastUpdate': ServerValue.timestamp,
        });
      }
    }

    _updateGame();
    _startTurnTimer();
    _updateMoveableHighlights();

    // 7. Auto-skip is now handled EXCLUSIVELY by _startReRollGraceTimer for the local player
    // to ensure they have the full window to use their remaining diamond re-rolls.
    if (_gameMode == 'online') {
      // ✅ SAFETY NET: 4s after diamond re-roll completes, if state is stuck, force next turn
      final int safetyPlayer = _currentPlayer;
      final List<int> safetyDice = List.from(_diceRolled);
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        // Still the same player, same dice, not rolling, can't roll, can't move
        // Do NOT force-skip if the re-roll grace timer is still running (player may re-roll again)
        if (_currentPlayer == safetyPlayer &&
            !_isRolling &&
            !_canRoll &&
            _reRollGraceRemaining <= 0 &&
            !_canMoveAnyWithDice(_diceRolled) &&
            _diceRolled.toString() == safetyDice.toString()) {
          debugPrint(
            '[BlueButton] Safety net triggered — forcing next turn for player $safetyPlayer',
          );
          if (_gameMode == 'online' && _isEffectiveMaster) {
            _nextTurn();
          } else if (_gameMode != 'online') {
            _nextTurn();
          }
        }
      });

      // Added: Auto-move for human player in online mode if only one choice exists
      if (_currentPlayer == _myPlayerIndex && !_canRoll && _canMoveAny()) {
        _checkAutoMove();
      }
    } else {
      bool isBust =
          (_diceRolled.length >= 3 && _diceRolled.sublist(_diceRolled.length - 3).every((d) => d == 6));
      if (isBust && _currentPlayer != _myPlayerIndex) {
        _ludoGame.playThreeSixSound();
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && _currentPlayer != _myPlayerIndex) {
            _nextTurn();
          }
        });
        return;
      }

      if (_currentPlayer != _myPlayerIndex && !_canRoll && !_canMoveAny()) {
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted && _currentPlayer != _myPlayerIndex) {
          _nextTurn();
        }
      } else if (_currentPlayer == _myPlayerIndex) {
        // For the human player, just check for auto-move if valid moves exist
        if (!_canRoll && _canMoveAny()) {
          _checkAutoMove();
        }
        _scheduleAutoPlayForCurrentTurn();
      }
    }
  }

  Future<void> _performRollStep() async {
    if (_isWinDialogShowing) return;
    final int playerIndexAtRoll = _currentPlayer;
    int result = 0;
    // Animation locally
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
      if (_isWinDialogShowing) return;
      if (mounted) setState(() => result = _getWeightedDiceResult(peek: true));
    }

    if (_isWinDialogShowing) return;
    result = _getWeightedDiceResult();

    if (!mounted || _isWinDialogShowing) return;

    if (_currentPlayer == _myPlayerIndex) {
      _startReRollGraceTimer(localResult: result);
    }

    if (_gameMode == 'online') {
      // Calculate new state for online
      List<int> newDice = _diceRolled.toList()..add(result);
      bool bust = (newDice.length >= 3 && newDice.sublist(newDice.length - 3).every((d) => d == 6));
      bool canStillRoll = (result == 6 && !bust);

      // ── Log dice roll ──
      _addToLog(
        LudoGameLogEntry(
          type: result == 6 ? LudoGameLogType.sixBonus : LudoGameLogType.move,
          playerName: _getPlayerName(_currentPlayer),
          playerColor: _getPlayerColor(_currentPlayer),
          message: 'رمى النرد وحصل على $result ${result == 6 ? "⭐" : ""}',
        ),
      );

      if (bust && _roomId != null) {
        _ludoGame.playThreeSixSound();
        _addToLog(
          LudoGameLogEntry(
            type: LudoGameLogType.turnChange,
            playerName: _getPlayerName(_currentPlayer),
            playerColor: _getPlayerColor(_currentPlayer),
            message: 'خسر دوره بسبب الحصول على 6 ثلاث مرات! 😮',
          ),
        );

        // FIX: Apply bust state locally BEFORE pushing to Firebase.
        // Without this, _isRolling stays true and _diceRolled stays at [6,6]
        // because the Firebase push has no lastUpdate → stateChanged=false →
        // _handleRoomUpdate skips the game-state block entirely.
        // The stale _isRolling=true blocks _reRollDice() at its guard check,
        // making the diamond button silently do nothing.
        setState(() {
          _diceRolled = newDice; // e.g. [6, 6, 6]
          _isRolling = false; // allow diamond re-roll button to work
          _canRoll = false; // no more free rolls
          _remainingTime =
              kTurnDurationSeconds; // reset timer in player's favor
        });
        _updateGame();
        _startTurnTimer();

        await LudoService().updateGameState(_roomId!, {
          'state/diceRolled': newDice,
          'state/isRolling': false,
          'state/canRoll': false,
          // Adding lastUpdate ensures stateChanged=true on all devices so
          // _handleRoomUpdate correctly processes and syncs the bust state.
          'state/lastUpdate': ServerValue.timestamp,
        });

        // If the current player is a human player (not a bot and not in auto-play),
        // we do NOT force turn transition after 1.5s.
        // Their own device's grace timer/re-roll logic will handle it!
        bool isCurrentHuman =
            !_botIndices.contains(_currentPlayer) &&
            !_autoPlayingIndices.contains(_currentPlayer);

        if (isCurrentHuman) {
          return;
        }

        await Future.delayed(const Duration(milliseconds: 1000));

        if (_isEffectiveMaster) {
          int nextPlayer = _getNextActivePlayerIndex((_currentPlayer + 1) % 4);
          await LudoService().updateGameState(_roomId!, {
            'state/diceRolled': [],
            'state/isRolling': false,
            'state/canRoll': true,
            'state/currentPlayerIndex': nextPlayer,
            'state/lastUpdate': ServerValue.timestamp,
          });
        }
        return;
      }

      if (_roomId != null) {
        await LudoService().updateGameState(_roomId!, {
          'state/diceRolled': newDice,
          'state/isRolling': false,
          'state/canRoll': canStillRoll,
        });
      }

      // ── React to six immediately after roll ──
      if (result == 6) {
        _botReactToSix(rollerGameIdx: _currentPlayer, diceValue: 6);
      }

      // If unable to move and can't roll again (not a 6), skip turn
      if (!canStillRoll && !_canMoveAnyWithDice(newDice)) {
        if (_currentPlayer != _myPlayerIndex) {
          double delaySeconds = 1.0; // Unified to 1.0s
          await Future.delayed(
            Duration(milliseconds: (delaySeconds * 1000).toInt()),
          );
          if (mounted && _currentPlayer == playerIndexAtRoll && !_isRolling) {
            _nextTurn();
          }
        }
      }
    } else {
      // Local Logic (Already existing)
      setState(() {
        _isRolling = false;
        _diceRolled.add(result);
        bool bust = (_diceRolled.length >= 3 && _diceRolled.sublist(_diceRolled.length - 3).every((d) => d == 6));
        _canRoll = (result == 6 && !bust);
        _remainingTime = kTurnDurationSeconds;
      });

      // ── React to six immediately after roll ──
      if (result == 6) {
        _botReactToSix(rollerGameIdx: _currentPlayer, diceValue: 6);
      }

      // ── Log local dice roll ──
      _addToLog(
        LudoGameLogEntry(
          type: result == 6 ? LudoGameLogType.sixBonus : LudoGameLogType.move,
          playerName: _getPlayerName(_currentPlayer),
          playerColor: _getPlayerColor(_currentPlayer),
          message: 'رمى النرد وحصل على $result ${result == 6 ? "⭐" : ""}',
        ),
      );

      if (_diceRolled.length >= 3 && _diceRolled.sublist(_diceRolled.length - 3).every((d) => d == 6)) {
        _ludoGame.playThreeSixSound();
        _addToLog(
          LudoGameLogEntry(
            type: LudoGameLogType.turnChange,
            playerName: _getPlayerName(_currentPlayer),
            playerColor: _getPlayerColor(_currentPlayer),
            message: 'حصل على 6 ثلاث مرات! 😮',
          ),
        );

        // If the current player is a human player (not a bot and not in auto-play),
        // we do NOT force turn transition after 1.5s.
        // The grace timer will handle it!
        bool isCurrentHuman =
            !_botIndices.contains(_currentPlayer) &&
            !_autoPlayingIndices.contains(_currentPlayer);

        if (isCurrentHuman) {
          return;
        }

        // Wait 1.0s and proceed to next turn for everyone
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted && _currentPlayer == playerIndexAtRoll && !_isRolling) {
          _nextTurn();
        }
        return;
      }

      _updateGame();
      _startTurnTimer();
      _updateMoveableHighlights();

      // Check auto-move for local human
      if (!_canMoveAny() && !_canRoll) {
        if (_currentPlayer != _myPlayerIndex) {
          double delaySeconds = 1.0; // Unified to 1.0s
          await Future.delayed(
            Duration(milliseconds: (delaySeconds * 1000).toInt()),
          );
          if (mounted && _currentPlayer == playerIndexAtRoll && !_isRolling) {
            _nextTurn();
          }
        }
      } else {
        _checkAutoMove();
        // Use unified scheduler for bots/auto-players
        _scheduleAutoPlayForCurrentTurn();
      }
    }
  }

  Future<bool> _deductDiamondsForExtraTurn(int amount) async {
    // In a real app, this should securely deduct from the user's wallet via Firebase or a backend.
    // Assuming a simple Local/Firebase flow for demonstration:
    try {
      final user = auth.FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          int currentDiamonds = doc.data()?['diamonds'] ?? 0;
          if (currentDiamonds >= amount) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'diamonds': currentDiamonds - amount});
            return true;
          }
        }
      }
      return false; // Not logged in or not enough
    } catch (e) {
      debugPrint("Error deducting diamonds: $e");
      return false;
    }
  }

  bool _canMoveAnyWithDice(List<int> diceList) {
    int gameIdx = _currentPlayer;
    if (_winners.contains(_currentPlayer)) {
      gameIdx = _currentPlayer ^ 2;
    }

    for (int t in _tokens[gameIdx]) {
      for (int d in diceList) {
        if (t == 0 && d == 6) return true;
        if (t > 0 && t + d <= 57) return true;
      }
    }
    return false;
  }

  bool _canMoveAny() {
    return _canMoveAnyWithDice(_diceRolled);
  }

  List<int> _getMovableTokenIndices() {
    int gameIdx = _currentPlayer;
    if (_winners.contains(_currentPlayer)) {
      gameIdx = _currentPlayer ^ 2;
    }

    List<int> movable = [];
    for (int tIdx = 0; tIdx < 4; tIdx++) {
      int tPos = _tokens[gameIdx][tIdx];
      bool canMoveToken = false;
      for (int d in _diceRolled) {
        if (tPos == 0 && d == 6) {
          canMoveToken = true;
          break;
        }
        if (tPos > 0 && tPos + d <= 57) {
          canMoveToken = true;
          break;
        }
      }
      if (canMoveToken) movable.add(tIdx);
    }
    return movable;
  }

  void _checkAutoMove() async {
    // Only for the local user's turn
    if (_currentPlayer != _myPlayerIndex && _gameMode == 'online') return;

    // Disable if Auto-Play is active for this player (let AI logic handle it)
    if (_autoPlayingIndices.contains(_currentPlayer)) return;

    // Must be in moving state (not rolling, has dice)
    if (_isRolling || _canRoll || _diceRolled.isEmpty) return;

    // Do NOT auto-move while the re-roll grace timer is active —
    // the player may still want to use their diamond re-roll.
    if (_reRollGraceRemaining > 0) return;

    // Do not auto-move if there are multiple accumulated dice (e.g., player rolled a 6 previously)
    // The player might want to think about their strategy.
    if (_diceRolled.length > 1) return;

    List<int> movable = _getMovableTokenIndices();
    if (movable.length == 1) {
      // تأخير بسيط (1.5 ثانية) للسماح للاعب برؤية النرد قبل التحريك التلقائي
      await Future.delayed(const Duration(milliseconds: 1500));
      // Re-verify state after delay
      if (mounted &&
          _currentPlayer == _myPlayerIndex &&
          !_isRolling &&
          !_canRoll &&
          _diceRolled.isNotEmpty) {
        List<int> currentMovable = _getMovableTokenIndices();
        if (currentMovable.length == 1 &&
            currentMovable.first == movable.first) {
          int gameIdx = _playerToGameIndex(_currentPlayer);
          int tIdx = movable.first;
          int currentPos = _tokens[gameIdx][tIdx];

          int validDiceIdx = -1;
          int dToUse = -1;
          for (int i = 0; i < _diceRolled.length; i++) {
            int d = _diceRolled[i];
            if (currentPos == 0) {
              if (d == 6) {
                validDiceIdx = i;
                dToUse = 6;
                break;
              }
            } else if (!_isPathBlocked(gameIdx, currentPos, d)) {
              if (currentPos + d <= 57) {
                validDiceIdx = i;
                dToUse = d;
                break;
              }
            }
          }

          if (validDiceIdx != -1) {
            _userInteraction(); // Prevents multiple rapid auto-moves from stepping on each other
            _tryMove(_currentPlayer, gameIdx, tIdx, dToUse, validDiceIdx);
          }
        }
      }
    }
  }

  void _updateMoveableHighlights() {
    if (_currentPlayer != _myPlayerIndex) {
      // Clear highlights if not my turn
      _ludoGame.syncHighlights(List.generate(4, (_) => List.filled(4, false)));
      return;
    }

    int gameIdx = _currentPlayer;
    if (_winners.contains(_currentPlayer)) {
      gameIdx = (_currentPlayer + 2) % 4;
    }

    List<List<bool>> highlightMask = List.generate(
      4,
      (_) => List.filled(4, false),
    );

    for (int tIdx = 0; tIdx < 4; tIdx++) {
      int tPos = _tokens[gameIdx][tIdx];
      bool canMoveToken = false;
      for (int d in _diceRolled) {
        if (tPos == 0 && d == 6) {
          canMoveToken = true;
          break;
        }
        if (tPos > 0 && tPos + d <= 57) {
          canMoveToken = true;
          break;
        }
      }
      highlightMask[gameIdx][tIdx] = canMoveToken;
    }

    _ludoGame.syncHighlights(highlightMask);
  }

  void _tryMove(
    int playerIndex, // Logical player (0=User, 1=AI)
    int gameIndex, // Game board index (3=Blue, 1=Green)
    int tokenIdx,
    int diceValue,
    int diceIndexInList,
  ) async {
    if (_isWinDialogShowing) return;
    // If the user moves a piece, they can no longer re-roll
    if (_reRollGraceRemaining > 0) {
      _reRollGraceTimer?.cancel();
      _reRollGraceRemaining = 0;
      if (mounted) setState(() {});
    }
    int currentPos = _tokens[gameIndex][tokenIdx];
    int nextPos = -1;

    bool canMove = false;
    if (currentPos == 0) {
      if (diceValue == 6) {
        nextPos = 1;
        canMove = true;
      }
    } else {
      if (currentPos + diceValue <= 57) {
        nextPos = currentPos + diceValue;
        canMove = true;
      }
    }

    if (canMove) {
      // Bot social reactions: rolling a 6 / deploying a token
      if (diceValue == 6) {
        _botReactToSix(rollerGameIdx: gameIndex, diceValue: diceValue);
      }
      if (currentPos == 0 && nextPos == 1) {
        _ludoGame.playNewTokenSound();
        _botReactToDeploy(deployerGameIdx: gameIndex);
      }

      // Arrow Mode Shortcut Logic
      bool isArrowMode = false;
      if (_gameMode == 'online') {
        isArrowMode = _currentMatchMode == 'arrow';
      } else {
        if (_uiState == LudoUiState.twoFourSelection) {
          isArrowMode = _twoFourMode == 'arrow';
        } else if (_uiState == LudoUiState.teamUpSelection)
          isArrowMode = _teamUpMode == 'arrow';
        else if (_uiState == LudoUiState.privateTableSelection)
          isArrowMode = _privateTableMode == 'arrow';
        else
          isArrowMode = _currentMatchMode == 'arrow';
      }

      // Arrow Mode Shortcut Logic
      if (isArrowMode) {
        // 1. Universal Square 5 Check (Global Track indices 4, 17, 30, 43)
        // This maps to local progress 5, 18, 31, 44 for player 0 (if indices match)
        // We use global track index to make it universal
        int globalIdx = (nextPos - 1 + [0, 13, 26, 39][gameIndex]) % 52;
        bool isUniversalSquare5 = [4, 17, 30, 43].contains(globalIdx);

        // 2. Specific Home Shortcut (Square 10 of the arm, local progress 49)
        // Only if this is the player's OWN arm return leg
        bool isSpecificHome10 = (nextPos == 49);

        if (isUniversalSquare5 && nextPos <= 51) {
          nextPos = nextPos + 1;
          _hasEarnedBonusDuringTurn = true;
        } else if (isSpecificHome10) {
          nextPos = 52; // Jump to Home Entrance
          _hasEarnedBonusDuringTurn = true;
        }
      }

      // Calculate new state
      List<List<int>> newTokens = _tokens.map((list) => list.toList()).toList();
      newTokens[gameIndex][tokenIdx] = nextPos;

      // Safety check for dice indexing
      if (diceIndexInList < 0 || diceIndexInList >= _diceRolled.length) {
        return;
      }

      List<int> newDiceRolled = _diceRolled.toList();
      newDiceRolled.removeAt(diceIndexInList);

      setState(() {
        _tokens[gameIndex][tokenIdx] = nextPos;
        _diceRolled.removeAt(diceIndexInList);
      });
      _updateGame(); // Instantly start token animation locally

      if (_gameMode == 'online' && _roomId != null) {
        // Push update to Firebase
        await LudoService().updateGameState(_roomId!, {
          'state/tokens': newTokens,
          'state/diceRolled': newDiceRolled,
          'state/flyingToken':
              null, // تأكيد إخلاء مسار الصاروخ لضمان حركة المشي الطبيعية
          'state/lastUpdate': ServerValue.timestamp,
        });
      }

      // Wait for animation to complete before checking capture
      // Animation duration = number of steps * 0.20 seconds per step
      int steps = (nextPos - currentPos).abs();
      if (currentPos == 0) steps = 1; // Moving from base to start
      int animationMs = (steps * 200).toInt(); // Match LudoGame 0.20s per step

      await Future.delayed(
        Duration(milliseconds: animationMs + 100),
      ); // +100ms buffer

      // Ludo X Magic Tile Check (with support for consecutive rocket chain reactions!)
      if (_ludoGame.ludoXManager != null) {
        bool hasMagicChain = true;
        int magicChainCount =
            0; // صمام أمان لمنع الحلقات غير المنتهية (بحد أقصى 5 انطلاقات متتالية)
        while (hasMagicChain && magicChainCount < 5) {
          hasMagicChain = false;
          final LudoXEffectResult? effect = _ludoGame.ludoXManager!.getEffect(
            gameIndex,
            nextPos,
            _tokens,
          );
          if (effect != null) {
            if (effect.type == MagicTileType.dice) {
              setState(() {
                _nextRollIsSix[playerIndex] = (_nextRollIsSix[playerIndex] + 1)
                    .clamp(0, 3);
              });

              // إضافة إشعار أنيق وجذاب في سجل أحداث اللعبة
              _addToLog(
                LudoGameLogEntry(
                  type: LudoGameLogType.magic,
                  playerName: _getPlayerName(playerIndex),
                  playerColor: _getPlayerColor(playerIndex),
                  message: 'التقط النرد السحري! 🎲 الرمية القادمة مضمونة 6!',
                ),
              );

              // 🌟 دفع حالة الكتل السحرية الجديدة للشبكة بعد التقاط النرد بنجاح!
              if (_gameMode == 'online' && _roomId != null) {
                await LudoService().updateGameState(_roomId!, {
                  'state/magicTiles': _ludoGame.ludoXManager!.magicTiles.map(
                    (k, v) => MapEntry(k.toString(), v.name),
                  ),
                  'state/nextRollIsSix': _nextRollIsSix,
                  'state/lastUpdate': ServerValue.timestamp,
                });
              }

              // No secondary move or flight for dice, ends the chain
              break;
            } else {
              // إنه صاروخ سحري! سنقوم بتفعيل الطيران المتسلسل
              magicChainCount++;
              int rocketStartPos = nextPos;
              int rocketLandingPos = effect.newProgress;

              // تثبيت الحجر ووقفه تماماً عند مركز خانة الصاروخ قبل بدء التحليق المنحني التالي
              _ludoGame.snapTokenToProgress(
                gameIndex,
                tokenIdx,
                rocketStartPos,
              );

              // Apply secondary move from magic tile (like rocket)
              nextPos = rocketLandingPos;

              // تفعيل حالة طيران الصاروخ للمكون البصري
              _ludoGame.setFlyingToken(gameIndex, tokenIdx);

              if (_gameMode == 'online' && _roomId != null) {
                List<List<int>> effectTokens = _tokens
                    .map((list) => list.toList())
                    .toList();
                effectTokens[gameIndex][tokenIdx] = nextPos;
                // ✅ تحقق من الالتقاء بعد التأثير السحري أيضاً — ليرى الجميع
                if (nextPos <= 51) {
                  int myGlobalAfterEffect = _toGlobal(nextPos, gameIndex);
                  for (int oppIdx = 0; oppIdx < 4; oppIdx++) {
                    if (oppIdx == gameIndex) continue;
                    if (_isTeamMode && oppIdx == (gameIndex + 2) % 4) continue;
                    for (int ti = 0; ti < 4; ti++) {
                      int oppP = effectTokens[oppIdx][ti];
                      if (oppP > 0 && oppP <= 51) {
                        int oppGlobal = _toGlobal(oppP, oppIdx);
                        if (oppGlobal == myGlobalAfterEffect &&
                            !_isPlayerSafeAt(
                              oppIdx,
                              myGlobalAfterEffect,
                              effectTokens,
                              newcomerPlayerIdx: gameIndex,
                              newcomerTokenIdx: tokenIdx,
                            )) {
                          effectTokens[oppIdx][ti] = 0;
                          _hasEarnedBonusDuringTurn = true;
                        }
                      }
                    }
                  }
                }
                await LudoService().updateGameState(_roomId!, {
                  'state/tokens': effectTokens,
                  'state/magicTiles': _ludoGame.ludoXManager!.magicTiles.map(
                    (k, v) => MapEntry(k.toString(), v.name),
                  ),
                  'state/flyingToken': {
                    'p': gameIndex,
                    't': tokenIdx,
                  }, // مزامنة تفعيل طيران الصاروخ لباقي اللاعبين
                  'state/lastUpdate': ServerValue.timestamp,
                });
              } else {
                if (mounted) {
                  setState(() {
                    _tokens[gameIndex][tokenIdx] = nextPos;
                  });
                  _updateGame();
                }
              }

              // Wait for secondary animation (matching new 1.5s majestic flight duration + buffer)
              await Future.delayed(const Duration(milliseconds: 1600));

              // مسح علم طيران الصاروخ من قاعدة البيانات فور انتهاء الطيران لمنع الحركات التالية للحجر من التحليق
              if (_gameMode == 'online' && _roomId != null) {
                await LudoService().updateGameState(_roomId!, {
                  'state/flyingToken': null,
                  'state/lastUpdate': ServerValue.timestamp,
                });
              }

              // مواصلة فحص السلسلة: سنعيد ضبط العلم للتحقق إذا كانت الخانة الجديدة تحتوي على صاروخ آخر
              hasMagicChain = true;
            }
          }
        }
      }

      // Bonus Roll Detection
      // We set the persistent flag to true if a bonus is earned in THIS move.
      // It stays true until the end of the turn (all dice used).

      // Capture logic (only for non-magic positions to avoid double-capture)
      if (nextPos <= 51) {
        int myGlobal = _toGlobal(nextPos, gameIndex);

        // Check all 4 game indices
        for (int oppGameIdx = 0; oppGameIdx < 4; oppGameIdx++) {
          // 1. Skip myself (cannot capture own tokens)
          if (oppGameIdx == gameIndex) continue;

          for (int i = 0; i < 4; i++) {
            int oppPos = _tokens[oppGameIdx][i];
            if (oppPos > 0 && oppPos <= 51) {
              int oppGlobal = _toGlobal(oppPos, oppGameIdx);
              if (oppGlobal == myGlobal) {
                if (!_isPlayerSafeAt(
                  oppGameIdx,
                  myGlobal,
                  _tokens,
                  newcomerPlayerIdx: gameIndex,
                  newcomerTokenIdx: tokenIdx,
                )) {
                  _hasEarnedBonusDuringTurn =
                      true; // Earned bonus roll for capture!

                  // Log capture event
                  final myName = _getPlayerName(gameIndex);
                  final victimName = _getPlayerName(oppGameIdx);
                  _addToLog(
                    LudoGameLogEntry(
                      type: LudoGameLogType.capture,
                      playerName: myName,
                      playerColor: _getPlayerColor(gameIndex),
                      message: 'أكل حجرة $victimName! +جولة إضافية 🎉',
                    ),
                  );

                  // Bot reactions (emoji)
                  _botReactToCapture(
                    moverGameIdx: gameIndex,
                    victimGameIdx: oppGameIdx,
                  );

                  if (_gameMode == 'online' && _roomId != null) {
                    // Update tokens for capture online
                    List<List<int>> updatedTokens = _tokens
                        .map((list) => list.toList())
                        .toList();
                    updatedTokens[oppGameIdx][i] = 0;
                    await LudoService().updateGameState(_roomId!, {
                      'state/tokens': updatedTokens,
                      'state/lastUpdate': ServerValue.timestamp,
                    });
                  } else {
                    setState(() {
                      _tokens[oppGameIdx][i] = 0;
                    });
                  }
                }
              }
            }
          }
        }
      }

      // Reaching home triangle bonus
      if (nextPos == 57) {
        _hasEarnedBonusDuringTurn = true;
      }

      // 🌟 تصفية التأثيرات السحرية (مثل الظلام) بعد انتهاء الحركة
      // كما طلب المستخدم: "يجب أن يتم رفع التعتيم فقط بعد أن يتم تحريك الحجر"
      if (_ludoGame.ludoXManager != null) {
        _ludoGame.ludoXManager?.networkManager?.clearEffect();
      }

      // Win Check
      if (_tokens[gameIndex].every((t) => t == 57)) {
        if (!_winners.contains(gameIndex)) {
          List<int> updatedWinners = _winners.toList();
          updatedWinners.add(gameIndex);

          if (_gameMode == 'online' && _roomId != null) {
            // Push winners update to Firebase
            await LudoService().updateGameState(_roomId!, {
              'state/winners': updatedWinners,
              'state/lastUpdate': ServerValue.timestamp,
            });

            // If this was the second-to-last non-leaver player, finish the game
            // (e.g. 4 players total, 2 winners, 1 leaver -> 1 remains -> Game over)
            int totalParticipants = _onlinePlayerNames.length;
            int remainingToFinish =
                totalParticipants - updatedWinners.length - _leavers.length;

            bool team0Won =
                updatedWinners.contains(0) && updatedWinners.contains(2);
            bool team1Won =
                updatedWinners.contains(1) && updatedWinners.contains(3);

            if (remainingToFinish <= 1 ||
                (_isTeamMode && (team0Won || team1Won))) {
              await LudoService().updateGameState(_roomId!, {
                'status': 'finished',
                'state/lastUpdate': ServerValue.timestamp,
              });
            }
          } else {
            setState(() {
              _winners = updatedWinners;
            });
            // Local Team Win Check
            bool team0Won = _winners.contains(0) && _winners.contains(2);
            bool team1Won = _winners.contains(1) && _winners.contains(3);
            if (_isTeamMode && (team0Won || team1Won)) {
              // The UI state logic usually handles finishing, but let's ensure it stops
              debugPrint("Team Won in local mode! Game should end.");
            }
          }

          // Show dialog for the finisher
          if (_gameMode == 'online') {
            if (gameIndex == _myPlayerIndex) {
              _hasSeenMyWinDialog = true;
              _showWinDialog(gameIndex);
            }
          } else {
            // Offline/Local match: first player (human or bot) who finishes triggers the win dialogue!
            _hasSeenMyWinDialog = true;
            _showWinDialog(gameIndex);
          }
        }
      }

      // 4. Bonus Roll Logic: Grant immediately if earned
      if (_hasEarnedBonusDuringTurn) {
        await Future.delayed(const Duration(milliseconds: 400));
        _grantBonusRoll();
        return;
      }

      // 5. Normal turn progression if no bonus earned
      if (_diceRolled.isNotEmpty) {
        if (!_canMoveAny()) {
          int delay = 1000; // Unified to 1.0 second
          await Future.delayed(Duration(milliseconds: delay));
          if (mounted &&
              _currentPlayer == playerIndex &&
              !_isRolling &&
              _diceRolled.isNotEmpty) {
            _nextTurn();
          }
        } else {
          setState(() {
            _remainingTime = kTurnDurationSeconds;
          });
          _startTurnTimer();

          _updateMoveableHighlights();
          _checkAutoMove(); // Trigger auto-move check for next dice
          // Use unified scheduler for continuous moves
          _scheduleAutoPlayForCurrentTurn();
        }
      } else {
        // No dice remaining. Check if there's a pending roll (from rolling a 6)
        if (_canRoll) {
          // If it's a bot's turn OR an auto-playing human's turn, trigger roll automatically
          if (_botIndices.contains(_currentPlayer) ||
              _autoPlayingIndices.contains(_currentPlayer)) {
            // Keep game active in local mode or online master mode
            bool ownsControl = (_gameMode != 'online') || (_isEffectiveMaster);
            if (ownsControl) {
              Future.delayed(const Duration(milliseconds: 300), _rollDice);
            }
          }
          // For manual human, the UI will show the roll button naturally
        } else {
          // Truly end of turn
          int delay = 1000; // Unified to 1.0 second
          await Future.delayed(Duration(milliseconds: delay));
          if (mounted &&
              _currentPlayer == playerIndex &&
              !_isRolling &&
              _diceRolled.isEmpty &&
              !_canRoll) {
            _nextTurn();
          }
        }
      }
    } else {
      if (playerIndex == _myPlayerIndex &&
          !_autoPlayingIndices.contains(_myPlayerIndex)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("حركة غير مسموحة")));
      }
    }
  }

  int _toGlobal(int localPos, int gameIndex) {
    if (localPos <= 0 || localPos > 51) return -1;
    int offset = [0, 13, 26, 39][gameIndex];
    return (localPos - 1 + offset) % 52;
  }

  bool _isPathBlocked(int gameIndex, int currentPos, int steps) {
    // Blockade rule disabled as requested: Everyone can pass stacked tokens.
    return false;
  }

  bool _isSafe(int global) {
    List<int> safes = [0, 8, 13, 21, 26, 34, 39, 47];
    return safes.contains(global);
  }

  bool _isPlayerSafeAt(
    int playerIndex,
    int global,
    List<List<int>> currentTokens, {
    int? newcomerPlayerIdx,
    int? newcomerTokenIdx,
  }) {
    if (_isSafe(global)) return true;

    // A spot is considered safe if it contains 2 or more tokens of ANY color.
    int totalOccupants = 0;
    for (int p = 0; p < 4; p++) {
      for (int t = 0; t < 4; t++) {
        // When checking for a tentative capture, we exclude the moving token (newcomer)
        // because we want to know if the target spot was ALREADY safe or is safe for residents.
        if (p == newcomerPlayerIdx && t == newcomerTokenIdx) continue;

        int pos = currentTokens[p][t];
        if (pos > 0 && pos <= 51 && _toGlobal(pos, p) == global) {
          totalOccupants++;
        }
      }
    }

    // According to the new rule: If there are 2 or more tokens (even mixed), it's a safe zone.
    return totalOccupants >= 2;
  }

  int _getNextActivePlayerIndex(int startIndex) {
    int nextPlayer = startIndex;
    int count = 0;
    while (count < 4) {
      bool isParticipant = (_gameMode == 'online')
          ? _onlinePlayerNames.containsKey(nextPlayer)
          : _isPlayerActive(nextPlayer);

      if (isParticipant && !_leavers.contains(nextPlayer)) {
        bool hasFinished = _winners.contains(nextPlayer);
        final int partnerIdx = (nextPlayer + 2) % 4;
        bool teammateFinished = _winners.contains(partnerIdx);

        // In team mode, a player keeps getting turns until the WHOLE team has finished.
        if (!hasFinished || (_isTeamMode && !teammateFinished)) {
          return nextPlayer;
        }
      }
      nextPlayer = (nextPlayer + 1) % 4;
      count++;
    }
    return startIndex;
  }

  void _grantBonusRoll() async {
    if (_isWinDialogShowing) return;
    if (_gameMode == 'online' && _roomId != null) {
      await LudoService().updateGameState(_roomId!, {
        'state/diceRolled': _diceRolled, // Preserve unplayed dice
        'state/canRoll': true,
        'state/isRolling': false,
        'state/lastUpdate': ServerValue.timestamp,
      });
      // Reset local flag
      if (mounted) {
        setState(() {
          _hasEarnedBonusDuringTurn = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _hasEarnedBonusDuringTurn = false; // Reset flag
        // Note: _diceRolled is NOT cleared to preserve unplayed numbers
        _canRoll = true;
        _isRolling = false;
        _remainingTime = kTurnDurationSeconds; // Reset timer for bonus roll
      });
      _updateGame();
      _startTurnTimer();
    }

    // Trigger auto-roll if needed
    _scheduleAutoPlayForCurrentTurn();
  }

  void _nextTurn() async {
    if (_isWinDialogShowing) return;
    _reRollGraceTimer?.cancel();
    setState(() {
      _reRollGraceRemaining = 0.0;
    });

    _isAiThinking = false;
    if (_gameMode == 'online' && _roomId != null) {
      // Switch to next active player
      int nextPlayer = _getNextActivePlayerIndex((_currentPlayer + 1) % 4);

      await LudoService().updateGameState(_roomId!, {
        'state/currentPlayerIndex': nextPlayer,
        'state/diceRolled': [],
        'state/canRoll': true,
        'state/isRolling': false,
        'state/lastUpdate': ServerValue.timestamp,
      });
      setState(() {
        _hasEarnedBonusDuringTurn = false;
        _sentHurryThisTurn = false; // Reset hurry flag for next turn
        _blueButtonClicksThisTurn = 0;
      });
      // Trigger random bot chatter occasionally in online mode too
      _botRandomChatter();
      return;
    }

    setState(() {
      _hasEarnedBonusDuringTurn = false;
      _sentHurryThisTurn = false; // Reset hurry flag for new turn
      _blueButtonClicksThisTurn = 0;
      _currentPlayer = _getNextActivePlayerIndex(_currentPlayer);
      _diceRolled.clear();
      _canRoll = true;
      _isRolling = false;
      // Reset Timer
      _remainingTime = kTurnDurationSeconds;
    });
    _updateMoveableHighlights(); // Clear highlights for next player
    _updateGame();
    _startTurnTimer(); // Restart timer for new turn

    // Log turn change
    _addToLog(
      LudoGameLogEntry(
        type: LudoGameLogType.turnChange,
        playerName: _getPlayerName(_currentPlayer),
        playerColor: _getPlayerColor(_currentPlayer),
        message: 'دوره الآن',
      ),
    );

    // Occasional bot chatter after each turn change
    _botRandomChatter();

    _scheduleAutoPlayForCurrentTurn();
  }
}
