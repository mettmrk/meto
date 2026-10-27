import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/post_service.dart';
import 'comments_screen.dart';
import 'profile_screen.dart';
import '../widgets/framed_avatar.dart';
import '../widgets/post_gifts_summary_bottom_sheet.dart';
import 'ludo_screen.dart';
import 'voice_room_screen.dart';
import 'package:provider/provider.dart';
import '../services/voice_room_service.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FB),
        body: Center(child: Text('يرجى تسجيل الدخول لمشاهدة الإشعارات')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            tooltip: 'تحديد الكل كمقروء',
            onPressed: () {
              NotificationService().markAllAsRead(currentUserId);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: NotificationService().getNotificationsStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
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
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 64,
                      color: Colors.teal.shade200,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'لا توجد إشعارات حتى الآن',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سوف نخطرك عندما يكون هناك نشاط جديد',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: Colors.teal,
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationTile(notification: notification);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationTile({required this.notification});

  Color _getNotificationColor() {
    switch (notification.type) {
      case NotificationType.like:
        return Colors.redAccent;
      case NotificationType.comment:
      case NotificationType.reply:
        return Colors.blueAccent;
      case NotificationType.gift:
        return Colors.amber;
      case NotificationType.follow:
        return Colors.teal;
      case NotificationType.ludoInvite:
        return Colors.indigo;
      case NotificationType.system:
        return Colors.deepPurple;
      case NotificationType.roomInvite:
        return Colors.greenAccent;
      case NotificationType.agency:
        return Colors.blueGrey;
      case NotificationType.support:
        return Colors.orange;
      case NotificationType.reward:
      case NotificationType.mining:
        return Colors.green;
    }
  }

  IconData _getNotificationIcon() {
    switch (notification.type) {
      case NotificationType.like:
        return Icons.favorite_rounded;
      case NotificationType.comment:
      case NotificationType.reply:
        return Icons.chat_bubble_rounded;
      case NotificationType.gift:
        return Icons.card_giftcard_rounded;
      case NotificationType.follow:
        return Icons.person_add_rounded;
      case NotificationType.ludoInvite:
        return Icons.videogame_asset_rounded;
      case NotificationType.system:
        return Icons.campaign_rounded;
      case NotificationType.roomInvite:
        return Icons.record_voice_over_rounded;
      case NotificationType.agency:
        return Icons.business_rounded;
      case NotificationType.support:
        return Icons.headset_mic_rounded;
      case NotificationType.reward:
        return Icons.currency_bitcoin_rounded;
      case NotificationType.mining:
        return Icons.precision_manufacturing_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: !notification.isRead
            ? Colors.white
            : Colors.grey.shade50.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: !notification.isRead
            ? Border.all(color: Colors.teal.withValues(alpha: 0.2), width: 1.5)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Mark as read immediately when clicked (no matter the type)
            await NotificationService().markAsRead(notification.id);

            if (context.mounted) {
              if (notification.type == NotificationType.follow) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfileScreen(uid: notification.senderId),
                  ),
                );
              } else if (notification.type == NotificationType.support) {
                // Navigate to support directly
                Navigator.pushNamed(context, '/support');
              } else if (notification.type == NotificationType.gift &&
                  notification.postId != null) {
                try {
                  final post = await PostService().getPost(
                    notification.postId!,
                  );
                  if (post != null && context.mounted) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) =>
                          PostGiftsSummaryBottomSheet(postId: post.id),
                    );
                  }
                } catch (e) {
                  debugPrint('Error opening gifts: $e');
                }
              } else if (notification.type == NotificationType.ludoInvite) {
                final roomId = notification.roomId;
                if (roomId != null && context.mounted) {
                  try {
                    // Check if room is still valid
                    final snapshot = await FirebaseDatabase.instance
                        .ref('ludo_rooms')
                        .child(roomId)
                        .child('status')
                        .get();
                    
                    if (!snapshot.exists || snapshot.value == 'closed' || snapshot.value == 'finished') {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('عذراً، انتهت المباراة أو تم إغلاق الطاولة')),
                        );
                        NotificationService().deleteNotification(notification.id);
                      }
                    } else {
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LudoScreen(roomId: roomId),
                          ),
                        );
                        // Delete notification so user can't reuse it later
                        NotificationService().deleteNotification(notification.id);
                      }
                    }
                  } catch (e) {
                    // Fallback just in case
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LudoScreen(roomId: roomId),
                        ),
                      );
                      NotificationService().deleteNotification(notification.id);
                    }
                  }
                }
              } else if (notification.type == NotificationType.agency) {
                Navigator.pushNamed(context, '/agency-request');
              } else if (notification.type == NotificationType.roomInvite) {
                final roomId = notification.roomId;
                if (roomId != null && context.mounted) {
                  final voiceService = Provider.of<VoiceRoomService>(
                    context,
                    listen: false,
                  );
                  if (voiceService.isJoined &&
                      voiceService.currentRoomId == roomId) {
                    Navigator.pop(context); // Close notification screen
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VoiceRoomScreen(roomId: roomId),
                      ),
                    );
                  }
                }
              } else if (notification.type == NotificationType.reward ||
                  notification.type == NotificationType.mining) {
                // Navigate to reward screen
                Navigator.pushNamed(context, '/daily-reward');
              } else if (notification.postId != null) {
                try {
                  final post = await PostService().getPost(
                    notification.postId!,
                  );
                  if (post != null && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommentsScreen(post: post),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error opening post: $e');
                }
              }
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: FramedAvatar(
                        userId: notification.senderId,
                        radius: 26,
                        imageUrl: notification.senderProfileImage,
                        disableFrame: true,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getNotificationIcon(),
                          size: 14,
                          color: _getNotificationColor(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            height: 1.5,
                            fontFamily: 'Segoe UI',
                          ),
                          children: [
                            TextSpan(
                              text: notification.senderName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: notification.text,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeago.format(notification.createdAt, locale: 'ar'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  Container(
                    margin: const EdgeInsets.only(top: 12, left: 4),
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
