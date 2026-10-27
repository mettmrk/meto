// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api
part of 'ludo_screen.dart';

/// Preferences, audio, themes, and data loading methods.
extension LudoScreenPreferences on _LudoScreenState {
  Future<void> _savePlayerTokenShape(int playerIndex, String shape) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ludo_token_shape_player_$playerIndex', shape);
      setState(() {
        _playerTokenShapes[playerIndex] = shape;
        if (playerIndex == _myPlayerIndex) {
          _tokenShape = shape;
        }
      });

      // تحديث اللعبة بالشكل الجديد
      _ludoGame.updateThemes(
        bTheme: _boardTheme,
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

      debugPrint('[TokenShape] Saved shape for player $playerIndex: $shape');
    } catch (e) {
      debugPrint('[TokenShape] Error saving shape for player $playerIndex: $e');
    }
  }

  // ── دالة جديدة لتحميل شكل الحجرات لكل لاعب ─────────────────────────────────
  Future<void> _loadPlayerTokenShape(int playerIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedShape = prefs.getString(
        'ludo_token_shape_player_$playerIndex',
      );

      if (savedShape != null && savedShape.isNotEmpty) {
        setState(() {
          _playerTokenShapes[playerIndex] = savedShape;
          if (playerIndex == _myPlayerIndex) {
            _tokenShape = savedShape;
          }
        });
        debugPrint(
          '[TokenShape] Loaded shape for player $playerIndex: $savedShape',
        );
      } else {
        // إذا لم يكن هناك شكل محفوظ، استخدم الشكل الافتراضي
        setState(() {
          _playerTokenShapes[playerIndex] = 'pawn';
          if (playerIndex == _myPlayerIndex) {
            _tokenShape = 'pawn';
          }
        });
      }
    } catch (e) {
      debugPrint(
        '[TokenShape] Error loading shape for player $playerIndex: $e',
      );
      // في حالة الخطأ، استخدم الشكل الافتراضي
      setState(() {
        _playerTokenShapes[playerIndex] = 'pawn';
        if (playerIndex == _myPlayerIndex) {
          _tokenShape = 'pawn';
        }
      });
    }
  }

  // ── دالة مساعدة للحصول على شكل اللاعب ─────────────────────────────────────
  String _getPlayerTokenShape(int playerIndex) {
    return _playerTokenShapes[playerIndex] ?? 'pawn';
  }

  Future<void> _initMusic() async {
    if (_isMusicInitializing) return;
    _isMusicInitializing = true;
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers |
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.moviePlayback,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.game,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );

      await _switchMusicTrack();
    } catch (e) {
      debugPrint('Music Init Error: $e');
    } finally {
      _isMusicInitializing = false;
    }
  }

  Future<void> _switchMusicTrack() async {
    if (_isSwitchingMusic || !mounted) return;
    _isSwitchingMusic = true;

    try {
      // 1. تحديد المسار المطلوب بناءً على الحالة الحالية بدقة
      final String mode = (_currentMatchMode).toLowerCase();
      final bool isLudoX = mode == 'ludox';
      final bool isInInteractiveState =
          _uiState == LudoUiState.matchmaking ||
          _uiState == LudoUiState.playing;

      final String targetAsset = (isLudoX && isInInteractiveState)
          ? 'assets/sounds/lodux.mp3'
          : 'assets/sounds/lodumusic.mp3';

      // 2. إذا كان نفس الملف يعمل حالياً، لا تفعل شيئاً
      if (targetAsset == _currentMusicAsset && _musicPlayer.playing) {
        return;
      }

      debugPrint('[MusicLog] Switching to: $targetAsset');

      // 3. تحديث المسار الحالي فوراً لمنع الاستدعاءات المتداخلة
      _currentMusicAsset = targetAsset;

      // 4. إيقاف الموسيقى الحالية بسلاسة
      if (_musicPlayer.playing) {
        await _musicPlayer.stop();
      }

      // 5. تحميل وتشغيل الملف الجديد
      await _musicPlayer.setAsset(targetAsset);
      await _musicPlayer.setLoopMode(LoopMode.all);
      await _musicPlayer.setVolume(_isMuted ? 0 : _musicVolume);

      if (!_isMuted && mounted) {
        // نستخدم الـ catch هنا للتأكد من أن أي خطأ في التشغيل لا يعلق الـ Flag
        _musicPlayer.play().catchError((e) => debugPrint('Play error: $e'));
      }
    } catch (e) {
      debugPrint('[MusicLog] Error: $e');
    } finally {
      _isSwitchingMusic = false;
    }
  }

  Future<void> _loadAudioSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _musicVolume = prefs.getDouble('ludo_music_volume') ?? 0.4;
        _diceVolume = prefs.getDouble('ludo_dice_volume') ?? 0.7;
        _sfxVolume = prefs.getDouble('ludo_sfx_volume') ?? 0.4;
        _isMuted = prefs.getBool('ludo_muted') ?? false;
      });

      // Apply to players
      await _musicPlayer.setVolume(_isMuted ? 0 : _musicVolume);
      _ludoGame.updateVolumes(dice: _diceVolume, sfx: _sfxVolume);
      _ludoGame.isMuted = _isMuted; // Sync game's mute state
    } catch (e) {
      debugPrint('Error loading audio settings: $e');
    }
  }

  Future<void> _saveAudioSetting(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (e) {
      debugPrint('Error saving audio setting: $e');
    }
  }

  void _toggleMute({bool? forceValue}) async {
    final newValue = forceValue ?? !_isMuted;
    setState(() {
      _isMuted = newValue;
    });

    if (_isMuted) {
      _musicPlayer.pause();
    } else {
      _musicPlayer.setVolume(_musicVolume); // Restore music volume
      _musicPlayer.play().catchError(
        (e) => debugPrint('Error playing music: $e'),
      );
    }

    _ludoGame.isMuted = _isMuted; // Update game's mute state

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ludo_muted', _isMuted);
    } catch (e) {
      debugPrint('Error saving mute state: $e');
    }
  }

  /// Loads ALL user preferences in one shot, then re-applies them to the game.
  /// Uses a static cache so the shape is instantly available on next game start.
  Future<void> _loadAllPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Board Theme
      final savedBoard = prefs.getString('ludo_board_theme');

      // 2. Token Theme / Shape - تحميل الشكل المحفوظ للاعب الحالي
      final savedTokenTheme = prefs.getString('ludo_token_theme');
      final savedTokenShape = prefs.getString('ludo_token_shape') ?? 'pawn';

      // 3. Dice Theme
      final savedDice = prefs.getString('ludo_dice_theme');

      // تحميل الأشكال المحفوظة لكل لاعب
      await _loadPlayerTokenShape(0);
      await _loadPlayerTokenShape(1);
      await _loadPlayerTokenShape(2);
      await _loadPlayerTokenShape(3);

      const basicShapes = ['pawn', 'star', 'shield'];

      // Update the static cache FIRST so future widget instances use it
      if (savedTokenTheme != null && basicShapes.contains(savedTokenTheme)) {
        _LudoScreenState._savedTokenShape = savedTokenTheme;
      } else if (basicShapes.contains(savedTokenShape)) {
        _LudoScreenState._savedTokenShape = savedTokenShape;
      }
      _LudoScreenState._prefsLoaded = true;

      if (!mounted) return;
      setState(() {
        if (savedBoard != null) _boardTheme = savedBoard;

        if (savedTokenTheme != null) {
          _ludoTokenTheme = savedTokenTheme;
          if (basicShapes.contains(savedTokenTheme)) {
            _ludoTokenUrls = null; // no remote URLs for basic shapes
          }
        }

        if (savedDice != null) _ludoDiceTheme = savedDice;

        // Populate current player themes maps
        _playerTokenThemes[_myPlayerIndex] = _ludoTokenTheme ?? 'pawn';
        _playerDiceThemes[_myPlayerIndex] = _ludoDiceTheme ?? 'none';
        if (_ludoTokenUrls != null) {
          _playerTokenUrlsMap[_myPlayerIndex] = _ludoTokenUrls!;
        }
        if (_ludoDiceUrls != null && _ludoDiceUrls!.isNotEmpty) {
          _playerDiceUrlsMap[_myPlayerIndex] = _ludoDiceUrls!;
        }
      });

      // Fetch network icons for advanced token themes if needed
      if (_ludoTokenTheme != null && !basicShapes.contains(_ludoTokenTheme)) {
        await _fetchTokenUrls(_ludoTokenTheme!);
      }

      // Fetch dice URLs
      if (_ludoDiceTheme != null && _ludoDiceTheme != 'none') {
        await _fetchDiceUrls(_ludoDiceTheme!);
        if (_ludoDiceUrls != null && _ludoDiceUrls!.isNotEmpty) {
          setState(() {
            _playerDiceUrlsMap[_myPlayerIndex] = _ludoDiceUrls!;
          });
        }
      }

      // 4. Force apply themes to the engine
      _ludoGame.updateThemes(
        bTheme: _boardTheme,
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

      // For premium token theme: fetch remote URLs
      if (_ludoTokenTheme != null && !basicShapes.contains(_ludoTokenTheme!)) {
        await _fetchTokenUrls(_ludoTokenTheme!);
      }

      // For premium dice theme: fetch remote URLs
      if (_ludoDiceTheme != null) {
        await _fetchDiceUrls(_ludoDiceTheme!);
      }
    } catch (e) {
      debugPrint('Error loading preferences: \$e');
    }
  }

  void _listenToUserData() {
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _userSub?.cancel();
      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots()
          .listen((userDoc) {
            if (userDoc.exists && mounted) {
              final userData = model.User.fromMap(
                userDoc.data()!,
                currentUser.uid,
              );
              setState(() {
                _userName = (userData.nickname != null && userData.nickname!.trim().isNotEmpty)
                    ? userData.nickname!
                    : userData.username;
                _userProfileImage = userData.profileImage;
                _userCoins = userData.coins;
                _userDiamonds = userData.diamonds;
                _userLevel = userData.level;
                _userLeagueRank = userData.leagueRank;
                _userBestLeagueRank = userData.bestLeagueRank;

                // Theme Handling
                if (_ludoTokenTheme != userData.ludoTokenTheme) {
                  _ludoTokenTheme = userData.ludoTokenTheme;
                  _playerTokenThemes[_myPlayerIndex] = _ludoTokenTheme ?? 'pawn';
                  if (_ludoTokenTheme != null) _fetchTokenUrls(_ludoTokenTheme!);
                }

                if (_ludoDiceTheme != userData.ludoDiceTheme) {
                  _ludoDiceTheme = userData.ludoDiceTheme;
                  _playerDiceThemes[_myPlayerIndex] = _ludoDiceTheme ?? 'none';
                  if (_ludoDiceTheme != null) _fetchDiceUrls(_ludoDiceTheme!);
                }

                // If the theme name matches one of our local shapes, sync it
                if (_ludoTokenTheme != null) {
                  final themeLower = _ludoTokenTheme!.toLowerCase();
                  if (['pawn', 'shield', 'star'].contains(themeLower)) {
                    // حفظ الشكل المحلي للاعب الحالي
                    _savePlayerTokenShape(_myPlayerIndex, themeLower);
                  }
                }

                if (userData.ludoBoardTheme != null &&
                    userData.ludoBoardTheme != 'none' &&
                    _boardTheme != userData.ludoBoardTheme) {
                  _boardTheme = userData.ludoBoardTheme!;
                  _fetchBoardImageUrl(_boardTheme);
                }

                if (_hallTheme != userData.ludoHallTheme) {
                  _hallTheme = userData.ludoHallTheme;
                  if (_hallTheme != null && _hallTheme != 'none') {
                    _fetchHallUrl(_hallTheme!);
                  } else {
                    _hallImageUrl = null;
                  }
                }

                _saveThemesToLocal(
                  userData,
                ); // Keep Local storage in sync with Cloud

                // Fetch Token URLs if theme exists and isn't a simple shape
                if (_ludoTokenTheme != null &&
                    _ludoTokenTheme != 'none' &&
                    ![
                      'pawn',
                      'shield',
                      'star',
                    ].contains(_ludoTokenTheme!.toLowerCase())) {
                  _fetchTokenUrls(_ludoTokenTheme!);
                } else {
                  _ludoTokenUrls = null;
                }

                // Fetch Dice URLs if theme exists
                if (_ludoDiceTheme != null && _ludoDiceTheme != 'none') {
                  _fetchDiceUrls(_ludoDiceTheme!);
                } else {
                  _ludoDiceUrls = null;
                  _playerDiceUrlsMap.remove(_myPlayerIndex);
                }

                if (_uiState == LudoUiState.playing ||
                    _uiState == LudoUiState.menu) {
                  _reinitGameWithTheme();
                }
              });
            }
          });
    }
  }

  void _saveThemesToLocal(model.User user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user.ludoBoardTheme != null) {
      await prefs.setString('ludo_board_theme', user.ludoBoardTheme!);
    }
    if (user.ludoTokenTheme != null) {
      await prefs.setString('ludo_token_theme', user.ludoTokenTheme!);
    }
    if (user.ludoDiceTheme != null) {
      await prefs.setString('ludo_dice_theme', user.ludoDiceTheme!);
    }
  }

  Future<void> _fetchDiceUrls(String itemId) async {
    try {
      // Check shop_items first
      var snap = await FirebaseFirestore.instance
          .collection('shop_items')
          .doc(itemId)
          .get();

      if (!snap.exists) {
        // Check ludo_assets
        snap = await FirebaseFirestore.instance
            .collection('ludo_assets')
            .doc(itemId)
            .get();
      }

      if (snap.exists) {
        final data = snap.data();
        final metadata = data?['metadata'] as Map?;
        if (metadata != null && metadata['urls'] != null) {
          setState(() {
            _ludoDiceUrls = Map<String, String>.from(metadata['urls']);
            _playerDiceUrlsMap[_myPlayerIndex] = _ludoDiceUrls!;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching dice urls: $e');
    }
  }

  Future<void> _fetchTokenUrls(String itemId) async {
    try {
      // Check shop_items first
      var snap = await FirebaseFirestore.instance
          .collection('shop_items')
          .doc(itemId)
          .get();

      if (!snap.exists) {
        // Check ludo_assets
        snap = await FirebaseFirestore.instance
            .collection('ludo_assets')
            .doc(itemId)
            .get();
      }

      if (snap.exists) {
        final data = snap.data();
        final metadata = data?['metadata'] as Map?;
        if (metadata != null && metadata['urls'] != null) {
          setState(() {
            _ludoTokenUrls = Map<String, String>.from(metadata['urls']);
            _playerTokenUrlsMap[_myPlayerIndex] = _ludoTokenUrls!;
          });
          if (_uiState == LudoUiState.playing || _uiState == LudoUiState.menu) {
            _reinitGameWithTheme();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching token urls: $e');
    }
  }

  Future<void> _fetchHallUrl(String itemId) async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('ludo_assets')
          .doc(itemId)
          .get();
      
      if (!snap.exists) {
        snap = await FirebaseFirestore.instance
            .collection('shop_items')
            .doc(itemId)
            .get();
      }

      if (snap.exists) {
        setState(() {
          _hallImageUrl = snap.data()?['image'] ?? snap.data()?['imageUrl'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching hall url: $e');
    }
  }

  Future<void> _fetchBoardImageUrl(String itemId) async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('ludo_assets')
          .doc(itemId)
          .get();
      
      if (!snap.exists) {
        snap = await FirebaseFirestore.instance
            .collection('shop_items')
            .doc(itemId)
            .get();
      }

      if (snap.exists) {
        final url = snap.data()?['image'] ?? snap.data()?['imageUrl'];
        if (url != null) {
          setState(() {
            _boardImageUrl = url;
          });
          if (_uiState == LudoUiState.playing || _uiState == LudoUiState.menu) {
            _reinitGameWithTheme();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching board image url: $e');
    }
  }

  // ── دوال جديدة لجلب روابط الثيمات لكل لاعب ───────────────────────────────────

  Future<void> _fetchPlayerTokenUrls(int playerIndex, String itemId) async {
    if (itemId == 'none' ||
        ['pawn', 'shield', 'star'].contains(itemId.toLowerCase())) {
      setState(() {
        _playerTokenUrlsMap.remove(playerIndex);
      });
      return;
    }

    try {
      var snap = await FirebaseFirestore.instance
          .collection('shop_items')
          .doc(itemId)
          .get();

      if (!snap.exists) {
        snap = await FirebaseFirestore.instance
            .collection('ludo_assets')
            .doc(itemId)
            .get();
      }

      if (snap.exists) {
        final data = snap.data();
        final metadata = data?['metadata'] as Map?;
        if (metadata != null && metadata['urls'] != null) {
          setState(() {
            _playerTokenUrlsMap[playerIndex] = Map<String, String>.from(
              metadata['urls'],
            );
          });
          // تحديث اللعبة فوراً
          _ludoGame.updateThemes(pUrlsMap: _playerTokenUrlsMap);
          _updateGame();
        }
      }
    } catch (e) {
      debugPrint('Error fetching player token urls: $e');
    }
  }

  Future<void> _fetchPlayerDiceUrls(int playerIndex, String itemId) async {
    if (itemId == 'none') {
      setState(() {
        _playerDiceUrlsMap.remove(playerIndex);
      });
      return;
    }

    try {
      var snap = await FirebaseFirestore.instance
          .collection('shop_items')
          .doc(itemId)
          .get();

      if (!snap.exists) {
        snap = await FirebaseFirestore.instance
            .collection('ludo_assets')
            .doc(itemId)
            .get();
      }

      if (snap.exists) {
        final data = snap.data();
        final metadata = data?['metadata'] as Map?;
        if (metadata != null && metadata['urls'] != null) {
          setState(() {
            _playerDiceUrlsMap[playerIndex] = Map<String, String>.from(
              metadata['urls'],
            );
          });
          // تحديث الواجهة (النرد يتم رسمه في الطبقة العلوية وليس في الفليم)
          _updateGame();
        }
      }
    } catch (e) {
      debugPrint('Error fetching player dice urls: $e');
    }
  }
}
