import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/voice_room_screen.dart'; // For navigation
import 'framed_avatar.dart';

class GlobalGiftBanner extends StatefulWidget {
  final Function(String)? onGlobalVideoReceived;

  const GlobalGiftBanner({super.key, this.onGlobalVideoReceived});

  @override
  State<GlobalGiftBanner> createState() => _GlobalGiftBannerState();
}

class _GlobalGiftBannerState extends State<GlobalGiftBanner>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _currentAnnouncement;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  final List<Map<String, dynamic>> _queue = [];
  bool _isProcessing = false;
  final Set<String> _seenDocIds = {};

  StreamSubscription? _subscription;
  DateTime? _announcementStartTime;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(
        seconds: 10,
      ), // Increased duration for better visibility
      vsync: this,
    );

    // Start from left (-1.5) and move to right (1.5)
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(-1.5, 0.0),
      end: const Offset(1.5, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleSlideCompletion();
      }
    });

    _listenForAnnouncements();
  }

  void _listenForAnnouncements() {
    // Only listen for announcements that happen AFTER we join the room
    final now = DateTime.now();

    _subscription = FirebaseFirestore.instance
        .collection('global_announcements')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(now))
        .orderBy(
          'timestamp',
          descending: false,
        )
        .snapshots()
        .listen((snapshot) {
          bool added = false;
          for (var doc in snapshot.docs) {
            if (!_seenDocIds.contains(doc.id)) {
              _seenDocIds.add(doc.id);
              _queue.add(doc.data());
              added = true;
            }
          }
          if (added) {
            if (!_isProcessing) {
              _processQueue();
            } else {
              _interruptAndShowNext();
            }
          }
        });
  }

  void _processQueue() {
    if (_isProcessing) return;

    if (_queue.isNotEmpty) {
      _isProcessing = true;
      final next = _queue.removeAt(0);

      if (mounted) {
        setState(() {
          _currentAnnouncement = next;
          _announcementStartTime = DateTime.now();
        });

        if (next['lottieUrl'] != null &&
            next['lottieUrl'].toString().isNotEmpty) {
          widget.onGlobalVideoReceived?.call(next['lottieUrl']);
        }

        _controller.forward(from: 0.0);
      }
    } else {
      _isProcessing = false;
      if (mounted) {
        setState(() {
          _currentAnnouncement = null;
          _announcementStartTime = null;
        });
      }
    }
  }

  void _interruptAndShowNext() {
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);

      if (mounted) {
        setState(() {
          _currentAnnouncement = next;
          _announcementStartTime = DateTime.now();
        });

        if (next['lottieUrl'] != null &&
            next['lottieUrl'].toString().isNotEmpty) {
          widget.onGlobalVideoReceived?.call(next['lottieUrl']);
        }

        // Restart the sliding animation immediately for the new gift
        _controller.forward(from: 0.0);
      }
    }
  }

  void _handleSlideCompletion() {
    if (!mounted) return;

    // 1. If there are other gifts in the queue, immediately process them
    if (_queue.isNotEmpty) {
      _isProcessing = false;
      _processQueue();
      return;
    }

    // 2. If no other gifts are waiting, the current gift is "alone".
    // Check if it has been sliding for less than 1 minute.
    if (_announcementStartTime != null) {
      final elapsed = DateTime.now().difference(_announcementStartTime!);
      if (elapsed < const Duration(minutes: 1)) {
        // Repeat the slide animation continuously
        _controller.forward(from: 0.0);
        return;
      }
    }

    // 3. One minute has passed, or start time is missing. Dismiss the banner.
    _isProcessing = false;
    _processQueue();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentAnnouncement == null) return const SizedBox.shrink();

    final data = _currentAnnouncement!;
    final senderId = data['senderId'];
    final realSenderName = data['senderName'] ?? 'Unknown';
    final senderImage = data['senderImage'];
    final receiverName = data['receiverName'] ?? 'Unknown';
    final receiverImage = data['receiverImage'];
    final giftIcon = data['giftIcon'] ?? '🎁';

    // Privacy & Contextual Text Logic
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final receiverId = data['receiverId'];
    final bool isMeSender = (senderId != null && senderId == currentUserId);
    final bool isMeReceiver = (receiverId != null && receiverId == currentUserId);

    final displaySenderName = isMeSender ? 'أنت' : realSenderName;

    final String contextualText;
    if (isMeSender) {
      contextualText = 'أرسلت هدية قيمة إلى';
    } else if (isMeReceiver) {
      contextualText = 'أرسل لك هدية قيمة';
    } else {
      contextualText = 'أرسل هدية قيمة إلى';
    }

    // Safe Room ID display
    String roomDisplay =
        data['roomDisplayId']?.toString() ??
        data['roomId']?.toString() ??
        'Room';
    if (roomDisplay.length > 8) {
      roomDisplay = roomDisplay.substring(0, 8);
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SlideTransition(
        position: _offsetAnimation,
        child: GestureDetector(
          onTap: () {
            if (data['roomId'] != null) {
              _showNavigationDialog(context, data['roomId']);
            }
          },
          child: Container(
            height: 60,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1. Premium Glow Background
                Container(
                  width: double.infinity,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: data['currency'] == 'meto'
                            ? Colors.red.withValues(alpha: 0.4)
                            : Colors.amber.withValues(alpha: 0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // 2. Main Banner Body
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: data['currency'] == 'meto'
                          ? [
                              Colors.transparent,
                              const Color(0xFF330000), // Dark Red
                              const Color(0xFF660000).withValues(alpha: 0.8), // Bright Red Trans
                              const Color(0xFF330000),
                              Colors.transparent,
                            ]
                          : [
                              Colors.transparent,
                              const Color(0xFF1A1A1A),
                              const Color(0xFF2A1F00),
                              const Color(0xFF1A1A1A),
                              Colors.transparent,
                            ],
                      stops: const [0.0, 0.1, 0.5, 0.9, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: data['currency'] == 'meto'
                            ? Colors.redAccent.withValues(alpha: 0.6)
                            : Colors.amber.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // A. Sender Avatar and Name
                        _buildUserInfo(
                          userId: senderId,
                          imageUrl: senderImage,
                          name: displaySenderName,
                          nameColor: Colors.amber,
                          isSender: true,
                        ),

                        // B. Contextual Text
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            contextualText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),

                        // C. Receiver Avatar and Name (Omitted if the current user is the receiver)
                        if (!isMeReceiver)
                          _buildUserInfo(
                            userId: receiverId,
                            imageUrl: receiverImage,
                            name: receiverName,
                            nameColor: Colors.cyanAccent,
                            isSender: false,
                          ),

                        const SizedBox(width: 20),

                        // D. The Gift Icon
                        _buildGiftWidget(giftIcon),

                        const SizedBox(width: 8),

                        // E. Gift Quantity
                        Text(
                          'x${data['quantity'] ?? 1}',
                          style: const TextStyle(
                            color: Colors.yellowAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Tajawal',
                            fontStyle: FontStyle.italic,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Room ID Badge - Top Right
                Positioned(
                  top: -10,
                  right: 30, // Positioned on the RIGHT as requested
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFA500), Color(0xFFFF4500)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'ID: $roomDisplay',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Tajawal',
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

  void _showNavigationDialog(BuildContext context, String roomId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        title: const Text(
          'انتقال للمشاركة',
          style: TextStyle(
            color: Colors.amber,
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'هل ترغب في الانتقال إلى الغرفة ومشاركة الاحتفال؟',
          style: TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VoiceRoomScreen(roomId: roomId),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'انضم الآن',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo({
    required String? userId,
    required String? imageUrl,
    required String name,
    required Color nameColor,
    required bool isSender,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSender
                    ? [Colors.amber, Colors.orange]
                    : [Colors.cyan, Colors.blueAccent],
              ),
              shape: BoxShape.circle,
            ),
            child: FramedAvatar(
              userId: userId,
              imageUrl: (imageUrl != null && imageUrl.trim().startsWith('http'))
                  ? imageUrl.trim()
                  : null,
              radius: 17,
              disableFrame: true,
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              name,
              style: TextStyle(
                color: nameColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                fontFamily: 'Tajawal',
                shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftWidget(String giftIcon) {
    final String iconStr = giftIcon.trim();
    final bool isUrl = iconStr.toLowerCase().startsWith('http');
    final bool isAsset = iconStr.toLowerCase().contains('assets/');

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: isUrl
          ? Image.network(iconStr, width: 48, height: 48, fit: BoxFit.contain)
          : isAsset
          ? Image.asset(iconStr, width: 48, height: 48, fit: BoxFit.contain)
          : Text(
              iconStr.length > 4 ? '🎁' : iconStr,
              style: const TextStyle(fontSize: 35),
            ),
    );
  }
}
