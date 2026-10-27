import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/level_badge.dart';

class SupportChatScreen extends StatefulWidget {
  final String ticketId;
  final String status;

  const SupportChatScreen({
    super.key,
    required this.ticketId,
    required this.status,
  });

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // ألوان متناسقة وأنيقة
  final Color primaryColor = const Color(0xFF1A1A2E); // كحلي عميق
  final Color accentColor = const Color(0xFF00BFA5);  // تركواز نابض
  final Color bubbleMeColor = const Color(0xFF4A4E69); // رمادي مائل للبنفسجي هادئ
  final Color bubbleOtherColor = Colors.white;

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    _messageController.clear();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final batch = FirebaseFirestore.instance.batch();
      
      final messageRef = FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(widget.ticketId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'senderId': user.uid,
        'text': text,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
      });

      final ticketRef = FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(widget.ticketId);

      batch.update(ticketRef, {
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الإرسال: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sendImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      
      if (image == null) return;

      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final storageRef = FirebaseStorage.instance.ref().child('support_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(File(image.path));
      final imageUrl = await storageRef.getDownloadURL();

      final batch = FirebaseFirestore.instance.batch();

      final messageRef = FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(widget.ticketId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'senderId': user.uid,
        'text': 'أرسل صورة',
        'type': 'image',
        'mediaUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final ticketRef = FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(widget.ticketId);

      batch.update(ticketRef, {
        'lastMessage': '📷 صورة',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إرسال الصورة: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isSolved = widget.status == 'solved' || widget.status == 'accepted';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Column(
          children: [
            Text('مركز المساعدة', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              'تذكرة #${widget.ticketId.substring(0, 5)}',
              style: GoogleFonts.tajawal(fontSize: 10, color: Colors.white70),
            ),
          ],
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
          // شريط الحالة الراقي
          if (!isSolved)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.amber.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const LevelBadge(level: 1, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'المشكلة قيد المراجعة، فريقنا سيهتم بطلبك قريباً.',
                      style: GoogleFonts.tajawal(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // قائمة الرسائل
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_tickets')
                  .doc(widget.ticketId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final messages = snapshot.data?.docs ?? [];
                
                if (messages.isEmpty && (snapshot.data?.metadata.isFromCache ?? false)) {
                  return const SizedBox.shrink();
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.chat_bubble_outline_rounded, size: 48, color: primaryColor.withOpacity(0.2)),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'ابدأ المحادثة واشرح المشكلة بالتفصيل\nمع ارفاق صورة بالمشكلة ليتم الرد عليك سريعا.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final text = data['text'] ?? '';
                    final type = data['type'] ?? 'text';
                    final mediaUrl = data['mediaUrl'];
                    final senderId = data['senderId'] ?? '';
                    final isMe = senderId == currentUid;
                    final timestamp = data['timestamp'] as Timestamp?;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                        decoration: BoxDecoration(
                          color: isMe ? bubbleMeColor : bubbleOtherColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isMe ? 20 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 20),
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (type == 'image' && mediaUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: mediaUrl,
                                  placeholder: (context, url) => Container(
                                    width: 200,
                                    height: 150,
                                    color: Colors.grey.shade100,
                                  ),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                ),
                              )
                            else
                              Text(
                                text,
                                style: GoogleFonts.tajawal(
                                  color: isMe ? Colors.white : primaryColor,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              timestamp != null 
                                  ? intl.DateFormat('HH:mm').format(timestamp.toDate())
                                  : '...',
                              style: TextStyle(
                                color: isMe ? Colors.white54 : Colors.grey,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // منطقة الإدخال الراقية
          if (!isSolved)
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isLoading ? null : _sendImage,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.image_rounded, color: accentColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: null,
                        style: GoogleFonts.tajawal(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالتك وتفاصيل المشكلة...',
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.tajawal(fontSize: 13, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [accentColor, const Color(0xFF009688)]),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: _isLoading 
                          ? const Icon(Icons.downloading, color: Colors.white, size: 24)
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.verified_rounded, color: Colors.green, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'تم إغلاق هذه التذكرة بنجاح',
                    style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 17, color: primaryColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'إذا كانت لديك مشكلة أخرى، يرجى إنشاء طلب جديد',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tajawal(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: Text('رجوع للقائمة', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
