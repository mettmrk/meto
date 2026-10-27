import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class BlockWrapper extends StatelessWidget {
  final Widget child;

  const BlockWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentUser = auth.FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return child;
    }

    return StreamBuilder<User?>(
      stream: UserService().getUserStream(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // You can return the child or a loading indicator.
          // Returning child means the app is interactive for a split second until data arrives.
          return child;
        }

        final user = snapshot.data;
        if (user == null) {
          return child;
        }

        if (user.isBanned || user.isSuspended || user.isDisabled) {
          return _buildBlockOverlay(context, user);
        }

        return child;
      },
    );
  }

  Widget _buildBlockOverlay(BuildContext context, User user) {
    String title = 'حسابك مقيد';
    String type = 'unknown';

    if (user.isDisabled) {
      title = 'تم تعطيل حسابك';
      type = 'disable';
    } else if (user.isSuspended) {
      title = 'تم توقف حسابك';
      type = 'suspend';
    } else if (user.isBanned) {
      title = 'تم حظر حسابك';
      type = 'ban';
    }

    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (navContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade900, Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 100),
                    const Icon(
                      Icons.block_flipped,
                      color: Colors.white,
                      size: 100,
                    ),
                    const SizedBox(height: 40),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        user.banReason ??
                            'نأسف، لقد تم اتخاذ إجراء بحق حسابك لمخالفة القوانين.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildSupportSection(navContext, user, type),
                    const SizedBox(height: 50),
                    ElevatedButton(
                      onPressed: () => auth.FirebaseAuth.instance.signOut(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red.shade900,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context, User user, String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: UserService().getUserSupportTicketsStream(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Column(
            children: [
              const Text(
                'إذا كنت تعتقد أن هذا الإجراء تم عن طريق الخطأ، يرجى التواصل مع الدعم الفني.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _showSupportDialog(context, user, type),
                icon: const Icon(Icons.support_agent, color: Colors.white),
                label: const Text(
                  'مراسلة الدعم الفني',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          );
        }

        final docs = snapshot.data!.docs.toList();

        final pendingDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['status'] ?? 'pending') == 'pending';
        }).toList();

        if (pendingDocs.isEmpty) {
          // No active pending ticket, allow submitting a new one
          return Column(
            children: [
              const Text(
                'إذا كنت تعتقد أن هذا الإجراء تم عن طريق الخطأ، يرجى التواصل مع الدعم الفني.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _showSupportDialog(context, user, type),
                icon: const Icon(Icons.support_agent, color: Colors.white),
                label: const Text(
                  'مراسلة الدعم الفني',
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          );
        }

        // Sort pending tickets to show the most recent one
        pendingDocs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final dateA = dataA['createdAt'] as Timestamp?;
          final dateB = dataB['createdAt'] as Timestamp?;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA); // Descending
        });

        final ticketDoc = pendingDocs.first;
        final ticketData = ticketDoc.data() as Map<String, dynamic>;
        final feedback = ticketData['adminFeedback'] ?? '';

        String statusText = 'طلبك قيد المراجعة';
        Color statusColor = Colors.orange;

        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: statusColor),
                  const SizedBox(width: 10),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (feedback.isNotEmpty) ...[
                const Divider(color: Colors.white24),
                Text(
                  'رد الدعم: $feedback',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showSupportDialog(BuildContext context, User user, String type) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('مراسلة الدعم الفني'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'يرجى توضيح المشكلة أو سبب طلب الاستئناف وسيتم الرد عليك في أقرب وقت.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'اكتب هنا...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                await UserService().submitSupportTicket(
                  uid: user.uid,
                  username: user.username,
                  reason: controller.text.trim(),
                  type: type,
                );
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرسال طلبك بنجاح')),
                  );
                }
              },
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }
}
