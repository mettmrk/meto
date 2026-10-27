import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/user_service.dart';
import '../services/storage_service.dart';
import '../services/voice_room_service.dart';
import '../services/referral_service.dart';
import '../models/user_model.dart';
import 'chat_screen.dart';
import 'add_story_screen.dart';
import 'follow_list_screen.dart';
import '../widgets/profile_frame_selection_sheet.dart';
import '../widgets/framed_avatar.dart';
import '../widgets/level_badge.dart';
import '../services/task_service.dart';
import '../models/task_model.dart';

class ProfileScreen extends StatefulWidget {
  final String? uid;
  const ProfileScreen({super.key, this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final UserService _userService = UserService();
  final VoiceRoomService _voiceRoomService = VoiceRoomService();
  final ReferralService _referralService = ReferralService();
  late final String? _targetUid;
  bool _isWaitingForFollowBack = false;
  Timer? _followTimer;
  late AnimationController _verificationController;
  Timer? _verificationTimer;
  late AnimationController _chipsController;

  @override
  void initState() {
    // 1. Initialize Controllers FIRST
    _verificationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _chipsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // 2. Initialize other state
    super.initState();
    _targetUid = widget.uid ?? auth.FirebaseAuth.instance.currentUser?.uid;

    // 3. Start animations/timers
    _verificationController.forward();
    _verificationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _verificationController.forward(from: 0);
    });

    _loadData();
  }

  @override
  void dispose() {
    _verificationController.dispose();
    _chipsController.dispose();
    _followTimer?.cancel();
    _verificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $urlString')));
      }
    }
  }

  void _loadData() {}

  @override
  Widget build(BuildContext context) {
    if (_targetUid == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: Text('المستخدم غير موجود')),
      );
    }

    final isMe = _targetUid == auth.FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<User?>(
      stream: _userService.getUserStream(_targetUid),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            ),
          );
        }

        if (userSnapshot.hasError ||
            !userSnapshot.hasData ||
            userSnapshot.data == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('الملف الشخصي', style: TextStyle()),
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black87),
            ),
            body: const Center(child: Text('خطأ في تحميل بيانات المستخدم')),
          );
        }

        final user = userSnapshot.data!;
        final currentUser = auth.FirebaseAuth.instance.currentUser;

        return StreamBuilder<User?>(
          stream: _userService.getUserStream(currentUser?.uid ?? ''),
          builder: (context, currentUserSnapshot) {
            final myUserData = currentUserSnapshot.data;
            final amIBlockedByHim = user.blockedUsers.contains(
              currentUser?.uid,
            );
            final didIBlockHim =
                myUserData?.blockedUsers.contains(_targetUid) ?? false;

            if (didIBlockHim) {
              return _buildBlockedScreen(currentUser, _targetUid, true);
            }

            if (amIBlockedByHim) {
              return _buildBlockedScreen(currentUser, _targetUid, false);
            }

            final bool isMuted =
                myUserData?.mutedUsers.contains(_targetUid) ?? false;
            final bool isBlacklisted =
                myUserData?.blacklistedUsers.contains(_targetUid) ?? false;

            // Privacy check: for private accounts, require MUTUAL following (both sides)
            // user.followers.contains(me) = I follow them
            // user.following.contains(me) = they follow me back
            final bool isMutualFollow =
                user.followers.contains(currentUser?.uid) &&
                user.following.contains(currentUser?.uid);
            final bool isPrivateAndNotFollower =
                !isMe && user.isPrivate && !isMutualFollow;

            return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                elevation: 0,
                centerTitle: true,
                // 1. Update AppBar title (lines 137-142 approx)
                title: Text(
                  user.nickname?.isNotEmpty == true
                      ? user.nickname!
                      : user.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                automaticallyImplyLeading: false,
                actions: [
                  if (isMe) ...[
                    IconButton(
                      icon: const Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        final String referralCode = user.displayId ?? user.uid;
                        final String shareMessage =
                            'انضم إلي في تطبيق ميتو واستمتع بأفضل الألعاب والدردشة الصوتية!\n'
                            'استخدم كود الدعوة الخاص بي: $referralCode\n'
                            'حمل التطبيق من هنا: [رابط التطبيق الخاص بك]';

                        Share.share(shareMessage).then((_) {
                          TaskService().incrementTaskProgress(
                            user.uid,
                            TaskType.shareApp,
                          );
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.settings_suggest_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamed('/settings');
                      },
                    ),
                  ] else
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onSelected: (value) async => _handleMenuAction(
                        value,
                        user,
                        didIBlockHim,
                        isMuted,
                        isBlacklisted,
                      ),
                      itemBuilder: (BuildContext context) =>
                          _buildMenuItems(didIBlockHim, isMuted, isBlacklisted),
                    ),
                ],
              ),
              extendBodyBehindAppBar: true,
              body: DefaultTabController(
                length: 1,
                child: RefreshIndicator(
                  color: Theme.of(context).primaryColor,
                  onRefresh: () async {
                    setState(() {
                      _loadData();
                    });
                  },
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              // --- Giant Header Section ---
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Premium Cover
                                  GestureDetector(
                                    onTap: isMe
                                        ? () => _changeCoverImage(context)
                                        : null,
                                    child: SizedBox(
                                      height: 240,
                                      width: double.infinity,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (user.coverImage != null &&
                                              user.coverImage!.isNotEmpty)
                                            Image.network(
                                              user.coverImage!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Container(
                                                    color: const Color(
                                                      0xFF1A1A1A,
                                                    ),
                                                  ),
                                            ),
                                          // Gradient Overlays
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withOpacity(0.5),
                                                  Colors.black.withOpacity(0.9),
                                                ],
                                              ),
                                            ),
                                          ),

                                          if (user.coverImage == null ||
                                              user.coverImage!.isEmpty)
                                            Center(
                                              child: Icon(
                                                Icons
                                                    .auto_awesome_mosaic_rounded,
                                                size: 64,
                                                color: Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Decoration Wave Hanging Below Cover
                                  if (user.profileDecoration != null &&
                                      user.profileDecoration!.isNotEmpty)
                                    Positioned(
                                      top: 150,
                                      left: 0,
                                      right: 0,
                                      height: 190,
                                      child: SizedBox(
                                        width: double.infinity,
                                        child:
                                            user.profileDecoration!.startsWith(
                                              'http',
                                            )
                                            ? Image.network(
                                                user.profileDecoration!,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return const SizedBox();
                                                    },
                                              )
                                            : Image.asset(
                                                user.profileDecoration!,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return const SizedBox();
                                                    },
                                              ),
                                      ),
                                    ),

                                  // Profile Content (Layered)
                                  Positioned(
                                    bottom: -40,
                                    left: 0,
                                    right: 0,
                                    child: Column(
                                      children: [
                                        Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.center,
                                          children: [
                                            GestureDetector(
                                              onTap: isMe
                                                  ? () => _showFrameSelection(
                                                      context,
                                                      user,
                                                    )
                                                  : null,
                                              child: FramedAvatar(
                                                userId: user.uid,
                                                imageUrl: user.profileImage,
                                                radius: 40,
                                                useProfileFrameFallback: true,
                                                fallbackBorderWhenNoFrame: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Wall Hanging (معلقة جدارية) - Moved here to be above Profile Picture
                                  if (user.activeWallHanging != null &&
                                      user.activeWallHanging!.isNotEmpty)
                                    Positioned(
                                      top: -10,
                                      left: 0,
                                      right: 0,
                                      child: IgnorePointer(
                                        child: Align(
                                          alignment: Alignment.topCenter,
                                          child: SizedBox(
                                            width: double.infinity,
                                            height: 300,
                                            child:
                                                user.activeWallHanging!
                                                        .endsWith('.json') ||
                                                    user.activeWallHanging!
                                                        .contains('lottie')
                                                ? Lottie.network(
                                                    user.activeWallHanging!,
                                                    fit: BoxFit.contain,
                                                    alignment:
                                                        Alignment.topCenter,
                                                  )
                                                : (user.activeWallHanging!
                                                          .startsWith('http')
                                                      ? Image.network(
                                                          user.activeWallHanging!,
                                                          fit: BoxFit.contain,
                                                          alignment: Alignment
                                                              .topCenter,
                                                        )
                                                      : Image.asset(
                                                          user.activeWallHanging!,
                                                          fit: BoxFit.contain,
                                                          alignment: Alignment
                                                              .topCenter,
                                                        )),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 60),

                              // --- Name & Bio Card ---
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 24,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: 35,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              user.nickname?.isNotEmpty == true
                                                  ? user.nickname!
                                                  : user.username,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.5,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            if (user.verificationTier != null ||
                                                user.isVerified) ...[
                                              const SizedBox(width: 8),
                                              AnimatedBuilder(
                                                animation:
                                                    _verificationController,
                                                builder: (context, child) {
                                                  return Transform(
                                                    alignment: Alignment.center,
                                                    transform: Matrix4.identity()
                                                      ..setEntry(3, 2, 0.001)
                                                      ..rotateY(
                                                        _verificationController
                                                                .value *
                                                            2 *
                                                            math.pi,
                                                      ),
                                                    child: child,
                                                  );
                                                },
                                                child:
                                                    (user.verificationIcon !=
                                                            null &&
                                                        user.verificationIcon!
                                                            .startsWith('http'))
                                                    ? Image.network(
                                                        user.verificationIcon!,
                                                        width: 27,
                                                        height: 27,
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) =>
                                                                _buildDefaultVerif(
                                                                  user,
                                                                ),
                                                      )
                                                    : _buildDefaultVerif(user),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (user.displayId != null)
                                        GestureDetector(
                                          onTap: () {
                                            Clipboard.setData(
                                              ClipboardData(
                                                text:
                                                    (user.displayIdImage !=
                                                            null &&
                                                        user
                                                            .displayIdImage!
                                                            .isNotEmpty &&
                                                        user.ownedSpecialIdImages
                                                            .contains(
                                                              user.displayIdImage!,
                                                            ))
                                                    ? user.ownedSpecialIds[user
                                                          .ownedSpecialIdImages
                                                          .indexOf(
                                                            user.displayIdImage!,
                                                          )]
                                                    : user.displayId!,
                                              ),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                  'تم نسخ المعرف بنجاح',
                                                  style: TextStyle(
                                                    fontFamily: 'Segoe UI',
                                                  ),
                                                ),
                                                backgroundColor:
                                                    Colors.teal.shade700,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                duration: const Duration(
                                                  seconds: 1,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 0,
                                                ),
                                                child:
                                                    user.displayIdImage !=
                                                            null &&
                                                        user
                                                            .displayIdImage!
                                                            .isNotEmpty
                                                    ? Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        textDirection:
                                                            TextDirection.ltr,
                                                        children: [
                                                          const Text(
                                                            'ID: ',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors
                                                                  .black54,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          Image.network(
                                                            user.displayIdImage!,
                                                            height: 55,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ],
                                                      )
                                                    : Text(
                                                        'ID: ${user.displayId}',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.black54,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(
                                                Icons.copy,
                                                size: 16,
                                                color: Colors.black38,
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      if (user.gender != null ||
                                          (user.country != null &&
                                              user.country!.isNotEmpty))
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _buildStyledLevelBadge(
                                              user,
                                              sizeScale: 0.90,
                                            ),
                                            const SizedBox(width: 8),
                                            if (user.country != null &&
                                                user.country!.isNotEmpty) ...[
                                              Text(
                                                user.country!.replaceAll(
                                                  RegExp(
                                                    r'[a-zA-Z\u0600-\u06FF\s]+',
                                                  ),
                                                  '',
                                                ),
                                                style: const TextStyle(
                                                  fontSize:
                                                      22, // Slightly larger for flag
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            if (user.gender != null) ...[
                                              Image.asset(
                                                user.gender == 'male'
                                                    ? 'assets/images/maile/Male.png'
                                                    : 'assets/images/maile/Female.png',
                                                width: 22,
                                                height: 22,
                                              ),
                                            ],
                                          ],
                                        ),
                                      if (user.bio != null &&
                                          user.bio!.isNotEmpty) ...[
                                        const SizedBox(height: 20),
                                        Text(
                                          user.bio!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                              if (!isPrivateAndNotFollower) ...[
                                if (isMe) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: _buildLevelProgressCard(user),
                                  ),
                                  const SizedBox(height: 15),
                                ],

                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: _buildTraitsCard(user, isMe),
                                ),
                              ],

                              const SizedBox(height: 20),

                              if (!isPrivateAndNotFollower) ...[
                                // --- Premium Stats Row ---
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    decoration: _getCardDecoration(user),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildStatItem(
                                          context,
                                          'متابع',
                                          user.followers.length.toString(),
                                          () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    FollowListScreen(
                                                      title: 'المتابعون',
                                                      userIds: user.followers,
                                                    ),
                                              ),
                                            );
                                          },
                                          user,
                                        ),
                                        _buildStatDivider(),
                                        _buildStatItem(
                                          context,
                                          'يتابع',
                                          user.following.length.toString(),
                                          () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    FollowListScreen(
                                                      title: 'يتابع',
                                                      userIds: user.following,
                                                    ),
                                              ),
                                            );
                                          },
                                          user,
                                        ),
                                        _buildStatDivider(),
                                        StreamBuilder<int>(
                                          stream: _referralService
                                              .teamCountStream(user.uid),
                                          builder: (context, snap) {
                                            final count = snap.data ?? 0;
                                            return _buildStatItem(
                                              context,
                                              'فريق',
                                              count.toString(),
                                              isMe
                                                  ? () async {
                                                      final ids =
                                                          await _referralService
                                                              .getTeamIds(
                                                                user.uid,
                                                              );
                                                      if (!context.mounted) {
                                                        return;
                                                      }
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              FollowListScreen(
                                                                title: 'فريقك',
                                                                userIds: ids,
                                                                referralCode:
                                                                    user.referralCode ??
                                                                    user.displayId,
                                                              ),
                                                        ),
                                                      );
                                                    }
                                                  : null,
                                              user,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 30),

                                // --- Action Buttons ---
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: isMe
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: _buildGiantActionBtn(
                                                onPressed: _openGalleryForStory,
                                                icon: Icons.add_rounded,
                                                label: 'قصة',
                                                gradient: [
                                                  Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                  Theme.of(context).primaryColor
                                                      .withValues(alpha: 0.7),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildGiantActionBtn(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pushNamed('/editProfile'),
                                                icon: Icons.edit_note_rounded,
                                                label: 'تعديل',
                                                color: Colors.grey.shade200,
                                                textColor: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildGiantActionBtn(
                                                onPressed: () =>
                                                    _showFrameSelection(
                                                      context,
                                                      user,
                                                    ),
                                                icon:
                                                    Icons.auto_awesome_rounded,
                                                label: 'تزيين',
                                                color: Colors.grey.shade200,
                                                textColor: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        )
                                      : _buildActionButtons(user, currentUser),
                                ),
                              ],

                              // --- Private Account: Follow Request Only ---
                              if (isPrivateAndNotFollower) ...[
                                const SizedBox(height: 30),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: _buildActionButtons(
                                    user,
                                    currentUser,
                                    hideMessageButton: true,
                                  ),
                                ),
                                const SizedBox(height: 40),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.lock_outline_rounded,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'هذا الحساب خاص',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'تابع هذا الحساب لمشاهدة محتواه ومعلوماته',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (!isPrivateAndNotFollower) ...[
                                const SizedBox(height: 24),

                                // --- VIP Wallet Card ---
                                if (isMe)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: _buildVIPWalletCard(context, user),
                                  ),

                                const SizedBox(height: 24),

                                // --- User Room Card ---
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: _buildUserRoomCard(user.uid),
                                ),

                                const SizedBox(height: 24),

                                if (isMe) const SizedBox(height: 24),

                                const SizedBox(height: 32),

                                // --- Personal Details ---
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: _getCardDecoration(user),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color:
                                                    _getCardTextColor(user) ==
                                                        Colors.white
                                                    ? Colors.white.withValues(
                                                        alpha: 0.1,
                                                      )
                                                    : Colors.amber.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                Icons.info_outline_rounded,
                                                color:
                                                    _getCardTextColor(user) ==
                                                        Colors.white
                                                    ? Colors.amber.shade200
                                                    : Colors.amber.shade800,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'المعلومات الأساسية',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: _getCardTextColor(user),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: [
                                            if (user.work != null &&
                                                user.work!.isNotEmpty)
                                              _buildInfoTile(
                                                Icons.work_rounded,
                                                'العمل',
                                                user.work!,
                                                Colors.blue,
                                                user,
                                              ),
                                            if (user.country != null &&
                                                user.country!.isNotEmpty)
                                              _buildInfoTile(
                                                Icons.flag_rounded,
                                                'الدولة',
                                                user.country!.split(' ').first,
                                                Colors.red,
                                                user,
                                              ),
                                            if (user.city != null &&
                                                user.city!.isNotEmpty)
                                              _buildInfoTile(
                                                Icons.location_on_rounded,
                                                'يسكن في',
                                                user.city!,
                                                Colors.green,
                                                user,
                                              ),
                                            if (user.birthDate != null)
                                              _buildInfoTile(
                                                Icons.cake_rounded,
                                                'تاريخ الميلاد',
                                                _formatDate(user.birthDate!),
                                                Colors.pink,
                                                user,
                                              ),
                                            _buildInfoTile(
                                              Icons.calendar_month_rounded,
                                              'تاريخ الانضمام',
                                              _formatDate(user.createdAt),
                                              Colors.purple,
                                              user,
                                            ),
                                            if (user.gender != null)
                                              _buildInfoTile(
                                                user.gender == 'male'
                                                    ? Icons.male_rounded
                                                    : Icons.female_rounded,
                                                'الجنس',
                                                user.gender == 'male'
                                                    ? 'ذكر'
                                                    : 'أنثى',
                                                Colors.orange,
                                                user,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 40),
                              ],
                            ],
                          ),
                        ),

                        if (!isPrivateAndNotFollower)
                          SliverPersistentHeader(
                            delegate: _SliverAppBarDelegate(
                              const TabBar(
                                labelColor: Colors.teal,
                                unselectedLabelColor: Colors.grey,
                                indicatorColor: Colors.teal,
                                indicatorWeight: 3,
                                indicatorSize: TabBarIndicatorSize.label,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                tabs: [
                                  Tab(
                                    text: 'بيانات اللعب',
                                    icon: Icon(Icons.sports_esports_rounded),
                                  ),
                                ],
                              ),
                            ),
                            pinned: true,
                          ),
                      ];
                    },
                    body: isPrivateAndNotFollower
                        ? const SizedBox.shrink()
                        : TabBarView(children: [_buildGameStats(user)]),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBlockedScreen(
    auth.User? currentUser,
    String targetUid,
    bool didIBlock,
  ) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('الملف الشخصي'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_rounded, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              didIBlock ? 'لقد قمت بحظر هذا المستخدم' : 'المستخدم غير متاح',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            if (didIBlock) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (currentUser != null) {
                    await _userService.unblockUser(
                      currentUserId: currentUser.uid,
                      userToUnblockId: targetUid,
                    );
                    setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                child: const Text(
                  'رفع الحظر',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    User user,
    auth.User? currentUser, {
    bool hideMessageButton = false,
  }) {
    final isFollowing = user.followers.contains(currentUser?.uid);
    final isFollower = user.following.contains(currentUser?.uid);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildGiantActionBtn(
            onPressed: () async {
              if (currentUser == null) return;

              if (_isWaitingForFollowBack) {
                // If waiting, user might want to cancel manually?
                // For now, let's treat it as cancelling the wait/unfollowing early.
                _followTimer?.cancel();
                await _userService.unfollowUser(
                  currentUserId: currentUser.uid,
                  userToUnfollowId: user.uid,
                );
                setState(() => _isWaitingForFollowBack = false);
                return;
              }

              if (isFollowing) {
                await _userService.unfollowUser(
                  currentUserId: currentUser.uid,
                  userToUnfollowId: user.uid,
                );
              } else {
                final currentUserData = await _userService.getUser(
                  currentUser.uid,
                );

                setState(() => _isWaitingForFollowBack = true);

                await _userService.followUser(
                  currentUserId: currentUser.uid,
                  currentUsername:
                      currentUserData?.nickname ??
                      currentUserData?.username ??
                      'مستخدم',
                  currentUserProfileImage: currentUserData?.profileImage,
                  userToFollowId: user.uid,
                );

                _followTimer?.cancel();
                _followTimer = Timer(const Duration(seconds: 10), () async {
                  if (!mounted) return;
                  // Check if they followed back
                  final freshTargetUser = await _userService.getUser(user.uid);
                  final isMutual =
                      freshTargetUser?.following.contains(currentUser.uid) ??
                      false;

                  if (!isMutual) {
                    // Not mutual, revert (unfollow)
                    await _userService.unfollowUser(
                      currentUserId: currentUser.uid,
                      userToUnfollowId: user.uid,
                    );
                  }
                  if (mounted) {
                    setState(() => _isWaitingForFollowBack = false);
                  }
                });
              }
            },
            icon: _isWaitingForFollowBack
                ? Icons.hourglass_top_rounded
                : (isFollowing
                      ? Icons.person_remove_outlined
                      : Icons.person_add_outlined),
            label: _isWaitingForFollowBack
                ? 'بانتظار الرد...'
                : (isFollowing
                      ? 'إلغاء المتابعة'
                      : (isFollower ? 'رد المتابعة' : 'متابعة')),
            gradient: (_isWaitingForFollowBack || isFollowing)
                ? null
                : const [Color(0xFF00BFA5), Color(0xFF00796B)],
            color: (_isWaitingForFollowBack || isFollowing)
                ? Colors.grey.shade200
                : null,
            textColor: (_isWaitingForFollowBack || isFollowing)
                ? Colors.black87
                : Colors.white,
          ),
        ),
        if (!hideMessageButton) ...[
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: _buildGiantActionBtn(
              onPressed: () {
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
              icon: Icons.chat_bubble_outline_rounded,
              label: 'رسالة',
              color: Colors.grey.shade100,
              textColor: Colors.black87,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleMenuAction(
    String value,
    User user,
    bool isBlocked,
    bool isMuted,
    bool isBlacklisted,
  ) async {
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      if (value == 'حظر') {
        if (isBlocked) {
          await _userService.unblockUser(
            currentUserId: currentUser.uid,
            userToUnblockId: user.uid,
          );
        } else {
          await _userService.blockUser(
            currentUserId: currentUser.uid,
            userToBlockId: user.uid,
          );
        }
      } else if (value == 'أصمات') {
        if (isMuted) {
          await _userService.unmuteUser(
            currentUserId: currentUser.uid,
            userToUnmuteId: user.uid,
          );
        } else {
          await _userService.muteUser(
            currentUserId: currentUser.uid,
            userToMuteId: user.uid,
          );
        }
      } else if (value == 'قائمة سوداء') {
        if (isBlacklisted) {
          await _userService.removeBlacklistUser(
            currentUserId: currentUser.uid,
            userToRemoveId: user.uid,
          );
        } else {
          await _userService.blacklistUser(
            currentUserId: currentUser.uid,
            userToBlacklistId: user.uid,
          );
        }
      } else if (value == 'إبلاغ') {
        if (mounted) _showReportDialog(currentUser, user);
      }

      if (mounted && value != 'إبلاغ') {
        String msg = '';
        if (value == 'حظر') msg = isBlocked ? 'تم إلغاء الحظر' : 'تم الحظر';
        if (value == 'أصمات') msg = isMuted ? 'تم تفعيل التنبيهات' : 'تم الكتم';
        if (value == 'قائمة سوداء')
          msg = isBlacklisted
              ? 'تمت الإزالة من القائمة'
              : 'تمت الإضافة للقائمة';

        if (msg.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems(
    bool isBlocked,
    bool isMuted,
    bool isBlacklisted,
  ) {
    return [
      PopupMenuItem(
        value: 'حظر',
        child: Row(
          children: [
            Icon(isBlocked ? Icons.undo : Icons.block, color: Colors.red),
            const SizedBox(width: 8),
            Text(isBlocked ? 'إلغاء الحظر' : 'حظر'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'أصمات',
        child: Row(
          children: [
            Icon(
              isMuted ? Icons.volume_up : Icons.volume_off,
              color: Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(isMuted ? 'تفعيل التنبيهات' : 'كتم التنبيهات'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'قائمة سوداء',
        child: Row(
          children: [
            Icon(
              isBlacklisted ? Icons.playlist_remove : Icons.list_alt,
              color: Colors.black,
            ),
            const SizedBox(width: 8),
            Text(isBlacklisted ? 'إزالة من القائمة السوداء' : 'قائمة سوداء'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'إبلاغ',
        child: Row(
          children: [
            Icon(Icons.report, color: Colors.orange),
            const SizedBox(width: 8),
            Text('إبلاغ'),
          ],
        ),
      ),
    ];
  }

  void _showReportDialog(auth.User currentUser, User user) {
    // ... Report dialog implementation ...
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController reasonController = TextEditingController();
        return AlertDialog(
          title: const Text('إبلاغ عن مستخدم'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(hintText: 'سبب الإبلاغ'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                if (reasonController.text.isNotEmpty) {
                  await _userService.reportUser(
                    currentUserId: currentUser.uid,
                    userToReportId: user.uid,
                    reason: reasonController.text,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إرسال الإبلاغ')),
                    );
                  }
                }
              },
              child: const Text('إرسال'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _openGalleryForStory() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddStoryScreen(initialFile: File(image.path)),
        ),
      );
    }
  }

  Future<void> _changeCoverImage(BuildContext context) async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تغيير صورة الغلاف',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.teal),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.teal),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw 'يجب تسجيل الدخول أولاً';
      }

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.teal),
          ),
        );
      }

      final storageService = StorageService();
      final coverImageUrl = await storageService.uploadCoverImage(
        uid: currentUser.uid,
        file: File(image.path),
      );

      await _userService.updateUser(
        uid: currentUser.uid,
        data: {'coverImage': coverImageUrl},
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog safely
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث صورة الغلاف بنجاح'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحديث الغلاف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- Giant Design Helper Widgets ---

  Color _getCardTextColor(User user) {
    final borderId = user.profileCardBorder ?? user.activeRoomCardBorder;
    if (borderId == 'style:volcanic' || borderId == 'style:starry') {
      return Colors.white;
    }
    return Colors.black87;
  }

  Color _getCardSubTextColor(User user) {
    final borderId = user.profileCardBorder ?? user.activeRoomCardBorder;
    if (borderId == 'style:volcanic' || borderId == 'style:starry') {
      return Colors.white70;
    }
    return Colors.grey.shade600;
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    VoidCallback? onTap,
    User user,
  ) {
    final subTextColor = _getCardSubTextColor(user);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _getCardTextColor(user) == Colors.white
                  ? Colors.white
                  : Colors.teal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: subTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(height: 25, width: 1.5, color: Colors.grey.shade200);
  }

  Widget _buildStyledLevelBadge(User user, {double sizeScale = 0.8}) {
    return LevelBadge(level: user.level, size: 24 * sizeScale * 1.5);
  }

  Widget _buildLevelProgressCard(User user) {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _getCardDecoration(user),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Progress Bar on the Left
          Expanded(
            child: Container(
              height: 18,
              decoration: BoxDecoration(
                color:
                    ((user.profileCardBorder ?? user.activeRoomCardBorder) ==
                                'style:volcanic' ||
                            (user.profileCardBorder ??
                                    user.activeRoomCardBorder) ==
                                'style:starry')
                        ? Colors.white12
                        : Colors.grey.shade700,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(10),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(10),
                    ),
                    child: LinearProgressIndicator(
                      value: user.levelProgress,
                      backgroundColor: Colors.transparent,
                      minHeight: 18,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  Text(
                    '${user.exp}/${user.nextLevelExp}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Level Badge (Shield with wreath)
          _buildStyledLevelBadge(user, sizeScale: 1.0),
        ],
      ),
    );
  }

  Widget _buildTraitsCard(User user, bool isMe) {
    if (user.traits.isEmpty && !isMe) return const SizedBox.shrink();
    final subTextColor = _getCardSubTextColor(user);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: _getCardDecoration(user),
      child: Wrap(
        spacing: 8,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...user.traits.map((trait) => _buildTraitTag(trait)).toList(),
          if (isMe)
            GestureDetector(
              onTap: () => _showTraitsSelectionDialog(user),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color:
                      user.activeRoomCardBorder == 'style:volcanic' ||
                          user.activeRoomCardBorder == 'style:starry'
                      ? Colors.white12
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        user.activeRoomCardBorder == 'style:volcanic' ||
                            user.activeRoomCardBorder == 'style:starry'
                        ? Colors.white24
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 16,
                      color: subTextColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.traits.isEmpty ? 'أضف سماتك' : 'تعديل',
                      style: TextStyle(
                        fontSize: 12,
                        color: subTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showTraitsSelectionDialog(User user) async {
    final List<String> availableTraits = [
      'موسيقى',
      'رياضة',
      'ألعاب',
      'سفر',
      'قراءة',
      'تصوير',
      'طبخ',
      'تقنية',
      'سينما',
      'رسم',
      'برمجة',
      'تجارة',
      'سيارات',
      'حيوانات',
      'فضاء',
      'تصميم',
      'تمثيل',
      'غناء',
      'رقص',
      'كتابة',
    ];
    List<String> selectedTraits = List.from(user.traits);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'اختر سماتك الشخصية',
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: availableTraits.map((trait) {
                      final isSelected = selectedTraits.contains(trait);
                      return FilterChip(
                        label: Text(trait),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              if (selectedTraits.length < 4) {
                                selectedTraits.add(trait);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'يمكنك اختيار 4 سمات بحد أقصى',
                                    ),
                                  ),
                                );
                              }
                            } else {
                              selectedTraits.remove(trait);
                            }
                          });
                        },
                        selectedColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.2),
                        checkmarkColor: Theme.of(context).primaryColor,
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await UserService().updateUser(
                        uid: user.uid,
                        data: {'traits': selectedTraits},
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('حدث خطأ أثناء التحديث'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTraitTag(String label) {
    final Map<String, Color> traitColors = {
      'موسيقى': Colors.blue,
      'رياضة': Colors.green,
      'ألعاب': Colors.orange,
      'سفر': Colors.purple,
      'قراءة': Colors.teal,
      'تصوير': Colors.indigo,
      'طبخ': Colors.red,
      'تقنية': Colors.cyan,
      'سينما': Colors.pink,
      'رسم': Colors.amber,
      'برمجة': Colors.deepPurple,
      'تجارة': Colors.brown,
      'سيارات': Colors.blueGrey,
      'حيوانات': Colors.lightGreen,
      'فضاء': Colors.deepOrange,
      'تصميم': Colors.pinkAccent,
      'تمثيل': Colors.indigoAccent,
      'غناء': Colors.lightBlue,
      'رقص': Colors.deepPurpleAccent,
      'كتابة': Colors.blueGrey,
    };

    final color = traitColors[label] ?? Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35), width: 1.2),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color.withOpacity(0.9),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGiantActionBtn({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    List<Color>? gradient,
    Color? color,
    Color textColor = Colors.white,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient != null ? LinearGradient(colors: gradient) : null,
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: gradient != null
            ? [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: textColor),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVIPWalletCard(BuildContext context, User user) {
    String format(num number) {
      if (number >= 1000000000000) {
        return '${(number / 1000000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}t';
      }
      if (number >= 1000000000) {
        return '${(number / 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}b';
      }
      if (number >= 1000000) {
        return '${(number / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}m';
      }
      if (number >= 1000) {
        return '${(number / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k';
      }
      return number.toString();
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/wallet'),
      child: Container(
        width: double.infinity,
        height: 180,
        margin: const EdgeInsets.symmetric(
          horizontal: 4,
        ), // Add margin if needed
        decoration: _getCardDecoration(
          user,
          defaultDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF141E30),
                Color(0xFF243B55),
              ], // Premium Dark Blue-Grey
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF243B55).withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative Background Shapes
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'رصيد المحفظة',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Text(
                              'شحن ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 10,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      // Gold Section
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: Lottie.asset(
                                'assets/lottie/Fake 3D vector coin.json',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'الذهب',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                format(user.coins),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildVerticalDivider(),
                      // Meto Chips Section (The Green one)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ScaleTransition(
                              scale: Tween(begin: 1.0, end: 1.15).animate(
                                CurvedAnimation(
                                  parent: _chipsController,
                                  curve: Curves.easeInOutBack,
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/coinsmeto.png',
                                width: 25,
                                height: 25,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'ميتو',
                              style: TextStyle(
                                color: Color(0xFF00BFA5),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                format(user.meto_chips),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildVerticalDivider(),
                      // Diamonds Section
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: Lottie.asset(
                                'assets/lottie/Diomand Loading.json',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'الألماس',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                format(user.diamonds),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withAlpha(25),
      margin: const EdgeInsets.symmetric(horizontal: 5),
    );
  }

  Widget _buildUserRoomCard(String userId) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _voiceRoomService.getUserRoomStream(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final room = snapshot.data!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              colors: [Colors.teal.shade400, Colors.teal.shade700],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.shade700.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1), // Glass effect
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const _AudioWaveVisualizer(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الغرفة الصوتية',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        room['name'] ?? 'غرفة ${room['id']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/voice-room',
                      arguments: {'roomId': room['id']},
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.teal.shade700,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('دخول'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value,
    Color color,
    User user,
  ) {
    final isDark = _getCardTextColor(user) == Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultVerif(User user) {
    return Image.asset(
      'assets/images/verification/verified_${user.verificationTier ?? 'blue'}.png',
      width: 24,
      height: 24,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.verified_rounded, color: Colors.blue, size: 24),
    );
  }

  BoxDecoration _getCardDecoration(
    User user, {
    BoxDecoration? defaultDecoration,
  }) {
    // Use profileCardBorder if available, otherwise fallback to activeRoomCardBorder
    final borderId =
        (user.profileCardBorder != null && user.profileCardBorder!.isNotEmpty)
            ? user.profileCardBorder
            : user.activeRoomCardBorder;

    if (borderId == null || borderId.isEmpty) {
      return defaultDecoration ??
          BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          );
    }

    Border? border;
    List<BoxShadow> shadows = [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 15,
        offset: const Offset(0, 5),
      ),
    ];
    Color cardColor = Colors.white;
    Gradient? gradient;

    if (borderId.startsWith('color:')) {
        try {
          String colorStr = borderId.split(':')[1];
          int? colorCode;
          if (colorStr.startsWith('0x')) {
            colorCode = int.tryParse(colorStr.substring(2), radix: 16);
          } else {
            colorCode =
                int.tryParse(colorStr) ?? int.tryParse(colorStr, radix: 16);
          }

          if (colorCode != null) {
            border = Border.all(
              color: Color(colorCode).withOpacity(1.0),
              width: 2.5, // Increased width for better visibility
            );
          }
        } catch (_) {}
      } else if (borderId == 'style:neon') {
        border = Border.all(color: Colors.cyanAccent, width: 2);
        shadows = [
          BoxShadow(
            color: Colors.cyanAccent.withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 1,
          ),
          ...shadows,
        ];
      } else if (borderId == 'style:royal') {
        border = Border.all(color: const Color(0xFFFFD700), width: 3);
        shadows = [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          ...shadows,
        ];
        cardColor = const Color(0xFFFFFDF0); // Creamy royal white
      } else if (borderId == 'style:volcanic') {
        border = Border.all(color: const Color(0xFFFF4500), width: 2.5);
        shadows = [
          BoxShadow(
            color: const Color(0xFFFF4500).withOpacity(0.5),
            blurRadius: 18,
            spreadRadius: 2,
          ),
          const BoxShadow(color: Colors.black26, blurRadius: 10),
        ];
        cardColor = const Color(0xFF1A0A05); // Very dark brown/black
      } else if (borderId == 'style:starry') {
        // حد وردي-ذهبي فاخر مشابه لإطار الكريستالات
        border = Border.all(color: const Color(0xFFFFD700), width: 3.5);
        shadows = [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.55),
            blurRadius: 22,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: const Color(0xFFFF69B4).withOpacity(0.45),
            blurRadius: 14,
            spreadRadius: 1,
          ),
          const BoxShadow(color: Colors.black38, blurRadius: 10),
        ];
        gradient = const LinearGradient(
          colors: [Color(0xFF1A0E2E), Color(0xFF2D1B4E), Color(0xFF1A0E2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      }

    return BoxDecoration(
      color: cardColor != Colors.white
          ? cardColor
          : (defaultDecoration?.color ?? cardColor),
      gradient: gradient ?? defaultDecoration?.gradient,
      borderRadius:
          defaultDecoration?.borderRadius ?? BorderRadius.circular(25),
      border: border,
      boxShadow: shadows,
    );
  }

  Future<void> _showFrameSelection(BuildContext context, User user) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileFrameSelectionSheet(
        currentFrame: user.profileFrame,
        profileImageUrl: user.profileImage,
      ),
    );
    // Refresh the UI after selection closes
    if (mounted) setState(() {});
  }

  Widget _buildGameStats(User user) {
    final int played = user.gamesPlayed;
    final int wins = user.wins;
    final double winRate = played > 0 ? (wins / played) * 100 : 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Achievement Records (سجل الإنجازات)
          _buildRedesignedSectionHeader('سجل الإنجازات'),
          const SizedBox(height: 16),
          _buildGamesTable(user, played, wins, winRate),

          const SizedBox(height: 32),

          // Section 2: League Championship (بطولة الدوري)
          _buildRedesignedSectionHeader('بطولة الدوري'),
          const SizedBox(height: 20),
          _buildLeagueSection(user),

          const SizedBox(height: 40),

          // Section 3: Social Links (تواصل معنا)
          _buildSocialLinks(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSocialLinks() {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'تواصل معنا',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialIcon(
                'assets/images/twasell/facebook.png',
                '',
                () => _launchURL('https://www.facebook.com/share/18Sh6Wbo1r'),
              ),
              _buildSocialIcon('assets/images/twasell/insta.png', '', () {
                _launchURL('https://www.instagram.com/meto.app');
              }),
              _buildSocialIcon(
                'assets/images/twasell/telgram.png',
                '',
                () => _launchURL('https://t.me/metoapp1'),
              ),
              _buildSocialIcon('assets/images/twasell/tiktok.png', '', () {
                _launchURL('https://www.tiktok.com/@metoapp');
              }),
              _buildSocialIcon('assets/images/twasell/email.png', '', () {}),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(String path, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                path,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.link_rounded, color: Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedesignedSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF009688), Color(0xFF00BFA5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesTable(
    User user,
    int totalPlayed,
    int totalWins,
    double totalRate,
  ) {
    // Helper to get stats safely
    Map<String, dynamic> getStats(String gameId) {
      return Map<String, dynamic>.from(
        user.gameStats[gameId] ?? {'played': 0, 'wins': 0},
      );
    }

    final ludo = getStats('ludo');
    final domino = getStats('domino');
    final snakes = getStats('snakes');

    String formatGameRate(Map<String, dynamic> stats) {
      final p = stats['played'] ?? 0;
      final w = stats['wins'] ?? 0;
      if (p == 0) return '0.0%';
      return '${((w / p) * 100).toStringAsFixed(1)}%';
    }

    String formatRecord(Map<String, dynamic> stats) {
      return '${stats['wins'] ?? 0}/${stats['played'] ?? 0}';
    }

    return Column(
      children: [
        // Premium Summary Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _getCardDecoration(
            user,
            defaultDecoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1A1A), Color(0xFF333333)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الإحصائيات العامة',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${totalRate.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    'المباريات',
                    totalPlayed.toString(),
                    Icons.sports_esports_rounded,
                    Colors.cyan,
                  ),
                  _buildSummaryItem(
                    'الفوز',
                    totalWins.toString(),
                    Icons.emoji_events_rounded,
                    Colors.greenAccent,
                  ),
                  _buildSummaryItem(
                    'الخسارة',
                    (totalPlayed - totalWins).toString(),
                    Icons.close_rounded,
                    Colors.redAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Individual Game Cards with REAL DATA
        _buildGameDetailCard(
          user,
          'لودو (Ludo)',
          formatRecord(ludo),
          formatGameRate(ludo),
          'assets/images/ludo.png',
          Colors.pink.shade400,
        ),
        const SizedBox(height: 12),
        _buildGameDetailCard(
          user,
          'دومينو (Domino)',
          formatRecord(domino),
          formatGameRate(domino),
          'assets/images/domi.png',
          Colors.blue.shade400,
        ),
        const SizedBox(height: 12),
        _buildGameDetailCard(
          user,
          'سلم وثعبان',
          formatRecord(snakes),
          formatGameRate(snakes),
          'assets/images/snack.png',
          Colors.green.shade400,
        ),
      ],
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color.withValues(alpha: 0.7), size: 20),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontFamily: 'Tajawal',
          ),
        ),
      ],
    );
  }

  Widget _buildGameDetailCard(
    User user,
    String name,
    String record,
    String rate,
    String iconPath,
    Color themeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _getCardDecoration(
        user,
        defaultDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
              image: DecorationImage(
                image: AssetImage(iconPath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _getCardTextColor(user),
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 12,
                      color: _getCardSubTextColor(user),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'معدل الفوز: $rate',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getCardSubTextColor(user),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              record,
              style: TextStyle(
                color: themeColor,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeagueSection(User user) {
    return Row(
      children: [
        _buildLeagueBadge(
          user,
          'البيانات الحالية',
          user.leagueRank > 0 ? user.leagueRank.toString() : '-',
          Colors.cyan.shade400,
        ),
        const SizedBox(width: 20),
        _buildLeagueBadge(
          user,
          'أفضل البيانات',
          user.bestLeagueRank > 0 ? user.bestLeagueRank.toString() : '-',
          Colors.orange.shade400,
        ),
      ],
    );
  }

  Widget _buildLeagueBadge(User user, String label, String rank, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _getCardDecoration(
          user,
          defaultDecoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: _getCardSubTextColor(user),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.shield_rounded,
                  color: color.withOpacity(0.15),
                  size: 60,
                ),
                Image.asset(
                  'assets/images/trophy_3d.png',
                  width: 35,
                  height: 35,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'الترتيب: $rank',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height + 1; // +1 for border
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _tabBar,
          Container(height: 1, color: Colors.grey.shade100),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class _AudioWaveVisualizer extends StatefulWidget {
  const _AudioWaveVisualizer();

  @override
  State<_AudioWaveVisualizer> createState() => _AudioWaveVisualizerState();
}

class _AudioWaveVisualizerState extends State<_AudioWaveVisualizer>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 600 + index * 200),
      )..repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controllers[index],
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 3,
                height: 10 + (_controllers[index].value * 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _AutoScrollText({required this.text, required this.style});

  @override
  State<_AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<_AutoScrollText> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Delay start to ensure everything is rendered
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _startScrolling();
    });
  }

  void _startScrolling() {
    if (!mounted) return;
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(_scrollController.offset + 0.7);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure text width
        final textSpan = TextSpan(text: widget.text, style: widget.style);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.rtl,
        )..layout(maxWidth: double.infinity);

        final textWidth = textPainter.width;

        // If text fits within the card, show it normally (static)
        if (textWidth <= constraints.maxWidth) {
          return Center(
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        // If text is long, use the classic marquee effect
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _scrollController,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              // Spacing equal to container width to let text start from "outside"
              SizedBox(width: constraints.maxWidth),
              Text(widget.text, style: widget.style),
              // Spacing equal to container width to let text fully "exit"
              SizedBox(width: constraints.maxWidth),
            ],
          ),
        );
      },
    );
  }
}

class LevelBadgePainter extends CustomPainter {
  final Color color;
  LevelBadgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final wreathPaint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;
    final double centerX = w / 2;
    final double centerY = h / 2;

    // 1. Draw Wreath (Proportional)
    Path wreathPath = Path();
    // Left leaf
    wreathPath.moveTo(centerX - w * 0.2, centerY + h * 0.25);
    wreathPath.quadraticBezierTo(
      centerX - w * 0.45,
      centerY + h * 0.2,
      centerX - w * 0.4,
      centerY - h * 0.2,
    );
    // Right leaf
    wreathPath.moveTo(centerX + w * 0.2, centerY + h * 0.25);
    wreathPath.quadraticBezierTo(
      centerX + w * 0.45,
      centerY + h * 0.2,
      centerX + w * 0.4,
      centerY - h * 0.2,
    );

    canvas.drawPath(wreathPath, wreathPaint);

    // Draw small leaf stems (Proportional)
    for (int i = 0; i < 4; i++) {
      double yOff = i * (h * 0.13);
      canvas.drawLine(
        Offset(centerX - w * 0.3, centerY + h * 0.18 - yOff),
        Offset(centerX - w * 0.4, centerY + h * 0.1 - yOff),
        wreathPaint..strokeWidth = w * 0.025,
      );
      canvas.drawLine(
        Offset(centerX + w * 0.3, centerY + h * 0.18 - yOff),
        Offset(centerX + w * 0.4, centerY + h * 0.1 - yOff),
        wreathPaint,
      );
    }

    // 2. Draw Shield Proportional
    Path shieldPath = Path();
    double sw = w * 0.2; // shield half width
    double sh = h * 0.35; // shield half height

    shieldPath.moveTo(centerX - sw, centerY - sh);
    shieldPath.lineTo(centerX + sw, centerY - sh);
    shieldPath.lineTo(centerX + sw, centerY + sh * 0.3);
    shieldPath.quadraticBezierTo(
      centerX + sw,
      centerY + sh * 0.8,
      centerX,
      centerY + sh,
    );
    shieldPath.quadraticBezierTo(
      centerX - sw,
      centerY + sh * 0.8,
      centerX - sw,
      centerY + sh * 0.3,
    );
    shieldPath.close();

    canvas.drawPath(shieldPath, shadowPaint);

    // 3. Draw Shield with Gradient
    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: w,
      height: h,
    );
    paint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color, color.withOpacity(0.8)],
    ).createShader(rect);

    canvas.drawPath(shieldPath, paint);

    // 4. Draw Inner Shield Detail
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.015;

    Path innerPath = Path();
    double isw = sw * 0.75;
    double ish = sh * 0.8;
    innerPath.moveTo(centerX - isw, centerY - ish);
    innerPath.lineTo(centerX + isw, centerY - ish);
    innerPath.lineTo(centerX + isw, centerY + ish * 0.2);
    innerPath.quadraticBezierTo(
      centerX + isw,
      centerY + ish * 0.7,
      centerX,
      centerY + h * 0.35,
    );
    innerPath.quadraticBezierTo(
      centerX - isw,
      centerY + ish * 0.7,
      centerX - isw,
      centerY + ish * 0.2,
    );
    innerPath.close();

    canvas.drawPath(innerPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
