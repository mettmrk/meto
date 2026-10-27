import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart'; // Ensure UserService is imported
import '../models/user_model.dart'
    as model; // Import User model with alias to avoid conflict if any
import '../widgets/level_up_dialog.dart'; // Import the dialog
import 'package:cloud_firestore/cloud_firestore.dart';


import '../widgets/popup_ad_dialog.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'chat_list_screen.dart';

import 'entertainment_screen.dart';
import 'daily_reward_screen.dart';


/// شاشة التطبيق الرئيسية مع قائمة التنقل السفلية
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int? _previousLevel;
  StreamSubscription<model.User?>? _userLevelSubscription;
  bool _hasCheckedPopupAd = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const DailyRewardScreen(), // العداد اليومي
    const ChatListScreen(),
    const EntertainmentScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setPresence(true);
    _initLevelListener();
    _checkPopupAds();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setPresence(false);
    _userLevelSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setPresence(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _setPresence(false);
    }
  }

  void _setPresence(bool isOnline) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      UserService().updatePresence(user.uid, isOnline);
    }
  }

  void _initLevelListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userLevelSubscription = UserService().getUserStream(user.uid).listen((
        userData,
      ) {
        if (!mounted || userData == null) return;

        final currentLevel = userData.level;

        // Initialize previous level if first run
        if (_previousLevel == null) {
          _previousLevel = currentLevel;
          return;
        }

        // Check for level up
        if (currentLevel > _previousLevel!) {
          // Update previous level to new level so dialog doesn't show again for same level
          _previousLevel = currentLevel;

          // Show Dialog
          Future.delayed(Duration.zero, () {
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => LevelUpDialog(newLevel: currentLevel),
              );
            }
          });
        }
      });
    }
  }

  void _checkPopupAds() {
    if (_hasCheckedPopupAd) return;
    _hasCheckedPopupAd = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Query ordered by creation time to avoid composite index error (where + orderBy)
        final snapshot = await FirebaseFirestore.instance
            .collection('popup_ads')
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get();
        
        // Find the first active ad that hasn't expired
        final activeAds = snapshot.docs.where((doc) {
          final data = doc.data();
          if (data['isActive'] != true) return false;
          
          final Timestamp? endDate = data['endDate'] as Timestamp?;
          if (endDate != null) {
            // Check if it's expired
            if (endDate.toDate().isBefore(DateTime.now())) {
              return false; // Expired
            }
          }
          return true; // Active and not expired
        }).toList();
        
        if (activeAds.isNotEmpty) {
          final adDoc = activeAds.first;
          final adData = adDoc.data();

          // Show every time app is opened (per session)
          if (mounted) {
            await Future.delayed(const Duration(milliseconds: 500)); // Small delay to let UI settle
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (context) => PopupAdDialog(adData: adData),
            );
          }
        }

      } catch (e) {
        print('Error checking popup ads: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // لون الخلفية يتطابق مع خلفية كل صفحة لمنع ظهور إطار خلف الزوايا المستديرة
      backgroundColor: _currentIndex == 1
          ? const Color(0xFF021618) // يطابق خلفية صفحة العداد الداكنة
          : _currentIndex == 2
          ? Colors.white
          : _currentIndex == 3
          ? Theme.of(context).primaryColor.withValues(alpha: 0.9)
          : Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: StreamBuilder<int>(
        stream: FirebaseAuth.instance.currentUser != null
            ? ChatService().getTotalUnreadCountStream(
                FirebaseAuth.instance.currentUser!.uid,
              )
            : Stream.value(0),
        initialData: ChatService().cachedTotalUnreadCount,
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;
          return _AnimatedNavBar(
            currentIndex: _currentIndex,
            unreadCount: unreadCount,
            onTap: (index) => setState(() => _currentIndex = index),
            isDarkMode: _currentIndex == 1,
          );
        },
      ),
    );
  }
}

// ─── Custom Animated Bottom Nav Bar ───────────────────────────────────────────
class _AnimatedNavBar extends StatefulWidget {
  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onTap;
  /// عند true يُستخدم تصميم داكن (مناسب لصفحة العداد)
  final bool isDarkMode;

  const _AnimatedNavBar({
    required this.currentIndex,
    required this.unreadCount,
    required this.onTap,
    this.isDarkMode = false,
  });

  @override
  State<_AnimatedNavBar> createState() => _AnimatedNavBarState();
}

class _AnimatedNavBarState extends State<_AnimatedNavBar>
    with TickerProviderStateMixin {
  late AnimationController _indicatorController;
  late Animation<double> _indicatorAnim;

  static const _navItems = [
    _NavItem(
      icon: Icons.home_rounded,
      iconOff: Icons.home_outlined,
      label: 'الرئيسية',
    ),
    _NavItem(icon: Icons.timer, iconOff: Icons.timer_sharp, label: 'العداد'),
    _NavItem(
      icon: Icons.chat_bubble_rounded,
      iconOff: Icons.chat_bubble_outline_rounded,
      label: 'الرسائل',
    ),
    _NavItem(
      icon: Icons.sports_esports_rounded,
      iconOff: Icons.sports_esports_outlined,
      label: 'تسلية',
    ),
    _NavItem(
      icon: Icons.person_rounded,
      iconOff: Icons.person_outline,
      label: 'حسابي',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _indicatorAnim =
        Tween<double>(
          begin: widget.currentIndex.toDouble(),
          end: widget.currentIndex.toDouble(),
        ).animate(
          CurvedAnimation(
            parent: _indicatorController,
            curve: Curves.easeInOutCubic,
          ),
        );
  }

  @override
  void didUpdateWidget(_AnimatedNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      final from = _indicatorAnim.value;
      _indicatorAnim =
          Tween<double>(
            begin: from,
            end: widget.currentIndex.toDouble(),
          ).animate(
            CurvedAnimation(
              parent: _indicatorController,
              curve: Curves.easeInOutCubic,
            ),
          );
      _indicatorController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ألوان متكيفة: داكنة لصفحة العداد، عادية للباقي
    final navBg = widget.isDarkMode
        ? const Color(0xFF062326)
        : Theme.of(context).primaryColor;
    final pillColor = widget.isDarkMode
        ? const Color(0xFF00E5FF).withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.18);
    final topBorder = widget.isDarkMode
        ? Border(
            top: BorderSide(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
              width: 1,
            ),
          )
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: topBorder,
        boxShadow: [
          BoxShadow(
            color: widget.isDarkMode
                ? const Color(0xFF00E5FF).withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / _navItems.length;
              final pillW = itemWidth * 0.62;
              return AnimatedBuilder(
                animation: _indicatorAnim,
                builder: (context, _) {
                  final pillOffset =
                      _indicatorAnim.value * itemWidth +
                      (itemWidth - pillW) / 2;
                  return SizedBox(
                    height: 68,
                    child: Stack(
                      children: [
                        // ── Sliding Pill Indicator ──
                        Positioned(
                          right: pillOffset,
                          top: 8,
                          child: Container(
                            width: pillW,
                            height: 36,
                            decoration: BoxDecoration(
                              color: pillColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),

                        // ── Nav Items ──
                        Positioned.fill(
                          child: Row(
                            children: List.generate(_navItems.length, (index) {
                              final item = _navItems[index];
                              final isSelected = index == widget.currentIndex;
                              return Expanded(
                                child: _NavItemWidget(
                                  item: item,
                                  isSelected: isSelected,
                                  badge: index == 2 && widget.unreadCount > 0
                                      ? widget.unreadCount
                                      : null,
                                  onTap: () => widget.onTap(index),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// بيانات كل عنصر
class _NavItem {
  final IconData icon;
  final IconData iconOff;
  final String label;
  const _NavItem({
    required this.icon,
    required this.iconOff,
    required this.label,
  });
}

// ويدجت كل أيقونة مع أنيميشن مستقل
class _NavItemWidget extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final int? badge;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  State<_NavItemWidget> createState() => _NavItemWidgetState();
}

class _NavItemWidgetState extends State<_NavItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isSelected ? 1.0 : 0.0,
    );
    _scale = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_NavItemWidget old) {
    super.didUpdateWidget(old);
    if (widget.isSelected != old.isSelected) {
      if (widget.isSelected) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.scale(
                scale: _scale.value,
                child: Opacity(
                  opacity: _fade.value,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: EdgeInsets.all(widget.isSelected ? 5 : 0),
                        decoration: widget.isSelected
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF00E5FF),
                                  width: 1.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF).withValues(
                                      alpha: 0.5,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              )
                            : null,
                        child: Icon(
                          widget.isSelected
                              ? widget.item.icon
                              : widget.item.iconOff,
                          color: widget.isSelected
                              ? const Color(0xFF00E5FF)
                              : Colors.white70,
                          size: widget.isSelected ? 22 : 24,
                        ),
                      ),
                      // Badge للرسائل
                      if (widget.badge != null)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              widget.badge! > 9 ? '9+' : '${widget.badge}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: widget.isSelected
                      ? const Color(0xFF00E5FF)
                      : Colors.white.withValues(alpha: 0.6),
                  fontSize: widget.isSelected ? 11.5 : 10.5,
                  fontWeight: widget.isSelected
                      ? FontWeight.bold
                      : FontWeight.w500,
                  fontFamily: 'Tajawal',
                ),
                child: Text(widget.item.label),
              ),
            ],
          );
        },
      ),
    );
  }
}
