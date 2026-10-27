import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:google_sign_in/google_sign_in.dart' as g_signin;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

/// خدمة المصادقة والتسجيل
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // الحصول على المستخدم الحالي
  User? get currentUser => _auth.currentUser;

  // التحقق من وجود مستخدم مسجل دخول
  bool get isLoggedIn => _auth.currentUser != null;

  // الاستماع إلى تغييرات المصادقة
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// تسجيل مستخدم جديد
  Future<Map<String, dynamic>?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update sessionId on signup
      if (userCredential.user != null) {
        final newSessionId =
            DateTime.now().millisecondsSinceEpoch.toString() +
            Random().nextInt(10000).toString();
        // Return sessionId to be saved when user profile is created
        return {'userCredential': userCredential, 'sessionId': newSessionId};
      }

      return null;
    } on FirebaseAuthException catch (e) {
      // التعامل مع الأخطاء
      String message = 'حدث خطأ ما';
      if (e.code == 'weak-password') {
        message = 'كلمة المرور ضعيفة جداً';
      } else if (e.code == 'email-already-in-use') {
        message = 'البريد الإلكتروني مستخدم بالفعل';
      } else if (e.code == 'invalid-email') {
        message = 'البريد الإلكتروني غير صحيح';
      } else if (e.message?.contains('Connection reset by peer') ?? false) {
        message = 'خطأ في الاتصال: يرجى التأكد من تشغيل VPN أو جودة الإنترنت';
      }
      throw message;
    } catch (e) {
      if (e.toString().contains('Connection reset by peer')) {
        throw 'خطأ في الاتصال بخوادم جوجل (reCAPTCHA). يرجى التأكد من تشغيل VPN.';
      }
      throw 'خطأ غير متوقع: $e';
    }
  }

  /// تسجيل الدخول
  Future<Map<String, dynamic>?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update sessionId on signin
      if (userCredential.user != null) {
        final newSessionId =
            DateTime.now().millisecondsSinceEpoch.toString() +
            Random().nextInt(10000).toString();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({'sessionId': newSessionId});
        return {'userCredential': userCredential, 'sessionId': newSessionId};
      }

      return null;
    } on FirebaseAuthException catch (e) {
      String message = 'حدث خطأ ما';
      if (e.code == 'user-not-found') {
        message = 'المستخدم غير موجود';
      } else if (e.code == 'wrong-password') {
        message = 'كلمة المرور غير صحيحة';
      } else if (e.code == 'user-disabled') {
        message = 'الحساب معطل';
      } else if (e.code == 'invalid-email') {
        message = 'البريد الإلكتروني غير صحيح';
      }
      throw message;
    } catch (e) {
      throw 'خطأ غير متوقع: $e';
    }
  }

  /// تسجيل الدخول باستخدام Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      // Using scopes parameter explicitly
      final g_signin.GoogleSignIn googleSignIn = g_signin.GoogleSignIn(
        scopes: ['email'],
      );
      final g_signin.GoogleSignInAccount? googleUser = await googleSignIn
          .signIn();

      if (googleUser == null) {
        return null; // The user canceled the sign-in
      }

      // Obtain the auth details from the request
      final g_signin.GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the user credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Update sessionId
      if (userCredential.user != null) {
        final newSessionId =
            DateTime.now().millisecondsSinceEpoch.toString() +
            Random().nextInt(10000).toString();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({'sessionId': newSessionId})
            .catchError((e) {
              // Ignore update error if user doc doesn't exist yet
            });
      }

      return userCredential;
    } catch (e) {
      print('Error signing in with Google: $e');
      throw 'خطأ في تسجيل الدخول عبر Google: $e';
    }
  }

  /// تسجيل الدخول باستخدام Facebook
  Future<UserCredential?> signInWithFacebook() async {
    try {
      // Trigger the sign-in flow
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        // Create a credential from the access token
        final OAuthCredential credential = FacebookAuthProvider.credential(
          result.accessToken!.tokenString,
        );

        // Sign in to Firebase with the user credential
        final UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );

        // Update sessionId
        if (userCredential.user != null) {
          final newSessionId =
              DateTime.now().millisecondsSinceEpoch.toString() +
              Random().nextInt(10000).toString();
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .update({'sessionId': newSessionId})
              .catchError((e) {
                // Ignore update error if user doc doesn't exist yet
              });
        }

        return userCredential;
      } else if (result.status == LoginStatus.cancelled) {
        return null;
      } else {
        throw 'فشل تسجيل الدخول عبر فيسبوك: ${result.message}';
      }
    } catch (e) {
      print('Error signing in with Facebook: $e');
      throw 'خطأ في تسجيل الدخول عبر Facebook: $e';
    }
  }

  /// تسجيل الدخول كضيف (مجهول)
  Future<UserCredential> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      // Create a minimal user document if it doesn't exist
      if (userCredential.user != null) {
        final uid = userCredential.user!.uid;
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (!doc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'uid': uid,
            'name': 'ضيف',
            'email': '',
            'isAnonymous': true,
            'createdAt': FieldValue.serverTimestamp(),
            'coins': 0,
            'diamonds': 0,
          });
        }
      }
      return userCredential;
    } catch (e) {
      throw 'خطأ في الدخول كضيف: $e';
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'خطأ في تسجيل الخروج: $e';
    }
  }

  /// تغيير كلمة المرور
  Future<void> changePassword({required String newPassword}) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      String message = 'حدث خطأ ما';
      if (e.code == 'weak-password') {
        message = 'كلمة المرور ضعيفة جداً';
      } else if (e.code == 'requires-recent-login') {
        message = 'يرجى تسجيل الدخول مرة أخرى';
      }
      throw message;
    }
  }

  /// إعادة تعيين كلمة المرور
  Future<void> resetPassword({required String email}) async {
    try {
      // محاولة إرسال بريد إعادة التعيين مباشرة
      // ملاحظة: لكي تظهر رسالة "المستخدم غير موجود"، يجب إيقاف "Email Enumeration Protection" في إعدادات Firebase
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        throw 'البريد غير موجود أو ليس مرتبط بحساب';
      }
      throw 'خطأ في العملية: ${e.message}';
    } catch (e) {
      if (e is String) rethrow;
      throw 'البريد غير موجود أو ليس مرتبط بحساب';
    }
  }

  /// حذف الحساب
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'يرجى تسجيل الدخول مرة أخرى';
      }
      throw 'خطأ في حذف الحساب: $e';
    }
  }

  /// تحديث البريد الإلكتروني
  Future<void> updateEmail({required String newEmail}) async {
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
    } catch (e) {
      throw 'خطأ في تحديث البريد: $e';
    }
  }
}
