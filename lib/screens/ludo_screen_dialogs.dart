// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api, unused_element
part of 'ludo_screen.dart';

/// Dialog and modal UI methods.
extension LudoScreenDialogs on _LudoScreenState {
  void _showCustomizationDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2C).withOpacity(0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        final currentUser = auth.FirebaseAuth.instance.currentUser;
        
        final diceInvStream = FirebaseFirestore.instance
            .collection('user_inventory')
            .where('userId', isEqualTo: currentUser?.uid)
            .where('itemType', isEqualTo: model.ShopItemType.ludoDice.index)
            .snapshots();
        final boardInvStream = FirebaseFirestore.instance
            .collection('user_inventory')
            .where('userId', isEqualTo: currentUser?.uid)
            .where('itemType', isEqualTo: model.ShopItemType.ludoBoard.index)
            .snapshots();
        final pieceInvStream = FirebaseFirestore.instance
            .collection('user_inventory')
            .where('userId', isEqualTo: currentUser?.uid)
            .where('itemType', isEqualTo: model.ShopItemType.ludoPiece.index)
            .snapshots();

        final diceShopStream = ShopService().getShopItems(model.ShopItemType.ludoDice);
        final boardShopStream = ShopService().getShopItems(model.ShopItemType.ludoBoard);
        final pieceShopStream = ShopService().getShopItems(model.ShopItemType.ludoPiece);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return DefaultTabController(
              length: 3,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      "تخصيص المظهر",
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TabBar(
                      labelStyle: GoogleFonts.tajawal(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      unselectedLabelStyle: GoogleFonts.tajawal(),
                      indicatorColor: Colors.amber,
                      labelColor: Colors.amber,
                      unselectedLabelColor: Colors.white54,
                      tabs: const [
                        Tab(text: "النرد", icon: Icon(Icons.casino)),
                        Tab(text: "الطاولة والبيئة", icon: Icon(Icons.grid_4x4)),
                        Tab(text: "الحجرات", icon: Icon(Icons.style)),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildInventoryTab(
                            model.ShopItemType.ludoDice,
                            setModalState,
                            diceInvStream,
                            diceShopStream,
                          ),
                          _buildInventoryTab(
                            model.ShopItemType.ludoBoard,
                            setModalState,
                            boardInvStream,
                            boardShopStream,
                          ),
                          _buildInventoryTab(
                            model.ShopItemType.ludoPiece,
                            setModalState,
                            pieceInvStream,
                            pieceShopStream,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInventoryTab(
    model.ShopItemType type,
    StateSetter setModalState,
    Stream<QuerySnapshot> invStream,
    Stream<List<model.ShopItem>> shopStream,
  ) {
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: invStream,
      builder: (context, invSnapshot) {
        if (invSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final ownedIds =
            invSnapshot.data?.docs
                .map((doc) => (doc.data() as Map)['itemId'] as String)
                .toSet() ??
            {};

        return StreamBuilder<List<model.ShopItem>>(
          stream: shopStream,
          builder: (context, shopSnapshot) {
            if (shopSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox();
            }

            final shopItems =
                shopSnapshot.data
                    ?.where((item) => ownedIds.contains(item.id))
                    .toList() ??
                [];

            // Always add default/classic items
            return GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: [
                if (type == model.ShopItemType.ludoBoard) ...[
                  _buildThemeOption(
                    "كلاسيك",
                    "classic",
                    type: model.ShopItemType.ludoBoard,
                    imageUrl: "assets/images/classk.jpg",
                    hallImageUrl: "assets/images/ludo_purple_bg.png",
                    setModalState: setModalState,
                  ),
                  _buildThemeOption(
                    "نيون مضيء",
                    "neon",
                    type: model.ShopItemType.ludoBoard,
                    imageUrl: "assets/images/board_neon.png",
                    setModalState: setModalState,
                  ),
                  _buildThemeOption(
                    "منتصف الليل",
                    "midnight",
                    type: model.ShopItemType.ludoBoard,
                    imageUrl: "assets/images/board_midnight.png",
                    setModalState: setModalState,
                  ),
                  _buildThemeOption(
                    "بركاني",
                    "volcano",
                    type: model.ShopItemType.ludoBoard,
                    imageUrl: "assets/images/board_volcano.png",
                    setModalState: setModalState,
                  ),

                  // ── الأنماط الإضافية من الصور 1-7 ──
                  _buildThemeOption(
                    "بنفسجي مضيء",
                    "board1",
                    type: model.ShopItemType.ludoBoard,
                    imageUrl: "assets/images/1.jpg",
                    setModalState: setModalState,
                  ),
                  _buildThemeOption(
                    "نهر",
                    "river",
                    type: model.ShopItemType.ludoBoard,
                    imageUrl: "assets/images/3.jpg",
                    hallImageUrl: "assets/images/ludo_river_bg.png",
                    setModalState: setModalState,
                  ),
                  _buildThemeOption(
                    "أزرق صلب",
                    "board4",
                    type: model.ShopItemType.ludoBoard,
                    imageUrl: "assets/images/4.jpg",
                    setModalState: setModalState,
                  ),
                  _buildThemeOption(
                    "ليلي غامق",
                    "board5",
                    type: model.ShopItemType.ludoBoard,
                    imageUrl: "assets/images/5.jpg",
                    setModalState: setModalState,
                  ),
                  _buildThemeOption(
                    "حجارة نارية",
                    "board6",
                    type: model.ShopItemType.ludoBoard,
                    imageUrl: "assets/images/6.jpg",
                    setModalState: setModalState,
                  ),
                  _buildThemeOption(
                    "غابة استوائية",
                    "board7",
                    type: model.ShopItemType.ludoBoard,
                    imageUrl: "assets/images/7.jpg",
                    setModalState: setModalState,
                  ),
                  _buildThemeOption(
                    "قصر الملوك",
                    "board8",
                    type: model.ShopItemType.ludoBoard,
                    imageUrl: "assets/images/8.jpg",
                    setModalState: setModalState,
                  ),
                ],
                if (type == model.ShopItemType.ludoHall) ...[
                   _buildThemeOption(
                    "الافتراضي",
                    "none",
                    type: model.ShopItemType.ludoHall,
                    icon: Icons.door_front_door_rounded,
                    setModalState: setModalState,
                  ),
                ],
                if (type == model.ShopItemType.ludoPiece)
                  _buildTokenThemeOption(
                    "الافتراضي",
                    "pawn",
                    "assets/images/token_pawn_red.png",
                    modalSetState: setModalState,
                  ),
                if (type == model.ShopItemType.ludoDice)
                  _buildDiceThemeOption(
                    "الافتراضي",
                    "none",
                    null,
                    setModalState: setModalState,
                  ),
                ...shopItems.map((item) {
                  final itemId = item.id;
                  final metadata = item.metadata;

                  if (type == model.ShopItemType.ludoPiece) {
                    Map<String, String>? urls;
                    if (metadata != null && metadata['urls'] != null) {
                      urls = Map<String, String>.from(metadata['urls']);
                    }
                    return _buildTokenThemeOption(
                      item.name,
                      itemId,
                      item.imageUrl,
                      urls: urls,
                      modalSetState: setModalState,
                    );
                  } else if (type == model.ShopItemType.ludoDice) {
                    Map<String, String>? urls;
                    if (metadata != null && metadata['urls'] != null) {
                      urls = Map<String, String>.from(metadata['urls']);
                    }
                    return _buildDiceThemeOption(
                      item.name,
                      itemId,
                      item.imageUrl,
                      urls: urls,
                      setModalState: setModalState,
                    );
                  } else if (type == model.ShopItemType.ludoBoard) {
                    return _buildThemeOption(
                      item.name,
                      itemId,
                      type: type,
                      imageUrl: item.imageUrl,
                      setModalState: setModalState,
                      hallImageUrl: (metadata?['urls'] as Map?)?['hall']?.toString(),
                    );
                  }
                  return const SizedBox();
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption(
    String title,
    String themeKey, {
    required model.ShopItemType type,
    String? imageUrl,
    IconData? icon,
    required StateSetter setModalState,
    String? hallImageUrl,
  }) {
    bool isSelected = (type == model.ShopItemType.ludoBoard)
        ? (_boardTheme == themeKey)
        : (_hallTheme == themeKey);
    return GestureDetector(
      onTap: () async {
        // Perform all backend updates safely in the background
        try {
          setState(() {
            if (type == model.ShopItemType.ludoBoard) {
              _boardTheme = themeKey;
              if (hallImageUrl != null) {
                _hallImageUrl = hallImageUrl;
                _hallTheme = themeKey; // Use same key for tracking
              }
            } else {
              _hallTheme = themeKey;
            }
          });
          setModalState(() {});

          final prefs = await SharedPreferences.getInstance();
          if (type == model.ShopItemType.ludoBoard) {
            await prefs.setString('ludo_board_theme', themeKey);
          } else {
            await prefs.setString('ludo_hall_theme', themeKey);
          }

          final currentUser = auth.FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            final updates = <String, dynamic>{};
            if (type == model.ShopItemType.ludoBoard) {
              updates['ludoBoardTheme'] = themeKey;
              if (hallImageUrl != null) {
                updates['ludoHallTheme'] = themeKey;
              }
            } else {
              updates['ludoHallTheme'] = themeKey;
            }
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .update(updates);
          }

          if (_gameMode == 'online' && _roomId != null) {
            if (type == model.ShopItemType.ludoBoard) {
              LudoService().updatePlayerPreference(
                _roomId!, 
                boardTheme: themeKey,
                hallTheme: hallImageUrl != null ? themeKey : null,
              );
            } else {
              LudoService().updatePlayerPreference(_roomId!, hallTheme: themeKey);
            }
          }

          if (type == model.ShopItemType.ludoBoard) {
            _reinitGameWithTheme();
          }
        } catch (e) {
          debugPrint('Error equipping ludo board theme: $e');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.amber.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.startsWith('http')
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Icon(
                                icon ?? Icons.grid_4x4,
                                color: isSelected
                                    ? Colors.amber
                                    : Colors.white70,
                                size: 28,
                              ),
                            )
                          : Image.asset(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Icon(
                                icon ?? Icons.grid_4x4,
                                color: isSelected
                                    ? Colors.amber
                                    : Colors.white70,
                                size: 28,
                              ),
                            ),
                    )
                  : Icon(
                          icon ?? Icons.grid_4x4,
                          color: isSelected ? Colors.amber : Colors.white70,
                          size: 28,
                        ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.tajawal(
                  color: isSelected ? Colors.amber : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.check_circle, color: Colors.amber, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiceThemeOption(
    String title,
    String themeKey,
    String? imageUrl, {
    required StateSetter setModalState,
    Map<String, String>? urls,
  }) {
    bool isSelected = _playerDiceThemes[_myPlayerIndex] == themeKey;
    return GestureDetector(
      onTap: () async {
        // Perform all backend updates safely in the background
        try {
          setModalState(() {
            _ludoDiceTheme = themeKey;
            if (urls != null) {
              _ludoDiceUrls = urls;
              _playerDiceUrlsMap[_myPlayerIndex] = urls;
            } else {
              _ludoDiceUrls = null;
              _playerDiceUrlsMap.remove(_myPlayerIndex);
            }
            _playerDiceThemes[_myPlayerIndex] = themeKey;
          });
          setState(() {}); // Keep parent in sync

          final currentUser = auth.FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .update({'ludoDiceTheme': themeKey});
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('ludo_dice_theme', themeKey);

          if (_gameMode == 'online' && _roomId != null) {
            LudoService().updatePlayerPreference(_roomId!, diceTheme: themeKey);
          }

          _reinitGameWithTheme();
        } catch (e) {
          debugPrint('Error equipping ludo dice theme: $e');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.amber.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.startsWith('http')
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => const Icon(
                                Icons.casino,
                                color: Colors.white70,
                                size: 30,
                              ),
                            )
                          : Image.asset(
                              imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => const Icon(
                                Icons.casino,
                                color: Colors.white70,
                                size: 30,
                              ),
                            ),
                    )
                  : const Icon(Icons.casino, color: Colors.white70, size: 30),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.tajawal(
                  color: isSelected ? Colors.amber : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.check_circle, color: Colors.amber, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenThemeOption(
    String title,
    String themeKey,
    String? imageUrl, {
    Map<String, String>? urls,
    VoidCallback? onSelect,
    StateSetter? modalSetState,
  }) {
    bool isSelected = _getPlayerTokenShape(_myPlayerIndex) == themeKey;
    return GestureDetector(
      onTap: () async {
        // Perform all backend updates safely in the background
        try {
          // حفظ شكل الحجرات للاعب الحالي فقط
          await _savePlayerTokenShape(_myPlayerIndex, themeKey);

          if (modalSetState != null) {
            modalSetState(() {
              _ludoTokenTheme = themeKey;
            });
          }

          if (onSelect != null) onSelect();

          final currentUser = auth.FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .update({'ludoTokenTheme': themeKey});
          }

          // Persist to SharedPreferences for immediate next load
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('ludo_token_theme', themeKey);

          // Update Room if online
          if (_gameMode == 'online' && _roomId != null) {
            LudoService().updatePlayerPreference(
              _roomId!,
              tokenShape: themeKey,
              tokenTheme: themeKey,
            );
          }

          if (themeKey != 'none') {
            setState(() {
              _ludoTokenUrls = urls ?? {};
            });
            if (urls == null) {
              await _fetchTokenUrls(themeKey);
            }
          } else {
            setState(() {
              _ludoTokenUrls = {};
            });
          }

          if (_uiState == LudoUiState.playing || _uiState == LudoUiState.menu) {
            _reinitGameWithTheme();
          }
        } catch (e) {
          debugPrint('Error equipping ludo token theme: $e');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.amber.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl.startsWith('http')
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const Icon(
                                Icons.style,
                                color: Colors.white70,
                              ),
                            )
                          : Image.asset(
                              imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const Icon(
                                Icons.style,
                                color: Colors.white70,
                              ),
                            ),
                    )
                  : const Icon(Icons.style, color: Colors.white70, size: 30),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.tajawal(
                  color: isSelected ? Colors.amber : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.check_circle, color: Colors.amber, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomizationButton(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "إعدادات اللعب",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_uiState == LudoUiState.playing)
                    ListTile(
                      onTap: () {
                        Navigator.pop(context); // Close settings
                        _showExitConfirmation();
                      },
                      leading: const CircleAvatar(
                        backgroundColor: Colors.redAccent,
                        child: Icon(Icons.exit_to_app, color: Colors.white),
                      ),
                      title: const Text(
                        "مغادرة اللعبة",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      subtitle: const Text(
                        "سيتم إنهاء المباراة وفوز الخصم",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  const Divider(color: Colors.white10),
                  const Text(
                    "إعدادات الصوت",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(height: 24),

                  // Silent Mode Toggle
                  SwitchListTile(
                    title: const Text(
                      "وضع الصامت (كتم الكل)",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    value: _isMuted,
                    activeColor: Colors.cyanAccent,
                    onChanged: (val) {
                      setModalState(() => _isMuted = val);
                      _toggleMute(forceValue: val);
                    },
                    secondary: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: _isMuted ? Colors.redAccent : Colors.cyanAccent,
                    ),
                  ),
                  const Divider(color: Colors.white10),

                  // Music Volume
                  _buildVolumeSlider(
                    title: "الموسيقى الخلفية",
                    icon: Icons.music_note,
                    value: _musicVolume,
                    enabled: !_isMuted,
                    onChanged: (val) {
                      setModalState(() => _musicVolume = val);
                      setState(() => _musicVolume = val);
                      if (!_isMuted) _musicPlayer.setVolume(val);
                      _saveAudioSetting('ludo_music_volume', val);
                    },
                  ),

                  // Dice Volume
                  _buildVolumeSlider(
                    title: "صوت رمي النرد",
                    icon: Icons.casino,
                    value: _diceVolume,
                    enabled: !_isMuted,
                    onChanged: (val) {
                      setModalState(() => _diceVolume = val);
                      setState(() => _diceVolume = val);
                      _ludoGame.updateVolumes(dice: val);
                      _saveAudioSetting('ludo_dice_volume', val);
                    },
                  ),

                  // SFX Volume
                  _buildVolumeSlider(
                    title: "تأثيرات اللعب (الحركة/القبض)",
                    icon: Icons.auto_awesome,
                    value: _sfxVolume,
                    enabled: !_isMuted,
                    onChanged: (val) {
                      setModalState(() => _sfxVolume = val);
                      setState(() => _sfxVolume = val);
                      _ludoGame.updateVolumes(sfx: val);
                      _saveAudioSetting('ludo_sfx_volume', val);
                    },
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.withOpacity(0.8),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "حفظ وإغلاق",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
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

  Widget _buildVolumeSlider({
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
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontFamily: 'Tajawal',
                        ),
                      ),
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

  void _showWinDialog(int winner) {
    if (!mounted || _isWinDialogShowing) return;
    _isWinDialogShowing = true; // Set sync immediately

    // Stop Flame Game Engine
    try {
      _ludoGame.paused = true;
      _ludoGame.pauseEngine();
    } catch (e) {
      debugPrint('[LudoGame] Error pausing engine: $e');
    }

    setState(() {
      _hasSeenMyWinDialog = true;
      _isRolling = false;
      _canRoll = false;
      _isAiThinking = false;
      _remainingTime = 0;
      _reRollGraceRemaining = 0;
    });

    // Stop everything
    _turnTimer?.cancel();
    _reRollGraceTimer?.cancel();

    bool isMeWinner = (winner == _myPlayerIndex);

    // Distribute winnings if I am the winner
    if (isMeWinner && _selectedBet > 0) {
      final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
      if (myUid != null) {
        int winAmount = (_selectedBet * _currentMatchMaxPlayers * 0.9).toInt();
        UserService()
            .updateUser(
              uid: myUid,
              data: {'coins': FieldValue.increment(winAmount)},
            )
            .catchError((e) => debugPrint('[LudoBet] Reward error: $e'));

        debugPrint('[LudoBet] Rewarded $winAmount coins to $myUid');
      }
    }

    // Update Ludo statistics in Firebase
    final myUid = auth.FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null) {
      UserService().updateUser(
        uid: myUid,
        data: {
          'gamesPlayed': FieldValue.increment(1),
          'wins': FieldValue.increment(isMeWinner ? 1 : 0),
          'losses': FieldValue.increment(isMeWinner ? 0 : 1),
          'gameStats.ludo.played': FieldValue.increment(1),
          'gameStats.ludo.wins': FieldValue.increment(isMeWinner ? 1 : 0),
          'gameStats.ludo.losses': FieldValue.increment(isMeWinner ? 0 : 1),
        },
      ).catchError((e) => debugPrint('[LudoStats] Update error: $e'));
      debugPrint('[LudoStats] Updated Ludo statistics for $myUid');
    }

    // ── Log win event ──
    _addToLog(
      LudoGameLogEntry(
        type: LudoGameLogType.win,
        playerName: _getPlayerName(winner),
        playerColor: _getPlayerColor(winner),
        message: isMeWinner
            ? 'اكتسح المباراة وفاز بالمركز الأول! 🏆🎉'
            : '${_getPlayerName(winner)} فاز بالمركز الأول! 🏆',
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 10),
            child: _LudoVictoryDialog(
              winnerIndex: winner,
              myPlayerIndex: _myPlayerIndex,
              selectedBet: _selectedBet,
              currentMatchMaxPlayers: _currentMatchMaxPlayers,
              onlinePlayerNames: _onlinePlayerNames,
              onlinePlayerImages: _onlinePlayerImages,
              botProfiles: _botProfiles,
              userProfileImage: _userProfileImage,
              userName: _userName,
              gameMode: _gameMode,
              isMeWinner: isMeWinner,
              onExit: () {
                _isWinDialogShowing = false;
                try {
                  _ludoGame.paused = false;
                  _ludoGame.resumeEngine();
                } catch (e) {
                  debugPrint('[LudoGame] Error resuming engine: $e');
                }
                Navigator.of(ctx, rootNavigator: true).pop();
                if (mounted) {
                  _backToMenu();
                  // If online, leave room
                  if (_gameMode == 'online' && _roomId != null) {
                    LudoService().leaveRoom(_roomId!);
                  }
                }
              },
              onPlayAgain: () {
                _isWinDialogShowing = false;
                try {
                  _ludoGame.paused = false;
                  _ludoGame.resumeEngine();
                } catch (e) {
                  debugPrint('[LudoGame] Error resuming engine: $e');
                }
                Navigator.of(ctx, rootNavigator: true).pop();
                if (_gameMode == 'online') {
                  _startOnlineGame(
                    maxPlayers: _currentMatchMaxPlayers,
                    mode: _currentMatchMode,
                  );
                } else {
                  // Restart local game
                  _startOfflineGame();
                }
              },
              getPlayerName: _getPlayerName,
              getPlayerColor: _getPlayerColor,
              getAvatarProvider: _getAvatarProvider,
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultButton({
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.white10,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isPrimary ? Colors.white24 : color.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isPrimary ? Colors.black87 : color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        ),
      ),
    );
  }

  void _showPlayerProfile(int pIndex) {
    final name = _getPlayerName(pIndex);
    final color = _getPlayerColor(pIndex);
    final profile = _botProfiles[pIndex];
    final isBot = _botIndices.contains(pIndex) || profile != null;

    int level = profile?.fakeLevel ?? (pIndex == _myPlayerIndex ? 15 : 1);
    String difficultyLabel = '';
    if (isBot && profile != null) {
      switch (profile.difficulty) {
        case LudoBotDifficulty.easy:
          difficultyLabel = '🐣 مبتدئ';
          break;
        case LudoBotDifficulty.medium:
          difficultyLabel = '⚔️ متوسط';
          break;
        case LudoBotDifficulty.hard:
          difficultyLabel = '🔥 محترف';
          break;
        case LudoBotDifficulty.pro:
          difficultyLabel = '👑 خبير';
          break;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        String? resolvedUid = _onlinePlayerUids[pIndex];
        if (resolvedUid == null && pIndex == _myPlayerIndex) {
          resolvedUid = auth.FirebaseAuth.instance.currentUser?.uid;
        }
        final bool isOnlineRealPlayer =
            _gameMode == 'online' &&
            !isBot &&
            resolvedUid != null &&
            resolvedUid.isNotEmpty;
        Future<bool>? friendCheckFuture;
        if (isOnlineRealPlayer && resolvedUid != auth.FirebaseAuth.instance.currentUser?.uid) {
          friendCheckFuture = VoiceRoomService().isFriend(resolvedUid);
        }

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1C1C2E), Color(0xFF2A2A40)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: color.withOpacity(0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 30,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: isOnlineRealPlayer
                  ? FutureBuilder<model.User?>(
                      future: UserService().getUser(resolvedUid),
                      builder: (context, userSnap) {
                        final realUser = userSnap.data;
                        final int realLevel = realUser?.level ?? level;
                        final String? bio = realUser?.bio;
                        final String? displayId = realUser?.displayId;
                        final String? gender = realUser?.gender;
                        final String? country = realUser?.country;

                        return _buildProfileCardContent(
                          ctx: ctx,
                          pIndex: pIndex,
                          name: name,
                          color: color,
                          displayId: displayId,
                          gender: gender,
                          country: country,
                          level: realLevel,
                          bio: bio,
                          difficultyLabel: difficultyLabel,
                          isOnlineRealPlayer: isOnlineRealPlayer,
                          uidStr: resolvedUid,
                          friendCheckFuture: friendCheckFuture,
                          realUser: realUser,
                        );
                      },
                    )
                  : _buildProfileCardContent(
                      ctx: ctx,
                      pIndex: pIndex,
                      name: name,
                      color: color,
                      displayId: null,
                      gender: null,
                      country: null,
                      level: level,
                      bio: null,
                      difficultyLabel: difficultyLabel,
                      isOnlineRealPlayer: false,
                      uidStr: resolvedUid,
                      friendCheckFuture: null,
                      realUser: null,
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCardContent({
    required BuildContext ctx,
    required int pIndex,
    required String name,
    required Color color,
    String? displayId,
    String? gender,
    String? country,
    required int level,
    String? bio,
    required String difficultyLabel,
    required bool isOnlineRealPlayer,
    String? uidStr,
    Future<bool>? friendCheckFuture,
    model.User? realUser,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: _getProfileImage(pIndex, color),
            ),
            if (difficultyLabel.isNotEmpty)
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    difficultyLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Name
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
          textAlign: TextAlign.center,
        ),
        // ID
        if (displayId != null)
          Text(
            'ID: $displayId',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              fontFamily: 'Tajawal',
            ),
          ),
        const SizedBox(height: 8),
        // Info Row: Gender / Country / Level
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (gender != null)
              Icon(
                gender.toLowerCase() == 'female' ? Icons.female : Icons.male,
                color: gender.toLowerCase() == 'female'
                    ? Colors.pinkAccent
                    : Colors.blueAccent,
                size: 18,
              ),
            if (gender != null) const SizedBox(width: 8),
            if (country != null && country.isNotEmpty)
              Text(
                country, // Assuming country is a flag emoji or short name
                style: const TextStyle(fontSize: 16),
              ),
            if (country != null && country.isNotEmpty) const SizedBox(width: 8),
            LevelBadge(level: level, size: 20),
          ],
        ),
        const SizedBox(height: 16),
        // Bio
        if (bio != null && bio.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              bio,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontFamily: 'Tajawal',
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // ── Ludo Statistics Section ──
        if (isOnlineRealPlayer) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      color: color,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'إحصائيات لودو',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem('لعب', '${realUser?.gameStats['ludo']?['played'] ?? 0}'),
                    _buildStatDivider(),
                    _buildStatItem('فوز', '${realUser?.gameStats['ludo']?['wins'] ?? 0}'),
                    _buildStatDivider(),
                    _buildStatItem('خسارة', '${realUser?.gameStats['ludo']?['losses'] ?? 0}'),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        // Action Icons Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Follow / Message Button
            if (isOnlineRealPlayer && uidStr != null && uidStr != auth.FirebaseAuth.instance.currentUser?.uid)
              FutureBuilder<bool>(
                future: friendCheckFuture,
                builder: (context, snapshot) {
                  final bool isFriend = snapshot.data ?? false;
                  bool isLoading =
                      snapshot.connectionState == ConnectionState.waiting;

                  return _buildIconButton(
                    icon: isLoading
                        ? Icons.sync
                        : (isFriend
                              ? Icons.message_rounded
                              : Icons.person_add_rounded),
                    color: isFriend ? Colors.blueAccent : Colors.pinkAccent,
                    onTap: isLoading
                        ? null
                        : () async {
                            if (isFriend) {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (c) => ChatScreen(
                                    receiverId: uidStr,
                                    receiverName: name,
                                    receiverImage: _onlinePlayerImages[pIndex],
                                  ),
                                ),
                              );
                            } else {
                              try {
                                final currentUid =
                                    auth
                                        .FirebaseAuth
                                        .instance
                                        .currentUser
                                        ?.uid ??
                                    '';
                                final currentUsername =
                                    auth
                                        .FirebaseAuth
                                        .instance
                                        .currentUser
                                        ?.displayName ??
                                    'مستخدم';
                                if (currentUid.isNotEmpty) {
                                  await UserService().followUser(
                                    currentUserId: currentUid,
                                    currentUsername: currentUsername,
                                    userToFollowId: uidStr,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'تم إرسال طلب المتابعة بنجاح',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('حدث خطأ أثناء المتابعة'),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                  );
                },
              ),
            // Mute Button
            if (pIndex != _myPlayerIndex)
              StatefulBuilder(
                builder: (context, setBtnState) {
                  bool isSilenced = _silencedPlayerIndices.contains(pIndex);
                  return _buildIconButton(
                    icon: isSilenced
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: isSilenced ? Colors.redAccent : Colors.white70,
                    onTap: () {
                      setState(() {
                        if (isSilenced) {
                          _silencedPlayerIndices.remove(pIndex);
                        } else {
                          _silencedPlayerIndices.add(pIndex);
                        }
                      });
                      setBtnState(() {});
                      if (_gameMode == 'online') {
                        final uId = _onlinePlayerUids[pIndex];
                        if (uId != null) {
                          final agoraUid = VoiceRoomService.getAgoraUid(uId);
                          if (agoraUid != 0) {
                            final voiceService = Provider.of<VoiceRoomService>(context, listen: false);
                            voiceService.muteRemoteAudioStreamLocally(
                              agoraUid,
                              !isSilenced,
                            );
                          }
                        }
                      }
                    },
                  );
                },
              ),
            // Close Button
            _buildIconButton(
              icon: Icons.close_rounded,
              color: Colors.white54,
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  void _showInsufficientFundsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Column(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 50,
            ),
            const SizedBox(height: 10),
            const Text(
              "رصيد غير كافٍ",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: const Text(
          "ليس لديك قطع ذهبية كافية لهذا الرهان. هل تريد الشحن؟",
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'Tajawal',
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
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
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LudoStoreScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "شحن",
                    style: TextStyle(
                      color: Color(0xFF1E1E2C),
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

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "تأكيد الخروج",
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
          content: Text(
            "هل أنت متأكد من أنك تريد الخروج من المباراة؟ سيتم اعتبارك منسحباً.",
            style: GoogleFonts.tajawal(color: Colors.white70),
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                "إلغاء",
                style: GoogleFonts.tajawal(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                "خروج",
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontFamily: 'Tajawal',
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

// ── Custom Victory Dialog overlaying win.png ──
class _LudoVictoryDialog extends StatefulWidget {
  final int winnerIndex;
  final int myPlayerIndex;
  final int selectedBet;
  final int currentMatchMaxPlayers;
  final String gameMode;
  final Map<int, String> onlinePlayerNames;
  final Map<int, String?> onlinePlayerImages;
  final Map<int, LudoBotProfile> botProfiles;
  final String? userProfileImage;
  final String userName;
  final bool isMeWinner;
  final VoidCallback onExit;
  final VoidCallback onPlayAgain;
  final String Function(int) getPlayerName;
  final Color Function(int) getPlayerColor;
  final ImageProvider? Function(String?) getAvatarProvider;

  const _LudoVictoryDialog({
    required this.winnerIndex,
    required this.myPlayerIndex,
    required this.selectedBet,
    required this.currentMatchMaxPlayers,
    required this.gameMode,
    required this.onlinePlayerNames,
    required this.onlinePlayerImages,
    required this.botProfiles,
    required this.userProfileImage,
    required this.userName,
    required this.isMeWinner,
    required this.onExit,
    required this.onPlayAgain,
    required this.getPlayerName,
    required this.getPlayerColor,
    required this.getAvatarProvider,
  });

  @override
  State<_LudoVictoryDialog> createState() => _LudoVictoryDialogState();
}

class _LudoVictoryDialogState extends State<_LudoVictoryDialog> with SingleTickerProviderStateMixin {
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
    String? photoPath;
    if (widget.gameMode == 'online') {
      photoPath = widget.onlinePlayerImages[pIndex];
    } else if (pIndex == widget.myPlayerIndex) {
      photoPath = widget.userProfileImage;
    }

    if (photoPath != null && photoPath.isNotEmpty) {
      final provider = widget.getAvatarProvider(photoPath);
      if (provider != null) {
        return Image(
          image: provider,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: color,
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: Colors.white),
          ),
        );
      }
    }

    if (widget.botProfiles.containsKey(pIndex)) {
      final profile = widget.botProfiles[pIndex]!;
      if (profile.botImage != null) {
        return Image.asset(
          profile.botImage!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: color,
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: Colors.white),
          ),
        );
      }
      final botName = profile.name;
      final avatarUrl =
          'https://api.dicebear.com/9.x/avataaars/png?seed=$botName&backgroundColor=b6e3f4,c0aede,d1d4f9,ffdfbf,ffd5dc';
      return Image.network(
        avatarUrl,
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
    // Determine active players in this match
    List<int> activePlayerIndices = [];
    for (int i = 0; i < 4; i++) {
      if (widget.gameMode == 'online') {
        if (widget.onlinePlayerNames.containsKey(i)) {
          activePlayerIndices.add(i);
        }
      } else {
        if (i == widget.myPlayerIndex || widget.botProfiles.containsKey(i)) {
          activePlayerIndices.add(i);
        }
      }
    }

    // Determine the loser (runner-up / main opponent)
    int loserIndex = activePlayerIndices.firstWhere(
      (idx) => idx != widget.winnerIndex,
      orElse: () => (widget.winnerIndex + 2) % 4,
    );

    // Prize text calculation
    int prizeValue = widget.selectedBet > 0
        ? (widget.selectedBet * widget.currentMatchMaxPlayers * 0.9).toInt()
        : 500;
    String prizeText = widget.isMeWinner 
        ? "+$prizeValue" 
        : "-${widget.selectedBet > 0 ? widget.selectedBet : 500}";

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
                    // 1. Background Image
                    Positioned.fill(
                      child: Image.asset(
                        widget.isMeWinner ? 'assets/images/win.png' : 'assets/images/lost.png',
                        fit: BoxFit.fill,
                      ),
                    ),

                    // 2. Lottie Fireworks overlay if user won
                    if (widget.isMeWinner)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Lottie.asset(
                            'assets/lottie/Fireworks.json',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                    // 3. Perfect Game Data Overlays aligned inside win.png components
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final h = constraints.maxHeight;

                          return Stack(
                            children: [
                              // A. Prize Capsule Text (above winner card on the right)
                              Positioned(
                                left: w * 0.77,
                                top: h * 0.405,
                                width: w * 0.15,
                                height: h * 0.042,
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      prizeText,
                                      style: GoogleFonts.tajawal(
                                        color: const Color(0xFFFFD700), // Gold
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

                              // B. Winner Avatar (Centered inside Gold circle inside yellow card)
                              Positioned(
                                left: w * 0.273,
                                top: h * 0.485,
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
                                      widget.getPlayerColor(widget.winnerIndex),
                                    ),
                                  ),
                                ),
                              ),

                              // C. Winner Name Next to Avatar (Inside Yellow Card)
                              Positioned(
                                left: w * 0.435,
                                top: h * 0.48,
                                width: w * 0.43,
                                height: w * 0.15,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    widget.getPlayerName(widget.winnerIndex),
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

                              // D. Loser Avatar (Centered inside Blue circle inside blue card)
                              Positioned(
                                left: w * 0.273,
                                top: h * 0.665,
                                width: w * 0.138,
                                height: w * 0.138,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blueAccent.withOpacity(0.35),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _buildPlayerAvatar(
                                      loserIndex,
                                      widget.getPlayerColor(loserIndex),
                                    ),
                                  ),
                                ),
                              ),

                              // E. Loser Name Next to Avatar (Inside Blue Card)
                              Positioned(
                                left: w * 0.435,
                                top: h * 0.66,
                                width: w * 0.43,
                                height: w * 0.15,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    widget.getPlayerName(loserIndex),
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
                                    highlightColor: Colors.orange.withOpacity(0.15),
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
                                    highlightColor: Colors.blue.withOpacity(0.15),
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
