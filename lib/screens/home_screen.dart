// ignore_for_file: unused_element_parameter

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:mmmm/services/story_service.dart';
import 'package:mmmm/services/post_service.dart';
import 'package:mmmm/services/user_service.dart';
import 'package:mmmm/models/index.dart';
import 'package:mmmm/screens/post_search_screen.dart';
import 'package:mmmm/screens/add_story_screen.dart';
import 'package:mmmm/screens/comments_screen.dart';
import 'package:mmmm/screens/add_post_screen.dart';
import 'package:mmmm/screens/profile_screen.dart';
import 'package:mmmm/screens/story_view_screen.dart';
import 'package:mmmm/screens/shop_screen.dart';
import 'package:mmmm/widgets/gift_selection_bottom_sheet.dart';
import 'package:mmmm/widgets/post_gifts_summary_bottom_sheet.dart';
import 'package:mmmm/services/notification_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:just_audio/just_audio.dart';
import 'package:lottie/lottie.dart';
import '../services/story_upload_manager.dart';
import 'package:mmmm/widgets/news_ticker.dart';
import 'package:mmmm/widgets/framed_avatar.dart';
import 'daily_tasks_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  double _pullDistance = 0.0;
  bool _isRefreshing = false;
  late Stream<List<Story>> _storiesStream;
  late Stream<List<Post>> _postsStream;
  User? _currentUser;
  String _selectedProvince = 'جميع المحافظات';
  final List<String> _provinces = [
    'جميع المحافظات',
    'بغداد',
    'البصرة',
    'نينوى',
    'أربيل',
    'النجف',
    'كربلاء',
    'كركوك',
    'ديالى',
    'بابل',
    'الأنبار',
    'ذي قار',
    'ميسان',
    'المثنى',
    'القادسية',
    'صلاح الدين',
    'دهوك',
    'السليمانية',
    'حلبجة',
  ];

  @override
  void initState() {
    super.initState();
    _storiesStream = StoryService().getStoriesStream();
    _postsStream = PostService().getPostsStream();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _loadUserData();

    // تشغيل مؤقت التسوية اليومي ومكافآت التفاعلات عند منتصف الليل
    PostService().startMidnightSettlementTimer();
    PostService().processDailyPostReactionRewards();
  }

  Future<void> _loadUserData() async {
    final uid = auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final user = await UserService().getUser(uid);
      if (mounted) {
        setState(() => _currentUser = user);
      }
    }
  }

  Stream<int> _getUnreadNotificationsStream(String userId) {
    return NotificationService()
        .getNotificationsStream(userId)
        .map((notifications) => notifications.where((n) => !n.isRead).length);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    // تنظيف المنشورات المنتهية عند التحديث اليدوي ومعالجة مكافآت التفاعلات
    await PostService().cleanupExpiredPosts();
    await PostService().processDailyPostReactionRewards();

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _pullDistance = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = auth.FirebaseAuth.instance.currentUser?.uid;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              if (notification.metrics.pixels < 0) {
                setState(() {
                  _pullDistance = (-notification.metrics.pixels).clamp(0, 100);
                });
              } else if (_pullDistance != 0 && !_isRefreshing) {
                setState(() {
                  _pullDistance = 0;
                });
              }
            } else if (notification is ScrollEndNotification) {
              if (_pullDistance >= 80 && !_isRefreshing) {
                _onRefresh();
              } else if (!_isRefreshing && _pullDistance != 0) {
                setState(() {
                  _pullDistance = 0;
                });
              }
            }
            return false;
          },
          child: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverAppBar(
                    toolbarHeight: 305.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    elevation: 0,
                    leading: const SizedBox.shrink(),
                    leadingWidth: 0,
                    flexibleSpace: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. Static Mesh Gradient Background
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).primaryColor,
                                Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.8),
                                Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                        // 2. Glassmorphic Overlays
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.transparent,
                                  Theme.of(context).scaffoldBackgroundColor
                                      .withValues(alpha: 0.8),
                                  Theme.of(context).scaffoldBackgroundColor,
                                ],
                                stops: const [0.0, 0.4, 0.85, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // 3. Header Content (Greeting + Search)
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'METO',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                    const Spacer(),
                                    _buildAppBarIcon(
                                      iconWidget: const Icon(
                                        Icons.checklist_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const DailyTasksScreen(),
                                          ),
                                        );
                                      },
                                      tooltip: 'المهام',
                                    ),

                                    _buildAppBarIcon(
                                      iconWidget: const Icon(
                                        Icons.search_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const UnifiedSearchScreen(),
                                          ),
                                        );
                                      },
                                      tooltip: 'البحث',
                                    ),

                                    _buildAppBarIcon(
                                      iconWidget: const Icon(
                                        Icons.shopping_cart_outlined,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ShopScreen(),
                                          ),
                                        );
                                      },
                                      tooltip: 'المتجر',
                                    ),

                                    StreamBuilder<int>(
                                      stream: currentUserId != null
                                          ? _getUnreadNotificationsStream(
                                              currentUserId,
                                            )
                                          : Stream.value(0),
                                      builder: (context, snapshot) {
                                        final unreadCount = snapshot.data ?? 0;
                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            _buildAppBarIcon(
                                              iconWidget: ColorFiltered(
                                                colorFilter:
                                                    const ColorFilter.mode(
                                                      Colors.white,
                                                      BlendMode.srcIn,
                                                    ),
                                                child: Lottie.asset(
                                                  'assets/lottie/bell_notification.json',
                                                  width: 38,
                                                  height: 38,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              onTap: () => Navigator.pushNamed(
                                                context,
                                                '/notifications',
                                              ),
                                              tooltip: 'الإشعارات',
                                            ),
                                            if (unreadCount > 0)
                                              Positioned(
                                                right: 16,
                                                top: 16,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.redAccent,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 14,
                                                        minHeight: 14,
                                                      ),
                                                  child: Center(
                                                    child: Text(
                                                      unreadCount > 9
                                                          ? '9+'
                                                          : '$unreadCount',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        height: 1,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),

                                    _buildProfileIcon(currentUserId),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Integrated Stories Section
                                SizedBox(
                                  height: 100,
                                  child: StreamBuilder<List<Story>>(
                                    initialData: StoryService().cachedStories,
                                    stream: _storiesStream,
                                    builder: (context, snapshot) {
                                      final stories = snapshot.data ?? [];
                                      final Map<String, List<Story>>
                                      userStoriesMap = {};
                                      for (var story in stories) {
                                        userStoriesMap
                                            .putIfAbsent(story.userId, () => [])
                                            .add(story);
                                      }
                                      final List<String> sortedUserIds =
                                          userStoriesMap.keys.toList();

                                      return ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        padding: EdgeInsets.zero,
                                        itemCount: sortedUserIds.length + 1,
                                        itemBuilder: (context, index) {
                                          if (index == 0) {
                                            return _buildAddStoryButton(
                                              context,
                                            );
                                          }
                                          final userId =
                                              sortedUserIds[index - 1];
                                          final userStories =
                                              userStoriesMap[userId]!;
                                          return _buildStoryCircle(
                                            userId,
                                            userStories,
                                            currentUserId,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _buildQuickPostBar(context, currentUserId),
                                NewsTicker(
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.05,
                                  ),
                                  textColor: Colors.black87,
                                  speed: 70.0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildProvinceFilter(),
                  ),
                  StreamBuilder<List<Post>>(
                    initialData: PostService().cachedPosts,
                    stream: _postsStream,
                    builder: (context, snapshot) {
                      var posts = snapshot.data ?? [];
                      
                      // تطبيق فلتر المحافظة
                      if (_selectedProvince != 'جميع المحافظات') {
                        posts = posts.where((p) => p.province == _selectedProvince).toList();
                      }

                      // Show loading only if we have NO cached data AND the stream is still waiting
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          posts.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(
                                color: Theme.of(context).primaryColor,
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                        );
                      }

                      if (posts.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.only(bottom: 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => PostCard(
                              key: ValueKey(posts[index].id),
                              post: posts[index],
                            ),
                            childCount: posts.length,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              // Custom Premium Refresh Indicator
              if (_pullDistance > 0 || _isRefreshing)
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildPremiumRefreshIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumRefreshIndicator() {
    final double progress = (_pullDistance / 80).clamp(0, 1.2);
    final isFull = progress >= 1.0;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return SizedBox(
          width: 60,
          height: 80 + (_pullDistance * 0.5),
          child: CustomPaint(
            painter: _LiquidGlowPainter(
              progress: progress,
              isRefreshing: _isRefreshing,
              animationValue: _glowController.value,
              pulseValue:
                  (1.0 +
                  0.1 * (isFull || _isRefreshing ? _glowController.value : 0)),
              colorTeal: Theme.of(context).primaryColor,
              colorAmber: Colors.amber, // keep amber for flavor or change later
              colorBlue: Theme.of(context).primaryColor.withValues(alpha: 0.6),
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: _pullDistance * 0.2),
                child: Icon(
                  _isRefreshing
                      ? Icons.auto_awesome_rounded
                      : (isFull
                            ? Icons.expand_more_rounded
                            : Icons.south_rounded),
                  size: 22,
                  color: isFull || _isRefreshing
                      ? Colors.white
                      : Theme.of(context).primaryColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBarIcon({
    required Widget iconWidget,
    required VoidCallback onTap,
    String? tooltip,
    bool isPrimary = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary ? Colors.white24 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: iconWidget,
        onPressed: onTap,
        tooltip: tooltip,
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(50),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.dashboard_outlined,
                size: 48,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'لا توجد بلاغات حالياً',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '(تختفي البلاغات بعد دقيقة من نشرها)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProvinceFilter() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedProvince,
              icon: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 20),
              ),
              isDense: true,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(16),
              items: _provinces.map((province) {
                return DropdownMenuItem(
                  value: province,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_rounded, color: Theme.of(context).primaryColor, size: 18),
                      const SizedBox(width: 6),
                      Text(province),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedProvince = val;
                  });
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddStoryButton(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: StoryUploadManager.instance.isUploading,
      builder: (context, isUploading, child) {
        if (isUploading) {
          // Uploading State
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: FramedAvatar(
                        userId: _currentUser?.uid,
                        imageUrl: _currentUser?.profileImage,
                        radius: 30,
                        useProfileFrameFallback: false,
                      ),
                    ),
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'جاري النشر...',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.teal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        // Normal Add Button
        return GestureDetector(
          onTap: () async {
            final picker = ImagePicker();
            final XFile? media = await picker.pickMedia();
            if (media != null && context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      AddStoryScreen(initialFile: File(media.path)),
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.5),
                            Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'قصتك',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStoryCircle(
    String userId,
    List<Story> userStories,
    String? currentUserId,
  ) {
    if (userStories.isEmpty) return const SizedBox.shrink();
    final firstStory = userStories.first;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoryViewScreen(
                stories: userStories,
                username: firstStory.username,
                userProfileImage: firstStory.userProfileImage,
                currentUserId: currentUserId ?? '',
              ),
            ),
          );
        },
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: const [
                        Colors.teal,
                        Colors.cyan,
                        Colors.amber,
                        Colors.teal,
                      ],
                      transform: GradientRotation(
                        _glowController.value * 2 * 3.14159,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: FramedAvatar(
                      userId: userId,
                      imageUrl: firstStory.userProfileImage,
                      radius: 30,
                      useProfileFrameFallback: false,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 65,
              child: Text(
                userId == currentUserId ? 'قصتك' : firstStory.username,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPostBar(BuildContext context, String? currentUserId) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/addPost'),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            FramedAvatar(
              userId: _currentUser?.uid,
              imageUrl: _currentUser?.profileImage,
              radius: 17,
              useProfileFrameFallback: false,
            ),
            const SizedBox(width: 15),
            const Text(
              'أنشئ بلاغاً جديداً...',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color.fromARGB(
                  255,
                  255,
                  0,
                  0,
                ).withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wb_twilight,
                color: Color.fromARGB(255, 252, 251, 251),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileIcon(String? currentUserId) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (currentUserId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(uid: currentUserId),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(
          2.0,
        ), // Slightly reduced to prevent overflow
        child: Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: FramedAvatar(
            userId: currentUserId,
            imageUrl: _currentUser?.profileImage,
            radius: 20,
            useProfileFrameFallback: true,
            disableFrame: true,
          ),
        ),
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final Post post;
  const PostCard({super.key, required this.post});

  void _showDeleteDialog(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'حذف المنشور',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('هل أنت متأكد من حذف هذا المنشور نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await PostService().deletePost(postId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حذف المنشور بنجاح')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
                }
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'إبلاغ عن محتوى',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('هل تريد الإبلاغ عن هذا المنشور لمراجعته؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final currentUserId =
                    auth.FirebaseAuth.instance.currentUser?.uid;
                if (currentUserId == null) return;

                await PostService().reportPost(
                  postId: post.id,
                  reporterId: currentUserId,
                  reason: 'محتوى غير لائق / بلاغ مستخدم',
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرسال بلاغك، شكراً لك')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في إرسال البلاغ: $e')),
                  );
                }
              }
            },
            child: const Text('إبلاغ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid;
    final isLiked = post.likedBy.contains(currentUserId);
    final isOwner = post.userId == currentUserId;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.isShared) _buildSharedHeader(context),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Avatar aligned with top row
                children: [
                  _buildUserAvatar(context),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(child: _buildUsername(context)),
                            const SizedBox(width: 6),
                            Text(
                              "•",
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              timeago.format(post.createdAt, locale: 'ar'),
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: _buildGlassBadge(
                                post.province,
                                Colors.teal,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: _buildGlassBadge(
                                post.category,
                                Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildMoreButton(context, isOwner),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                post.content,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.color?.withValues(alpha: 0.9),
                  letterSpacing: 0.1,
                ),
              ),
            ),

            // Images
            if (post.images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 450),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: post.images.first,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 200,
                        color: Colors.grey.shade50,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        color: Colors.grey.shade50,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: _LikeButton(
                              currentReaction:
                                  post.reactions[auth
                                          .FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.uid ??
                                      ''] ??
                                  (isLiked ? 'like' : null),
                              likesCount: post.likesCount,
                              onReactionSelected: (reactionType) async {
                                final currentUserId =
                                    auth.FirebaseAuth.instance.currentUser?.uid;
                                if (currentUserId == null) return;
                                final userData = await UserService().getUser(
                                  currentUserId,
                                );
                                final displayName =
                                    userData?.nickname ??
                                    userData?.username ??
                                    'مستخدم';
                                await PostService().toggleReaction(
                                  post.id,
                                  currentUserId,
                                  displayName,
                                  userData?.profileImage,
                                  post.userId,
                                  reactionType,
                                );
                              },
                            ),
                          ),
                          Flexible(
                            child: _AnimatedInteractionItem(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: post.commentsCount > 0
                                  ? post.commentsCount.toString()
                                  : '',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CommentsScreen(post: post),
                                  ),
                                );
                              },
                            ),
                          ),
                          Flexible(
                            child: _AnimatedInteractionItem(
                              icon: Icons.share_rounded,
                              label: '',
                              onTap: () =>
                                  _showShareDialog(context, currentUser!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildGiftButton(context, currentUserId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Icon(Icons.repeat_rounded, size: 16, color: Colors.teal.shade400),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'مشاركة بواسطة '),
                  TextSpan(
                    text: post.username,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(uid: post.userId),
        ),
      ),
      child: FramedAvatar(
        imageUrl: post.userProfileImage,
        radius: 20, // Reduced from 24
        userId: post.userId,
      ),
    );
  }

  Widget _buildUsername(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(uid: post.userId),
        ),
      ),
      child: Text(
        post.username,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14, // Reduced from 16
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildGlassBadge(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color.shade700,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMoreButton(BuildContext context, bool isOwner) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz_rounded, color: Colors.grey.shade400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      offset: const Offset(0, 40),
      onSelected: (value) {
        if (value == 'edit') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddPostScreen(post: post)),
          );
        } else if (value == 'delete') {
          _showDeleteDialog(context, post.id);
        } else if (value == 'report') {
          _showReportDialog(context);
        }
      },
      itemBuilder: (context) => [
        if (isOwner) ...[
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit_rounded, size: 20),
                SizedBox(width: 12),
                Text('تعديل'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                SizedBox(width: 12),
                Text('حذف', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ] else ...[
          const PopupMenuItem(
            value: 'report',
            child: Row(
              children: [
                Icon(
                  Icons.report_gmailerrorred_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
                SizedBox(width: 12),
                Text('إبلاغ'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGiftButton(BuildContext context, String? currentUserId) {
    return InkWell(
      onTap: () async {
        if (currentUserId == null) return;

        final userService = UserService();
        final userData = await userService.getUser(currentUserId);

        if (userData != null && context.mounted) {
          // إذا كان المستخدم هو كاتب المنشور، نعرض له ملخص الهدايا
          if (post.userId == currentUserId) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) =>
                  PostGiftsSummaryBottomSheet(postId: post.id),
            );
          } else {
            // إذا كان مستخدماً آخراً، نعرض له قائمة اختيار الهدايا للإرسال
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => GiftSelectionBottomSheet(
                receiverId: post.userId,
                receiverName: post.username,
                postId: post.id,
                senderId: currentUserId,
                senderName: userData.nickname ?? userData.username,
                senderProfileImage: userData.profileImage,
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade400, Colors.orange.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              size: 18,
              color: Colors.white,
            ),
            if (post.giftsCount > 0) ...[
              const SizedBox(width: 6),
              Text(
                post.giftsCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showShareDialog(BuildContext context, auth.User currentUser) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: const Text('مشاركة المنشور'),
        content: const Text(
          'هل تريد مشاركة هذا المنشور على صفحتك الشخصية ليراه متابعوك؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await PostService().sharePost(
                  originalPost: post,
                  currentUserId: currentUser.uid,
                  currentUsername: currentUser.displayName ?? 'مستخدم',
                  currentUserProfileImage: currentUser.photoURL,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت مشاركة المنشور بنجاح')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل في مشاركة المنشور: $e')),
                  );
                }
              }
            },
            child: const Text(
              'مشاركة الآن',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- Methods removed to fix unused code warnings ---
}

class _AnimatedInteractionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;

  const _AnimatedInteractionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
  });

  @override
  State<_AnimatedInteractionItem> createState() =>
      _AnimatedInteractionItemState();
}

class _AnimatedInteractionItemState extends State<_AnimatedInteractionItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? (widget.activeColor ?? Colors.teal).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: widget.isActive
                    ? (widget.activeColor ?? Colors.teal)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isActive
                        ? (widget.activeColor ?? Colors.teal)
                        : Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidGlowPainter extends CustomPainter {
  final double progress;
  final bool isRefreshing;
  final double animationValue;
  final double pulseValue;
  final Color colorTeal;
  final Color colorAmber;
  final Color colorBlue;

  _LiquidGlowPainter({
    required this.progress,
    required this.isRefreshing,
    required this.animationValue,
    required this.pulseValue,
    required this.colorTeal,
    required this.colorAmber,
    required this.colorBlue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = 24.0 * pulseValue;

    // 1. Draw Liquid Stretch
    if (progress > 0 && !isRefreshing) {
      final stretchPath = Path();
      final stretchHeight = (progress * 40.0).clamp(0.0, 50.0);
      final topWidth = baseRadius * 2;
      final bottomWidth = baseRadius * 1.2 * (1 - progress * 0.3);

      stretchPath.moveTo(center.dx - topWidth / 2, center.dy);
      stretchPath.quadraticBezierTo(
        center.dx,
        center.dy - stretchHeight,
        center.dx + topWidth / 2,
        center.dy,
      );
      stretchPath.lineTo(
        center.dx + bottomWidth / 2,
        center.dy + stretchHeight,
      );
      stretchPath.quadraticBezierTo(
        center.dx,
        center.dy + stretchHeight * 1.5,
        center.dx - bottomWidth / 2,
        center.dy + stretchHeight,
      );
      stretchPath.close();

      final liquidPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            colorTeal.withValues(alpha: 0.1 * progress.clamp(0.0, 1.0)),
            colorTeal.withValues(alpha: 0.3 * progress.clamp(0.0, 1.0)),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(stretchPath, liquidPaint);
    }

    // 2. Draw Glass Base
    final glassPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 4);
    canvas.drawCircle(center, baseRadius, glassPaint);

    // 3. Draw Glow Aura
    if (progress >= 1.0 || isRefreshing) {
      final glowPaint = Paint()
        ..color = colorTeal.withValues(
          alpha: 0.3 * (1 - (animationValue % 1.0)),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * pulseValue);
      canvas.drawCircle(center, baseRadius * 1.4, glowPaint);
    }

    // 4. Draw Animated Gradient Ring
    final rect = Rect.fromCircle(center: center, radius: baseRadius - 2);
    final ringPaint = Paint()
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [colorTeal, colorBlue, colorAmber, colorTeal],
        stops: const [0.0, 0.3, 0.7, 1.0],
        transform: GradientRotation(animationValue * 2 * 3.14159),
      ).createShader(rect);

    if (isRefreshing) {
      canvas.drawArc(rect, animationValue * 2 * 3.14159, 2, false, ringPaint);
    } else {
      canvas.drawArc(
        rect,
        -0.5 * 3.14159,
        (progress.clamp(0.0, 1.0)) * 2 * 3.14159,
        false,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidGlowPainter oldDelegate) {
    return true;
  }
}

class _LikeButton extends StatefulWidget {
  final int likesCount;
  final String? currentReaction;
  final Function(String) onReactionSelected;

  const _LikeButton({
    super.key,
    required this.likesCount,
    required this.currentReaction,
    required this.onReactionSelected,
  });

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late String? currentReaction;
  late int likesCount;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  OverlayEntry? _overlayEntry;

  final Map<String, String> _reactionAssets = {
    'like': 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f44d/lottie.json',
    'love': 'https://fonts.gstatic.com/s/e/notoemoji/latest/2764/lottie.json',
    'haha': 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f602/lottie.json',
    'wow': 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f62e/lottie.json',
    'sad': 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f622/lottie.json',
    'angry': 'https://fonts.gstatic.com/s/e/notoemoji/latest/1f621/lottie.json',
  };

  final Map<String, Color> _reactionColors = {
    'like': Colors.blue,
    'love': Colors.red,
    'haha': Colors.amber,
    'wow': Colors.orange,
    'sad': Colors.amberAccent,
    'angry': Colors.redAccent,
  };

  final Map<String, String> _reactionLabels = {
    'like': '👍',
    'love': '❤️',
    'haha': '😂',
    'wow': '😮',
    'sad': '😢',
    'angry': '😡',
  };

  @override
  void initState() {
    super.initState();
    currentReaction = widget.currentReaction;
    likesCount = widget.likesCount;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
  }

  @override
  void didUpdateWidget(_LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentReaction != oldWidget.currentReaction ||
        widget.likesCount != oldWidget.likesCount) {
      currentReaction = widget.currentReaction;
      likesCount = widget.likesCount;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showReactionMenu(BuildContext context) {
    _removeOverlay();
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _removeOverlay,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            top: position.dy - 60, // Position above the button
            left: 20, // Check bounds in real app
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _reactionAssets.entries.map((entry) {
                    return GestureDetector(
                      onTap: () {
                        _handleReactionSelect(entry.key);
                        _removeOverlay();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Lottie.network(
                          entry.value,
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                          repeat: true,
                          animate: true,
                          errorBuilder: (context, error, stackTrace) => Text(
                            _reactionLabels[entry.key] ?? '?',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _handleReactionSelect(String type) {
    _controller.forward().then((_) => _controller.reverse());

    setState(() {
      if (currentReaction == type) {
        // Untoggle if same reaction
        currentReaction = null;
        likesCount = (likesCount - 1).clamp(0, 999999);
      } else {
        // Change or add reaction
        if (currentReaction == null) {
          likesCount++;
        }
        currentReaction = type;
      }
    });

    // Validating Sound
    try {
      final player = AudioPlayer();
      player
          .setAsset('assets/sounds/like.wav')
          .then((_) {
            player.play();
            // Optional: dispose after playing, but difficult with async.
            // Better to keep a single instance if frequent.
            // For now, let GC handle it or use a persistent player.
            // But relying on GC for audio resources is risky on Android.
            // Ideally we dispose.
            player.playerStateStream.listen((state) {
              if (state.processingState == ProcessingState.completed) {
                player.dispose();
              }
            });
          })
          .catchError((e) {
            debugPrint('Error playing sound: $e');
            player.dispose();
          });
    } catch (e) {
      debugPrint('Error: $e');
    }

    widget.onReactionSelected(type);
  }

  void _handleTap() {
    // Default tap toggles 'like' if not reacted, or removes reaction if reacted
    final type = currentReaction == null ? 'like' : currentReaction!;
    _handleReactionSelect(type);
  }

  @override
  Widget build(BuildContext context) {
    final isReacted = currentReaction != null;
    final color = isReacted
        ? (_reactionColors[currentReaction] ?? Colors.pinkAccent)
        : Colors.grey.shade600;

    // Using Lottie for animated reactions
    Widget iconWidget;
    if (isReacted) {
      iconWidget = Lottie.network(
        _reactionAssets[currentReaction] ??
            'https://fonts.gstatic.com/s/e/notoemoji/latest/1f44d/lottie.json',
        width: 24,
        height: 24,
        repeat: true, // Enable looping
        animate: true,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to text emoji if lottie fails
          return Text(
            _reactionLabels[currentReaction] ?? '❤️',
            style: const TextStyle(fontSize: 18),
          );
        },
      );
    } else {
      iconWidget = Icon(
        Icons.thumb_up_alt_outlined,
        size: 20,
        color: Colors.grey.shade600,
      );
    }

    return GestureDetector(
      onTap: _handleTap,
      onLongPress: () => _showReactionMenu(context),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isReacted
                ? color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  likesCount > 0 ? likesCount.toString() : '',
                  style: TextStyle(
                    color: color,
                    fontSize: 12, // slightly smaller to fit text
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
