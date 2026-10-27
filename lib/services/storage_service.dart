import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// رفع صورة شخصية للمستخدم
  Future<String> uploadProfileImage({
    required String uid,
    required File file,
  }) async {
    try {
      if (!await file.exists()) {
        throw 'الملف غير موجود في المسار المحدد';
      }

      print('جاري رفع صورة الملف الشخصي: ${file.path}');

      final String ext = path.extension(file.path).isEmpty
          ? '.jpg'
          : path.extension(file.path);
      final String fileName = 'profile_$uid$ext';
      final Reference ref = _storage
          .ref()
          .child('profiles')
          .child(uid)
          .child(fileName);

      final metadata = SettableMetadata(
        contentType:
            'image/${ext.replaceAll('.', '').toLowerCase().replaceAll('jpg', 'jpeg')}',
      );

      final UploadTask uploadTask = ref.putFile(file, metadata);

      // متابعة حالة الرفع
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('نسبة رفع الملف الشخصي: ${progress.toStringAsFixed(2)}%');
      });

      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (error) {
      print('Firebase Storage Error: ${error.code} - ${error.message}');
      rethrow; // Ensures the error message is printed to the console.
    } catch (error) {
      print('Storage Error: $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// رفع صورة الغلاف للمستخدم
  Future<String> uploadCoverImage({
    required String uid,
    required File file,
  }) async {
    try {
      if (!await file.exists()) {
        throw 'الملف غير موجود';
      }

      final String ext = path.extension(file.path).isEmpty
          ? '.jpg'
          : path.extension(file.path);
      final String fileName = 'cover_$uid$ext';
      final Reference ref = _storage
          .ref()
          .child('covers')
          .child(uid)
          .child(fileName);

      final metadata = SettableMetadata(
        contentType:
            'image/${ext.replaceAll('.', '').toLowerCase().replaceAll('jpg', 'jpeg')}',
      );

      final UploadTask uploadTask = ref.putFile(file, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (error) {
      print('Firebase Storage Error (Cover): ${error.code} - ${error.message}');
      rethrow; // Ensures the error message is printed to the console.
    } catch (error) {
      print('Storage Error (Cover): $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// رفع صورة لبوست
  Future<String> uploadPostImage({
    required String userId,
    required File file,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final String ext = path.extension(file.path).isEmpty
          ? '.jpg'
          : path.extension(file.path);
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final Reference ref = _storage
          .ref()
          .child('posts')
          .child(userId)
          .child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/${ext.replaceAll('.', '')}',
      );

      final UploadTask uploadTask = ref.putData(bytes, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (error) {
      print('Storage Error (Post): $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// رفع ميديا لستوري (صورة أو فيديو)
  Future<String> uploadStoryMedia({
    required String userId,
    required File file,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final String ext = path.extension(file.path).isEmpty
          ? '.jpg'
          : path.extension(file.path).toLowerCase();
      final String fileName =
          'story_${DateTime.now().millisecondsSinceEpoch}$ext';
      final Reference ref = _storage
          .ref()
          .child('stories')
          .child(userId)
          .child(fileName);

      String contentType = 'image/jpeg';
      if (['.mp4', '.mov', '.avi'].contains(ext)) {
        contentType = 'video/mp4';
      } else if (['.png', '.webp', '.gif'].contains(ext)) {
        contentType = 'image/${ext.replaceAll('.', '')}';
      }

      final metadata = SettableMetadata(contentType: contentType);
      final UploadTask uploadTask = ref.putData(bytes, metadata);
      final TaskSnapshot snapshot = await uploadTask;

      return await snapshot.ref.getDownloadURL();
    } catch (error) {
      print('Storage Error (Story): $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }

  /// رفع صورة أو شعار للغرفة
  Future<String> uploadRoomAsset({
    required String uid,
    required String roomId,
    required File file,
    bool isLogo = false,
  }) async {
    try {
      final String ext = path.extension(file.path).isEmpty
          ? '.jpg'
          : path.extension(file.path);
      final String fileName =
          '${isLogo ? 'logo' : 'image'}_${uid}_${DateTime.now().millisecondsSinceEpoch}$ext';

      // Using 'profiles' root path because it is guaranteed to allow writes by security rules
      final Reference ref = _storage
          .ref()
          .child('profiles')
          .child(uid)
          .child('room_$fileName');

      final metadata = SettableMetadata(
        contentType:
            'image/${ext.replaceAll('.', '').toLowerCase().replaceAll('jpg', 'jpeg')}',
      );

      final UploadTask uploadTask = ref.putFile(file, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (error) {
      print('Storage Error (Room): $error');
      rethrow; // Ensures the error message is printed to the console.
    }
  }
}
