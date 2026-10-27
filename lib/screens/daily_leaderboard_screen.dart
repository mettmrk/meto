import 'package:flutter/material.dart';
import '../services/task_service.dart';
import '../services/reward_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/framed_avatar.dart';
import '../widgets/daily_earning_counter.dart';
import '../widgets/level_badge.dart';

class DailyTasksScreen extends StatefulWidget {
  const DailyTasksScreen({super.key});

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen>
    with SingleTickerProviderStateMixin {
  final TaskService _taskService = TaskService();
  final RewardService _rewardService = RewardService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  late AnimationController _headerController;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildLeaderboardList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _headerController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(
                  255,
                  7,
                  44,
                  255,
                ).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لوحة الشرف اليومية',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      Text(
                        'أفضل المستخدمين اليوم',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Close Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              if (_currentUserId != null) ...[
                const SizedBox(height: 20),
                StreamBuilder<Map<String, dynamic>>(
                  stream: _rewardService.getCounterState(_currentUserId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final data = snapshot.data!;
                    final isSubscribed = data['isSubscribed'] ?? false;
                    final isCounterActive = data['isCounterActive'] ?? false;
                    final counterStartTime =
                        (data['counterStartTime'] as Timestamp?)?.toDate();
                    final diamondsPerClaim =
                        (data['diamondsPerClaim'] as num?)?.toInt() ?? 0;
                    final goldReward = diamondsPerClaim + 1000;

                    if (isSubscribed &&
                        isCounterActive &&
                        counterStartTime != null) {
                      return Center(
                        child: DailyEarningCounter(
                          dailyAmount: goldReward,
                          startTime: counterStartTime,
                          isGold: true,
                          isMeto: false,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _taskService.getDailyLeaderboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amber),
          );
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 60,
                  color: Colors.white24,
                ),
                SizedBox(height: 10),
                Text(
                  'لا يوجد متصدرين اليوم بعد',
                  style: TextStyle(
                    color: Colors.white54,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final rank = index + 1;
            final isTop3 = rank <= 3;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isTop3
                    ? LinearGradient(
                        colors: [
                          Colors.amber.withValues(alpha: 0.15 * (4 - rank)),
                          Colors.transparent,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: isTop3 ? null : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isTop3
                      ? [
                          const Color(0xFFFFD700), // Gold
                          const Color(0xFFC0C0C0), // Silver
                          const Color(0xFFCD7F32), // Bronze
                        ][index].withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.05),
                  width: isTop3 ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Rank
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: isTop3
                        ? Text(
                            ['🥇', '🥈', '🥉'][index],
                            style: const TextStyle(fontSize: 28),
                          )
                        : Text(
                            '#$rank',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                              fontSize: 16,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Avatar
                  FramedAvatar(
                    userId: user['uid'],
                    imageUrl: user['profileImage'],
                    radius: 24,
                    useProfileFrameFallback: true,
                  ),
                  const SizedBox(width: 14),
                  // Name & Level
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['nickname'] ?? user['username'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        LevelBadge(level: user['level'] ?? 1, size: 18),
                      ],
                    ),
                  ),
                  // Daily Diamonds
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded, // Gold
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${user['dailyCoins']}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                            fontSize: 15,
                          ),
                        ),
                      ],
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
}
