import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_room_service.dart';
import '../models/user_model.dart';
import 'framed_avatar.dart';

class RoomUserManagementSheet extends StatelessWidget {
  final User targetUser;

  const RoomUserManagementSheet({super.key, required this.targetUser});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<VoiceRoomService>();
    final bool amIOwner = service.hostId == service.currentUserId;
    final bool amIDeputy = service.isCoOwner(service.currentUserId ?? "");
    final bool amIAdmin = service.isAdmin(service.currentUserId ?? "");

    final bool isTargetOwner = targetUser.uid == service.hostId;
    final bool isTargetDeputy = service.isCoOwner(targetUser.uid);
    final bool isTargetAdmin = service.isAdmin(targetUser.uid);

    bool canManageTarget = false;
    if (amIOwner) {
      canManageTarget = targetUser.uid != service.currentUserId;
    } else if (amIDeputy) {
      canManageTarget =
          targetUser.uid != service.currentUserId &&
          !isTargetOwner &&
          !isTargetDeputy;
    } else if (amIAdmin) {
      canManageTarget =
          targetUser.uid != service.currentUserId &&
          !isTargetOwner &&
          !isTargetDeputy &&
          !isTargetAdmin;
    }

    if (!canManageTarget) {
      return const SizedBox.shrink();
    }

    final isTargetMuted = service.isUserMuted(targetUser.uid);
    final bool isSeated = service.seats.any(
      (s) => s != null && s['userId'] == targetUser.uid,
    );
    final bool isMember =
        service.roomUsersMetadata[targetUser.uid]?['isMember'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              FramedAvatar(
                userId: targetUser.uid,
                imageUrl: targetUser.profileImage,
                radius: 25,
                useProfileFrameFallback: false,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    targetUser.nickname ?? targetUser.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "ID: ${targetUser.displayId ?? targetUser.uid}",
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (!isTargetOwner) ...[
            const Text(
              "إدارة العضو",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (isSeated)
              _buildActionTile(
                context,
                icon: Icons.chair_alt,
                color: Colors.pinkAccent,
                title: "إنزال من المايك",
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await service.kickFromSeat(targetUser.uid);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم إنزال العضو من المايك'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                    }
                  }
                },
              ),

            _buildActionTile(
              context,
              icon: isTargetMuted ? Icons.mic : Icons.mic_off,
              color: isTargetMuted ? Colors.greenAccent : Colors.orangeAccent,
              title: isTargetMuted ? "إلغاء الأصمات " : "أصمات",
              onTap: () async {
                Navigator.pop(context);
                try {
                  await service.toggleMuteUser(targetUser.uid, !isTargetMuted);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isTargetMuted ? 'تم إلغاء الكتم' : 'تم كتم العضو',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                }
              },
            ),

            _buildActionTile(
              context,
              icon: Icons.remove_circle_outline,
              color: Colors.redAccent,
              title: "طرد ساعتين",
              onTap: () async {
                Navigator.pop(context); // Close sheet first
                _showConfirmationDialog(
                  context,
                  title: "طرد العضو",
                  content:
                      "هل أنت متأكد من طرد ${targetUser.nickname} لمدة ساعتين؟",
                  onConfirm: () async {
                    try {
                      await service.kickUser(targetUser.uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم طرد العضو بنجاح')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                      }
                    }
                  },
                );
              },
            ),

            if (amIOwner || !isTargetAdmin)
              _buildActionTile(
                context,
                icon: Icons.block,
                color: Colors.red[900]!,
                title: "حظر نهائي",
                onTap: () {
                  Navigator.pop(context);
                  _showConfirmationDialog(
                    context,
                    title: "حظر العضو",
                    content:
                        "هل أنت متأكد من حظر ${targetUser.nickname} نهائياً من الغرفة؟",
                    onConfirm: () async {
                      try {
                        await service.banUser(targetUser.uid);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم حظر العضو بنجاح')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                        }
                      }
                    },
                  );
                },
              ),

            if (amIOwner) ...[
              if (isMember || isTargetAdmin || isTargetDeputy)
                if (!isTargetDeputy) // Only show promote to admin if not already co-owner (Co-owner is higher)
                  _buildActionTile(
                    context,
                    icon: isTargetAdmin ? Icons.shield_outlined : Icons.shield,
                    color: Colors.blueAccent,
                    title: isTargetAdmin
                        ? "تنزيل من مشرف"
                        : "ترقية إلى مشرف (Admin)",
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await service.setAdmin(targetUser.uid, !isTargetAdmin);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isTargetAdmin
                                    ? 'تم تنزيل العضو من الإشراف'
                                    : 'تم ترقية العضو إلى مشرف',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                        }
                      }
                    },
                  ),

              if (isMember || isTargetDeputy)
                _buildActionTile(
                  context,
                  icon: isTargetDeputy ? Icons.star_border : Icons.star,
                  color: Colors.amberAccent,
                  title: isTargetDeputy
                      ? "تنزيل من نائب المالك"
                      : "ترقية إلى نائب المالك (Co-Owner)",
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await service.setCoOwner(targetUser.uid, !isTargetDeputy);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isTargetDeputy
                                  ? 'تم تنزيل العضو من نيابة المالك'
                                  : 'تم ترقية العضو إلى نائب مالك',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                      }
                    }
                  },
                ),
            ],
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  "صاحب الغرفة",
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text(
              "تأكيد",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
