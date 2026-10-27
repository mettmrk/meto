import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/index.dart';
import 'fcm_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _chatsCollection = 'chats';
  final String _messagesCollection = 'messages';

  // Static cache for unread count
  static int? _cachedTotalUnreadCount;
  int? get cachedTotalUnreadCount => _cachedTotalUnreadCount;

  /// الحصول على معرف الشات الفريد بين مستخدمين
  String getChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort(); // ترتيب المعرفات لضمان الحصول على نفس المعرف دائماً بين نفس الشخصين
    return ids.join('_');
  }

  /// إرسال رسالة
  Future<String> sendMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String type = 'text',
    String? mediaUrl,
    int? duration,
    String status = 'sent',
  }) async {
    // التحقق من الحظر والقائمة السوداء
    final senderDoc = await _firestore.collection('users').doc(senderId).get();
    final receiverDoc = await _firestore
        .collection('users')
        .doc(receiverId)
        .get();

    if (!senderDoc.exists || !receiverDoc.exists) {
      throw 'المستخدم غير موجود';
    }

    final senderData = senderDoc.data()!;
    final receiverData = receiverDoc.data()!;

    final List<dynamic> senderBlocked = senderData['blockedUsers'] ?? [];
    final List<dynamic> receiverBlocked = receiverData['blockedUsers'] ?? [];
    final List<dynamic> senderBlacklist = senderData['blacklistedUsers'] ?? [];
    final List<dynamic> receiverBlacklist =
        receiverData['blacklistedUsers'] ?? [];

    if (senderBlocked.contains(receiverId)) {
      throw 'لا يمكنك مراسلة مستخدم قمت بحظره';
    }
    if (receiverBlocked.contains(senderId)) {
      throw 'لا يمكنك مراسلة هذا المستخدم'; // محظور من قبله
    }
    if (senderBlacklist.contains(receiverId)) {
      throw 'لا يمكنك مراسلة مستخدم في قائمتك السوداء';
    }
    if (receiverBlacklist.contains(senderId)) {
      // في القائمة السوداء (العزل)، لا يمكنه مراسلتي.
      throw 'لا يمكنك مراسلة هذا المستخدم';
    }

    // التحقق من المتابعة المربوطة (يجب أن يكون المستقبل يتابع المرسل)
    // استثناء: السماح بالمراسلة إذا كان المستقبل هو حساب الدعم الرسمي (displayId: 1)
    final List<dynamic> receiverFollowing = receiverData['following'] ?? [];
    final bool isReceiverSupport = receiverData['displayId'] == '1';

    if (!isReceiverSupport && !receiverFollowing.contains(senderId)) {
      throw 'لا يمكنك مراسلة هذا المستخدم إلا بعد أن يقوم بمتابعتك';
    }

    final chatId = getChatId(senderId, receiverId);
    final timestamp = FieldValue.serverTimestamp();

    // 1. إضافة الرسالة للمجموعة الفرعية
    final messageRef = _firestore
        .collection(_chatsCollection)
        .doc(chatId)
        .collection(_messagesCollection)
        .doc();

    await messageRef.set({
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp,
      'serverTimestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'isDelivered': false,
      'type': type,
      'mediaUrl': mediaUrl,
      'duration': duration,
      'status': status,
    });

    // 2. تحديث بيانات الشات الرئيسي
    await _firestore.collection(_chatsCollection).doc(chatId).set({
      'participants': FieldValue.arrayUnion([senderId, receiverId]),
      'lastMessage': type == 'text'
          ? text
          : (type == 'audio' ? '🎵 بصمة صوتية' : '📷 صورة'),
      'lastTimestamp': timestamp,
      'unreadCounts': {receiverId: FieldValue.increment(1)},
    }, SetOptions(merge: true));

    // 3. إرسال إشعار لحظي (only for sent messages, not pending)
    if (status == 'sent') {
      try {
        final fcmToken = receiverData['fcmToken'];
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await FCMService.sendNotification(
            deviceToken: fcmToken,
            title:
                senderData['nickname'] ??
                senderData['username'] ??
                'رسالة جديدة',
            body: text,
            data: {
              'type': '4', // Chat Message index
              'senderId': senderId,
              'chatId': chatId,
              'messageType': type, // Specific type like 'text', 'audio', 'image', 'room_invite'
            },
          );
        }
      } catch (error) {
        print('Error sending chat FCM: $error');
        // We don't re-throw here to avoid failing the message send if only the notification fails
      }
    }

    return messageRef.id;
  }

  /// الحصول على تدفق الرسائل لشات معين
  Stream<List<Message>> getMessagesStream(String chatId) {
    return _firestore
        .collection(_chatsCollection)
        .doc(chatId)
        .collection(_messagesCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => Message.fromMap(doc.data(), doc.id))
              .toList();
              
          // الترتيب محلياً أيضا لضمان أن البصمات (والتي ربما لم يكن لها وقت من الخادم بعد)
          // تظهر بالترتيب الصحيح (من الأحدث للأقدم) إذا لم تتضمنها الفايربيس بطريقة صحيحة
          messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          
          return messages;
        });
  }

  /// الحصول على قائمة المحادثات للمستخدم الحالي
  Stream<List<Chat>> getChatsStream(String userId) {
    return _firestore
        .collection(_chatsCollection)
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Chat.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Future<void> markAsRead(String chatId, String userId) async {
    try {
      // تصفير العداد
      await _firestore.collection(_chatsCollection).doc(chatId).set({
        'unreadCounts': {userId: 0},
      }, SetOptions(merge: true));

      // تحديث حالة الرسائل (isRead = true)
      final unreadMessages = await _firestore
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesCollection)
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in unreadMessages.docs) {
          batch.update(doc.reference, {'isRead': true, 'isDelivered': true});
        }
        await batch.commit();
      }
    } catch (error) {
      print('Error marking messages as read: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// تحديد الرسائل كمستلمة (Delivered)
  Future<void> markMessagesAsDelivered(String chatId, String userId) async {
    try {
      final undeliveredMessages = await _firestore
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesCollection)
          .where('receiverId', isEqualTo: userId)
          .where('isDelivered', isEqualTo: false)
          .get();

      if (undeliveredMessages.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in undeliveredMessages.docs) {
        batch.update(doc.reference, {'isDelivered': true});
      }
      await batch.commit();
    } catch (error) {
      print('Error marking messages as delivered: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// تحديث حالة الكتابة
  Future<void> setTypingStatus(
    String chatId,
    String userId,
    bool isTyping,
  ) async {
    try {
      await _firestore.collection(_chatsCollection).doc(chatId).set({
        'typingStatus': {userId: isTyping},
      }, SetOptions(merge: true));
    } catch (error) {
      print('Error setting typing status: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// تحديث حالة تسجيل البصمة
  Future<void> setRecordingStatus(
    String chatId,
    String userId,
    bool isRecording,
  ) async {
    try {
      await _firestore.collection(_chatsCollection).doc(chatId).set({
        'recordingStatus': {userId: isRecording},
      }, SetOptions(merge: true));
    } catch (error) {
      print('Error setting recording status: $error');
      rethrow;
    }
  }

  /// حذف المحادثة بالكامل
  Future<void> deleteChat(String chatId) async {
    await clearChatMessages(chatId);
    // 2. حذف مستند المحادثة الرئيسي
    await _firestore.collection(_chatsCollection).doc(chatId).delete();
  }

  /// تنظيف محتوى الرسائل فقط
  Future<void> clearChatMessages(String chatId) async {
    final messages = await _firestore
        .collection(_chatsCollection)
        .doc(chatId)
        .collection(_messagesCollection)
        .get();

    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// الحصول على تدفق بيانات شات معين (لمراقبة حالة الكتابة)
  Stream<Chat?> getChatStream(String chatId) {
    return _firestore.collection(_chatsCollection).doc(chatId).snapshots().map((
      doc,
    ) {
      if (doc.exists) {
        return Chat.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    });
  }

  /// الحصول على عدد الرسائل غير المقروءة الكلي للمستخدم
  Stream<int> getTotalUnreadCountStream(String userId) {
    return _firestore
        .collection(_chatsCollection)
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          int totalUnread = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final unreadCounts = Map<String, int>.from(
              data['unreadCounts'] ?? {},
            );
            totalUnread += unreadCounts[userId] ?? 0;
          }
          _cachedTotalUnreadCount = totalUnread;
          return totalUnread;
        });
  }

  /// إرسال بصمة صوتية
  Future<String> sendAudioMessage({
    required String senderId,
    required String receiverId,
    required String audioPath,
    required int duration,
  }) async {
    // Phase 1: Create pending message immediately
    final messageId = await sendMessage(
      senderId: senderId,
      receiverId: receiverId,
      text: 'بصمة صوتية',
      type: 'audio',
      mediaUrl: audioPath, // Temporary local path
      duration: duration,
      status: 'pending',
    );

    // Phase 2: Upload in background and update status
    _uploadAudioAndUpdateStatus(
      messageId: messageId,
      audioPath: audioPath,
      senderId: senderId,
      receiverId: receiverId,
      duration: duration,
    );

    return messageId;
  }

  /// Upload audio file and update message status
  Future<void> _uploadAudioAndUpdateStatus({
    required String messageId,
    required String audioPath,
    required String senderId,
    required String receiverId,
    required int duration,
  }) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final Reference ref = _storage.ref().child('chats/audio/$fileName');
      
      // Explicitly set content type to ensure player compatibility
      final metadata = SettableMetadata(
        contentType: 'audio/mp4',
        customMetadata: {'duration': duration.toString()},
      );
      
      final UploadTask uploadTask = ref.putFile(File(audioPath), metadata);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update message with download URL and status 'sent'
      final chatId = getChatId(senderId, receiverId);
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'mediaUrl': downloadUrl, 'status': 'sent'});

      print('🎤 Audio uploaded successfully: $downloadUrl');
    } catch (error) {
      print('Error uploading audio: $error');

      // Update message status to 'failed'
      final chatId = getChatId(senderId, receiverId);
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'status': 'failed'});

      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// إرسال صورة
  Future<String> sendImageMessage({
    required String senderId,
    required String receiverId,
    required File imageFile,
  }) async {
    // Phase 1: Create pending message immediately with local path
    final messageId = await sendMessage(
      senderId: senderId,
      receiverId: receiverId,
      text: 'صورة',
      type: 'image',
      mediaUrl: imageFile.path, // Temporary local path
      status: 'pending',
    );

    // Phase 2: Upload in background and update status
    _uploadImageAndUpdateStatus(
      messageId: messageId,
      imageFile: imageFile,
      senderId: senderId,
      receiverId: receiverId,
    );

    return messageId;
  }

  /// Upload image file and update message status
  Future<void> _uploadImageAndUpdateStatus({
    required String messageId,
    required File imageFile,
    required String senderId,
    required String receiverId,
  }) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('chats/images/$fileName');
      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update message with download URL and status 'sent'
      final chatId = getChatId(senderId, receiverId);
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'mediaUrl': downloadUrl, 'status': 'sent'});

      print('📷 Image uploaded successfully: $downloadUrl');
    } catch (error) {
      print('Error uploading image: $error');

      // Update message status to 'failed'
      final chatId = getChatId(senderId, receiverId);
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'status': 'failed'});
    }
  }

  /// حذف الرسالة لدي فقط
  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final messageRef = _firestore
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesCollection)
          .doc(messageId);

      await messageRef.update({
        'isDeletedForMe': FieldValue.arrayUnion([userId]),
      });
    } catch (error) {
      print('Error deleting message for me: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// حذف الرسالة للجميع (للمرسل فقط)
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
  }) async {
    try {
      final messageRef = _firestore
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesCollection)
          .doc(messageId);

      await messageRef.update({
        'isDeletedForEveryone': true,
        'text': 'تم حذف هذه الرسالة',
      });
    } catch (error) {
      print('Error deleting message for everyone: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// تعديل الرسالة (للرسائل النصية فقط)
  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    try {
      final messageRef = _firestore
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesCollection)
          .doc(messageId);

      await messageRef.update({
        'text': newText,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      print('Error editing message: $error');
      rethrow;
    }
  }

  /// إرسال رسالة موقع
  Future<void> sendLocationMessage({
    required String senderId,
    required String receiverId,
    required double latitude,
    required double longitude,
  }) async {
    final locationText = '$latitude,$longitude';
    final mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    await sendMessage(
      senderId: senderId,
      receiverId: receiverId,
      text: locationText,
      type: 'location',
      mediaUrl: mapsUrl,
    );
  }
}
