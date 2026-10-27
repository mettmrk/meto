import 'package:flutter/material.dart';
import 'package:mmmm/screens/daily_tasks_screen.dart';
import 'package:mmmm/widgets/music_player_bottom_sheet.dart';
import 'package:lottie/lottie.dart';
import '../services/task_service.dart';
import '../services/notification_service.dart';
import '../services/chat_service.dart';
import '../models/notification_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class RoomSidebarActions extends StatelessWidget {
  final String roomId;
  final VoidCallback onShowMessages;

  const RoomSidebarActions({
    super.key,
    required this.roomId,
    required this.onShowMessages,
  });

  @override
  Widget build(BuildContext context) {
    // Note: We use Selector or specific consumers to avoid rebuilding everything.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Tasks Icon
        _TasksAction(uid: auth.FirebaseAuth.instance.currentUser?.uid ?? ''),
        const SizedBox(height: 15),

        // 2. Messages Action
        _MessagesAction(
          uid: auth.FirebaseAuth.instance.currentUser?.uid ?? '',
          onTap: onShowMessages,
        ),
        const SizedBox(height: 15),

        // 3. Music Action
        const _MusicAction(),
      ],
    );
  }
}

class _TasksAction extends StatefulWidget {
  final String uid;
  const _TasksAction({required this.uid});

  @override
  State<_TasksAction> createState() => _TasksActionState();
}

class _TasksActionState extends State<_TasksAction> {
  late Stream<bool> _tasksStream;

  @override
  void initState() {
    super.initState();
    _tasksStream = TaskService().hasClaimableRewardsStream(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _tasksStream,
      builder: (context, snapshot) {
        final hasRewards = snapshot.data ?? false;
        return GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => DraggableScrollableSheet(
                initialChildSize: 0.85,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                builder: (context, scrollController) =>
                    const DailyTasksScreen(),
              ),
            );
          },
          child: SidebarIconUI(
            label: 'المهام',
            icon: Icons.lightbulb_outline_rounded,
            color: Colors.amberAccent,
            badge: hasRewards ? '!' : null,
            child: Lottie.asset(
              'assets/lottie/Idea.json',
              repeat: true,
              width: 25,
              height: 25,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.checklist_rounded,
                color: Colors.amberAccent,
                size: 20,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessagesAction extends StatefulWidget {
  final String uid;
  final VoidCallback onTap;
  const _MessagesAction({required this.uid, required this.onTap});

  @override
  State<_MessagesAction> createState() => _MessagesActionState();
}

class _MessagesActionState extends State<_MessagesAction> {
  late Stream<List<NotificationModel>> _notifStream;
  late Stream<int> _chatUnreadStream;

  @override
  void initState() {
    super.initState();
    _notifStream = NotificationService().getNotificationsStream(widget.uid);
    _chatUnreadStream = ChatService().getTotalUnreadCountStream(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notifStream,
      builder: (context, notifSnapshot) {
        return StreamBuilder<int>(
          stream: _chatUnreadStream,
          builder: (context, chatUnreadSnapshot) {
            int notifCount = 0;
            if (notifSnapshot.hasData) {
              notifCount = notifSnapshot.data!
                  .where((n) => !n.isRead && n.type == NotificationType.follow)
                  .length;
            }
            int chatCount = chatUnreadSnapshot.data ?? 0;
            int totalCount = notifCount + chatCount;

            return GestureDetector(
              onTap: widget.onTap,
              child: SidebarIconUI(
                label: 'الرسائل',
                icon: Icons.chat_bubble_rounded,
                color: Colors.blueAccent,
                badge: totalCount > 0 ? totalCount.toString() : null,
                child: Lottie.network(
                  'https://assets10.lottiefiles.com/packages/lf20_7msh8snk.json',
                  repeat: true,
                  width: 25,
                  height: 25,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MusicAction extends StatelessWidget {
  const _MusicAction();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => const MusicPlayerBottomSheet(),
        );
      },
      child: const SidebarIconUI(
        label: 'الموسيقى',
        icon: Icons.album_rounded,
        color: Colors.blueAccent,
        child: _MusicDiscIconUI(),
      ),
    );
  }
}

class SidebarIconUI extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String? badge;
  final Widget? child;

  const SidebarIconUI({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.badge,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(child: child ?? Icon(icon, color: color, size: 20)),
            ),
            if (badge != null)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
      ],
    );
  }
}

class _MusicDiscIconUI extends StatefulWidget {
  const _MusicDiscIconUI();

  @override
  State<_MusicDiscIconUI> createState() => _MusicDiscIconUIState();
}

class _MusicDiscIconUIState extends State<_MusicDiscIconUI>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Image.asset(
        'assets/images/disc music.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.album_rounded, color: Colors.blueAccent, size: 24),
      ),
    );
  }
}
