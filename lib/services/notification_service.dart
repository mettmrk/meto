import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';
import '../models/notification_model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'dart:ui';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendNotification(NotificationModel notification) async {
    if (notification.receiverId == notification.senderId) return;

    try {
      // 1. Save to Firestore
      await _firestore.collection('notifications').add(notification.toMap());

      // 2. Fetch receiver's FCM token
      final receiverDoc = await _firestore
          .collection('users')
          .doc(notification.receiverId)
          .get();
      if (receiverDoc.exists) {
        final data = receiverDoc.data()!;
        final fcmToken = data['fcmToken'];
        final currentRoomId = data['currentRoomId'];

        // If user is in a room and it's a gift or follow notification, don't show pop-up (banner)
        // Just keeping it in Firestore is enough for the bell notification
        bool shouldShowBanner = true;
        if (currentRoomId != null &&
            (notification.type == NotificationType.gift ||
                notification.type == NotificationType.follow)) {
          shouldShowBanner = false;
        }

        if (fcmToken != null && fcmToken.isNotEmpty && shouldShowBanner) {
          // 3. Send real-time push notification
          await FCMService.sendNotification(
            deviceToken: fcmToken,
            title: notification.senderName,
            body: notification.text,
            data: {
              'type': notification.type.index.toString(),
              'senderId': notification.senderId,
              'postId': notification.postId ?? '',
              'roomId': notification.roomId ?? '',
            },
          );
        }
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    // جلب الإشعارات الخاصة بالمستخدم + الإشعارات العامة (FCM) من الإدارة
    return _firestore
        .collection('notifications')
        .where(Filter.or(
          Filter('receiverId', isEqualTo: userId),
          Filter('target', isEqualTo: 'all'),
        ))
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
              .toList();

          // ترتيب الإشعارات برمجياً (الأحدث أولاً)
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications;
        });
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });

    // حذف الإشعار تلقائياً بعد دقيقة من قراءته
    Timer(const Duration(minutes: 1), () async {
      try {
        await deleteNotification(notificationId);
      } catch (e) {
        print('Error auto-deleting notification: $e');
      }
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final snapshots = await _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snapshots.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();

    // حذف هذه الإشعارات تلقائياً بعد دقيقة
    Timer(const Duration(minutes: 1), () async {
      final deleteBatch = _firestore.batch();
      for (var doc in snapshots.docs) {
        deleteBatch.delete(doc.reference);
      }
      try {
        await deleteBatch.commit();
      } catch (e) {
        print('Error auto-deleting batch notifications: $e');
      }
    });
  }

  // دالة لمسح كافة الإشعارات
  Future<void> clearAllNotifications(String userId) async {
    final batch = _firestore.batch();
    final snapshots = await _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .get();

    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // حذف إشعار واحد
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Schedules a local notification for the reward
  Future<void> scheduleRewardNotification(Duration delay) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    try {
      final scheduledDate = tz.TZDateTime.now(tz.local).add(delay);

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'reward_timer_channel',
            'عداد المكافآت',
            channelDescription: 'إشعارات انتهاء وقت العداد',
            icon: '@drawable/ic_notification',
            largeIcon: const DrawableResourceAndroidBitmap('@drawable/shaar'),
            color: const Color(0xFF0A2E1A),
            importance: Importance.max,
            priority: Priority.high,
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        888, // Unique ID for reward notification
        'انتهى وقت العداد! 🚀',
        'عد إلى ميتو لجمع جواهرك وتشغيله مرة أخرى.',
        scheduledDate,
        platformChannelSpecifics,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('Error scheduling local notification: $e');
    }
  }

  /// Cancels any scheduled reward notification
  Future<void> cancelRewardNotification() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin.cancel(888);
  }
}
