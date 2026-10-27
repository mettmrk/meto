// ignore_for_file: unused_local_variable

import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/competition_model.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'speed_challenge_play_screen.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/fcm_service.dart';
import 'package:share_plus/share_plus.dart';

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  // Cache for participant names to prevent flickering during sync
  final Map<String, List<String>> _participantNamesCache = {};
  Timer? _competitionTimer;

  @override
  void initState() {
    super.initState();
    _startCompetitionTimer();
  }

  @override
  void dispose() {
    _competitionTimer?.cancel();
    super.dispose();
  }

  void _startCompetitionTimer() {
    _competitionTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkCompetitionsTime();
    });
  }

  Future<void> _checkCompetitionsTime() async {
    try {
      final now = DateTime.now();
      // Only run expensive logic every 10 seconds or so,
      // but the timer runs every second for the UI.
      if (now.second % 10 != 0) return;

      final snapshot = await _firestore
          .collection('competitions')
          .where('status', isEqualTo: 'active')
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final endTime = (data['endTime'] as Timestamp?)?.toDate();
        final isSent = data['endNotificationSent'] ?? false;

        if (endTime != null && now.isAfter(endTime) && !isSent) {
          await _finalizeCompetition(doc.id, data);
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _finalizeCompetition(
    String compId,
    Map<String, dynamic> data,
  ) async {
    try {
      // 1. Mark as processing to avoid race conditions
      await _firestore.collection('competitions').doc(compId).update({
        'endNotificationSent': true,
      });

      final String type = data['type'] ?? '';
      final String title = data['title'] ?? 'المسابقة';

      String? winnerId;
      String? winnerName;
      String? winnerPhoto;

      if (type == 'مشاركة التطبيق') {
        // Winner is the one with most referrals among participants
        final List<String> participants = List<String>.from(
          data['participants'] ?? [],
        );
        if (participants.isNotEmpty) {
          int maxReferrals = -1;
          for (String uid in participants) {
            final userDoc = await _firestore.collection('users').doc(uid).get();
            if (userDoc.exists) {
              final referrals =
                  (userDoc.data()?['referredUsers'] as List?)?.length ?? 0;
              if (referrals > maxReferrals) {
                maxReferrals = referrals;
                winnerId = uid;
                winnerName =
                    userDoc.data()?['nickname'] ?? userDoc.data()?['username'];
                winnerPhoto = userDoc.data()?['profileImage'];
              }
            }
          }
        }
      } else if (type == 'تصويت') {
        final List votesA = data['votesA'] ?? [];
        final List votesB = data['votesB'] ?? [];
        final String? teamA = data['teamA'];
        final String? teamB = data['teamB'];

        String? winningTeam;
        List? winnersList;

        if (votesA.length > votesB.length) {
          winningTeam = teamA;
          winnersList = votesA;
        } else if (votesB.length > votesA.length) {
          winningTeam = teamB;
          winnersList = votesB;
        }

        if (winnersList != null && winnersList.isNotEmpty) {
          // Pick a random winner from the winning team
          winnerId =
              winnersList[DateTime.now().millisecond % winnersList.length];
          final userDoc = await _firestore
              .collection('users')
              .doc(winnerId!)
              .get();
          winnerName =
              userDoc.data()?['nickname'] ?? userDoc.data()?['username'];
          winnerPhoto = userDoc.data()?['profileImage'];
        }
      } else {
        // Default: random participant
        final List<String> participants = List<String>.from(
          data['participants'] ?? [],
        );
        if (participants.isNotEmpty) {
          winnerId =
              participants[DateTime.now().millisecond % participants.length];
          final userDoc = await _firestore
              .collection('users')
              .doc(winnerId)
              .get();
          winnerName =
              userDoc.data()?['nickname'] ?? userDoc.data()?['username'];
          winnerPhoto = userDoc.data()?['profileImage'];
        }
      }

      // Update competition status
      await _firestore.collection('competitions').doc(compId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'winnerUserId': winnerId,
        'winnerName': winnerName,
        'winnerPhoto': winnerPhoto,
      });

      // Send Global Notification
      await FCMService.sendGlobalNotification(
        title: '🏆 مبروك للفائز!',
        body: winnerName != null
            ? 'انتهت مسابقة "$title" وفاز بها المبدع $winnerName! مبروك وعقبال الجميع.'
            : 'انتهت مسابقة "$title" بنجاح. شكراً لجميع المشاركين!',
      );
    } catch (e) {
      print("Error finalizing competition: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('app_settings').doc('global').snapshots(),
      builder: (context, settingsSnap) {
        final settingsData =
            settingsSnap.data?.data() as Map<String, dynamic>? ?? {};
        final bool isEnabled = settingsData['isCompetitionsEnabled'] ?? true;

        if (!isEnabled) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            appBar: AppBar(
              title: const Text('المسابقات'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_clock_rounded,
                    color: Colors.amber,
                    size: 80,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'المسابقات مغلقة حالياً',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ترقبوا انطلاق المسابقات الجديدة قريباً!',
                    style: GoogleFonts.tajawal(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'المسابقات المركزية',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('competitions')
                    .where('status', whereIn: ['active', 'rolling'])
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.amber,
                          size: 20,
                        ),
                        tooltip: 'العامة',
                        onPressed: () => _showGlobalChat(context),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('competitions')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'خطأ في التحميل: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final competitions =
                  snapshot.data?.docs.map((doc) {
                    return Competition.fromMap(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    );
                  }).toList() ??
                  [];

              if (competitions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 80,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'لا توجد مسابقات حالياً',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 18,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                itemCount: competitions.length,
                itemBuilder: (context, index) =>
                    _buildCompetitionCard(competitions[index]),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCompetitionCard(Competition comp) {
    final String currentUserId = _auth.currentUser?.uid ?? '';
    final bool hasVotedA = comp.votesA.contains(currentUserId);
    final bool hasVotedB = comp.votesB.contains(currentUserId);
    final bool hasVoted = hasVotedA || hasVotedB;

    final bool isEnded = comp.endTime != null && 
        comp.endTime!.difference(DateTime.now()).isNegative;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with Prize
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusBadge(
                          comp.status,
                          isEnded: isEnded,
                        ),
                        if (comp.status == CompetitionStatus.active &&
                            comp.endTime != null) ...[
                          const SizedBox(width: 8),
                          _buildLiveTimer(comp.endTime!),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildRewardButton(comp),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comp.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  comp.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    fontFamily: 'Tajawal',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),

                if ((comp.status == CompetitionStatus.active && !isEnded) ||
                    (comp.status == CompetitionStatus.rolling &&
                        comp.type == 'تساقط فردي'))
                  comp.type == 'تصويت'
                      ? _buildVotingSection(
                          comp,
                          hasVoted,
                          hasVotedA,
                          hasVotedB,
                        )
                      : comp.type == 'تساقط فردي'
                      ? _buildEliminationSection(comp, currentUserId)
                      : comp.type == 'مشاركة التطبيق'
                      ? _buildShareAppSection(comp, currentUserId)
                      : comp.type == 'اجمل صورة'
                      ? _buildPhotoContestSection(comp, currentUserId)
                      : _buildGeneralJoinSection(comp, currentUserId)
                else if (comp.status == CompetitionStatus.rolling)
                  _buildRollingSection(comp)
                else
                  _buildCompletedSection(comp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTimer(DateTime endTime) {
    final isEnded = endTime.difference(DateTime.now()).isNegative;
    final color = isEnded ? Colors.redAccent : Colors.amber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pulsing Dot
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 1.5),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) {
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color.withOpacity(2 - value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: value * 2,
                    ),
                  ],
                ),
              );
            },
            onEnd: () {}, // Re-triggering via parent setState
          ),
          const SizedBox(width: 6),
          LiveCountdownWidget(endTime: endTime),
        ],
      ),
    );
  }

  void _showGlobalChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) =>
          const CompetitionChatSheet(compId: 'global', title: ' العامة'),
    );
  }

  Widget _buildStatusBadge(CompetitionStatus status, {bool isEnded = false}) {
    Color color;
    String label;
    IconData icon;

    if (status == CompetitionStatus.active && isEnded) {
      color = Colors.blueAccent;
      label = 'مكتملة';
      icon = Icons.check_circle_rounded;
    } else {
      switch (status) {
        case CompetitionStatus.active:
          color = Colors.greenAccent;
          label = 'نشط الآن';
          icon = Icons.bolt_rounded;
          break;
        case CompetitionStatus.rolling:
          color = Colors.amber;
          label = 'جاري السحب';
          icon = Icons.autorenew_rounded;
          break;
        case CompetitionStatus.completed:
          color = Colors.blueAccent;
          label = 'مكتملة';
          icon = Icons.check_circle_rounded;
          break;
        case CompetitionStatus.cancelled:
          color = Colors.redAccent;
          label = 'ملغاة';
          icon = Icons.cancel_rounded;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardButton(Competition comp) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'مكافأة المسابقة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildRewardGrid(comp),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'حسناً',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 12),
            const SizedBox(width: 4),
            const Text(
              'المكافآت',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardGrid(Competition comp) {
    List<Widget> cards = [];

    // Main Prize
    if (comp.prizeAmount > 0) {
      if (comp.prizeCurrency == 'diamonds') {
        cards.add(_buildSquareRewardCard(
          icon: Icons.diamond_rounded,
          iconColor: Colors.blueAccent,
          title: '${comp.prizeAmount}\nالماس',
        ));
      } else if (comp.prizeCurrency == 'coins') {
        cards.add(_buildSquareRewardCard(
          icon: Icons.monetization_on_rounded,
          iconColor: Colors.amber,
          title: '${comp.prizeAmount}\nذهب',
        ));
      } else {
        cards.add(_buildSquareRewardLocalAssetCard(
          'assets/images/coinsmeto.png',
          '${comp.prizeAmount}\nعملة ميتو',
        ));
      }
    }

    // Exclusive items
    if (comp.exclusiveFrame != null) {
      cards.add(_buildSquareRewardAssetCard(comp.exclusiveFrame!, 'إطار بروفايل'));
    }
    if (comp.profileDeco != null) {
      cards.add(_buildSquareRewardAssetCard(comp.profileDeco!, 'زينة بروفايل'));
    }
    if (comp.roomBg != null) {
      cards.add(_buildSquareRewardAssetCard(comp.roomBg!, 'خلفية غرفة'));
    }
    if (comp.exclusiveEntrance != null) {
      cards.add(_buildSquareRewardAssetCard(comp.exclusiveEntrance!, 'دخولية'));
    }
    if (comp.exclusiveWallHanging != null) {
      cards.add(_buildSquareRewardAssetCard(comp.exclusiveWallHanging!, 'معلقة جدارية'));
    }
    if (comp.exclusiveRoomCardFrame != null) {
      cards.add(_buildSquareRewardAssetCard(comp.exclusiveRoomCardFrame!, 'إطار بطاقة'));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: cards,
    );
  }

  Widget _buildSquareRewardLocalAssetCard(String assetPath, String title) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(assetPath, width: 30, height: 30),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareRewardCard({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareRewardAssetCard(String url, String title) {
    return GestureDetector(
      onTap: () => _showAssetPreview(url, title),
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: url.startsWith('http')
                  ? (url.endsWith('.json')
                      ? Lottie.network(url, fit: BoxFit.contain)
                      : CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          placeholder: (context, url) =>
                              const Icon(Icons.image, size: 20, color: Colors.amber),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.broken_image, size: 20, color: Colors.amber),
                        ))
                  : const Icon(Icons.card_giftcard, size: 30, color: Colors.amber),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeBadge(Competition comp) {
    Color color = Colors.amber;
    IconData icon = Icons.emoji_events_rounded;
    if (comp.prizeCurrency == 'diamonds') {
      color = Colors.blueAccent;
      icon = Icons.diamond_rounded;
    } else if (comp.prizeCurrency == 'meto') {
      color = Colors.tealAccent;
      icon = Icons.token_rounded;
    } else if (comp.prizeCurrency == 'coins') {
      color = Colors.amber;
      icon = Icons.monetization_on_rounded;
    }

    bool hasExclusive =
        comp.exclusiveFrame != null ||
        comp.profileDeco != null ||
        comp.roomBg != null ||
        comp.exclusiveEntrance != null ||
        comp.exclusiveWallHanging != null ||
        comp.exclusiveRoomCardFrame != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (hasExclusive) ...[
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (comp.exclusiveFrame != null)
                    _buildSmallAssetThumb(
                      comp.exclusiveFrame!,
                      Icons.filter_tilt_shift_rounded,
                      'إطار بروفايل حصري',
                    ),
                  if (comp.profileDeco != null)
                    _buildSmallAssetThumb(
                      comp.profileDeco!,
                      Icons.auto_awesome_rounded,
                      'زينة بروفايل حصرية',
                    ),
                  if (comp.roomBg != null)
                    _buildSmallAssetThumb(
                      comp.roomBg!,
                      Icons.wallpaper_rounded,
                      'خلفية غرفة حصرية',
                    ),
                  if (comp.exclusiveEntrance != null)
                    _buildSmallAssetThumb(
                      comp.exclusiveEntrance!,
                      Icons.login_rounded,
                      'دخولية حصرية',
                    ),
                  if (comp.exclusiveWallHanging != null)
                    _buildSmallAssetThumb(
                      comp.exclusiveWallHanging!,
                      Icons.landscape_rounded,
                      'معلقة جدارية حصرية',
                    ),
                  if (comp.exclusiveRoomCardFrame != null)
                    _buildSmallAssetThumb(
                      comp.exclusiveRoomCardFrame!,
                      Icons.crop_original_rounded,
                      'إطار بطاقة غرفة حصري',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],

        if (comp.prizeAmount > 0) ...[
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                comp.prizeAmount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, color: color, size: 20),
        ],
      ],
    );
  }

  Widget _buildSmallAssetThumb(
    String url,
    IconData fallbackIcon,
    String title,
  ) {
    return GestureDetector(
      onTap: () => _showAssetPreview(url, title),
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: url.startsWith('http')
              ? (url.endsWith('.json')
                    ? Lottie.network(url, fit: BoxFit.cover)
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Icon(fallbackIcon, size: 14, color: Colors.amber),
                        errorWidget: (context, url, error) =>
                            Icon(fallbackIcon, size: 14, color: Colors.amber),
                      ))
              : Icon(fallbackIcon, size: 14, color: Colors.amber),
        ),
      ),
    );
  }

  void _showAssetPreview(String url, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 250,
                    width: 250,
                    child: url.startsWith('http')
                        ? (url.endsWith('.json')
                              ? Lottie.network(url, fit: BoxFit.contain)
                              : CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.amber,
                                    ),
                                  ),
                                ))
                        : const Icon(
                            Icons.broken_image,
                            size: 80,
                            color: Colors.white24,
                          ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'جائزة حصرية للفائز في المسابقة',
                    style: GoogleFonts.tajawal(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'إغلاق',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildVotingSection(
    Competition comp,
    bool hasVoted,
    bool hasVotedA,
    bool hasVotedB,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTeamVoteCard(
                comp.teamA,
                comp.teamAImage,
                Colors.blue,
                hasVotedA,
                hasVoted,
                () => _vote(comp.id, 'A'),
                comp.votesA.length,
                comp.votesA.length + comp.votesB.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'VS',
                style: TextStyle(
                  color: Colors.white24,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
            ),
            Expanded(
              child: _buildTeamVoteCard(
                comp.teamB,
                comp.teamBImage,
                Colors.red,
                hasVotedB,
                hasVoted,
                () => _vote(comp.id, 'B'),
                comp.votesB.length,
                comp.votesA.length + comp.votesB.length,
              ),
            ),
          ],
        ),
        if (hasVoted)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.greenAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'تم تسجيل تصويتك بنجاح، انتظر السحب!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEliminationSection(Competition comp, String userId) {
    final bool hasJoined = comp.participants.contains(userId);
    final bool isEliminated = comp.eliminated.contains(userId);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Gold Outer Frame
            Container(
              height: 320,
              width: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFD4AF37),
                    Color(0xFFFFD700),
                    Color(0xFFB8860B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(color: const Color(0xFF8B4513), width: 2),
              ),
            ),
            // Inner Background
            Container(
              height: 300,
              width: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1E293B),
              ),
              child: StreamBuilder<List<String>>(
                stream: _getParticipantNames(
                  comp.rouletteParticipants.isNotEmpty
                      ? comp.rouletteParticipants
                      : comp.participants,
                ),
                builder: (context, snapshot) {
                  List<String> names =
                      snapshot.data ?? _participantNamesCache[comp.id] ?? [];
                  if (snapshot.hasData) {
                    _participantNamesCache[comp.id] = snapshot.data!;
                  }

                  if (names.length < 2) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.group_add_rounded,
                            color: Colors.amber,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            names.isEmpty
                                ? 'كن أول المشتركين!'
                                : 'بانتظار مشترك آخر للروليت...',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                          if (names.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                names.first,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  return SynchedFortuneWheel(
                    key: ValueKey('wheel_${comp.id}'),
                    targetIndex: comp.spinTargetIndex,
                    names: names,
                    onAnimationEnd: () {
                      if (comp.status == CompetitionStatus.rolling &&
                          comp.spinTargetIndex != null &&
                          comp.rouletteParticipants.isNotEmpty &&
                          comp.rouletteParticipants[comp.spinTargetIndex!] ==
                              userId) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'حظ أوفر في المرة القادمة! لقد تم استبعادك.',
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
            // Center Gold Pin
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                ),
                border: Border.all(color: Colors.white24, width: 1),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (comp.lastEliminatedName != null)
          _buildLastEliminatedCard(
            comp.lastEliminatedName!,
            comp.lastEliminatedPhoto,
          ),
        const SizedBox(height: 16),
        if (comp.status == CompetitionStatus.rolling)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              '⚠️ جاري السحب للاستبعاد... لا يمكن الاشتراك الآن',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed:
                (hasJoined ||
                    isEliminated ||
                    comp.status == CompetitionStatus.rolling)
                ? null
                : () => _joinCompetition(comp.id),
            icon: Icon(
              isEliminated
                  ? Icons.block
                  : (hasJoined ? Icons.check_circle : Icons.stars_rounded),
            ),
            label: Text(
              isEliminated
                  ? 'تم استبعادك (حظ أوفر)'
                  : (hasJoined
                        ? 'تم الاشتراك (${comp.participants.length}/100)'
                        : 'اشترك الآن في الروليت'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isEliminated
                  ? Colors.redAccent.withOpacity(0.2)
                  : (comp.status == CompetitionStatus.rolling)
                  ? Colors.grey[800]
                  : hasJoined
                  ? Colors.green[600]
                  : Colors.amber,
              foregroundColor: isEliminated
                  ? Colors.redAccent
                  : (comp.status == CompetitionStatus.rolling)
                  ? Colors.white54
                  : hasJoined
                  ? Colors.white
                  : Colors.black,
              disabledBackgroundColor: isEliminated
                  ? Colors.redAccent.withOpacity(0.2)
                  : (comp.status == CompetitionStatus.rolling)
                  ? Colors.grey[800]
                  : hasJoined
                  ? Colors.green[600]
                  : Colors.grey[800],
              disabledForegroundColor: isEliminated
                  ? Colors.redAccent
                  : (comp.status == CompetitionStatus.rolling)
                  ? Colors.white54
                  : hasJoined
                  ? Colors.white
                  : Colors.white38,
              elevation:
                  (isEliminated || comp.status == CompetitionStatus.rolling)
                  ? 0
                  : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Stream<List<String>> _getParticipantNames(List<String> uids) async* {
    if (uids.isEmpty) {
      yield [];
      return;
    }

    try {
      // Fetch up to 10 users at once for basic real-time feel, or all if small
      // For large lists, we should ideally fetch in chunks or use a more efficient way
      final List<String> names = [];

      // Limit to 100 as requested
      final limitedUids = uids.take(100).toList();

      // Batch fetch users
      final userDocs = await Future.wait(
        limitedUids.map((uid) => _firestore.collection('users').doc(uid).get()),
      );

      for (var doc in userDocs) {
        final data = doc.data();
        final String rawNickname = data?['nickname'] ?? '';
        final String rawUsername = data?['username'] ?? '';
        final String name = rawNickname.trim().isNotEmpty
            ? rawNickname
            : (rawUsername.trim().isNotEmpty ? rawUsername : 'لاعب ميتو');
        names.add(name);
      }
      yield names;
    } catch (e) {
      yield uids.map((_) => 'متسابق').toList();
    }
  }

  Widget _buildShareAppSection(Competition comp, String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final String referralCode = userData['referralCode']?.toString() ?? '';
        final List<dynamic> referredUsers = userData['referredUsers'] ?? [];
        final int sharesCount = referredUsers.length;

        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  final String shareText =
                      'حمل تطبيق ميتو الآن واستمتع! استخدم كود الدعوة الخاص بي: $referralCode\nhttps://meto-app.com';
                  Share.share(shareText);

                  if (!comp.participants.contains(userId)) {
                    _joinCompetition(comp.id);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
                icon: const Icon(Icons.share_rounded, size: 24),
                label: const Text(
                  'مشاركة التطبيق',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_alt_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'عدد الدعوات الناجحة: $sharesCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGeneralJoinSection(Competition comp, String currentUserId) {
    final bool hasJoined =
        comp.participants.contains(currentUserId) ||
        comp.answers.containsKey(currentUserId);
    final TextEditingController _answerController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (comp.type == 'جاوب صح' || comp.type == 'خمن') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: comp.type == 'خمن'
                            ? Colors.blueAccent
                            : Colors.amber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        comp.type == 'خمن' ? 'تخمين' : 'سؤال',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        comp.teamA,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  ],
                ),
                if (comp.type == 'خمن' && comp.teamBImage != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            comp.teamAImage!,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            comp.teamBImage!,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (comp.teamAImage != null &&
                    comp.teamAImage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      comp.teamAImage!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                if (!hasJoined) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _answerController,
                    keyboardType: comp.type == 'خمن'
                        ? TextInputType.number
                        : TextInputType.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Tajawal',
                    ),
                    decoration: InputDecoration(
                      hintText: comp.type == 'خمن'
                          ? 'اكتب تخمينك الرقمي هنا...'
                          : 'اكتب إجابتك هنا...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 14,
                        fontFamily: 'Tajawal',
                      ),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.greenAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          comp.type == 'خمن'
                              ? 'تخمينك: ${comp.answers[currentUserId] ?? 'تم الإرسال'}'
                              : 'إجابتك: ${comp.answers[currentUserId] ?? 'تمت المشاركة'}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 14,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (comp.type == 'تحدي السرعة') ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: Colors.blueAccent,
                  size: 40,
                ),
                const SizedBox(height: 12),
                const Text(
                  'تحدي السرعة: 4 جولات × 7 أسئلة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const Text(
                  'يجب الإجابة على جميع الأسئلة خلال 10 ثواني للسؤال الواحد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 16),
                if (hasJoined)
                  const Text(
                    '✅ لقد أتممت التحدي بنجاح!',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: comp.questions.isEmpty
                          ? () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'عذراً، لا توجد أسئلة مضافة لهذا التحدي بعد',
                                ),
                              ),
                            )
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SpeedChallengePlayScreen(
                                        competition: comp,
                                        userId: currentUserId,
                                      ),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: comp.questions.isEmpty
                            ? Colors.grey
                            : Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'ابدأ التحدي الآن',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (comp.type != 'تحدي السرعة')
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: hasJoined
                  ? null
                  : () {
                      if (comp.type == 'جاوب صح' || comp.type == 'خمن') {
                        if (_answerController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'الرجاء كتابة التخمين/الإجابة أولاً',
                              ),
                            ),
                          );
                          return;
                        }
                        _submitAnswer(comp.id, _answerController.text.trim());
                      } else {
                        if (comp.eliminated.contains(currentUserId)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'لا يمكنك الانضمام مجدداً، لقد تم استبعادك.',
                              ),
                            ),
                          );
                        } else {
                          _joinCompetition(comp.id);
                        }
                      }
                    },
              icon: Icon(hasJoined ? Icons.check_circle : Icons.stars_rounded),
              label: Text(
                hasJoined
                    ? 'تمت المشاركة'
                    : (comp.type == 'خمن'
                          ? 'إرسال التخمين'
                          : (comp.type == 'جاوب صح'
                                ? 'إرسال الإجابة'
                                : 'مشاركة في المسابقة')),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasJoined ? Colors.green[600] : Colors.amber,
                foregroundColor: hasJoined ? Colors.white : Colors.black,
                disabledBackgroundColor: hasJoined
                    ? Colors.green[600]
                    : Colors.grey[800],
                disabledForegroundColor: hasJoined
                    ? Colors.white
                    : Colors.white38,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        if (hasJoined)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(
              child: Text(
                'أنت الآن في قائمة المتسابقين، انتظر موعد السحب!',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _submitAnswer(String id, String answer) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('competitions').doc(id).update({
        'answers.$uid': answer,
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إرسال إجابتك بنجاح!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _joinCompetition(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('competitions').doc(id).update({
        'participants': FieldValue.arrayUnion([uid]),
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تمت المشاركة بنجاح!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Widget _buildTeamVoteCard(
    String name,
    String? image,
    Color color,
    bool isSelected,
    bool disabled,
    VoidCallback onTap,
    int votes,
    int totalVotes,
  ) {
    double percentage = totalVotes == 0 ? 0 : (votes / totalVotes);

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.2)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            if (image != null && image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  image,
                  height: 50,
                  width: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) =>
                      Icon(Icons.shield, color: color, size: 50),
                ),
              )
            else
              Icon(Icons.shield, color: color, size: 50),
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 12),
            if (disabled) ...[
              LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.white10,
                color: color,
                borderRadius: BorderRadius.circular(5),
                minHeight: 6,
              ),
              const SizedBox(height: 6),
              Text(
                '${(percentage * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'تصويت',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoContestSection(Competition comp, String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid of submissions
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('competitions')
              .doc(comp.id)
              .collection('submissions')
              .orderBy('votesCount', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );

            final submissions = snapshot.data!.docs;
            final bool hasSubmitted = submissions.any(
              (doc) => doc.id == userId,
            );

            return Column(
              children: [
                if (!hasSubmitted)
                  _buildUploadSection(comp.id, userId)
                else
                  _buildAlreadySubmittedBadge(),

                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'صور المتسابقين (صوت للأجمل)',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (submissions.isEmpty)
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white10,
                          size: 40,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'لا توجد مشاركات بعد',
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 12,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                    itemCount: submissions.length,
                    itemBuilder: (context, index) {
                      final data =
                          submissions[index].data() as Map<String, dynamic>;
                      final votes = List<String>.from(data['votes'] ?? []);
                      final bool isLiked = votes.contains(userId);

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isLiked ? Colors.pinkAccent : Colors.white10,
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (data['photo'] != null &&
                                            data['photo']
                                                .toString()
                                                .trim()
                                                .isNotEmpty) {
                                          showDialog(
                                            context: context,
                                            builder: (c) => Dialog(
                                              backgroundColor:
                                                  Colors.transparent,
                                              insetPadding:
                                                  const EdgeInsets.all(10),
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  InteractiveViewer(
                                                    child: CachedNetworkImage(
                                                      imageUrl: data['photo'],
                                                      fit: BoxFit.contain,
                                                      placeholder: (ctx, url) =>
                                                          const CircularProgressIndicator(
                                                            color: Colors.amber,
                                                          ),
                                                      errorWidget:
                                                          (
                                                            ctx,
                                                            url,
                                                            error,
                                                          ) => const Icon(
                                                            Icons.broken_image,
                                                            color: Colors.white,
                                                            size: 50,
                                                          ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 10,
                                                    right: 10,
                                                    child: IconButton(
                                                      icon: const Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                        size: 30,
                                                      ),
                                                      onPressed: () =>
                                                          Navigator.pop(c),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(20),
                                            ),
                                        child: CachedNetworkImage(
                                          imageUrl: data['photo'] ?? '',
                                          fit: BoxFit.cover,
                                          placeholder: (c, u) =>
                                              Container(color: Colors.white),
                                          errorWidget: (c, u, e) => const Icon(
                                            Icons.broken_image,
                                            color: Colors.white10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.favorite,
                                            color: Colors.pinkAccent,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${votes.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      data['name'] ?? 'لاعب ميتو',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _toggleSubmissionLike(
                                      comp.id,
                                      submissions[index].id,
                                      userId,
                                      isLiked,
                                    ),
                                    icon: Icon(
                                      isLiked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isLiked
                                          ? Colors.pinkAccent
                                          : Colors.white38,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildUploadSection(String compId, String userId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purpleAccent.withOpacity(0.1),
            Colors.blueAccent.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.add_photo_alternate_rounded,
            color: Colors.amber,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'شارك بصورتك الآن!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'Tajawal',
            ),
          ),
          const Text(
            'ارفع صورتك واجمع أكبر عدد من اللايكات للفوز',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _pickAndUploadImage(compId, userId),
            icon: const Icon(Icons.cloud_upload_rounded),
            label: const Text(
              'رفع صورة المشاركة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadySubmittedBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
          SizedBox(width: 8),
          Text(
            'لقد شاركت في المسابقة بنجاح!',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(String compId, String userId) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    // Show loading
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('جاري رفع صورتك...')));

    try {
      final ref = FirebaseStorage.instance.ref().child(
        'competitions/$compId/submissions/$userId.jpg',
      );
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      // Get user name
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data();
      final String rawNickname = data?['nickname'] ?? '';
      final String rawUsername = data?['username'] ?? '';
      final String userName = rawNickname.trim().isNotEmpty
          ? rawNickname
          : (rawUsername.trim().isNotEmpty ? rawUsername : 'لاعب ميتو');

      await _firestore
          .collection('competitions')
          .doc(compId)
          .collection('submissions')
          .doc(userId)
          .set({
            'uid': userId,
            'name': userName,
            'photo': url,
            'votes': [],
            'votesCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Add user to participants list for admin tracking
      await _firestore.collection('competitions').doc(compId).update({
        'participants': FieldValue.arrayUnion([userId]),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تمت المشاركة بنجاح!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الرفع: $e')));
    }
  }

  Future<void> _toggleSubmissionLike(
    String compId,
    String submissionId,
    String userId,
    bool isLiked,
  ) async {
    final docRef = _firestore
        .collection('competitions')
        .doc(compId)
        .collection('submissions')
        .doc(submissionId);

    if (isLiked) {
      await docRef.update({
        'votes': FieldValue.arrayRemove([userId]),
        'votesCount': FieldValue.increment(-1),
      });
    } else {
      await docRef.update({
        'votes': FieldValue.arrayUnion([userId]),
        'votesCount': FieldValue.increment(1),
      });
    }
  }

  Widget _buildLastEliminatedCard(String name, String? photo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white10,
            backgroundImage: (photo != null && photo.trim().isNotEmpty)
                ? NetworkImage(photo.trim())
                : null,
            child: (photo == null || photo.trim().isEmpty)
                ? const Icon(Icons.person, color: Colors.white24)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المستبعد: $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const Text(
                  'حظ أوفر للمسابقة القادمة',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.sentiment_very_dissatisfied_rounded,
            color: Colors.redAccent,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildRollingSection(Competition comp) {
    return Center(
      child: Column(
        children: [
          const Text(
            'جاري سحب الفائز الآن!',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Lottie.network(
              'https://assets9.lottiefiles.com/packages/lf20_tiviyc3p.json', // Lucky Wheel Lottie
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) =>
                  const CircularProgressIndicator(color: Colors.amber),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'شاهد السحب المباشر...',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(String? rankName) {
    if (rankName == null || rankName.trim().isEmpty)
      return const SizedBox.shrink();

    String badgeText = '';
    List<Color> gradientColors = [];
    String icon = '';

    if (rankName == 'المركز الأول') {
      badgeText = 'الأول';
      icon = '🥇';
      gradientColors = [
        const Color(0xFFFFD700),
        const Color(0xFFFFA500),
      ]; // Premium Gold
    } else if (rankName == 'المركز الثاني') {
      badgeText = 'الثاني';
      icon = '🥈';
      gradientColors = [
        const Color(0xFFE2E8F0),
        const Color(0xFF94A3B8),
      ]; // Premium Silver
    } else if (rankName == 'المركز الثالث') {
      badgeText = 'الثالث';
      icon = '🥉';
      gradientColors = [
        const Color(0xFFD97706),
        const Color(0xFF78350F),
      ]; // Premium Bronze
    } else {
      badgeText = rankName;
      gradientColors = [const Color(0xFF475569), const Color(0xFF1E293B)];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          if (icon.isNotEmpty) const SizedBox(width: 4),
          Text(
            badgeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSection(Competition comp) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: Colors.amber,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                comp.winners.isNotEmpty
                    ? 'الفائزون بالمسابقة'
                    : 'الفائز المحظوظ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.emoji_events_rounded,
                color: Colors.amber,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (comp.winners.isNotEmpty)
            ...comp.winners
                .map(
                  (winner) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white10,
                          backgroundImage:
                              (winner['photo'] != null &&
                                  winner['photo'].toString().trim().isNotEmpty)
                              ? NetworkImage(winner['photo'].toString().trim())
                              : null,
                          child:
                              (winner['photo'] == null ||
                                  winner['photo'].toString().trim().isEmpty)
                              ? const Icon(Icons.person, color: Colors.white24)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      winner['name'] ?? 'لاعب ميتو',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildRankBadge(winner['rankName']),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'فاز بـ ${winner['prizeAmount'] ?? comp.prizeAmount} ${comp.prizeCurrency == 'diamonds' ? 'الماس' : (comp.prizeCurrency == 'coins' ? 'ذهب' : 'عملة ميتو')}',
                                style: TextStyle(
                                  color: Colors.amber.withOpacity(0.7),
                                  fontSize: 11,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.stars_rounded,
                          color: Colors.amber,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                )
                .toList()
          else ...[
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white10,
              backgroundImage:
                  (comp.winnerPhoto != null &&
                      comp.winnerPhoto!.trim().isNotEmpty)
                  ? NetworkImage(comp.winnerPhoto!.trim())
                  : null,
              child:
                  (comp.winnerPhoto == null || comp.winnerPhoto!.trim().isEmpty)
                  ? const Icon(Icons.person, size: 40, color: Colors.white24)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              comp.winnerName ?? 'غير معروف',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'فاز بـ ${comp.prizeAmount} ${comp.prizeCurrency == 'diamonds' ? 'الماس' : (comp.prizeCurrency == 'coins' ? 'ذهب' : 'عملة ميتو')}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),
          ],
          const SizedBox(height: 15),
          Text(
            'تاريخ السحب: ${comp.completedAt?.day}/${comp.completedAt?.month}/${comp.completedAt?.year}',
            style: const TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Future<void> _vote(String compId, String team) async {
    final String userId = _auth.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    try {
      final docRef = _firestore.collection('competitions').doc(compId);
      if (team == 'A') {
        await docRef.update({
          'votesA': FieldValue.arrayUnion([userId]),
        });
      } else {
        await docRef.update({
          'votesB': FieldValue.arrayUnion([userId]),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }
}

class SynchedFortuneWheel extends StatefulWidget {
  final int? targetIndex;
  final List<String> names;
  final VoidCallback onAnimationEnd;

  const SynchedFortuneWheel({
    super.key,
    this.targetIndex,
    required this.names,
    required this.onAnimationEnd,
  });

  @override
  _SynchedFortuneWheelState createState() => _SynchedFortuneWheelState();
}

class _SynchedFortuneWheelState extends State<SynchedFortuneWheel> {
  late StreamController<int> _controller;

  @override
  void initState() {
    super.initState();
    _controller = StreamController<int>.broadcast();
    if (widget.targetIndex != null) {
      // Small delay to ensure widget is mounted
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && widget.targetIndex != null) {
          _controller.add(widget.targetIndex!);
        }
      });
    }
  }

  @override
  void didUpdateWidget(SynchedFortuneWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetIndex != null &&
        widget.targetIndex != oldWidget.targetIndex) {
      _controller.add(widget.targetIndex!);
    }
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FortuneWheel(
      selected: _controller.stream,
      animateFirst: false,
      physics: NoPanPhysics(),
      duration: const Duration(seconds: 5),
      indicators: const [
        FortuneIndicator(
          alignment: Alignment.topCenter,
          child: TriangleIndicator(color: Colors.red),
        ),
      ],
      items: [
        for (int i = 0; i < widget.names.length; i++)
          FortuneItem(
            child: RotatedBox(
              quarterTurns: 1,
              child: Text(
                widget.names[i],
                style: TextStyle(
                  fontSize: widget.names.length > 50
                      ? 6
                      : (widget.names.length > 20 ? 8 : 10),
                  fontFamily: 'Tajawal',
                  color: i % 2 == 0 ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onTap: () {},
            style: FortuneItemStyle(
              color: i % 2 == 0
                  ? const Color(0xFFB22222)
                  : const Color(0xFFF5F5DC),
              borderColor: const Color(0xFFD4AF37),
              borderWidth: 0.5,
            ),
          ),
      ],
      onAnimationEnd: widget.onAnimationEnd,
    );
  }
}

class CompetitionChatSheet extends StatefulWidget {
  final String compId;
  final String title;

  const CompetitionChatSheet({
    super.key,
    required this.compId,
    required this.title,
  });

  @override
  State<CompetitionChatSheet> createState() => _CompetitionChatSheetState();
}

class _CompetitionChatSheetState extends State<CompetitionChatSheet> {
  final TextEditingController _msgController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DateTime _entryTime = DateTime.now();
  Map<String, dynamic>? _replyingTo;

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    final userDoc = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .get();
    final data = userDoc.data();
    final String rawNickname = data?['nickname'] ?? '';
    final String rawUsername = data?['username'] ?? '';
    final String name = rawNickname.trim().isNotEmpty
        ? rawNickname
        : (rawUsername.trim().isNotEmpty ? rawUsername : 'لاعب ميتو');
    final String pic = data?['profilePic'] ?? '';

    await _firestore
        .collection('competitions')
        .doc(widget.compId)
        .collection('chat')
        .add({
          'text': text,
          'senderId': _auth.currentUser!.uid,
          'senderName': name,
          'senderPic': pic,
          'timestamp': FieldValue.serverTimestamp(),
          if (_replyingTo != null) 'repliedTo': _replyingTo,
        });

    setState(() {
      _replyingTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'الدردشة ${widget.title}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
            const Divider(color: Colors.white10, height: 30),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('competitions')
                    .doc(widget.compId)
                    .collection('chat')
                    .where('timestamp', isGreaterThan: _entryTime)
                    .orderBy('timestamp', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    );
                  final messages = snapshot.data!.docs;
                  return ListView.builder(
                    reverse: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg =
                          messages[index].data() as Map<String, dynamic>;
                      final bool isMe =
                          msg['senderId'] == _auth.currentUser?.uid;
                      final repliedTo =
                          msg['repliedTo'] as Map<String, dynamic>?;

                      return InkWell(
                        onLongPress: () {
                          setState(() {
                            _replyingTo = msg;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe) ...[
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.white10,
                                  backgroundImage:
                                      msg['senderPic'].toString().isNotEmpty
                                      ? NetworkImage(msg['senderPic'])
                                      : null,
                                  child: msg['senderPic'].toString().isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.amber.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(15),
                                    topRight: const Radius.circular(15),
                                    bottomLeft: Radius.circular(isMe ? 15 : 0),
                                    bottomRight: Radius.circular(isMe ? 0 : 15),
                                  ),
                                  border: Border.all(
                                    color: isMe
                                        ? Colors.amber.withOpacity(0.3)
                                        : Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Text(
                                        msg['senderName'] ?? '',
                                        style: TextStyle(
                                          color: Colors.amber.withOpacity(0.8),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    if (repliedTo != null)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              repliedTo['senderName'] ?? '',
                                              style: const TextStyle(
                                                color: Colors.amber,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              repliedTo['text'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Text(
                                      msg['text'] ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
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
              ),
            ),
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: const Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.reply_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الرد على ${_replyingTo!['senderName']}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _replyingTo!['text'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _replyingTo = null),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LiveCountdownWidget extends StatefulWidget {
  final DateTime endTime;
  const LiveCountdownWidget({super.key, required this.endTime});

  @override
  State<LiveCountdownWidget> createState() => _LiveCountdownWidgetState();
}

class _LiveCountdownWidgetState extends State<LiveCountdownWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTimeLeft(DateTime endTime) {
    final diff = endTime.difference(DateTime.now());
    if (diff.isNegative) return "انتهى الوقت";

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final isEnded = widget.endTime.difference(DateTime.now()).isNegative;

    return Text(
      _formatTimeLeft(widget.endTime),
      style: GoogleFonts.poppins(
        color: isEnded ? Colors.redAccent : Colors.amber,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
