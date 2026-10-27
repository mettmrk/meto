import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../screens/profile_screen.dart';
import '../widgets/framed_avatar.dart';
import '../widgets/level_badge.dart';

class RoomSupportersSheet extends StatefulWidget {
  final String roomId;
  const RoomSupportersSheet({super.key, required this.roomId});

  @override
  State<RoomSupportersSheet> createState() => _RoomSupportersSheetState();
}

class _RoomSupportersSheetState extends State<RoomSupportersSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
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
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          _buildHeader(),
          const SizedBox(height: 10),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSupportersList('daily'),
                _buildSupportersList('weekly'),
                _buildSupportersList('total'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gift_transactions')
          .where('roomId', isEqualTo: widget.roomId)
          .orderBy('timestamp', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        String? topUid;
        int topAmount = 0;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          Map<String, int> aggregates = {};
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final senderId = data['senderId'] as String?;
            if (senderId == null) continue;
            final amount = (data['totalCost'] as num?)?.toInt() ?? 0;
            aggregates[senderId] = (aggregates[senderId] ?? 0) + amount;
          }
          if (aggregates.isNotEmpty) {
            var sortedKeys = aggregates.keys.toList()
              ..sort((a, b) => aggregates[b]!.compareTo(aggregates[a]!));
            topUid = sortedKeys.first;
            topAmount = aggregates[topUid]!;
          }
        }

        if (topUid == null) {
          return const SizedBox(height: 20);
        }

        return StreamBuilder<User?>(
          stream: UserService().getUserStream(topUid),
          builder: (context, userSnap) {
            final user = userSnap.data;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(uid: topUid),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        FramedAvatar(
                          userId: topUid!,
                          imageUrl: user?.profileImage,
                          radius: 35, // Smaller Avatar
                        ),
                        // Small subtle crown
                        Positioned(
                          top: -5,
                          right: -5,
                          child: const Text(
                            '👑',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.nickname ?? user?.username ?? "الداعم الأول",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.diamond_rounded,
                              color: Color(0xFF00E5FF),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              topAmount.toString(),
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: const Color(0xFF00FFD1).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF00FFD1).withOpacity(0.3)),
        ),
        labelColor: const Color(0xFF00FFD1),
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          fontFamily: 'Tajawal',
        ),
        tabs: const [
          Tab(text: "يومي"),
          Tab(text: "أسبوعي"),
          Tab(text: "كلي"),
        ],
      ),
    );
  }

  Widget _buildSupportersList(String type) {
    // For now, we query gift_transactions and aggregate.
    // In a production app, you'd want a cached leaderboard collection.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gift_transactions')
          .where('roomId', isEqualTo: widget.roomId)
          .orderBy('timestamp', descending: true)
          .limit(500)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00FFD1)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        // Sort locally if we have timestamps
        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final tsA =
              (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final tsB =
              (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (tsA == null || tsB == null) return 0;
          return tsB.compareTo(tsA);
        });

        Map<String, int> aggregates = {};
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final senderId = data['senderId'] as String?;
          if (senderId == null) continue;

          final amount = (data['totalCost'] as num?)?.toInt() ?? 0;

          // Filter by type (daily/weekly) if timestamp allows
          if (type != 'total') {
            final ts =
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final now = DateTime.now();

            if (type == 'daily') {
              if (ts.day != now.day ||
                  ts.month != now.month ||
                  ts.year != now.year)
                continue;
            }
            if (type == 'weekly' && now.difference(ts).inDays > 7) continue;
          }

          aggregates[senderId] = (aggregates[senderId] ?? 0) + amount;
        }

        if (aggregates.isEmpty) return _buildEmptyState();

        var sortedKeys = aggregates.keys.toList()
          ..sort((a, b) => aggregates[b]!.compareTo(aggregates[a]!));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          itemCount: sortedKeys.length,
          itemBuilder: (context, index) {
            final uid = sortedKeys[index];
            final amount = aggregates[uid]!;
            return _buildSupporterItem(index + 1, uid, amount);
          },
        );
      },
    );
  }

  Widget _buildSupporterItem(
    int rank,
    String uid,
    int amount, {
    bool isHighlight = false,
  }) {
    bool isTop3 = rank <= 3;
    Color rankColor;
    if (rank == 1)
      rankColor = const Color(0xFFFFD700);
    else if (rank == 2)
      rankColor = const Color(0xFFC0C0C0);
    else if (rank == 3)
      rankColor = const Color(0xFFCD7F32);
    else
      rankColor = Colors.white24;

    return StreamBuilder<User?>(
      stream: UserService().getUserStream(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen(uid: uid)),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHighlight
                    ? [
                        const Color(0xFF00FFD1).withOpacity(0.15),
                        const Color(0xFF00FFD1).withOpacity(0.05),
                      ]
                    : (isTop3
                          ? [
                              rankColor.withOpacity(0.12),
                              Colors.white.withOpacity(0.03),
                            ]
                          : [
                              Colors.white.withOpacity(0.04),
                              Colors.white.withOpacity(0.01),
                            ]),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isHighlight
                    ? const Color(0xFF00FFD1).withOpacity(0.4)
                    : (isTop3
                          ? rankColor.withOpacity(0.4)
                          : Colors.white.withOpacity(0.06)),
                width: isTop3 ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Rank Shield Badge
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isTop3
                        ? rankColor.withOpacity(0.15)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isTop3
                        ? Border.all(
                            color: rankColor.withOpacity(0.6),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Text(
                    rank.toString(),
                    style: TextStyle(
                      color: isTop3 ? rankColor : Colors.white38,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FramedAvatar(
                  userId: uid,
                  imageUrl: user.profileImage,
                  radius: 22,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nickname ?? user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isTop3
                              ? Colors.white
                              : Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(height: 4),
                      LevelBadge(level: user.level, size: 16),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.diamond_rounded,
                            color: Color(0xFF00E5FF),
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            amount.toString(),
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        rank == 1
                            ? 'الملك'
                            : (rank == 2
                                  ? 'الوصيف'
                                  : (rank == 3 ? 'نخبة' : 'داعم')),
                        style: TextStyle(
                          color: isTop3 ? rankColor : Colors.white30,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
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
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.volunteer_activism_rounded,
            size: 60,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 15),
          const Text(
            'لا يوجد داعمين لهذه الفترة بعد',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }
}
