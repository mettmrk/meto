import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/voice_room_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import 'voice_room_screen.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/framed_avatar.dart';
import 'profile_screen.dart';

class VoiceRoomListScreen extends StatefulWidget {
  const VoiceRoomListScreen({super.key});

  @override
  State<VoiceRoomListScreen> createState() => _VoiceRoomListScreenState();
}

class _VoiceRoomListScreenState extends State<VoiceRoomListScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<int> _topTabNotifier = ValueNotifier(2);
  final ValueNotifier<int> _categoryNotifier = ValueNotifier(0);
  late final PageController _categoryPageController;
  final Set<String> _syncedRoomFrameIds = <String>{};

  @override
  void initState() {
    super.initState();
    _categoryPageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _categoryPageController.dispose();
    _topTabNotifier.dispose();
    _categoryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceRoomService>(context, listen: false);
    final userService = UserService();
    final currentUser = auth.FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                // Nav bar: only tab indicators rebuild via ValueListenableBuilder
                ValueListenableBuilder<int>(
                  valueListenable: _topTabNotifier,
                  builder: (ctx, topIdx, _) =>
                      _buildTopNav(ctx, userService, currentUser?.uid, topIdx),
                ),
                // IndexedStack keeps all 3 tabs alive — zero rebuild when switching
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _topTabNotifier,
                    builder: (ctx, topIdx, _) => IndexedStack(
                      index: topIdx,
                      children: [
                        _buildDiscoveryContent(voiceService, currentUser?.uid),
                        _buildPopularContent(voiceService, currentUser?.uid),
                        _buildMyRoomContent(voiceService, currentUser?.uid),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryContent(VoiceRoomService service, String? currentUid) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildStreamGrid(
              stream: service.getDiscoveryRoomsStream(),
              initialData: service.cachedDiscoveryRooms,
              excludeUid: currentUid,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPopularContent(VoiceRoomService service, String? currentUid) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildStreamGrid(
              stream: service.getPopularRoomsStream(),
              initialData: service.cachedPopularRooms,
              excludeUid: currentUid,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMyRoomContent(VoiceRoomService service, String? uid) {
    return Column(
      children: [
        const SizedBox(height: 16),
        StreamBuilder<Map<String, dynamic>?>(
          initialData: service.cachedMyRoom,
          stream: service.getMyRoomStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const SizedBox(height: 150);
            }
            final myRoom = snapshot.data;
            return myRoom != null
                ? _buildMyRoomBanner(myRoom)
                : _buildCreateRoomPlaceholder(service, uid);
          },
        ),
        const SizedBox(height: 10),
        _buildCategoryBar(),
        Expanded(
          child: PageView(
            controller: _categoryPageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (page) => _categoryNotifier.value = page,
            children: [
              _buildCategoryPage(service, 0, excludeUid: uid),
              _buildCategoryPage(service, 1, excludeUid: uid),
              _buildCategoryPage(service, 2, excludeUid: uid),
              _buildCategoryPage(service, 3, excludeUid: uid),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreamGrid({
    required Stream<List<Map<String, dynamic>>> stream,
    List<Map<String, dynamic>>? initialData,
    String? excludeUid, // hide the current user's own room
  }) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      initialData: initialData,
      stream: stream,
      builder: (context, snapshot) {
        final allRooms = snapshot.data ?? [];
        // Filter out paused rooms, and the current user's own room from public lists
        final rooms = excludeUid == null
            ? allRooms.where((r) => r['isPaused'] != true).toList()
            : allRooms.where((r) => r['hostId'] != excludeUid && r['isPaused'] != true).toList();

        if (snapshot.connectionState == ConnectionState.waiting &&
            rooms.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (rooms.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'لا توجد غرف هنا',
                style: TextStyle(color: Colors.white54, fontFamily: 'Tajawal'),
              ),
            ),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: rooms.length,
          itemBuilder: (context, index) => _buildRoomCard(rooms[index]),
        );
      },
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF084B46), // Lighter Dark Teal
            const Color(0xFF063B37), // Lighter Mid Teal
            const Color(0xFF03221E), // Soft Dark Teal
          ],
        ),
      ),
      child: Stack(
        children: [
          // Top ambient glowing orb
          Positioned(
            top: -150,
            left: -50,
            right: -50,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Subtle texture or floating elements could be added here later
        ],
      ),
    );
  }

  Widget _buildTopNav(
    BuildContext context,
    UserService userService,
    String? uid,
    int topIdx,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFFA5C5BE),
                  size: 28,
                ),
                onPressed: () async {
                  final service = Provider.of<VoiceRoomService>(
                    context,
                    listen: false,
                  );
                  final allRoomsSet = <String, Map<String, dynamic>>{};
                  for (final r
                      in (service.cachedRooms ??
                          const <Map<String, dynamic>>[])) {
                    allRoomsSet[r['id']] = r;
                  }
                  for (final r
                      in (service.cachedPopularRooms ??
                          const <Map<String, dynamic>>[])) {
                    allRoomsSet[r['id']] = r;
                  }
                  for (final r
                      in (service.cachedDiscoveryRooms ??
                          const <Map<String, dynamic>>[])) {
                    allRoomsSet[r['id']] = r;
                  }

                  final selectedRoom = await showSearch<Map<String, dynamic>?>(
                    context: context,
                    delegate: RoomSearchDelegate(
                      allRoomsSet.values.toList(),
                      (room, onTap) => _buildRoomCard(room, onTap: onTap),
                    ),
                  );
                  if (selectedRoom != null && context.mounted) {
                    _handleJoinRoom(selectedRoom);
                  }
                },
              ),
            ],
          ),

          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTopTab('جميع الغرف', 0, topIdx),
                  const SizedBox(width: 8),
                  _buildTopTab('شائعة', 1, topIdx),
                  const SizedBox(width: 8),
                  _buildTopTab('غرفتي', 2, topIdx),
                ],
              ),
            ),
          ),

          if (uid != null)
            StreamBuilder<User?>(
              stream: userService.getUserStream(uid),
              builder: (context, snapshot) {
                final user = snapshot.data;
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(uid: uid),
                      ),
                    );
                  },
                  child: Stack(
                    children: [
                      FramedAvatar(
                        userId: uid,
                        imageUrl: user?.profileImage,
                        radius: 20,
                        useProfileFrameFallback: false,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${user?.level ?? 1}',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          else
            const SizedBox(width: 45, height: 45),
        ],
      ),
    );
  }

  Widget _buildTopTab(String label, int index, int activeIndex) {
    final bool isActive = activeIndex == index;
    return GestureDetector(
      onTap: () => _topTabNotifier.value = index,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ), // Reduced padding
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(color: Colors.white.withOpacity(0.2), width: 1)
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFFA5C5BE),
                fontSize: isActive ? 14 : 12, // Scaled down font sizes
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'Tajawal',
                letterSpacing: 0.2, // Reduced letter spacing
                shadows: isActive
                    ? [
                        Shadow(
                          color: Theme.of(context).primaryColor,
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: isActive ? 1.0 : 0.0,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                width: 16,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.cyanAccent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRoomBanner(Map<String, dynamic> room) {
    final dynamic cardFrameImage =
        room['cardFrameImage'] ??
        room['roomFrameImage'] ??
        room['roomFrame'] ??
        room['frameImage'] ??
        room['frameUrl'];
    final String? cardFrameImagePath = cardFrameImage?.toString();
    final String resolvedCardFrameSource =
        (cardFrameImagePath != null && cardFrameImagePath.isNotEmpty && cardFrameImagePath != 'assets/images/rom.png')
        ? FramedAvatar.getFrameAsset(cardFrameImagePath)
        : '';

    return GestureDetector(
      onTap: () => _handleJoinRoom(room),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // The Scroll/Paper style banner
          // 3D Glassmorphic Premium Banner
          Container(
            margin: const EdgeInsets.only(
              top: 27,
              left: 50,
              right: 40,
              bottom: 12,
            ),
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF26A69A), // Vibrant teal color splash at the start
                  Colors.white, // Quickly fading into pure white
                  Colors.white, // White takes the majority of the card
                ],
                stops: [
                  0.0,
                  0.35,
                  1.0,
                ], // Teal occupies the first 35%, the rest 65% is pure white
              ),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: Colors.white,
                width: 2,
              ), // Solid white border
              boxShadow: [
                // Deep 3D Shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
                // Pseudo Top-left lighting highlight
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 2,
                  offset: const Offset(-2, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(
                          0.04,
                        ), // Lighter translucent background for white card
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.05),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${(room['users'] as Map?)?.length ?? 0}',
                            style: const TextStyle(
                              color: Color(
                                0xFF042F2C,
                              ), // Dark text for white background
                              fontWeight: FontWeight.bold,
                              fontSize: 12, // Reduced size
                            ),
                          ),
                          const SizedBox(width: 6),
                          const SoundWaveWidget(
                            color: Color(0xFF042F2C), // Dark wave
                            size: 14,
                            barCount: 3,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF084B46),
                            Color(0xFF03221E),
                          ], // Matches page background
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF03221E,
                            ).withOpacity(0.5), // Subtle dark teal shadow
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'غرفتي',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDynamicFlag(room['hostId']),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        room['name'] ?? 'اسم الغرفة',
                        style: const TextStyle(
                          color: Color(0xFF042F2C),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  room['description'] ?? 'أهلاً بكم في غرفتي الخاصة',
                  textAlign: TextAlign.center,
                  maxLines: 1, // Restrict to 1 line for smaller banner
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.blueGrey.shade700, // Dark greyish-blue
                    fontSize: 9.5,
                    // Removed fontStyle: FontStyle.italic
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Card frame (above the banner)
          if (resolvedCardFrameSource.isNotEmpty)
            Positioned(
              top: 5,
              left: -5,
              right: -5,
              bottom: -15,
              child: IgnorePointer(
                child: resolvedCardFrameSource.startsWith('http')
                    ? Image.network(
                        resolvedCardFrameSource,
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      )
                    : Image.asset(
                        resolvedCardFrameSource,
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
              ),
            ),

          // Circular Room Image above the banner
          Positioned(
            top: 0,
            child: Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF80CBC4),
                    Color(0xFF004D40),
                  ], // Cool teal 3D gradient for avatar border
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FramedAvatar(
                userId: room['hostId'],
                imageUrl:
                    (room['imageUrl'] != null &&
                        room['imageUrl'].toString().isNotEmpty)
                    ? room['imageUrl']
                    : 'https://i.pravatar.cc/100?img=12',
                radius: 28,
                useProfileFrameFallback: false,
              ),
            ),
          ),
          // Banned Icon overlay for My Room
          if (room['isBanned'] == true)
            Positioned(
              top: 0,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent, width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.block_rounded,
                    color: Colors.redAccent,
                    size: 36,
                  ),
                ),
              ),
            ),
          // Lock Icon overlay for My Room
          if (room['isLocked'] == true &&
              (room['lockExpiresAt'] as Timestamp?)?.toDate().isAfter(
                    DateTime.now(),
                  ) ==
                  true)
            Positioned(
              top: 0,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_rounded,
                    color: Colors.amber,
                    size: 36,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateRoomPlaceholder(VoiceRoomService service, String? uid) {
    return GestureDetector(
      onTap: () => _showCreateRoomDialog(context, service, uid),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.white70,
                size: 40,
              ),
              SizedBox(height: 8),
              Text(
                'أنشئ غرفتك الخاصة',
                style: TextStyle(color: Colors.white70, fontFamily: 'Tajawal'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPage(
    VoiceRoomService service,
    int categoryIndex, {
    String? excludeUid,
  }) {
    Stream<List<Map<String, dynamic>>> stream;
    List<Map<String, dynamic>>? initialData;

    switch (categoryIndex) {
      case 0:
        stream = service.getRecentlyEnteredRoomsStream();
        initialData = service.cachedRecentRooms;
        break;
      case 1:
        stream = service.getJoinedRoomsStream();
        initialData = service.cachedJoinedRooms;
        break;
      case 2:
        stream = service.getFollowedRoomsStream();
        break;
      case 3:
        stream = service.getFriendRecommendedRoomsStream();
        break;
      default:
        stream = service.getRoomsStream();
        initialData = service.cachedRooms;
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('category_page_$categoryIndex'),
      initialData: initialData,
      stream: stream,
      builder: (context, snapshot) {
        final allRooms = snapshot.data ?? [];
        // Filter out the current user's own room
        final rooms = excludeUid == null
            ? allRooms
            : allRooms.where((r) => r['hostId'] != excludeUid).toList();

        if (snapshot.connectionState == ConnectionState.waiting &&
            rooms.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (rooms.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد غرف هنا',
              style: TextStyle(color: Colors.white54, fontFamily: 'Tajawal'),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: rooms.length,
          itemBuilder: (context, index) =>
              _buildRoomCard(rooms[index], isRecent: categoryIndex == 0),
        );
      },
    );
  }

  Widget _buildCategoryBar() {
    return ValueListenableBuilder<int>(
      valueListenable: _categoryNotifier,
      builder: (context, activeIndex, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 50,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Row(
            children: [
              _buildCategoryTab('حديثاً', 0, activeIndex),
              _buildCategoryTab('تم الانضمام', 1, activeIndex),
              _buildCategoryTab('تم المتابعة', 2, activeIndex),
              _buildCategoryTab('الأصدقاء', 3, activeIndex),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryTab(String label, int index, int activeIndex) {
    final bool isActive = activeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _categoryPageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      const Color(0xFF00897B),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
              fontSize: 13,
              fontFamily: 'Tajawal',
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room, {bool isRecent = false, VoidCallback? onTap}) {
    bool showDeleteOverlay = false;
    final dynamic roomCardFrame =
        room['cardFrameImage'] ??
        room['roomFrameImage'] ??
        room['roomFrame'] ??
        room['frameImage'] ??
        room['frameUrl'];
    final String? roomCardFramePath = roomCardFrame?.toString();
    final String roomCardFrameSource =
        (roomCardFramePath != null && roomCardFramePath.isNotEmpty && roomCardFramePath != 'assets/images/rom.png')
        ? FramedAvatar.getFrameAsset(roomCardFramePath)
        : '';

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: () {
            if (showDeleteOverlay) {
              setState(() {
                showDeleteOverlay = false;
              });
              return;
            }
            if (onTap != null) {
              onTap();
            } else {
              _handleJoinRoom(room);
            }
          },
          onLongPress: isRecent
              ? () {
                  setState(() {
                    showDeleteOverlay = true;
                  });
                }
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                            child: Image.network(
                              room['imageUrl'] ??
                                  'https://i.pravatar.cc/300?img=${room.hashCode % 50}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey.shade900,
                                    child: const Icon(
                                      Icons.meeting_room,
                                      color: Colors.white24,
                                      size: 40,
                                    ),
                                  ),
                            ),
                          ),
                          // Subtle gradient overlay at bottom of image for text readability (if we add text there later)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.6),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            top: 8,
                            left: 8,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                color: Colors.black.withOpacity(
                                  0.4,
                                ), // Frosted glass fallback
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${room['viewerCount'] ?? (room['users'] as Map?)?.length ?? 0}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    SoundWaveWidget(
                                      color: Colors.cyanAccent,
                                      size: 12,
                                      barCount: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // شارة الإدارة (تظهر للعامة)
                          if (room['isAdminRoom'] == true)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(
                                    0.4,
                                  ), // أحمر شفاف
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  'الإدارة',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),

                          // Banned Icon overlay
                          if (room['isBanned'] == true)
                            Positioned.fill(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.redAccent, width: 1.5),
                                  ),
                                  child: const Text(
                                    'محظورة',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Lock Icon overlay (Glowing Ember Style)
                          if (room['isLocked'] == true &&
                              (room['lockExpiresAt'] as Timestamp?)
                                      ?.toDate()
                                      .isAfter(DateTime.now()) ==
                                  true)
                            Positioned.fill(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orangeAccent.withOpacity(
                                          0.6,
                                        ),
                                        blurRadius: 20,
                                        spreadRadius: -5,
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.amber.withOpacity(0.8),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    color: Colors.amber,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Delete Overlay
                    if (showDeleteOverlay)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      showDeleteOverlay = false;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade600,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Text(
                                      'إلغاء',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () async {
                                    final service =
                                        Provider.of<VoiceRoomService>(
                                          context,
                                          listen: false,
                                        );
                                    await service.removeRecentRoom(room['id']);
                                    if (mounted) {
                                      setState(() {
                                        showDeleteOverlay = false;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Text(
                                      'حذف',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildDynamicFlag(room['hostId']),
                              const SizedBox(width: 6),
                              Expanded(
                                child: SizedBox(
                                  height: 24,
                                  child: _AutoScrollText(
                                    text: room['name'] ?? 'اسم الغرفة',
                                    style: const TextStyle(
                                      color: Color(0xFF042F2C),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            room['description'] ??
                                '{قوانين الروم} 1-تجاوز ممنوع 🚫 2-شق...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.blueGrey.shade600,
                              fontSize: 9,
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (roomCardFrameSource.isNotEmpty)
                Positioned(
                  top: -26,
                  left: -19,
                  right: -14,
                  bottom: -33,
                  child: IgnorePointer(
                    child: roomCardFrameSource.startsWith('http')
                        ? Image.network(
                            roomCardFrameSource,
                            fit: BoxFit.fill,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          )
                        : Image.asset(
                            roomCardFrameSource,
                            fit: BoxFit.fill,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateRoomDialog(
    BuildContext context,
    VoiceRoomService service,
    String? uid,
  ) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    File? roomImage;
    final picker = ImagePicker();
    bool isUploading = false;
    bool isPickingImage = false;

    Widget buildInputField({
      required TextEditingController controller,
      required String label,
      required String hint,
      required IconData icon,
      int maxLines = 1,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              prefixIcon: Padding(
                padding: EdgeInsets.only(
                  bottom: maxLines > 1 ? (maxLines - 1) * 20.0 : 0,
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).primaryColor.withOpacity(0.7),
                  size: 22,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor.withValues(
                      alpha: 0.9,
                    ), // Darkened by opacity
                    Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.7), // Darker transition
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Header ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.meeting_room_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'إنشاء غرفة جديدة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'قم بإعداد مساحتك الخاصة للدردشة والتفاعل',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 30),

                    // --- Image Picker ---
                    GestureDetector(
                      onTap: () async {
                        if (isPickingImage) return;
                        setState(() => isPickingImage = true);
                        try {
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (picked != null) {
                            setState(() => roomImage = File(picked.path));
                          }
                        } catch (e) {
                          debugPrint('Image picker error: $e');
                        } finally {
                          if (context.mounted) {
                            setState(() => isPickingImage = false);
                          } else {
                            isPickingImage = false;
                          }
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: roomImage == null
                              ? Colors.white.withOpacity(0.03)
                              : null,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.4),
                            width: 1.5,
                            style: BorderStyle.solid,
                          ),
                          image: roomImage != null
                              ? DecorationImage(
                                  image: FileImage(roomImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: roomImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.cloud_upload_rounded,
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.8),
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'اضغط لرفع صورة الغرفة',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ],
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.black.withOpacity(0.4),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Name Input ---
                    buildInputField(
                      controller: nameController,
                      label: 'اسم الغرفة',
                      hint: 'أدخل اسم الغرفة...',
                      icon: Icons.title_rounded,
                    ),
                    const SizedBox(height: 20),

                    // --- Description Input ---
                    buildInputField(
                      controller: descriptionController,
                      label: 'إشعار الغرفة',
                      hint: 'قوانين، ترحيب، الخ...',
                      icon: Icons.description_rounded,
                      maxLines: 3,
                    ),

                    if (isUploading) ...[
                      const SizedBox(height: 30),
                      const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00FFD1),
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'جاري إنشاء الغرفة...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],

                    const SizedBox(height: 36),

                    // --- Action Buttons ---
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isUploading
                                ? null
                                : () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Colors.white.withOpacity(0.05),
                            ),
                            child: const Text(
                              'إلغاء',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FFD1),
                              foregroundColor: const Color(0xFF061A16),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 8,
                              shadowColor: const Color(
                                0xFF00FFD1,
                              ).withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: isUploading
                                ? null
                                : () async {
                                    if (nameController.text.isNotEmpty) {
                                      setState(() => isUploading = true);
                                      try {
                                        String? imageUrl;
                                        final storageService = StorageService();

                                        final tempId = DateTime.now()
                                            .millisecondsSinceEpoch
                                            .toString();

                                        if (roomImage != null) {
                                          imageUrl = await storageService
                                              .uploadRoomAsset(
                                                uid: uid ?? 'anonymous',
                                                roomId: tempId,
                                                file: roomImage!,
                                              );
                                        }

                                        await service.createRoom(
                                          name: nameController.text.trim(),
                                          imageUrl: imageUrl,
                                          logoText: '',
                                          description: descriptionController
                                              .text
                                              .trim(),
                                        );

                                        if (context.mounted)
                                          Navigator.pop(context);
                                      } catch (error) {
                                        debugPrint(
                                          'Error creating room: $error',
                                        );
                                        rethrow;
                                      } finally {
                                        setState(() => isUploading = false);
                                      }
                                    }
                                  },
                            child: const Text(
                              'إنشاء الغرفة',
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleJoinRoom(Map<String, dynamic> room) {
    final currentUserId = auth.FirebaseAuth.instance.currentUser?.uid;

    if (room['isBanned'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'عذراً، هذه الغرفة محظورة من قبل الإدارة ولا يمكن الدخول إليها',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check if room is locked
    final bool isLocked = room['isLocked'] ?? false;
    final String? password = room['password'];
    final dynamic lockExpiresAt = room['lockExpiresAt'];
    final bool isHost = room['hostId'] == currentUserId;

    bool isStillLocked = isLocked;
    if (isLocked && lockExpiresAt != null) {
      DateTime expiry;
      if (lockExpiresAt is Timestamp) {
        expiry = lockExpiresAt.toDate();
      } else {
        expiry = DateTime.now(); // Fallback
      }
      if (DateTime.now().isAfter(expiry)) {
        isStillLocked = false;
      }
    }

    if (isStillLocked && !isHost && password != null) {
      _showPasswordDialog(room);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              VoiceRoomScreen(roomId: room['id'], initialRoomData: room),
        ),
      );
    }
  }

  void _showPasswordDialog(Map<String, dynamic> room) {
    final TextEditingController controller = TextEditingController();
    bool obscureText = true;
    String? errorMessage;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "PasswordDialog",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setDialogState) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2C3E50), Color(0xFF000000)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.amber,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "غرفة مقفلة",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "يرجى إدخال الرقم السري المكون من 4 أرقام للدخول",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      obscureText: obscureText,
                      maxLength: 4,
                      onChanged: (val) {
                        if (errorMessage != null) {
                          setDialogState(() => errorMessage = null);
                        }
                      },
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: "",
                        hintText: "* * * *",
                        errorText: errorMessage,
                        errorStyle: const TextStyle(
                          color: Colors.redAccent,
                          fontFamily: 'Tajawal',
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureText
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.amber.withOpacity(0.6),
                            size: 20,
                          ),
                          onPressed: () =>
                              setDialogState(() => obscureText = !obscureText),
                        ),
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.1),
                          letterSpacing: 8,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 40,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.amber,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.redAccent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              "إلغاء",
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 16,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (controller.text == room['password']) {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VoiceRoomScreen(
                                      roomId: room['id'],
                                      initialRoomData: room,
                                    ),
                                  ),
                                );
                              } else {
                                setDialogState(
                                  () => errorMessage = "الرقم السري غير صحيح",
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "دخول",
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  Widget _buildDynamicFlag(String? hostId) {
    if (hostId == null || hostId.isEmpty) return const SizedBox.shrink();
    final userService = UserService();

    return StreamBuilder<User?>(
      stream: userService.getUserStream(hostId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        String flagEmoji = '🌍'; // fallback neutral globe

        if (user != null && user.country != null && user.country!.isNotEmpty) {
          final country = user.country!.trim();
          // Regional Indicator Symbols are in U+1F1E6–U+1F1FF
          // A flag emoji = exactly 2 consecutive regional indicators
          // We scan all parts of the string and extract the first flag found
          final words = country.split(' ');
          for (final word in words.reversed) {
            final runes = word.runes.toList();
            // Flag emoji = 2 runes, each in range 0x1F1E6–0x1F1FF
            if (runes.length == 2 &&
                runes[0] >= 0x1F1E6 &&
                runes[0] <= 0x1F1FF &&
                runes[1] >= 0x1F1E6 &&
                runes[1] <= 0x1F1FF) {
              flagEmoji = word;
              break;
            }
          }
        }

        return Text(flagEmoji, style: const TextStyle(fontSize: 18));
      },
    );
  }
}

class RoomSearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final List<Map<String, dynamic>> rooms;
  final Widget Function(Map<String, dynamic>, VoidCallback) buildCard;

  RoomSearchDelegate(this.rooms, this.buildCard);

  @override
  String get searchFieldLabel => 'ابحث عن غرفة...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: const Color(0xFF03221E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white54, fontFamily: 'Tajawal'),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'Tajawal',
        ),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildFutureList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildFutureList();
  }

  Widget _buildFutureList() {
    final searchLower = query.trim().toLowerCase();

    final localResults = rooms.where((room) {
      final name = (room['name'] ?? '').toString().toLowerCase();
      final id = (room['id'] ?? '').toString().toLowerCase();
      final shortId = (room['ownerDisplayId'] ?? room['displayId'] ?? '').toString().toLowerCase();
      return name.contains(searchLower) ||
          id.contains(searchLower) ||
          shortId.contains(searchLower);
    }).toList();

    if (searchLower.isEmpty) {
      return _buildGrid(localResults);
    }

    return FutureBuilder<QuerySnapshot>(
      future: _searchRooms(searchLower),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (localResults.isNotEmpty) {
            return _buildGrid(localResults);
          }
          return Container(
            color: const Color(0xFF03221E),
            child: const Center(child: CircularProgressIndicator(color: Colors.amber)),
          );
        }

        final remoteDocs = snapshot.data?.docs ?? [];
        final remoteRooms = remoteDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        final mergedMap = <String, Map<String, dynamic>>{};
        for (var r in localResults) {
          mergedMap[r['id'] ?? ''] = r;
        }
        for (var r in remoteRooms) {
          mergedMap[r['id'] ?? ''] = r;
        }
        mergedMap.remove('');

        final finalResults = mergedMap.values.toList();

        return _buildGrid(finalResults);
      },
    );
  }

  Future<QuerySnapshot> _searchRooms(String queryText) async {
    Query q = FirebaseFirestore.instance.collection('rooms');

    if (RegExp(r'^[0-9]+$').hasMatch(queryText)) {
      final intId = int.tryParse(queryText);
      if (intId != null) {
        // usually stored as int based on createRoom
        q = q.where('ownerDisplayId', isEqualTo: intId);
      } else {
        q = q.where('ownerDisplayId', isEqualTo: queryText);
      }
    } else {
      q = q
          .where('name', isGreaterThanOrEqualTo: queryText)
          .where('name', isLessThan: '${queryText}z');
    }

    return await q.limit(20).get();
  }

  Widget _buildGrid(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return Container(
        color: const Color(0xFF03221E),
        child: const Center(
          child: Text(
            'لا توجد نتائج',
            style: TextStyle(color: Colors.white54, fontFamily: 'Tajawal'),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF03221E),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final room = results[index];
          return buildCard(room, () => close(context, room));
        },
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

        // If text fits, show it normally (static)
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
