// ignore_for_file: deprecated_member_use, duplicate_ignore, unused_import, unused_field

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../services/voice_room_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart'; // Added
import '../services/task_service.dart';
import '../models/index.dart';
// Fixed path
import '../models/task_model.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import '../widgets/gift_selection_bottom_sheet.dart';
import 'package:lottie/lottie.dart';
import '../components/room_sidebar_actions.dart';
import 'store_screen.dart';

import '../widgets/room_info_sheet.dart';
import '../widgets/owner_entrance_banner.dart';
import '../widgets/room_user_list.dart';

import '../widgets/vvip_entrance_animation.dart';
import '../widgets/sticker_selection_bottom_sheet.dart';
import 'package:animated_emoji/animated_emoji.dart';
import '../widgets/reaction_display.dart';
import '../widgets/framed_avatar.dart';
import '../widgets/ambient_background.dart';
import '../widgets/global_gift_banner.dart';
import '../widgets/lottie_gift_animation.dart';
import '../widgets/svga_gift_animation.dart';
import '../widgets/car_adventure_animation.dart';
import '../widgets/vip_video_overlay.dart';
import 'voice_room_screen_menu_methods.dart';
import '../widgets/member_profile_bottom_sheet.dart';
import '../widgets/level_badge.dart';
import '../widgets/room_supporters_sheet.dart';
import '../widgets/marquee_text.dart';

class VoiceRoomScreen extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic>? initialRoomData;
  const VoiceRoomScreen({
    super.key,
    required this.roomId,
    this.initialRoomData,
  });

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late VoiceRoomService _service;
  late AnimationController _shakeController;
  late AnimationController _sparkleController;
  final FocusNode _chatFocusNode = FocusNode(); // Added focus node
  Timer? _shakeTimer;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  Map<String, dynamic>? _replyingTo;
  Timer? _entryNotificationTimer;
  static String? _lastGiftMsgId;
  // For Yalla Ludo style animation
  String? _hostEntranceImageUrl; // For host profile in banner
  // New: For fetching real image
  // 'owner' or 'mod'
  final List<Map<String, dynamic>> _activeEntranceBanners =
      []; // Stackable banners
  // Loading state
  String? _premiumGiftLottieUrl; // For full-screen premium gift animations
  String?
  _specialEntryEffectUrl; // For special shop entry effects (Lottie or Image)
  String? _thousandGiftLottieUrl; // For 1000 gifts special animation
  String? _christmasGiftLottieUrl; // For 51 gifts special animation
  bool _isKeyboardOpen = false; // Track keyboard state for scrolling logic
  // Throttle for entry animations
  static final Set<String> _playedEntranceIds =
      {}; // Track already-triggered entrance animations
  static final Set<String> _playedGiftMsgIds =
      {}; // Track already-triggered gift message animations and popups
  static final Map<String, DateTime> _lastUserEntranceTrigger =
      {}; // Throttle by userId
  String? _vvipNickname; // For professional entry animation
  bool _showVipVideo = false; // For ID 1 special video entrance
  String? _customVipVideoPath; // For dynamic shop video entrances
  final List<Map<String, dynamic>> _activeGiftPopups =
      []; // For concurrent static gift pop-ups

  // In-Room Game Overlay
  String? _activeGameId; // When set, shows TicTacToe overlay inside the room

  // Queue system for full screen gift animations
  final List<Map<String, String>> _giftAnimQueue = [];
  bool _isPlayingGiftAnim = false;

  void _processGiftAnimQueue() {
    if (_isPlayingGiftAnim || _giftAnimQueue.isEmpty) return;

    _isPlayingGiftAnim = true;
    final nextAnim = _giftAnimQueue.removeAt(0);
    final type = nextAnim['type'];
    final url = nextAnim['url'];

    if (mounted) {
      setState(() {
        if (type == 'car') {
          _thousandGiftLottieUrl = url;
        } else if (type == 'vipVideo') {
          _showVipVideo = true;
          _customVipVideoPath = url;
        } else if (type == 'christmas') {
          _christmasGiftLottieUrl = url;
        } else if (type == 'premium') {
          _premiumGiftLottieUrl = url;
        }
      });
    }
  }

  void _onGiftAnimComplete() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _isPlayingGiftAnim = false;
        _processGiftAnimQueue();
      }
    });
  }

  final Map<int, String?> _seatErrors =
      {}; // Track fleeting error messages per seat
  bool _isExiting = false; // Flag to prevent multiple pops
  bool _didSuccessfullyJoin = false; // Track if we ever successfully joined

  // Timer Feature
  bool _showRoomTimer = false;
  int _remainingRoomTime = 0; // in seconds
  Timer? _roomTimer;
  bool _isRoomTimerPaused = false;
  bool _isRoomCountdownMode = false;
  int _roomTimerInitialMs = 0;
  final GlobalKey _timerKey = GlobalKey();

  // Challenge (PK) State
  Map<String, dynamic>? _activeChallenge;
  Timer? _challengeTimer;
  int _challengeRemainingMs = 0;
  bool _showChallengeWinner = false;
  Map<String, dynamic>? _challengeWinnerData;
  Timer? _pkUpdateTimer;
  bool _pkVictoryShown = false;
  bool _isRetrying = false; // Local retry state
  int _retryCountdown = 0; // Countdown for retry
  Timer? _retryTimer;

  Color? _parseColor(dynamic colorVal) {
    if (colorVal == null) return null;
    try {
      final String hex = colorVal.toString();
      return Color(int.parse("0xFF$hex"));
    } catch (e) {
      return null;
    }
  }

  Widget _buildNetworkLostOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.65),
        child: Center(
          child: Container(
            width: 250, // More compact width
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2C2C2C).withOpacity(0.3),
                  const Color(0xFF1E1E1E).withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.redAccent,
                    size: 32, // More balanced icon size
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: const Text(
                    "انقطع الاتصال",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "يرجى التحقق من اتصالك بالإنترنت",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12,
                      fontFamily: 'Tajawal',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Padding(padding: EdgeInsets.only(top: 20)),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          _isExiting = true; // Mark as voluntary exit
                          _retryTimer?.cancel();
                          _service.leaveRoom();
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.3),
                          foregroundColor: Colors.white.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "خروج",
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                        ),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.only(left: 10)),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_isRetrying || _retryCountdown > 0)
                            ? null
                            : () async {
                                setState(() {
                                  _isRetrying = true;
                                  _retryCountdown = 10;
                                });

                                _retryTimer?.cancel();
                                _retryTimer = Timer.periodic(
                                  const Duration(seconds: 1),
                                  (timer) {
                                    if (!mounted) {
                                      timer.cancel();
                                      return;
                                    }
                                    setState(() {
                                      if (_retryCountdown > 0) {
                                        _retryCountdown--;
                                      } else {
                                        _isRetrying = false;
                                        timer.cancel();
                                      }
                                    });
                                  },
                                );

                                try {
                                  await _service.retryConnection();
                                } finally {
                                  if (mounted) {
                                    if (!_service.isNetworkLost) {
                                      _retryTimer?.cancel();
                                      setState(() {
                                        _isRetrying = false;
                                        _retryCountdown = 0;
                                      });
                                    }
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                          disabledBackgroundColor: Colors.white.withOpacity(
                            0.3,
                          ),
                          disabledForegroundColor: Colors.white.withOpacity(
                            0.3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _retryCountdown > 0
                              ? "إعادة ($_retryCountdown)"
                              : "إعادة",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSeatError(int index, String error) {
    if (!mounted) return;
    setState(() => _seatErrors[index] = error);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _seatErrors.remove(index));
      }
    });
  }

  Future<void> _handleExit() async {
    final NavigatorState navigator = Navigator.of(context);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'ExitOverlay',
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (overlayContext, anim1, anim2) {
        return Container(
          color: Colors.black.withOpacity(0.55),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(overlayContext),
                  child: Container(color: Colors.transparent),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildExitOptionButton(
                        icon: Icons.upload_rounded,
                        label: "الاحتفاظ",
                        color: Theme.of(context).primaryColor,
                        onTap: () {
                          _isExiting = true;
                          Navigator.pop(overlayContext);
                          _service.setMinimized(true);
                          navigator.pop();
                        },
                      ),
                      const SizedBox(height: 80),
                      _buildExitOptionButton(
                        icon: Icons.power_settings_new_rounded,
                        label: "خروج",
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        onTap: () {
                          _isExiting = true;
                          // 1. Pop overlay
                          Navigator.pop(overlayContext);
                          // 2. Pop the voice room screen immediately for "instant" feel
                          navigator.pop();
                          // 3. Perform cleanup in the background
                          _service.leaveRoom();
                        },
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
  }

  void _showRoomMenu(Map<String, dynamic> roomData) {
    showRoomMenu(
      context: context,
      service: _service,
      roomId: widget.roomId,
      roomData: roomData,
      onShareTap: _showInviteFriendsSheet,
    );
  }

  void _showInvitationDialog(Map<String, dynamic> invitation) {
    if (!mounted) return;
    final String type = invitation['type'] ?? 'mic';
    final String senderName = invitation['senderName'] ?? "عضو في ميتو";
    final int? seatIndex = invitation['seatIndex'];

    String title = type == 'mic' ? "دعوة للمايك" : "دعوة للانضمام";
    String actionText = type == 'mic'
        ? "دعاك $senderName للصعود على المايك رقم ${seatIndex! + 1}"
        : "دعاك $senderName لتصبح عضواً في الغرفة";

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "InvitationPopup",
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, anim1, anim2) {
        // Auto close timer
        Timer? timer;
        timer = Timer(const Duration(seconds: 15), () {
          if (Navigator.canPop(dialogContext)) {
            Navigator.pop(dialogContext);
          }
        });

        return Center(
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.82,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2A2A2A),
                        const Color(0xFF1A1A1A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (type == 'mic' ? Colors.deepPurple : Colors.teal)
                            .withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: -10,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // Elegant Background Pattern
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                (type == 'mic'
                                        ? Colors.deepPurple
                                        : Colors.teal)
                                    .withOpacity(0.3),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: type == 'mic'
                                      ? [Colors.deepPurple, Colors.indigoAccent]
                                      : [Colors.teal, Colors.cyanAccent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (type == 'mic'
                                                ? Colors.deepPurple
                                                : Colors.teal)
                                            .withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Icon(
                                type == 'mic'
                                    ? Icons.mic_rounded
                                    : Icons.person_add_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              actionText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 15,
                                height: 1.6,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () {
                                      timer?.cancel();
                                      Navigator.pop(dialogContext);
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      "رفض",
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: type == 'mic'
                                          ? Colors.deepPurple
                                          : Colors.teal,
                                      foregroundColor: Colors.white,
                                      elevation: 8,
                                      shadowColor:
                                          (type == 'mic'
                                                  ? Colors.deepPurple
                                                  : Colors.teal)
                                              .withOpacity(0.3),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: () async {
                                      timer?.cancel();
                                      Navigator.pop(dialogContext);
                                      if (type == 'mic') {
                                        try {
                                          await _service.takeSeat(seatIndex!, isInvited: true);
                                        } catch (e) {
                                          _showSeatError(
                                            seatIndex!,
                                            e.toString(),
                                          );
                                        }
                                      } else {
                                        await _service.followRoom(
                                          widget.roomId,
                                          fee: 0,
                                        );
                                      }
                                    },
                                    child: const Text(
                                      "قبول",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Progress Bar at the bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1.0, end: 0.0),
                          duration: const Duration(seconds: 15),
                          builder: (context, value, child) =>
                              LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  (type == 'mic'
                                          ? Colors.deepPurpleAccent
                                          : Colors.tealAccent)
                                      .withOpacity(0.3),
                                ),
                                minHeight: 4,
                              ),
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

  Widget _buildExitOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                // 3D Depth Shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(4, 8),
                  blurRadius: 15,
                ),
                // Glowing Outer Shadow
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                // Inner Highlight for 3D edge
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  offset: const Offset(-4, -4),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ],
              border: Border.all(color: Colors.white24, width: 2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.3), color, color.withAlpha(200)],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: 55,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(2, 4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
              letterSpacing: 1.5,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  offset: Offset(0, 3),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _service = Provider.of<VoiceRoomService>(context, listen: false);

    // SEED: If we have partial room data from the previous screen,
    // use it immediately to prevent a black screen/loading flicker.
    if (widget.initialRoomData != null) {
      _service.seedRoomData(widget.initialRoomData);
    } else {}

    // If returning from minimized state or re-entering, mark all existing messages as played
    // to prevent re-triggering entrance banners/animations for history.
    if (_service.messages.isNotEmpty) {
      final newest = _service.messages.first;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      for (final msg in _service.messages) {
        final ts = msg['timestamp'];
        final String entryId =
            msg['id']?.toString() ??
            msg['localId']?.toString() ??
            "${ts}_${msg['senderId']}";

        bool isMyFreshEntry = false;
        if (msg['senderId'] == _service.currentUserId &&
            (msg['type'] == 'host_enter' ||
                (msg['type'] == 'system' &&
                    msg['text']?.toString().contains('دخل') == true))) {
          if (ts is int && (nowMs - ts) < 5000) {
            isMyFreshEntry = true;
          }
        }

        if (!isMyFreshEntry) {
          _playedEntranceIds.add(entryId);
        }
      }
      final newestTs = newest['timestamp'];
      final String initialId =
          newest['id']?.toString() ??
          newest['localId']?.toString() ??
          "${newestTs}_${newest['senderId']}";

      _lastGiftMsgId = initialId;
    }

    _initRoom();
    WidgetsBinding.instance.addObserver(this);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _shakeTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _shakeController.forward(from: 0);
        _sparkleController.forward(from: 0);
      }
    });

    _service.addListener(_onServiceUpdate);
  }

  Future<void> _initRoom() async {
    try {
      final bool wasJoined =
          _service.isJoined && _service.currentRoomId == widget.roomId;

      await _service.initialize();
      await _service.joinRoom(widget.roomId);

      if (mounted) {
        setState(() {
          _didSuccessfullyJoin = true;
        });

        // مهمة: الانضمام لغرفة صوتية (فقط عند الانضمام الجديد)
        if (!wasJoined && _service.currentUserId != null) {
          TaskService().incrementTaskProgress(
            _service.currentUserId!,
            TaskType.joinRoom,
          );
        }
      }
    } catch (e) {
      debugPrint("Error initializing room: $e");
      if (mounted) {
        final errorMsg = e.toString();

        // Check if the error is due to a ban or kick to show the appropriate dialog instead of a SnackBar
        if (errorMsg.contains('حظرك') || errorMsg.contains('طردك')) {
          _isExiting =
              true; // Mark as exiting to prevent redundant service updates

          final nav = Navigator.of(context);
          if (nav.canPop()) nav.pop();

          _showInvoluntaryExitDialog(
            parentContext: nav.context,
            title: errorMsg.contains('حظرك')
                ? 'لقد تم حظرك من دخول الغرفة'
                : 'لقد تم طردك من الغرفة',
            subtitle: errorMsg.contains('حظرك')
                ? 'تواصل مع مالك الغرفة'
                : 'لقد تم إخراجك من الغرفة من قبل الإدارة/صاحب الغرفة',
            icon: errorMsg.contains('حظرك') ? Icons.block : Icons.error_outline,
          );
        } else {
          // generic error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ في الانضمام: $e'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
            ),
          );
          // If critical init failure, pop back
          _isExiting = true;
          Navigator.of(context).pop();
        }
      }
    }

    // 5. Challenge Sync
    final roomData = _service.currentRoomData;
    final challengeData = roomData?['challenge'] as Map<String, dynamic>?;
    if (challengeData != null && challengeData['isActive'] == true) {
      final startTime = challengeData['startTime'] as Timestamp?;
      final durationMs = challengeData['durationMs'] as int? ?? 0;

      if (startTime != null) {
        int elapsed = DateTime.now()
            .difference(startTime.toDate())
            .inMilliseconds;
        int remaining = durationMs - elapsed;

        if (remaining > 0) {
          if (_activeChallenge == null ||
              _activeChallenge!['isActive'] != true) {
            // New challenge started or joining mid-challenge
            setState(() {
              _activeChallenge = challengeData;
              _challengeRemainingMs = remaining;
            });
            _startLocalChallengeTimer();
          } else {
            // Just update points from service if needed (though we rely on _activeChallenge for UI)
            setState(() => _activeChallenge = challengeData);
          }
        } else {
          // Challenge should have ended
          if (_activeChallenge != null &&
              _activeChallenge!['isActive'] == true) {
            _onChallengeEnd(challengeData);
          }
          setState(() => _activeChallenge = null);
        }
      }
    } else {
      if (_activeChallenge != null) {
        setState(() => _activeChallenge = null);
        _challengeTimer?.cancel();
        _challengeTimer = null;
      }
    }
  }

  void _startLocalChallengeTimer() {
    _challengeTimer?.cancel();
    _challengeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_challengeRemainingMs > 0) {
        setState(() => _challengeRemainingMs -= 1000);
      } else {
        timer.cancel();
        if (_activeChallenge != null) {
          _onChallengeEnd(_activeChallenge!);
        }
      }
    });
  }

  void _onChallengeEnd(Map<String, dynamic> challenge) {
    // Calculate winner
    final points = challenge['points'] as Map<String, dynamic>? ?? {};
    if (points.isEmpty) return;

    String? winnerId;
    int maxPoints = -1;

    points.forEach((uid, p) {
      if (p is int && p > maxPoints) {
        maxPoints = p;
        winnerId = uid;
      }
    });

    if (winnerId != null) {
      // Find winner info
      final seat = _service.seats.firstWhere(
        (s) => s != null && s['userId'] == winnerId,
        orElse: () => null,
      );
      if (seat != null) {
        setState(() {
          _challengeWinnerData = {
            'name': seat['nickname'] ?? seat['username'] ?? 'مجهول',
            'points': maxPoints,
          };
          _showChallengeWinner = true;
        });
      }
    }

    // Stop remotely if we are host
    if (_service.currentUserId == _service.currentRoomData?['hostId']) {
      _service.stopChallenge();
    }
  }

  void _onServiceUpdate() {
    if (!mounted || _isExiting) return;

    // Check if the user was kicked or banned, causing them to leave the room.
    // IMPORTANT: Only trigger this if we actually joined successfully first.
    if (_service.currentRoomId == null && _didSuccessfullyJoin) {
      if (_isExiting)
        return; // Prevent natural exits from showing removal logic
      _isExiting = true;

      if (mounted) {
        final reason = _service.exitReason;
        final nav = Navigator.of(context);

        if (nav.canPop()) {
          nav.pop();
        }

        if (reason == 'kicked') {
          _showInvoluntaryExitDialog(
            parentContext: nav.context,
            title: 'لقد تم طردك من الغرفة',
            subtitle: 'لقد تم إخراجك من قبل الإدارة أو صاحب الغرفة',
            icon: Icons.error_outline,
          );
        } else if (reason == 'banned') {
          _showInvoluntaryExitDialog(
            parentContext: nav.context,
            title: 'لقد تم حظرك من دخول الغرفة',
            subtitle: 'تواصل مع مالك الغرفة لمزيد من التفاصيل',
            icon: Icons.block,
          );
        } else if (reason == 'network_lost') {
          _showInvoluntaryExitDialog(
            parentContext: nav.context,
            title: 'انقطع الاتصال بالإنترنت',
            subtitle:
                'تم إخراجك من الغرفة بسبب فقدان الاتصال بالشبكة. يرجى التحقق من اتصالك والمحاولة مرة أخرى.',
            icon: Icons.wifi_off_rounded,
          );
        } else if (reason == 'ghost') {
          _showInvoluntaryExitDialog(
            parentContext: nav.context,
            title: 'تم قطع الاتصال',
            subtitle: 'تم فقدان تزامن تواجدك في الغرفة. يرجى الدخول مرة أخرى.',
            icon: Icons.sync_problem,
          );
        } else {
          // Fallback for unexpected room closure
          _showInvoluntaryExitDialog(
            parentContext: nav.context,
            title: 'لقد تم إغلاق الغرفة',
            subtitle: 'انتهت الجلسة أو تم إغلاق الغرفة من قبل المالك',
            icon: Icons.info_outline,
          );
        }

        _service.clearExitReason();
      }
      return;
    }

    final roomData = _service.currentRoomData;

    // 5. Challenge Sync (PK Points)
    final challengeData = roomData?['challenge'] as Map<String, dynamic>?;
    if (challengeData != null && challengeData['isActive'] == true) {
      final startTime = challengeData['startTime'] as Timestamp?;
      final durationMs = challengeData['durationMs'] as int? ?? 0;

      if (startTime != null) {
        int elapsed = DateTime.now()
            .difference(startTime.toDate())
            .inMilliseconds;
        int remaining = durationMs - elapsed;

        if (remaining > 0) {
          if (_activeChallenge == null ||
              _activeChallenge!['isActive'] != true) {
            // New challenge started or joining mid-challenge
            setState(() {
              _activeChallenge = challengeData;
              _challengeRemainingMs = remaining;
            });
            _startLocalChallengeTimer();
          } else {
            // Just update points from service conditionally to avoid lag
            final oldPoints = _activeChallenge?['points']?.toString();
            final newPoints = challengeData['points']?.toString();
            if (oldPoints != newPoints) {
              setState(() => _activeChallenge = challengeData);
            } else {
              _activeChallenge = challengeData;
            }
          }
        } else {
          // Challenge should have ended
          if (_activeChallenge != null &&
              _activeChallenge!['isActive'] == true) {
            _onChallengeEnd(challengeData);
          }
          setState(() => _activeChallenge = null);
        }
      }
    } else {
      if (_activeChallenge != null) {
        setState(() => _activeChallenge = null);
        _challengeTimer?.cancel();
        _challengeTimer = null;
      }
    }

    // 4. Timer Sync (Firestore)
    final timerData = roomData?['timer'] as Map<String, dynamic>?;
    if (timerData != null) {
      final status = timerData['status'] as String?;
      final mode = timerData['mode'] as String?;
      final initialMs = timerData['initialMs'] as int? ?? 0;
      final baseMs = timerData['baseMs'] as int? ?? 0;
      final startTimeStamp = timerData['startTime'] as Timestamp?;

      bool remoteIsPaused = status == 'paused';
      bool remoteIsRunning = status == 'running';
      bool remoteIsCountdown = mode == 'countdown';

      if (remoteIsRunning || remoteIsPaused) {
        int currentVal = baseMs;
        if (remoteIsRunning && startTimeStamp != null) {
          int elapsedSinceStart = DateTime.now()
              .difference(startTimeStamp.toDate())
              .inMilliseconds;
          if (remoteIsCountdown) {
            currentVal = baseMs - elapsedSinceStart;
            if (currentVal < 0) currentVal = 0;
          } else {
            currentVal = baseMs + elapsedSinceStart;
            if (currentVal > 3600000) currentVal = 3600000;
          }
        }

        if (!_showRoomTimer ||
            _isRoomTimerPaused != remoteIsPaused ||
            _isRoomCountdownMode != remoteIsCountdown) {
          setState(() {
            _showRoomTimer = true;
            _remainingRoomTime = currentVal;
            _isRoomTimerPaused = remoteIsPaused;
            _isRoomCountdownMode = remoteIsCountdown;
            _roomTimerInitialMs = initialMs;
          });

          if (remoteIsRunning && _roomTimer == null) {
            _roomTimer = Timer.periodic(const Duration(milliseconds: 100), (
              timer,
            ) {
              if (!mounted || !_showRoomTimer || _isRoomTimerPaused) {
                timer.cancel();
                _roomTimer = null;
                return;
              }
              setState(() {
                if (_isRoomCountdownMode) {
                  if (_remainingRoomTime > 0) {
                    _remainingRoomTime -= 100;
                  } else {
                    _remainingRoomTime = 0;
                    _isRoomTimerPaused = true;

                    final canControl =
                        _service.isAdmin(_service.currentUserId ?? '') ||
                        _service.isCoOwner(_service.currentUserId ?? '') ||
                        (_service.currentRoomData?['hostId'] ==
                            _service.currentUserId);
                    if (canControl) {
                      _syncPauseToFirestore(true);
                    }
                  }
                } else {
                  _remainingRoomTime += 100;
                  if (_remainingRoomTime >= 3600000) {
                    _remainingRoomTime = 3600000;
                    _isRoomTimerPaused = true;
                  }
                }
              });
            });
          }
        } else if (_isRoomTimerPaused) {
          if ((_remainingRoomTime - currentVal).abs() > 500) {
            setState(() => _remainingRoomTime = currentVal);
          }
        }
      } else {
        if (_showRoomTimer) {
          setState(() {
            _showRoomTimer = false;
            _roomTimer?.cancel();
            _roomTimer = null;
          });
        }
      }
    } else {
      // If timerData is null, it means the timer was stopped/deleted by owner
      if (_showRoomTimer) {
        setState(() {
          _showRoomTimer = false;
          _roomTimer?.cancel();
          _roomTimer = null;
        });
      }
    }

    if (!mounted) return;

    // 1. Last Invitation Check (Real-time Dialog)
    if (_service.lastInvitation != null) {
      final invitation = Map<String, dynamic>.from(_service.lastInvitation!);
      _service.clearLastInvitation();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showInvitationDialog(invitation);
      });
    }

    // 2. Message Alerts & Entrance Animations
    if (_service.messages.isNotEmpty) {
      final now = DateTime.now();

      final List<Map<String, dynamic>> newBannersToAdd = [];

      for (var rawMsg in _service.messages) {
        final String uid = rawMsg['senderId']?.toString() ?? rawMsg['userId']?.toString() ?? '';
        if (uid.isEmpty) continue;

        final dynamic timestamp = rawMsg['timestamp'];
        final int tsSeconds = (timestamp is int)
            ? (timestamp ~/ 1000)
            : (now.millisecondsSinceEpoch ~/ 1000);
        final String fingerprint = "entry_${uid}_${tsSeconds}";
        final String msgId =
            rawMsg['id']?.toString() ??
            rawMsg['localId']?.toString() ??
            fingerprint;

        if (_playedEntranceIds.contains(msgId) ||
            _playedEntranceIds.contains(fingerprint)) {
          continue;
        }

        // Mark as processed immediately so we don't process it again on the next update
        _playedEntranceIds.add(msgId);
        _playedEntranceIds.add(fingerprint);

        final newestMsg = Map<String, dynamic>.from(rawMsg);
        final text = newestMsg['text'] ?? '';

        bool isFresh = true;
        if (timestamp != null) {
          DateTime? msgTime;
          if (timestamp is Timestamp)
            msgTime = timestamp.toDate();
          else if (timestamp is DateTime)
            msgTime = timestamp;
          else if (timestamp is int)
            msgTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          if (msgTime != null && now.difference(msgTime).inSeconds.abs() > 30)
            isFresh = false;
        }
        if (!isFresh) continue;

        if (rawMsg == _service.messages.first) {
          final pkMatchSync = roomData?['pkMatch'] as Map<String, dynamic>?;
          if (pkMatchSync == null || pkMatchSync['isActive'] != true) {
            if (_pkVictoryShown) setState(() => _pkVictoryShown = false);
          }
        }

        final bool isEntryEvent =
            newestMsg['type'] == 'host_enter' ||
            (newestMsg['type'] == 'system' && text.contains('دخل'));
        final bool isVVIP =
            newestMsg['senderDisplayId']?.toString() == "1" && isEntryEvent;
        final String? entryEffect = newestMsg['roomEntrance'];

        if (isEntryEvent || (entryEffect != null && entryEffect.isNotEmpty)) {
          final bool isMe = uid == _service.currentUserId;
          if (!isMe &&
              _lastUserEntranceTrigger.containsKey(uid) &&
              now.difference(_lastUserEntranceTrigger[uid]!).inSeconds < 15) {
            _playedEntranceIds.add(fingerprint);
            _playedEntranceIds.add(msgId);
            continue;
          }

          _playedEntranceIds.add(msgId);
          _playedEntranceIds.add(fingerprint);
          _lastUserEntranceTrigger[uid] = now;

          final String? rHostId =
              roomData?['hostId'] ??
              _service.hostId ??
              _service.currentRoomData?['hostId'];
          final bool isOwner =
              uid == rHostId ||
              (uid == _service.currentUserId && _service.isHost);
          final bool isMod = _service.isModerator(uid);
          final bool isDeputy = _service.isCoOwner(uid);

          if (entryEffect != null && entryEffect.isNotEmpty) {
            final bool isVideo = entryEffect.toLowerCase().endsWith('.mp4');
            setState(() {
              _vvipNickname =
                  newestMsg['senderName'] ??
                  newestMsg['senderNickname'] ??
                  text.split(' دخل')[0];
              _hostEntranceImageUrl =
                  newestMsg['imageUrl'] ?? newestMsg['photoURL'];
              if (isVideo) {
                _customVipVideoPath = entryEffect;
                _showVipVideo = true;
              } else {
                _specialEntryEffectUrl = entryEffect;
              }
            });
          } else if (isVVIP) {
            setState(() {
              _showVipVideo = true;
              _vvipNickname =
                  newestMsg['senderName'] ??
                  newestMsg['senderNickname'] ??
                  text.split(' دخل')[0];
              _hostEntranceImageUrl =
                  newestMsg['imageUrl'] ?? newestMsg['photoURL'];
            });
          } else if (isOwner || isMod || isDeputy) {
            bool alreadyInStack =
                _activeEntranceBanners.any((b) => b['userId'] == uid) ||
                newBannersToAdd.any((b) => b['userId'] == uid);
            if (!alreadyInStack) {
              double topOffset = 240.0;
              for (int i = 0; i < 5; i++) {
                double candidate = 240.0 + (i * 60.0);
                bool occupied =
                    _activeEntranceBanners.any((b) => b['top'] == candidate) ||
                    newBannersToAdd.any((b) => b['top'] == candidate);
                if (!occupied) {
                  topOffset = candidate;
                  break;
                }
              }
              String? manualFrame = uid.isNotEmpty
                  ? _service.getActiveFrameForUser(uid)
                  : null;
              newBannersToAdd.add({
                'id': fingerprint,
                'text': text,
                'userId': uid,
                'imageUrl': newestMsg['imageUrl'] ?? newestMsg['photoURL'],
                'bannerType': isOwner ? 'owner' : (isMod ? 'mod' : 'deputy'),
                'manualFrame': manualFrame,
                'top': topOffset,
              });
            }
          }
        }

        final String msgKey =
            newestMsg['id']?.toString() ??
            newestMsg['localId']?.toString() ??
            fingerprint;
        if (newestMsg['type'] == 'gift' &&
            !_playedGiftMsgIds.contains(msgKey) &&
            isFresh) {
          _playedGiftMsgIds.add(msgKey);
          setState(() {
            _lastGiftMsgId = msgKey;
            final int price = newestMsg['price'] ?? 0;
            final int quantity = newestMsg['quantity'] ?? 1;
            final String? giftName = newestMsg['giftName'];
            final String? imageUrl =
                newestMsg['giftImage'] ?? newestMsg['imageUrl'];
            final bool hasAnimation =
                (newestMsg['lottieUrl'] != null &&
                newestMsg['lottieUrl'].toString().isNotEmpty);

            if (!hasAnimation &&
                ![
                  'نمر',
                  'النمر',
                  'ببغاء صغير',
                  'الببغاء الصغير',
                  'طاووس',
                  'الطاووس',
                  'صقر',
                  'الصقر',
                ].contains(giftName)) {
              final String uniqueKeyVal =
                  '${msgKey}_${DateTime.now().microsecondsSinceEpoch}';
              _activeGiftPopups.add({
                'id': msgKey,
                'uniqueKey': uniqueKeyVal,
                'imageUrl': imageUrl,
                'senderName': newestMsg['senderName'],
                'receiverName': newestMsg['receiverName'],
                'giftName': giftName,
                'quantity': quantity,
              });
            }
            if (giftName == 'السيارة الكلاسيكية') {
              _giftAnimQueue.add({
                'type': 'car',
                'url': "assets/lottie/car_adventure.json",
              });
            } else if (['نمر', 'النمر'].contains(giftName)) {
              _giftAnimQueue.add({
                'type': 'vipVideo',
                'url': "assets/videos/nmer.mp4",
              });
            } else if (giftName == 'شجرة الكريسماس') {
              _giftAnimQueue.add({
                'type': 'christmas',
                'url': "assets/lottie/christmas_tree.json",
              });
            } else {
              final String? msgLottieUrl = newestMsg['lottieUrl'];
              if (msgLottieUrl != null && msgLottieUrl.isNotEmpty) {
                _giftAnimQueue.add({'type': 'premium', 'url': msgLottieUrl});
              } else if (imageUrl == null || imageUrl.isEmpty) {
                final url = (price >= 500)
                    ? "assets/lottie/Money.json"
                    : "assets/lottie/Fireworks.json";
                _giftAnimQueue.add({'type': 'premium', 'url': url});
              }
            }
            _processGiftAnimQueue();
          });
        }
      }

      if (newBannersToAdd.isNotEmpty) {
        setState(() {
          _activeEntranceBanners.addAll(newBannersToAdd);
          if (_activeEntranceBanners.length > 5) {
            _activeEntranceBanners.removeRange(
              0,
              _activeEntranceBanners.length - 5,
            );
          }
        });
      }

      // Auto-scroll to bottom for new messages
      if (mounted && _chatScrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted &&
              _chatScrollController.hasClients &&
              _chatScrollController.positions.length == 1) {
            _chatScrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  void _showInvoluntaryExitDialog({
    required BuildContext parentContext,
    required String title,
    String? subtitle,
    required IconData icon,
  }) {
    showDialog(
      context: parentContext,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.redAccent, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 14,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'حسنًا',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMention(String nickname) {
    if (!mounted) return;
    setState(() {
      final String currentText = _chatController.text;
      String prefix = currentText;
      if (currentText.isNotEmpty && !currentText.endsWith(' ')) {
        prefix += ' ';
      }
      _chatController.text = "$prefix@$nickname ";
      _chatController.selection = TextSelection.fromPosition(
        TextPosition(offset: _chatController.text.length),
      );
    });
    _chatFocusNode.requestFocus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_service.isMinimized) {
      _service.leaveRoom();
    }
    _service.removeListener(_onServiceUpdate);
    _chatController.dispose();
    _chatScrollController.dispose();
    _shakeController.dispose();
    _sparkleController.dispose();
    _shakeTimer?.cancel();
    _entryNotificationTimer?.cancel();
    _chatFocusNode.dispose(); // Dispose focus node
    _retryTimer?.cancel();
    _roomTimer?.cancel();
    super.dispose();
  }

  void _startRoomTimer({
    bool isCountdown = false,
    int initialMs = 0,
    int? resumeMs,
  }) {
    // Permission Check: only host, admin or co-owner (Deputy)
    if (!_service.isAdmin(_service.currentUserId ?? '') &&
        !_service.isCoOwner(_service.currentUserId ?? '') &&
        !(_service.currentRoomData?['hostId'] == _service.currentUserId)) {
      return;
    }

    if (resumeMs == null) {
      _service.updateRoomTimer({
        'mode': isCountdown ? 'countdown' : 'stopwatch',
        'status': 'running',
        'initialMs': initialMs,
        'baseMs': isCountdown ? initialMs : 0,
        'startTime': FieldValue.serverTimestamp(),
      });
    }

    _stopRoomTimer(updateFirestore: false);
    setState(() {
      _remainingRoomTime = resumeMs ?? (isCountdown ? initialMs : 0);
      _roomTimerInitialMs = initialMs;
      _isRoomCountdownMode = isCountdown;
      _showRoomTimer = true;
      _isRoomTimerPaused = false;
    });

    _roomTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isRoomTimerPaused) return;

      setState(() {
        if (_isRoomCountdownMode) {
          if (_remainingRoomTime > 0) {
            _remainingRoomTime -= 100;
          } else {
            _remainingRoomTime = 0;
            _isRoomTimerPaused = true;

            final canControl =
                _service.isAdmin(_service.currentUserId ?? '') ||
                _service.isCoOwner(_service.currentUserId ?? '') ||
                (_service.currentRoomData?['hostId'] == _service.currentUserId);
            if (canControl) {
              _syncPauseToFirestore(true);
            }
          }
        } else {
          _remainingRoomTime += 100;
          if (_remainingRoomTime >= 3600000) {
            _remainingRoomTime = 0;
            _showRoomTimer = false;
            _isRoomTimerPaused = true;
            timer.cancel();
            _roomTimer = null;
          }
        }
      });
    });
  }

  void _syncPauseToFirestore(bool isPaused) {
    if (_remainingRoomTime < 0) _remainingRoomTime = 0;
    _service.updateRoomTimer({
      'mode': _isRoomCountdownMode ? 'countdown' : 'stopwatch',
      'status': isPaused ? 'paused' : 'running',
      'initialMs': _roomTimerInitialMs,
      'baseMs': _remainingRoomTime,
      'startTime': isPaused ? null : FieldValue.serverTimestamp(),
    });
  }

  void _showChallengeSelectionDialog({required bool isPK}) {
    int selectedDuration = 5;
    String selectedPKMode = "2v2";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 350,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF008080), Color(0xFF004D4D)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 20,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF66CCCC),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                      Text(
                        isPK ? "بدء مباراة PK" : "بدء تحدي الهدايا",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const Icon(Icons.help_outline, color: Colors.white),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "المدة",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 20),
                // Timer grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [5, 10, 15, 20, 25, 30, 60, 120].map((mins) {
                      bool isSelected = selectedDuration == mins;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedDuration = mins),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.cyan : Colors.white12,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.white24,
                            ),
                          ),
                          child: Text(
                            "$mins من الدقائق",
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (isPK) ...[
                  const SizedBox(height: 25),
                  const Text(
                    "النمط",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ["1v1", "2v2", "4v4"].map((mode) {
                        bool isSelected = selectedPKMode == mode;
                        final int roomLevel =
                            (_service.currentRoomData?['roomLevel'] ?? 1)
                                as int;
                        bool isLocked = mode == "4v4" && roomLevel < 10;

                        return GestureDetector(
                          onTap: () {
                            if (isLocked) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "نمط 4v4 متاح فقط للغرف من المستوى 10 فما فوق",
                                    style: TextStyle(fontFamily: 'Tajawal'),
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }
                            setDialogState(() => selectedPKMode = mode);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isLocked
                                  ? Colors.grey.withOpacity(0.2)
                                  : (isSelected ? Colors.cyan : Colors.white12),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: isLocked
                                    ? Colors.grey.withOpacity(0.3)
                                    : (isSelected
                                          ? Colors.white
                                          : Colors.white24),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isLocked) ...[
                                  const Icon(
                                    Icons.lock,
                                    size: 14,
                                    color: Colors.white54,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  mode,
                                  style: TextStyle(
                                    color: isLocked
                                        ? Colors.white38
                                        : (isSelected
                                              ? Colors.black
                                              : Colors.white70),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                // Start Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 25),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      if (isPK) {
                        _service.startPKMatch(
                          selectedDuration,
                          mode: selectedPKMode,
                        );
                      } else {
                        _service.startChallenge(selectedDuration);
                      }
                    },
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "ابدأ",
                          style: TextStyle(
                            color: Color(0xFF4D3300),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeTimerOverlay(Map<String, dynamic>? roomData) {
    if (roomData == null) return const SizedBox.shrink();
    final challenge = roomData['challenge'] as Map<String, dynamic>?;
    if (challenge == null || challenge['isActive'] != true) {
      return const SizedBox.shrink();
    }

    final startTime = challenge['startTime'] as Timestamp?;
    if (startTime == null) return const SizedBox.shrink();

    final durationMs = challenge['durationMs'] as int? ?? 0;
    int elapsed = DateTime.now().difference(startTime.toDate()).inMilliseconds;
    int remaining = durationMs - elapsed;

    if (remaining <= 0) return const SizedBox.shrink();

    final String currentUid = _service.currentUserId ?? "";
    final bool canStopChallenge =
        currentUid == (roomData['hostId'] ?? "") ||
        ((_service.isAdmin(currentUid) || _service.isCoOwner(currentUid)) &&
            roomData['adminCanControlGames'] == true);

    return Positioned(
      left: _service.challengePosition.dx,
      top: _service.challengePosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _service.updateChallengePosition(
              Offset(
                _service.challengePosition.dx + details.delta.dx,
                _service.challengePosition.dy + details.delta.dy,
              ),
            );
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.military_tech_rounded,
                    color: Colors.orangeAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "PK: ${_formatChallengeDuration(remaining)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Tajawal',
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (canStopChallenge)
              Positioned(
                top: -8,
                right: -8,
                child: GestureDetector(
                  onTap: () => _service.stopChallenge(),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatChallengeDuration(int ms) {
    if (ms < 0) ms = 0;
    // Round up the seconds so that 5 minutes starts as 05:00 instead of 04:59
    int totalSec = (ms + 999) ~/ 1000;
    int mins = totalSec ~/ 60;
    int secs = totalSec % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  Widget _buildWinnerOverlay() {
    if (!_showChallengeWinner || _challengeWinnerData == null)
      return const SizedBox.shrink();

    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutExpo,
        builder: (context, val, child) {
          return Opacity(
            opacity: val,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: val == 0.0 ? 0.1 : 10 * val,
                sigmaY: val == 0.0 ? 0.1 : 10 * val,
              ),
              child: Container(
                color: Colors.black.withOpacity(0.6 * val),
                child: Center(
                  child: Transform.scale(
                    scale: 0.8 + (0.2 * val),
                    child: _buildVictoryCard(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVictoryCard() {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.2),
            blurRadius: 50,
            spreadRadius: 10,
          ),
          BoxShadow(
            color: const Color(0xFFFF8C00).withOpacity(0.1),
            blurRadius: 100,
            spreadRadius: 20,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Background Card
          Container(
            padding: const EdgeInsets.fromLTRB(30, 70, 30, 30),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(35),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A0845), Color(0xFF6441A5)],
              ),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFFDF00),
                      Color(0xFFD4AF37),
                      Color(0xFFFFDF00),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ).createShader(bounds),
                  child: const Text(
                    "مبروك الفوز!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Tajawal',
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "الفائز بالمركز الأول",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 25),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _challengeWinnerData!['name'] ?? "غير معروف",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars_rounded,
                            color: Color(0xFFFFD700),
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${_challengeWinnerData!['points']} نقطة",
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 35),
                GestureDetector(
                  onTap: () => setState(() => _showChallengeWinner = false),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF8C00).withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "استمرار",
                        style: TextStyle(
                          color: Color(0xFF3E2723),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Trophy
          Positioned(
            top: -65,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.8),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFFFD700),
                      size: 130,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPKVictoryDialog(int bluePoints, int redPoints) {
    if (!mounted || _pkVictoryShown) return;
    _pkVictoryShown = true;

    String winnerText;
    bool isBlueWinner = bluePoints > redPoints;
    bool isRedWinner = redPoints > bluePoints;
    bool isDraw = bluePoints == redPoints;

    if (isBlueWinner) {
      winnerText = "انتصار الفريق الأزرق!";
    } else if (isRedWinner) {
      winnerText = "انتصار الفريق الأحمر!";
    } else {
      winnerText = "تعادل الفريقين!";
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'PKVictory',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: Material(
              color: Colors.transparent,
              child: Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
                  // Main Card
                  Container(
                    width: MediaQuery.of(ctx).size.width * 0.9,
                    margin: const EdgeInsets.only(top: 60),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1021),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "انتهاء التحدي",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                          const SizedBox(height: 5),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFFFFDF00),
                                Color(0xFFD4AF37),
                                Color(0xFFFFDF00),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(bounds),
                            child: Text(
                              winnerText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),

                          // Golden Divider
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 2,
                                width: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.amber.withOpacity(0.8),
                                    ],
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(
                                  Icons.waves,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                              ),
                              Container(
                                height: 2,
                                width: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 25),

                          // Teams Container with Tech Border
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Red Team (Left)
                                Expanded(
                                  child: _buildNewVictoryTeamBox(
                                    teamName: "الفريق الاحمر",
                                    teamLabel: "",
                                    points: redPoints,
                                    isWinner: isRedWinner,
                                    isRed: true,
                                  ),
                                ),
                                // Center Arrow
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Icon(
                                    isDraw
                                        ? Icons.pause_rounded
                                        : (isBlueWinner
                                              ? Icons.chevron_left_rounded
                                              : Icons.chevron_right_rounded),
                                    color: const Color(0xFFFFD700),
                                    size: 45,
                                  ),
                                ),
                                // Blue Team (Right)
                                Expanded(
                                  child: _buildNewVictoryTeamBox(
                                    teamName: "الفريق الازرق",
                                    teamLabel: "",
                                    points: bluePoints,
                                    isWinner: isBlueWinner,
                                    isRed: false,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Close Button
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              width: double.infinity,
                              height: 55,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF9C27B0),
                                    Color(0xFFE91E63),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Text(
                                    "إغلاق",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                  Positioned(
                                    right: 15,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top Right Profile & Diamond
                  Positioned(
                    top: 80,
                    right: 25,
                    child: Row(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[800],
                            border: Border.all(
                              color: const Color(0xFFFFD700),
                              width: 2,
                            ),
                          ),
                          child: Stack(
                            children: [
                              const Center(
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 0),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFFFD700),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    "1",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF1976D2),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.diamond,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Top Left Pink Diamond
                  Positioned(
                    top: 80,
                    left: 25,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE91E63),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.diamond,
                        color: Colors.pinkAccent,
                        size: 20,
                      ),
                    ),
                  ),

                  // Top Center Trophy
                  Positioned(
                    top: -10,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0B1021),
                        border: Border.all(
                          color: const Color(0xFFFFD700),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Image.asset(
                          'assets/images/trophy_3d.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (_service.currentRoomData?['hostId'] == _service.currentUserId) {
      Future.delayed(const Duration(seconds: 12), () {
        if (mounted && _pkVictoryShown) {
          _service.stopPKMatch();
        }
      });
    }
  }

  Widget _buildCornerGem(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)],
      ),
      child: const Icon(Icons.diamond, color: Colors.white, size: 12),
    );
  }

  Widget _buildNewVictoryTeamBox({
    required String teamName,
    required String teamLabel,
    required int points,
    required bool isWinner,
    required bool isRed,
  }) {
    final primaryColor = isRed
        ? const Color(0xFF8B0000)
        : const Color(0xFF00008B);
    final borderColor = isRed
        ? const Color(0xFFFFD700)
        : const Color(0xFF4FC3F7);
    final iconColor = isRed ? Colors.pinkAccent : Colors.blueAccent;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 15),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isWinner ? 2.5 : 1.5),
            boxShadow: isWinner
                ? [
                    BoxShadow(
                      color: borderColor.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Text(
                teamName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 18),
              Icon(
                Icons.diamond_rounded,
                color: iconColor,
                size: 45,
                shadows: [
                  Shadow(color: iconColor.withOpacity(0.8), blurRadius: 10),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                "$points",
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                teamLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFamily: 'Tajawal',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (isWinner)
          Positioned(
            top: -5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Color(0xFFFFD700),
                  size: 45,
                ),
                Positioned(
                  top: 12,
                  child: Text(
                    "1",
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _stopRoomTimer({bool updateFirestore = true}) {
    _roomTimer?.cancel();
    _roomTimer = null;
    if (mounted) {
      setState(() {
        _showRoomTimer = false;
        _remainingRoomTime = 0;
      });
    }
    if (updateFirestore) {
      _service.updateRoomTimer(null);
    }
  }

  void _showTimerModeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "اختر نوع المؤقت",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: _buildTimerModeButton(
                    "ساعة ايقاف",
                    Icons.timer_outlined,
                    Colors.cyanAccent,
                    () {
                      Navigator.pop(context);
                      _startRoomTimer(isCountdown: false);
                    },
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildTimerModeButton(
                    "مؤقت تنازلي",
                    Icons.hourglass_bottom_rounded,
                    Colors.orangeAccent,
                    () {
                      Navigator.pop(context);
                      _showCountdownPicker(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerModeButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCountdownPicker(BuildContext context) {
    int selectedMinutes = 5;
    int selectedSeconds = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "تحديد الوقت",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTimeSpinner(
                        "دقائق",
                        selectedMinutes,
                        59,
                        (val) => setModalState(() => selectedMinutes = val),
                      ),
                      const Text(
                        ":",
                        style: TextStyle(color: Colors.white, fontSize: 30),
                      ),
                      _buildTimeSpinner(
                        "ثواني",
                        selectedSeconds,
                        59,
                        (val) => setModalState(() => selectedSeconds = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        int totalMs =
                            (selectedMinutes * 60 + selectedSeconds) * 1000;
                        if (totalMs > 0) {
                          _startRoomTimer(
                            isCountdown: true,
                            initialMs: totalMs,
                          );
                        }
                      },
                      child: const Text(
                        "بدء",
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

  Widget _buildTimeSpinner(
    String label,
    int value,
    int max,
    Function(int) onChanged,
  ) {
    return Column(
      children: [
        IconButton(
          onPressed: () => onChanged(value < max ? value + 1 : 0),
          icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white54),
        ),
        Container(
          width: 60,
          alignment: Alignment.center,
          child: Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(value > 0 ? value - 1 : max),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  String _formatTimerDuration(int totalMs) {
    int deciseconds =
        (totalMs % 1000) ~/ 100; // Get the 1/10th of a second digit
    int totalSeconds = totalMs ~/ 1000;
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;

    String hoursStr = hours > 0 ? "${hours.toString().padLeft(2, '0')}:" : "";
    String baseTime =
        "$hoursStr${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

    // Only add fractions of seconds for Stopwatch mode
    if (!_isRoomCountdownMode) {
      return "$baseTime.$deciseconds";
    }
    return baseTime;
  }

  Widget _buildDraggableRoomTimer() {
    if (!_showRoomTimer) return const SizedBox.shrink();

    return Positioned(
      left: _service.roomTimerPosition.dx,
      top: _service.roomTimerPosition.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          final screenSize = MediaQuery.of(context).size;
          final safeAreaTop = MediaQuery.of(context).padding.top;

          // Get the actual dynamic size of the timer card
          double cardWidth = 140.0; // Default fallback
          double cardHeight = 45.0; // Default fallback
          final RenderBox? renderBox =
              _timerKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            cardWidth = renderBox.size.width;
            cardHeight = renderBox.size.height;
          }

          setState(() {
            double newX = (_service.roomTimerPosition.dx + details.delta.dx)
                .clamp(0.0, screenSize.width - cardWidth);
            double newY = (_service.roomTimerPosition.dy + details.delta.dy)
                .clamp(safeAreaTop, screenSize.height - cardHeight);
            _service.updateRoomTimerPosition(Offset(newX, newY));
          });
        },
        child: Container(key: _timerKey, child: _buildTimerContent()),
      ),
    );
  }

  Widget _buildTimerContent() {
    final bool canControl =
        _service.currentUserId == (_service.currentRoomData?['hostId'] ?? "") ||
        _service.isAdmin(_service.currentUserId ?? "") ||
        _service.isCoOwner(_service.currentUserId ?? "");

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.cyanAccent.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canControl)
            GestureDetector(
              onTap: () {
                if (!_isRoomTimerPaused) {
                  // If running, "Pause" it
                  _syncPauseToFirestore(true);
                  // Optionally, we don't reset when pausing, we just pause.
                  // The previous code reset it to initialMs which acts like "Stop"
                  // but user asked for Play/Pause.
                  // We'll just pause it where it is:
                } else {
                  // If stopped/paused, "Play" it (Start counting)
                  if (_isRoomCountdownMode && _remainingRoomTime <= 0) {
                    _remainingRoomTime = _roomTimerInitialMs;
                  }
                  _syncPauseToFirestore(false);
                }
              },
              child: Icon(
                !_isRoomTimerPaused
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.cyanAccent,
                size: 20,
              ),
            ),
          if (canControl) const SizedBox(width: 8),
          Text(
            _formatTimerDuration(_remainingRoomTime),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          if (canControl) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                _stopRoomTimer();
              },
              child: const Icon(
                Icons.close_rounded,
                color: Colors.redAccent,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _service.leaveRoom();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Check keyboard status using View.of(context) which is the modern way
    // Note: In some setups View.of(context) might need a valid context.
    // Since we are in a State<StatefulWidget>, context is available if mounted.
    if (!mounted) return;

    final bottom = View.of(context).viewInsets.bottom;
    final isVisible = bottom > 0;

    if (_isKeyboardOpen != isVisible) {
      _isKeyboardOpen = isVisible;
      if (!isVisible) {
        // Scroll to the end of the history immediately when the keyboard is closed
        _scrollToBottom(instant: true);
      } else {
        // Also scroll when keyboard opens to keep newest messages visible
        _scrollToBottom(instant: true);
      }
    }
  }

  void _scrollToBottom({bool instant = false}) {
    if (_chatScrollController.hasClients) {
      // With reverse: true, offset 0 is already the bottom (natively pinned)
      void doScroll() {
        if (_chatScrollController.hasClients &&
            _chatScrollController.positions.length == 1) {
          if (instant) {
            _chatScrollController.jumpTo(0);
          } else {
            // Only animate to 0 if the user is already near the bottom
            if (_chatScrollController.offset < 200) {
              _chatScrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          }
        }
      }

      // Immediate attempt
      WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());

      // Secondary attempt for animation safety
      if (instant) {
        Future.delayed(const Duration(milliseconds: 100), doScroll);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<VoiceRoomService>();

    // Safety Guard: Only use service data if it belongs to the current roomId
    final bool isServiceForThisRoom = service.currentRoomId == widget.roomId;
    final roomData = isServiceForThisRoom
        ? (service.currentRoomData ?? widget.initialRoomData)
        : widget.initialRoomData;

    // Resolve URL for permanent background
    final rawId =
        (roomData?['backgroundId'] ?? roomData?['roomBackground']) as String?;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        _isExiting = true;
        await _handleExit();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // 1. Permanent Background Layer
              Positioned.fill(child: _buildPermanentBackground(rawId)),

              // 2. Main Content
              _buildRoomContent(service),

              // Draggable Timer Overlay
              _buildDraggableRoomTimer(),

              // Challenge (PK) Overlays
              _buildChallengeTimerOverlay(roomData),
              _buildWinnerOverlay(),

              // Eye Care Filter Overlay (Highest Z-index)
              if (service.eyeCareEnabled)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.3),
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

  Widget _buildRoomContent(VoiceRoomService service) {
    return GestureDetector(
      onTap: () {
        _chatFocusNode.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
        // Force hide keyboard to prevent "standby" issues
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      },
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // 3. Ambient Particles (Liveness)
          Selector<VoiceRoomService, bool>(
            selector: (_, s) => s.showAmbientBubbles,
            builder: (_, show, __) => show
                ? const Positioned.fill(child: AmbientBackground())
                : const SizedBox.shrink(),
          ),

          // Main Content
          Selector<VoiceRoomService, Map<String, dynamic>?>(
            selector: (_, s) => s.currentRoomData,
            builder: (context, roomData, _) {
              final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
              final bool isKeyboardVisible = keyboardHeight > 50;

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(bottom: keyboardHeight),
                  child: Column(
                    children: [
                      // --- TOP BAR (FIXED) ---
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        crossFadeState: isKeyboardVisible
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 1. RIGHT SIDE: Header Card & Badges (First in RTL)
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildHeaderProfileCard(
                                      service,
                                      roomData ?? {'name': '...'},
                                      widget.roomId,
                                    ),
                                    _buildRoomBadges(roomData),
                                  ],
                                ),
                              ),

                              // 2. LEFT SIDE: Control Buttons (Second in RTL)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildHeaderIconButton(
                                    icon: Icons.more_horiz_rounded,
                                    onPressed: () {
                                      if (roomData != null) {
                                        _showRoomMenu(roomData);
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildHeaderIconButton(
                                    icon: Icons.power_settings_new_rounded,
                                    onPressed: _handleExit,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- ROOM CONTENT (FIXED AREA) ---
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 300),
                            crossFadeState: isKeyboardVisible
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Row(
                                children: [
                                  // RIGHT: Trophy Wealth (Index 0 is Right in RTL)
                                  _buildTrophyIcon(roomData ?? {'wealth': 0}),

                                  const Spacer(),

                                  // LEFT GROUP: Thumbnails + Online Badge (Index 1 is Left in RTL)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      RoomUserList(onMention: _handleMention),
                                      const SizedBox(width: 8),
                                      _buildVerticalOnlineBadge(service),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            clipBehavior: Clip.none,
                            child: isKeyboardVisible
                                ? const SizedBox.shrink()
                                : _buildDynamicLayout(
                                    context,
                                    service,
                                    roomData,
                                    isKeyboardVisible,
                                  ),
                          ),
                        ],
                      ),

                      // Global Gift Banner (Fixed below chairs)
                      GlobalGiftBanner(
                        onGlobalVideoReceived: (url) {
                          if (mounted) {
                            setState(() {
                              _giftAnimQueue.add({
                                'type': 'premium',
                                'url': url,
                              });
                              _processGiftAnimQueue();
                            });
                          }
                        },
                      ),

                      // --- SCROLLABLE CHAT AREA (Integrated Flow) ---
                      Expanded(
                        child: Column(
                          children: [
                            _buildPinnedAnnouncement(roomData?['announcement']),
                            Expanded(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Builder(
                                  builder: (context) {
                                    final rawMessages = service.messages;
                                    final filteredMessages = rawMessages
                                        .where(
                                          (m) =>
                                              m['type'] != 'host_enter' &&
                                              // Only filter out System messages that are "leaving"
                                              !(m['type'] == 'system' &&
                                                  (m['text']
                                                          ?.toString()
                                                          .contains('خرج') ??
                                                      false)),
                                        )
                                        .toList();

                                    final String? motto = roomData?['notice'];

                                    return ListView.builder(
                                      reverse:
                                          true, // Native pinning: newest stays pinned at offset 0
                                      controller: _chatScrollController,
                                      shrinkWrap:
                                          true, // Crucial for top-start alignment when list is short
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        8,
                                        14,
                                        110,
                                      ),
                                      // The Motto is now at the END of our reversed list (TOP of the UI)
                                      itemCount: filteredMessages.length + 2,
                                      itemBuilder: (context, index) {
                                        // --- SPECIAL ITEMS AT THE TOP (Highest indices in reverse: true) ---

                                        // 1. MeTo Standard Message (Fixed at the very top)
                                        if (index ==
                                            filteredMessages.length + 1) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: _buildNoticeBox(
                                              text:
                                                  'مرحباً بك في MeTo، يرجى احترام بعضنا البعض والدردشة بطريقة لائقة تليق بالمجتمع.',
                                              color: const Color(0xFF35ABA1),
                                              title: 'MeTo',
                                            ),
                                          );
                                        }

                                        // 2. Owner's Room Announcement (Below MeTo)
                                        if (index == filteredMessages.length) {
                                          if (motto == null || motto.isEmpty) {
                                            return const SizedBox.shrink();
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: _buildNoticeBox(
                                              text: motto,
                                              color: const Color(0xFF6B43AB),
                                              title:
                                                  roomData?['noticeTitle'] ??
                                                  'إعلان الغرفة',
                                            ),
                                          );
                                        }

                                        // Messages start from index 0 (Newest at index 0, which is BOTTOM in reverse: true)
                                        return _buildChatMessageItem(
                                          filteredMessages[index],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- BOTTOM BAR ---
                      _buildBottomControlBar(
                        service,
                        isKeyboardVisible,
                        roomData,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Premium Gift Full Screen Overlay
          if (_premiumGiftLottieUrl != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.85,
                child: _premiumGiftLottieUrl!.toLowerCase().contains('.svga')
                    ? SVGAGiftAnimation(
                        svgaUrl: _premiumGiftLottieUrl!,
                        onComplete: () {
                          if (mounted) {
                            setState(() => _premiumGiftLottieUrl = null);
                            _onGiftAnimComplete();
                          }
                        },
                      )
                    : _premiumGiftLottieUrl!.toLowerCase().contains('.mp4')
                    ? VipVideoOverlay(
                        videoPath: _premiumGiftLottieUrl!,
                        onFinished: () {
                          if (mounted) {
                            setState(() => _premiumGiftLottieUrl = null);
                            _onGiftAnimComplete();
                          }
                        },
                      )
                    : FullScreenLottieGift(
                        lottieUrl: _premiumGiftLottieUrl!,
                        onComplete: () {
                          if (mounted) {
                            setState(() => _premiumGiftLottieUrl = null);
                            _onGiftAnimComplete();
                          }
                        },
                      ),
              ),
            ),

          // Special User Entrance Effect (Lottie or Image)
          if (_specialEntryEffectUrl != null)
            Opacity(
              opacity: 0.85,
              child: VVIPEntranceAnimation(
                lottieUrl: _specialEntryEffectUrl!,
                imageUrl:
                    _hostEntranceImageUrl ??
                    'assets/images/user_placeholder.png',
                name: _vvipNickname ?? 'عضو VIP',
                onComplete: () {
                  if (mounted) {
                    setState(() {
                      _specialEntryEffectUrl = null;
                      _vvipNickname = null;
                    });
                  }
                },
              ),
            ),

          // Car Adventure Animation (Classic Car Gift)
          if (_thousandGiftLottieUrl != null)
            CarAdventureAnimation(
              onComplete: () {
                if (mounted) {
                  setState(() => _thousandGiftLottieUrl = null);
                  _onGiftAnimComplete();
                }
              },
            ),

          // 51 Gifts Special Animation (Christmas Tree)
          if (_christmasGiftLottieUrl != null)
            Positioned.fill(
              child: _christmasGiftLottieUrl!.toLowerCase().contains('.svga')
                  ? SVGAGiftAnimation(
                      svgaUrl: _christmasGiftLottieUrl!,
                      onComplete: () {
                        if (mounted) {
                          setState(() => _christmasGiftLottieUrl = null);
                          _onGiftAnimComplete();
                        }
                      },
                    )
                  : _christmasGiftLottieUrl!.toLowerCase().contains('.mp4')
                  ? VipVideoOverlay(
                      videoPath: _christmasGiftLottieUrl!,
                      onFinished: () {
                        if (mounted) {
                          setState(() => _christmasGiftLottieUrl = null);
                          _onGiftAnimComplete();
                        }
                      },
                    )
                  : FullScreenLottieGift(
                      lottieUrl: _christmasGiftLottieUrl!,
                      onComplete: () {
                        if (mounted) {
                          setState(() => _christmasGiftLottieUrl = null);
                          _onGiftAnimComplete();
                        }
                      },
                    ),
            ),

          // Owner/Host Entrance Banner (Stacked Overlays)
          ..._activeEntranceBanners.asMap().entries.map((entry) {
            final Map<String, dynamic> banner = entry.value;
            return Positioned(
              top: banner['top'] ?? 240.0, // Use the stored fixed slot position
              left: 0,
              right: 0,
              child: OwnerEntranceBanner(
                key: ValueKey(banner['id']),
                text: banner['text'],
                userId: banner['userId'],
                imageUrl: banner['imageUrl'],
                bannerType: banner['bannerType'],
                manualFrame: banner['manualFrame'],
                onDismiss: () {
                  if (mounted) {
                    setState(() {
                      _activeEntranceBanners.removeWhere(
                        (b) => b['id'] == banner['id'],
                      );
                    });
                  }
                },
              ),
            );
          }).toList(),

          // --- LEFT SIDEBAR ICONS (REFACTORED) ---
          Positioned(
            left: 16,
            bottom: 100,
            child: RoomSidebarActions(
              roomId: widget.roomId,
              onShowMessages: () => _showRoomMessagesSheet(context),
            ),
          ),

          // --- VVIP Video Entrance Overlay ---
          if (_showVipVideo)
            Positioned.fill(
              child: Opacity(
                opacity: 0.8, // Slightly more transparent for full-screen video
                child: VipVideoOverlay(
                  videoPath: _customVipVideoPath ?? 'assets/videos/tsjel.mp4',
                  onFinished: () {
                    if (mounted) {
                      setState(() {
                        _showVipVideo = false;
                        _customVipVideoPath = null;
                      });
                      _onGiftAnimComplete();
                    }
                  },
                ),
              ),
            ),

          // Static Gift Pop-ups (Concurrent pooled rendering)
          ..._activeGiftPopups.asMap().entries.map((entry) {
            final int index = entry.key;
            final Map<String, dynamic> gift = entry.value;

            // Stagger them slightly if multiple appear at once
            final double staggerY = (index % 5) * 40.0;
            final double staggerX = (index % 3) * 20.0 - 20.0;

            return _StaticGiftPopUp(
              key: ValueKey(gift['uniqueKey'] ?? gift['id']),
              imageUrl: gift['imageUrl'],
              senderName: gift['senderName'],
              receiverName: gift['receiverName'],
              giftName: gift['giftName'],
              quantity: gift['quantity'],
              offset: Offset(staggerX, staggerY),
              onComplete: () {
                if (mounted) {
                  setState(() {
                    _activeGiftPopups.removeWhere(
                      (g) =>
                          (g['uniqueKey'] ?? g['id']) ==
                          (gift['uniqueKey'] ?? gift['id']),
                    );
                  });
                }
              },
            );
          }).toList(),

          // ─── In-Room Game Overlay (TicTacToe) ───
          if (_activeGameId != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // absorb taps so room stays alive
                child: Container(
                  color: Colors.black.withOpacity(0.75),
                  child: Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.92,
                      height: MediaQuery.of(context).size.height * 0.72,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Connection Lost Overlay (Rendered last to be on top of everything)
          Selector<VoiceRoomService, bool>(
            selector: (_, s) => s.isNetworkLost,
            builder: (_, isLost, __) =>
                isLost ? _buildNetworkLostOverlay() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // --- UI HELPER METHODS ---

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildVerticalOnlineBadge(VoiceRoomService service) {
    return GestureDetector(
      onTap: () =>
          RoomUserList.showOnlineUsers(context, onMention: _handleMention),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, color: Colors.white70, size: 11),
            const SizedBox(height: 2),
            Text(
              '${service.viewerCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                height: 1.1,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomBadges(Map<String, dynamic>? roomData) {
    if (roomData == null) return const SizedBox.shrink();

    // Support multiple fields for badging (string or list of strings)
    List<String> badges = [];

    if (roomData['roomBadge'] != null &&
        roomData['roomBadge'].toString().isNotEmpty) {
      badges.add(roomData['roomBadge'].toString());
    } else if (roomData['roomBadges'] is List) {
      badges.addAll(List<String>.from(roomData['roomBadges']));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4.0, right: 6.0),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: badges.map((badgeUrl) {
          return Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                badgeUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeaderProfileCard(
    VoiceRoomService service,
    Map<String, dynamic> roomData,
    String roomId,
  ) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => RoomInfoSheet(
            roomData: roomData,
            service: service,
            roomId: roomId,
            hostId: roomData['hostId'] ?? '',
          ),
        );
      },
      child: Container(
        height: 52,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Right: Avatar (Index 0 is Right in RTL)
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.5),
                child:
                    (roomData['imageUrl'] != null &&
                        roomData['imageUrl'].toString().isNotEmpty)
                    ? Image.network(roomData['imageUrl'], fit: BoxFit.cover)
                    : Image.asset(
                        'assets/images/user_placeholder.png',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(width: 8),

            // 2. Middle: Name & ID (Left of Avatar in RTL)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<User?>(
                    stream:
                        (roomData['hostId'] != null &&
                            roomData['hostId'].toString().isNotEmpty)
                        ? UserService().getUserStream(roomData['hostId'])
                        : Stream.value(null),
                    builder: (context, userSnapshot) {
                      final user = userSnapshot.data;
                      final String displayName =
                          roomData['name'] ?? user?.nickname ?? 'غرفة صوتية';
                      return MarqueeText(
                        text: displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                          height: 1.2,
                        ),
                      );
                    },
                  ),
                  StreamBuilder<User?>(
                    stream:
                        (roomData['hostId'] != null &&
                            roomData['hostId'].toString().isNotEmpty)
                        ? UserService().getUserStream(roomData['hostId'])
                        : Stream.value(null),
                    builder: (context, userSnapshot) {
                      final user = userSnapshot.data;
                      final displayId = roomData['displayId'] ?? user?.displayId ?? '...';
                      return Text(
                        'ID: $displayId',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontFamily: 'Tajawal',
                          height: 1.2,
                        ),
                        textScaler: TextScaler.noScaling,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // 3. Left: Star Icon or Join Button (Index 2 is Left in RTL)
            StreamBuilder<bool>(
              stream: service.isRoomMemberStream(roomId),
              builder: (context, snapshot) {
                final isMember = snapshot.data ?? false;
                final bool isHost = service.currentUserId == roomData['hostId'];

                if (isMember || isHost) {
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.stars,
                      color: Colors.amber,
                      size: 18,
                    ),
                  );
                } else {
                  return GestureDetector(
                    onTap: () async {
                      final int fee = roomData['entranceFee'] ?? 0;
                      try {
                        await service.followRoom(roomId, fee: fee);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00FFD1), Color(0xFF00A3FF)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FFD1).withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Text(
                        "انضمام",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                          height: 1.1,
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrophyIcon(Map<String, dynamic> roomData) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => RoomSupportersSheet(roomId: widget.roomId),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0EA5E9).withOpacity(0.3),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.diamond_rounded,
              color: Color(0xFF00E5FF),
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              '${roomData['wealth'] ?? 0}',
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/trophy_3d.png',
              height: 22,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicLayout(
    BuildContext context,
    VoiceRoomService service,
    Map<String, dynamic>? roomData,
    bool isKeyboardVisible,
  ) {
    // 1. Get the layout type. Strict preference for roomData from DB
    String? layoutType = roomData?['micLayoutType'] ?? service.micLayoutType;

    // Force PK layout if PK match is active
    final pkMatch = roomData?['pkMatch'] as Map<String, dynamic>?;
    if (pkMatch != null && pkMatch['isActive'] == true) {
      layoutType = 'layout_pk';
    }

    // 2. Prevent flicker: If we don't know the layout yet, don't show any seats.
    // This stops the app from showing 5 seats prematurely.
    if (layoutType == null) {
      return const SizedBox(
        height: 120,
      ); // Placeholder to maintain layout stability
    }

    final int roomLevel = roomData?['roomLevel'] ?? roomData?['level'] ?? 1;
    final bool isHighLevel = roomLevel >= 2 || (service.seats.length > 5);

    if (!isHighLevel && layoutType.startsWith('layout_10')) {
      layoutType = 'layout_10_grid';
    }

    switch (layoutType) {
      case 'layout_pk':
        return _buildPKLayout(context, service, roomData, isKeyboardVisible);
      case 'layout_2':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _buildSeatByIndex(
                  context,
                  service,
                  roomData,
                  0,
                  isKeyboardVisible,
                ),
              ),
              const SizedBox(width: 40),
              Flexible(
                child: _buildSeatByIndex(
                  context,
                  service,
                  roomData,
                  1,
                  isKeyboardVisible,
                ),
              ),
            ],
          ),
        );
      case 'layout_5':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              5,
              (index) => Flexible(
                child: _buildSeatByIndex(
                  context,
                  service,
                  roomData,
                  index,
                  isKeyboardVisible,
                ),
              ),
            ),
          ),
        );
      case 'layout_10_pyramid':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Column(
            children: [
              // Row 1: 2 mics
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: _buildSeatByIndex(
                      context,
                      service,
                      roomData,
                      0,
                      isKeyboardVisible,
                    ),
                  ),
                  const SizedBox(width: 30),
                  Flexible(
                    child: _buildSeatByIndex(
                      context,
                      service,
                      roomData,
                      1,
                      isKeyboardVisible,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Row 2: 4 mics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  4,
                  (index) => Flexible(
                    child: _buildSeatByIndex(
                      context,
                      service,
                      roomData,
                      index + 2,
                      isKeyboardVisible,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Row 3: 4 mics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  4,
                  (index) => Flexible(
                    child: _buildSeatByIndex(
                      context,
                      service,
                      roomData,
                      index + 6,
                      isKeyboardVisible,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      case 'layout_10_grid':
      default:
        // Organized Layout (5 or 10 Seats depending on level)
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: Column(
            children: [
              // Top Row: 5 Seats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  5,
                  (index) => Flexible(
                    child: _buildSeatByIndex(
                      context,
                      service,
                      roomData,
                      index,
                      isKeyboardVisible,
                    ),
                  ),
                ),
              ),
              if (isHighLevel) ...[
                const SizedBox(height: 15),
                // Bottom Row: 5 Seats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    5,
                    (index) => Flexible(
                      child: _buildSeatByIndex(
                        context,
                        service,
                        roomData,
                        index + 5,
                        isKeyboardVisible,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }

  Future<void> _showMembershipJoinDialog(
    BuildContext context,
    VoiceRoomService service,
    Map<String, dynamic>? roomData,
    String roomId,
    int seatIndex,
  ) async {
    final int fee = roomData?['entranceFee'] ?? 0;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "JoinMembership",
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F3D2E), Color(0xFF071F18)],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LevelBadge(
                    level: (roomData != null ? roomData['roomLevel'] : 1) ?? 1,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "انضم لعضوية الغرفة",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "يجب أن تكون عضواً في الغرفة لتتمكن من الصعود على المايك",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (fee > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.diamond_outlined,
                            color: Colors.cyanAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "رسوم الانضمام: $fee ماسة",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "إلغاء",
                            style: TextStyle(
                              color: Colors.white38,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7DCD9D),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            try {
                              Navigator.pop(context);
                              await service.followRoom(roomId, fee: fee);
                              try {
                                await service.takeSeat(seatIndex);
                              } catch (e) {
                                _showSeatError(seatIndex, e.toString());
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      e.toString(),
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(
                            "انضم الآن",
                            style: const TextStyle(
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
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSeatOptionsForAdmin(
    BuildContext context,
    VoiceRoomService service,
    Map<String, dynamic>? roomData,
    int index,
    bool isLocked,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xE6101920), // Elegant Dark Translucent
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: const Color(
                0xFF00FFD1,
              ).withOpacity(0.4), // Glowing teal border
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FFD1).withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Take Mic / Sit here
              if (!isLocked)
                _buildModernDialogAction(
                  label: "أخذ المايك",
                  icon: Icons.mic_none_rounded,
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await service.takeSeat(index);
                    } catch (e) {
                      _showSeatError(index, e.toString());
                    }
                  },
                ),
              if (!isLocked)
                Divider(height: 1, color: Colors.white.withOpacity(0.05)),

              // 2. Lock / Unlock
              _buildModernDialogAction(
                label: isLocked ? "فتح المايك" : "قفل المايك",
                icon: isLocked
                    ? Icons.lock_open_rounded
                    : Icons.lock_outline_rounded,
                onTap: () async {
                  Navigator.pop(context);
                  await service.toggleSeatLock(index);
                },
              ),

              // 3. Invite (Only if not locked and perm check)
              if (!isLocked &&
                  (service.currentUserId == roomData?['hostId'] ||
                      roomData?['adminCanInviteUsers'] == true))
                Divider(height: 1, color: Colors.white.withOpacity(0.05)),
              if (!isLocked &&
                  (service.currentUserId == roomData?['hostId'] ||
                      roomData?['adminCanInviteUsers'] == true))
                _buildModernDialogAction(
                  label: "الدعوة للمايك",
                  icon: Icons.interpreter_mode_rounded,
                  onTap: () {
                    Navigator.pop(context);
                    _showMemberInvitePicker(context, service, index);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDialogAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center, // Centering the whole block
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 50,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FFD1).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00FFD1).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: const Color(0xFF00FFD1), size: 24),
                ),
              ),
            ),
            const SizedBox(width: 15),
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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

  Future<void> _showMemberInvitePicker(
    BuildContext context,
    VoiceRoomService service,
    int seatIndex,
  ) async {
    final List<User> candidates = service.roomUsers
        .where((u) => u.uid != service.currentUserId)
        .toList();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "MemberPicker",
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.84,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 25,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_search_rounded,
                      color: Colors.blueAccent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "دعوة صديق للمايك",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      "اختر عضواً للانضمام على المايك",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: candidates.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Text(
                              "لا يوجد أعضاء متصلون حالياً",
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 14,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: candidates.length,
                            itemBuilder: (context, idx) {
                              final user = candidates[idx];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.blueAccent.withOpacity(
                                          0.3,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: FramedAvatar(
                                      userId: user.uid,
                                      imageUrl: user.profileImage,
                                      radius: 20,
                                      disableFrame: true,
                                    ),
                                  ),
                                  title: Text(
                                    user.nickname ?? user.username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: Colors.blueAccent,
                                    size: 22,
                                  ),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    await service.inviteToSeat(
                                      user.uid,
                                      seatIndex,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "إلغاء",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 16,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPKLayout(
    BuildContext context,
    VoiceRoomService service,
    Map<String, dynamic>? roomData,
    bool isKeyboardVisible,
  ) {
    final pkMatch = roomData?['pkMatch'] as Map<String, dynamic>?;
    final bool isPkActive = pkMatch?['isActive'] == true;

    // Start real-time update timer if active and not running
    if (isPkActive && (_pkUpdateTimer == null || !_pkUpdateTimer!.isActive)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pkUpdateTimer?.cancel();
        _pkUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            // Check for PK end condition
            final pkMatchData =
                _service.currentRoomData?['pkMatch'] as Map<String, dynamic>?;
            if (pkMatchData != null && pkMatchData['isActive'] == true) {
              final startTime = pkMatchData['startTime'] as Timestamp?;
              final durationMs = pkMatchData['durationMs'] as int? ?? 0;
              if (startTime != null) {
                final elapsed = DateTime.now()
                    .difference(startTime.toDate())
                    .inMilliseconds;
                if (elapsed >= durationMs && !_pkVictoryShown) {
                  final String mode = pkMatchData['mode'] ?? "2v2";
                  final pts =
                      pkMatchData['points'] as Map<String, dynamic>? ?? {};
                  String? getUidLocal(int idx) {
                    if (idx < _service.seats.length) {
                      return _service.seats[idx]?['userId']?.toString();
                    }
                    return null;
                  }

                  int getPtsLocal(String? uid) {
                    if (uid != null && pts.containsKey(uid)) {
                      return (pts[uid] ?? 0) as int;
                    }
                    return 0;
                  }

                  int bluePts = 0;
                  int redPts = 0;

                  if (mode == "1v1") {
                    bluePts = getPtsLocal(getUidLocal(1));
                    redPts = getPtsLocal(getUidLocal(5));
                  } else if (mode == "2v2") {
                    bluePts =
                        getPtsLocal(getUidLocal(1)) +
                        getPtsLocal(getUidLocal(2));
                    redPts =
                        getPtsLocal(getUidLocal(5)) +
                        getPtsLocal(getUidLocal(6));
                  } else {
                    // 4v4
                    bluePts =
                        getPtsLocal(getUidLocal(1)) +
                        getPtsLocal(getUidLocal(2)) +
                        getPtsLocal(getUidLocal(3)) +
                        getPtsLocal(getUidLocal(4));
                    redPts =
                        getPtsLocal(getUidLocal(5)) +
                        getPtsLocal(getUidLocal(6)) +
                        getPtsLocal(getUidLocal(7)) +
                        getPtsLocal(getUidLocal(8));
                  }

                  _showPKVictoryDialog(bluePts, redPts);
                }
              }
            }
            setState(() {});
          } else {
            timer.cancel();
          }
        });
      });
    } else if (!isPkActive && _pkUpdateTimer != null) {
      _pkUpdateTimer?.cancel();
      _pkUpdateTimer = null;
    }

    final points = pkMatch?['points'] as Map<String, dynamic>? ?? {};

    String? getUid(int idx) {
      if (idx < service.seats.length) {
        return service.seats[idx]?['userId']?.toString();
      }
      return null;
    }

    final String mode = (pkMatch?['mode'] as String?) ?? "2v2";
    int getPoints(String? uid) =>
        (uid != null && points.containsKey(uid)) ? (points[uid] ?? 0) : 0;

    int pointsLeft = 0;
    int pointsRight = 0;

    if (mode == "1v1") {
      pointsLeft = getPoints(getUid(1));
      pointsRight = getPoints(getUid(5));
    } else if (mode == "2v2") {
      pointsLeft = getPoints(getUid(1)) + getPoints(getUid(2));
      pointsRight = getPoints(getUid(5)) + getPoints(getUid(6));
    } else {
      // 4v4
      pointsLeft =
          getPoints(getUid(1)) +
          getPoints(getUid(2)) +
          getPoints(getUid(3)) +
          getPoints(getUid(4));
      pointsRight =
          getPoints(getUid(5)) +
          getPoints(getUid(6)) +
          getPoints(getUid(7)) +
          getPoints(getUid(8));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.withOpacity(0.3), Colors.red.withOpacity(0.3)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Row 1: Referee (الحكم)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: _buildSeatByIndex(
                    context,
                    service,
                    roomData,
                    0,
                    isKeyboardVisible,
                    pkColor: Colors.amber,
                    customSeatShape: 'image:michakam',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: Teams
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Left Team
                Expanded(
                  child: _buildPKTeamContainer(
                    context,
                    service,
                    roomData,
                    isKeyboardVisible,
                    mode: mode,
                    isLeft: true,
                    points: pointsLeft,
                  ),
                ),
                const SizedBox(width: 12),
                // Right Team
                Expanded(
                  child: _buildPKTeamContainer(
                    context,
                    service,
                    roomData,
                    isKeyboardVisible,
                    mode: mode,
                    isLeft: false,
                    points: pointsRight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Row 3: All Supporters Row (Above Bar)
            _buildPKSupportersTopRow(pkMatch),
            const SizedBox(height: 8),
            // Row 4: Supporters Bar (شريط الداعمين)
            _buildPKSupportersBar(pointsLeft, pointsRight, pkMatch),
            const SizedBox(height: 8),
            // Row 5: Top 3 Supporters for Each Team (Below Bar)
            _buildPKTopThreeSupportersRow(pkMatch),
          ],
        ),
      ),
    );
  }

  Widget _buildPKTeamContainer(
    BuildContext context,
    VoiceRoomService service,
    Map<String, dynamic>? roomData,
    bool isKeyboardVisible, {
    required String mode,
    required bool isLeft,
    required int points,
  }) {
    final List<int> seatIndices = [];
    if (mode == "1v1") {
      seatIndices.add(isLeft ? 1 : 5);
    } else if (mode == "2v2") {
      if (isLeft) {
        seatIndices.addAll([1, 2]);
      } else {
        seatIndices.addAll([5, 6]);
      }
    } else {
      // 4v4
      if (isLeft) {
        seatIndices.addAll([1, 2, 3, 4]);
      } else {
        seatIndices.addAll([5, 6, 7, 8]);
      }
    }

    final Color teamColor = isLeft ? Colors.blueAccent : Colors.redAccent;
    final String shapePrefix = isLeft ? 'micbluue' : 'micreed';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [teamColor.withOpacity(0.3), teamColor.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: teamColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          // Seats Grid/Row based on mode
          if (mode == "4v4")
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPKSeat(
                      context,
                      service,
                      roomData,
                      seatIndices[0],
                      isKeyboardVisible,
                      teamColor,
                      shapePrefix,
                    ),
                    const SizedBox(width: 4),
                    _buildPKSeat(
                      context,
                      service,
                      roomData,
                      seatIndices[1],
                      isKeyboardVisible,
                      teamColor,
                      shapePrefix,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPKSeat(
                      context,
                      service,
                      roomData,
                      seatIndices[2],
                      isKeyboardVisible,
                      teamColor,
                      shapePrefix,
                    ),
                    const SizedBox(width: 4),
                    _buildPKSeat(
                      context,
                      service,
                      roomData,
                      seatIndices[3],
                      isKeyboardVisible,
                      teamColor,
                      shapePrefix,
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: seatIndices
                  .map(
                    (idx) => _buildPKSeat(
                      context,
                      service,
                      roomData,
                      idx,
                      isKeyboardVisible,
                      teamColor,
                      shapePrefix,
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: teamColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "$points",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPKSeat(
    BuildContext context,
    VoiceRoomService service,
    Map<String, dynamic>? roomData,
    int index,
    bool isKeyboardVisible,
    Color color,
    String shape,
  ) {
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: _buildSeatByIndex(
          context,
          service,
          roomData,
          index,
          isKeyboardVisible,
          pkColor: color,
          customSeatShape: 'image:$shape',
        ),
      ),
    );
  }

  Widget _buildPKSupportersTopRow(Map<String, dynamic>? pkMatch) {
    final leftSupporters =
        pkMatch?['leftSupporters'] as Map<String, dynamic>? ?? {};
    final rightSupporters =
        pkMatch?['rightSupporters'] as Map<String, dynamic>? ?? {};

    // Combine all unique supporters
    final Map<String, String> allSupporters = {};
    leftSupporters.forEach((uid, img) => allSupporters[uid] = img.toString());
    rightSupporters.forEach((uid, img) => allSupporters[uid] = img.toString());

    if (allSupporters.isEmpty) return const SizedBox(height: 40);

    // Order by total contribution (sum of points from both sides)
    final leftPoints =
        pkMatch?['leftSupporterPoints'] as Map<String, dynamic>? ?? {};
    final rightPoints =
        pkMatch?['rightSupporterPoints'] as Map<String, dynamic>? ?? {};

    final List<String> sortedUids = allSupporters.keys.toList();
    sortedUids.sort((a, b) {
      final int ptsA =
          ((leftPoints[a] ?? 0) as num).toInt() +
          ((rightPoints[a] ?? 0) as num).toInt();
      final int ptsB =
          ((leftPoints[b] ?? 0) as num).toInt() +
          ((rightPoints[b] ?? 0) as num).toInt();
      return ptsB.compareTo(ptsA);
    });

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sortedUids.length,
        itemBuilder: (context, index) {
          final String uid = sortedUids[index];
          final String? img = allSupporters[uid];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: (img != null && img.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: img,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(color: Colors.grey),
                        errorWidget: (c, u, e) => Container(color: Colors.grey),
                      )
                    : Container(color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPKTopThreeSupportersRow(Map<String, dynamic>? pkMatch) {
    final leftPoints =
        pkMatch?['leftSupporterPoints'] as Map<String, dynamic>? ?? {};
    final rightPoints =
        pkMatch?['rightSupporterPoints'] as Map<String, dynamic>? ?? {};
    final leftAvatars =
        pkMatch?['leftSupporters'] as Map<String, dynamic>? ?? {};
    final rightAvatars =
        pkMatch?['rightSupporters'] as Map<String, dynamic>? ?? {};

    List<MapEntry<String, int>> getTop3(Map<String, dynamic> pts) {
      final list = pts.entries
          .map((e) => MapEntry(e.key, (e.value as num).toInt()))
          .toList();
      list.sort((a, b) => b.value.compareTo(a.value));
      return list.take(3).toList();
    }

    final top3Left = getTop3(leftPoints);
    final top3Right = getTop3(rightPoints);

    return Row(
      children: [
        // Left Top 3
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: top3Left.asMap().entries.map((entry) {
                final int index = entry.key;
                final supporter = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildRankedSupporterAvatar(
                    index + 1,
                    leftAvatars[supporter.key]?.toString(),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Spacer(),
        // Right Top 3
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: top3Right.asMap().entries.map((entry) {
                final int index = entry.key;
                final supporter = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildRankedSupporterAvatar(
                    index + 1,
                    rightAvatars[supporter.key]?.toString(),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankedSupporterAvatar(int rank, String? imageUrl) {
    Color rankColor;
    String rankLabel;
    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        rankLabel = "MVP";
        break;
      case 2:
        rankColor = Colors.blueGrey.shade200;
        rankLabel = "2";
        break;
      case 3:
        rankColor = Colors.brown.shade300;
        rankLabel = "3";
        break;
      default:
        rankColor = Colors.white;
        rankLabel = "";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer Frame / Glow
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    rankColor.withOpacity(0.3),
                    rankColor,
                    rankColor.withOpacity(0.3),
                  ],
                ),
              ),
            ),
            // Avatar
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.black26),
                        errorWidget: (c, u, e) => Image.asset(
                          'assets/images/user_placeholder.png',
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        'assets/images/user_placeholder.png',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            // Crown / Rank Badge
            Positioned(
              top: -8,
              child: rank == 1
                  ? const Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 18,
                    )
                  : Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: rankColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        rankLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPKSupportersBar(
    int left,
    int right,
    Map<String, dynamic>? pkMatch,
  ) {
    final int total = left + right;
    final double leftRatio = (total == 0) ? 0.5 : right / total; // Red ratio

    // Calculate Remaining Time
    String timeStr = "00:00";
    bool isWarning = false;
    int remainingSec = 0;

    if (pkMatch != null) {
      final startTime = pkMatch['startTime'] as Timestamp?;
      final durationMs = pkMatch['durationMs'] as int? ?? 0;
      if (startTime != null) {
        final elapsed = DateTime.now()
            .difference(startTime.toDate())
            .inMilliseconds;
        remainingSec = ((durationMs - elapsed) / 1000).floor();
        if (remainingSec < 0) remainingSec = 0;

        if (remainingSec <= 10 && remainingSec > 0) {
          isWarning = true;
        }

        final m = (remainingSec ~/ 60).toString().padLeft(2, '0');
        final s = (remainingSec % 60).toString().padLeft(2, '0');
        timeStr = "$m:$s";
      }
    }

    final double blinkOpacity = isWarning
        ? (0.6 +
              0.4 *
                  math.sin(
                    DateTime.now().millisecondsSinceEpoch * math.pi / 500,
                  ))
        : 1.0;

    // Force LTR for this bar to ensure Left/Right logic is absolute
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Right Side Base (Blue)
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
                  ),
                ),
              ),
              // Left Side Fill (Red)
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 500),
                widthFactor: leftRatio,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFFF5252)],
                    ),
                  ),
                ),
              ),
              // Points Red (On the Left side)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.diamond_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$right",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Points Blue (On the Right side)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Row(
                    children: [
                      Text(
                        "$left",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.diamond_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
              // Center Divider / Timer
              Align(
                alignment: Alignment.center,
                child: Opacity(
                  opacity: blinkOpacity,
                  child: Container(
                    width: 45,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isWarning
                          ? Colors.red.withOpacity(0.2)
                          : Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isWarning
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        width: isWarning ? 1.5 : 1,
                      ),
                      boxShadow: isWarning
                          ? [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        timeStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
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

  Widget _buildSeatByIndex(
    BuildContext context,
    VoiceRoomService service,
    Map<String, dynamic>? roomData,
    int index,
    bool isKeyboardVisible, {
    Color? pkColor,
    String? customSeatShape,
  }) {
    if (index >= service.seats.length) return const SizedBox.shrink();
    final seat = service.seats[index];

    final String? seatUserId = seat?['userId'];
    final bool isUserOnline = (seatUserId == null)
        ? false
        : ((seatUserId == service.currentUserId && !service.isNetworkLost) ||
              service.roomUsers.any((u) => u.uid == seatUserId));

    if (seat != null && seatUserId != null && isUserOnline) {
      final bool isMe = seatUserId == service.currentUserId;
      final bool isTalking = service.isUserTalking(seatUserId);
      final bool isActualHost =
          roomData != null && seatUserId == roomData['hostId'];
      return GestureDetector(
        onTap: () {
          if (isMe) {
            _showMySeatOptions(context, service);
          } else {
            _showMemberProfile(
              context,
              service,
              seat['userId'],
              seat['name'],
              seat['avatar'],
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildSeatItem(
            isMe: isMe,
            isHost: isActualHost,
            isTalking: isTalking,
            name: seat['name'],
            isEmpty: false,
            avatarUrl: seat['avatar'],
            seatIndex: index + 1,
            userId: seat['userId'],
            displayId: seat['displayId'],
            displayIdImage: seat['displayIdImage'],
            frames: service.activeFrames,
            frame: seat['frame'],
            reactions: service.activeReactions,
            showLocalMute: isMe && service.isMuted,
            errorOverlay: _seatErrors[index],
            isMusicPlaying:
                (seat['isMusicPlaying'] == true) ||
                (isMe && service.isMusicPlaying),
            isKeyboardVisible: isKeyboardVisible,
            challenge: service.currentRoomData?['challenge'],
            customSeatColor: _parseColor(roomData?['seatColor']),
            customSeatShape:
                customSeatShape ??
                ((roomData?['seatColor']?.toString().startsWith('image:') ==
                            true ||
                        roomData?['seatColor']?.toString().startsWith('url:') ==
                            true)
                    ? roomData!['seatColor']
                    : null),
            pkColor: pkColor,
          ),
        ),
      );
    } else {
      final bool isGlobalLocked = !service.isGlobalMicEnabled;
      final bool isAdminSeatsLocked = !service.adminSeatsEnabled;
      final bool isSeatLocked = seat?['isLocked'] == true;
      final int roomLevel = roomData?['roomLevel'] ?? roomData?['level'] ?? 1;
      final bool isSeatBoosted = index < 5 || roomLevel >= 2 || roomData?['isBoosted'] == true || roomData?['isAdminRoom'] == true || roomData?['ownerId'] == 'admin';
      final bool isBoosted = isSeatBoosted;
      final bool effectivelyLocked =
          isGlobalLocked || isAdminSeatsLocked || isSeatLocked || !isBoosted;

      return GestureDetector(
        onTap: () async {
          final String currentUid = service.currentUserId ?? "";
          if (currentUid.isEmpty) return;

          final bool isHostOrAdmin =
              currentUid == (roomData?['hostId'] ?? "") ||
              (service.isAdmin(currentUid) &&
                  roomData?['adminCanManageSeats'] == true) ||
              service.isCoOwner(currentUid);

          final int tapRoomLevel = roomData?['roomLevel'] ?? roomData?['level'] ?? 1;
          final bool isBoostedTap = index < 5 || tapRoomLevel >= 2 || roomData?['isBoosted'] == true || roomData?['isAdminRoom'] == true || roomData?['ownerId'] == 'admin';
          if (!isBoostedTap) {
            if (currentUid == (roomData?['hostId'] ?? "")) {
              _showBoostRoomDialog(context, service);
            } else {
              _showSeatError(index, "مغلق");
            }
            return;
          }

          if (isGlobalLocked || isAdminSeatsLocked) {
            _showSeatError(index, "مغلق");
            return;
          }

          if (isHostOrAdmin) {
            _showSeatOptionsForAdmin(
              context,
              service,
              roomData,
              index,
              isSeatLocked,
            );
            return;
          }

          if (isSeatLocked) {
            _showSeatError(index, "مقفول");
            return;
          }

          final String micMode = roomData?['micMode'] ?? "الجميع";
          final bool isMeAdmin =
              currentUid == (roomData?['hostId'] ?? "") ||
              service.isAdmin(currentUid) ||
              service.isCoOwner(currentUid);

          if (!isMeAdmin) {
            if (micMode == "المشرفون فقط") {
              _showSeatError(index, "عذراً، أنت لست مشرفاً");
              return;
            }
            if (micMode == "الأعضاء فقط" && !service.isRoomMember) {
              _showMembershipJoinDialog(
                context,
                service,
                roomData,
                widget.roomId,
                index,
              );
              return;
            }
          }

          try {
            await service.takeSeat(index);
          } catch (e) {
            _showSeatError(index, e.toString());
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildSeatItem(
            isMe: false,
            isHost: false,
            isTalking: false,
            isEmpty: true,
            isLocked: effectivelyLocked,
            isGlobalLocked: isGlobalLocked,
            errorOverlay: _seatErrors[index],
            seatIndex: index + 1,
            userId: null,
            displayId: null,
            reactions: service.activeReactions,
            isKeyboardVisible: isKeyboardVisible,
            challenge: service.currentRoomData?['challenge'],
            customSeatColor: _parseColor(roomData?['seatColor']),
            customSeatShape:
                customSeatShape ??
                ((roomData?['seatColor']?.toString().startsWith('image:') ==
                            true ||
                        roomData?['seatColor']?.toString().startsWith('url:') ==
                            true)
                    ? roomData!['seatColor']
                    : null),
            pkColor: pkColor,
          ),
        ),
      );
    }
  }

  Future<void> _showBoostRoomDialog(
    BuildContext context,
    VoiceRoomService service,
  ) async {
    const int cost = 60000;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "BoostRoom",
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rocket_launch,
                      color: Colors.amber,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "تعزيز الغرفة وفتح الكراسي",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "سيتم فتح جميع الكراسي بشكل دائم في هذه الغرفة. هذا الإجراء يتم لمرة واحدة فقط.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/coinsmeto.png',
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.monetization_on,
                                color: Colors.amber,
                                size: 20,
                              ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "$cost",
                          style: TextStyle(
                            color: Color.fromARGB(255, 6, 192, 6),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "إلغاء",
                            style: TextStyle(
                              color: Colors.white38,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            try {
                              Navigator.pop(context);
                              await service.boostRoomSeats();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("تم تعزيز الغرفة بنجاح!"),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                final errorStr = e.toString();
                                if (errorStr.contains('رصيدك') ||
                                    errorStr.contains('ميتو')) {
                                  _showRechargeDialog(context);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(errorStr)),
                                  );
                                }
                              }
                            }
                          },
                          child: const Text(
                            "تعزيز الآن",
                            style: TextStyle(
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeatItem({
    required bool isHost,
    required bool isTalking,
    bool isEmpty = true,
    String? name,
    String? avatarUrl,
    int? seatIndex,
    String? userId,
    String? displayId,
    String? displayIdImage,
    Map<String, dynamic>? frames,
    Map<String, dynamic>? reactions,
    bool isMe = false,
    bool showLocalMute = false,
    bool isMusicPlaying = false,
    bool isKeyboardVisible = false,
    bool isLocked = false,
    bool isGlobalLocked = false,
    String? frame,
    String? errorOverlay,
    Map<String, dynamic>? challenge,
    Color? customSeatColor,
    String? customSeatShape,
    Color? pkColor,
    double size = 58,
  }) {
    // Unified identity check to prevent flicker during seat transitions

    // Check for active reaction
    String? activeReaction;
    if (userId != null && reactions != null && reactions.containsKey(userId)) {
      activeReaction = reactions[userId]['type'];
    }

    // Filter Ghost Users: Check if the user on this seat is actually in the active member list
    // (We skip this for 'me' to allow for local reconnection stability)
    final bool isUserOnline = (userId == null)
        ? false
        : ((isMe && !_service.isNetworkLost) ||
              _service.roomUsers.any((u) => u.uid == userId));

    final bool displayAsEmpty = isEmpty || !isUserOnline;

    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Column(
          key: ValueKey('seat_spot_$seatIndex'),
          mainAxisSize: MainAxisSize.min,
          children: [
            _TalkingPulse(
              key: ValueKey('pulse_${userId ?? seatIndex}'),
              isTalking: isTalking,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // === OCCUPIED SEAT (Avatar) ===
                  if (!displayAsEmpty)
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            (pkColor != null &&
                                (customSeatShape == null ||
                                    !customSeatShape.startsWith('image:')))
                            ? Border.all(color: pkColor, width: 2)
                            : null,
                        boxShadow: [
                          if (isTalking)
                            BoxShadow(
                              color:
                                  (customSeatColor ?? const Color(0xFF00FFD1))
                                      .withOpacity(0.3),
                              blurRadius: 18,
                              spreadRadius: 5,
                            ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (customSeatShape != null &&
                              customSeatShape.startsWith('image:'))
                            Image.asset(
                              customSeatShape == 'image:michakam'
                                  ? 'assets/images/michakam.png'
                                  : (customSeatShape == 'image:mic'
                                        ? 'assets/images/mick/mic.png'
                                        : (customSeatShape == 'image:micbluue'
                                              ? 'assets/images/micbluue.png'
                                              : 'assets/images/micreed.png')),
                              width: size,
                              height: size,
                              fit: BoxFit.contain,
                            ),
                          FramedAvatar(
                            key: ValueKey('avatar_${userId}_$frame'),
                            userId: userId,
                            imageUrl: avatarUrl,
                            radius: pkColor != null
                                ? 21
                                : 27, // Smaller avatar specifically for PK seats
                            manualFrame: frame,
                            disableFrame: true,
                            disableAnimation: false,
                            overlay: showLocalMute
                                ? Container(
                                    width: 54,
                                    height: 54,
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.mic_off_rounded,
                                      color: Colors.redAccent,
                                      size: 24,
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),

                  // === EMPTY SEAT – Glassmorphism 3D ===
                  if (displayAsEmpty)
                    SizedBox(
                      width: size,
                      height: size,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (customSeatShape != null &&
                              customSeatShape.toString().startsWith('url:') &&
                              !(isGlobalLocked || isLocked))
                            ClipOval(
                              child: Image.network(
                                customSeatShape.toString().substring(4),
                                width: size,
                                height: size,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.broken_image,
                                      color: Colors.white54,
                                    ),
                              ),
                            )
                          else if (customSeatShape == 'image:mic' &&
                              !(isGlobalLocked || isLocked))
                            Image.asset(
                              'assets/images/mick/mic.png',
                              width: size,
                              height: size,
                              fit: BoxFit.contain,
                            )
                          else if (customSeatShape == 'image:micbluue' &&
                              !(isGlobalLocked || isLocked))
                            Image.asset(
                              'assets/images/micbluue.png',
                              width: size,
                              height: size,
                              fit: BoxFit.contain,
                            )
                          else if (customSeatShape == 'image:micreed' &&
                              !(isGlobalLocked || isLocked))
                            Image.asset(
                              'assets/images/micreed.png',
                              width: size,
                              height: size,
                              fit: BoxFit.contain,
                            )
                          else if (customSeatShape == 'image:michakam' &&
                              !(isGlobalLocked || isLocked))
                            Image.asset(
                              'assets/images/michakam.png',
                              width: size,
                              height: size,
                              fit: BoxFit.contain,
                            )
                          else ...[
                            // Outer rim (3D depth border)
                            Container(
                              width: size - 2,
                              height: size - 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: isGlobalLocked || isLocked
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.25),
                                          blurRadius: 6,
                                          offset: const Offset(1, 3),
                                        ),
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.06),
                                          blurRadius: 3,
                                          offset: const Offset(-1, -1),
                                        ),
                                      ],
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: customSeatColor != null
                                      ? [
                                          customSeatColor.withOpacity(0.35),
                                          customSeatColor.withOpacity(0.10),
                                        ]
                                      : isGlobalLocked || isLocked
                                      ? [
                                          Colors.white.withOpacity(0.3),
                                          Colors.white.withOpacity(0.3),
                                        ]
                                      : [
                                          Colors.white.withOpacity(0.3),
                                          Colors.white.withOpacity(0.3),
                                        ],
                                ),
                                border: Border.all(
                                  color:
                                      customSeatColor ??
                                      (isGlobalLocked || isLocked
                                          ? Colors.white.withOpacity(0.3)
                                          // ignore: deprecated_member_use
                                          : Colors.white.withOpacity(0.3)),
                                  width: 1.5,
                                ),
                              ),
                            ),

                            // Top-left shine dot (3D highlight)
                            if (!isGlobalLocked && !isLocked)
                              Positioned(
                                top: 8,
                                left: 10,
                                child: Container(
                                  width: 14,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              ),
                          ],

                          // Lock icon or default Mic icon
                          Icon(
                            isGlobalLocked || isLocked
                                ? Icons.lock_rounded
                                : Icons.mic_none_rounded,
                            color: isGlobalLocked || isLocked
                                ? (customSeatColor ?? Colors.redAccent)
                                : (customSeatShape == 'image:mic'
                                      ? const Color(0xFFFFD700)
                                      : (customSeatShape?.toString().startsWith(
                                                  'url:',
                                                ) ==
                                                true
                                            ? Colors.transparent
                                            : (customSeatColor != null
                                                  ? Color.lerp(
                                                      customSeatColor,
                                                      Colors.white,
                                                      0.6,
                                                    )
                                                  : Colors.white))),
                            size: 22,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Reaction
                  if (activeReaction != null && !displayAsEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ReactionDisplay(
                          reactionType: activeReaction,
                          onComplete: () {
                            Provider.of<VoiceRoomService>(
                              context,
                              listen: false,
                            ).clearLocalReaction(userId);
                          },
                        ),
                      ),
                    ),
                  if (errorOverlay != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        errorOverlay,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            // === LABEL: Seat Number (empty) or User Name (occupied) ===
            if (displayAsEmpty)
              Text(
                '$seatIndex',
                style: TextStyle(
                  color: customSeatColor ?? Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Tajawal',
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 8),
                    Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        name ?? '...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isTalking
                              ? const Color(0xFF00FFD1)
                              : Colors.white,
                          fontSize: 11,
                          fontWeight: isTalking
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontFamily: 'Tajawal',
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                            Shadow(color: Colors.black, blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (isMusicPlaying && !isEmpty)
          const Positioned(
            bottom: -12,
            child: SizedBox(width: 12, height: 12, child: _MusicDiscIcon()),
          ),
        if (challenge != null &&
            challenge['isActive'] == true &&
            !isEmpty &&
            userId != null)
          Positioned(
            bottom: -20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.pinkAccent,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "${(challenge['points'] as Map<String, dynamic>?)?[userId] ?? 0}",
                    style: const TextStyle(
                      color: Colors.pinkAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildNoticeBox({
    String? title,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Right in RTL
        children: [
          if (title != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.start, // Right in RTL
              children: [
                const Icon(
                  Icons.playlist_add_check_circle_rounded,
                  color: Color(0xFFFFD600),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFFFD600),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          if (title != null) const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF4DD0E1),
              fontSize: 11,
              height: 1.4,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControlBar(
    VoiceRoomService service,
    bool isKeyboardVisible,
    Map<String, dynamic>? roomData,
  ) {
    final String chatMode = roomData?['chatMode'] ?? "الجميع";
    final String currentUid = service.currentUserId ?? "";

    final bool isHostOrAdmin =
        service.isAdmin(currentUid) ||
        service.isCoOwner(currentUid) ||
        currentUid == (roomData?['hostId'] ?? "");

    bool canWriteText = true;
    String restrictionMessage = "";

    // Admin panel per-room chat toggle takes priority
    if (!service.adminChatEnabled) {
      canWriteText = false;
      restrictionMessage = "التكست موقوف في هذه الغرفة من قِبَل الإدارة";
    } else if (chatMode == "إيقاف التكست للجميع") {
      canWriteText = isHostOrAdmin;
      restrictionMessage = "المراسلة متوقفة للجميع حالياً";
    } else if (chatMode == "المشرفون فقط") {
      canWriteText = isHostOrAdmin;
      restrictionMessage = "المراسلة مسموحة للمشرفين فقط حالياً";
    } else if (chatMode == "الأعضاء فقط") {
      canWriteText = isHostOrAdmin || service.isRoomMember;
      restrictionMessage = "المراسلة مسموحة للأعضاء فقط حالياً";
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: Colors.black45,
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.3))),
        ),
        child: Row(
          children: [
            // RIGHT SIDE (End in RTL): Stickers, Mic, Speaker
            if (!isKeyboardVisible)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => service.toggleSpeakerMute(),
                    child: _buildBottomIconButton(
                      service.isSpeakerMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: service.isSpeakerMuted
                          ? Colors.redAccent
                          : Colors.white,
                    ),
                  ),
                  if (service.isMeSeated) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        try {
                          await service.toggleMute();
                        } catch (e) {
                          if (context.mounted) {
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
                      },
                      child: _buildBottomIconButton(
                        service.isMuted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        color: service.isMuted
                            ? Colors.redAccent
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) =>
                              const StickerSelectionBottomSheet(),
                        );
                      },
                      child: _buildBottomIconButton(
                        Icons.emoji_emotions_outlined,
                      ),
                    ),
                  ],
                ],
              ),

            if (!isKeyboardVisible) const SizedBox(width: 8),

            Expanded(
              key: const ValueKey(
                'chat_input_section',
              ), // Key to preserve state
              child: service.isUserMuted(service.currentUserId ?? '')
                  ? Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "تم اصماتك من قبل المشرف",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    )
                  : !canWriteText
                  ? Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        restrictionMessage,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 8,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyingTo != null) _buildReplyPreview(),
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: _replyingTo != null
                                ? const BorderRadius.vertical(
                                    bottom: Radius.circular(22),
                                  )
                                : BorderRadius.circular(22),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Expanded(
                                child: ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _chatController,
                                  builder: (context, value, _) {
                                    return TextField(
                                      key: const ValueKey('chat_text_field'),
                                      focusNode: _chatFocusNode,
                                      controller: _chatController,
                                      textInputAction: value.text.trim().isEmpty
                                          ? TextInputAction.done
                                          : TextInputAction.send,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'اكتب رسالة...',
                                        hintStyle: TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                      ),
                                      onSubmitted: (val) {
                                        if (val.trim().isNotEmpty) {
                                          service.sendMessage(
                                            val.trim(),
                                            replyTo: _replyingTo,
                                          );
                                          _chatController.clear();
                                          setState(() => _replyingTo = null);
                                          _chatFocusNode.requestFocus();
                                        } else {
                                          _chatFocusNode.unfocus();
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _chatController,
                                builder: (context, value, child) {
                                  // Show send button if keyboard is visible or if there is text/reply
                                  final bool showSend =
                                      isKeyboardVisible ||
                                      value.text.trim().isNotEmpty ||
                                      _replyingTo != null;
                                  if (!showSend) return const SizedBox.shrink();
                                  return IconButton(
                                    icon: const Icon(
                                      Icons.send_rounded,
                                      color: Colors.black87,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      if (value.text.trim().isNotEmpty) {
                                        service.sendMessage(
                                          value.text.trim(),
                                          replyTo: _replyingTo,
                                        );
                                        _chatController.clear();
                                        setState(() => _replyingTo = null);
                                        // Keep focus to prevent keyboard from hiding
                                        _chatFocusNode.requestFocus();
                                      }
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),

            if (!isKeyboardVisible) const SizedBox(width: 8),

            // LEFT SIDE (Start in RTL): Gift & Games
            if (!isKeyboardVisible)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentUid == (roomData?['hostId'] ?? "") ||
                      service.isAdmin(currentUid) ||
                      service.isCoOwner(currentUid))
                    GestureDetector(
                      onTap: () => _showRoomGamesSheet(context),
                      child: _buildBottomIconButton(
                        Icons.sports_esports_rounded,
                      ),
                    ),
                  if (currentUid == (roomData?['hostId'] ?? "") ||
                      ((service.isAdmin(currentUid) ||
                              service.isCoOwner(currentUid)) &&
                          roomData?['adminCanControlGames'] == true))
                    const SizedBox(width: 12),
                  // Gift Box Stack
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Sparkles (Keep existing logic)
                      AnimatedBuilder(
                        animation: _sparkleController,
                        builder: (context, child) {
                          if (_sparkleController.value == 0 ||
                              _sparkleController.value == 1) {
                            return const SizedBox.shrink();
                          }
                          return Stack(
                            alignment: Alignment.center,
                            children: List.generate(8, (index) {
                              final angle = (index * 45) * math.pi / 180;
                              final curve = Curves.easeOutCubic.transform(
                                _sparkleController.value,
                              );
                              final distance = curve * 45.0;
                              final opacity = 1.0 - _sparkleController.value;
                              return Transform.translate(
                                offset: Offset(
                                  math.cos(angle) * distance,
                                  math.sin(angle) * distance,
                                ),
                                child: Opacity(
                                  opacity: opacity,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.amberAccent,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber,
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      GestureDetector(
                        onTap: () => _showGiftPanel(context, service),
                        child: AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            double rotation = 0;
                            if (_shakeController.value > 0) {
                              rotation =
                                  math.sin(
                                    _shakeController.value * math.pi * 4,
                                  ) *
                                  0.15;
                            }
                            return Transform.rotate(
                              angle: rotation,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.95, end: 1.05),
                                duration: const Duration(seconds: 2),
                                curve: Curves.easeInOut,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF8B5CF6,
                                            ).withOpacity(0.3),
                                            blurRadius: 15,
                                            spreadRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                                child: child,
                              ),
                            );
                          },
                          child: Image.asset(
                            'assets/images/purple_gift_box.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.card_giftcard_rounded,
                                  color: Color(0xFF8B5CF6),
                                  size: 24,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ), // end Container
    ); // end Listener
  }

  Widget _buildFrameOrStickerPreview(Map<String, dynamic> msg) {
    if (msg['frameType'] != null) {
      final String frameType = msg['frameType'].toString();
      if (frameType.startsWith('http')) {
        return SizedBox(
          width: 30,
          height: 30,
          child: Lottie.network(
            frameType,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => const Icon(
              Icons.emoji_emotions,
              color: Colors.blueAccent,
              size: 20,
            ),
          ),
        );
      } else {
        return Image.asset(
          FramedAvatar.getFrameAsset(frameType),
          width: 30,
          height: 30,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => const SizedBox.shrink(),
        );
      }
    }

    if (msg['imageUrl'] != null) {
      final imgUrl = msg['imageUrl'].toString();
      if (imgUrl.startsWith('http')) {
        return SizedBox(
          width: 30,
          height: 30,
          child: Lottie.network(
            imgUrl,
            fit: BoxFit.contain,
            errorBuilder: (c, e, s) => const Icon(
              Icons.emoji_emotions,
              color: Colors.blueAccent,
              size: 20,
            ),
          ),
        );
      } else {
        final emojiData = StickerSelectionBottomSheet.getEmojiData(imgUrl);
        if (emojiData != null) {
          return SizedBox(
            width: 24,
            height: 24,
            child: AnimatedEmoji(emojiData, size: 24),
          );
        }
      }
    }

    if (msg['roomEntrance'] != null) {
      return Text(
        msg['roomEntrance'], // Emoji fallback
        style: const TextStyle(fontSize: 20),
      );
    }

    return const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 20);
  }

  Widget _buildChatMessageItem(Map<String, dynamic> msg) {
    final service = Provider.of<VoiceRoomService>(context, listen: false);
    final String msgType = msg['type'] ?? 'text';
    final String text = msg['text'] ?? '';

    if (msgType == 'game_invite') {
      final gameId = msg['gameId'];
      return GestureDetector(
        onTap: () async {
          if (gameId != null) {
            await service.joinRoomGame(gameId);
            _showTicTacToeGame(gameId);
          }
        },
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF35ABA1), Color(0xFF2C3E50)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.grid_3x3_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const Text(
                      'اضغط للانضمام والبدء باللعب',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool isSystem = msgType == 'system';
    final bool isStickerBasic = msgType == 'sticker_basic';

    if (isSystem || isStickerBasic) {
      final bool isSticker = text.contains('ملصقاً') || isStickerBasic;
      final bool isFrameType = text.contains('إطاراً');

      if (!isSticker && !isFrameType) {
        // Simple System Message (Fallback)
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00FFD1).withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00FFD1).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.stars_rounded,
                  color: Color(0xFF00FFD1),
                  size: 14,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFF00FFD1),
                      fontSize: 10,
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

      final String senderName = msg['senderName'] ?? 'مستخدم';
      final String receiverName =
          msg['receiverName'] ?? (isStickerBasic ? '' : 'مستخدم');
      final bool isMe = msg['senderId'] == service.currentUserId;

      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isFrameType
                ? const Color(0xFFFFD700).withOpacity(0.3)
                : Colors.blueAccent.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isFrameType
                  ? const Color(0xFFFFD700).withOpacity(0.3)
                  : Colors.blueAccent.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg['photoURL'] != null) ...[
                (() {
                  final senderId = msg['senderId'];
                  String? activeFrameId = senderId != null
                      ? service.getActiveFrameForUser(senderId)
                      : null;
                  return FramedAvatar(
                    userId: senderId,
                    radius: 12,
                    imageUrl: msg['photoURL'],
                    manualFrame: activeFrameId,
                    borderColor: Colors.white.withOpacity(0.3),
                    borderWidth: 1.0,
                    disableFrame: true,
                  );
                })(),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: RichText(
                  textAlign: TextAlign.start,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontFamily: 'Tajawal',
                    ),
                    children: [
                      TextSpan(
                        text: '${isMe ? "أنت" : senderName} ',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: isMe
                            ? (isSticker ? 'أرسلت ملصقاً ' : 'أرسلت إطاراً ')
                            : (msg['receiverId'] == service.currentUserId
                                  ? (isSticker
                                        ? 'أرسل لك ملصقاً '
                                        : 'أرسل لك إطاراً ')
                                  : (isSticker
                                        ? 'أرسل ملصقاً '
                                        : 'أرسل إطاراً ')),
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildFrameOrStickerPreview(msg),
                        ),
                      ),
                      if (receiverName.isNotEmpty &&
                          msg['receiverId'] != service.currentUserId) ...[
                        const TextSpan(text: ' إلى '),
                        TextSpan(
                          text: receiverName,
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (msgType == 'gift') {
      final int quantity = msg['quantity'] ?? 1;
      final bool isMe = msg['senderId'] == service.currentUserId;

      final bool canReply =
          (msg['receiverId'] == service.currentUserId ||
              msg['receiverId'] == 'all') &&
          !isMe;
      final Widget replyButton = canReply
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                String senderName = 'أنت';
                if (service.currentUserId != null) {
                  final user = await UserService().getUser(
                    service.currentUserId!,
                  );
                  if (user != null) {
                    senderName =
                        (user.nickname != null && user.nickname!.isNotEmpty)
                        ? user.nickname!
                        : user.username;
                  }
                }
                if (!context.mounted) return;

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => GiftSelectionBottomSheet(
                    receiverId: msg['senderId'],
                    receiverName: msg['senderName'] ?? 'مستخدم',
                    roomId: service.currentRoomId,
                    senderId: service.currentUserId ?? '',
                    senderName: senderName,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                child: Image.asset(
                  'assets/images/giftrom.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
              ),
            )
          : const SizedBox.shrink();

      return Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.of(context).size.width *
                      0.75, // slightly smaller to fit the button
                ),
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4081).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFF4081).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (msg['photoURL'] != null) ...[
                      (() {
                        final senderId = msg['senderId'];
                        String? activeFrameId = senderId != null
                            ? service.getActiveFrameForUser(senderId)
                            : null;
                        return FramedAvatar(
                          userId: senderId,
                          radius: 12,
                          imageUrl: msg['photoURL'],
                          manualFrame: activeFrameId,
                          borderColor: Colors.white.withOpacity(0.3),
                          borderWidth: 1.0,
                          disableFrame: true,
                        );
                      })(),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: RichText(
                        textAlign: TextAlign.start,
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontFamily: 'Tajawal',
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '${isMe ? "أنت" : (msg['senderName'] ?? "مستخدم")} ',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: isMe
                                  ? 'أرسلت '
                                  : (msg['receiverId'] == service.currentUserId
                                        ? 'أرسل لك '
                                        : 'أرسل '),
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child:
                                    (msg['giftIcon']?.toString().startsWith(
                                          'http',
                                        ) ??
                                        false)
                                    ? Image.network(
                                        msg['giftIcon'],
                                        width: 24,
                                        height: 24,
                                        errorBuilder: (c, e, s) =>
                                            const Text('🎁'),
                                      )
                                    : (msg['giftIcon']?.toString().startsWith(
                                            'assets/',
                                          ) ??
                                          false)
                                    ? Image.asset(
                                        msg['giftIcon'],
                                        width: 24,
                                        height: 24,
                                        errorBuilder: (c, e, s) =>
                                            const Text('🎁'),
                                      )
                                    : Text(
                                        '${msg['giftIcon'] ?? '🎁'}',
                                        style: const TextStyle(fontSize: 18),
                                      ),
                              ),
                            ),
                            if (quantity > 1)
                              TextSpan(
                                text: 'x$quantity ',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            if (msg['receiverId'] != service.currentUserId) ...[
                              const TextSpan(text: 'إلى '),
                              TextSpan(
                                text: '${msg['receiverName']}',
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            replyButton,
          ],
        ),
      );
    }

    // Default Text Message rendering
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onLongPress: () {
          setState(() => _replyingTo = msg);
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showMemberProfile(
                context,
                service,
                msg['senderId'] ?? '',
                msg['senderName'],
                msg['photoURL'],
              ),
              child: (() {
                String? activeFrameId;
                final senderId = msg['senderId'];
                if (senderId != null &&
                    service.activeFrames.containsKey(senderId)) {
                  final fData = service.activeFrames[senderId];
                  final expiryStr = fData['expiry'] as String?;
                  if (expiryStr != null) {
                    final expiry = DateTime.parse(expiryStr).toUtc();
                    if (DateTime.now().toUtc().isBefore(expiry)) {
                      activeFrameId = fData['type'];
                    }
                  }
                }
                return FramedAvatar(
                  userId: senderId,
                  imageUrl:
                      (msg['photoURL'] != null &&
                          msg['photoURL'].toString().isNotEmpty)
                      ? msg['photoURL'].toString()
                      : null,
                  radius: 12.0, // Reduced from 14.5
                  manualFrame: activeFrameId,
                  borderColor: Colors.white.withOpacity(0.3),
                  borderWidth: 1.0,
                  disableFrame: true,
                );
              })(),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Role-based Name Area (Outside the bubble)
                  (() {
                    final String senderId = msg['senderId'] ?? '';
                    Color roleColor = Colors.grey;
                    if (senderId == service.hostId) {
                      roleColor = const Color(0xFFFF4081); // Pink for Owner
                    } else if (service.isCoOwner(senderId)) {
                      roleColor = const Color(0xFFFFD700); // Yellow for Deputy
                    } else if (service.isAdmin(senderId)) {
                      roleColor = const Color(0xFF4CAF50); // Green for Admin
                    } else if (service
                            .roomUsersMetadata[senderId]?['isMember'] ==
                        true) {
                      roleColor = const Color(0xFF2196F3); // Blue for Member
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4, right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person, size: 12, color: roleColor),
                          const SizedBox(width: 4),
                          Text(
                            msg['senderName'] ?? '...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.normal,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ],
                      ),
                    );
                  })(),

                  // 2. Message Content (Inside a bubble)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showChatMessageActions(context, msg),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (msg['replyTo'] != null)
                            _buildInternalReplyBubble(msg['replyTo']),
                          Text(
                            msg['text'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              height: 1.4,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ],
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

  void _showChatMessageActions(BuildContext context, Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.white),
              title: const Text(
                'رد على الرسالة',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingTo = msg);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.report_problem_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                'إبلاغ عن محتوى الرسالة',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                // Simple report for text
                await UserService().reportUser(
                  currentUserId: _service.currentUserId ?? "",
                  userToReportId: msg['senderId'] ?? "",
                  reason: "إبلاغ عن رسالة: ${msg['text']}",
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرسال البلاغ بنجاح')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberProfile(
    BuildContext context,
    VoiceRoomService service,
    String userId,
    String? name,
    String? avatar,
  ) async {
    final user = await UserService().getUser(userId);
    if (user == null) return;
    if (!mounted) return;

    MemberProfileBottomSheet.show(
      context,
      service,
      user,
      onMention: (name) {
        _chatController.text = "${_chatController.text}@$name ".trimLeft();
        _chatController.selection = TextSelection.fromPosition(
          TextPosition(offset: _chatController.text.length),
        );
        _chatFocusNode.requestFocus();
      },
    );
  }

  void _showMySeatOptions(BuildContext context, VoiceRoomService service) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xE6101920), // Elegant Dark Translucent
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: const Color(0xFF00FFD1).withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FFD1).withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Leave Mic
              _buildModernDialogAction(
                label: 'ترك المايك',
                icon: Icons.mic_off_rounded,
                onTap: () {
                  Navigator.pop(context);
                  service.leaveSeat();
                },
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.05)),

              // 2. View Profile
              _buildModernDialogAction(
                label: 'فتح الملف الشخصي',
                icon: Icons.person_rounded,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileScreen(uid: service.currentUserId),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomMessagesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const SizedBox(height: 15),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                TabBar(
                  indicatorColor: Colors.amber,
                  labelColor: Colors.amber,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    const Tab(text: 'الرسائل'),
                    StreamBuilder<List<NotificationModel>>(
                      stream: NotificationService().getNotificationsStream(
                        _service.currentUserId ?? '',
                      ),
                      builder: (context, snapshot) {
                        bool hasUnreadRequests = false;
                        if (snapshot.hasData) {
                          hasUnreadRequests = snapshot.data!.any(
                            (n) =>
                                !n.isRead && n.type == NotificationType.follow,
                          );
                        }
                        return Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('الطلبات'),
                              if (hasUnreadRequests) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [_buildChatsList(), _buildNotificationsList()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatsList() {
    return StreamBuilder<List<Chat>>(
      stream: ChatService().getChatsStream(_service.currentUserId ?? ''),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final chats = snapshot.data!;
        if (chats.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد رسائل',
              style: TextStyle(color: Colors.white38),
            ),
          );
        }
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final otherId = chat.participants.firstWhere(
              (id) => id != _service.currentUserId,
            );
            return FutureBuilder(
              future: UserService().getUser(otherId),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return const SizedBox();
                final user = userSnap.data!;
                return ListTile(
                  leading: FramedAvatar(
                    userId: user.uid,
                    radius: 20,
                    imageUrl: user.profileImage,
                    disableFrame: true,
                  ),
                  title: Text(
                    user.nickname ?? user.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    chat.lastMessage,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          receiverId: user.uid,
                          receiverName: user.nickname ?? user.username,
                          receiverImage: user.profileImage,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationsList() {
    return StreamBuilder<List<NotificationModel>>(
      stream: NotificationService().getNotificationsStream(
        _service.currentUserId ?? '',
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final notifications = snapshot.data!
            .where((n) => n.type == NotificationType.follow)
            .toList();

        if (notifications.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد طلبات جديدة',
              style: TextStyle(color: Colors.white38),
            ),
          );
        }

        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return ListTile(
              leading: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileScreen(uid: notification.senderId),
                    ),
                  );
                },
                child: FramedAvatar(
                  userId: notification.senderId,
                  radius: 20,
                  imageUrl: notification.senderProfileImage,
                  disableFrame: true,
                ),
              ),
              title: Text(
                notification.senderName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                notification.text,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              trailing: FutureBuilder<User?>(
                future: UserService().getUser(_service.currentUserId ?? ''),
                builder: (context, meSnap) {
                  if (!meSnap.hasData) return const SizedBox();
                  final isFollowingBack = meSnap.data!.following.contains(
                    notification.senderId,
                  );
                  if (isFollowingBack) {
                    return const Text(
                      'متابع',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    );
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          // Reject: Remove follow from sender and delete notification
                          await UserService().unfollowUser(
                            currentUserId: notification.senderId,
                            userToUnfollowId: _service.currentUserId!,
                          );
                          await NotificationService().deleteNotification(
                            notification.id,
                          );
                        },
                        child: const Text(
                          'رفض',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await UserService().followUser(
                            currentUserId: _service.currentUserId!,
                            currentUsername:
                                meSnap.data!.nickname ?? meSnap.data!.username,
                            currentUserProfileImage: meSnap.data!.profileImage,
                            userToFollowId: notification.senderId,
                          );
                          await NotificationService().markAsRead(
                            notification.id,
                          );
                        },
                        child: const Text(
                          'رد المتابعة',
                          style: TextStyle(color: Colors.amber, fontSize: 13),
                        ),
                      ),
                    ],
                  );
                },
              ),
              onTap: () async {
                await NotificationService().markAsRead(notification.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileScreen(uid: notification.senderId),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  void _showGiftPanel(BuildContext context, VoiceRoomService service) async {
    String senderName = 'أنت';
    if (service.currentUserId != null) {
      final user = await UserService().getUser(service.currentUserId!);
      if (user != null) {
        senderName = (user.nickname != null && user.nickname!.isNotEmpty)
            ? user.nickname!
            : user.username;
      }
    }
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftSelectionBottomSheet(
        receiverId: null,
        receiverName: null,
        roomId: service.currentRoomId,
        senderId: service.currentUserId ?? '',
        senderName: senderName,
      ),
    );
  }

  Widget _buildInternalReplyBubble(Map replyTo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          right: BorderSide(color: Colors.amber.withOpacity(0.3), width: 3.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.reply_rounded, color: Colors.amber, size: 14),
              const SizedBox(width: 6),
              Text(
                replyTo['senderName'] ?? '...',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            replyTo['text'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 12,
              fontFamily: 'Tajawal',
              fontStyle: FontStyle.italic,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C3C).withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          // Reply Icon Indicator
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.reply_rounded,
              color: Colors.amber,
              size: 20,
            ),
          ),
          const SizedBox(width: 15),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "الرد على ${(_replyingTo!['senderName'] ?? '')}",
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!['text'] ?? '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 13,
                    fontFamily: 'Tajawal',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Close button
          GestureDetector(
            onTap: () => setState(() => _replyingTo = null),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomIconButton(
    IconData icon, {
    Color color = Colors.white,
    double opacity = 1.0,
  }) {
    return Icon(icon, color: color.withOpacity(opacity * 0.9), size: 24);
  }

  void _showRoomGamesSheet(BuildContext context) {
    final roomData = _service.currentRoomData;
    final isOwner = _service.isHost;
    final currentUid = auth.FirebaseAuth.instance.currentUser?.uid ?? "";
    _service.isAdmin(currentUid);
    _service.isCoOwner(currentUid);
    final adminCanControl = roomData?['adminCanControlGames'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.55,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 25),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'ألعاب الغرفة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
              const SizedBox(height: 30),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _buildGameLauncherItem(
                    'عداد وقت',
                    Icons.timer_rounded,
                    Colors.cyan,
                    () {
                      Navigator.pop(context);
                      _showTimerModeSelection(context);
                    },
                  ),
                  if (isOwner || adminCanControl)
                    _buildGameLauncherItem(
                      'تحدي الهدايا',
                      Icons.military_tech_rounded,
                      Colors.orange,
                      () {
                        Navigator.pop(context);
                        _showChallengeSelectionDialog(isPK: false);
                      },
                    ),
                  if (isOwner || adminCanControl)
                    StreamBuilder<DocumentSnapshot>(
                      stream: _service.roomStream,
                      builder: (context, snapshot) {
                        final roomData =
                            snapshot.data?.data() as Map<String, dynamic>?;
                        final pkActive =
                            roomData?['pkMatch']?['isActive'] == true;

                        return _buildGameLauncherItem(
                          pkActive ? 'إنهاء PK' : 'مباراة PK',
                          pkActive
                              ? Icons.stop_circle_rounded
                              : Icons.bolt_rounded,
                          pkActive ? Colors.redAccent : Colors.amber,
                          () {
                            Navigator.pop(context);
                            if (pkActive) {
                              _service.stopPKMatch();
                            } else {
                              _showChallengeSelectionDialog(isPK: true);
                            }
                          },
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameLauncherItem(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    String? imagePath,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 2),
            ),
            child: ClipOval(
              child: imagePath != null
                  ? Image.asset(imagePath, fit: BoxFit.cover)
                  : Icon(icon, color: color, size: 30),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  void _showTicTacToeGame(String gameId) {
    // Use setState to show the game as an inline overlay inside the room.
    // This avoids pushing a new navigator route which could trigger dispose/leaveRoom.
    if (mounted) {
      setState(() => _activeGameId = gameId);
    }
  }

  Widget _buildPermanentBackground(String? url) {
    if (url == null || url.isEmpty) {
      return _buildDefaultCosmicBackgroundStack();
    }
    // Always route through _buildRoomBackground first to allow theme overrides
    // even if the ID happens to be a URL string.
    return _buildRoomBackground(_service, url);
  }

  Widget _buildDefaultCosmicBackgroundStack() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF133E2B), // Brighter Emerald Lighting Top
                  Color(0xFF0D241C), // Classic Deep Emerald
                  Color(0xFF03160F), // Dark Space Green
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomBackground(VoiceRoomService service, String backgroundId) {
    Widget backgroundWidget;
    bool isCustomGradient = false;

    if (backgroundId == 'default_cosmic' || backgroundId == 'cosmic_deep') {
      backgroundWidget = _buildDefaultCosmicBackgroundStack();
      isCustomGradient = true;
    } else if (backgroundId == 'royal_oasis') {
      backgroundWidget = _buildGradientBackground([
        const Color(0xFF5E35B1), // Top Purple
        const Color(0xFF311B92), // Mid Purple
        const Color(0xFF120B38), // Dark midnight purple
      ]);
      isCustomGradient = true;
    } else if (backgroundId == 'crystal_glow') {
      backgroundWidget = _buildGradientBackground([
        const Color(0xFF1E88E5), // Top Blue
        const Color(0xFF0D47A1), // Mid Blue
        const Color(0xFF0A192F), // Dark midnight blue
      ]);
      isCustomGradient = true;
    } else if (backgroundId == 'royal_horizon') {
      backgroundWidget = _buildGradientBackground([
        const Color(0xFF004B91), // Goyti Blue Top
        const Color(0xFF002D5A), // Deep Navy Mid
        const Color(0xFF00152D), // Dark midnight navy
      ]);
      isCustomGradient = true;
    } else {
      // 1. Resolve from service cache for other backgrounds
      final bg = service.allBackgrounds
          .where((b) => b.id == backgroundId)
          .firstOrNull;

      if (bg != null && bg.id != 'unknown') {
        // 2. Lottie Priority
        if (bg.lottieUrl != null && bg.lottieUrl!.isNotEmpty) {
          backgroundWidget = Lottie.network(
            bg.lottieUrl!,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => _buildDefaultCosmicBackgroundStack(),
          );
        }
        // 3. Image Priority
        else if (bg.image.startsWith('http')) {
          backgroundWidget = CachedNetworkImage(
            imageUrl: bg.image,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            errorWidget: (c, u, e) => _buildDefaultCosmicBackgroundStack(),
            placeholder: (c, u) => _buildDefaultCosmicBackgroundStack(),
          );
        } else if (bg.image.isNotEmpty && bg.image != 'default') {
          backgroundWidget = Image.asset(
            bg.image,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => _buildDefaultCosmicBackgroundStack(),
          );
        } else {
          backgroundWidget = _buildDefaultCosmicBackgroundStack();
        }
      } else if (backgroundId.startsWith('http')) {
        backgroundWidget = CachedNetworkImage(
          imageUrl: backgroundId,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          errorWidget: (c, u, e) => _buildDefaultCosmicBackgroundStack(),
          placeholder: (c, u) => _buildDefaultCosmicBackgroundStack(),
        );
      } else {
        backgroundWidget = _buildDefaultCosmicBackgroundStack();
      }
    }

    // Apply Global Darker Overlay for Eye Protection
    return Stack(
      fit: StackFit.expand,
      children: [
        backgroundWidget,
        // Semi-transparent black layer to darken the background
        Container(
          color: Colors.black.withOpacity(isCustomGradient ? 0.35 : 0.50),
        ),
      ],
    );
  }

  Widget _buildGradientBackground(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
    );
  }

  ImageProvider? _getAvatarProvider(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('assets/')) {
      return AssetImage(photoUrl);
    }
    return NetworkImage(photoUrl);
  }

  void _showInviteFriendsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1C3C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            final userId = auth.FirebaseAuth.instance.currentUser?.uid ?? '';
            return StreamBuilder<User?>(
              stream: UserService().getUserStream(userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final following = snapshot.data!.following;
                if (following.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: const Text(
                        "ليس لديك أصدقاء حالياً لمتابعتهم",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Text(
                        "دعوة الأصدقاء",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white10),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: following.length,
                        itemBuilder: (context, index) {
                          return FutureBuilder<User?>(
                            future: UserService().getUser(following[index]),
                            builder: (context, userSnap) {
                              if (!userSnap.hasData)
                                return const SizedBox.shrink();
                              final friend = userSnap.data!;
                              return ListTile(
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundImage: _getAvatarProvider(
                                        friend.profileImage,
                                      ),
                                      child: friend.profileImage == null
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                    if (friend.isOnline)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF1A1C3C),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  friend.nickname ?? friend.username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                                subtitle: Text(
                                  friend.isOnline ? "نشط الآن" : "غير متصل",
                                  style: TextStyle(
                                    color: friend.isOnline
                                        ? Colors.greenAccent
                                        : Colors.white54,
                                    fontSize: 12,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyanAccent,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                  ),
                                  onPressed: () => _sendRoomInvite(friend),
                                  child: const Text(
                                    "دعوة",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _sendRoomInvite(User targetUser) async {
    final senderId = auth.FirebaseAuth.instance.currentUser?.uid;
    if (senderId == null) return;

    // Fetch sender details
    final senderDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(senderId)
        .get();
    final senderData = senderDoc.data();
    final senderName =
        senderData?['nickname'] ?? senderData?['username'] ?? 'صديقك';

    final notification = NotificationModel(
      id: '',
      receiverId: targetUser.uid,
      senderId: senderId,
      senderName: senderName,
      senderProfileImage: senderData?['profileImage'],
      type: NotificationType.roomInvite,
      postId: widget.roomId,
      text: 'يدعوك للانضمام إلى غرفته الصوتية!',
      createdAt: DateTime.now(),
    );

    await NotificationService().sendNotification(notification);

    // ALSO send a chat message for "Invitation as a message"
    try {
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .get();
      final roomName = roomDoc.data()?['name'] ?? 'غرفة صوتية';

      await ChatService().sendMessage(
        senderId: senderId,
        receiverId: targetUser.uid,
        text: 'انضم إلى غرفتي الصوتية: $roomName',
        type: 'room_invite',
        mediaUrl: widget.roomId, // Store roomId in mediaUrl
      );
    } catch (e) {
      print('Error sending room invite chat message: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "تم إرسال دعوة إلى ${targetUser.nickname ?? targetUser.username}",
          ),
          backgroundColor: const Color(0xFF6366F1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showRechargeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.amber,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "رصيد غير كافٍ",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
        content: const Text(
          "رصيدك من عملات ميتو غير كافٍ لتعزيز الكراسي. هل تريد الذهاب لمتجر ميتو الذكي للشحن؟",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
            fontFamily: 'Tajawal',
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    "إلغاء",
                    style: TextStyle(
                      color: Colors.white38,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    final uid = auth.FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoreScreen(userId: uid),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "شحن الآن",
                    style: TextStyle(
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

  Widget _buildPinnedAnnouncement(dynamic announcement) {
    if (announcement == null) return const SizedBox.shrink();
    final String text = announcement.toString().trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFF4A148C).withOpacity(0.3), // Dark Purple
            const Color(0xFF00BFA5).withOpacity(0.3), // Teal
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Color(0xFFFFD600),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'إعلان الوكلاء',
                  style: TextStyle(
                    color: Color(0xFFFFD600),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Tajawal',
                    height: 1.4,
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

class _MarqueeWidget extends StatefulWidget {
  final Widget child;

  const _MarqueeWidget({required this.child});

  @override
  _MarqueeWidgetState createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<_MarqueeWidget> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _animate());
  }

  void _animate() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted || !_scrollController.hasClients) return;

    if (_scrollController.position.maxScrollExtent > 0) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 3000),
        curve: Curves.linear,
      );
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
    _animate(); // Recursively call to keep checking for dynamic content
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      controller: _scrollController,
      child: widget.child,
    );
  }
}

class MusicNotesFloatingAnimation extends StatefulWidget {
  const MusicNotesFloatingAnimation({super.key});

  @override
  State<MusicNotesFloatingAnimation> createState() =>
      _MusicNotesFloatingAnimationState();
}

class _MusicNotesFloatingAnimationState
    extends State<MusicNotesFloatingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  // Use a simple list of active notes with their properties
  final List<MusicNote> _notes = [];
  final math.Random _random = math.Random();
  Timer? _spawnTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Loop duration (not note lifetime)
    )..repeat();

    // Add listener to update positions on every tick
    _controller.addListener(_updateNotes);

    // Spawn new notes periodically
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (mounted) {
        _addNote();
      }
    });

    // Add initial note
    _addNote();
  }

  void _addNote() {
    setState(() {
      _notes.add(
        MusicNote(
          id: DateTime.now().microsecondsSinceEpoch,
          x: (_random.nextDouble() * 40) - 20, // -20 to 20
          y: 0,
          opacity: 1.0,
          icon: _random.nextBool()
              ? Icons.music_note_rounded
              : Icons.music_video_rounded,
          color: const Color(0xFF00FFD1), // Single clear Cyan color
        ),
      );
    });
  }

  void _updateNotes() {
    if (!mounted) return;
    setState(() {
      // Update existing notes
      for (var note in _notes) {
        note.y += 2.0; // Move up faster and clearer
        // Let's use bottom: note.y

        note.opacity -= 0.015; // Fade out
      }
      // Remove invisible notes
      _notes.removeWhere((note) => note.opacity <= 0);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateNotes);
    _controller.dispose();
    _spawnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 120, // Taller to allow floating up higher
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: _notes.map((note) {
          return Positioned(
            bottom: note.y + 20, // Start just above seat
            left: 25 + note.x - 12, // Center horizontally + offset
            child: Opacity(
              opacity: note.opacity.clamp(0.0, 1.0),
              child: Icon(
                note.icon,
                size: 28,
                color: note.color,
              ), // Larger size
            ),
          );
        }).toList(),
      ),
    );
  }
}

class MusicNote {
  final int id;
  final double x;
  double y;
  double opacity;
  final IconData icon;
  final Color color;

  MusicNote({
    required this.id,
    required this.x,
    required this.y,
    required this.opacity,
    required this.icon,
    required this.color,
  });
}

class _RoomAutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _RoomAutoScrollText({required this.text, required this.style});

  @override
  State<_RoomAutoScrollText> createState() => _RoomAutoScrollTextState();
}

class _RoomAutoScrollTextState extends State<_RoomAutoScrollText> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    if (!mounted) return;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(_scrollController.offset + 1);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check text length, if short, don't scroll
    final textSpan = TextSpan(text: widget.text, style: widget.style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: double.infinity);

    final textWidth = textPainter.width;

    // We can't know constraints easily here without LayoutBuilder.
    // Assuming Seat name width is small (approx 50-60).
    // If text is somewhat long, we scroll.
    if (textWidth < 50) {
      return Center(child: Text(widget.text, style: widget.style));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style),
          const SizedBox(width: 30),
          Text(widget.text, style: widget.style),
          const SizedBox(width: 30),
          Text(widget.text, style: widget.style),
          const SizedBox(width: 30),
        ],
      ),
    );
  }
}

class _RotatingAura extends StatefulWidget {
  final Color color;
  const _RotatingAura({required this.color});

  @override
  State<_RotatingAura> createState() => _RotatingAuraState();
}

class _RotatingAuraState extends State<_RotatingAura>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RotationTransition(
        turns: _controller,
        child: SizedBox(
          width: 44,
          height: 44,
          child: CustomPaint(painter: _StarDotsPainter()),
        ),
      ),
    );
  }
}

class _StarDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final dotPaint = Paint()..color = Colors.white;
    final ringPaint = Paint()..color = Colors.black.withOpacity(0.3);

    // قرص أسود خلفي لجعل الحركة واضحة تماماً
    canvas.drawCircle(center, radius, ringPaint);

    // رسم نقطة بيضاء واحدة لتمييز الدوران بوضوح وببساطة
    const double angle = 0.0;
    const double dotRadius = 2.0;

    final double x = center.dx + radius * 0.8 * math.cos(angle);
    final double y = center.dy + radius * 0.8 * math.sin(angle);

    canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _MusicDiscIcon extends StatefulWidget {
  const _MusicDiscIcon();

  @override
  State<_MusicDiscIcon> createState() => _MusicDiscIconState();
}

class _MusicDiscIconState extends State<_MusicDiscIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Image.asset(
        'assets/images/disc music.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.album_rounded, color: Colors.blueAccent, size: 24),
      ),
    );
  }
}

class _TalkingPulse extends StatefulWidget {
  final Widget child;
  final bool isTalking;

  const _TalkingPulse({
    super.key,
    required this.child,
    required this.isTalking,
  });

  @override
  State<_TalkingPulse> createState() => _TalkingPulseState();
}

class _TalkingPulseState extends State<_TalkingPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isTalking) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_TalkingPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTalking && !oldWidget.isTalking) {
      _controller.repeat();
    } else if (!widget.isTalking && oldWidget.isTalking) {
      _controller.stop();
      _controller.reset();
    }
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
      clipBehavior: Clip.none,
      children: [
        if (widget.isTalking)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Pulse 1
                  _buildPulseRing(
                    1.0 + (_controller.value * 0.4),
                    (1.0 - _controller.value).clamp(0.0, 1.0),
                  ),
                  // Pulse 2 (offset)
                  _buildPulseRing(
                    1.0 + (((_controller.value + 0.5) % 1.0) * 0.4),
                    (1.0 - ((_controller.value + 0.5) % 1.0)).clamp(0.0, 1.0),
                  ),
                ],
              );
            },
          ),
        widget.child,
      ],
    );
  }

  Widget _buildPulseRing(double scale, double opacity) {
    return IgnorePointer(
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF00FFD1).withOpacity(opacity * 0.9),
              width: 3.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticGiftPopUp extends StatefulWidget {
  final String imageUrl;
  final String? senderName;
  final String? receiverName;
  final String? giftName;
  final int quantity;
  final VoidCallback onComplete;
  final Offset offset;

  const _StaticGiftPopUp({
    super.key,
    required this.imageUrl,
    this.senderName,
    this.receiverName,
    this.giftName,
    this.quantity = 1,
    required this.onComplete,
    this.offset = Offset.zero,
  });

  @override
  State<_StaticGiftPopUp> createState() => _StaticGiftPopUpState();
}

class _StaticGiftPopUpState extends State<_StaticGiftPopUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  int _currentCount = 1;
  Timer? _countTimer;

  @override
  void initState() {
    super.initState();

    // Natural counting speed: ~150ms per gift
    // If quantity is very high, we cap the total counting time to 6 seconds
    final int countIntervalMs = widget.quantity <= 1
        ? 0
        : (6000 / widget.quantity).round().clamp(100, 250);

    final int totalCountingTimeMs = widget.quantity > 1
        ? countIntervalMs * widget.quantity
        : 0;

    // Total duration = Intro (500ms) + Counting + Outro (500ms) + Stay (1s)
    final int totalDurationMs = (2000 + totalCountingTimeMs).clamp(3000, 10000);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalDurationMs),
    );

    // Weights are percentages of total duration
    // Intro: ~10%, Stay: ~80%, Outro: ~10%
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 5,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 75),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInBack)),
        weight: 10,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 80),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
    ]).animate(_controller);

    _slideAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0, -0.05)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: const Offset(0, -0.05),
          end: const Offset(0, -0.2),
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_controller);

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    // Handle count increments with consistent timing
    if (widget.quantity > 1) {
      // Start counting after intro settle (approx 500ms)
      Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _countTimer = Timer.periodic(Duration(milliseconds: countIntervalMs), (
          timer,
        ) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() {
            if (_currentCount < widget.quantity) {
              _currentCount++;
            } else {
              timer.cancel();
            }
          });
        });
      });
    }

    // Safety timeout
    Future.delayed(Duration(milliseconds: totalDurationMs + 1000), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _countTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.translate(
                  offset:
                      (_slideAnimation.value *
                          MediaQuery.of(context).size.height) +
                      widget.offset,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior:
                          Clip.none, // Prevents clipping of the number card
                      children: [
                        // The Gift Image
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CachedNetworkImage(
                            imageUrl: widget.imageUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) =>
                                const SizedBox.shrink(),
                            errorWidget: (context, url, error) =>
                                const SizedBox.shrink(),
                          ),
                        ),

                        // MULTI-GIFT COUNT LABEL
                        if (widget.quantity > 1 || _currentCount > 1)
                          Positioned(
                            right: 0, // Positioned at the edge
                            bottom: 30,
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey(_currentCount),
                              tween: Tween(begin: 1.4, end: 1.0),
                              duration: const Duration(milliseconds: 200),
                              builder: (context, scale, child) =>
                                  Transform.scale(
                                    scale: scale,
                                    child: Transform.rotate(
                                      angle: 0.05, // Subtle tilt
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(
                                            0.7,
                                          ), // Transparent Black
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.4,
                                            ),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.4,
                                              ),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'x$_currentCount',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 32,
                                                fontWeight: FontWeight.w900,
                                                fontFamily: 'Tajawal',
                                                letterSpacing: -1,
                                                shadows: [
                                                  // BEAMING WHITE GLOW
                                                  Shadow(
                                                    color: Colors.white
                                                        .withOpacity(0.4),
                                                    blurRadius: 12,
                                                  ),
                                                  Shadow(
                                                    color: Colors.white
                                                        .withOpacity(0.4),
                                                    blurRadius: 20,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                            ),
                          ),

                        // Text Info
                        if (widget.senderName != null)
                          Positioned(
                            top: -40,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.senderName!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tajawal',
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                                const Text(
                                  'أهدى',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (widget.receiverName != null)
                          Positioned(
                            bottom: -40,
                            child: Text(
                              'إلى ${widget.receiverName}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 10),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
