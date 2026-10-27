import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../widgets/framed_avatar.dart';

enum ListType { blocked, muted, blacklisted }

class UsersListScreen extends StatelessWidget {
  final ListType type;
  final UserService _userService = UserService();

  UsersListScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FB),
        body: Center(child: Text('غير مسجل دخول')),
      );
    }

    String title;
    String emptyMessage;
    IconData emptyIcon;

    switch (type) {
      case ListType.blocked:
        title = 'الحسابات المحجوبة';
        emptyMessage = 'لا يوجد مستخدمين محجوبين';
        emptyIcon = Icons.block;
        break;
      case ListType.muted:
        title = 'الحسابات المصمتة';
        emptyMessage = 'لا يوجد مستخدمين مصمتين';
        emptyIcon = Icons.volume_off_rounded;
        break;
      case ListType.blacklisted:
        title = 'القائمة السوداء';
        emptyMessage = 'القائمة السوداء فارغة';
        emptyIcon = Icons.list_alt_rounded;
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
      ),
      body: StreamBuilder<User?>(
        stream: _userService.getUserStream(currentUser.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          final user = snapshot.data!;
          List<String> ids;

          switch (type) {
            case ListType.blocked:
              ids = user.blockedUsers;
              break;
            case ListType.muted:
              ids = user.mutedUsers;
              break;
            case ListType.blacklisted:
              ids = user.blacklistedUsers;
              break;
          }

          if (ids.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      emptyIcon,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ids.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final targetId = ids[index];
              return FutureBuilder<User?>(
                future: _userService.getUser(targetId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox(); // Loading individual item
                  }
                  final targetUser = userSnapshot.data!;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.teal.shade100),
                          ),
                          child: FramedAvatar(
                            userId: targetUser.uid,
                            radius: 24,
                            imageUrl: targetUser.profileImage,
                            disableFrame: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                targetUser.nickname ?? targetUser.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${targetUser.username}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              switch (type) {
                                case ListType.blocked:
                                  await _userService.unblockUser(
                                    currentUserId: currentUser.uid,
                                    userToUnblockId: targetId,
                                  );
                                  break;
                                case ListType.muted:
                                  await _userService.unmuteUser(
                                    currentUserId: currentUser.uid,
                                    userToUnmuteId: targetId,
                                  );
                                  break;
                                case ListType.blacklisted:
                                  await _userService.removeBlacklistUser(
                                    currentUserId: currentUser.uid,
                                    userToRemoveId: targetId,
                                  );
                                  break;
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('حدث خطأ: $e')),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade400,
                            backgroundColor: Colors.red.shade50,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'إزالة',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
