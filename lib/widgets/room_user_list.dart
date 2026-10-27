import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/voice_room_service.dart';
import 'framed_avatar.dart';

import 'member_profile_bottom_sheet.dart';
import 'level_badge.dart';

class RoomUserList extends StatelessWidget {
  final Function(String)? onMention;
  const RoomUserList({super.key, this.onMention});

  @override
  @override
  Widget build(BuildContext context) {
    final service = context.watch<VoiceRoomService>();
    final users = service.roomUsers;

    if (service.viewerCount == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: false, // Normal order in RTL Row
        shrinkWrap: true,
        itemCount: users.length,
        separatorBuilder: (context, index) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final user = users[index];
          final isMuted = service.isUserMuted(user.uid);
          return GestureDetector(
            onTap: () => _showUserInfo(context, user, onMention),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.0,
                    ),
                  ),
                  child: FramedAvatar(
                    key: ValueKey('room_user_list_${user.uid}'),
                    userId: user.uid,
                    imageUrl: user.profileImage,
                    radius: 14,
                    disableFrame: true,
                  ),
                ),
                if (isMuted)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: const Icon(
                      Icons.block_outlined,
                      color: Colors.redAccent,
                      size: 24,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static void showOnlineUsers(
    BuildContext context, {
    Function(String)? onMention,
  }) {
    final service = Provider.of<VoiceRoomService>(context, listen: false);
    final users = service.roomUsers;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "المتواجدون الآن",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                // Sort users by role: Owner (0) > Co-Owner (1) > Admin (2) > member (3)
                final sortedUsers = List<User>.from(users);
                sortedUsers.sort((a, b) {
                  int getRolePriority(String uid) {
                    if (service.hostId == uid) return 0;
                    if (service.isCoOwner(uid)) return 1;
                    if (service.isAdmin(uid)) return 2;
                    return 3;
                  }

                  final roleCompare = getRolePriority(a.uid).compareTo(getRolePriority(b.uid));
                  if (roleCompare != 0) return roleCompare;

                  final nameA = (a.nickname ?? a.username).toLowerCase();
                  final nameB = (b.nickname ?? b.username).toLowerCase();
                  return nameA.compareTo(nameB);
                });

                return Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedUsers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = sortedUsers[index];
                      final isOwner = service.hostId == user.uid;
                      final isCoOwner = service.isCoOwner(user.uid);
                      final isAdmin = service.isAdmin(user.uid);

                      // Check membership from presence metadata
                      final bool isMemberOfRoom =
                          service.roomUsersMetadata[user.uid]?['isMember'] ==
                          true;

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            MemberProfileBottomSheet.show(
                              context,
                              service,
                              user,
                              onMention: onMention,
                            );
                          },
                          child: FramedAvatar(
                            key: ValueKey('online_list_${user.uid}'),
                            userId: user.uid,
                            imageUrl: user.profileImage,
                            radius: 22,
                            disableFrame: true,
                          ),
                        ),
                        title: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user.nickname ?? user.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            LevelBadge(level: user.level, size: 16),
                            const SizedBox(width: 8),
                            if (isOwner)
                              _buildRoleBadge("مالك", Colors.red, Icons.stars)
                            else if (isCoOwner)
                              _buildRoleBadge(
                                "نائب",
                                Colors.yellow,
                                Icons.shield,
                              )
                            else if (isAdmin)
                              _buildRoleBadge(
                                "مشرف",
                                Colors.green,
                                Icons.security,
                              )
                            else if (isMemberOfRoom)
                              _buildRoleBadge("عضو", Colors.blue, Icons.person)
                            else
                              _buildRoleBadge(
                                "زائر",
                                Colors.blueGrey,
                                Icons.person_outline,
                              ),
                          ],
                        ),
                        subtitle: Text(
                          "ID: ${user.displayId ?? user.uid}",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey,
                          size: 14,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          MemberProfileBottomSheet.show(
                            context,
                            service,
                            user,
                            onMention: onMention,
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildRoleBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showUserInfo(
    BuildContext context,
    User user,
    Function(String)? onMention,
  ) {
    final service = Provider.of<VoiceRoomService>(context, listen: false);
    MemberProfileBottomSheet.show(context, service, user, onMention: onMention);
  }
}
