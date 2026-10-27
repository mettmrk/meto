import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a secure payment order in the database.
  /// In a real app, this would be verified by a Cloud Function using a Google/Apple receipt.
  Future<String> createSecureOrder({
    required String uid,
    required int amount,
    required String price,
    required String packageName,
  }) async {
    try {
      final String orderId =
          'ORD-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999)}';

      await _firestore.collection('payment_orders').doc(orderId).set({
        'orderId': orderId,
        'userId': uid,
        'amount': amount,
        'price': price,
        'packageName': packageName,
        'status': 'pending', // Initial status
        'createdAt': FieldValue.serverTimestamp(),
        'method': 'in_app_purchase',
      });

      return orderId;
    } catch (e) {
      throw 'حدث خطأ في إنشاء طلب الشراء: $e';
    }
  }

  /// Simulates a secure verification from a server callback or receipt validation.
  /// For the client, we listen to this document to see when it changes to 'completed'.
  Stream<DocumentSnapshot> watchOrder(String orderId) {
    return _firestore.collection('payment_orders').doc(orderId).snapshots();
  }

  /// SECURE VERSION: Verification must happen within a transaction on the server.
  /// This simulates what the server-side validator (Cloud Function) would do.
  Future<void> simulateServerVerification(String orderId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference orderRef = _firestore
            .collection('payment_orders')
            .doc(orderId);
        DocumentSnapshot orderSnap = await transaction.get(orderRef);

        if (!orderSnap.exists) throw 'الطلب غير موجود';
        final orderData = orderSnap.data() as Map<String, dynamic>;

        if (orderData['status'] == 'completed') throw 'هذا الطلب مكتمل بالفعل';

        final String uid = orderData['userId'];
        final int amount = orderData['amount'];

        // 1. Mark order as completed
        transaction.update(orderRef, {
          'status': 'completed',
          'verifiedAt': FieldValue.serverTimestamp(),
        });

        // 2. Update user diamonds securely
        DocumentReference userRef = _firestore.collection('users').doc(uid);
        transaction.update(userRef, {
          'diamonds': FieldValue.increment(amount),
          'totalRechargedDiamonds': FieldValue.increment(amount),
          'lastRechargeDate': FieldValue.serverTimestamp(),
        });

        // 3. Create a recharge log in transactions (unified log)
        DocumentReference logRef = _firestore.collection('transactions').doc();
        transaction.set(logRef, {
          'userId': uid,
          'type': 'diamond_recharge',
          'title': 'شحن ألماس',
          'amount': amount,
          'orderId': orderId,
          'timestamp': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
          'status': 'verified',
        });
      });
    } catch (e) {
      throw 'خطأ في التحقق من العملية: $e';
    }
  }

  /// REAL IAP VERSION: Delivers diamonds after real store purchase.
  Future<void> simulateServerVerificationFromIAP({
    required String uid,
    required int amount,
    required String purchaseId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Check if this purchaseId was already processed (Anti-cheat) using stable Doc ID
        DocumentReference processedRef = _firestore
            .collection('processed_iap_purchases')
            .doc(purchaseId);
        DocumentSnapshot processedSnap = await transaction.get(processedRef);

        if (processedSnap.exists) {
          throw 'تنبيه: تم معالجة هذه العملية مسبقاً';
        }

        // 2. Update user diamonds securely
        DocumentReference userRef = _firestore.collection('users').doc(uid);
        transaction.update(userRef, {
          'diamonds': FieldValue.increment(amount),
          'totalRechargedDiamonds': FieldValue.increment(amount),
          'lastRechargeDate': FieldValue.serverTimestamp(),
          'isPremiumMember': true,
        });

        // 3. Mark as processed TRANSACTIONALLY
        transaction.set(processedRef, {
          'purchaseId': purchaseId,
          'processedAt': FieldValue.serverTimestamp(),
          'uid': uid,
          'amount': amount,
        });

        // 4. Create a financial receipt in transactions log
        DocumentReference logRef = _firestore.collection('transactions').doc();
        transaction.set(logRef, {
          'userId': uid,
          'type': 'diamond_recharge',
          'title': 'شحن ألماس خارجي',
          'amount': amount,
          'purchaseId': purchaseId,
          'timestamp': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
          'status': 'verified',
        });
      });
    } catch (e) {
      throw 'فشل تسليم الماس: $e';
    }
  }
}
