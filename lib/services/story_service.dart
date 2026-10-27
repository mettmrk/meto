import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/index.dart';

/// خدمة Firestore لإدارة الستوريز
class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _storiesCollection = 'stories';

  // Static cache for data only
  static List<Story>? _cachedStories;

  List<Story>? get cachedStories => _cachedStories;

  /// إنشاء ستوري جديد
  Future<String> createStory({
    required String userId,
    required String username,
    String? storyImage,
    String? storyVideo,
    String? caption,
    String? userProfileImage,
  }) async {
    try {
      final story = Story(
        id: '', // سيتم إنشاء id من Firestore
        userId: userId,
        username: username,
        storyImage: storyImage,
        storyVideo: storyVideo,
        caption: caption,
        userProfileImage: userProfileImage,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      final docRef = await _firestore
          .collection(_storiesCollection)
          .add(story.toMap());
      return docRef.id;
    } catch (e) {
      throw 'خطأ في إنشاء الستوري: $e';
    }
  }

  /// الحصول على جميع الستوريز النشطة
  Future<List<Story>> getActiveStories() async {
    try {
      final now = DateTime.now();
      final querySnapshot = await _firestore
          .collection(_storiesCollection)
          .where('expiresAt', isGreaterThan: now.toIso8601String())
          .orderBy('expiresAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Story.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'خطأ في جلب الستوريز: $e';
    }
  }

  /// الحصول على ستوريز مستخدم معين
  Future<List<Story>> getUserStories(String userId) async {
    try {
      final now = DateTime.now();
      final querySnapshot = await _firestore
          .collection(_storiesCollection)
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: now.toIso8601String())
          .orderBy('expiresAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => Story.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw 'خطأ في جلب ستوريز المستخدم: $e';
    }
  }

  /// الحصول على ستوري معين
  Future<Story?> getStory(String storyId) async {
    try {
      final doc = await _firestore
          .collection(_storiesCollection)
          .doc(storyId)
          .get();

      if (doc.exists) {
        final story = Story.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        if (!story.isExpired()) {
          return story;
        }
      }
      return null;
    } catch (e) {
      throw 'خطأ في جلب الستوري: $e';
    }
  }

  /// تحديث الستوري
  Future<void> updateStory({
    required String storyId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(_storiesCollection).doc(storyId).update(data);
    } catch (e) {
      throw 'خطأ في تحديث الستوري: $e';
    }
  }

  /// حذف الستوري
  Future<void> deleteStory(String storyId) async {
    try {
      await _firestore.collection(_storiesCollection).doc(storyId).delete();
    } catch (e) {
      throw 'خطأ في حذف الستوري: $e';
    }
  }

  /// إضافة عرض للستوري
  Future<void> viewStory({
    required String storyId,
    required String userId,
  }) async {
    try {
      final storyDoc = await _firestore
          .collection(_storiesCollection)
          .doc(storyId)
          .get();
      final data = storyDoc.data();
      final viewedBy = List<String>.from(data?['viewedBy'] ?? []);

      if (!viewedBy.contains(userId)) {
        viewedBy.add(userId);
        await _firestore.collection(_storiesCollection).doc(storyId).update({
          'viewedBy': viewedBy,
        });
      }
    } catch (e) {
      throw 'خطأ في تحديث الآراء: $e';
    }
  }

  /// التدفق الحي للستوريز
  Stream<List<Story>> getStoriesStream() {
    // Ensuring a fresh stream for each listener to prevent stale state.
    final now = DateTime.now();
    return _firestore
        .collection(_storiesCollection)
        .where('expiresAt', isGreaterThan: now.toIso8601String())
        .orderBy('expiresAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final stories = snapshot.docs
              .map((doc) => Story.fromMap(doc.data(), doc.id))
              .toList();
          _cachedStories = stories;
          return stories;
        });
  }

  /// إضافة تفاعل للستوري
  Future<void> reactToStory({
    required String storyId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final storyDoc = await _firestore
          .collection(_storiesCollection)
          .doc(storyId)
          .get();
      final data = storyDoc.data();
      final reactions = Map<String, String>.from(data?['reactions'] ?? {});

      reactions[userId] = emoji;
      await _firestore.collection(_storiesCollection).doc(storyId).update({
        'reactions': reactions,
      });
    } catch (e) {
      throw 'خطأ في إضافة التفاعل: $e';
    }
  }
}
