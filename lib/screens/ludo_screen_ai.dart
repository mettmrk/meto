// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api
part of 'ludo_screen.dart';

/// AI/bot logic and social reactions.
extension LudoScreenAI on _LudoScreenState {
  void _aiLogic(int playerIdx) async {
    // No more redundant delayed() here, as _scheduleAutoPlayForCurrentTurn handles it.
    _aiMakeNextMoveHumanLike(playerIdx);
  }

  void _aiMakeNextMoveHumanLike(int playerIdx) async {
    if (!mounted) return;
    if (_diceRolled.isEmpty) {
      _nextTurn();
      return;
    }

    final moves = _enumerateMoves(playerIdx);
    if (moves.isEmpty) {
      _nextTurn();
      return;
    }

    // Get bot personality and difficulty for scoring weights
    final profile = _botProfiles[playerIdx];
    final personality = profile?.personality ?? LudoBotPersonality.balanced;
    final difficulty = profile?.difficulty ?? LudoBotDifficulty.medium;

    // Use the explicit difficulty field to scale the AI depth
    // Pro bots have very low mistake chance and high strategic depth
    int mistakeChance;
    double difficultyMultiplier;

    switch (difficulty) {
      case LudoBotDifficulty.pro:
        mistakeChance = personality == LudoBotPersonality.aggressive ? 3 : 5;
        difficultyMultiplier = 1.8;
        break;
      case LudoBotDifficulty.hard:
        mistakeChance = personality == LudoBotPersonality.aggressive ? 6 : 9;
        difficultyMultiplier = 1.4;
        break;
      case LudoBotDifficulty.medium:
        mistakeChance = personality == LudoBotPersonality.random ? 30 : 15;
        difficultyMultiplier = 1.0;
        break;
      case LudoBotDifficulty.easy:
        mistakeChance = 35;
        difficultyMultiplier = 0.6;
        break;
    }
    final bool makeMistake = _rng.nextInt(100) < mistakeChance;

    // Scoring weights per personality (scaled by difficulty)
    double captureW, escapeW, safeW, homeW, deployW, forwardW, posW;
    switch (personality) {
      case LudoBotPersonality.aggressive:
        captureW = 1400 * difficultyMultiplier;
        escapeW = 300 * difficultyMultiplier;
        safeW = 80;
        homeW = 900 * difficultyMultiplier;
        deployW = 350;
        forwardW = 2.0;
        posW = 0.3;
        break;
      case LudoBotPersonality.defensive:
        captureW = 700 * difficultyMultiplier;
        escapeW = 750 * difficultyMultiplier;
        safeW = 260 * difficultyMultiplier;
        homeW = 900 * difficultyMultiplier;
        deployW = 200;
        forwardW = 1.2;
        posW = 0.15;
        break;
      case LudoBotPersonality.random:
        captureW = 800;
        escapeW = 400;
        safeW = 100;
        homeW = 700;
        deployW = 300;
        forwardW = 1.0;
        posW = 0.1;
        break;
      case LudoBotPersonality.balanced:
        captureW = 1100 * difficultyMultiplier;
        escapeW = 520 * difficultyMultiplier;
        safeW = 140 * difficultyMultiplier;
        homeW = 900 * difficultyMultiplier;
        deployW = 260 * difficultyMultiplier;
        forwardW = 1.6;
        posW = 0.25;
    }

    double bestScore = -1e18;
    LudoBotMove? best;

    // --- Pro / Hard mode: count how many opponents are close to finishing
    int closestOpponentDistance = 57; // Lower is more dangerous
    if (difficultyMultiplier >= 1.4) {
      final int myGameIdx = _playerToGameIndex(playerIdx);
      for (int opp = 0; opp < 4; opp++) {
        if (opp == myGameIdx) continue;
        for (final pos in _tokens[opp]) {
          if (pos > 0 && pos < 57) {
            final dist = 57 - pos;
            if (dist < closestOpponentDistance) closestOpponentDistance = dist;
          }
        }
      }
    }

    for (final m in moves) {
      double score = 0;

      // Prefer progress towards home
      score += (m.toPos - m.fromPos) * forwardW;
      score += m.toPos * posW;

      // Bonus for tokens that are already advanced (protect them)
      if (m.fromPos > 45) score += 80 * difficultyMultiplier;

      if (m.isHome) score += homeW;
      if (m.isDeploy) {
        // Deploy priority: the more tokens still in base, the higher the deploy bonus
        score += deployW + (m.tokensInBase * 60.0 * difficultyMultiplier);
      }
      if (m.landsSafe) score += safeW;

      // If landing on a safe cell while threatened: extra escape bonus
      if (m.wasThreatened && m.landsSafe) score += escapeW * 0.5;

      // Kill / Escape priorities (can be ignored when making a mistake)
      if (!makeMistake && m.canCapture) score += captureW;
      if (!makeMistake && m.wasThreatened) score += escapeW;

      // --- Advanced heuristics for Hard/Pro ---
      if (difficultyMultiplier >= 1.4) {
        // 1. Urgency: If an opponent is about to win, prioritise aggression
        if (closestOpponentDistance <= 6 && m.canCapture) {
          score += 600 * difficultyMultiplier;
        }
        // 2. Blockade formation: Reward moving to cells with own tokens nearby
        if (m.toPos > 0 && m.toPos <= 51) {
          final myGameIdx = _playerToGameIndex(playerIdx);
          final occupants = _tokens[myGameIdx]
              .where((p) => p == m.toPos)
              .length;
          if (occupants >= 1) score += 200; // Form a blockade
        }
        // 3. Prefer to keep threatened tokens moving over safe idle ones
        if (m.wasThreatened && m.toPos - m.fromPos > 0) {
          score += 150 * difficultyMultiplier;
        }
        // 4. Near-home prioritisation
        if (m.toPos > 50 && m.toPos < 57) {
          score += (m.toPos - 50) * 80 * difficultyMultiplier;
        }
      }

      // Penalise staying in front of a blockade path (near-home danger)
      if (m.toPos >= 45 && m.toPos < 52 && !m.landsSafe && !m.isHome) {
        score -= 60;
      }

      // Slight randomness so it doesn't look perfectly mechanical
      // Easy / Random personality gets more noise; Pro gets very little
      final double noiseFactor;
      if (personality == LudoBotPersonality.random) {
        noiseFactor = 200.0;
      } else if (difficultyMultiplier >= 1.8) {
        noiseFactor = 8.0; // Pro: nearly deterministic
      } else if (difficultyMultiplier >= 1.4) {
        noiseFactor = 20.0; // Hard
      } else if (difficultyMultiplier >= 1.0) {
        noiseFactor = 50.0; // Medium
      } else {
        noiseFactor = 120.0; // Easy: lots of randomness
      }
      score += _rng.nextDouble() * noiseFactor;

      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
    }

    if (best == null) {
      _nextTurn();
      return;
    }

    // Safety: re-check dice index is still valid (state can change in online)
    if (best.diceIdx < 0 || best.diceIdx >= _diceRolled.length) {
      _nextTurn();
      return;
    }

    int targetGameIdx = playerIdx;
    if (_isTeamMode && _winners.contains(playerIdx)) {
      targetGameIdx = (playerIdx + 2) % 4;
    }
    _tryMove(playerIdx, targetGameIdx, best.tokenIdx, best.diceValue, best.diceIdx);
  }

  List<LudoBotMove> _enumerateMoves(int playerIdx) {
    int targetGameIdx = playerIdx;
    if (_isTeamMode && _winners.contains(playerIdx)) {
      targetGameIdx = (playerIdx + 2) % 4;
    }

    final int gameIdx = targetGameIdx;
    final List<LudoBotMove> moves = [];

    // Pre-compute aggregated token data for scoring hints
    final myTokens = _tokens[gameIdx];
    final int tokensInBase = myTokens.where((p) => p == 0).length;
    final int advancedTokens = myTokens.where((p) => p > 40 && p < 57).length;

    for (int diceIdx = 0; diceIdx < _diceRolled.length; diceIdx++) {
      final int d = _diceRolled[diceIdx];
      for (int tokenIdx = 0; tokenIdx < 4; tokenIdx++) {
        final int from = myTokens[tokenIdx];

        int to = -1;
        bool valid = false;
        if (from == 0) {
          if (d == 6) {
            to = 1;
            valid = true;
          }
        } else {
          if (from + d <= 57) {
            to = from + d;
            valid = true;
          }
        }
        if (!valid) continue;

        if (from > 0 && from <= 51 && _isPathBlocked(gameIdx, from, d)) {
          continue;
        }

        final bool isHome = (to == 57);
        final bool isDeploy = (from == 0 && d == 6);

        bool landsSafe = false;
        bool canCapture = false;
        if (to > 0 && to <= 51) {
          final myGlobal = _toGlobal(to, gameIdx);
          landsSafe = _isSafe(myGlobal);
          canCapture = _wouldCaptureAtGlobal(myGlobal, gameIdx);
        }

        final bool threatened = _isThreatened(gameIdx, from);

        moves.add(
          LudoBotMove(
            tokenIdx: tokenIdx,
            diceIdx: diceIdx,
            diceValue: d,
            fromPos: from,
            toPos: to,
            canCapture: canCapture,
            isHome: isHome,
            isDeploy: isDeploy,
            landsSafe: landsSafe,
            wasThreatened: threatened,
            tokensInBase: tokensInBase,
            advancedTokens: advancedTokens,
          ),
        );
      }
    }

    return moves;
  }

  bool _isTeammate(int myIdx, int otherIdx) {
    if (!_isTeamMode) return false;
    // Current Rule: Red(0)^Blue(3) = 3, Green(1)^Yellow(2) = 3
    return (myIdx ^ 3) == otherIdx;
  }

  bool _wouldCaptureAtGlobal(int myGlobal, int myGameIdx) {
    if (_isSafe(myGlobal)) return false;
    for (int opp = 0; opp < 4; opp++) {
      if (opp == myGameIdx) continue;
      if (_isTeamMode && _isTeammate(myGameIdx, opp)) continue;

      // Shared Safe Zone rule: 2+ tokens (mixed or same player) make it safe
      if (_isPlayerSafeAt(opp, myGlobal, _tokens)) continue;

      for (int ti = 0; ti < 4; ti++) {
        final int oppPos = _tokens[opp][ti];
        if (oppPos > 0 && oppPos <= 51) {
          final int oppGlobal = _toGlobal(oppPos, opp);
          if (oppGlobal == myGlobal) return true;
        }
      }
    }
    return false;
  }

  bool _isThreatened(int myGameIdx, int myLocalPos) {
    if (myLocalPos <= 0 || myLocalPos > 51) return false;
    final int myGlobal = _toGlobal(myLocalPos, myGameIdx);
    if (myGlobal < 0) return false;
    if (_isPlayerSafeAt(myGameIdx, myGlobal, _tokens)) return false;

    for (int opp = 0; opp < 4; opp++) {
      if (opp == myGameIdx) continue;
      if (_isTeamMode && opp == (myGameIdx + 2) % 4) continue;
      for (int ti = 0; ti < 4; ti++) {
        final int oppPos = _tokens[opp][ti];
        if (oppPos <= 0 || oppPos > 51) continue;
        final int oppGlobal = _toGlobal(oppPos, opp);
        final int dist = (myGlobal - oppGlobal + 52) % 52;
        if (dist >= 1 && dist <= 6) {
          return true;
        }
      }
    }
    return false;
  }

  void _botReactToCapture({
    required int moverGameIdx,
    required int victimGameIdx,
  }) {
    if (!_botsEnabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    // AI Mover reaction
    if (_botIndices.contains(moverGameIdx)) {
      final profile = _botProfiles[moverGameIdx];
      final personality = profile?.personality ?? LudoBotPersonality.balanced;

      _getSmartBotComment(
        pIndex: moverGameIdx,
        event:
            "لقد أكلت حجرة اللاعب ${_getPlayerName(victimGameIdx)} وتغلبت عليه! سخر منه قليلاً.",
      ).then((aiMsg) {
        if (!mounted) return;
        if (aiMsg != null) {
          _handleNewInteraction(moverGameIdx, {
            'type': 'text',
            'content': aiMsg,
            'timestamp': now,
          });
        } else {
          // Fallback to randomized phrases
          final List<String> killerEmojis;
          switch (personality) {
            case LudoBotPersonality.aggressive:
              killerEmojis = [
                'هاك استلم! 🤜',
                'بويه اشتعلوا 😂',
                'وداعاً حبيبي هههه',
                'مو كتلكم ماحد يكدرلي؟ 😎',
                'شلون دقة! 🔥',
              ];
              break;
            case LudoBotPersonality.defensive:
              killerEmojis = [
                '😅',
                '🙈',
                'ماقصدت والله 😅',
                'صدفة جت 🤭',
                'عذراً 😉',
              ];
              break;
            case LudoBotPersonality.random:
              killerEmojis = [
                '😜',
                '🤪',
                '🎉',
                'طارت القطعة! 😂',
                'باي باي 👋',
                '💀',
              ];
              break;
            case LudoBotPersonality.balanced:
              killerEmojis = [
                'كول يا ربي هههه 😂',
                '🎉',
                'عمي اللعب مهارة 😉',
                'هيا 😄',
                '🤜',
              ];
          }
          final msg = killerEmojis[_rng.nextInt(killerEmojis.length)];
          _handleNewInteraction(moverGameIdx, {
            'type': msg.contains(RegExp(r'[😂💪😈🔥🙈😅😯🎲😜🤪🎉💀👏🤜]'))
                ? (msg.length < 3 ? 'emoji' : 'text')
                : 'text',
            'content': msg,
            'timestamp': now,
          });
        }
      });
    }

    // AI Victim reaction
    if (_botIndices.contains(victimGameIdx)) {
      final profile = _botProfiles[victimGameIdx];
      final personality = profile?.personality ?? LudoBotPersonality.balanced;

      _getSmartBotComment(
        pIndex: victimGameIdx,
        event:
            "اللاعب ${_getPlayerName(moverGameIdx)} أكل حجرتي وأرجعني للقاعدة! عبر عن استيائك أو غضبك.",
      ).then((aiMsg) {
        if (!mounted) return;
        if (aiMsg != null) {
          _handleNewInteraction(victimGameIdx, {
            'type': 'text',
            'content': aiMsg,
            'timestamp': now,
          });
        } else {
          // Fallback to randomized phrases
          final List<String> victimEmojis;
          switch (personality) {
            case LudoBotPersonality.aggressive:
              victimEmojis = [
                'هاي شسويت يا بذات! 🤬',
                'حظك كاعد اليوم 😒',
                'اني اعلمك.. الصبر طيب 😈',
                'والله خباثة هههه 😂',
                'لا تفرح هواي',
              ];
              break;
            case LudoBotPersonality.defensive:
              victimEmojis = [
                'اييي هم كول ما غدرتني 😢',
                '💔',
                'ليش هيجي؟ 😢',
                '😔',
                'خطية اني 😅',
              ];
              break;
            case LudoBotPersonality.random:
              victimEmojis = [
                '😵',
                'شنو هاي! 🫠',
                'ضحكتني واني مقهور 😂',
                '🙃',
                'بسيطة 👋',
              ];
              break;
            case LudoBotPersonality.balanced:
              victimEmojis = [
                'يا ستار! 😂',
                'اخ راسي! 🤕',
                'ليش يابه؟ 🤨',
                'باي باي حجرتي 👋',
                'بسيطة بسيطة 😉',
              ];
          }
          final msg = victimEmojis[_rng.nextInt(victimEmojis.length)];
          _handleNewInteraction(victimGameIdx, {
            'type': msg.contains(RegExp(r'[😂💪😈🔥🙈😅😯🎲😜🤪🎉💀👏🤜]'))
                ? (msg.length < 3 ? 'emoji' : 'text')
                : 'text',
            'content': msg,
            'timestamp': now,
          });
        }
      });
    }

    // Occasionally (20%), bot also reacts to seeing someone else get captured
    for (final observerIdx in _botIndices) {
      if (observerIdx == moverGameIdx || observerIdx == victimGameIdx) continue;
      if (_rng.nextInt(100) < 20) {
        final observerEmojis = ['👀', '😲', '🍿', '😏', '🤭'];
        final msg = observerEmojis[_rng.nextInt(observerEmojis.length)];
        Future.delayed(Duration(milliseconds: 800 + _rng.nextInt(1200)), () {
          if (!mounted) return;
          _handleNewInteraction(observerIdx, {
            'type': 'emoji',
            'content': msg,
            'timestamp': now + 800,
          });
        });
      }
    }
  }

  /// Random chatter \u2014 occasionally bots say something in the middle of the game
  /// Call this after each turn change (25% chance)
  void _botRandomChatter() {
    if (_isWinDialogShowing) return;
    if (!_botsEnabled) return;
    if (_botIndices.isEmpty) return;
    if (_rng.nextInt(100) >= 25) return; // Only 25% chance per turn

    // Pick a random bot to speak
    final speakerIdx = _botIndices.elementAt(_rng.nextInt(_botIndices.length));
    final profile = _botProfiles[speakerIdx];
    final personality = profile?.personality ?? LudoBotPersonality.balanced;

    final List<String> chatLines;
    switch (personality) {
      case LudoBotPersonality.aggressive:
        chatLines = [
          '🔥 هااا اجه دوري.. منو يكدرلي؟',
          'راح اشدلها ههههههه 😂',
          'هذا الكيم الي.. انت بس راقب 😎',
          'منو يريد يستسلم من هسه؟ 😉',
          'اللعب صار حامي يا ولد! 🔥',
        ];
        break;
      case LudoBotPersonality.defensive:
        chatLines = [
          '🙏 حظاً طيباً للجميع',
          'العب بحذر وعوف السوالف 😂',
          'لعبة ممتعة يا طيبين!',
          'عيني باردة على لعبي 😉',
          'قطعتي بأمان الحمد لله 😌',
        ];
        break;
      case LudoBotPersonality.random:
        chatLines = [
          '🎲 النرد قفل لو شنو؟',
          'حرت شلعب.. دايخ والله 😂',
          'صارلي ساعة انتظر دوري.. ناموا؟ 😴',
          '😵 ما فهمت شي من هاي الحركة',
          'ايييي عفية عليك.. خوش لعب',
          '🌊 أحب هاي اللعبة حيل',
        ];
        break;
      case LudoBotPersonality.balanced:
        chatLines = [
          '👍 كفوuu والله.. خوش لعب',
          'هااا صرت لاعب براسي؟ هههه 😉',
          'صايرة حيل قوية اليوم 🔥',
          'الحظ وياي لو وي الملوك؟ 😎',
          '🌟 مباراة توب وبيها مهارة',
          'يا معودين ركزوا باللعب 😂',
        ];
    }

    _getSmartBotComment(
      pIndex: speakerIdx,
      event:
          "أنت الآن في منتصف اللعبة، قل جملة عشوائية للاعبين حسب شخصيتك لزيادة التفاعل والمرح.",
    ).then((aiMsg) {
      if (!mounted) return;
      final msg = aiMsg ?? chatLines[_rng.nextInt(chatLines.length)];
      // Small delay so it doesn't fire at same time as other events
      Future.delayed(Duration(milliseconds: 600 + _rng.nextInt(1400)), () {
        if (!mounted) return;
        _handleNewInteraction(speakerIdx, {
          'type': 'text',
          'content': msg,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      });
    });
  }

  /// Bot reacts when it (or the human) rolls a 6
  void _botReactToSix({required int rollerGameIdx, required int diceValue}) {
    if (!_botsEnabled || diceValue != 6) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    // The rolling participant (bot OR auto-playing human) celebrates
    if (_botIndices.contains(rollerGameIdx) ||
        _autoPlayingIndices.contains(rollerGameIdx)) {
      final sixReactions = [
        '🎉 اويلييي 6!',
        '🔥 هاكم الـ 6 كولوا ما عنده حظ',
        '💎 6! بدا الحرفنة!',
        'هههه اشتعلت.. 6 🎲',
        'اللهم صل على محمد وآل محمد ✨',
        '🤩 اخيراً جتني!',
        ' ..رووووح دك ششات 6 🎲',
      ];

      _getSmartBotComment(
        pIndex: rollerGameIdx,
        event: "لقد حصلت على الرقم 6 في اللعبة! عبر عن فرحتك.",
      ).then((aiMsg) {
        if (!mounted) return;
        final msg = aiMsg ?? sixReactions[_rng.nextInt(sixReactions.length)];
        _handleNewInteraction(rollerGameIdx, {
          'type': 'text',
          'content': msg,
          'timestamp': now,
        });
      });
    } else if (rollerGameIdx == _myPlayerIndex) {
      // A bot observer might comment when the real player rolls 6
      if (_rng.nextInt(100) < 40) {
        final observerIdx = _botIndices.elementAt(
          _rng.nextInt(_botIndices.length),
        );
        final reactions = [
          '😲 6! شنو هاي؟',
          '😬 حظك يكسر الصخر!',
          '👀 انتبهوا منه جته 6',
          '😟 بدت الخباثة!',
        ];

        _getSmartBotComment(
          pIndex: observerIdx,
          event:
              "اللاعب ${_getPlayerName(_myPlayerIndex)} حصل على الرقم 6! عبر عن دهشتك أو قلقك.",
        ).then((aiMsg) {
          if (!mounted) return;
          final msg = aiMsg ?? reactions[_rng.nextInt(reactions.length)];
          Future.delayed(Duration(milliseconds: 300 + _rng.nextInt(500)), () {
            if (!mounted) return;
            _handleNewInteraction(observerIdx, {
              'type': msg.length < 3 ? 'emoji' : 'text',
              'content': msg,
              'timestamp': now + 300,
            });
          });
        });
      }
    }
  }

  /// Bot reacts when a piece is deployed from base
  void _botReactToDeploy({required int deployerGameIdx}) {
    if (!_botsEnabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Deployer celebrates deploying
    if (_botIndices.contains(deployerGameIdx) && _rng.nextInt(100) < 60) {
      final deployReactions = [
        '🚀 انطلق السهم!',
        '✅ قطعة جديدة.. نورت الساحة!',
        '⛳️ يلا يا بطل!',
        '🎯 بدت المهمة',
      ];

      _getSmartBotComment(
        pIndex: deployerGameIdx,
        event: "لقد قمت بإخراج حجرة جديدة من القاعدة! عبر عن حماسك.",
      ).then((aiMsg) {
        if (!mounted) return;
        final msg =
            aiMsg ?? deployReactions[_rng.nextInt(deployReactions.length)];
        Future.delayed(Duration(milliseconds: 200 + _rng.nextInt(400)), () {
          if (!mounted) return;
          _handleNewInteraction(deployerGameIdx, {
            'type': 'text',
            'content': msg,
            'timestamp': now,
          });
        });
      });
    }

    // Opponents (bots) might warn each other (25% chance one bot warns)
    for (final observerIdx in _botIndices) {
      if (observerIdx == deployerGameIdx) continue;
      if (_rng.nextInt(100) < 25) {
        final warningReactions = [
          '😱 طلع قطعة! احموا نفسكم',
          '👀 طلع الوحش!',
          '⚠️ انتبهوا منه ترا يغدر',
        ];

        _getSmartBotComment(
          pIndex: observerIdx,
          event:
              "اللاعب ${_getPlayerName(deployerGameIdx)} أخرج حجرة جديدة! حذر اللاعبين الآخرين منه.",
        ).then((aiMsg) {
          if (!mounted) return;
          final msg =
              aiMsg ?? warningReactions[_rng.nextInt(warningReactions.length)];
          Future.delayed(Duration(milliseconds: 700 + _rng.nextInt(800)), () {
            if (!mounted) return;
            _handleNewInteraction(observerIdx, {
              'type': 'text',
              'content': msg,
              'timestamp': now + 700,
            });
          });
        });
        break; // Only one observer reacts
      }
    }
  }
}
