import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/voice_room_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../screens/profile_screen.dart';
import '../utils/room_level_system.dart';
import 'framed_avatar.dart';
import 'level_badge.dart';
import '../utils/room_tier_system.dart';

class RoomInfoSheet extends StatefulWidget {
  final Map<String, dynamic> roomData;
  final VoiceRoomService service;
  final String roomId;
  final String hostId;

  const RoomInfoSheet({
    super.key,
    required this.roomData,
    required this.service,
    required this.roomId,
    required this.hostId,
  });

  @override
  State<RoomInfoSheet> createState() => _RoomInfoSheetState();
}

class _RoomInfoSheetState extends State<RoomInfoSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _memberSearchController = TextEditingController();
  String _memberSearchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.70,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1316),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),

          // Header with large avatar and background accent
          _buildElegantHeader(),

          // Modern Styled Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(width: 3, color: Color(0xFF00FFD1)),
                insets: EdgeInsets.symmetric(horizontal: 24),
              ),
              labelColor: const Color(0xFF00FFD1),
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Tajawal',
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 12,
                fontFamily: 'Tajawal',
              ),
              tabs: const [
                Tab(text: "المعلومات"),
                Tab(text: "الأعضاء"),
                Tab(text: "اللحظات"),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildModernInfoTab(),
                _buildModernMembersTab(),
                _buildModernMomentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElegantHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Row(
        children: [
          // Large Glowing Avatar
          Container(
            width: 85,
            height: 85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FFD1).withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
              gradient: const LinearGradient(
                colors: [Color(0xFF00FFD1), Color(0xFF00A3FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F1316),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child:
                    (widget.roomData['imageUrl'] != null &&
                        widget.roomData['imageUrl'].toString().isNotEmpty)
                    ? Image.network(
                        widget.roomData['imageUrl'],
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/images/user_placeholder.png',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Room Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.roomData['name'] ?? "اسم الغرفة",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                StreamBuilder<User?>(
                  stream: UserService().getUserStream(widget.hostId),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final displayId = user?.displayId ?? '...';
                    final country = user?.country;
                    String flagStr = "";
                    if (country != null && country.isNotEmpty) {
                      // Attempt to extract the emoji flag part if it's formatted as "Flag Name"
                      final parts = country.split(' ');
                      flagStr = parts.isNotEmpty ? parts.first : "";
                    }

                    return Row(
                      children: [
                        const Icon(
                          Icons.token_rounded,
                          color: Color(0xFF00FFD1),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "ID: $displayId",
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontFamily: 'Tajawal',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        LevelBadge(
                          level: widget.roomData['roomLevel'] ?? 1,
                          size: 18,
                        ),
                        if (flagStr.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(flagStr, style: const TextStyle(fontSize: 14)),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                // Language/Region Badges
                Row(
                  children: [
                    _buildTinyBadge(
                      "العربية",
                      Colors.blue.withOpacity(0.2),
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildTinyBadge(
                      "عالمية",
                      Colors.orange.withOpacity(0.2),
                      Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _buildTinyBadge(
                      RoomTierSystem.getTier(
                        widget.roomData['roomTier'] ?? 0,
                      ).title,
                      const Color(0xFF00FFD1).withOpacity(0.2),
                      const Color(0xFF00FFD1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTinyBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildModernInfoTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: CircularProgressIndicator());
        }

        final roomDoc = snapshot.data!.data() as Map<String, dynamic>;
        final isHost = widget.service.currentUserId == widget.hostId;

        int roomLevel = roomDoc['roomLevel'] ?? 1;
        double currentXP = (roomDoc['roomXP'] ?? 0.0).toDouble();
        double requiredXP = RoomLevelSystem.getRequiredXPForLevel(roomLevel);
        double progress = RoomLevelSystem.getLevelProgress(
          roomLevel,
          currentXP,
        );

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            // Level Card (Owner only)
            if (isHost)
              _buildInfoCard(
                title: "مستوى الغرفة",
                icon: Icons.auto_awesome_rounded,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.military_tech_rounded,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "المستوى $roomLevel",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "${currentXP.toStringAsFixed(0)} / ${requiredXP.toStringAsFixed(0)} XP",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.05),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF00FFD1),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),

            if (isHost) const SizedBox(height: 16),

            // Motto / Announcement Card
            _buildInfoCard(
              title: "إعلان الغرفة",
              icon: Icons.campaign_rounded,
              child: Text(
                widget.roomData['description'] ??
                    "لم يتم تعيين إعلان للغرفة كعد...",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  height: 1.5,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Stats row (Owner only)
            if (isHost)
              _buildInfoCard(
                title: "إحصائيات الغرفة",
                icon: Icons.analytics_rounded,
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      _buildModernStatItem(
                        "الأعضاء",
                        "${roomDoc['memberCount'] ?? 0}",
                      ),
                      _buildVerticalDivider(),
                      _buildModernStatItem(
                        "إجمالي الدعم",
                        "${roomDoc['wealth'] ?? 0}",
                        valueColor: const Color(0xFF00E5FF),
                        icon: Icons.diamond_rounded,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
            // Recommendation Action
            _buildRecommendationButton(),

            const SizedBox(height: 24),
            // Bottom Action (Join/Leave)
            _buildEnhancedBottomActions(),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00FFD1), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget _buildModernStatItem(String label, String value, {Color? valueColor, IconData? icon}) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: valueColor ?? Colors.white, size: 14),
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      color: const Color.fromARGB(255, 7, 7, 7).withOpacity(0.1),
    );
  }

  Widget _buildMemberSearchField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      height: 52, // زيادة الارتفاع قليلاً لراحة العين
      decoration: BoxDecoration(
        // لون خلفية داكن هادئ بدلاً من الشفافية التامة لسهولة التحديد بالعين
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          // حد رفيع جداً بلون هادئ
          color: const Color(0xFF00FFD1).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          // ظل خفيف جداً لإعطاء عمق
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _memberSearchController,
        cursorColor: const Color.fromARGB(255, 0, 124, 0),
        textAlignVertical: TextAlignVertical.center, // توسيط النص عمودياً
        style: const TextStyle(
          color: Color.fromARGB(255, 8, 8, 8),
          fontSize: 15,
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.w500,
        ),
        onChanged: (value) {
          setState(() {
            _memberSearchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: "ابحث عن اسم العضو أو الـ ID...",
          hintStyle: TextStyle(
            color: const Color.fromARGB(
              255,
              15,
              15,
              15,
            ).withValues(alpha: 0.35),
            fontSize: 12,
            fontFamily: 'Tajawal',
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: const Color.fromARGB(255, 17, 88, 2).withValues(alpha: 0.7),
            size: 22,
          ),
          suffixIcon: _memberSearchQuery.isNotEmpty
              ? IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        12,
                        12,
                        12,
                      ).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color.fromARGB(179, 10, 10, 10),
                      size: 12,
                    ),
                  ),
                  onPressed: () {
                    _memberSearchController.clear();
                    setState(() {
                      _memberSearchQuery = "";
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildModernMembersTab() {
    return Column(
      children: [
        _buildMemberSearchField(),
        Expanded(
          child: StreamBuilder<List<User>>(
            stream: widget.service.getRoomMembersStream(widget.roomId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00FFD1)),
                );
              }
              final allUsers = snapshot.data ?? [];

              // Filter based on search query
              final users = allUsers.where((u) {
                if (_memberSearchQuery.isEmpty) return true;
                final query = _memberSearchQuery.toLowerCase();
                final name = (u.nickname ?? u.username).toLowerCase();
                final id = u.displayId ?? "";
                return name.contains(query) || id.contains(query);
              }).toList();

              // Sorting logic preserved
              users.sort((a, b) {
                int getRolePriority(String uid) {
                  if (widget.hostId == uid) return 0;
                  if (widget.service.isCoOwner(uid)) return 1;
                  if (widget.service.isAdmin(uid)) return 2;
                  return 3;
                }

                return getRolePriority(a.uid).compareTo(getRolePriority(b.uid));
              });

              if (users.isEmpty) {
                return _buildEmptyState(
                  _memberSearchQuery.isEmpty
                      ? Icons.people_outline_rounded
                      : Icons.search_off_rounded,
                  _memberSearchQuery.isEmpty
                      ? "لا يوجد أعضاء في هذا النادي بعد"
                      : "لا توجد نتائج مطابقة لبحثك",
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isOwner = widget.hostId == user.uid;
                  final isCoOwner = widget.service.isCoOwner(user.uid);
                  final isAdmin = widget.service.isAdmin(user.uid);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        20,
                        20,
                        20,
                      ).withOpacity(0.02),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isOwner
                                ? Colors.red
                                : (isCoOwner
                                      ? Colors.yellow
                                      : (isAdmin ? Colors.green : Colors.blue)),
                            width: 1.5,
                          ),
                        ),
                        child: FramedAvatar(
                          userId: user.uid,
                          imageUrl: user.profileImage,
                          radius: 22,
                          useProfileFrameFallback: false,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            user.nickname ?? user.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (isOwner)
                            _buildModernRoleBadge(
                              "مالك",
                              Colors.red,
                              Icons.stars_rounded,
                            )
                          else if (isCoOwner)
                            _buildModernRoleBadge(
                              "نائب",
                              Colors.yellow,
                              Icons.shield_rounded,
                            )
                          else if (isAdmin)
                            _buildModernRoleBadge(
                              "مشرف",
                              Colors.green,
                              Icons.security_rounded,
                            )
                          else
                            _buildModernRoleBadge(
                              "عضو",
                              Colors.blue,
                              Icons.person_rounded,
                            ),
                        ],
                      ),
                      subtitle: Text(
                        "ID: ${user.displayId ?? '...'}",
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      trailing: Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white24,
                        size: 20,
                      ),
                      onTap: () => _showAdminActions(user),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAdminActions(User targetUser) {
    if (!mounted) return;

    final String? currentUid = widget.service.currentUserId;
    final bool isHost = currentUid == widget.hostId;
    final bool isCoOwner = widget.service.isCoOwner(currentUid ?? "");

    // Permissions
    final bool canManageRoles =
        isHost; // Only Host manages Co-Owners and Admins
    final bool canKickBan = isHost || isCoOwner;

    final bool targetIsHost = targetUser.uid == widget.hostId;
    final bool targetIsCoOwner = widget.service.isCoOwner(targetUser.uid);
    final bool targetIsAdmin = widget.service.isAdmin(targetUser.uid);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
        decoration: const BoxDecoration(
          color: Color(0xFF0F1316),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Profile Header
            Row(
              children: [
                FramedAvatar(
                  userId: targetUser.uid,
                  imageUrl: targetUser.profileImage,
                  radius: 25,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        targetUser.nickname ?? targetUser.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "ID: ${targetUser.displayId}",
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // Action Grid
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 15,
              crossAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildActionItemHorizontal(
                  icon: Icons.person_search_rounded,
                  label: "الملف",
                  onTap: () {
                    Navigator.pop(ctx);
                    _showUserProfile(targetUser);
                  },
                ),

                if (!targetIsHost && currentUid != targetUser.uid) ...[
                  // Roles (Owner Only)
                  if (canManageRoles) ...[
                    _buildActionItemHorizontal(
                      icon: targetIsCoOwner
                          ? Icons.person_remove_rounded
                          : Icons.stars_rounded,
                      label: targetIsCoOwner ? "تنزيل نائب" : "ترقية نائب",
                      color: targetIsCoOwner ? Colors.orange : Colors.amber,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await widget.service.setCoOwner(
                          targetUser.uid,
                          !targetIsCoOwner,
                        );
                      },
                    ),
                    _buildActionItemHorizontal(
                      icon: targetIsAdmin
                          ? Icons.security_update_warning_rounded
                          : Icons.security_rounded,
                      label: targetIsAdmin ? "تنزيل مشرف" : "ترقية مشرف",
                      color: targetIsAdmin ? Colors.blueGrey : Colors.green,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await widget.service.setAdmin(
                          targetUser.uid,
                          !targetIsAdmin,
                        );
                      },
                    ),
                  ],

                  // Restrictions (Owner / Co-Owner)
                  if (canKickBan) ...[
                    _buildActionItemHorizontal(
                      icon: Icons.no_accounts_rounded,
                      label: "إزالة العضو",
                      color: Colors.deepOrange,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await widget.service.removeRoomMember(
                          targetUser.uid,
                          widget.roomId,
                        );
                      },
                    ),
                    _buildActionItemHorizontal(
                      icon: Icons.gavel_rounded,
                      label: "حظر",
                      color: Colors.red,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await widget.service.banUser(targetUser.uid);
                      },
                    ),
                  ],

                  _buildActionItemHorizontal(
                    icon: Icons.report_problem_rounded,
                    label: "إبلاغ",
                    color: Colors.white70,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showReportDialog(targetUser);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(User targetUser) {
    if (!mounted) return;

    final List<String> reasons = [
      "محتوى غير لائق",
      "إساءة أو مضايقة",
      "انتحال شخصية",
      "تبادل محتوى ممنوع",
      "سبب آخر",
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "إبلاغ عن المستخدم",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            ...reasons.map(
              (reason) => ListTile(
                title: Text(
                  reason,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await UserService().reportUser(
                    currentUserId: widget.service.currentUserId ?? "",
                    userToReportId: targetUser.uid,
                    reason: reason,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إرسال بلاغك بنجاح')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItemHorizontal({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 10,
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModernMomentsTab() {
    return _buildEmptyState(
      Icons.auto_awesome_motion_rounded,
      "لا توجد لحظات مشاركة حالياً\nكن أول من يشارك لحظاتك!",
    );
  }

  Widget _buildEmptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white24,
              fontSize: 14,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            try {
              await widget.service.recommendRoomToFriends(widget.roomId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تمت التوصية بالغرفة لأصدقائك بنجاح!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطأ: $e')),
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0xFF00FFD1).withOpacity(0.2),
          highlightColor: const Color(0xFF00FFD1).withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF00FFD1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00FFD1).withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.thumb_up_alt_rounded, color: Color(0xFF00FFD1), size: 18),
                SizedBox(width: 10),
                Text(
                  "توصية للأصدقاء",
                  style: TextStyle(
                    color: Color(0xFF00FFD1),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedBottomActions() {
    if (widget.hostId == widget.service.currentUserId) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<bool>(
      stream: widget.service.isRoomFollowedStream(widget.roomId),
      builder: (context, snapshot) {
        final isFollowed = snapshot.data ?? false;

        return StreamBuilder<bool>(
          stream: widget.service.isRoomMemberStream(widget.roomId),
          builder: (context, memberSnapshot) {
            final isMember = memberSnapshot.data ?? false;

            return Row(
              children: [
                // Follow Button
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (isFollowed) {
                        if (isMember) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'لا يمكن إلغاء المتابعة بشكل منفرد أثناء انضمامك كعضو.',
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        await widget.service.unfollowRoom(widget.roomId);
                      } else {
                        await widget.service.followRoom(
                          widget.roomId,
                          justFollow: true,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: isFollowed
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFFFF0055), Color(0xFFFF7A8A)],
                              ),
                        color: isFollowed
                            ? Colors.white.withOpacity(0.05)
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isFollowed
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF0055,
                                  ).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Center(
                        child: Text(
                          isFollowed ? "إلغاء المتابعة" : "متابعة",
                          style: TextStyle(
                            color: isFollowed ? Colors.white60 : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Join Membership Button
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (isMember) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            title: const Text(
                              'خيارات الإلغاء',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'يمكنك إلغاء الانضمام فقط والاحتفاظ بالمتابعة، أو إلغائهما معاً:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontFamily: 'Tajawal',
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orangeAccent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      try {
                                        await widget.service.unfollowRoom(
                                          widget.roomId,
                                          keepFollow: true,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'تم إلغاء الانضمام مع الاحتفاظ بالمتابعة',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text(
                                      'إلغاء الانضمام فقط',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Tajawal',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      try {
                                        await widget.service.unfollowRoom(
                                          widget.roomId,
                                          keepFollow: false,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'تم إلغاء الانضمام والمتابعة',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text(
                                      'إلغاء الانضمام والمتابعة',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Tajawal',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text(
                                    'تراجع',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        return;
                      }
                      final fee = widget.roomData['entranceFee'] as int? ?? 0;
                      try {
                        await widget.service.followRoom(
                          widget.roomId,
                          fee: fee,
                          justFollow: false,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم الانضمام للغرفة كعضو بنجاح!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: isMember
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF00FFD1), Color(0xFF00A3FF)],
                              ),
                        color: isMember ? Colors.white.withOpacity(0.05) : null,
                        borderRadius: BorderRadius.circular(16),
                        border: isMember
                            ? Border.all(color: Colors.white12)
                            : null,
                        boxShadow: isMember
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00FFD1,
                                  ).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Center(
                        child: Text(
                          isMember ? "إلغاء الانضمام" : "انضمام",
                          style: TextStyle(
                            color: isMember ? Colors.white54 : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildModernRoleBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
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
            ),
          ),
        ],
      ),
    );
  }

  void _showUserProfile(User user) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
    );
  }
}
