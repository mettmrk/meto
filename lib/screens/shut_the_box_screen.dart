import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/animated_dice.dart';
import '../providers/shut_the_box_provider.dart';
import '../widgets/reaction_display.dart';
import 'shut_the_box_lobby_screen.dart';
import '../widgets/sticker_selection_bottom_sheet.dart';

import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';

class ShutTheBoxScreen extends StatefulWidget {
  const ShutTheBoxScreen({super.key});

  @override
  State<ShutTheBoxScreen> createState() => _ShutTheBoxScreenState();
}

class _ShutTheBoxScreenState extends State<ShutTheBoxScreen> {
  bool _winDialogShown = false;

  final List<Color> _playerColors = const [
    Color(0xFF1976D2), // Blue
    Color(0xFF388E3C), // Green
    Color(0xFFD32F2F), // Red
    Color(0xFFFBC02D), // Yellow
  ];

  final List<String> _playerNames = const [
    'الأزرق',
    'الأخضر',
    'الأحمر',
    'الأصفر',
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ShutTheBoxProvider>(
      builder: (context, provider, child) {
        final isGameOver = provider.status == 'finished';

        if (isGameOver && !_winDialogShown && provider.winnerIndex != -1) {
          _winDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showWinDialog(context, provider);
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFF2C1E16),
          appBar: AppBar(
            title: const Text(
              'أغلق الصندوق',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettingsDialog(context, provider),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Status Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isGameOver
                            ? 'انتهت اللعبة'
                            : 'دور اللاعب: ${_playerNames[provider.currentPlayerIndex]}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                          color: isGameOver
                              ? Colors.white
                              : _playerColors[provider.currentPlayerIndex],
                        ),
                      ),
                      if (provider.diceRolled && !isGameOver)
                        Text(
                          'المطلوب: ${provider.dice1 + provider.dice2}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // The Game Board and Player Cards
                Expanded(
                  child: Builder(
                    builder: (context) {
                      int baseIndex = provider.localPlayerIndex >= 0
                          ? provider.localPlayerIndex
                          : 0;
                      int bottomIndex = baseIndex;
                      int leftIndex = (baseIndex + 1) % 4;
                      int topIndex = (baseIndex + 2) % 4;
                      int rightIndex = (baseIndex + 3) % 4;

                      return Stack(
                        children: [
                          // The Board
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 60.0,
                              ),
                              child: AspectRatio(
                                aspectRatio: 1.0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6C280),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 15,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: const Color(0xFF8B5A2B),
                                      width: 12,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Center Green Felt
                                      Positioned(
                                        top: 55,
                                        bottom: 55,
                                        left: 55,
                                        right: 55,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E702D),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.6,
                                                ),
                                                blurRadius: 10,
                                                spreadRadius: -2,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: _buildCenterDiceArea(
                                            provider,
                                            isGameOver,
                                          ),
                                        ),
                                      ),

                                      // Top Side
                                      Positioned(
                                        top: 0,
                                        left: 55,
                                        right: 55,
                                        child: RotatedBox(
                                          quarterTurns: 2,
                                          child: _buildPlayerSide(
                                            topIndex,
                                            provider,
                                            isGameOver,
                                          ),
                                        ),
                                      ),

                                      // Bottom Side
                                      Positioned(
                                        bottom: 0,
                                        left: 55,
                                        right: 55,
                                        child: _buildPlayerSide(
                                          bottomIndex,
                                          provider,
                                          isGameOver,
                                        ),
                                      ),

                                      // Left Side
                                      Positioned(
                                        left: 0,
                                        top: 55,
                                        bottom: 55,
                                        child: RotatedBox(
                                          quarterTurns: 1,
                                          child: _buildPlayerSide(
                                            leftIndex,
                                            provider,
                                            isGameOver,
                                          ),
                                        ),
                                      ),

                                      // Right Side
                                      Positioned(
                                        right: 0,
                                        top: 55,
                                        bottom: 55,
                                        child: RotatedBox(
                                          quarterTurns: 3,
                                          child: _buildPlayerSide(
                                            rightIndex,
                                            provider,
                                            isGameOver,
                                          ),
                                        ),
                                      ),

                                      // Wooden corners
                                      _buildCorner(0, 0),
                                      _buildCorner(0, null, right: 0),
                                      _buildCorner(null, 0, bottom: 0),
                                      _buildCorner(
                                        null,
                                        null,
                                        right: 0,
                                        bottom: 0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Player Cards
                          _buildPlayerCard(
                            context,
                            bottomIndex,
                            provider,
                            Alignment.bottomLeft,
                          ),
                          _buildPlayerCard(
                            context,
                            topIndex,
                            provider,
                            Alignment.topRight,
                          ),
                          if (provider.maxPlayers == 4) ...[
                            _buildPlayerCard(
                              context,
                              leftIndex,
                              provider,
                              Alignment.centerLeft,
                            ),
                            _buildPlayerCard(
                              context,
                              rightIndex,
                              provider,
                              Alignment.centerRight,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),


              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerCard(
    BuildContext context,
    int playerIndex,
    ShutTheBoxProvider provider,
    Alignment alignment,
  ) {
    if (provider.maxPlayers == 2 && (playerIndex == 1 || playerIndex == 3)) {
      return const SizedBox();
    }

    Map<String, dynamic>? playerInfo;
    for (var player in provider.players.values) {
      if (player is Map && player['index'] == playerIndex) {
        playerInfo = Map<String, dynamic>.from(player);
        break;
      }
    }

    String playerName =
        playerInfo != null &&
            playerInfo['name'] != null &&
            playerInfo['name'].toString().trim().isNotEmpty
        ? playerInfo['name'].toString()
        : _playerNames[playerIndex];

    String? photoUrl = playerInfo?['photo']?.toString();

    Color playerColor = _playerColors[playerIndex];
    bool isActive =
        provider.currentPlayerIndex == playerIndex &&
        provider.status == 'playing';

    Widget cardContent = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? playerColor : Colors.white24,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [BoxShadow(color: playerColor.withOpacity(0.5), blurRadius: 10)]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (isActive)
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 1.0,
                        end: provider.remainingTurnSeconds / 20.0,
                      ),
                      duration: const Duration(seconds: 1),
                      builder: (context, value, child) {
                        return CircularProgressIndicator(
                          value: value,
                          color: playerColor,
                          strokeWidth: 3,
                          backgroundColor: Colors.white24,
                        );
                      },
                    ),
                  ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: playerColor.withOpacity(0.2),
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Icon(Icons.person, color: playerColor, size: 20)
                      : null,
                ),
                if (provider.activeReactions[playerIndex] != null)
                  if (provider.activeReactions[playerIndex]!.startsWith(
                    'text:',
                  ))
                    Positioned(
                      bottom: 40,
                      right: -10,
                      child: _ChatBubbleDisplay(
                        text: provider.activeReactions[playerIndex]!.substring(
                          5,
                        ),
                        onComplete: () => provider.clearReaction(playerIndex),
                      ),
                    )
                  else
                    ReactionDisplay(
                      reactionType: provider.activeReactions[playerIndex]!
                          .split('_')[0],
                      onComplete: () => provider.clearReaction(playerIndex),
                    ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 60, // Limit width so it doesn't overflow
                child: Text(
                  playerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (provider.localPlayerIndex == playerIndex) ...[
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) => StickerSelectionBottomSheet(
                            onSelect: (stickerId) {
                              provider.sendReaction(stickerId);
                            },
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.emoji_emotions_outlined,
                        color: Colors.amber,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _showChatInput(context, provider);
                      },
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.blueAccent,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.mic_none, color: Colors.white70, size: 14),
                ],
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );

    Widget? actionButton;
    if (provider.localPlayerIndex == playerIndex && isActive) {
      actionButton = GestureDetector(
        onTap: () {
          if (!provider.diceRolled) {
            provider.rollDice();
          } else if (provider.selectedTiles.isNotEmpty) {
            provider.confirmSelection((error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error),
                  duration: const Duration(seconds: 2),
                ),
              );
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: !provider.diceRolled ? 48 : 64,
          height: 48,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: !provider.diceRolled
                ? Colors.amber
                : (provider.selectedTiles.isNotEmpty
                      ? Colors.green
                      : Colors.grey),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: !provider.diceRolled
                ? const Icon(Icons.casino, color: Colors.black, size: 32)
                : const FittedBox(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        'تأكيد',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      );
    }

    return Align(
      alignment: alignment,
      child: actionButton != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [actionButton, cardContent],
            )
          : cardContent,
    );
  }

  Widget _buildCorner(
    double? top,
    double? left, {
    double? right,
    double? bottom,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          color: const Color(0xFFC19A6B),
          border: Border.all(color: const Color(0xFF8B5A2B), width: 2),
        ),
      ),
    );
  }

  Widget _buildCenterDiceArea(ShutTheBoxProvider provider, bool isGameOver) {
    if (!provider.diceRolled && !isGameOver) {
      return Center(
        child: Text(
          'ارمي النرد',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 24,
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (provider.diceRolled) {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: -0.1,
              child: _buildDice(provider.dice1, provider),
            ),
            const SizedBox(width: 15),
            Transform.rotate(
              angle: 0.2,
              child: _buildDice(provider.dice2, provider),
            ),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildPlayerSide(
    int playerIndex,
    ShutTheBoxProvider provider,
    bool isGameOver,
  ) {
    if (provider.maxPlayers == 2 && (playerIndex == 1 || playerIndex == 3)) {
      // Hide left/right sides for 2-player mode
      return Container(
        height: 55,
        decoration: BoxDecoration(
          color: const Color(0xFFE6C280),
          border: Border(
            bottom: BorderSide(color: Colors.black.withOpacity(0.5), width: 3),
          ),
        ),
      );
    }

    bool isActive = playerIndex == provider.currentPlayerIndex && !isGameOver;
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: const Color(0xFFE6C280),
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(0.5), width: 3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(10, (tileIndex) {
          bool isShut = provider.tiles[playerIndex.toString()]![tileIndex];
          bool isSelected =
              isActive && provider.selectedTiles.contains(tileIndex);

          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (provider.localPlayerIndex == playerIndex) {
                  provider.toggleTile(tileIndex);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                decoration: BoxDecoration(
                  color: isShut
                      ? const Color(0xFF8D6E63)
                      : _playerColors[playerIndex],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : Colors.black.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isShut
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            offset: const Offset(0, 3),
                            blurRadius: 2,
                          ),
                        ],
                ),
                child: isShut
                    ? const SizedBox()
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            '${tileIndex + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDice(int value, ShutTheBoxProvider provider) {
    if (value < 1 || value > 6) return const SizedBox();

    Color playerColor = _playerColors[provider.currentPlayerIndex];
    // Make the dice color darker
    Color diceColor = Color.lerp(playerColor, Colors.black, 0.3) ?? playerColor;

    return SizedBox(
      width: 66,
      height: 84,
      child: AnimatedDice(
        value: value,
        size: 30.0,
        color: diceColor,
        dotColor: Colors.white,
        isRolling: provider.isDiceAnimating,
      ),
    );
  }

  void _showChatInput(BuildContext context, ShutTheBoxProvider provider) {
    TextEditingController controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            color: const Color(0xFF130B2E),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Tajawal',
                      ),
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        hintStyle: TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Tajawal',
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        border: InputBorder.none,
                      ),
                      autofocus: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    if (controller.text.trim().isNotEmpty) {
                      provider.sendReaction('text:${controller.text.trim()}');
                      Navigator.pop(context);
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.send, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSettingsDialog(BuildContext context, ShutTheBoxProvider provider) {
    double musicVol = 0.5;
    double sfxVol = 0.8;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1B4B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'الإعدادات',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'التحكم في مستوى الأصوات',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Tajawal',
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      const Icon(Icons.music_note, color: Colors.white54),
                      Expanded(
                        child: Slider(
                          value: musicVol,
                          activeColor: Colors.amber,
                          inactiveColor: Colors.white24,
                          onChanged: (val) {
                            setDialogState(() {
                              musicVol = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.volume_up, color: Colors.white54),
                      Expanded(
                        child: Slider(
                          value: sfxVol,
                          activeColor: Colors.amber,
                          inactiveColor: Colors.white24,
                          onChanged: (val) {
                            setDialogState(() {
                              sfxVol = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.exit_to_app, color: Colors.white),
                      label: const Text(
                        'الخروج من المباراة',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await provider.leaveGame();
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWinDialog(BuildContext context, ShutTheBoxProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 10),
            child: _ShutTheBoxVictoryDialog(
              winnerIndex: provider.winnerIndex,
              myPlayerIndex: provider.localPlayerIndex,
              betAmount: provider.betAmount,
              maxPlayers: provider.maxPlayers,
              players: provider.players,
              defaultNames: _playerNames,
              playerColors: _playerColors,
              onExit: () async {
                Navigator.of(ctx).pop();
                await provider.leaveGame();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              onPlayAgain: () async {
                final lastBet = provider.betAmount;
                final lastPlayers = provider.maxPlayers;
                Navigator.of(ctx).pop();
                await provider.leaveGame();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => ShutTheBoxLobbyScreen(
                        autoStartBet: lastBet,
                        autoStartPlayers: lastPlayers,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class _ShutTheBoxVictoryDialog extends StatefulWidget {
  final int winnerIndex;
  final int myPlayerIndex;
  final int betAmount;
  final int maxPlayers;
  final Map<String, dynamic> players;
  final List<String> defaultNames;
  final List<Color> playerColors;
  final VoidCallback onExit;
  final VoidCallback onPlayAgain;

  const _ShutTheBoxVictoryDialog({
    required this.winnerIndex,
    required this.myPlayerIndex,
    required this.betAmount,
    required this.maxPlayers,
    required this.players,
    required this.defaultNames,
    required this.playerColors,
    required this.onExit,
    required this.onPlayAgain,
  });

  @override
  State<_ShutTheBoxVictoryDialog> createState() =>
      _ShutTheBoxVictoryDialogState();
}

class _ShutTheBoxVictoryDialogState extends State<_ShutTheBoxVictoryDialog>
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

  String _getPlayerName(int index) {
    for (var p in widget.players.values) {
      if (p['index'] == index &&
          p['name'] != null &&
          p['name'].toString().trim().isNotEmpty) {
        return p['name'].toString();
      }
    }
    return widget.defaultNames[index];
  }

  String? _getPlayerPhoto(int index) {
    for (var p in widget.players.values) {
      if (p['index'] == index) {
        return p['photo']?.toString();
      }
    }
    return null;
  }

  Widget _buildPlayerAvatar(int index, Color color) {
    String? photoUrl = _getPlayerPhoto(index);
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(
          color: color,
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
    bool isMeWinner = widget.winnerIndex == widget.myPlayerIndex;
    int prizeValue = widget.betAmount > 0
        ? (widget.betAmount * widget.maxPlayers * 0.9).toInt()
        : 500;
    String prizeText = isMeWinner
        ? "+$prizeValue"
        : "-${widget.betAmount > 0 ? widget.betAmount : 500}";

    List<int> activePlayerIndices = widget.players.values
        .map((p) => p['index'] as int)
        .toList();
    int loserIndex = activePlayerIndices.firstWhere(
      (idx) => idx != widget.winnerIndex,
      orElse: () => (widget.winnerIndex == 0 ? 2 : 0),
    );

    return FadeTransition(
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
                    Positioned.fill(
                      child: Image.asset(
                        isMeWinner
                            ? 'assets/images/win.png'
                            : 'assets/images/lost.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                    if (isMeWinner)
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

                          // أبعاد صورة الفوز (win.png) تختلف قليلاً عن صورة الخسارة (lost.png)
                          // لذلك نستخدم متغيرات تتغير حسب نوع الصورة المعروضة
                          final double winnerTopAvatar = isMeWinner ? h * 0.485 : h * 0.505;
                          final double winnerTopName = isMeWinner ? h * 0.50 : h * 0.52;

                          final double loserTopAvatar = isMeWinner ? h * 0.668 : h * 0.688;
                          final double loserTopName = isMeWinner ? h * 0.68 : h * 0.70;

                          return Stack(
                            children: [
                              Positioned(
                                left: w * 0.77,
                                top: h * 0.420,
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
                              Positioned(
                                left: w * 0.273,
                                top: winnerTopAvatar,
                                width: w * 0.138,
                                height: w * 0.138,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.35),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _buildPlayerAvatar(
                                      widget.winnerIndex,
                                      widget.playerColors[widget.winnerIndex],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: w * 0.445,
                                top: winnerTopName,
                                width: w * 0.43,
                                height: w * 0.15,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _getPlayerName(widget.winnerIndex),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: TextDirection.rtl,
                                    style: GoogleFonts.tajawal(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.8),
                                          offset: const Offset(0, 1.5),
                                          blurRadius: 2.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // D. Loser Avatar (Centered inside Blue circle inside blue card)
                              Positioned(
                                left: w * 0.273,
                                top: loserTopAvatar,
                                width: w * 0.138,
                                height: w * 0.138,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blueAccent.withOpacity(
                                          0.35,
                                        ),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _buildPlayerAvatar(
                                      loserIndex,
                                      widget.playerColors[loserIndex],
                                    ),
                                  ),
                                ),
                              ),
                              // E. Loser Name Next to Avatar (Inside Blue Card)
                              Positioned(
                                left: w * 0.455,
                                top: loserTopName,
                                width: w * 0.43,
                                height: w * 0.15,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _getPlayerName(loserIndex),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: TextDirection.rtl,
                                    style: GoogleFonts.tajawal(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.8),
                                          offset: const Offset(0, 1.5),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // F. Play Again Button Overlay (Fits exactly over visual orange button in win.png)
                              Positioned(
                                left: w * 0.085,
                                top: h * 0.835,
                                width: w * 0.395,
                                height: h * 0.105,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    splashColor: Colors.orange.withOpacity(0.3),
                                    highlightColor: Colors.orange.withOpacity(
                                      0.15,
                                    ),
                                    onTap: widget.onPlayAgain,
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                              // G. Exit Button Overlay (Fits exactly over visual blue button in win.png)
                              Positioned(
                                left: w * 0.52,
                                top: h * 0.835,
                                width: w * 0.395,
                                height: h * 0.105,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    splashColor: Colors.blue.withOpacity(0.3),
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
    );
  }
}

class _ChatBubbleDisplay extends StatefulWidget {
  final String text;
  final VoidCallback? onComplete;

  const _ChatBubbleDisplay({required this.text, this.onComplete});

  @override
  State<_ChatBubbleDisplay> createState() => _ChatBubbleDisplayState();
}

class _ChatBubbleDisplayState extends State<_ChatBubbleDisplay> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) widget.onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
          bottomLeft: Radius.circular(2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 120),
      child: Text(
        widget.text,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal',
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
