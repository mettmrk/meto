// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api
part of 'ludo_screen.dart';

/// UI widget construction methods.
extension LudoScreenUIWidgets on _LudoScreenState {
  Future<String?> _getSmartBotComment({
    required int pIndex,
    required String event,
  }) async {
    if (!AIService.hasKey) return null;

    final profile = _botProfiles[pIndex];
    if (profile == null) return null;

    final personalityStr = switch (profile.personality) {
      LudoBotPersonality.aggressive => "هجومي، متنمّر قليلاً، يضحك عند الفوز",
      LudoBotPersonality.defensive => "حذر، معتذر، يحب اللعب بأمان",
      LudoBotPersonality.balanced => "متوازن، يتحدث بعقلانية ومرح",
      LudoBotPersonality.random => "عشوائي، مرح جداً، يتكلم بكلام غريب ومضحك",
    };

    // Construct a simple context
    String context =
        "اللاعب الحالي هو ${pIndex == _currentPlayer ? 'صاحب الدور' : 'مراقب'}. ";
    context += "أنت تلعب ضد: ${_onlinePlayerNames.values.join(', ')}. ";
    if (_winners.isNotEmpty) {
      context +=
          "الفائزون حتى الآن: ${_winners.map((w) => _getPlayerName(w)).join(', ')}.";
    }

    return await AIService.getBotResponse(
      botName: profile.name,
      personality: personalityStr,
      event: event,
      context: context,
    );
  }

  Future<String?> _getSmartChatResponse({
    required int pIndex,
    required String userMessage,
  }) async {
    if (!AIService.hasKey) return null;

    final profile = _botProfiles[pIndex];
    if (profile == null) return null;

    final personalityStr = switch (profile.personality) {
      LudoBotPersonality.aggressive => "هجومي، متنمّر قليلاً، يضحك عند الفوز",
      LudoBotPersonality.defensive => "حذر، معتذر، يحب اللعب بأمان",
      LudoBotPersonality.balanced => "متوازن، يتحدث بعقلانية ومرح",
      LudoBotPersonality.random => "عشوائي، مرح جداً، يتكلم بكلام غريب ومضحك",
    };

    // Construct a simple context
    String context =
        "اللاعب الحالي هو ${pIndex == _currentPlayer ? 'صاحب الدور' : 'مراقب'}. ";
    context += "أنت تلعب ضد: ${_onlinePlayerNames.values.join(', ')}. ";

    return await AIService.getChatResponse(
      botName: profile.name,
      personality: personalityStr,
      userMessage: userMessage,
      context: context,
    );
  }

  void _handleNewInteraction(int pIdx, Map<String, dynamic> data) {
    if (_silencedPlayerIndices.contains(pIdx)) return;

    final timestamp = data['timestamp'];
    if (timestamp == null) return;

    // Check if we already showed this one or a newer one
    final lastSeen = _lastSeenInteractions[pIdx];
    if (lastSeen != null && lastSeen >= (timestamp as num).toInt()) return;

    _lastSeenInteractions[pIdx] = (timestamp as num).toInt();

    if (!mounted) return;

    final interactionType = data['type'] as String? ?? 'text';
    if (interactionType == 'diamondReRoll') {
      return; // Suppress any dynamic bubble, notification, or logs when diamonds are used
    }

    _uiController.setActiveInteraction(pIdx, data);

    // Update unread count if receiver window is closed and message is from others
    if (interactionType == 'text' || interactionType == 'sticker') {
      if (!_isChatInputOpen && pIdx != _myPlayerIndex) {
        setState(() => _unreadMessagesCount++);
      }
    }

    // ── Log this interaction in the game history ───────────────────────────
    final content = data['content'] as String? ?? '';

    LudoGameLogType logType;
    String logMessage;

    if (interactionType == 'sticker') {
      logType = LudoGameLogType.sticker;
      logMessage = 'أرسل ملصق $content';
    } else {
      logType = LudoGameLogType.chat;
      logMessage = content;
    }

    _addToLog(
      LudoGameLogEntry(
        type: logType,
        playerName: _getPlayerName(pIdx),
        playerColor: _getPlayerColor(pIdx),
        message: logMessage,
      ),
    );

    // AI Chat response: if user sends a text message, the first bot replies (offline mode or master in online)
    if (pIdx == _myPlayerIndex &&
        interactionType == 'text' &&
        _botIndices.isNotEmpty) {
      final botIdx = _botIndices.first;
      _getSmartChatResponse(pIndex: botIdx, userMessage: content).then((aiMsg) {
        if (!mounted || aiMsg == null) return;

        // Natural delay before bot replies
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          _handleNewInteraction(botIdx, {
            'type': 'text',
            'content': aiMsg,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
        });
      });
    }

    // Clear after 4 seconds
    _uiController.clearInteractionAfterDelay(pIdx, const Duration(seconds: 4));
  }

  void _resetInteractions() {
    _uiController.reset();
    _lastSeenInteractions.clear();
  }

  String _getBackgroundImageAsset() {
    switch (_boardTheme) {
      case 'classic': return 'assets/images/ludo_classic_bg.png';
      case 'river': return 'assets/images/ludo_river_bg.png';
      case 'ice': return 'assets/images/ludo_ice_bg.png';
      case 'board1': return 'assets/images/ludo_neon_bg.png';
      case 'board4': return 'assets/images/ludo_blue_bg.png';
      case 'board5': return 'assets/images/ludo_purple_bg.png';
      case 'board6': return 'assets/images/ludo_emerald_bg.png';
      case 'board7': return 'assets/images/ludo_forest_bg.png';
      case 'board8': return 'assets/images/ludo_royal_bg.png';
      default: return 'assets/images/ludo_purple_bg.png';
    }
  }

  Widget _buildMainBody(Widget? gameBoard) {
    // Note: board is now accessed via _cachedBoardLayer
    final size = MediaQuery.of(context).size;
    final double boardSize = size.width - 20;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0B0D17), // Opaque dark background to hide underlying screens
      body: GestureDetector(
        onTapDown: (_) => _userInteraction(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Background Layer - Dynamic Based on Theme (Cached with RepaintBoundary)
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: (_hallImageUrl != null && _hallImageUrl!.isNotEmpty && _boardTheme == 'classic')
                      ? Image.network(
                          _hallImageUrl!,
                          key: ValueKey(_hallImageUrl),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              _getBackgroundImageAsset(),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            );
                          },
                        )
                      : Image.asset(
                          _getBackgroundImageAsset(),
                          key: ValueKey(_getBackgroundImageAsset()),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                ),
              ),
            ),
            // Overlay to dim the background so the Ludo board design is more visible
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
            // 1b. Light Leaks / Atmospheric Glows Removed to prevent "تشويش" (blur/distortion)
            // as requested by the user. New thematic backgrounds don't need them.
            const SizedBox.shrink(),

            // 2. Premium Glassmorphic Game Board
            Align(
              alignment: Alignment.center,
              child: Container(
                width: boardSize,
                height: boardSize,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, 15),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Glass Layer (No heavy blur filter to avoid GPU scrambling and lag)
                      Positioned.fill(
                        child: Container(
                          color:
                              (_boardTheme == 'classic' ||
                                  _boardTheme == 'ice' ||
                                  _boardTheme == 'board2')
                              ? (_boardTheme == 'classic'
                                        ? Colors.orange
                                        : (_boardTheme == 'ice'
                                              ? Colors.blue
                                              : Colors.blueGrey))
                                    .withValues(alpha: 0.12)
                              : (_boardTheme == 'board3' ||
                                    _boardTheme == 'board4')
                              ? Colors.blue.withValues(alpha: 0.12)
                              : (_boardTheme == 'board1' ||
                                    _boardTheme == 'board5' ||
                                    _boardTheme == 'board6' ||
                                    _boardTheme == 'board7' ||
                                    _boardTheme == 'board8')
                              ? (_boardTheme == 'board1' ||
                                            _boardTheme == 'board5'
                                        ? Colors.purple
                                        : (_boardTheme == 'board8'
                                              ? Colors.blueAccent
                                              : Colors.green))
                                    .withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      // The Game Content
                      RepaintBoundary(
                        child: KeyedSubtree(
                          key: ValueKey(_boardTheme),
                          child: gameBoard ?? const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. UI Overlay Layer (Wrapped in ListenableBuilder for isolation)
            ListenableBuilder(
              listenable: _uiController,
              builder: (context, _) {
                return Stack(
                  children: [
                    // Top Bar (Centered Viewer Count + Settings)
                    Positioned(
                      top: 40,
                      left: 16,
                      right: 16,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. Viewer Count (Center)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.remove_red_eye,
                                  color: Colors.white70,
                                  size: 15,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "0",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 2. Settings Button (Right)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(2),
                                    icon: const Icon(
                                      Icons.settings,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    onPressed: _showAudioSettingsDialog,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Player Avatars
                    ..._buildAllAvatarWidgets(),

                    // Bottom Capsule Buttons Bar
                    _buildBottomCapsuleBar(),

                    // Interaction Popover (appears above the stickers icon)
                    if (_uiController.isInteractionMenuOpen)
                      Positioned(
                        bottom: 60, // Above the capsule bar
                        left: 15,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 380, // Medium width for popover
                            height: 455,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: LudoInteractionBottomSheet(
                              roomId: _roomId,
                              interactionType: 'stickers',
                              height: 455,
                              onClose: () =>
                                  _uiController.isInteractionMenuOpen = false,
                              onSend: (type, content) {
                                if (_roomId == null) {
                                  _handleNewInteraction(_myPlayerIndex, {
                                    'type': type,
                                    'content': content,
                                    'timestamp':
                                        DateTime.now().millisecondsSinceEpoch,
                                  });
                                } else {
                                  LudoService().sendInteraction(
                                    _roomId!,
                                    type,
                                    content,
                                  );
                                }
                                _uiController.isInteractionMenuOpen = false;
                              },
                            ),
                          ),
                        ),
                      ),

                    // Chat Input Window
                    if (_isChatInputOpen)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 85,
                        child: _buildChatInputPanel(),
                      ),

                    // Game Log Panel
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildGameLogPanel(),
                    ),

                    // Turn Indicator
                    if (_autoPlayingIndices.contains(_myPlayerIndex) &&
                        _currentPlayer == _myPlayerIndex)
                      _buildAutoplayIndicator(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAllAvatarWidgets() {
    List<Widget> avatarWidgets = [];
    for (int i = 0; i < 4; i++) {
      if (_isPlayerActive(i)) {
        int vIdx = _toVisualIndex(i);
        double? top, bottom, left, right;
        switch (vIdx) {
          case 0: // Top-Left opponent
            top = 120;
            left = 26;
            break;
          case 1: // Top-Right opponent
            top = 120;
            right = 26;
            break;
          case 2: // Bottom-Right opponent
            bottom = 120;
            right = 26;
            break;
          case 3: // Bottom-Left (local user)
            bottom = 120;
            left = 20;
            break;
        }

        bool diceOnRight = (vIdx == 0 || vIdx == 3);
        Widget diceWidget = _buildDiceForPlayer(i);

        Widget avatarWidget = _buildAvatar(
          i,
          _getPlayerName(i),
          _getPlayerColor(i),
          diceWidget: diceWidget,
          diceOnRight: diceOnRight,
        );

        avatarWidgets.add(
          Positioned(
            top: top,
            bottom: bottom,
            left: left,
            right: right,
            child: avatarWidget,
          ),
        );
      }
    }
    return avatarWidgets;
  }

  Widget _buildBottomCapsuleBar() {
    bool isAuto = _autoPlayingIndices.contains(_myPlayerIndex);
    return Positioned(
      bottom: 20,
      left: 15,
      child: Row(
        children: [
          // Auto-Play Toggle Button
          _buildBottomCapsuleButton(
            onTap: () {
              if (isAuto) {
                _stopAutoPlay();
              } else {
                _enableAutoPlay();
              }
            },
            colors: isAuto
                ? [const Color(0xFF00E676), const Color(0xFF1DE9B6)]
                : [const Color(0xFFC0C0C0), const Color(0xFF808080)],
            child: Icon(
              Icons.smart_toy_outlined,
              color: isAuto ? Colors.black87 : Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Consumer<VoiceRoomService>(
            builder: (context, voice, _) {
              final isTalking = voice.isUserTalking(voice.currentUserId);
              return _buildBottomCapsuleButton(
                onTap: _toggleMic,
                colors: voice.isGameMuted
                    ? [const Color(0xFFC0C0C0), const Color(0xFF808080)]
                    : [const Color(0xFFFFD54F), const Color(0xFFFBC02D)],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      voice.isGameMuted ? Icons.mic_off : Icons.mic,
                      color: voice.isGameMuted
                          ? Colors.white70
                          : const Color(0xFF5D4037),
                      size: 14,
                    ),
                    if (!voice.isGameMuted && isTalking) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.8),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          _buildBottomCapsuleButton(
            onTap: () {
              final isOpen = _uiController.isInteractionMenuOpen;
              _uiController.isInteractionMenuOpen = !isOpen;
              if (_uiController.isInteractionMenuOpen) {
                setState(() => _unreadMessagesCount = 0);
              }
            },
            colors: [const Color(0xFFFFD700), const Color(0xFFFFA500)],
            child: const Icon(
              Icons.sentiment_very_satisfied,
              color: Color(0xFF5D4037),
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          _buildBottomCapsuleButton(
            onTap: () {
              _uiController.isChatInputOpen = !_uiController.isChatInputOpen;
              if (_uiController.isChatInputOpen) {
                _scrollToBottom();
                setState(() => _unreadMessagesCount = 0);
              }
            },
            badgeCount: _unreadMessagesCount,
            colors: [const Color(0xFFFFD54F), const Color(0xFFFBC02D)],
            child: Icon(
              _isChatInputOpen ? Icons.close : Icons.chat_bubble,
              color: Color(0xFF5D4037),
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          if (_uiState != LudoUiState.playing)
            _buildBottomCapsuleButton(
              onTap: _showCustomizationDialog,
              colors: [const Color(0xFF2962FF), const Color(0xFF00B0FF)],
              child: const Icon(
                Icons.palette_outlined,
                color: Colors.white,
                size: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAutoplayIndicator() {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: const SizedBox.shrink(),
    );
  }

  Widget _getMatchmakingAvatarForIndex(int idx) {
    // If it's ME
    if (idx == _myPlayerIndex) {
      return _buildMatchmakingAvatar(
        _userName,
        _userProfileImage,
        _getPlayerColor(idx),
        true,
      );
    }

    // If it's an online player or bot
    if (_onlinePlayerNames.containsKey(idx)) {
      final botProfile = _botProfiles[idx];
      return _buildMatchmakingAvatar(
        _onlinePlayerNames[idx] ?? '...',
        _onlinePlayerImages[idx],
        _getPlayerColor(idx),
        true,
        botImage: botProfile?.botImage,
      );
    }

    // Otherwise, it's an empty slot
    return _buildMatchmakingAvatar('جاري البحث...', null, Colors.grey, false);
  }

  Widget _buildConnectingOverlay() {
    final bool hasFoundOpponent = _matchFoundAnimation || _onlinePlayerNames.length > 1;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B0D17), // Deep space blue
              Color(0xFF112338), // Dark navy
              Color(0xFF1D5C6F), // Muted teal-blue
            ],
          ),
        ),
        child: Stack(
          children: [
            // ── 1. BACKGROUND DECORATIONS ──
            // Subtle twinkling stars (Reduced for battery optimization)
            ...List.generate(15, (index) {
              final random = Random(index + 100);
              return Positioned(
                left: random.nextDouble() * MediaQuery.of(context).size.width,
                top: random.nextDouble() * MediaQuery.of(context).size.height,
                child: _TwinklingStar(random: random),
              );
            }),

            // The Moon (Top Center)
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: 0.15,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.2),
                          blurRadius: 100,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.nightlight_round,
                      size: 200,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            // Settings Button (top-right)
            Positioned(
              top: 20,
              right: 20,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: Colors.white38,
                    size: 26,
                  ),
                  onPressed: _showAudioSettingsDialog,
                ),
              ),
            ),

            // ── 2. MAIN CONTENT ──
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Header Ludo Visual (Generated Image)
                  Center(
                    child: _MatchmakingRotatingFrame(
                      size: 90,
                      child: Image.asset(
                        'assets/images/ludo_games_icon.png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white24,
                            size: 60,
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Rank and Entry Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _showTotalPotInMatchmaking
                              ? [
                                  Colors.amber.withValues(alpha: 0.15),
                                  Colors.amber.withValues(alpha: 0.25),
                                  Colors.amber.withValues(alpha: 0.15),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.05),
                                  Colors.white.withValues(alpha: 0.1),
                                  Colors.white.withValues(alpha: 0.05),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: _showTotalPotInMatchmaking
                              ? Colors.amber.withValues(alpha: 0.4)
                              : Colors.white10,
                          width: _showTotalPotInMatchmaking ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                _showTotalPotInMatchmaking
                                    ? 'مجموع الرهان 🏆'
                                    : 'الترتيب 1',
                                style: GoogleFonts.tajawal(
                                  color: _showTotalPotInMatchmaking
                                      ? Colors.amber
                                      : Colors.amberAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!_showTotalPotInMatchmaking)
                                const SizedBox(width: 8),
                              if (!_showTotalPotInMatchmaking)
                                const Icon(
                                  Icons.emoji_events_outlined,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                            ],
                          ),
                          AnimatedScale(
                            scale: _showTotalPotInMatchmaking ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const GoldCoin(size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  _showTotalPotInMatchmaking
                                      ? _formatMatchmakingNumber(
                                          _selectedBet *
                                              _currentMatchMaxPlayers,
                                        )
                                      : _formatMatchmakingNumber(_selectedBet),
                                  style: GoogleFonts.outfit(
                                    color: _showTotalPotInMatchmaking
                                        ? Colors.amberAccent
                                        : Colors.white,
                                    fontSize: 14,
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

                  const SizedBox(height: 15),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const GoldCoin(size: 20),
                      const SizedBox(width: 6),
                      Text(
                        _showTotalPotInMatchmaking
                            ? 'تم تجميع الرهان: ${_formatMatchmakingNumber(_selectedBet * _currentMatchMaxPlayers)}'
                            : 'عملات الدخول ${_formatMatchmakingNumber(_selectedBet)}',
                        style: GoogleFonts.tajawal(
                          color: _showTotalPotInMatchmaking
                              ? Colors.amberAccent
                              : Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // ── 3. FLAGS AREA ──
                  Expanded(
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // Crossed Poles
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.rotate(
                                  angle: -pi / 8,
                                  child: Container(
                                    width: 2,
                                    height: 300,
                                    color: Colors.white12,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Transform.rotate(
                                  angle: pi / 8,
                                  child: Container(
                                    width: 2,
                                    height: 300,
                                    color: Colors.white12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Flags
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Team A (Red/Yellow Pair: 0 & 2)
                                _MatchmakingFlag(
                                  imagePath: 'assets/images/gams/red2x.png',
                                  playerAvatars: [
                                    _getMatchmakingAvatarForIndex(0),
                                    if (_currentMatchMaxPlayers == 4)
                                      _getMatchmakingAvatarForIndex(2),
                                  ],
                                  alignLeft: true,
                                ),
                                const SizedBox(width: 40),
                                // Team B (Green/Blue Pair: 1 & 3)
                                _MatchmakingFlag(
                                  imagePath: 'assets/images/gams/blu1x.png',
                                  playerAvatars: [
                                    _getMatchmakingAvatarForIndex(
                                      _currentMatchMaxPlayers == 2 ? 2 : 1,
                                    ),
                                    if (_currentMatchMaxPlayers == 4)
                                      _getMatchmakingAvatarForIndex(3),
                                  ],
                                  alignLeft: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_matchFoundAnimation) const _PulseDot(),
                      if (!_matchFoundAnimation) const SizedBox(width: 10),
                      Text(
                        _matchFoundAnimation
                            ? 'تبدأ المباراة خلال $_matchCountdown ثواني... 🎲'
                            : 'جاري البحث عن خصم...',
                        style: GoogleFonts.tajawal(
                          color: _matchFoundAnimation
                              ? Colors.amberAccent
                              : Colors.white70,
                          fontSize: _matchFoundAnimation ? 16 : 13,
                          fontWeight: _matchFoundAnimation
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  if (!hasFoundOpponent) const SizedBox(height: 25),

                  // Cancel Search Button
                  if (!hasFoundOpponent)
                    GestureDetector(
                      onTap: () => _backToMenu(),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 25),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 35,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          'إلغاء البحث',
                          style: GoogleFonts.tajawal(
                            color: Colors.white38,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  Widget _buildMatchmakingAvatar(
    String name,
    String? photo,
    Color color,
    bool found, {
    String? botImage,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // ── 1. BACKGROUND GLOW ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: found ? 80 : 60,
              height: found ? 80 : 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (found ? color : Colors.white10).withValues(
                      alpha: found ? 0.3 : 0.05,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // ── 2. PULSING SCANNER FOR SEARCHING ──
            if (!found)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Container(
                    width: 50 + (15 * value),
                    height: 50 + (15 * value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.cyanAccent.withValues(alpha: 1.0 - value),
                        width: 1.0,
                      ),
                    ),
                  );
                },
              ),

            // ── 3. CONTINUOUSLY SPINNING RING ──
            _AvatarSpinningRing(isSearching: !found, color: color),

            // ── 4. AVATAR CONTAINER ──
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: found ? color : Colors.white10,
                  width: found ? 1.5 : 1,
                ),
              ),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: found ? Colors.black : Colors.black45,
                  border: found
                      ? null
                      : Border.all(color: Colors.white10, width: 0.5),
                  boxShadow: [
                    if (found)
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: found
                    ? (botImage != null
                          ? Image.asset(botImage, fit: BoxFit.cover)
                          : (photo != null
                                ? Image(
                                    image: _getAvatarProvider(photo)!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        color: Colors.white24,
                                        size: 24,
                                      );
                                    },
                                  )
                                : const Icon(
                                    Icons.person,
                                    color: Colors.white24,
                                    size: 24,
                                  )))
                    : Center(
                        child: Opacity(
                          opacity: 0.8,
                          child: Lottie.asset(
                            'assets/lottie/Idea.json',
                            width: 30,
                            height: 30,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // NAME TAG (Compact)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: found
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: found ? Colors.white10 : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  color: found ? Colors.white : Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (found)
                Text(
                  'READY',
                  style: GoogleFonts.outfit(
                    color: Colors.greenAccent,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(
    int pIndex,
    String name,
    Color color, {
    Widget? diceWidget,
    bool diceOnRight = false,
  }) {
    bool isTurn = _currentPlayer == pIndex;
    int vIdx = _toVisualIndex(pIndex);
    _silencedPlayerIndices.contains(pIndex);

    Widget buildYellowDiceIndicator() {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.5),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '6',
            style: TextStyle(
              color: Colors.black,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              fontFamily: 'Tajawal',
            ),
          ),
        ),
      );
    }

    Widget avatarStack = Container(
      margin: EdgeInsets.only(
        left: vIdx == 3 ? 26.0 : 0.0,
        right: vIdx != 3 ? 26.0 : 0.0,
      ),
      child: GestureDetector(
        onTap: () => _showPlayerProfile(pIndex),
        child: SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Background circle for the avatar (Glassmorphic)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),

              // Avatar Image
              Consumer<VoiceRoomService>(
                builder: (context, voice, _) {
                  final myId = auth.FirebaseAuth.instance.currentUser?.uid;
                  String? pUid;
                  if (_gameMode == 'online') {
                    pUid = _onlinePlayerUids[pIndex];
                    if (pUid == null && pIndex == _myPlayerIndex) {
                      pUid = myId;
                    }
                  } else {
                    pUid = (pIndex == _myPlayerIndex) ? myId : null;
                  }
                  final isTalking = voice.isUserTalking(pUid);
                  final isOnline = voice.isUserInRoom(pUid);

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isTalking
                            ? Colors.cyanAccent
                            : (isOnline
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.transparent),
                        width: isTalking ? 3 : 1.5,
                      ),
                      boxShadow: [
                        if (isTalking)
                          BoxShadow(
                            color: Colors.cyanAccent.withValues(alpha: 0.8),
                            blurRadius: 15,
                            spreadRadius: 4,
                          ),
                      ],
                    ),
                    child: ClipOval(
                      child: Stack(
                        children: [
                          Container(
                            color: color.withValues(alpha: 0.2),
                            child: _getProfileImage(pIndex, color),
                          ),
                          if (_leavers.contains(pIndex))
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.5),
                                child: const Center(
                                  child: Text(
                                    'مغادر',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Tajawal',
                                    ),
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

              // Name and History shown ABOVE avatar for bottom players (closer to board edge)
              if (vIdx == 2 || vIdx == 3)
                Positioned(
                  bottom: 56,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🌟 النرد الأصفر المضمون مكدس فوق الاسم بوضوح تام للاعبي الأسفل
                      if (_nextRollIsSix[pIndex] > 0) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            _nextRollIsSix[pIndex],
                            (idx) => buildYellowDiceIndicator(),
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ), // مسافة أنيقة ومريحة فوق الاسم
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _getDisplayName(pIndex, name),
                          style: TextStyle(
                            color: isTurn ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_currentPlayer == pIndex &&
                          _diceRolled.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _diceRolled.map((value) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  value.toString(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

              // History shown ABOVE avatar for top players
              if ((vIdx == 0 || vIdx == 1) &&
                  _currentPlayer == pIndex &&
                  _diceRolled.isNotEmpty)
                Positioned(
                  bottom: 56,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _diceRolled.map((value) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 2),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            value.toString(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // Name shown BELOW avatar for top players (with stacked yellow dice placed directly ABOVE the name container!)
              if (vIdx == 0 || vIdx == 1)
                Positioned(
                  top: 50,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🌟 النرد الأصفر المضمون مكدس فوق الاسم بوضوح تام للاعبي الأعلى
                      if (_nextRollIsSix[pIndex] > 0) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            _nextRollIsSix[pIndex],
                            (idx) => buildYellowDiceIndicator(),
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ), // مسافة أنيقة ومريحة فوق الاسم
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _getDisplayName(pIndex, name),
                          style: TextStyle(
                            color: isTurn ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Interaction bubble ──
              if (_activeInteractions.containsKey(pIndex))
                Builder(
                  builder: (_) {
                    final interaction = _activeInteractions[pIndex]!;
                    final isStickerType = interaction['type'] == 'sticker';
                    if (isStickerType) {
                      return Positioned.fill(
                        child: IgnorePointer(
                          child: _buildStickerOverlay(
                            interaction['content'] as String? ?? '',
                          ),
                        ),
                      );
                    }
                    // For local player (vIdx==3): bubble goes right to avoid left edge
                    bool isTop = (vIdx == 0 || vIdx == 1);
                    return Positioned(
                      bottom: isTop ? null : 62,
                      top: isTop ? 70 : null,
                      left: vIdx == 3 ? 0 : -30,
                      right: vIdx == 3 ? -80 : -30,
                      child: IgnorePointer(
                        child: Center(
                          child: _buildInteractionBubble(
                            interaction,
                            isTop: isTop,
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Auto Play Badge
              if (_autoPlayingIndices.contains(pIndex))
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Text(
                      "AUTO",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              // ── Mute Icon (opponents only) ── REMOVED FROM HERE
              // Moved outside the SizedBox to fix hit testing
            ],
          ),
        ),
      ),
    );

    // ── Wrap avatar with mute icon (outside the 50x50 SizedBox for proper hit testing) ──
    if (pIndex != _myPlayerIndex && _gameMode == 'online') {
      avatarStack = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarStack,
          Positioned(
            top: 2,
            left: (vIdx == 3) ? -2 : null,
            right: (vIdx != 3) ? -2 : null,
            child: Consumer<VoiceRoomService>(
              builder: (context, voice, _) {
                String? pUid = _onlinePlayerUids[pIndex];
                int volumeLevel = pUid != null ? voice.getUserVolume(pUid) : 0;
                bool isMuted = (_playerVolumes[pIndex] ?? 1.0) == 0.0;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      double currentVol = _playerVolumes[pIndex] ?? 1.0;
                      bool isMuting = currentVol > 0;
                      _playerVolumes[pIndex] = isMuting ? 0.0 : 1.0;

                      if (pUid != null) {
                        try {
                          int agoraUid = VoiceRoomService.getAgoraUid(pUid);
                          voice.muteRemoteAudioStreamLocally(agoraUid, isMuting);
                        } catch (e) {
                          print("Error muting player: $e");
                        }
                      }
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Real-time sound level meter
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
                          border: Border.all(color: Colors.black87, width: 1.2),
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
                );
              },
            ),
          ),
        ],
      );
    }

    if (diceWidget == null) return avatarStack;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      textDirection: TextDirection.ltr,
      children: diceOnRight
          ? [avatarStack, const SizedBox(width: 8), diceWidget]
          : [diceWidget, const SizedBox(width: 8), avatarStack],
    );
  }

  String _getDisplayName(int pIndex, String defaultName) {
    if (_gameMode == 'online') {
      return _onlinePlayerNames[pIndex] ?? "بانتظار...";
    }
    return defaultName;
  }

  Widget _buildChatInputPanel() {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        _uiController.isChatInputOpen = false;
      },
      behavior:
          HitTestBehavior.translucent, // Allow taps through transparent areas
      child: Container(
        color: Colors
            .transparent, // Fix: Changed from black26 to allow interaction
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {}, // Prevent closing when clicking message area
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF130B2E).withValues(alpha: 0.3),
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
                                    _uiController.isChatInputOpen = false,
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
                                  .where(
                                    (e) =>
                                        e.type == LudoGameLogType.chat ||
                                        e.type == LudoGameLogType.sticker,
                                  )
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
      decoration: BoxDecoration(
        color: const Color(
          0xFF1E1440,
        ).withValues(alpha: 0.4), // Higher transparency
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Notice bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                "يرجى الدردشة بطريقة لائقة (0/200)",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Send Button
              _buildSendButton(),
              const SizedBox(width: 12),
              // Input Field
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: _chatInputController,
                    textAlign: TextAlign.right,
                    onChanged: (v) => setState(() {}),
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك هنا...',
                      hintStyle: GoogleFonts.tajawal(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
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

  Widget _buildSendButton() {
    bool hasText = _chatInputController.text.isNotEmpty;
    return GestureDetector(
      onTap: hasText ? _onSendMessage : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 48,
        decoration: BoxDecoration(
          gradient: hasText
              ? const LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF1DE9B6)],
                )
              : const LinearGradient(colors: [Colors.grey, Colors.blueGrey]),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(
          child: Text(
            'إرسال',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Tajawal',
            ),
          ),
        ),
      ),
    );
  }

  void _onSendMessage() {
    // Sending messages does NOT stop persistent auto-play anymore
    if (_chatInputController.text.isEmpty) return;
    _handleNewInteraction(_myPlayerIndex, {
      'type': 'text',
      'content': _chatInputController.text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    if (_roomId != null) {
      LudoService().sendInteraction(
        _roomId!,
        'text',
        _chatInputController.text,
      );
    }
    _chatInputController.clear();
    _uiController.isChatInputOpen = false; // Fix: Close window after sending
    _scrollToBottom();
  }

  Widget _buildBottomCapsuleButton({
    required VoidCallback onTap,
    required List<Color> colors,
    required Widget child,
    double width = 54,
    double height = 30,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.2),
              blurRadius: 1,
              offset: const Offset(0, -1),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: child),
            if (badgeCount > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 9 ? "+9" : "$badgeCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _getProfileImage(int pIndex, Color color) {
    String? photoPath;
    if (_gameMode == 'online') {
      photoPath = _onlinePlayerImages[pIndex];
    } else if (pIndex == _myPlayerIndex) {
      photoPath = _userProfileImage;
    }

    if (photoPath != null && photoPath.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: _getAvatarProvider(photoPath),
      );
    }

    // If no explicit photo, check if it's a bot with a specific image
    if (_botProfiles.containsKey(pIndex)) {
      final profile = _botProfiles[pIndex]!;
      if (profile.botImage != null) {
        return Image.asset(profile.botImage!, fit: BoxFit.cover);
      }
      // Unique bot avatar
      final botName = profile.name;
      final avatarUrl =
          'https://api.dicebear.com/9.x/avataaars/png?seed=$botName&backgroundColor=b6e3f4,c0aede,d1d4f9,ffdfbf,ffd5dc';
      return CircleAvatar(
        radius: 26,
        backgroundColor: color,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: color,
      child: const Icon(Icons.person, color: Colors.white, size: 30),
    );
  }

  Widget _buildDiceForPlayer(int pIndex) {
    if (_currentPlayer != pIndex && pIndex != _myPlayerIndex)
      return const SizedBox.shrink();

    bool canUserRoll =
        (pIndex == _myPlayerIndex &&
        _canRoll &&
        !_isRolling &&
        _currentPlayer == pIndex &&
        !_isWinDialogShowing);

    // Get player color for the timer
    Color color = _getPlayerColor(pIndex);

    bool isMe = pIndex == _myPlayerIndex;
    bool displayRolling = _isRolling && !_isWinDialogShowing;

    Widget centerDice;
    if (displayRolling && _currentPlayer == pIndex) {
      centerDice = SizedBox(
        width: 46,
        height: 46,
        child: RepaintBoundary(
          child: Center(
            child: AnimatedDice(
              value: Random().nextInt(6) + 1,
              isRolling: true,
              size: 42,
              color: Colors.white,
              diceTheme: _playerDiceThemes[pIndex] ?? 'classic',
              diceUrls: _playerDiceUrlsMap[pIndex],
            ),
          ),
        ),
      );
    } else {
      centerDice = GestureDetector(
        onTap:
            (canUserRoll ||
                (isMe && _currentPlayer == pIndex && _reRollGraceRemaining > 0))
            ? () {
                _userInteraction();
                if (_canRoll) {
                  _rollDice();
                } else if (_reRollGraceRemaining > 0) {
                  // User doesn't want to re-roll, skip the wait
                  setState(() => _reRollGraceRemaining = 0);
                  _reRollGraceTimer?.cancel();

                  bool isBust =
                      (_diceRolled.length >= 3 &&
                      _diceRolled.sublist(_diceRolled.length - 3).every((d) => d == 6));
                  if ((!_canRoll && !_canMoveAny()) || isBust) {
                    _nextTurn();
                  }
                }
              }
            : null,
        child: Container(
          width: 46,
          height: 46,
          decoration:
              (_currentPlayer == pIndex &&
                  (_diceRolled.isNotEmpty || displayRolling))
              ? null // No frame when dice is shown
              : BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: canUserRoll || isMe
                        ? [
                            Colors.white.withValues(alpha: 0.2),
                            Colors.white.withValues(alpha: 0.1),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.1),
                            Colors.white.withValues(alpha: 0.05),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canUserRoll ? Colors.cyanAccent : Colors.white24,
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (canUserRoll)
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    const BoxShadow(
                      color: Colors.black45,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
          child:
              (_currentPlayer == pIndex &&
                  (_diceRolled.isNotEmpty || displayRolling))
              ? RepaintBoundary(
                  child: Center(
                    child: AnimatedDice(
                      value: displayRolling
                          ? (Random().nextInt(6) + 1)
                          : (_diceRolled.isNotEmpty ? _diceRolled.last : 1),
                      isRolling: displayRolling,
                      size: 42,
                      color: Colors.white,
                      diceTheme: _playerDiceThemes[pIndex] ?? 'classic',
                      diceUrls: _playerDiceUrlsMap[pIndex],
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "العب",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: canUserRoll || isMe
                            ? Colors.black87
                            : Colors.white60,
                        fontSize: 12,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    Icon(
                      Icons.casino,
                      color: canUserRoll
                          ? Colors.redAccent
                          : Colors.white38,
                      size: 16,
                    ),
                  ],
                ),
        ),
      );
    }

    Widget diceWidget = SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Timer indicator around the dice
          if (_currentPlayer == pIndex && !_isWinDialogShowing)
            CustomPaint(
              size: const Size(52, 52),
              painter: SquareTimerPainter(
                progress: (_remainingTime / kTurnDurationSeconds).clamp(
                  0.0,
                  1.0,
                ),
                color: color,
                strokeWidth: 3.5,
                borderRadius: 12.0,
              ),
            ),

          // 2. The Dice itself
          centerDice,

          // 3. Green Arrow Indicator (pointing down at the dice when it's your turn)
          if (canUserRoll)
            const Positioned(
              top: -50,
              child: _ContinuousBouncingIndicator(
                assetPath: 'assets/images/shm.png',
                size: 32,
              ),
            ),
        ],
      ),
    );

    if (isMe) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          diceWidget,
          const SizedBox(width: 24),
          // Buy Extra Turn circular button - disabled when Max reached
          GestureDetector(
            onTap:
                (_currentPlayer == _myPlayerIndex &&
                    _blueButtonClicksThisTurn < 3 &&
                    _blueButtonClicks < 8 &&
                    _diceRolled.isNotEmpty &&
                    _reRollGraceRemaining > 0)
                ? () {
                    _userInteraction(); // Buying extra turn stops auto-play
                    _reRollDice();
                  }
                : null,
            child: Opacity(
              opacity:
                  (_currentPlayer == _myPlayerIndex &&
                      _blueButtonClicksThisTurn < 3 &&
                      _blueButtonClicks < 8 &&
                      _diceRolled.isNotEmpty &&
                      _reRollGraceRemaining > 0)
                  ? 1.0
                  : 0.5,
              child: SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Timer filling background
                    if (_currentPlayer == _myPlayerIndex &&
                        _reRollGraceRemaining > 0 &&
                        _blueButtonClicksThisTurn < 3 &&
                        _blueButtonClicks < 8)
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          value:
                              _reRollGraceRemaining / 3.0, // Match new 3s timer
                          strokeWidth: 3.5,
                          backgroundColor: Colors.black26,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF2196F3),
                          ),
                        ),
                      ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8),
                          width: 1.2,
                        ),
                        boxShadow: [
                          if (_reRollGraceRemaining > 0 &&
                              _blueButtonClicksThisTurn < 3 &&
                              _blueButtonClicks < 8)
                            BoxShadow(
                              color: Colors.blueAccent.withValues(alpha: 0.3),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 12,
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  (_blueButtonClicks < 8 &&
                                          _blueButtonClicksThisTurn < 3)
                                      ? '${kBlueButtonCosts[_blueButtonClicks < kBlueButtonCosts.length ? _blueButtonClicks : kBlueButtonCosts.length - 1]}'
                                      : 'Max',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                                if (_blueButtonClicks < 8 &&
                                    _blueButtonClicksThisTurn < 3) ...[
                                  const SizedBox(width: 1),
                                  const Icon(
                                    Icons.diamond_rounded,
                                    color: Colors.cyanAccent,
                                    size: 9,
                                  ),
                                ],
                              ],
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
        ],
      );
    }

    return diceWidget;
  }

  // ── Premium Sticker / Message Bubble ──────────────────────────────────────
  // Stickers: shown as a FULL-AVATAR glowing overlay (64×64 on top of avatar)
  // Text/Emoji: glassmorphism speech bubble above avatar with pointer tail
  Widget _buildStickerOverlay(String content) {
    return RepaintBoundary(
      child: Center(
        child: AnimatedEmoji(
          StickerSelectionBottomSheet.getEmojiData(content) ??
              AnimatedEmojis.joy,
          size: 48,
          repeat: true,
        ),
      ),
    );
  }

  Widget _buildInteractionBubble(
    Map<String, dynamic> data, {
    bool isTop = false,
  }) {
    final type = data['type'] as String? ?? 'text';
    final content = data['content'] as String? ?? '';

    if (type == 'sticker') {
      return _buildStickerOverlay(content);
    }

    return _buildTextBubble(
      content,
      isEmoji: type == 'emoji',
      tailAtTop: isTop,
    );
  }

  Widget _buildTextBubble(
    String content, {
    bool isEmoji = false,
    bool tailAtTop = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isEmoji
                ? [const Color(0xFF2D1B69), const Color(0xFF11047A)]
                : [
                    const Color(0xFFFFF9C4),
                    const Color(0xFFFFF176).withValues(alpha: 0.9),
                  ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: tailAtTop ? -11 : null,
              bottom: tailAtTop ? null : -11,
              left: 20,
              child: Transform.rotate(
                angle: tailAtTop ? pi : 0,
                child: CustomPaint(
                  size: const Size(18, 12),
                  painter: BubbleTailPainter(
                    isEmoji ? const Color(0xFF11047A) : const Color(0xFFFFF176),
                  ),
                ),
              ),
            ),
            Text(
              content,
              style: TextStyle(
                color: isEmoji ? Colors.white : const Color(0xFF5D4037),
                fontWeight: FontWeight.bold,
                fontSize: isEmoji ? 28 : 14,
                fontFamily: 'Tajawal',
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Scrollable Game-Log Panel ──────────────────────────────────────────────
  Widget _buildGameLogPanel() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      offset: _showGameLog ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 280),
        opacity: _showGameLog ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_showGameLog,
          child: Container(
            height: 240,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D0529).withValues(alpha: 0.97),
                  const Color(0xFF1A0545).withValues(alpha: 0.97),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history_edu,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'سجل اللعبة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _uiController.showGameLog = false,
                        child: const Icon(
                          Icons.close,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                // Messages list
                Expanded(
                  child: _gameLog.isEmpty
                      ? const Center(
                          child: Text(
                            'لم تبدأ اللعبة بعد..',
                            style: TextStyle(
                              color: Colors.white38,
                              fontFamily: 'Tajawal',
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _logScrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          itemCount: _gameLog.length,
                          itemBuilder: (ctx, i) {
                            final entry = _gameLog[i];
                            return _buildLogRow(entry);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogRow(LudoGameLogEntry entry, {bool isLarge = false}) {
    bool isMe = entry.playerName == _userName;

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
                      color: entry.playerColor,
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  entry.playerName,
                  style: TextStyle(
                    color: entry.playerColor,
                    fontWeight: FontWeight.bold,
                    fontSize: isLarge ? 15 : 12,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.timeLabel,
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
              color: isMe
                  ? const Color(0xFF6B4EE0).withValues(
                      alpha: 0.85,
                    ) // Vibrant Purple
                  : const Color(
                      0xFF2C1B4D,
                    ).withValues(alpha: 0.85), // Darker contrast
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
              border: Border.all(
                color: isMe
                    ? const Color(0xFF9575CD).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.icon.isNotEmpty &&
                    entry.type != LudoGameLogType.chat) ...[
                  Text(
                    entry.icon,
                    style: TextStyle(fontSize: isLarge ? 20 : 16),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    entry.message,
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

  String _formatMatchmakingNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")}K';
    } else {
      return number.toString();
    }
  }
}

/// Custom Painter for the Radar Scanning effect
class _RadarScanner extends StatefulWidget {
  const _RadarScanner();

  @override
  State<_RadarScanner> createState() => _RadarScannerState();
}

class _RadarScannerState extends State<_RadarScanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: RadarScannerPainter(animationValue: _controller.value),
        );
      },
    );
  }
}

class RadarScannerPainter extends CustomPainter {
  final double animationValue;
  RadarScannerPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.8;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw grid rings
    for (int i = 1; i <= 4; i++) {
      paint.color = const Color(0xFF009688).withValues(alpha: 0.05 * i);
      canvas.drawCircle(center, (radius / 4) * i, paint);
    }

    // Draw Crosshair lines
    paint.color = const Color(0xFF009688).withValues(alpha: 0.1);
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      paint,
    );

    // Draw Sweeping Scanner
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: pi / 2,
        colors: [
          const Color(0xFF009688).withValues(alpha: 0.5),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(animationValue * 2 * pi);
    canvas.drawCircle(Offset.zero, radius, sweepPaint);

    // Bright edge line
    final linePaint = Paint()
      ..color = const Color(0xFF4DB6AC)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(radius, 0), linePaint);
    canvas.restore();

    // Draw Random Data Points
    final rnd = Random(42);
    for (int i = 0; i < 8; i++) {
      final angle = rnd.nextDouble() * 2 * pi;
      final dist = rnd.nextDouble() * radius;
      final opacity = (1.0 - ((animationValue + rnd.nextDouble()) % 1.0)).clamp(
        0.0,
        1.0,
      );

      canvas.drawCircle(
        Offset(center.dx + cos(angle) * dist, center.dy + sin(angle) * dist),
        3.0,
        Paint()
          ..color = const Color(0xFF009688).withValues(alpha: opacity * 0.5)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(RadarScannerPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

/// Custom Painter for the Energy Ring around players
class EnergyRingPainter extends CustomPainter {
  final Color color;
  EnergyRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color, color.withValues(alpha: 0.1), color],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawArc(rect, 0, pi / 3, false, paint);
    canvas.drawArc(rect, pi, pi / 3, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ContinuousBouncingIndicator extends StatefulWidget {
  final String assetPath;
  final double size;

  const _ContinuousBouncingIndicator({
    required this.assetPath,
    required this.size,
  });

  @override
  State<_ContinuousBouncingIndicator> createState() =>
      _ContinuousBouncingIndicatorState();
}

class _ContinuousBouncingIndicatorState
    extends State<_ContinuousBouncingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Faster speed
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: -8.0,
      end: 8.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: Image.asset(
        widget.assetPath,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _TwinklingStar extends StatefulWidget {
  final Random random;
  const _TwinklingStar({required this.random});

  @override
  State<_TwinklingStar> createState() => _TwinklingStarState();
}

class _TwinklingStarState extends State<_TwinklingStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double opacity;

  @override
  void initState() {
    super.initState();
    opacity = widget.random.nextDouble();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000 + widget.random.nextInt(2000)),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: (opacity * _controller.value).clamp(0.1, 1.0),
          child: Container(
            width: 2,
            height: 2,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
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
      width: 140,
      height: 340,
      margin: const EdgeInsets.only(top: 20),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Flag Image
          Image.asset(imagePath, width: 140, height: 340, fit: BoxFit.fill),
          // Avatars positioned over the image
          SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  height: 60,
                ), // Push avatars down so they sit nicely on the image
                ...playerAvatars.map(
                  (avatar) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: avatar,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: _controller.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withValues(
                  alpha: 0.5 * _controller.value,
                ),
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
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        RotationTransition(
          turns: _controller,
          child: Container(
            width: widget.size + 20,
            height: widget.size + 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Colors.cyanAccent.withValues(alpha: 0.0),
                  Colors.cyanAccent.withValues(alpha: 0.7),
                  Colors.cyanAccent.withValues(alpha: 0.0),
                ],
                stops: const [0.2, 0.5, 0.8],
              ),
            ),
          ),
        ),
        // Subtle outer glow
        Container(
          width: widget.size + 12,
          height: widget.size + 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// A continuously rotating ring around a matchmaking avatar.
/// Cyan while searching, switches to [color] once the player is found.
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      child: RotationTransition(
        turns: _ctrl,
        child: Container(
          width: 65,
          height: 65,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: CustomPaint(painter: EnergyRingPainter(color: ringColor)),
        ),
      ),
    );
  }
}

