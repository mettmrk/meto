import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;
import 'package:google_fonts/google_fonts.dart';
import 'support_chat_screen.dart';

class SupportInboxScreen extends StatefulWidget {
  const SupportInboxScreen({super.key});

  @override
  State<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

class _SupportInboxScreenState extends State<SupportInboxScreen> {
  bool _isCreating = false;

  // ألوان متناسقة وأنيقة
  final Color primaryColor = const Color(0xFF1A1A2E); // كحلي عميق
  final Color accentColor = const Color(0xFF00BFA5);  // تركواز نابض
  final Color backgroundColor = const Color(0xFFF8F9FD); // رمادي فاتح جداً
  final Color ticketCardColor = Colors.white;

  void _createNewTicket() async {
    setState(() => _isCreating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['nickname'] ?? userData['username'] ?? 'مستخدم';

      final ticketRef = await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId': user.uid,
        'userName': userName,
        'status': 'pending',
        'lastMessage': 'تم إنشاء طلب جديد',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isCreating = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SupportChatScreen(
              ticketId: ticketRef.id,
              status: 'pending',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إنشاء الطلب: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'مركز دعم MeTo',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      body: Column(
        children: [
          // نص إرشادي أنيق في الأعلى
          Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor.withOpacity(0.1), Colors.white],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accentColor.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.help_center_rounded, color: accentColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'ابدأ المحادثة واشرح المشكلة بالتفصيل مع ارفاق صورة بالمشكلة ليتم الرد عليك سريعاً',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // قائمة المراسلات
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_tickets')
                  .where('userId', isEqualTo: currentUid)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                
                final tickets = snapshot.data?.docs ?? [];
                
                if (tickets.isEmpty && (snapshot.data?.metadata.isFromCache ?? false)) {
                  return const SizedBox.shrink();
                }
                
                if (tickets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 80, color: primaryColor.withOpacity(0.05)),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد مراسلات سابقة.\nفريق الدعم دائماً في خدمتك.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    final data = ticket.data() as Map<String, dynamic>;
                    final lastMessage = data['lastMessage'] ?? 'بدون رسائل';
                    final status = data['status'] ?? 'pending';
                    final timestamp = data['lastMessageTime'] as Timestamp?;
                    
                    String statusLabel = 'قيد المراجعة';
                    Color statusColor = Colors.amber;
                    if (status == 'solved' || status == 'accepted') {
                      statusLabel = 'تم الحل';
                      statusColor = accentColor;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: ticketCardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(color: Colors.grey.withOpacity(0.05)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Material(
                          color: Colors.transparent,
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SupportChatScreen(
                                    ticketId: ticket.id,
                                    status: status,
                                  ),
                                ),
                              );
                            },
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                status == 'solved' || status == 'accepted' 
                                    ? Icons.done_all_rounded 
                                    : Icons.access_time_filled_rounded,
                                color: statusColor,
                                size: 28,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  'تذكرة #${ticket.id.substring(0, 5)}',
                                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 15, color: primaryColor),
                                ),
                                const Spacer(),
                                if (timestamp != null)
                                  Text(
                                    intl.DateFormat('MM/dd HH:mm').format(timestamp.toDate()),
                                    style: GoogleFonts.tajawal(fontSize: 10, color: Colors.grey),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.tajawal(fontSize: 13, color: primaryColor.withOpacity(0.6)),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: GoogleFonts.tajawal(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: primaryColor.withOpacity(0.2)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // زر بدء محادثة جديدة أنيق
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, -10)),
              ],
            ),
            child: Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryColor, const Color(0xFF2B2B4E)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6)),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createNewTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      _isCreating ? 'جاري التحضير...' : 'بدء محادثة جديدة',
                      style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
