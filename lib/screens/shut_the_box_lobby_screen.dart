import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/shut_the_box_provider.dart';
import 'shut_the_box_screen.dart';

class ShutTheBoxLobbyScreen extends StatefulWidget {
  final int? autoStartBet;
  final int? autoStartPlayers;

  const ShutTheBoxLobbyScreen({
    super.key,
    this.autoStartBet,
    this.autoStartPlayers,
  });

  @override
  State<ShutTheBoxLobbyScreen> createState() => _ShutTheBoxLobbyScreenState();
}

class _ShutTheBoxLobbyScreenState extends State<ShutTheBoxLobbyScreen> {
  int _selectedBet = 50;
  int _selectedPlayers = 2; // 2 means 1v1
  bool _isSearching = false;
  bool _matchFoundAnimation = false;
  int _matchCountdown = 3;
  ShutTheBoxProvider? _activeProvider;

  final List<int> _betOptions = [50, 100, 250, 500, 1000, 2000, 4000, 6000];

  @override
  void initState() {
    super.initState();
    if (widget.autoStartBet != null) {
      _selectedBet = widget.autoStartBet!;
    }
    if (widget.autoStartPlayers != null) {
      _selectedPlayers = widget.autoStartPlayers!;
    }
    if (widget.autoStartBet != null || widget.autoStartPlayers != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startGame();
      });
    }
  }

  void _incrementBet() {
    int currentIndex = _betOptions.indexOf(_selectedBet);
    if (currentIndex < _betOptions.length - 1) {
      setState(() {
        _selectedBet = _betOptions[currentIndex + 1];
      });
    }
  }

  void _decrementBet() {
    int currentIndex = _betOptions.indexOf(_selectedBet);
    if (currentIndex > 0) {
      setState(() {
        _selectedBet = _betOptions[currentIndex - 1];
      });
    }
  }

  void _startGame() async {
    setState(() {
      _isSearching = true;
      _matchFoundAnimation = false;
      _matchCountdown = 3;
    });

    _activeProvider = Provider.of<ShutTheBoxProvider>(context, listen: false);
    
    try {
      String? name;
      String? photo;
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (doc.exists) {
            final data = doc.data();
            name = data?['nickname'] ?? data?['username'] ?? user.displayName;
            photo = data?['profileImage'] ?? user.photoURL;
            
            int metoChips = data?['meto_chips'] ?? 0;
            if (_selectedBet > 0 && metoChips < _selectedBet) {
              if (mounted) {
                setState(() {
                  _isSearching = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('عذراً، لا تملك رصيد كافي من عملات ميتو')),
                );
              }
              return;
            }
          } else {
            name = user.displayName;
            photo = user.photoURL;
          }
        }
      } catch (e) {
        if (e.toString().contains('insufficient_funds') || e.toString().contains('رصيد كافي')) {
          return;
        }
      }

      await _activeProvider!.joinGame(_selectedBet, _selectedPlayers, name: name, photo: photo);

      // Listen for room status to change to 'playing'
      _activeProvider!.addListener(_onRoomStatusChanged);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().contains('insufficient_funds') ? 'عذراً، لا تملك رصيد كافي من عملات ميتو' : 'فشل الانضمام: $e')),
      );
    }
  }

  void _onRoomStatusChanged() async {
    if (_activeProvider == null) return;
    
    if (_activeProvider!.status == 'playing' && _isSearching && !_matchFoundAnimation) {
      _activeProvider!.removeListener(_onRoomStatusChanged);
      if (mounted) {
        setState(() {
          _matchFoundAnimation = true;
        });

        for (int i = 3; i > 0; i--) {
          if (!mounted) return;
          setState(() {
            _matchCountdown = i;
          });
          await Future.delayed(const Duration(seconds: 1));
        }

        if (!mounted) return;
        setState(() {
          _isSearching = false;
          _matchFoundAnimation = false;
        });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ShutTheBoxScreen()),
        );
      }
    } else if (_activeProvider!.status == 'closed' && !_matchFoundAnimation) {
      _activeProvider!.removeListener(_onRoomStatusChanged);
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إغلاق الغرفة')),
        );
      }
    }
  }

  void _cancelSearch() async {
    if (_activeProvider != null) {
      _activeProvider!.removeListener(_onRoomStatusChanged);
      await _activeProvider!.leaveGame();
    }
    if (mounted) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    if (_activeProvider != null) {
      _activeProvider!.removeListener(_onRoomStatusChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/ludo_purple_bg.png'), // Default background if available
            fit: BoxFit.cover,
          ),
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isSearching ? _buildSearchingView() : _buildSelectionView(),
        ),
      ),
    );
  }

  Widget _buildSelectionView() {
    return Column(
      children: [
        // Top Bar
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.redAccent, size: 24),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 20),

        // Player Selection Cards
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPlayerTab(
              title: "1 مقابل 1",
              icon: Icons.group,
              players: 2,
            ),
            const SizedBox(width: 20),
            _buildPlayerTab(
              title: "4 لاعبين",
              icon: Icons.groups,
              players: 4,
            ),
          ],
        ),

        const SizedBox(height: 40),

        // Bet Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                const Text(
                  'الرهان',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBetButton(
                      icon: Icons.remove,
                      onTap: _decrementBet,
                      enabled: _betOptions.indexOf(_selectedBet) > 0,
                    ),
                    const SizedBox(width: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/coinsmeto.png',
                            width: 24,
                            height: 24,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_selectedBet',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    _buildBetButton(
                      icon: Icons.add,
                      onTap: _incrementBet,
                      enabled: _betOptions.indexOf(_selectedBet) < _betOptions.length - 1,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      '%10 الخبرة',
                      style: TextStyle(color: Colors.amber, fontSize: 14, fontFamily: 'Tajawal'),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.help_outline, color: Colors.grey, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Start Button
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFACC15), // Yellow
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 5,
            ),
            child: const Text(
              'ابدأ',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerTab({
    required String title,
    required IconData icon,
    required int players,
  }) {
    bool isSelected = _selectedPlayers == players;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlayers = players;
        });
      },
      child: Container(
        width: 140,
        height: 120,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0EA5E9).withOpacity(0.2) : const Color(0xFF1E293B).withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0EA5E9) : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0EA5E9).withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 50,
              color: isSelected ? Colors.white : Colors.white54,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0EA5E9) : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBetButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFFACC15) : Colors.grey.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.black,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSearchingView() {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    String opponentName = 'جاري البحث...';
    String? opponentPhoto;

    String localName = currentUser?.displayName ?? 'أنا';
    String? localPhoto = currentUser?.photoURL;

    if (_activeProvider != null) {
      final players = _activeProvider!.players;
      
      // Update local details from provider if available
      if (currentUser != null && players.containsKey(currentUser.uid)) {
        localName = players[currentUser.uid]['name'] ?? localName;
        localPhoto = players[currentUser.uid]['photo'] ?? localPhoto;
      }
      
      if (_matchFoundAnimation) {
        for (var entry in players.entries) {
          if (entry.key != currentUser?.uid) {
            opponentName = entry.value['name'] ?? 'خصم';
            opponentPhoto = entry.value['photo'];
            break;
          }
        }
      }
    }

    return Stack(
      children: [
        // Moon background
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
                      color: Colors.white.withOpacity(0.2),
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

        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Top Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Icon(Icons.image, size: 40, color: Colors.white54),
              ),
              const SizedBox(height: 20),

              // Top Status Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$_selectedBet',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Image.asset(
                            'assets/images/coinsmeto.png',
                            width: 20,
                            height: 20,
                            errorBuilder: (c, e, s) => const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                          ),
                        ],
                      ),
                      Row(
                        children: const [
                          Icon(Icons.emoji_events_outlined, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'الترتيب 1',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 15),
              
              // Entry Coins
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'عملات الدخول ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  Text(
                    '$_selectedBet',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/images/coinsmeto.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (c, e, s) => const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Flags
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
                              angle: -0.3,
                              child: Container(width: 2, height: 300, color: Colors.white12),
                            ),
                            const SizedBox(width: 20),
                            Transform.rotate(
                              angle: 0.3,
                              child: Container(width: 2, height: 300, color: Colors.white12),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // The Banners
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Blue Banner
                        _buildBanner(
                          'assets/images/gams/blu1x.png',
                          Colors.blue,
                          Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (!_matchFoundAnimation)
                                    const SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: CircularProgressIndicator(
                                        color: Colors.cyanAccent,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: _matchFoundAnimation ? Colors.greenAccent : Colors.white10),
                                    ),
                                    child: localPhoto != null
                                        ? ClipOval(
                                            child: Image.network(
                                              localPhoto,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white54, size: 30),
                                            ),
                                          )
                                        : const Icon(Icons.person, color: Colors.white54, size: 30),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                localName,
                                style: TextStyle(
                                  color: _matchFoundAnimation ? Colors.greenAccent : Colors.white54,
                                  fontSize: 14,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Red Banner
                        _buildBanner(
                          'assets/images/gams/red2x.png',
                          Colors.red,
                          Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.redAccent, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent.withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E293B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: _matchFoundAnimation && opponentPhoto != null
                                      ? ClipOval(
                                          child: Image.network(
                                            opponentPhoto,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.blueGrey, size: 40),
                                          ),
                                        )
                                      : const Icon(Icons.person, color: Colors.blueGrey, size: 40),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      opponentName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                    const Text(
                                      'READY',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 10,
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
              ),

              // Bottom texts
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _matchFoundAnimation
                        ? 'تبدأ المباراة خلال $_matchCountdown ثواني... 🎲'
                        : 'جاري البحث عن خصم...',
                    style: TextStyle(
                      color: _matchFoundAnimation ? Colors.amberAccent : Colors.white70,
                      fontSize: _matchFoundAnimation ? 16 : 14,
                      fontWeight: _matchFoundAnimation ? FontWeight.bold : FontWeight.normal,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_matchFoundAnimation)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
                    ),
                ],
              ),
              
              const SizedBox(height: 20),

              if (!_matchFoundAnimation)
                GestureDetector(
                  onTap: _cancelSearch,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 30),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Text(
                      'إلغاء البحث',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                ),
              if (_matchFoundAnimation)
                const SizedBox(height: 70), // Maintain spacing when button is hidden
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBanner(String imagePath, Color themeColor, Widget content) {
    return SizedBox(
      width: 140,
      height: 340,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Image.asset(
            imagePath, 
            width: 140, 
            height: 340, 
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 140,
              height: 340,
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 60),
              content,
            ],
          ),
        ],
      ),
    );
  }
}
