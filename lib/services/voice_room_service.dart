// ignore_for_file: avoid_print, invalid_return_type_for_catch_error, duplicate_ignore

import 'dart:async' as dart_async;
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/background_model.dart';
import '../utils/room_level_system.dart';
import '../utils/room_tier_system.dart';
import 'user_service.dart';
import 'gift_service.dart';
import 'shop_service.dart';
import 'task_service.dart';
import 'fcm_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';

class VoiceRoomService extends ChangeNotifier {
  static const String appId = "32dcde8605f74750a23f89cbb8afe486";
  static const String tokenServerUrl =
      "https://your-token-server.com"; // استبدله برابط السيرفر الخاص بك

  late RtcEngineEx _engine;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  VoiceRoomService() {
    _startBackgroundSubscriptions();
    _startFrameExpiryTimer();
  }

  bool _isInitialized = false;
  Completer<void>? _initCompleter;
  bool _isJoined = false;
  bool _isGameChannel =
      false; // Indicates if the user is in an active Ex game channel
  String? _gameChannelId;
  bool _isGameMuted = true;
  bool get isGameMuted => _isGameMuted;
  // Agora UID

  // State
  String? _roomId;

  // Static Caches for Instant Loading
  static List<Map<String, dynamic>>? _cachedRooms;
  static List<Map<String, dynamic>>? _cachedPopularRooms;
  static List<Map<String, dynamic>>? _cachedDiscoveryRooms;
  static List<Map<String, dynamic>>? _cachedJoinedRooms;
  static List<Map<String, dynamic>>? _cachedRecentRooms;
  static Map<String, dynamic>? _cachedMyRoom;

  List<Map<String, dynamic>>? get cachedRooms => _cachedRooms;
  List<Map<String, dynamic>>? get cachedPopularRooms => _cachedPopularRooms;
  List<Map<String, dynamic>>? get cachedDiscoveryRooms => _cachedDiscoveryRooms;
  List<Map<String, dynamic>>? get cachedJoinedRooms => _cachedJoinedRooms;
  List<Map<String, dynamic>>? get cachedRecentRooms => _cachedRecentRooms;
  Map<String, dynamic>? get cachedMyRoom => _cachedMyRoom;

  Stream<DocumentSnapshot> get roomStream {
    if (_roomId == null) return const Stream.empty();
    return _db.collection('rooms').doc(_roomId).snapshots();
  }

  final Set<int> _remoteUsers = {};
  List<Map<String, dynamic>?> _seats = List.generate(10, (index) => null);
  List<Map<String, dynamic>> _messages = [];
  bool _freshJoin = false; // True only on first load after joining
  final Set<int> _activeSpeakers = {}; // Agora UIDs
  final Map<int, int> _userVolumeLevels =
      {}; // Agora UID -> volume level (0 to 255)

  bool _isMuted = false;
  bool _isGlobalMicEnabled = true;
  bool _adminSeatsEnabled = true; // Per-room admin toggle
  bool _adminChatEnabled = true; // Per-room admin toggle
  bool _isBroadcaster = false; // Based on seat status
  bool _isSettingRole = false;
  bool _isTakingSeat =
      false; // Prevent snapshot from overwriting optimistic seat update
  int _seatChangeGeneration =
      0; // Increments on every takeSeat call; only latest wins
  int _viewerCount = 0;
  ClientRoleType? _pendingRole; // Role to apply once joined
  Map<String, dynamic> _activeFrames = {};
  Map<String, dynamic> _activeReactions = {};
  // RAM Cache for instant profile display
  static final Map<String, Map<String, dynamic>> _profileCache = {};
  static final Map<String, String> _userFrameCache = {};
  // Persists temporary frames across room changes for instant display
  static final Map<String, Map<String, dynamic>> _temporaryFrameCache = {};
  final Map<String, int> _userIdToAgoraUid = {}; // Robust mapping
  final Map<int, DateTime> _talkingHoldMap = {}; // State persistence
  bool _isMinimized = false;
  bool _isSpeakerMuted = false;
  bool _isMusicPlaying = false;
  bool _isMusicPaused = false;
  bool _showAmbientBubbles = false; // State for bubbles
  static bool _noiseReductionEnabled = false; // Noise reduction state
  static bool _eyeCareEnabled = false; // Eye care state
  String? _selectedMusicName;
  double _musicVolume = 50.0;
  int _musicDuration = 0;
  int _musicPosition = 0;
  String? _musicSenderId; // Track who is playing
  Timer? _musicProgressTimer;

  // Persist UI Card Positions (Timer, PK) when room is minimized
  Offset _roomTimerPosition = const Offset(20, 150);
  Offset _challengePosition = const Offset(100, 140);

  Offset get roomTimerPosition => _roomTimerPosition;
  Offset get challengePosition => _challengePosition;

  void updateRoomTimerPosition(Offset newPos) {
    _roomTimerPosition = newPos;
  }

  void updateChallengePosition(Offset newPos) {
    _challengePosition = newPos;
  }

  Timer? _heartbeatTimer;
  Timer? _cleanupTimer;
  Timer? _frameExpiryTimer;

  void _startFrameExpiryTimer() {
    _frameExpiryTimer?.cancel();
    _frameExpiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      bool changed = false;
      final now = DateTime.now().toUtc();

      // Check active frames
      final activeKeys = _activeFrames.keys.toList();
      for (final uid in activeKeys) {
        final fData = _activeFrames[uid];
        final expiryStr = fData?['expiry'] as String?;
        if (expiryStr != null) {
          final expiry = DateTime.tryParse(expiryStr)?.toUtc();
          if (expiry != null && now.isAfter(expiry)) {
            _activeFrames.remove(uid);
            changed = true;
          }
        }
      }

      // Check temporary frame cache
      final tempKeys = _temporaryFrameCache.keys.toList();
      for (final uid in tempKeys) {
        final fData = _temporaryFrameCache[uid];
        final expiryStr = fData?['expiry'] as String?;
        if (expiryStr != null) {
          final expiry = DateTime.tryParse(expiryStr)?.toUtc();
          if (expiry != null && now.isAfter(expiry)) {
            _temporaryFrameCache.remove(uid);
            changed = true;
          }
        }
      }

      if (changed) {
        notifyListeners();
      }
    });
  }

  StreamSubscription? _rtdbPresenceSubscription;
  StreamSubscription? _reactionsSubscription;
  StreamSubscription? _giftBgsSubscription;
  StreamSubscription? _shopBgsSubscription;
  String? _exitReason; // 'kicked', 'banned', or null
  bool _isNetworkLost = false; // Tracks local connection status
  Timer? _networkMonitorTimer; // New: Faster check for UI responsiveness

  List<RoomBackground> _allBackgrounds = [...predefinedBackgrounds];
  List<RoomBackground> get allBackgrounds => _allBackgrounds;
  List<RoomBackground> _lastGiftBgs = [];
  List<RoomBackground> _lastShopBgs = [];

  // Getters
  bool get isNetworkLost => _isNetworkLost;
  Set<int> get remoteUsers => _remoteUsers;
  List<Map<String, dynamic>?> get seats => _seats;
  List<Map<String, dynamic>> get messages => _messages;
  bool get isMuted => _isMuted;
  bool get isGlobalMicEnabled => _isGlobalMicEnabled;
  bool get adminSeatsEnabled => _adminSeatsEnabled;
  bool get adminChatEnabled => _adminChatEnabled;
  bool get isBroadcaster => _isBroadcaster;
  bool get isJoined => _isJoined;
  String? get currentRoomId => _roomId;
  String? get currentUserId => _auth.currentUser?.uid;
  String? get exitReason => _exitReason;
  Map<String, dynamic>? get currentRoomData => _currentRoomData;
  int get viewerCount {
    if (_viewerCount > 0) return _viewerCount;
    return _isJoined ? 1 : 0;
  }

  void _listenToLikes(String roomId) {
    _likesSubscription?.cancel();
    _checkLikesDailyReset(roomId); // Check for daily reset on join
    _likesSubscription = _rtdb.ref('rooms/$roomId/likes').onValue.listen((
      event,
    ) {
      if (event.snapshot.value != null) {
        _roomLikes = int.tryParse(event.snapshot.value.toString()) ?? 0;
        notifyListeners();
      }
    });
  }

  dart_async.Future<void> _checkLikesDailyReset(String roomId) async {
    try {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month}-${now.day}";
      final resetRef = _rtdb.ref('rooms/$roomId/lastLikesResetDate');

      final snapshot = await resetRef.get();
      if (snapshot.exists && snapshot.value == todayStr) {
        return; // Already reset today
      }

      // Perform reset
      await _rtdb.ref('rooms/$roomId').update({
        'likes': 0,
        'lastLikesResetDate': todayStr,
      });
    } catch (e) {
      print("Error resetting daily likes: $e");
    }
  }

  bool isUserInRoom(String? userId) {
    if (userId == null) return false;
    if (userId == currentUserId) return _isJoined;
    final uid = getAgoraUid(userId);
    return _remoteUsers.contains(uid);
  }

  String? get musicSenderId => _musicSenderId;
  bool get isMusicOwner => _musicSenderId == currentUserId;
  Map<String, dynamic> get activeFrames => _activeFrames;
  
  String? getActiveFrameForUser(String uid) {
    if (_activeFrames.containsKey(uid)) {
      final fData = _activeFrames[uid];
      final expiryStr = fData['expiry'] as String?;
      if (expiryStr != null) {
        final expiry = DateTime.tryParse(expiryStr)?.toUtc();
        if (expiry != null && DateTime.now().toUtc().isBefore(expiry)) {
          return fData['type'] as String?;
        }
      }
    }
    
    if (_temporaryFrameCache.containsKey(uid)) {
      final cached = _temporaryFrameCache[uid];
      final expiryStr = cached?['expiry'] as String?;
      if (expiryStr != null) {
        final expiry = DateTime.tryParse(expiryStr)?.toUtc();
        if (expiry != null && DateTime.now().toUtc().isBefore(expiry)) {
          return cached?['type'] as String?;
        }
      }
    }
    return null;
  }

  Map<String, dynamic> get activeReactions => _activeReactions;
  Map<String, dynamic> get bannedUsers => _bannedUsers;
  bool get isMinimized => _isMinimized;
  bool get showAmbientBubbles => _showAmbientBubbles; // Getter
  bool get noiseReductionEnabled => _noiseReductionEnabled;
  bool get eyeCareEnabled => _eyeCareEnabled;

  Map<String, dynamic> _admins = {};
  Map<String, dynamic> _coOwners = {};
  Map<String, dynamic> _mutedUsers = {};
  Map<String, dynamic> _bannedUsers = {};

  bool _isMember = false;
  int? _joinTimestamp;
  bool get isRoomMember => _isMember;

  // Invitations
  Map<String, dynamic>? _lastInvitation;
  Map<String, dynamic>? get lastInvitation => _lastInvitation;
  StreamSubscription? _invitationsSubscription;
  StreamSubscription? _userDocSubscription;
  Map<String, dynamic> _roomUsersMetadata = {};
  Map<String, dynamic> get roomUsersMetadata => _roomUsersMetadata;

  bool isAdmin(String uid) => _admins.containsKey(uid);
  bool isModerator(String uid) => _admins.containsKey(uid);
  bool isCoOwner(String uid) => _coOwners.containsKey(uid);
  bool isUserMuted(String uid) => _mutedUsers.containsKey(uid);
  bool get isSpeakerMuted => _isSpeakerMuted;
  bool get isMusicPlaying => _isMusicPlaying;
  bool get isMusicPaused => _isMusicPaused;
  String? get selectedMusicName => _selectedMusicName;
  double get musicVolume => _musicVolume;
  Map<String, dynamic>? _currentRoomData;
  String? _micLayoutType; // New: To cache the layout type
  String? get micLayoutType => _micLayoutType;
  int get musicDuration => _musicDuration;
  int get musicPosition => _musicPosition;

  String? _hostId;
  String? get hostId => _hostId;
  bool get isHost => currentUserId != null && currentUserId == _hostId;

  // Penalty Logging Helpers
  dart_async.Future<void> _logPenalty({
    required String targetUserId,
    required String action, // 'ban', 'kick', 'mute', 'unmute', 'unban'
  }) async {
    if (_roomId == null || currentUserId == null) return;

    try {
      final executorDoc = await _db
          .collection('users')
          .doc(currentUserId)
          .get();
      final targetDoc = await _db.collection('users').doc(targetUserId).get();

      final executorName =
          executorDoc.data()?['nickname'] ??
          executorDoc.data()?['username'] ??
          'مجهول';
      final targetName =
          targetDoc.data()?['nickname'] ??
          targetDoc.data()?['username'] ??
          'عضو';

      await _db
          .collection('rooms')
          .doc(_roomId)
          .collection('penalty_logs')
          .add({
            'executorId': currentUserId,
            'executorName': executorName,
            'targetId': targetUserId,
            'targetName': targetName,
            'action': action,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint("Error logging penalty: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> getPenaltyLogsStream(String roomId) {
    // Simplify query to ensure it works without complex indexing if possible
    // and filter manually if needed, or just use the simplest Firestore filter.
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('penalty_logs')
        .where('timestamp', isGreaterThanOrEqualTo: todayStart)
        .snapshots()
        .map((snap) {
          final docs = snap.docs.map((d) => d.data()).toList();
          // Sort manually in memory to avoid index requirements
          docs.sort((a, b) {
            final ta = a['timestamp'] as Timestamp?;
            final tb = b['timestamp'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
          });
          return docs;
        });
  }

  int _roomLikes = 0;
  int get roomLikes => _roomLikes;
  StreamSubscription? _likesSubscription;

  void clearExitReason() {
    _exitReason = null;
    notifyListeners();
  }

  void setMinimized(bool value) {
    _isMinimized = value;
    notifyListeners();
  }

  dart_async.Future<void> toggleNoiseReduction() async {
    _noiseReductionEnabled = !_noiseReductionEnabled;
    await _applyNoiseReduction();

    // Save preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('noise_reduction_enabled', _noiseReductionEnabled);
    } catch (e) {
      print("[NoiseReduction] Error saving preference: $e");
    }

    notifyListeners();
  }

  dart_async.Future<void> _applyNoiseReduction() async {
    if (!_isInitialized) return;
    try {
      final int val = _noiseReductionEnabled ? 1 : 0;
      final bool state = _noiseReductionEnabled;

      await _engine.setParameters("{\"che.audio.enable_ans\": $state}");
      await _engine.setParameters("{\"che.audio.enable_aec\": $state}");
      await _engine.setParameters("{\"che.audio.enable_agc\": $state}");
      await _engine.setParameters("{\"che.audio.noise_suppression\": $val}");

      print("[Agora] Noise Reduction applied: $state");
    } catch (e) {
      print("[Agora] Error applying noise reduction: $e");
    }
  }

  void toggleEyeCare() async {
    _eyeCareEnabled = !_eyeCareEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('eye_care_enabled', _eyeCareEnabled);
    } catch (e) {
      print("[EyeCare] Error saving preference: $e");
    }
    notifyListeners();
  }

  dart_async.Future<void> lockRoom(String roomId, String password) async {
    final uid = currentUserId;
    if (uid == null) throw 'المستخدم غير متصل';

    final result = await _db.runTransaction<Map<String, dynamic>>((
      transaction,
    ) async {
      final userRef = _db.collection('users').doc(uid);
      final roomRef = _db.collection('rooms').doc(roomId);

      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        return {'success': false, 'error': 'المستخدم غير موجود'};
      }

      final int diamonds = userSnapshot.get('diamonds') ?? 0;
      if (diamonds < 150) {
        return {
          'success': false,
          'error': 'رصيدك من الماس غير كافٍ لقفل الغرفة (المطلوب 150 ماسة)',
        };
      }

      // 1. خصم الماس
      transaction.update(userRef, {'diamonds': FieldValue.increment(-150)});

      // 2. قفل الغرفة
      transaction.update(roomRef, {
        'isLocked': true,
        'password': password,
        'lockExpiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 1)),
        ),
      });

      // 3. تسجيل معاملة
      final logRef = _db.collection('room_lock_transactions').doc();
      transaction.set(logRef, {
        'userId': uid,
        'roomId': roomId,
        'amount': 150,
        'timestamp': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 1)),
        ),
      });

      return {'success': true};
    });

    if (result['success'] == false) {
      throw result['error'];
    }
    notifyListeners();
  }

  dart_async.Future<void> reportRoom(String roomId, String reason) async {
    final reporterId = currentUserId;
    if (reporterId == null) throw 'المستخدم غير متصل';

    // Get room data for context
    final roomSnap = await _db.collection('rooms').doc(roomId).get();
    if (!roomSnap.exists) throw 'الغرفة غير موجودة';

    final roomData = roomSnap.data()!;
    final hostId = roomData['hostId'];
    final roomName = roomData['name'];

    // Fetch names for visualization
    final reporter = await UserService().getUser(reporterId);
    final owner = await UserService().getUser(hostId);

    await _db.collection('room_reports').add({
      'type': 'room',
      'roomId': roomId,
      'roomName': roomName,
      'reportedUserId': hostId,
      'reporterUserId': reporterId,
      'reporterName': reporter?.nickname ?? reporter?.username ?? 'مبلغ مجهول',
      'targetName': owner?.nickname ?? owner?.username ?? 'هدف مجهول',
      'reason': reason,
      'status': 'pending', // pending, reviewed, resolved
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  dart_async.Future<void> pinRoomToTop(String roomId) async {
    final uid = currentUserId;
    if (uid == null) throw 'المستخدم غير متصل';

    final result = await _db.runTransaction<Map<String, dynamic>>((
      transaction,
    ) async {
      final userRef = _db.collection('users').doc(uid);
      final roomRef = _db.collection('rooms').doc(roomId);

      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        return {'success': false, 'error': 'المستخدم غير موجود'};
      }

      final int diamonds = userSnapshot.get('diamonds') ?? 0;
      if (diamonds < 5000) {
        return {
          'success': false,
          'error': 'رصيدك من الماس غير كافٍ لتثبيت الغرفة (المطلوب 5000 ماسة)',
        };
      }

      // 1. خصم الماس
      transaction.update(userRef, {'diamonds': FieldValue.increment(-5000)});

      // 2. تثبيت الغرفة
      transaction.update(roomRef, {
        'isPinned': true,
        'pinExpiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 1)),
        ),
      });

      // 3. تسجيل معاملة
      final logRef = _db.collection('room_pin_transactions').doc();
      transaction.set(logRef, {
        'userId': uid,
        'roomId': roomId,
        'amount': 5000,
        'timestamp': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 1)),
        ),
      });

      return {'success': true};
    });

    if (result['success'] == false) {
      throw result['error'];
    }
    notifyListeners();
  }

  Stream<List<Map<String, dynamic>>> getRoomsStream() {
    final myId = currentUserId;
    return _db
        .collection('rooms')
        .where('hostId', isNotEqualTo: myId)
        .orderBy('hostId')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final rooms = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).where((data) => data['isPaused'] != true).toList();
          _cachedRooms = rooms;
          return rooms;
        });
  }

  Stream<List<Map<String, dynamic>>> getPopularRoomsStream() {
    final controller = StreamController<List<Map<String, dynamic>>>();
    Map<String, Map<String, dynamic>> pinnedRooms = {};
    Map<String, Map<String, dynamic>> popularRooms = {};

    void emitCombined() {
      if (controller.isClosed) return;
      final Map<String, Map<String, dynamic>> combined = {};
      final now = DateTime.now();

      // Priority 1: Pinned Rooms
      pinnedRooms.forEach((id, data) {
        bool isActive = true;
        if (data['isPaused'] == true) isActive = false;
        if (data['pinExpiresAt'] != null) {
          final expiry = (data['pinExpiresAt'] as Timestamp).toDate();
          if (now.isAfter(expiry)) isActive = false;
        }
        if (isActive) combined[id] = data;
      });

      // Priority 2: Popular Rooms (don't overwrite active pins)
      popularRooms.forEach((id, data) {
        if (!combined.containsKey(id) && data['isPaused'] != true) combined[id] = data;
      });

      final List<Map<String, dynamic>> list = combined.values.toList();

      // Multi-tier sorting: Pinned > Wealth > ViewerCount
      list.sort((a, b) {
        bool aIsPinned = a['isPinned'] == true;
        bool bIsPinned = b['isPinned'] == true;
        if (aIsPinned && !bIsPinned) return -1;
        if (!aIsPinned && bIsPinned) return 1;

        final aWealth = a['wealth'] ?? 0;
        final bWealth = b['wealth'] ?? 0;
        if (aWealth != bWealth)
          return (bWealth as num).compareTo(aWealth as num);

        final aViewers = a['viewerCount'] ?? 0;
        final bViewers = b['viewerCount'] ?? 0;
        return (bViewers as num).compareTo(aViewers as num);
      });

      _cachedPopularRooms = list;
      controller.add(list);
    }

    final sub1 = _db
        .collection('rooms')
        .where('isPinned', isEqualTo: true)
        .snapshots()
        .listen((snap) {
          pinnedRooms = {
            for (var doc in snap.docs) doc.id: {...doc.data(), 'id': doc.id},
          };
          emitCombined();
        });

    final sub2 = _db
        .collection('rooms')
        .orderBy('viewerCount', descending: true)
        .limit(100)
        .snapshots()
        .listen((snap) {
          popularRooms = {
            for (var doc in snap.docs) doc.id: {...doc.data(), 'id': doc.id},
          };
          emitCombined();
        });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Stream<List<Map<String, dynamic>>> getMostInteractingRoomsStream() {
    return _db
        .collection('rooms')
        .orderBy('viewerCount', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final rooms = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).where((data) => data['isPaused'] != true).toList();
          return rooms;
        });
  }

  Stream<List<Map<String, dynamic>>> getMostGiftedRoomsStream() {
    return _db
        .collection('rooms')
        .orderBy('wealth', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final rooms = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).where((data) => data['isPaused'] != true).toList();
          return rooms;
        });
  }

  Stream<List<Map<String, dynamic>>> getPinnedRoomsStream() {
    final now = DateTime.now();
    return _db
        .collection('rooms')
        .where('isPinned', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final rooms = snapshot.docs
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              })
              .where((room) {
                if (room['isPaused'] == true) return false;
                if (room['pinExpiresAt'] == null) return true;
                final expiry = (room['pinExpiresAt'] as Timestamp).toDate();
                return !now.isAfter(expiry);
              })
              .toList();

          rooms.sort((a, b) {
            final aExp =
                (a['pinExpiresAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final bExp =
                (b['pinExpiresAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return bExp.compareTo(aExp);
          });

          return rooms;
        });
  }

  Stream<List<Map<String, dynamic>>> getDiscoveryRoomsStream() {
    return _db
        .collection('rooms')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final rooms = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).where((data) => data['isPaused'] != true).toList();
          _cachedDiscoveryRooms = rooms;
          return rooms;
        });
  }

  // --- Follow/Join Logic ---

  Stream<List<Map<String, dynamic>>> getJoinedRoomsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('joined_rooms')
        .orderBy('joinedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> rooms = [];
          for (var doc in snapshot.docs) {
            final roomId = doc.id;
            final roomDoc = await _db.collection('rooms').doc(roomId).get();
            if (roomDoc.exists) {
              final data = roomDoc.data()!;
              if (data['isPaused'] != true) {
                data['id'] = roomDoc.id;
                rooms.add(data);
              }
            }
          }
          return rooms;
        });
  }

  Stream<List<Map<String, dynamic>>> getFollowedRoomsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db.collection('users').doc(user.uid).snapshots().asyncMap((
      userDoc,
    ) async {
      if (!userDoc.exists) return [];
      final data = userDoc.data() ?? {};
      final followedRoomIds = List<String>.from(data['followedRooms'] ?? []);

      if (followedRoomIds.isEmpty) return [];

      // Get joined rooms to filter them out
      final joinedSnap = await _db
          .collection('users')
          .doc(user.uid)
          .collection('joined_rooms')
          .get();
      final joinedIds = joinedSnap.docs.map((d) => d.id).toSet();

      final Set<String> targetRoomIds = {};

      // 1. Add explicitly followed rooms only
      targetRoomIds.addAll(followedRoomIds);

      // Filter out joined rooms (as requested: "وليس منضم لها")
      targetRoomIds.removeWhere((id) => joinedIds.contains(id));

      if (targetRoomIds.isEmpty) return [];

      // Fetch room details for all target IDs
      final List<Map<String, dynamic>> rooms = [];
      final listIds = targetRoomIds.toList();
      for (var i = 0; i < listIds.length; i += 30) {
        final chunk = listIds.sublist(
          i,
          (i + 30 < listIds.length) ? i + 30 : listIds.length,
        );
        final snap = await _db
            .collection('rooms')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (var doc in snap.docs) {
          final rData = doc.data();
          if (rData['isPaused'] == true) continue;
          rData['id'] = doc.id;
          rooms.add(rData);
        }
      }

      return rooms;
    });
  }

  Stream<List<Map<String, dynamic>>> getFriendRecommendedRoomsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db.collection('users').doc(user.uid).snapshots().asyncMap((
      userDoc,
    ) async {
      try {
        if (!userDoc.exists) return [];
        final data = userDoc.data() ?? {};
        final following = List<String>.from(data['following'] ?? []);
        final followers = List<String>.from(data['followers'] ?? []);

        final friendIds = following
            .where((id) => followers.contains(id))
            .toList();
            
        friendIds.add(user.uid);

        if (friendIds.isEmpty) {
           return [];
        }

        final List<Map<String, dynamic>> rooms = [];
        final Set<String> processedRoomIds = {};

        if (friendIds.isNotEmpty) {
          for (var i = 0; i < friendIds.length; i += 30) {
            final chunk = friendIds.sublist(
              i,
              (i + 30 < friendIds.length) ? i + 30 : friendIds.length,
            );

            final recSnap = await _db
                .collection('room_recommendations')
                .where('recommenderId', whereIn: chunk)
                .limit(50)
                .get();

            for (var doc in recSnap.docs) {
              final recData = doc.data();
              
              final timestamp = recData['timestamp'] as Timestamp?;
              if (timestamp == null) continue;
              if (DateTime.now().difference(timestamp.toDate()).inHours >= 1) {
                continue;
              }

              final roomId = recData['roomId'];
              if (processedRoomIds.contains(roomId)) continue;

              final roomDoc = await _db.collection('rooms').doc(roomId).get();
              if (roomDoc.exists) {
                final rData = roomDoc.data()!;
                if (rData['isPaused'] == true) continue;
                rData['id'] = roomDoc.id;
                rData['recommendedBy'] = recData['recommenderName'] ?? 'صديق';
                rData['recommendationTimestamp'] = recData['timestamp'];
                rooms.add(rData);
                processedRoomIds.add(roomId);
              }
            }
          }
        }

        // Sort in memory: Pinned first, then by recommendation time or activity
        rooms.sort((a, b) {
          // 1. Pinned rooms first
          final aPinned = a['isPinned'] == true;
          final bPinned = b['isPinned'] == true;
          if (aPinned != bPinned) return aPinned ? -1 : 1;

          // 2. By timestamp (if exists)
          final aTime = a['recommendationTimestamp'] as Timestamp?;
          final bTime = b['recommendationTimestamp'] as Timestamp?;
          if (aTime != null && bTime != null) {
            return bTime.compareTo(aTime);
          }
          if (aTime != null) return -1;
          if (bTime != null) return 1;

          return 0;
        });

        return rooms;
      } catch (e) {
        print("Error in getFriendRecommendedRoomsStream: $e");
        return [];
      }
    });
  }

  dart_async.Future<void> recommendRoomToFriends(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) throw 'يجب تسجيل الدخول';

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final recommenderName =
        userData['nickname'] ?? userData['username'] ?? 'صديق';

    final recId = '${user.uid}_$roomId';
    await _db.collection('room_recommendations').doc(recId).set({
      'roomId': roomId,
      'recommenderId': user.uid,
      'recommenderName': recommenderName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getRecentlyEnteredRoomsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('recent_rooms')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> rooms = [];
          for (var doc in snapshot.docs) {
            final roomId = doc.id;
            final roomDoc = await _db.collection('rooms').doc(roomId).get();
            if (roomDoc.exists) {
              final data = roomDoc.data()!;
              if (data['isPaused'] == true) continue;
              data['id'] = roomDoc.id;
              rooms.add(data);
            }
          }
          return rooms;
        });
  }

  dart_async.Future<void> removeRecentRoom(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('recent_rooms')
        .doc(roomId)
        .delete();
  }

  Stream<Map<String, dynamic>?> getMyRoomStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _db
        .collection('rooms')
        .where('hostId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            Map<String, dynamic>? firstRoom;
            for (var doc in snapshot.docs) {
              final data = doc.data();
              if (data['isPaused'] == true) continue;
              
              if (data['isAdminRoom'] != true) {
                data['id'] = doc.id;
                _cachedMyRoom = data;
                return data;
              }
              if (firstRoom == null) {
                firstRoom = data;
                firstRoom['id'] = doc.id;
              }
            }
            // Fallback if user only has a support room (edge case)
            if (firstRoom != null) {
               _cachedMyRoom = firstRoom;
               return firstRoom;
            }
          }
          _cachedMyRoom = null;
          return null;
        });
  }

  Stream<Map<String, dynamic>?> getUserRoomStream(String userId) {
    return _db
        .collection('rooms')
        .where('hostId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            Map<String, dynamic>? firstRoom;
            for (var doc in snapshot.docs) {
              final data = doc.data();
              if (data['isPaused'] == true) continue;
              
              if (data['isAdminRoom'] != true) {
                data['id'] = doc.id;
                return data;
              }
              if (firstRoom == null) {
                firstRoom = data;
                firstRoom['id'] = doc.id;
              }
            }
            return firstRoom;
          }
          return null;
        });
  }


  dart_async.Future<String> createRoom({
    required String name,
    String? imageUrl,
    String? logoText,
    String? description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    // Fetch owner details for faster dashboard/listing display
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final ownerName =
        (userData?['nickname'] ?? userData?['username'] ?? 'مستخدم').toString();
    final ownerDisplayIdStr =
        (userData?['displayId'] ?? user.uid.substring(0, 8)).toString();
    final dynamic ownerDisplayId =
        int.tryParse(ownerDisplayIdStr) ?? ownerDisplayIdStr;

    final roomRef = await _db.collection('rooms').add({
      'name': name,
      'imageUrl': imageUrl,
      'logoText': logoText,
      'description': description,
      'announcement': description,
      'hostId': user.uid, // Existing field
      'ownerId': user.uid, // Redundant but good for multi-system compatibility
      'ownerName': ownerName,
      'ownerDisplayId': ownerDisplayId,
      'createdAt': FieldValue.serverTimestamp(),
      'roomLevel': 1,
      'roomXP': 0.0,
      'roomTier': 0, // Initial tier
      'isBoosted': false,
      'seats': List.generate(
        10,
        (index) => null,
      ), // Initial 10 chairs for PK compatibility
      'users': {},
    });

    return roomRef.id;
  }

  dart_async.Future<void> updateRoomSettings({
    String? name,
    String? imageUrl,
    String? logoText,
    String? cardFrameImage,
    String? announcement,
    String? micMode,
    String? chatMode,
    int? entranceFee,
    bool? autoClearInactive,
    bool? adminCanModifyRoom,
    bool? adminCanManageSeats,
    bool? adminCanInviteUsers,
    bool? adminCanControlGames,
    String? customEntryMessage,
    String? seatColor,
    String? notice,
    String? noticeTitle,
  }) async {
    if (_roomId == null) return;
    if (!await _isOwner()) throw Exception("ليس لديك صلاحية المالك");

    Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (imageUrl != null) updates['imageUrl'] = imageUrl;
    if (logoText != null) updates['logoText'] = logoText;
    if (cardFrameImage != null) updates['cardFrameImage'] = cardFrameImage;
    if (announcement != null) updates['announcement'] = announcement;
    if (micMode != null) updates['micMode'] = micMode;
    if (chatMode != null) updates['chatMode'] = chatMode;
    if (entranceFee != null) updates['entranceFee'] = entranceFee;
    if (notice != null) updates['notice'] = notice;
    if (noticeTitle != null) updates['noticeTitle'] = noticeTitle;
    if (autoClearInactive != null)
      updates['autoClearInactive'] = autoClearInactive;
    if (adminCanModifyRoom != null)
      updates['adminCanModifyRoom'] = adminCanModifyRoom;
    if (adminCanManageSeats != null)
      updates['adminCanManageSeats'] = adminCanManageSeats;
    if (adminCanInviteUsers != null)
      updates['adminCanInviteUsers'] = adminCanInviteUsers;
    if (adminCanControlGames != null)
      updates['adminCanControlGames'] = adminCanControlGames;
    if (customEntryMessage != null)
      updates['customEntryMessage'] = customEntryMessage;
    if (seatColor != null)
      updates['seatColor'] = seatColor == 'clear' ? null : seatColor;

    if (updates.isNotEmpty) {
      await _db.collection('rooms').doc(_roomId).update(updates);
    }
  }

  dart_async.Future<void> startChallenge(int durationMinutes) async {
    if (_roomId == null) return;
    final int durationMs = durationMinutes * 60 * 1000;

    await _db.collection('rooms').doc(_roomId).update({
      'challenge': {
        'isActive': true,
        'durationMs': durationMs,
        'startTime': FieldValue.serverTimestamp(),
        'points': {}, // Map of userId: points
      },
    });
  }

  dart_async.Future<void> stopChallenge() async {
    if (_roomId == null) return;
    await _db.collection('rooms').doc(_roomId).update({
      'challenge.isActive': false,
    });
  }

  dart_async.Future<void> startPKMatch(
    int durationMinutes, {
    String mode = "2v2",
  }) async {
    if (_roomId == null) return;
    final int durationMs = durationMinutes * 60 * 1000;

    await _db.collection('rooms').doc(_roomId).update({
      'pkMatch': {
        'isActive': true,
        'durationMs': durationMs,
        'mode': mode,
        'startTime': FieldValue.serverTimestamp(),
        'points': {}, // Map of userId: points
      },
    });
  }

  dart_async.Future<void> stopPKMatch() async {
    if (_roomId == null) return;
    await _db.collection('rooms').doc(_roomId).update({
      'pkMatch.isActive': false,
    });
  }

  dart_async.Future<void> upgradeRoomTier() async {
    final uid = currentUserId;
    if (uid == null) throw Exception('المستخدم غير متصل');
    if (_roomId == null) throw Exception('الغرفة غير محددة');
    final roomIdSnapshot = _roomId!;

    // --- Phase 1: Read & Validate OUTSIDE the transaction ---
    final userDoc = await _db.collection('users').doc(uid).get();
    final roomDoc = await _db.collection('rooms').doc(roomIdSnapshot).get();

    if (!userDoc.exists) throw Exception('المستخدم غير موجود');
    if (!roomDoc.exists) throw Exception('الغرفة غير موجودة');

    final int currentTierLevel = (roomDoc.data()?['roomTier'] ?? 0) as int;

    if (currentTierLevel >= RoomTierSystem.tiers.length - 1) {
      throw Exception('وصلت الغرفة إلى أقصى ترقية');
    }

    final nextTier = RoomTierSystem.getTier(currentTierLevel + 1);
    final int userMeto = (userDoc.get('meto_chips') ?? 0) as int;

    if (userMeto < nextTier.cost) {
      throw Exception(
        'رصيدك من عملات ميتو غير كافٍ (المطلوب ${nextTier.cost})',
      );
    }

    // --- Phase 2: Clean Transaction — writes only ---
    await _db.runTransaction((transaction) async {
      final userRef = _db.collection('users').doc(uid);
      final roomRef = _db.collection('rooms').doc(roomIdSnapshot);

      // Re-read inside transaction for consistency
      final freshUser = await transaction.get(userRef);
      final freshRoom = await transaction.get(roomRef);

      final int freshMeto = (freshUser.data()?['meto_chips'] ?? 0) as int;
      final int freshTier = (freshRoom.data()?['roomTier'] ?? 0) as int;

      // Guard against race conditions — abort by returning without writes
      if (freshMeto < nextTier.cost) return;
      if (freshTier != currentTierLevel) return;

      // Deduct Meto
      transaction.update(userRef, {
        'meto_chips': FieldValue.increment(-nextTier.cost),
      });

      // Upgrade Room tier
      transaction.update(roomRef, {'roomTier': nextTier.level});

      // Log upgrade
      final logRef = _db.collection('room_upgrade_transactions').doc();
      transaction.set(logRef, {
        'userId': uid,
        'roomId': roomIdSnapshot,
        'fromTier': currentTierLevel,
        'toTier': nextTier.level,
        'cost': nextTier.cost,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    // --- Phase 3: Send system message OUTSIDE transaction (subcollection) ---
    await _db
        .collection('rooms')
        .doc(roomIdSnapshot)
        .collection('messages')
        .add({
          'type': 'alert',
          'text': 'تمت ترقية الغرفة إلى ${nextTier.title} 🎉',
          'timestamp': FieldValue.serverTimestamp(),
        });

    notifyListeners();
  }

  dart_async.Future<void> boostRoomSeats() async {
    final uid = currentUserId;
    if (uid == null) throw Exception('المستخدم غير متصل');
    if (_roomId == null) throw Exception('الغرفة غير محددة');
    final roomIdSnapshot = _roomId!;

    // --- Phase 1: Read & Validate OUTSIDE the transaction ---
    final userDoc = await _db.collection('users').doc(uid).get();
    final roomDoc = await _db.collection('rooms').doc(roomIdSnapshot).get();

    if (!userDoc.exists) throw Exception('المستخدم غير موجود');
    if (!roomDoc.exists) throw Exception('الغرفة غير موجودة');

    final bool isBoosted = roomDoc.data()?['isBoosted'] == true;
    if (isBoosted) {
      throw Exception('الكراسي مفتوحة بالفعل');
    }

    final int cost = 60000;
    final int userMeto = (freshInt(userDoc.data()?['meto_chips']) ?? 0);

    if (userMeto < cost) {
      throw Exception(
        'رصيدك من عملات ميتو غير كافٍ لفتح الكراسي (المطلوب $cost)',
      );
    }

    // --- Phase 2: Clean Transaction — writes only ---
    await _db.runTransaction((transaction) async {
      final userRef = _db.collection('users').doc(uid);
      final roomRef = _db.collection('rooms').doc(roomIdSnapshot);

      // Re-read inside transaction for consistency
      final freshUser = await transaction.get(userRef);
      final freshRoom = await transaction.get(roomRef);

      final int freshMeto = (freshInt(freshUser.data()?['meto_chips']) ?? 0);
      final bool freshBoosted = freshRoom.data()?['isBoosted'] == true;

      // Guard against race conditions — abort by returning without writes
      if (freshMeto < cost) return;
      if (freshBoosted) return;

      // Deduct Meto
      transaction.update(userRef, {'meto_chips': FieldValue.increment(-cost)});

      // Unlock seats
      transaction.update(roomRef, {'isBoosted': true});

      // Log boost
      final logRef = _db.collection('room_boost_transactions').doc();
      transaction.set(logRef, {
        'userId': uid,
        'roomId': roomIdSnapshot,
        'cost': cost,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });

    // --- Phase 3: Send system message ---
    await _db
        .collection('rooms')
        .doc(roomIdSnapshot)
        .collection('messages')
        .add({
          'type': 'alert',
          'text': 'تم فتح قفل الكراسي الدائم للغرفة 🎉',
          'timestamp': FieldValue.serverTimestamp(),
        });

    notifyListeners();
  }

  // Utility to handle int parsing safely
  int? freshInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  dart_async.Future<void> recordChallengePoints(
    String receiverId,
    int points,
  ) async {
    if (_roomId == null) return;
    final roomDoc = await _db.collection('rooms').doc(_roomId).get();
    final challenge = roomDoc.data()?['challenge'] as Map<String, dynamic>?;

    if (challenge != null && challenge['isActive'] == true) {
      // Check if player is on a seat
      bool isOnSeat = _seats.any((s) => s != null && s['userId'] == receiverId);
      if (!isOnSeat) return;

      await _db.collection('rooms').doc(_roomId).update({
        'challenge.points.$receiverId': FieldValue.increment(points),
      });
    }
  }

  dart_async.Future<void> updateRoomTimer(
    Map<String, dynamic>? timerData,
  ) async {
    if (_roomId == null) return;
    await _db.collection('rooms').doc(_roomId).update({'timer': timerData});
  }

  dart_async.Future<String?> uploadRoomImage(File file) async {
    if (_roomId == null) return null;
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final storageRef = _storage
          .ref()
          .child('profiles')
          .child(uid)
          .child('room_$_roomId.jpg');
      final uploadTask = await storageRef.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update the room settings with the new image URL
      await updateRoomSettings(imageUrl: downloadUrl);

      return downloadUrl;
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
  }

  int getUserVolume(String? userId) {
    if (userId == null) return 0;
    if (isUserMuted(userId)) return 0;

    final seat = _seats.firstWhere(
      (s) => s?['userId'] == userId,
      orElse: () => null,
    );
    if (seat?['muted'] == true) return 0;

    // Local user special path
    if (userId == currentUserId) {
      if (_isMuted) return 0;
      final int localUid = getAgoraUid(currentUserId);
      return _userVolumeLevels[localUid] ?? _userVolumeLevels[0] ?? 0;
    }

    final int deterministicUid = getAgoraUid(userId);
    final int? mappedUid = _userIdToAgoraUid[userId];

    int vol = _userVolumeLevels[deterministicUid] ?? 0;
    if (mappedUid != null && mappedUid != deterministicUid) {
      int mappedVol = _userVolumeLevels[mappedUid] ?? 0;
      if (mappedVol > vol) vol = mappedVol;
    }
    return vol;
  }

  bool isUserTalking(String? userId) {
    if (userId == null) return false;

    final now = DateTime.now();

    // 1. Resolve identifiers
    final int deterministicUid = getAgoraUid(userId);
    final int? mappedUid = _userIdToAgoraUid[userId];

    // 2. Local User Special Path
    if (userId == currentUserId) {
      if (_isMuted) return false; // Don't show talking if locally muted
      if (_activeSpeakers.contains(0)) return true;
      if (_talkingHoldMap.containsKey(0)) {
        if (now.difference(_talkingHoldMap[0]!).inMilliseconds < 800)
          return true;
      }
    }

    // 3. Mute Priority (Global and Seat-specific)
    if (isUserMuted(userId)) return false;
    final seat = _seats.firstWhere(
      (s) => s?['userId'] == userId,
      orElse: () => null,
    );
    if (seat?['muted'] == true) return false;

    // 4. Remote Identification Check
    bool isCurrentlyActive = _activeSpeakers.contains(deterministicUid);
    if (!isCurrentlyActive && mappedUid != null) {
      isCurrentlyActive = _activeSpeakers.contains(mappedUid);
    }

    if (isCurrentlyActive) return true;

    // 5. Persistence (0.8s Hold - reduced from 3s for better responsiveness)
    const int holdMs = 800;
    if (_talkingHoldMap.containsKey(deterministicUid)) {
      if (now.difference(_talkingHoldMap[deterministicUid]!).inMilliseconds <
          holdMs)
        return true;
    }
    if (mappedUid != null && _talkingHoldMap.containsKey(mappedUid)) {
      if (now.difference(_talkingHoldMap[mappedUid]!).inMilliseconds < holdMs)
        return true;
    }

    return false;
  }

  bool get isMeSeated {
    final myId = _auth.currentUser?.uid;
    return _seats.any((s) => s != null && s['userId'] == myId);
  }

  StreamSubscription? _roomSubscription;
  StreamSubscription? _messagesSubscription;
  StreamSubscription<DocumentSnapshot>? _globalMicSubscription;

  dart_async.Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    try {
      print("[Agora] Initializing permissions...");
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.bluetoothConnect,
      ].request();

      print(
        "[Agora] Microphone Permission: ${statuses[Permission.microphone]}",
      );
      print(
        "[Agora] Bluetooth Permission: ${statuses[Permission.bluetoothConnect]}",
      );

      // Create Agora Engine
      print("[Agora] Creating RtcEngine...");
      _engine = createAgoraRtcEngineEx();
      await _engine.initialize(
        const RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      // Optimized for Stability
      _registerEventHandlers();

      // Optimized for Ultra-Low Latency Voice & High Quality
      print("[Agora] Setting Audio Profile: Low Latency Optimized...");
      await _engine.setAudioProfile(
        profile: AudioProfileType
            .audioProfileDefault, // Default is best for low-latency voice
        scenario: AudioScenarioType
            .audioScenarioGameStreaming, // Game streaming has the lowest latency
      );

      // Advanced Low Latency Parameters
      await _engine.setParameters("{\"che.audio.live_for_low_latency\": true}");
      await _engine.setParameters(
        "{\"che.audio.opensl\": true}",
      ); // Hardware acceleration on Android
      await _engine.setParameters("{\"che.audio.specify.codec\": \"OPUS\"}");

      // Enable Volume Indication
      await _engine.enableAudioVolumeIndication(
        interval: 200, // Slightly faster reporting
        smooth: 4, // More smoothing to prevent flicker
        reportVad: true,
      );
      await _engine.enableAudio();
      // Default to publishing if we started unmuted (Ludo Policy)
      await _engine.enableLocalAudio(true);
      await _engine.muteLocalAudioStream(_isMuted);

      // Force audio to speakerphone by default (Encapsulated to prevent crash on non-compatible platforms)
      try {
        await _engine.setEnableSpeakerphone(true);
        await _engine.setDefaultAudioRouteToSpeakerphone(true);
      } catch (e) {
        print(
          "[Agora] Skipping speakerphone routing: Not supported on this device.",
        );
      }

      await _engine.adjustRecordingSignalVolume(100);
      await _engine.adjustPlaybackSignalVolume(100);

      _startSpeakerCleanupTimer();

      // Load and apply Noise Reduction preference
      try {
        final prefs = await SharedPreferences.getInstance();
        _noiseReductionEnabled =
            prefs.getBool('noise_reduction_enabled') ?? false;
        if (_noiseReductionEnabled) {
          await _applyNoiseReduction();
        }

        _eyeCareEnabled = prefs.getBool('eye_care_enabled') ?? false;
      } catch (e) {
        print("[NoiseReduction] Error loading preference: $e");
      }

      _isInitialized = true;
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
      _initCompleter = null; // Clear after success
      print('[Agora] Engine initialized successfully');

      _globalMicSubscription?.cancel();
      _globalMicSubscription = _db
          .collection('app_settings')
          .doc('global')
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data();
              _isGlobalMicEnabled = data?['isGlobalMicEnabled'] ?? true;

              if (!_isGlobalMicEnabled) {
                print(
                  "[Global Mic Lock] Forcibly muting local mic and locking seats.",
                );
                if (!_isMuted) {
                  setMute(
                    true,
                  ).catchError((e) => print("Force mute error: $e"));
                }
                if (isMeSeated) {
                  leaveSeat().catchError(
                    (e) => print("Force leave seat error: $e"),
                  );
                }
              }
              notifyListeners();
            }
          });

      notifyListeners();
    } catch (e) {
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.completeError(e);
      }
      _initCompleter = null; // Clear after error
      print("[Agora] Initialization Error: $e");
      rethrow;
    }
  }

  void _registerEventHandlers() {
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
          final int localUid = connection.localUid ?? 0;
          print(
            "[Agora] Joined Channel Successfully. Local Uid: $localUid, Room: $_roomId",
          );
          _isJoined = true;

          if (_pendingRole != null) {
            print(
              "[Agora] Applying pending role on join success: ${_pendingRole!.name}",
            );
            await setRole(_pendingRole!);
            _pendingRole = null;
          } else {
            print("[Agora] No pending role to apply on join success.");
          }

          // Enforce speakerphone routing on join to fix first-time audio absence
          try {
            await _engine.setDefaultAudioRouteToSpeakerphone(true);
            await _engine.setEnableSpeakerphone(true);
          } catch (e) {
            print("[Agora] Speakerphone enforcement error on join: $e");
          }

          // Force sync deterministic UID immediately on join
          if (_roomId != null && currentUserId != null) {
            final int deterministicUid = getAgoraUid(currentUserId);
            _db
                .collection('rooms')
                .doc(_roomId)
                .update({'users.$currentUserId.agoraUid': deterministicUid})
                .catchError((e) => print("Join Sync UID error: $e"));

            _userIdToAgoraUid[currentUserId!] = deterministicUid;
          }

          notifyListeners();
          if (isMeSeated) setRole(ClientRoleType.clientRoleBroadcaster);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          _remoteUsers.add(remoteUid);
          notifyListeners();
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              print("Remote user $remoteUid went offline ($reason)");
              _remoteUsers.remove(remoteUid);
              _activeSpeakers.remove(remoteUid);
              notifyListeners();
            },
        onAudioVolumeIndication:
            (
              RtcConnection connection,
              List<AudioVolumeInfo> speakers,
              int speakerNumber,
              int totalVolume,
            ) {
              final now = DateTime.now();

              // Reset previous levels so silent users drop to 0
              _userVolumeLevels.clear();

              for (var speaker in speakers) {
                final int uid = speaker.uid ?? 0;
                final int volume = speaker.volume ?? 0;
                final int effectiveUid = (uid == 0 && currentUserId != null)
                    ? getAgoraUid(currentUserId)
                    : uid;

                _userVolumeLevels[effectiveUid] = volume;
                if (uid == 0) {
                  _userVolumeLevels[0] = volume;
                }

                if (volume > 15) {
                  // Increased threshold from 3 to 15 to filter out room noise
                  _talkingHoldMap[effectiveUid] = now;

                  // Immediate Notification for NEW speakers only
                  if (!_activeSpeakers.contains(effectiveUid)) {
                    _activeSpeakers.add(effectiveUid);
                  }
                }
              }

              // Always notify listeners so volume meter UI updates immediately
              notifyListeners();
            },
        onAudioMixingStateChanged:
            (AudioMixingStateType state, AudioMixingReasonType reason) {
              print("Audio Mixing State Changed: $state, Reason: $reason");
              if (state == AudioMixingStateType.audioMixingStateStopped) {
                _isMusicPlaying = false;
                _isMusicPaused = false;
                _musicPosition = 0;
                _musicProgressTimer?.cancel();
                notifyListeners();
                _syncMusicState(false);
                // Local Studio Mode: No global sync needed
              } else if (state ==
                  AudioMixingStateType.audioMixingStatePlaying) {
                _isMusicPlaying = true;
                _isMusicPaused = false;
                notifyListeners();
                _syncMusicState(true);
              } else if (state == AudioMixingStateType.audioMixingStateFailed) {
                _isMusicPlaying = false;
                _isMusicPaused = false;
                _musicProgressTimer?.cancel();
                print("Audio Mixing Failed: $reason");
                notifyListeners();
                _syncMusicState(false);
              }
            },
        onError: (ErrorCodeType err, String msg) {
          print("[Agora] ERROR: $err, Message: $msg");
          if (err == ErrorCodeType.errTokenExpired ||
              err == ErrorCodeType.errInvalidToken) {
            print("[Agora] CRITICAL: Token issue detected.");
          }
        },
        onConnectionStateChanged:
            (
              RtcConnection connection,
              ConnectionStateType state,
              ConnectionChangedReasonType reason,
            ) {
              print("[Agora] Connection State: $state, Reason: $reason");
            },
        onRemoteAudioStateChanged:
            (
              RtcConnection connection,
              int remoteUid,
              RemoteAudioState state,
              RemoteAudioStateReason reason,
              int elapsed,
            ) {
              print(
                "[Agora] Remote Audio State for $remoteUid: $state, Reason: $reason",
              );
            },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          print("[Agora] Left Channel. Stats: ${stats.userCount} users");
        },
        onTokenPrivilegeWillExpire:
            (RtcConnection connection, String token) async {
              print("[Agora] Token will expire soon! Renewing...");
              final String? roomId = _roomId;
              final int? myUid = _userIdToAgoraUid[currentUserId];
              if (roomId != null && myUid != null) {
                final newToken = await _fetchToken(roomId, myUid);
                if (newToken != null) {
                  await _engine.renewToken(newToken);
                  print("[Agora] Token renewed successfully.");
                }
              }
            },
      ),
    );
  }

  Future<String?> _fetchToken(String channelName, int uid) async {
    try {
      // ملاحظة: هذا الرابط يعتمد على هيكلية السيرفر الخاص بك.
      // الهيكلية الشائعة لسكربت Agora Token Server هي: /rtc/:channel/:role/:uid/
      final response = await http.get(
        Uri.parse('$tokenServerUrl/rtc/$channelName/publisher/uid/$uid'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['rtcToken'] ?? data['token'];
      } else {
        print("[Agora] Failed to fetch token: ${response.statusCode}");
      }
    } catch (e) {
      print("[Agora] Error fetching token: $e");
    }
    return null;
  }

  // Join Game Channel (Agora only, using Ex to preserve chat room connection)
  dart_async.Future<void> joinGameChannel(String channelId) async {
    try {
      if (!_isInitialized) {
        await initialize();
      } else {
        await _engine.enableAudio();
      }

      if (_isGameChannel && _gameChannelId == channelId) {
        return; // Already in this game channel
      }

      if (_isGameChannel && _gameChannelId != null) {
        await leaveGameChannel();
      }

      _gameChannelId = channelId;
      _isGameChannel = true;
      _isGameMuted = true; // Default to muted in game

      final int agoraUid = getAgoraUid(currentUserId);
      _userIdToAgoraUid[currentUserId ?? ""] = agoraUid;

      print("[Agora] Joining Game Channel Ex: $channelId as $agoraUid");
      final token = await _fetchToken(channelId.trim(), agoraUid);

      await _engine.joinChannelEx(
        token: token ?? "",
        connection: RtcConnection(
          channelId: channelId.trim(),
          localUid: agoraUid,
        ),
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: false, // Start muted
          autoSubscribeAudio: true,
        ),
      );

      // Force explicitly unmute the overall hardware mic so Ex tracks can work
      await _engine.muteLocalAudioStream(false);
      await _engine.adjustRecordingSignalVolume(100);

      notifyListeners();
      print("[Agora] Successfully joined game channel Ex: $channelId");
    } catch (e) {
      print("[Agora] Error joining game channel Ex: $e");
      _isGameChannel = false;
      _gameChannelId = null;
      notifyListeners();
    }
  }

  // Safely leave game channel Ex.
  dart_async.Future<void> leaveGameChannel() async {
    if (!_isGameChannel || _gameChannelId == null) {
      print("[Agora] Not in a game channel Ex. Ignoring leaveGameChannel.");
      return;
    }
    try {
      final int agoraUid = getAgoraUid(currentUserId);
      await _engine.leaveChannelEx(
        connection: RtcConnection(
          channelId: _gameChannelId!.trim(),
          localUid: agoraUid,
        ),
      );
      print("[Agora] Left Game Channel Ex: $_gameChannelId");
    } catch (e) {
      print("[Agora] Error leaving game channel Ex: $e");
    } finally {
      _isGameChannel = false;
      _gameChannelId = null;
      _isGameMuted = true;
      notifyListeners();
    }
  }

  dart_async.Future<void> setGameMute(bool muted) async {
    if (!_isInitialized || !_isGameChannel || _gameChannelId == null) return;

    _isGameMuted = muted;
    print("[Agora] setGameMute (Ex): ${muted ? 'MUTING' : 'UNMUTING'}");
    notifyListeners();

    try {
      final int agoraUid = getAgoraUid(currentUserId);
      await _engine.updateChannelMediaOptionsEx(
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: !muted,
          autoSubscribeAudio: true,
        ),
        connection: RtcConnection(
          channelId: _gameChannelId!.trim(),
          localUid: agoraUid,
        ),
      );
    } catch (e) {
      print("[Agora] async game mute ops ERROR: $e");
    }
  }

  dart_async.Future<void> toggleGameMute() async {
    await setGameMute(!_isGameMuted);
  }

  // Join Room (Firestore + Agora)
  dart_async.Future<void> joinRoom(
    String roomId, {
    ClientRoleType initialRole = ClientRoleType.clientRoleAudience,
  }) async {
    if (_isJoined && _roomId == roomId) {
      _isMinimized = false;
      notifyListeners();
      return;
    }

    if (_isJoined && _roomId != null) {
      // Always leave and CLEAN UP before joining a new one
      await leaveRoom();
    }

    // Explicit hard reset for safety before starting new join
    // Only reset if we are joining a completely different room (not a seed or re-join)
    if (_roomId != roomId) {
      _roomId = null;
      _currentRoomData = null;
      _micLayoutType = null;
      _seats = List.generate(10, (_) => null);
      notifyListeners();
    }

    try {
      // ── Step 0: Init engine (cannot parallelize) ──
      if (!_isInitialized) {
        await initialize();
      } else {
        await _engine.enableAudio();
      }

      _roomId = roomId;
      _isMinimized = false;
      _isBroadcaster = (initialRole == ClientRoleType.clientRoleBroadcaster);
      _pendingRole = initialRole;

      final String? myId = _auth.currentUser?.uid;
      final roomRef = _db.collection('rooms').doc(roomId);

      // ── Step 1: Fetch room + user profile IN PARALLEL (eliminates 1 round-trip) ──
      final results = await dart_async.Future.wait([
        roomRef.get(),
        _db.collection('users').doc(myId).get(),
      ]);

      final roomSnap = results[0];
      final userDoc = results[1];
      final userData = userDoc.data();

      // ── Step 1.5: Force-remove user from any previous room (cross-session safety) ──
      if (myId != null && userData != null) {
        final String? prevRoomId = userData['currentRoomId'] as String?;
        if (prevRoomId != null && prevRoomId != roomId) {
          // Remove from old room in background (don't block join flow)
          _db
              .collection('rooms')
              .doc(prevRoomId)
              .update({'users.$myId': FieldValue.delete()})
              .catchError(
                (e) => print(
                  '[joinRoom] Could not clean up old room $prevRoomId: $e',
                ),
              );
          // Also clean RTDB presence
          _rtdb
              .ref('rooms/$prevRoomId/presence/$myId')
              .remove()
              .catchError((e) => print('[joinRoom] RTDB cleanup error: $e'));
        }
      }

      // Load profile cache from userDoc (no separate _preloadCurrentUserProfile needed)
      if (myId != null && userData != null) {
        _profileCache[myId] = {
          'name': userData['nickname'] ?? userData['username'] ?? '',
          'avatar': userData['profileImage'],
          'displayId': userData['displayId']?.toString(),
          'displayIdImage': userData['displayIdImage'],
        };
      }

      // ── Step 2: Validate (ban/kick) ──
      if (roomSnap.exists) {
        final data = roomSnap.data();
        if (data != null && myId != null) {
          final bannedUsers = data['bannedUsers'] as Map?;
          if (bannedUsers != null && bannedUsers.containsKey(myId)) {
            throw "تم حظرك من دخول هذه الغرفة";
          }
          final kickedUsers = data['kickedUsers'] as Map?;
          if (kickedUsers != null && kickedUsers.containsKey(myId)) {
            final expiry = kickedUsers[myId];
            if (expiry is int &&
                DateTime.now().millisecondsSinceEpoch < expiry) {
              final remaining = DateTime.fromMillisecondsSinceEpoch(
                expiry,
              ).difference(DateTime.now());
              throw "تم طردك من الغرفة. يمكنك العودة بعد ${remaining.inMinutes} دقيقة";
            }
          }
        }
      } else {
        // Room doesn't exist — throw error instead of auto-creating
        throw "عذراً، هذه الغرفة غير موجودة أو تم حذفها";
      }

      // ── Step 3: Mark joined locally BEFORE writes for instant UI ──
      final now = DateTime.now().toIso8601String();
      final int agoraUid = getAgoraUid(myId);
      final List followedRooms = userData?['followedRooms'] ?? [];
      _isMember = followedRooms.contains(roomId);

      _roomId = roomId;
      _isJoined = true;

      // Apply room metadata instantly from snapshot
      final roomData = roomSnap.data();
      _hostId = roomData?['hostId'] ?? roomData?['ownerId'];
      final Map? admins = roomData?['admins'] as Map?;
      final Map? coOwners = roomData?['coOwners'] as Map?;
      if (admins != null) _admins = Map<String, dynamic>.from(admins);
      if (coOwners != null) _coOwners = Map<String, dynamic>.from(coOwners);
      _micLayoutType = roomData?['micLayoutType'];
      _showAmbientBubbles = roomData?['showAmbientBubbles'] != false;
      _currentRoomData = roomSnap.exists ? roomData : null;

      // ── Step 3.5: INSTANT UI UPDATES BEFORE NETWORK AWAITS ──
      // 1. Manually add current user to UI list so thumbnail appears instantly
      if (myId != null && userData != null) {
        final instantMe = User(
          uid: myId,
          username: userData['nickname'] ?? userData['username'] ?? '',
          email: '',
          createdAt: DateTime.now(),
          profileImage: userData['profileImage'],
          displayId: userData['displayId']?.toString(),
          displayIdImage: userData['displayIdImage'],
        );
        if (!_roomUsers.any((u) => u.uid == myId)) {
          _roomUsers.insert(0, instantMe);
        }
      }

      // 2. Dispatch entry message instantly
      final name = userData?['nickname'] ?? userData?['username'] ?? 'مستخدم';
      final String? hostId = roomData?['hostId'] ?? roomData?['ownerId'];
      final bool amIHost = hostId == currentUserId;

      String welcomeText;
      String messageType = 'system';

      if (amIHost) {
        // Prioritize Host banner
        welcomeText = ' $name';
        messageType = 'host_enter';
      } else if (roomData != null &&
          roomData['customEntryMessage'] != null &&
          roomData['customEntryMessage'].toString().isNotEmpty) {
        // Use custom message for guests/members
        welcomeText = roomData['customEntryMessage'].toString().replaceAll(
          '{name}',
          name,
        );
      } else {
        // Default for everyone else
        welcomeText = '$name دخل الغرفة';
      }

      dart_async.unawaited(
        sendSystemMessage(
          welcomeText,
          type: messageType,
          imageUrl: userData?['profileImage'],
          senderId: currentUserId,
          senderDisplayId: userData?['displayId']?.toString(),
          senderName: name,
          roomEntrance: userData?['roomEntrance'],
        ),
      );

      // Deduplicate before notify
      final Map<String, User> dedupMap = {};
      for (var u in _roomUsers) {
        dedupMap[u.uid] = u;
      }
      _roomUsers = dedupMap.values.toList();
      // Stable alphabetical sorting
      _roomUsers.sort((a, b) {
        final nameA = (a.nickname ?? a.username).toLowerCase();
        final nameB = (b.nickname ?? b.username).toLowerCase();
        return nameA.compareTo(nameB);
      });
      notifyListeners(); // ← الواجهة تُظهر القائمة والصورة والرسالة بشكل صاروخي فوراً

      // ── Step 4: All writes + Agora join IN PARALLEL ──
      final presenceRef = myId != null
          ? _rtdb.ref('rooms/$roomId/presence/$myId')
          : null;

      await dart_async.Future.wait([
        // Write 1: Register user in room
        roomRef.update({
          'users.$myId': {
            'lastSeen': now,
            'agoraUid': agoraUid,
            'joinTime': now,
            'isMember': _isMember,
          },
        }),
        // Write 1b: Set currentRoomId on user doc
        _db.collection('users').doc(myId).update({'currentRoomId': roomId}),
        // Write 2: RTDB presence
        if (presenceRef != null)
          presenceRef.set({'active': true, 'lastSeen': ServerValue.timestamp}),

        // Write 3: Agora join (Fetching token first)
        _fetchToken(roomId.trim(), agoraUid).then((token) {
          return _engine.joinChannel(
            token: token ?? "",
            channelId: roomId.trim(),
            uid: agoraUid,
            options: ChannelMediaOptions(
              clientRoleType: initialRole,
              autoSubscribeAudio: true,
            ),
          );
        }),
      ]);

      // ── Step 5: Post-join setup (non-blocking where possible) ──
      if (presenceRef != null) {
        dart_async.unawaited(presenceRef.onDisconnect().remove());
      }

      if (myId != null) {
        dart_async.unawaited(
          _db.collection('users').doc(myId).update({'currentRoomId': roomId}),
        );
        dart_async.unawaited(
          _db
              .collection('users')
              .doc(myId)
              .collection('recent_rooms')
              .doc(roomId)
              .set({'timestamp': FieldValue.serverTimestamp()}),
        );
      }

      await _engine.enableLocalAudio(
        initialRole == ClientRoleType.clientRoleBroadcaster,
      );

      _joinTimestamp = DateTime.now().millisecondsSinceEpoch;
      _freshJoin =
          true; // Mark as fresh join so first message load clears stale data

      // ── Step 6: Start subscriptions ──
      _subscribeToRoom(roomId);
      _subscribeToMessages(roomId);
      _startPresenceTimers();
      _listenToLikes(roomId);
      _startBackgroundSubscriptions();

      // Membership reactive listener
      _userDocSubscription?.cancel();
      _userDocSubscription = _db.collection('users').doc(myId).snapshots().listen((
        snap,
      ) {
        if (!snap.exists) return;
        final list = snap.data()?['followedRooms'] as List? ?? [];
        final newStatus = list.contains(roomId);
        if (_isMember != newStatus) {
          _isMember = newStatus;
          notifyListeners();

          // Force leave seat if membership is lost and micMode is "Members Only"
          if (!_isMember && _roomId == roomId) {
            final String micMode = _currentRoomData?['micMode'] ?? "الجميع";
            final bool isMeAdmin =
                this.isAdmin(myId!) || this.isCoOwner(myId) || this.isHost;
            if (micMode == "الأعضاء فقط" && !isMeAdmin && isMeSeated) {
              leaveSeat().catchError(
                (e) => print("Force leave seat (Unfollowed): $e"),
              );
            }
          }
        }
      });

      dart_async.unawaited(_checkDailySettlement(roomId));

      notifyListeners();
    } catch (error) {
      print('Error joining room: $error');
      _isJoined = false;
      _roomId = null;
      notifyListeners();
      rethrow;
    }
  }

  void seedRoomData(Map<String, dynamic>? data) {
    if (data != null && (_currentRoomData == null || _roomId == null)) {
      _currentRoomData = data;
      _roomId ??= data['id'] ?? data['roomId'] ?? data['docId'];
      // Pre-update layout and admin toggles if they exist in seeds
      if (data.containsKey('micLayoutType')) {
        _micLayoutType = data['micLayoutType'];
      }
      if (data.containsKey('adminSeatsEnabled')) {
        _adminSeatsEnabled = data['adminSeatsEnabled'] != false;
      }
      if (data.containsKey('adminChatEnabled')) {
        _adminChatEnabled = data['adminChatEnabled'] != false;
      }
      if (data.containsKey('hostId') || data.containsKey('ownerId')) {
        _hostId = data['hostId'] ?? data['ownerId'];
      }
      if (data.containsKey('showAmbientBubbles')) {
        _showAmbientBubbles = data['showAmbientBubbles'] != false;
      }
      if (data.containsKey('admins')) {
        _admins = Map<String, dynamic>.from(data['admins'] as Map);
      }
      if (data.containsKey('coOwners')) {
        _coOwners = Map<String, dynamic>.from(data['coOwners'] as Map);
      }

      // Seed Seats to prevent "blinking" on entry
      if (data.containsKey('seats')) {
        final dynamic rawSeats = data['seats'];
        final bool isPkActive =
            (data['pkMatch']?['isActive'] == true) ||
            (_currentRoomData?['pkMatch']?['isActive'] == true);
        final bool isChallengeActive =
            (data['challenge']?['isActive'] == true) ||
            (_currentRoomData?['challenge']?['isActive'] == true);

        // Determine seat count based on layout, but force 10 if PK/Challenge is active
        int seatCount = 10;
        if (!isPkActive && !isChallengeActive) {
          if (_micLayoutType == 'layout_2')
            seatCount = 2;
          else if (_micLayoutType == 'layout_5')
            seatCount = 5;
        }

        _seats = List.generate(seatCount, (index) {
          dynamic seatRaw;
          if (rawSeats is List) {
            if (index < rawSeats.length) seatRaw = rawSeats[index];
          } else if (rawSeats is Map) {
            seatRaw = rawSeats[index.toString()] ?? rawSeats[index];
          }
          return (seatRaw != null && seatRaw is Map)
              ? Map<String, dynamic>.from(seatRaw)
              : null;
        });
      }

      // Wrap in microtask to avoid 'notifyListeners called during build' errors
      dart_async.Future.microtask(() => notifyListeners());
    }
  }

  List<User> _roomUsers = [];
  List<User> get roomUsers => _roomUsers;
  final Map<int, String> _agoraToFireId =
      {}; // Mapping for instant Agora cleanup

  final Set<String> _rtdbActiveUsers = {};

  void _refreshRoomUsers() {
    if (_roomId == null) return;
    final now = DateTime.now();
    List<User> activeUsers = [];

    _roomUsersMetadata.forEach((uid, meta) {
      bool isRtdbActive = _rtdbActiveUsers.contains(uid);

      // Secondary fallback: Firestore lastSeen (only for very recent heartbeats)
      bool isFirestoreFresh = false;
      if (meta is Map && meta['lastSeen'] != null) {
        final lastSeen = DateTime.tryParse(meta['lastSeen'].toString());
        if (lastSeen != null) {
          // Threshold: 60 seconds (increased from 15s to prevent flickering with 20s heartbeat)
          isFirestoreFresh = now.difference(lastSeen).inSeconds < 60;
        }
      }

      // Final condition: Must be active in RTDB OR very fresh in Firestore
      // EXCEPT if it's 'me' and I know I've lost my connection.
      bool isMe = (uid == currentUserId);
      bool shouldShow = (isRtdbActive || isFirestoreFresh);

      if (isMe && _isNetworkLost) shouldShow = false;

      if (shouldShow) {
        if (_profileCache.containsKey(uid)) {
          final c = _profileCache[uid]!;
          activeUsers.add(
            User(
              uid: uid,
              username: c['name'] ?? '',
              email: '',
              createdAt: DateTime.now(),
              profileImage: c['avatar'],
              displayId: c['displayId']?.toString(),
              displayIdImage: c['displayIdImage'],
            ),
          );
        }
      }
    });

    activeUsers.sort(
      (a, b) => (a.nickname ?? a.username).toLowerCase().compareTo(
        (b.nickname ?? b.username).toLowerCase(),
      ),
    );
    _roomUsers = activeUsers;
    notifyListeners();
  }

  void _subscribeToRoom(String roomId) {
    _roomSubscription?.cancel();
    _roomSubscription = _db.collection('rooms').doc(roomId).snapshots().listen((
      snapshot,
    ) async {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          // 1. Process Users — show from cache instantly, fetch full data in background
          if (data.containsKey('users')) {
            final Map<String, dynamic> rawUsersData =
                data['users'] as Map<String, dynamic>;

            // Populate Agora mapping
            _agoraToFireId.clear();
            _userIdToAgoraUid.clear();
            _roomUsersMetadata = Map<String, dynamic>.from(rawUsersData);
            rawUsersData.forEach((uid, userData) {
              if (userData is Map && userData['agoraUid'] != null) {
                final int aUid = userData['agoraUid'];
                _agoraToFireId[aUid] = uid;
                _userIdToAgoraUid[uid] = aUid;
              }
            });

            _viewerCount = rawUsersData.length;

            final userIds = rawUsersData.keys.toList();

            // ── INSTANT: build _roomUsers from cache so UI updates immediately ──
            if (userIds.isNotEmpty) {
              final cachedUsers = userIds
                  .where((uid) => _profileCache.containsKey(uid))
                  .map((uid) {
                    final c = _profileCache[uid]!;
                    return User(
                      uid: uid,
                      username: c['name'] ?? '',
                      email: '',
                      createdAt: DateTime.now(),
                      profileImage: c['avatar'],
                      displayId: c['displayId']?.toString(),
                      displayIdImage: c['displayIdImage'],
                    );
                  })
                  .toList();
              if (cachedUsers.isNotEmpty) {
                // Stable alphabetical sorting
                cachedUsers.sort((a, b) {
                  final nameA = (a.nickname ?? a.username).toLowerCase();
                  final nameB = (b.nickname ?? b.username).toLowerCase();
                  return nameA.compareTo(nameB);
                });
                _roomUsers = cachedUsers;
                notifyListeners(); // ← عرض فوري من الكاش
              }
            }

            // ── BACKGROUND: fetch full data and update ──
            if (userIds.isNotEmpty) {
              // Priority: unknown users first
              final unknownIds = userIds
                  .where((id) => !_profileCache.containsKey(id))
                  .toList();
              final limitedIds = (unknownIds.length >= 20)
                  ? unknownIds.take(50).toList()
                  : userIds.take(50).toList();
              dart_async.Future(() async {
                try {
                  List<User> fetchedUsers = [];
                  for (var i = 0; i < limitedIds.length; i += 10) {
                    var end = (i + 10 < limitedIds.length)
                        ? i + 10
                        : limitedIds.length;
                    var chunk = limitedIds.sublist(i, end);
                    if (chunk.isNotEmpty) {
                      final qSnapshot = await _db
                          .collection('users')
                          .where(FieldPath.documentId, whereIn: chunk)
                          .get();
                      for (final d in qSnapshot.docs) {
                        // Update profile cache while we have fresh data
                        final pd = d.data();
                        _profileCache[d.id] = {
                          'name': pd['nickname'] ?? pd['username'] ?? '',
                          'avatar': pd['profileImage'],
                          'displayId': pd['displayId']?.toString(),
                          'displayIdImage': pd['displayIdImage'],
                        };
                      }
                      fetchedUsers.addAll(
                        qSnapshot.docs.map((d) => User.fromMap(d.data(), d.id)),
                      );
                    }
                  }
                  if (fetchedUsers.isNotEmpty && _roomId == roomId) {
                    _refreshRoomUsers(); // Update with newly fetched profiles
                  }
                } catch (e) {
                  print('[subscribeToRoom] Background fetch error: $e');
                }
              });
            }
          }

          // 2a. Process activeFrames FIRST so _userFrameCache is fresh
          //     before we build seat data below.
          if (data.containsKey('activeFrames')) {
            final rawFrames = data['activeFrames'] as Map<String, dynamic>;
            final now = DateTime.now().toUtc();
            final Map<String, dynamic> filteredFrames = {};
            final List<String> expiredUserIds = [];

            // Remove from cache any users who were in the old activeFrames but not in the new rawFrames
            _activeFrames.keys.forEach((uid) {
              if (!rawFrames.containsKey(uid)) {
                _userFrameCache.remove(uid);
              }
            });

            rawFrames.forEach((uid, fData) {
              if (fData is Map) {
                final expiryStr = fData['expiry'] as String?;
                if (expiryStr != null) {
                  final expiry = DateTime.parse(expiryStr).toUtc();
                  if (now.isBefore(expiry)) {
                    filteredFrames[uid] = fData;
                    if (fData['type'] != null) {
                      _userFrameCache[uid] = fData['type'] as String;
                    }
                  } else {
                    expiredUserIds.add(uid);
                    _userFrameCache.remove(uid);
                  }
                }
              }
            });

            _activeFrames = filteredFrames;

            // Trigger DB cleanup if there are expired frames
            if (expiredUserIds.isNotEmpty) {
              final roomRef = _db.collection('rooms').doc(roomId);
              final Map<String, dynamic> updates = {};
              for (final uId in expiredUserIds) {
                updates['activeFrames.$uId'] = FieldValue.delete();
              }
              roomRef
                  .update(updates)
                  .catchError(
                    (e) => print("Error cleaning up expired frames: $e"),
                  );
            }
          } else {
            _activeFrames = {};
          }

          // 2b. Process Seats (Lean & Direct)
          // Skip seat update if a local optimistic update is in progress
          if (data.containsKey('seats') && !_isTakingSeat) {
            final dynamic rawSeats = data['seats'];
            _micLayoutType =
                data['micLayoutType']; // Update layout from stream too

            final bool isPkActive =
                (data['pkMatch']?['isActive'] == true) ||
                (_currentRoomData?['pkMatch']?['isActive'] == true);
            final bool isChallengeActive =
                (data['challenge']?['isActive'] == true) ||
                (_currentRoomData?['challenge']?['isActive'] == true);

            // Determine seat count based on layout, but force 10 if PK/Challenge is active
            int seatCount = 10;
            if (!isPkActive && !isChallengeActive) {
              if (_micLayoutType == 'layout_2')
                seatCount = 2;
              else if (_micLayoutType == 'layout_5')
                seatCount = 5;
            }

            _seats = List.generate(seatCount, (index) {
              dynamic seatRaw;
              if (rawSeats is List) {
                if (index < rawSeats.length) seatRaw = rawSeats[index];
              } else if (rawSeats is Map) {
                seatRaw = rawSeats[index.toString()] ?? rawSeats[index];
              }

              if (seatRaw != null && seatRaw is Map) {
                final sData = Map<String, dynamic>.from(seatRaw);
                final String? uid = sData['userId'];

                if (uid != null) {
                  // Cache profile if it has info
                  if (sData['name'] != null) {
                    _profileCache[uid] = {
                      'name': sData['name'],
                      'avatar': sData['avatar'],
                      'displayId': sData['displayId'],
                      'displayIdImage': sData['displayIdImage'],
                    };
                  } else if (_profileCache.containsKey(uid)) {
                    // Inject cached info if Firestore is missing it
                    final cached = _profileCache[uid]!;
                    sData['name'] ??= cached['name'];
                    sData['avatar'] ??= cached['avatar'];
                    sData['displayId'] ??= cached['displayId'];
                    sData['displayIdImage'] ??= cached['displayIdImage'];
                  }

                  // Inject frame from up-to-date cache (processed above)
                  // Priority: Temporary frame (from cache) > Persistent frame (from seat data)
                  sData['frame'] = _userFrameCache[uid] ?? sData['frame'];
                }
                return sData;
              }
              return null;
            });

            // After building seats, fetch temporaryFrame from each user's profile
            // so cross-room frames are visible in this new room too.
            final seatedUids = _seats
                .where((s) => s != null && s['userId'] != null)
                .map((s) => s!['userId'] as String)
                .toList();

            if (seatedUids.isNotEmpty) {
              final now = DateTime.now().toUtc();

              // 1. INSTANT: Apply from in-memory cache (no network needed)
              bool didApplyFromCache = false;
              for (final uid in seatedUids) {
                if (_activeFrames.containsKey(uid)) continue;
                final cached = _temporaryFrameCache[uid];
                if (cached != null) {
                  final expiryStr = cached['expiry'] as String?;
                  if (expiryStr != null) {
                    final expiry = DateTime.tryParse(expiryStr)?.toUtc();
                    if (expiry != null && now.isBefore(expiry)) {
                      _activeFrames[uid] = cached;
                      _userFrameCache[uid] = cached['type'] as String;
                      didApplyFromCache = true;
                    } else {
                      // Expired — remove from static cache
                      _temporaryFrameCache.remove(uid);
                    }
                  }
                }
              }
              if (didApplyFromCache) notifyListeners();

              // 2. BACKGROUND: Fetch from Firestore for users not in local cache
              dart_async.unawaited(
                dart_async.Future(() async {
                  for (final uid in seatedUids) {
                    // Skip users already in activeFrames (from room or cache)
                    if (_activeFrames.containsKey(uid)) continue;
                    try {
                      final userSnap = await _db
                          .collection('users')
                          .doc(uid)
                          .get();
                      if (!userSnap.exists) continue;
                      final userData = userSnap.data();
                      final tempFrame = userData?['temporaryFrame'];
                      if (tempFrame is Map) {
                        final expiryStr = tempFrame['expiry'] as String?;
                        if (expiryStr != null) {
                          final expiry = DateTime.tryParse(expiryStr)?.toUtc();
                          if (expiry != null && now.isBefore(expiry)) {
                            final frameType = tempFrame['type'] as String?;
                            if (frameType != null) {
                              final fData = {
                                'type': frameType,
                                'expiry': expiryStr,
                              };
                              _activeFrames[uid] = fData;
                              _userFrameCache[uid] = frameType;
                              _temporaryFrameCache[uid] = fData;
                            }
                          }
                        }
                      }
                    } catch (_) {}
                  }
                  if (_roomId == roomId) notifyListeners();
                }),
              );
            }
          }

          // Check if I was banned or kicked while in the room
          final myId = _auth.currentUser?.uid;
          if (myId != null) {
            final banned = data['bannedUsers'] as Map?;
            final kicked = data['kickedUsers'] as Map?;

            String? reason;
            if (banned != null && banned.containsKey(myId)) {
              reason = 'banned';
            } else if (kicked != null && kicked.containsKey(myId)) {
              final expiry = kicked[myId];
              if (expiry is int &&
                  DateTime.now().millisecondsSinceEpoch < expiry) {
                reason = 'kicked';
              }
            } else if (!_freshJoin) {
              final usersMap = data['users'] as Map?;
              if (usersMap != null && !usersMap.containsKey(myId)) {
                // Ghost detected: user was removed from Firestore (due to internet lag cleanup) 
                // but the app is still active locally. Silently restore their presence.
                dart_async.unawaited(_forceRestorePresence());
              }
            }

            if (reason != null) {
              _exitReason = reason;
              leaveRoom();
              return; // Stop processing
            }
          }

          if (data.containsKey('admins')) {
            _admins = Map<String, dynamic>.from(data['admins'] as Map);
          } else {
            _admins = {};
          }

          if (data.containsKey('coOwners')) {
            _coOwners = Map<String, dynamic>.from(data['coOwners'] as Map);
          } else {
            _coOwners = {};
          }

          if (data.containsKey('mutedUsers')) {
            _mutedUsers = Map<String, dynamic>.from(data['mutedUsers'] as Map);
          } else {
            _mutedUsers = {};
          }
          if (data.containsKey('bannedUsers')) {
            _bannedUsers = Map<String, dynamic>.from(
              data['bannedUsers'] as Map,
            );
          } else {
            _bannedUsers = {};
          }

          // Check if I am in a seat to set Broadcaster role
          final amISeated = isMeSeated;

          if (data.containsKey('hostId') || data.containsKey('ownerId')) {
            _hostId = data['hostId'] ?? data['ownerId'];
          }

          if (amISeated && !_isBroadcaster && !_isSettingRole) {
            await setRole(ClientRoleType.clientRoleBroadcaster);
          } else if (!amISeated && _isBroadcaster && !_isSettingRole) {
            await setRole(ClientRoleType.clientRoleAudience);
          }

          // ── Per-room admin toggles ─────────────────────────────────────
          final bool prevSeats = _adminSeatsEnabled;
          _adminSeatsEnabled = data['adminSeatsEnabled'] != false;
          _adminChatEnabled = data['adminChatEnabled'] != false;
          _showAmbientBubbles = data['showAmbientBubbles'] != false;

          // Check Mic Mode Permissions
          final String micMode = data['micMode'] ?? "الجميع";
          final bool isMeAdmin = isAdmin(myId!) || isCoOwner(myId) || isHost;
          bool permissionLost = false;
          if (micMode == "الأعضاء فقط" && !_isMember && !isMeAdmin) {
            permissionLost = true;
          } else if (micMode == "المشرفون فقط" && !isMeAdmin) {
            permissionLost = true;
          }

          if ((!_adminSeatsEnabled && prevSeats && isMeSeated) ||
              (permissionLost && isMeSeated)) {
            leaveSeat().catchError(
              (e) => print(
                "[Room] Force leave seat (Permissions/Toggles changed): $e",
              ),
            );
          }

          _currentRoomData = data;
          /* Local Studio Mode: Audio is broadcasted natively by Agora, no Firestore sync needed */
          notifyListeners();
        }
      }
    });

    _rtdbPresenceSubscription?.cancel();
    _rtdbPresenceSubscription = _rtdb
        .ref('rooms/$roomId/presence')
        .onValue
        .listen((event) {
          if (event.snapshot.value != null) {
            final Map<dynamic, dynamic> presenceData =
                event.snapshot.value as Map<dynamic, dynamic>;
            _rtdbActiveUsers.clear();
            presenceData.forEach((uid, status) {
              if (status is Map && status['active'] == true) {
                _rtdbActiveUsers.add(uid.toString());
              }
            });
            _refreshRoomUsers();
          }
        });

    _subscribeToStickers(roomId);
    _subscribeToInvitations(roomId);
  }

  /// Listen to interactive stickers via RTDB for <1s latency
  void _subscribeToStickers(String roomId) {
    _reactionsSubscription?.cancel();
    _reactionsSubscription = _rtdb
        .ref('rooms/$roomId/activeReactions')
        .onValue
        .listen((event) {
          if (event.snapshot.exists) {
            _activeReactions = Map<String, dynamic>.from(
              event.snapshot.value as Map,
            );
          } else {
            _activeReactions = {};
          }
          notifyListeners();
        });
  }

  // Alias for backward compatibility and user request
  void listenToStickers(String roomId) => _subscribeToStickers(roomId);

  void _subscribeToInvitations(String roomId) {
    final myId = currentUserId;
    if (myId == null) return;
    _invitationsSubscription?.cancel();
    _invitationsSubscription = _rtdb
        .ref('rooms/$roomId/invitations/$myId')
        .onValue
        .listen((event) {
          if (event.snapshot.exists) {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            // Only trigger if it's new (within last 30 seconds to avoid stale ones)
            final ts = data['timestamp'] as int?;
            if (ts != null &&
                DateTime.now().millisecondsSinceEpoch - ts < 30000) {
              _lastInvitation = data;
              notifyListeners();
            }
          }
        });
  }

  void clearLastInvitation() {
    final myId = currentUserId;
    if (myId != null && _roomId != null) {
      _rtdb.ref('rooms/$_roomId/invitations/$myId').remove();
    }
    _lastInvitation = null;
    notifyListeners();
  }

  void _subscribeToMessages(String roomId) {
    _messagesSubscription?.cancel();
    _messagesSubscription = _rtdb
        .ref('rooms/$roomId/messages')
        .limitToLast(100)
        .onValue
        .listen((event) {
          // Preserve pending optimistic messages BEFORE any clears
          final pending = _messages
              .where((m) => m['isPending'] == true)
              .toList();

          if (event.snapshot.exists) {
            // Only clear messages on the very first load after a fresh join
            if (_freshJoin) {
              _messages = [];
              _freshJoin = false;
            }
            final Map<dynamic, dynamic> data = event.snapshot.value as Map;
            final List<Map<String, dynamic>> syncedMessages = [];

            data.forEach((key, value) {
              final m = Map<String, dynamic>.from(value as Map);
              m['id'] = key;

              // Only include messages sent after joining this session
              final dynamic tsRaw = m['timestamp'];
              final bool isPendingTs = tsRaw is Map || tsRaw == null;
              final int msgTs = (tsRaw is int)
                  ? tsRaw
                  : (isPendingTs ? DateTime.now().millisecondsSinceEpoch : 0);

              if (_joinTimestamp != null &&
                  !isPendingTs &&
                  msgTs < _joinTimestamp! - 10000) {
                // Skip messages from before joining (10s buffer for clock skew)
                return;
              }

              // Deep cast replyTo if exists
              if (m['replyTo'] != null && m['replyTo'] is Map) {
                m['replyTo'] = Map<String, dynamic>.from(m['replyTo'] as Map);
              }

              m['timestamp'] = msgTs;
              syncedMessages.add(m);
            });

            // Sort by timestamp descending (Newest First)
            syncedMessages.sort((a, b) {
              final aTs = a['timestamp'] ?? 0;
              final bTs = b['timestamp'] ?? 0;
              return bTs.compareTo(aTs);
            });

            // Deduplicate
            pending.removeWhere(
              (p) => syncedMessages.any(
                (s) => s['text'] == p['text'] && s['senderId'] == p['senderId'],
              ),
            );

            _messages = syncedMessages;
          } else {
            _messages = [];
            _freshJoin = false;
          }

          if (pending.isNotEmpty) {
            _messages.insertAll(0, pending);
          }

          notifyListeners();
        });
  }

  // Actions

  dart_async.Future<void> takeSeat(int index, {bool isInvited = false}) async {
    if (_roomId == null) return;
    final user = _auth.currentUser;
    if (user == null) return;

    if (!_isGlobalMicEnabled) {
      throw "عذراً، الكراسي مغلقة حالياً من قبل الإدارة";
    }

    if (!_adminSeatsEnabled) {
      throw "عذراً، تم إيقاف الكراسي مؤقتاً في هذه الغرفة";
    }

    final bool isBoosted = _currentRoomData?['isBoosted'] == true;
    final bool isOwner = user.uid == _hostId;
    final bool isMeAdmin = isAdmin(user.uid) || isCoOwner(user.uid) || isOwner;
    final bool isAdminRoom = _currentRoomData?['isAdminRoom'] == true;

    // Mic Mode Permissions Check
    final String micMode = _currentRoomData?['micMode'] ?? "الجميع";
    if (micMode == "الأعضاء فقط" && !isRoomMember && !isMeAdmin) {
      throw "عذراً، يجب الانضمام للغرفة أولاً لتتمكن من الجلوس على الكرسي.";
    }
    if (micMode == "المشرفون فقط" && !isMeAdmin && !isInvited) {
      throw "عذراً، الكراسي للمشرفين فقط حالياً";
    }

    if (isAdminRoom) {
      if (!isMeAdmin && !isInvited) {
        throw "عذراً، يجب عليك طلب صعود الكرسي من المشرف أو تلقي دعوة";
      }
    } else {
      if (!isBoosted && !isOwner && !isInvited) {
        throw "عذراً، الكراسي مغلقة حتى يتم تعزيز الغرفة";
      }
    }

    if (isUserMuted(user.uid)) {
      throw "عذراً، لا يمكنك صعود الكرسي لأنك مكتوم.";
    }

    // --- PK Match Team Restriction ---
    final pkMatch = _currentRoomData?['pkMatch'] as Map<String, dynamic>?;
    if (pkMatch != null && pkMatch['isActive'] == true) {
      final int currentSeat = _seats.indexWhere(
        (s) => s != null && s['userId'] == user.uid,
      );
      if (currentSeat != -1) {
        // Teams defined as: [Referee: 0], [Left: 1, 2], [Right: 3, 4]
        bool isLeft(int i) => i == 1 || i == 2;
        bool isRight(int i) => i == 3 || i == 4;
        bool isRef(int i) => i == 0;

        if (isLeft(currentSeat) && isRight(index)) {
          throw "عذراً، لا يمكنك الانتقال ";
        }
        if (isRight(currentSeat) && isLeft(index)) {
          throw "عذراً، لا يمكنك الانتقال ";
        }
        // Referee can move anywhere if they are the host, but others shouldn't take ref seat
        if (!isRef(currentSeat) && isRef(index)) {
          throw "كرسي الحكم";
        }
      }
    }

    // ---- LAST-WRITE-WINS: increment generation on every tap ----
    _seatChangeGeneration++;
    final int myGeneration = _seatChangeGeneration;

    final roomRef = _db.collection('rooms').doc(_roomId!);

    // OPTIMISTIC UPDATE: move user to the target seat immediately in local state
    final int oldIndex = _seats.indexWhere(
      (s) => s != null && s['userId'] == user.uid,
    );
    final dynamic oldSeatData = oldIndex != -1 ? _seats[oldIndex] : null;
    final dynamic targetSeatData = _seats[index];

    // Lock snapshots from touching seat state
    _isTakingSeat = true;

    if (oldIndex != -1) _seats[oldIndex] = null;

    // Retrieve from cache (which should be pre-loaded now)
    final cached = _profileCache[user.uid];
    _seats[index] = {
      'userId': user.uid,
      'name': (cached?['name']?.toString().isNotEmpty == true)
          ? cached!['name']
          : (user.displayName ?? '...'),
      'avatar': cached?['avatar'] ?? user.photoURL,
      'displayId': cached?['displayId'],
      'displayIdImage': cached?['displayIdImage'],
      'frame': _userFrameCache[user.uid],
    };

    // --- MUTE RESET (BACKGROUND): Clear state for next time ---
    _isMuted = false;
    _isSpeakerMuted = false;
    if (_isInitialized) {
      _engine
          .muteLocalAudioStream(false)
          .catchError((e) => print("Background unmute error: $e"));
      _engine
          .muteAllRemoteAudioStreams(false)
          .catchError((e) => print("Background unmute all error: $e"));
    }
    notifyListeners();

    try {
      await _db.runTransaction((transaction) async {
        // --- STALE CHECK: if a newer tap happened, abort this transaction ---
        if (myGeneration != _seatChangeGeneration) {
          // Silently exit; the newer takeSeat call will handle Firestore
          return;
        }

        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        // --- STALE CHECK again after the network round-trip ---
        if (myGeneration != _seatChangeGeneration) return;

        final rawSeats = snapshot.data()?['seats'];
        List<dynamic> currentSeats = List.generate(10, (i) => null);

        if (rawSeats is List) {
          for (int i = 0; i < rawSeats.length && i < 10; i++) {
            currentSeats[i] = rawSeats[i];
          }
        } else if (rawSeats is Map) {
          rawSeats.forEach((key, value) {
            final int? idx = int.tryParse(key.toString());
            if (idx != null && idx >= 0 && idx < 10) {
              currentSeats[idx] = value;
            }
          });
        }

        // Remove me from any existing seat
        for (int i = 0; i < currentSeats.length; i++) {
          final seat = currentSeats[i];
          if (seat != null && seat is Map && seat['userId'] == user.uid) {
            currentSeats[i] = null;
          }
        }

        // Check if seat is taken by someone else
        final targetSeat = currentSeats[index];
        if (targetSeat != null && targetSeat is Map) {
          if (targetSeat['isLocked'] == true) {
            throw "هذا الكرسي مقفل";
          }
          final String? occupantUid = targetSeat['userId'];
          if (occupantUid != null && occupantUid != user.uid) {
            // Check if the occupant is actually in the room's users list
            final usersMap = snapshot.data()?['users'] as Map? ?? {};
            if (usersMap.containsKey(occupantUid)) {
              throw "هذا الكرسي محجوز حالياً";
            }
            // If they are NOT in the usersMap, they are a ghost - allow overwriting!
            print(
              "[GhostSeat] Overwriting ghost user $occupantUid on seat $index",
            );
          }
        }

        // Fetch real user profile TRANSACTIONALLY
        final userProfileRef = _db.collection('users').doc(user.uid);
        final userDoc = await transaction.get(userProfileRef);
        final userData = userDoc.data() ?? {};
        final String realName =
            userData['nickname']?.toString().isNotEmpty == true
            ? userData['nickname']
            : user.displayName?.isNotEmpty == true
            ? user.displayName!
            : 'User';
        final String? realAvatar = userData['profileImage'] ?? user.photoURL;
        String? displayIdRaw = userData['displayId']?.toString();
        final String? displayId = (displayIdRaw == '1') ? null : displayIdRaw;
        final String? displayIdImage = userData['displayIdImage'];

        final currentMuted = snapshot.data()?['mutedUsers'] as Map? ?? {};
        if (currentMuted.containsKey(user.uid)) {
          throw "عذراً، لا يمكنك صعود الكرسي لأنك مكتوم.";
        }

        // One final stale check before writing
        if (myGeneration != _seatChangeGeneration) return;

        // Include the frame in the seat data so the snapshot that
        // comes back already has it — no extra round-trip needed.
        final String? myFrame = _userFrameCache[user.uid];

        currentSeats[index] = {
          'userId': user.uid,
          'name': realName,
          'avatar': realAvatar,
          'displayId': displayId,
          'displayIdImage': displayIdImage,
          'muted': _isMuted,
          if (myFrame != null) 'frame': myFrame,
        };

        transaction.update(roomRef, {'seats': currentSeats});
      });

      // Only switch to broadcaster if this is still the active generation
      if (myGeneration == _seatChangeGeneration) {
        print('[Agora] Seat taken, switching to broadcaster immediately');
        await setRole(ClientRoleType.clientRoleBroadcaster);
      }
    } catch (error) {
      // Only revert if this is still the latest request
      if (myGeneration == _seatChangeGeneration) {
        if (oldIndex != -1) _seats[oldIndex] = oldSeatData;
        _seats[index] = targetSeatData;
        notifyListeners();
      }
      print('Error taking seat: $error');
      if (myGeneration == _seatChangeGeneration) rethrow;
    } finally {
      // Release the snapshot lock only when the latest request finishes
      if (myGeneration == _seatChangeGeneration) {
        _isTakingSeat = false;
      }
    }
  }

  dart_async.Future<void> leaveSeat({String? targetRoomId}) async {
    final roomId = targetRoomId ?? _roomId;
    if (roomId == null) return;
    final user = _auth.currentUser;
    if (user == null) return;

    final roomRef = _db.collection('rooms').doc(roomId);

    // OPTIMISTIC LOCAL UPDATE: Clear the seat immediately for instant UI response
    _seatChangeGeneration++; // Track generation to avoid stale resets
    final int myGeneration = _seatChangeGeneration;
    _isTakingSeat = true; // Lock snapshots

    bool foundLocally = false;
    for (int i = 0; i < _seats.length; i++) {
      if (_seats[i] != null && _seats[i]!['userId'] == user.uid) {
        _seats[i] = null;
        foundLocally = true;
      }
    }
    if (foundLocally) notifyListeners();

    try {
      // Background Cleanup & Role Change
      setRole(
        ClientRoleType.clientRoleAudience,
      ).catchError((e) => print("Set role error: $e"));
      _isMuted = false;
      _isSpeakerMuted = false;
      if (_isInitialized) {
        _engine.muteLocalAudioStream(false).catchError((e) => null);
        _engine.muteAllRemoteAudioStreams(false).catchError((e) => null);
      }

      // Perform Firestore Update in background
      _db
          .runTransaction((transaction) async {
            final snapshot = await transaction.get(roomRef);
            if (!snapshot.exists) return;

            final rawSeats = snapshot.data()?['seats'];
            int seatCount = 10;
            if (_micLayoutType == 'layout_2')
              seatCount = 2;
            else if (_micLayoutType == 'layout_5')
              seatCount = 5;

            List<dynamic> currentSeats = List.generate(
              seatCount,
              (index) => null,
            );
            if (rawSeats is List) {
              for (int i = 0; i < rawSeats.length && i < seatCount; i++) {
                currentSeats[i] = rawSeats[i];
              }
            } else if (rawSeats is Map) {
              rawSeats.forEach((key, value) {
                final int? idx = int.tryParse(key.toString());
                if (idx != null && idx >= 0 && idx < seatCount)
                  currentSeats[idx] = value;
              });
            }

            for (int i = 0; i < currentSeats.length; i++) {
              if (currentSeats[i] != null &&
                  currentSeats[i]['userId'] == user.uid) {
                currentSeats[i] = null;
              }
            }
            transaction.update(roomRef, {'seats': currentSeats});
          })
          .then(
            (_) => null,
            onError: (e) {
              print("Leave transaction background error: $e");
              return null;
            },
          )
          .whenComplete(() {
            if (myGeneration == _seatChangeGeneration) {
              _isTakingSeat = false;
            }
          });

      dart_async.Future.microtask(() {
        if (hasListeners) notifyListeners();
      });
      return; // Return early as real UI update is already done
    } catch (error) {
      print('Error leaving seat: $error');
      _isTakingSeat = false;
    }
  }

  // --- Mute/Unmute Logic ---

  dart_async.Future<void> muteUser(
    String userId, {
    int? durationMinutes,
  }) async {
    if (_roomId == null) return;
    final myId = _auth.currentUser?.uid;
    if (myId == null) return;

    if (userId == _hostId) {
      throw Exception("لا يمكن كتم صاحب الغرفة");
    }

    final updates = <String, dynamic>{
      'mutedUsers.$userId': {
        'mutedBy': myId,
        'timestamp': FieldValue.serverTimestamp(),
        'expiry': durationMinutes != null
            ? DateTime.now()
                  .add(Duration(minutes: durationMinutes))
                  .millisecondsSinceEpoch
            : null,
      },
    };

    final roomRef = _db.collection('rooms').doc(_roomId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;

      // Remove from seat if seated
      final data = snapshot.data();
      final seatsRaw = data?['seats'];
      List<dynamic> newSeats = List.generate(10, (index) => null);

      if (seatsRaw is List) {
        for (int i = 0; i < seatsRaw.length && i < 10; i++) {
          newSeats[i] = seatsRaw[i];
        }
      } else if (seatsRaw is Map) {
        seatsRaw.forEach((key, value) {
          final int? idx = int.tryParse(key.toString());
          if (idx != null && idx >= 0 && idx < 10) {
            newSeats[idx] = value;
          }
        });
      }

      bool changed = false;
      for (int i = 0; i < newSeats.length; i++) {
        final s = newSeats[i];
        if (s is Map && s['userId'] == userId) {
          newSeats[i] = null;
          changed = true;
        }
      }

      if (changed) {
        transaction.update(roomRef, {'seats': newSeats});
      }

      transaction.update(roomRef, updates);
    });

    dart_async.unawaited(_logPenalty(targetUserId: userId, action: 'mute'));
  }

  dart_async.Future<void> unmuteUser(String userId) async {
    if (_roomId == null) return;
    await _db.collection('rooms').doc(_roomId).update({
      'mutedUsers.$userId': FieldValue.delete(),
    });
    dart_async.unawaited(_logPenalty(targetUserId: userId, action: 'unmute'));
  }

  dart_async.Future<void> sendMessage(
    String text, {
    Map<String, dynamic>? replyTo,
  }) async {
    if (_roomId == null || text.trim().isEmpty) return;
    final user = _auth.currentUser;
    if (user == null) return;

    if (isUserMuted(user.uid)) {
      throw "لقد تم كتمك من قبل المشرفين";
    }

    final cached = _profileCache[user.uid];
    final String realName = (cached?['name']?.toString().isNotEmpty == true)
        ? cached!['name']
        : (user.displayName ?? 'Guest');
    final String? realAvatar = cached?['avatar'] ?? user.photoURL;

    // 1. OPTIMISTIC LOCAL MESSAGE (Instant UI Delivery)
    final msgId = "local_${DateTime.now().millisecondsSinceEpoch}";
    final localMsg = {
      'id': msgId,
      'text': text,
      'senderId': user.uid,
      'senderName': realName,
      'photoURL': realAvatar,
      'timestamp': DateTime.now(), // Local proxy for immediate sorting
      'isPending': true,
      if (replyTo != null) 'replyTo': replyTo,
    };

    // Insert at front (Newest First for reverse: true chat)
    _messages.insert(0, localMsg);
    notifyListeners();

    // 2. BACKGROUND TRANSMISSION VIA RTDB (FAST)
    final messageRef = _rtdb.ref('rooms/$_roomId/messages').push();
    dart_async.unawaited(
      messageRef
          .set({
            'text': text,
            'senderId': user.uid,
            'senderName': realName,
            'photoURL': realAvatar,
            'timestamp': ServerValue.timestamp,
            if (replyTo != null) 'replyTo': replyTo,
          })
          .catchError((e) {
            print('[sendMessage] RTDB error: $e');
            _messages.removeWhere((m) => m['id'] == msgId);
            notifyListeners();
          }),
    );

    dart_async.unawaited(
      _db
          .collection('rooms')
          .doc(_roomId)
          .collection('messages')
          .add({
            'text': text,
            'senderId': user.uid,
            'senderName': realName,
            'photoURL': realAvatar,
            'timestamp': FieldValue.serverTimestamp(),
            if (replyTo != null) 'replyTo': replyTo,
          })
          .then((_) {})
          .catchError((e) {
            print('[sendMessage] Firestore log error: $e');
          }),
    );
  }

  dart_async.Future<void> sendSystemMessage(
    String text, {
    String type = 'system',
    String? imageUrl,
    String? senderId,
    String? senderDisplayId,
    String? senderName,
    String? roomEntrance,
    String? gameId,
  }) async {
    if (_roomId == null) return;

    final String rid = _roomId!;

    // 0. OPTIMISTIC LOCAL UPDATE (Instant UI Display)
    final String localId = "system_${DateTime.now().millisecondsSinceEpoch}";
    final Map<String, dynamic> localMsg = {
      'id': localId,
      'text': text,
      'type': type,
      'imageUrl': imageUrl,
      'senderId': senderId,
      'senderDisplayId': senderDisplayId,
      'senderName': senderName,
      'roomEntrance': roomEntrance,
      'gameId': gameId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'isPending': true,
    };

    _messages.insert(0, localMsg);
    notifyListeners(); // ← فوري بدون أي انتظار

    // 1. RTDB for instant delivery to others (fire-and-forget)
    dart_async.unawaited(
      _rtdb
          .ref('rooms/$rid/messages')
          .push()
          .set({
            'text': text,
            'type': type,
            'imageUrl': imageUrl,
            'senderId': senderId,
            'senderDisplayId': senderDisplayId,
            'senderName': senderName,
            'roomEntrance': roomEntrance,
            'timestamp': ServerValue.timestamp,
            'localId': localId,
          })
          .catchError((e) {
            print("[sendSystemMessage] RTDB error: $e");
            _messages.removeWhere((m) => m['id'] == localId);
            notifyListeners();
          }),
    );

    // 2. Firestore for history (fire-and-forget — no need to await)
    dart_async.unawaited(
      _db
          .collection('rooms')
          .doc(rid)
          .collection('messages')
          .add({
            'text': text,
            'type': type,
            'imageUrl': imageUrl,
            'senderId': senderId,
            'senderDisplayId': senderDisplayId,
            'senderName': senderName,
            'roomEntrance': roomEntrance,
            'timestamp': FieldValue.serverTimestamp(),
            'localId': localId,
          })
          .then((_) {})
          .catchError((e) {
            print("[sendSystemMessage] Firestore error: $e");
          }),
    );
  }

  // --- Daily Settlement Logic ---
  dart_async.Future<void> _checkDailySettlement(String roomId) async {
    try {
      await _db.runTransaction((transaction) async {
        final roomRef = _db.collection('rooms').doc(roomId);
        final roomSnap = await transaction.get(roomRef);

        if (!roomSnap.exists) return;
        final data = roomSnap.data()!;
        final hostId = data['hostId'];
        final currentWealth = data['wealth'] ?? 0;

        if (hostId == null || currentWealth <= 0) return;

        // Check date
        final lastSettlementVal = data['lastSettlement'];
        DateTime lastSettlement;
        if (lastSettlementVal != null) {
          lastSettlement = (lastSettlementVal as Timestamp).toDate();
        } else {
          // If never settled, use createdAt or yesterday to trigger
          final createdAt = data['createdAt'] as Timestamp?;
          lastSettlement =
              createdAt?.toDate() ??
              DateTime.now().subtract(const Duration(days: 1));
        }

        final now = DateTime.now();

        // Check if day changed (After 12:00 AM)
        bool isNewDay =
            now.year > lastSettlement.year ||
            (now.year == lastSettlement.year &&
                now.month > lastSettlement.month) ||
            (now.year == lastSettlement.year &&
                now.month == lastSettlement.month &&
                now.day > lastSettlement.day);

        if (isNewDay) {
          // Transfer Wealth to Host
          final userRef = _db.collection('users').doc(hostId);
          transaction.update(userRef, {
            'coins': FieldValue.increment(
              currentWealth,
            ), // Add to Coins (Profit)
          });

          // Reset Room Wealth & Update Timestamp
          transaction.update(roomRef, {
            'wealth': 0,
            'lastSettlement': FieldValue.serverTimestamp(),
          });

          print(
            "Daily Settlement Executed for Room $roomId: Transferred $currentWealth to Host $hostId",
          );
        }
      });
    } catch (e) {
      print("Error in daily settlement: $e");
    }
  }

  dart_async.Future<void> leaveRoom() async {
    // 0. Stop music immediately before clearing state
    if (_isMusicPlaying) {
      stopMusic();
    }

    _giftBgsSubscription?.cancel();
    _shopBgsSubscription?.cancel();
    _lastGiftBgs = [];
    _lastShopBgs = [];
    _allBackgrounds = [...predefinedBackgrounds];

    if (_roomId == null) return; // Already left or leaving

    // 1. Immediately cancel listeners to stop updates
    _messagesSubscription?.cancel();
    _reactionsSubscription?.cancel();
    _rtdbPresenceSubscription?.cancel();
    _invitationsSubscription?.cancel();
    _rtdbPresenceSubscription = null;
    _invitationsSubscription = null;
    _globalMicSubscription?.cancel();
    _globalMicSubscription = null;
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();
    _speakerCleanupTimer?.cancel();

    final String? rid = _roomId;
    final String? uid = currentUserId;

    // 2. Clear local state IMMEDIATELY so other widgets know we are out
    _roomId = null;
    _isGameChannel = false;
    _currentRoomData = null;
    _micLayoutType = null;
    _hostId = null;
    _roomLikes = 0;
    _messages = [];
    _seats = List.generate(10, (_) => null);
    _viewerCount = 0;
    _isBroadcaster = false;
    _isJoined = false;
    _admins = {};
    _coOwners = {};
    _mutedUsers = {};
    _bannedUsers = {};
    _roomUsersMetadata = {};
    _isMember = false;
    _isNetworkLost = false; // Reset connection status
    _networkMonitorTimer?.cancel(); // Stop fast monitor
    _showAmbientBubbles = false; // Reset to default (off)
    // Use microtask to avoid "widget tree was locked" errors if called during navigation/build
    dart_async.Future.microtask(() {
      if (_roomId == null)
        notifyListeners(); // Only notify if we haven't rejoined another room quickly
    });

    if (rid != null && uid != null) {
      // 3. Perform network/DB cleanups in the background (Parallel)
      // Clear currentRoomId from user profile
      _db
          .collection('users')
          .doc(uid)
          .update({'currentRoomId': FieldValue.delete()})
          .catchError(
            (e) => print('[leaveRoom] Error clearing currentRoomId: $e'),
          );

      dart_async.Future.wait([
        // Remove from Firestore
        // Remove from Firestore and check if room is empty
        _db
            .collection('rooms')
            .doc(rid)
            .update({'users.$uid': FieldValue.delete()})
            .then((_) async {
              // Check if room is empty - force fetch from SERVER to bypass cache
              try {
                final doc = await _db
                    .collection('rooms')
                    .doc(rid)
                    .get(const GetOptions(source: Source.server));
                if (doc.exists) {
                  final data = doc.data();
                  final users = data?['users'] as Map? ?? {};

                  // Debug print
                  print("Room $rid user count after leave: ${users.length}");

                  // Only clear the real-time chat if the room is completely empty.
                  // If others are still in the room, keep the chat history for them.
                  if (users.isEmpty) {
                    if (_roomId == rid) {
                      print(
                        "User rejoined $rid during cleanup, aborting message delete.",
                      );
                      return;
                    }
                    print(
                      "Room $rid is empty. Deleting chat history from both RTDB and Firestore...",
                    );

                    // 1. Clear RTDB messages (Main real-time source)
                    dart_async.unawaited(
                      _rtdb
                          .ref('rooms/$rid/messages')
                          .remove()
                          .catchError((e) => print("Error clearing RTDB: $e")),
                    );

                    // Fetch messages from server too
                    final msgsQuery = await _db
                        .collection('rooms')
                        .doc(rid)
                        .collection('messages')
                        .get(const GetOptions(source: Source.server));
                    if (msgsQuery.docs.isNotEmpty) {
                      // Process in batches of 400
                      final batch = _db.batch();
                      int count = 0;
                      for (final doc in msgsQuery.docs) {
                        batch.delete(doc.reference);
                        count++;
                        if (count >= 400) {
                          // Safe batch size
                          await batch.commit();
                          // In a real app we'd need loop logic for >500 messages
                          // but for now delete 400 most recent is good enough or throw warning
                          break;
                        }
                      }
                      if (count > 0 && count < 400) {
                        await batch.commit();
                      }
                      print("Deleted $count messages.");
                    }
                  }
                }
              } catch (e) {
                print("Error checking/clearing empty room: $e");
              }
            })
            .catchError((e) {
              print("Firestore cleanup error: $e");
              return null;
            }),

        // Remove from RTDB
        _rtdb.ref('rooms/$rid/presence/$uid').remove().catchError((e) {
          print("RTDB cleanup error: $e");
          return null;
        }),

        // Leave seat
        leaveSeat(targetRoomId: rid).catchError((e) {
          print("Seat cleanup error: $e");
          return null;
        }),

        // Leave Agora
        leaveChannel().catchError((e) {
          print("Agora cleanup error: $e");
          return null;
        }),

        // Clear currentRoomId from user document
        _db
            .collection('users')
            .doc(uid)
            .update({'currentRoomId': FieldValue.delete()})
            .catchError((e) {
              print("User room cleanup error: $e");
              return null;
            }),
      ]);
    }
  }

  // Internal Helpers

  static int getAgoraUid(String? userId) {
    if (userId == null || userId.isEmpty) return 0;
    // Stable DJB2 hash for cross-platform consistency (since String.hashCode is unstable)
    int hash = 5381;
    for (int i = 0; i < userId.length; i++) {
      hash = ((hash << 5) + hash) + userId.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    return (hash.abs() % 1000000) + 1000;
  }

  dart_async.Future<void> setRole(ClientRoleType role) async {
    print(
      "[Agora] Requesting role change to: ${role.name}. currentRoomId: $_roomId, isJoined: $_isJoined, currentMuteState: $_isMuted",
    );
    if (!_isInitialized || _isSettingRole) {
      if (_isSettingRole)
        print("[Agora] Role change IGNORED: Already setting a role.");
      return;
    }

    // Safety check: Cannot update channel media options if not joined
    if (!_isJoined) {
      print("[Agora] Delayed role change to $role until joined.");
      _pendingRole = role;
      return;
    }

    _pendingRole = null;
    _isSettingRole = true;

    try {
      if (role == ClientRoleType.clientRoleBroadcaster) {
        print(
          '[Agora] Transitioning to BROADCASTER (Seated). publishMic: ${!_isMuted}',
        );

        // Modern way: Use updateChannelMediaOptions for both role and publishing
        await _engine.updateChannelMediaOptions(
          ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            publishMicrophoneTrack: !_isMuted,
            publishMixedAudioTrack: true, // Mixed audio from startAudioMixing
            autoSubscribeAudio: true,
            publishCameraTrack: false,
          ),
        );

        await _engine.enableLocalAudio(true);
        print('[Agora] Local Audio Capture Module: ENABLED');

        // Explicitly ensuring the stream is not software-muted in the channel
        await _engine.muteLocalAudioStream(_isMuted);
        print('[Agora] muteLocalAudioStream: $_isMuted');

        if (_isMuted) {
          print('[Agora] Setting recording signal volume to 0 (Muted)');
          await _engine.adjustRecordingSignalVolume(0);
        } else {
          print('[Agora] Setting recording signal volume to 100 (Unmuted)');
          await _engine.adjustRecordingSignalVolume(100);
        }
        _isSpeakerMuted = false;
        await _engine.muteAllRemoteAudioStreams(false);
        await _engine.setEnableSpeakerphone(true);
        _isBroadcaster = true;
        print('[Agora] State Update: isBroadcaster = true');
      } else {
        print('[Agora] Transitioning to AUDIENCE (Leaving Seat)');

        await _engine.updateChannelMediaOptions(
          const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleAudience,
            audienceLatencyLevel:
                AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency,
            publishMicrophoneTrack: false,
            autoSubscribeAudio: true,
            publishCameraTrack: false,
          ),
        );

        await _engine.enableLocalAudio(false);
        print('[Agora] Local Audio Capture Module: DISABLED');
        _isBroadcaster = false;
        print('[Agora] State Update: isBroadcaster = false');
      }
    } catch (error) {
      print('[Agora] Role Change ERROR: $error');
      // If error is -8 (InvalidState), it usually means we're trying to update before the previous op finished
      if (error.toString().contains("-8")) {
        print("[Agora] Transient state error (-8), retrying in 500ms...");
        dart_async.Future.delayed(
          const Duration(milliseconds: 500),
          () => setRole(role),
        );
      }
    } finally {
      _isSettingRole = false;
      notifyListeners();
    }
  }

  // Agora Logic
  dart_async.Future<void> leaveChannel() async {
    if (!_isInitialized) return;
    await _engine.leaveChannel();
    await _engine.disableAudio(); // Stop audio polling and background tracks
    _isJoined = false;
    _remoteUsers.clear();
    _isBroadcaster = false;
    dart_async.Future.microtask(() {
      if (hasListeners) notifyListeners();
    });
  }

  dart_async.Future<void> toggleMute() async {
    // Optimistic toggle: instantaneous UI feedback
    await setMute(!_isMuted);
  }

  dart_async.Future<void> setMute(bool muted) async {
    if (!_isInitialized) return;

    if (!muted) {
      // Trying to unmute - verify against global admin setting
      try {
        final doc = await _db.collection('app_settings').doc('global').get();
        final data = doc.data() ?? {};
        final bool isGlobalMicEnabled = data['isGlobalMicEnabled'] ?? true;
        if (!isGlobalMicEnabled) {
          // If disabled, forcibly keep muted and throw error
          _isMuted = true;
          notifyListeners();
          throw "تم إغلاق جميع المايكات من قبل الإدارة";
        }
      } catch (e) {
        if (e is String) rethrow;
      }
    }

    // 1. INSTANT STATE CHANGE
    _isMuted = muted;
    print("[Agora] setMute (Optimistic): ${_isMuted ? 'MUTING' : 'UNMUTING'}");

    if (muted) {
      _activeSpeakers.remove(0);
      final int myUid = getAgoraUid(currentUserId);
      _activeSpeakers.remove(myUid);
    }

    // Trigger UI refresh immediately
    notifyListeners();

    // 2. FIRE-AND-FORGET AGORA/FIRESTORE (Don't block UI)
    dart_async.unawaited(_performMuteOperations(muted));
  }

  dart_async.Future<void> _performMuteOperations(bool muted) async {
    if (!_isJoined) return;
    try {
      // Update Agora Engine
      await _engine.updateChannelMediaOptions(
        ChannelMediaOptions(
          clientRoleType: (_isBroadcaster || _isGameChannel)
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
          publishMicrophoneTrack: (_isBroadcaster || _isGameChannel) && !muted,
          autoSubscribeAudio: true,
        ),
      );

      await _engine.muteLocalAudioStream(muted);

      int targetVol = muted ? 0 : 100;
      await _engine.adjustRecordingSignalVolume(targetVol);

      // 3. Update Firestore Seat Status so others see the icon change
      // Only update if I'm actually seated (Broadcaster)
      if (_isBroadcaster) {
        _updateSeatMuteStatus(currentUserId ?? "", muted);
      }
    } catch (e) {
      print("[Agora] async mute ops ERROR: $e");
      // REMOVED: Automatic retry loop for error -8 to prevent log spam and ANR
    }
  }

  dart_async.Future<void> setEnableSpeakerphone(bool enabled) async {
    if (!_isInitialized) return;
    try {
      await _engine.setEnableSpeakerphone(enabled);
      print("[Agora] setEnableSpeakerphone: $enabled");
    } catch (e) {
      print("[Agora] setEnableSpeakerphone ERROR: $e");
    }
  }

  dart_async.Future<void> toggleSpeakerMute() async {
    if (!_isInitialized) return;
    _isSpeakerMuted = !_isSpeakerMuted;

    // UI Feedback is instant
    notifyListeners();

    // Perform engine operation in background
    try {
      await _engine.muteAllRemoteAudioStreams(_isSpeakerMuted);
    } catch (e) {
      print("[Agora] toggleSpeakerMute ERROR: $e");
    }
  }

  dart_async.Future<void> muteRemoteAudioStreamLocally(
    int uid,
    bool mute,
  ) async {
    if (!_isInitialized) return;
    try {
      // Always mute on the regular voice room channel
      await _engine.muteRemoteAudioStream(uid: uid, mute: mute);
      print("[Agora] muteRemoteAudioStreamLocally: uid=$uid, mute=$mute");

      if (_isGameChannel && _gameChannelId != null) {
        // Also mute on the game Ex channel if active
        final int myAgoraUid = getAgoraUid(currentUserId);
        await _engine.muteRemoteAudioStreamEx(
          uid: uid,
          mute: mute,
          connection: RtcConnection(
            channelId: _gameChannelId!.trim(),
            localUid: myAgoraUid,
          ),
        );
        print(
          "[Agora] muteRemoteAudioStreamEx (game channel): uid=$uid, mute=$mute",
        );
      }
    } catch (e) {
      print("[Agora] Error muting remote audio for $uid: $e");
    }
  }

  dart_async.Future<void> toggleMusic() async {
    if (!_isInitialized) return;

    if (_isMusicPlaying && !_isMusicPaused) {
      await pauseMusic();
    } else if (_isMusicPaused) {
      await resumeMusic();
    } else {
      // Start default music
      const musicUrl =
          "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";
      await _startMusic(musicUrl, "موسيقى افتراضية");
    }
  }

  dart_async.Future<void> _startMusic(String path, String name) async {
    try {
      await _engine.startAudioMixing(
        filePath: path,
        loopback: false,
        cycle: 1, // Changed to 1 to allow duration calculation
      );
      await _engine.adjustAudioMixingPublishVolume(_musicVolume.toInt());
      await _engine.adjustAudioMixingPlayoutVolume(_musicVolume.toInt());

      _isMusicPlaying = true;
      _isMusicPaused = false;
      _selectedMusicName = name;
      _musicSenderId = currentUserId; // Mark localself as owner

      // Fetch duration for progress bar
      final dur = await _engine.getAudioMixingDuration();
      if (dur > 0) {
        _musicDuration = dur;
      }

      _startMusicProgressTimer();
      notifyListeners();
    } catch (e) {
      print("Error starting music: $e");
    }
  }

  dart_async.Future<void> pauseMusic() async {
    if (!_isInitialized) return;
    try {
      await _engine.pauseAudioMixing();
      // Force immediate local update
      _isMusicPaused = true;
      _musicProgressTimer?.cancel();
      notifyListeners();
    } catch (e) {
      print("Error pausing music: $e");
    }
  }

  dart_async.Future<void> stopMusic() async {
    if (!_isInitialized) return;
    try {
      await _engine.stopAudioMixing();
    } catch (e) {
      print("Error calling stopAudioMixing: $e");
    }

    // Force immediate local state update
    _isMusicPlaying = false;
    _isMusicPaused = false;
    _musicPosition = 0;
    _musicSenderId = null;
    _musicProgressTimer?.cancel();
    notifyListeners();
  }

  dart_async.Future<void> resumeMusic() async {
    if (!_isInitialized) return;
    try {
      await _engine.resumeAudioMixing();
      _isMusicPaused = false;
      _startMusicProgressTimer();
      notifyListeners();
    } catch (e) {
      print("Error resuming music: $e");
    }
  }

  dart_async.Future<void> seekMusic(double positionMs) async {
    if (!_isInitialized) return;
    try {
      await _engine.setAudioMixingPosition(positionMs.toInt());
      _musicPosition = positionMs.toInt();
      notifyListeners();
    } catch (e) {
      print("Error seeking music: $e");
    }
  }

  void _startMusicProgressTimer() {
    _musicProgressTimer?.cancel();
    _musicProgressTimer = dart_async.Timer.periodic(
      const Duration(milliseconds: 500),
      (timer) async {
        if (_isMusicPlaying && !_isMusicPaused) {
          try {
            final pos = await _engine.getAudioMixingCurrentPosition();
            if (pos >= 0) {
              _musicPosition = pos;
              notifyListeners();
            }
          } catch (e) {
            print("Error in _musicProgressTimer: $e");
          }
        }
      },
    );
  }

  dart_async.Future<void> pickAndPlayAudio() async {
    if (!_isInitialized) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;

        // INSTANT PLAYBACK: No Firebase upload, plays directly from local path
        if (_isMusicPlaying) {
          await _engine.stopAudioMixing();
        }

        await _startMusic(path, name);
        print('[VoiceRoom] Music started instantly from local path: $path');
      }
    } catch (e) {
      print("Error picking audio: $e");
    }
  }

  dart_async.Future<void> setMusicVolume(double volume) async {
    if (!_isInitialized) return;
    try {
      _musicVolume = volume;
      // Adjust BOTH publish (others) and playout (self) levels
      await _engine.adjustAudioMixingPublishVolume(_musicVolume.toInt());
      await _engine.adjustAudioMixingPlayoutVolume(_musicVolume.toInt());
      notifyListeners();
    } catch (e) {
      print("Error setting music volume: $e");
    }
  }

  dart_async.Future<void> toggleAmbientBubbles() async {
    if (_roomId == null) return;
    final bool newValue = !_showAmbientBubbles;

    try {
      await _db.collection('rooms').doc(_roomId).update({
        'showAmbientBubbles': newValue,
      });
      // Local state will be updated via the stream listener
    } catch (e) {
      debugPrint("Error toggling ambient bubbles: $e");
    }
  }

  dart_async.Future<void> sendFrame(
    String targetUserId,
    String frameType,
  ) async {
    if (_roomId == null || currentUserId == null) return;

    final frameCost = 99;
    final expiry = DateTime.now().add(const Duration(minutes: 5));

    final result = await _db.runTransaction<Map<String, dynamic>>((
      transaction,
    ) async {
      final userRef = _db.collection('users').doc(currentUserId);
      final roomRef = _db.collection('rooms').doc(_roomId);
      final targetUserRef = _db.collection('users').doc(targetUserId);

      // 1. ALL READS FIRST
      final userSnap = await transaction.get(userRef);
      final roomSnap = await transaction.get(roomRef);
      final targetUserSnap = (targetUserId == currentUserId)
          ? userSnap
          : await transaction.get(targetUserRef);

      if (!userSnap.exists)
        return {'success': false, 'error': "المستخدم غير موجود"};
      if (!roomSnap.exists)
        return {'success': false, 'error': "الغرفة غير موجودة"};

      final userData = userSnap.data();
      final int diamonds = userData?.containsKey('diamonds') == true
          ? (userData!['diamonds'] as int)
          : 0;
      if (diamonds < frameCost)
        return {'success': false, 'error': "رصيد الماس غير كافٍ"};

      // 1.5. OPTIMISTIC UPDATE: Update local state immediately for instant feedback
      _activeFrames[targetUserId] = {
        'type': frameType,
        'expiry': expiry.toUtc().toIso8601String(),
      };
      // Important: Also update the static frame cache for instant seat UI refresh
      _userFrameCache[targetUserId] = frameType;
      // Cross-room cache: persists when navigating to another room
      _temporaryFrameCache[targetUserId] = {
        'type': frameType,
        'expiry': expiry.toUtc().toIso8601String(),
      };

      notifyListeners();

      // 2. ALL WRITES AFTER READS
      // Deduct diamonds from sender
      transaction.update(userRef, {
        'diamonds': FieldValue.increment(-frameCost),
      });

      // Update room activeFrames for immediate local room state
      transaction.update(roomRef, {
        'activeFrames.$targetUserId': {
          'type': frameType,
          'expiry': expiry.toUtc().toIso8601String(),
        },
      });

      // Update global user document so frame persists across rooms
      transaction.update(targetUserRef, {
        'temporaryFrame': {
          'type': frameType,
          'expiry': expiry.toUtc().toIso8601String(),
        },
      });

      // (We no longer delete the permanent profile frame, manualFrame will prioritize over it)

      // Add room chat message
      final bool isSticker = frameType.startsWith('http');
      final bool isAnimated =
          frameType.toLowerCase().contains('anim') ||
          frameType.toLowerCase().endsWith('.svga');
      final String frameLabel = isSticker
          ? 'ملصقاً'
          : (isAnimated ? 'إطاراً متحركاً' : 'إطاراً ثابتاً');

      final targetData = targetUserSnap.data();
      final receiverName =
          targetData?['nickname'] ?? targetData?['username'] ?? 'مستخدم';
      final senderName =
          userData?['nickname'] ?? userData?['username'] ?? 'مستخدم';

      final chatRef = _db
          .collection('rooms')
          .doc(_roomId)
          .collection('messages')
          .doc();

      final Map<String, dynamic> firestoreMsgData = {
        'id': 'frame_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'system',
        'text': 'أرسل $senderName $frameLabel إلى $receiverName',
        'senderId': currentUserId,
        'senderName': senderName,
        'receiverId': targetUserId,
        'receiverName': receiverName,
        'photoURL': userData?['profileImage'] ?? userData?['photoURL'],
        'frameType': frameType,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isPending': true,
      };

      // 0. OPTIMISTIC UPDATE
      _messages.insert(0, Map.from(firestoreMsgData));
      notifyListeners();

      transaction.set(chatRef, firestoreMsgData);
      // RTDB for real-time display (Use ServerValue.timestamp)
      final rtdbMsgRef = _rtdb.ref('rooms/$_roomId/messages').push();
      final Map<String, dynamic> rtdbMsgData = Map.from(firestoreMsgData);
      rtdbMsgData.remove('id');
      rtdbMsgData.remove('isPending');
      rtdbMsgData['timestamp'] = ServerValue.timestamp;

      dart_async.unawaited(rtdbMsgRef.set(rtdbMsgData));
      return {'success': true};
    });

    if (result['success'] == false) {
      throw result['error'];
    }

    // Schedule automatic deletion from DB after 5 minutes + 5 seconds buffer
    final String expiryStr = expiry.toUtc().toIso8601String();
    dart_async.Future.delayed(const Duration(minutes: 5, seconds: 5), () async {
      if (_roomId != null) {
        // Only delete if it hasn't been overwritten by a newer frame (check expiry)
        await _db
            .runTransaction((transaction) async {
              // Delete from room
              final roomRef = _db.collection('rooms').doc(_roomId!);
              final snap = await transaction.get(roomRef);
              if (snap.exists) {
                final data = snap.data();
                final currentFrame = data?['activeFrames']?[targetUserId];
                if (currentFrame is Map &&
                    currentFrame['expiry'] == expiryStr) {
                  transaction.update(roomRef, {
                    'activeFrames.$targetUserId': FieldValue.delete(),
                  });
                }
              }

              // Delete from global user doc
              final userRef = _db.collection('users').doc(targetUserId);
              final userSnap = await transaction.get(userRef);
              if (userSnap.exists) {
                final data = userSnap.data();
                final currentTempFrame = data?['temporaryFrame'];
                if (currentTempFrame is Map &&
                    currentTempFrame['expiry'] == expiryStr) {
                  transaction.update(userRef, {
                    'temporaryFrame': FieldValue.delete(),
                  });
                }
              }
            })
            .catchError((e) => print("Auto-delete frame error: $e"));
      }
    });
  }

  dart_async.Future<void> sendFrameToAllSeats(String frameType) async {
    if (_roomId == null || currentUserId == null) return;

    final frameCostPerUser = 99;
    final expiry = DateTime.now().add(const Duration(minutes: 5));

    final occupiedUserIds = _seats
        .where((s) => s != null && s['userId'] != null)
        .map((s) => s!['userId'] as String)
        .toList();

    final result = await _db.runTransaction<Map<String, dynamic>>((
      transaction,
    ) async {
      final userRef = _db.collection('users').doc(currentUserId);
      final userSnap = await transaction.get(userRef);
      if (!userSnap.exists)
        return {'success': false, 'error': "المستخدم غير موجود"};

      final userData = userSnap.data();
      final int diamonds = userData?['diamonds'] ?? 0;

      if (occupiedUserIds.isEmpty)
        return {
          'success': false,
          'error': "لا يوجد مستخدمون حالياً على المقاعد",
        };

      final totalCost = frameCostPerUser * occupiedUserIds.length;
      if (diamonds < totalCost) {
        return {
          'success': false,
          'error': "رصيدك غير كافٍ لإرسال الإطارات للجميع ($totalCost ماسة)",
        };
      }

      final roomRef = _db.collection('rooms').doc(_roomId);
      final roomSnap = await transaction.get(roomRef);
      if (!roomSnap.exists)
        return {'success': false, 'error': "الغرفة غير موجودة"};

      // Deduct total crystals
      transaction.update(userRef, {
        'diamonds': FieldValue.increment(-totalCost),
      });

      // 1.5. OPTIMISTIC UPDATE: Update local state for all targets immediately
      for (final uId in occupiedUserIds) {
        final frameData = {
          'type': frameType,
          'expiry': expiry.toUtc().toIso8601String(),
        };
        _activeFrames[uId] = frameData;
        // Update static cache for each user
        _userFrameCache[uId] = frameType;
        // Cross-room cache: persists when navigating to another room
        _temporaryFrameCache[uId] = frameData;
      }
      notifyListeners();

      // Update all room frames and global user frames
      final roomUpdates = <String, dynamic>{};
      for (final uId in occupiedUserIds) {
        final frameData = {
          'type': frameType,
          'expiry': expiry.toUtc().toIso8601String(),
        };

        // Local room state
        roomUpdates['activeFrames.$uId'] = frameData;

        // Global user state (persists across rooms)
        transaction.update(_db.collection('users').doc(uId), {
          'temporaryFrame': frameData,
        });

        // (We no longer delete the permanent profile frames, manualFrame will prioritize over them)
      }
      transaction.update(roomRef, roomUpdates);

      // Add room chat message
      final bool isSticker = frameType.startsWith('http');
      final bool isAnimated =
          frameType.toLowerCase().contains('anim') ||
          frameType.toLowerCase().endsWith('.svga');
      final String frameLabel = isSticker
          ? 'ملصقاً'
          : (isAnimated ? 'إطاراً متحركاً' : 'إطاراً ثابتاً');

      final senderName =
          userData?['nickname'] ?? userData?['username'] ?? 'مستخدم';
      final count = occupiedUserIds.length;

      final chatRef = _db
          .collection('rooms')
          .doc(_roomId)
          .collection('messages')
          .doc();

      final Map<String, dynamic> firestoreMsgData = {
        'id': 'frame_all_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'system',
        'text': 'أرسل $senderName $frameLabel إلى الجميع ($count)',
        'senderId': currentUserId,
        'senderName': senderName,
        'receiverId': 'all',
        'receiverName': 'الجميع',
        'photoURL': userData?['profileImage'] ?? userData?['photoURL'],
        'frameType': frameType,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isPending': true,
      };

      // 0. OPTIMISTIC UPDATE
      _messages.insert(0, Map.from(firestoreMsgData));
      notifyListeners();

      transaction.set(chatRef, firestoreMsgData);
      // RTDB for real-time display (Use ServerValue.timestamp)
      final rtdbMsgRef = _rtdb.ref('rooms/$_roomId/messages').push();
      final Map<String, dynamic> rtdbMsgData = Map.from(firestoreMsgData);
      rtdbMsgData.remove('id');
      rtdbMsgData.remove('isPending');
      rtdbMsgData['timestamp'] = ServerValue.timestamp;

      dart_async.unawaited(rtdbMsgRef.set(rtdbMsgData));
      return {'success': true};
    });

    if (result['success'] == false) {
      throw result['error'];
    }

    // Schedule automatic deletion for all from DB after 5 minutes + 5 seconds buffer
    final String expiryStr = expiry.toUtc().toIso8601String();
    dart_async.Future.delayed(const Duration(minutes: 5, seconds: 5), () async {
      if (_roomId != null) {
        await _db
            .runTransaction((transaction) async {
              // Delete from room
              final roomRef = _db.collection('rooms').doc(_roomId!);
              final snap = await transaction.get(roomRef);
              if (snap.exists) {
                final data = snap.data();
                final activeFrames = data?['activeFrames'] as Map? ?? {};
                final Map<String, dynamic> updates = {};

                for (final uId in occupiedUserIds) {
                  final currentFrame = activeFrames[uId];
                  if (currentFrame is Map &&
                      currentFrame['expiry'] == expiryStr) {
                    updates['activeFrames.$uId'] = FieldValue.delete();
                  }
                }

                if (updates.isNotEmpty) {
                  transaction.update(roomRef, updates);
                }
              }

              // Delete from all global user docs
              for (final uId in occupiedUserIds) {
                final userRef = _db.collection('users').doc(uId);
                final userSnap = await transaction.get(userRef);
                if (userSnap.exists) {
                  final userData = userSnap.data();
                  final currentTempFrame = userData?['temporaryFrame'];
                  if (currentTempFrame is Map &&
                      currentTempFrame['expiry'] == expiryStr) {
                    transaction.update(userRef, {
                      'temporaryFrame': FieldValue.delete(),
                    });
                  }
                }
              }
            })
            .catchError((e) => print("Auto-delete all frames error: $e"));
      }
    });
  }

  /// Send interactive sticker via RTDB for <1s latency
  dart_async.Future<void> sendSticker(
    String stickerId, {
    String? targetUserId,
  }) async {
    final effectiveUid = targetUserId ?? currentUserId;
    if (_roomId == null || effectiveUid == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Optimistic Update
    _activeReactions[effectiveUid] = {
      'type': stickerId,
      'timestamp': timestamp,
    };
    notifyListeners();

    // Fast Path via RTDB
    final reactionRef = _rtdb.ref(
      'rooms/$_roomId/activeReactions/$effectiveUid',
    );
    await reactionRef.set({'type': stickerId, 'timestamp': timestamp});

    // Add chat notification for stickers ONLY if it's a network sticker (http)
    if (stickerId.startsWith('http')) {
      try {
        final userDoc = await _db.collection('users').doc(currentUserId).get();
        final senderName =
            userDoc.data()?['nickname'] ??
            userDoc.data()?['username'] ??
            'مستخدم';

        String receiverName = 'نفسه';
        if (targetUserId != null && targetUserId != currentUserId) {
          final targetDoc = await _db
              .collection('users')
              .doc(targetUserId)
              .get();
          receiverName =
              targetDoc.data()?['nickname'] ??
              targetDoc.data()?['username'] ??
              'مستخدم';
        }

        final chatRef = _db
            .collection('rooms')
            .doc(_roomId)
            .collection('messages')
            .doc();

        final Map<String, dynamic> firestoreMsgData = {
          'id': 'sticker_${DateTime.now().millisecondsSinceEpoch}',
          'type': 'system',
          'text': 'أرسل $senderName ملصقاً إلى $receiverName',
          'senderId': currentUserId,
          'senderName': senderName,
          'receiverId': effectiveUid,
          'receiverName': receiverName,
          'photoURL':
              userDoc.data()?['profileImage'] ?? userDoc.data()?['photoURL'],
          'imageUrl': stickerId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'isPending': true,
        };

        // 0. OPTIMISTIC UPDATE
        _messages.insert(0, Map.from(firestoreMsgData));
        notifyListeners();

        // Firestore
        dart_async.unawaited(chatRef.set(firestoreMsgData));

        // RTDB for real-time display
        final rtdbMsgRef = _rtdb.ref('rooms/$_roomId/messages').push();
        final Map<String, dynamic> rtdbMsgData = Map.from(firestoreMsgData);
        rtdbMsgData.remove('id');
        rtdbMsgData.remove('isPending');
        rtdbMsgData['timestamp'] = ServerValue.timestamp;
        dart_async.unawaited(rtdbMsgRef.set(rtdbMsgData));
      } catch (e) {
        print("Error sending sticker notification: $e");
      }
    }

    // Auto-clear after 4s
    dart_async.Future.delayed(const Duration(seconds: 4), () async {
      if (_roomId != null) {
        final snap = await reactionRef.get();
        if (snap.exists) {
          final data = Map<String, dynamic>.from(snap.value as Map);
          if (data['timestamp'] == timestamp) {
            await reactionRef.remove();
          }
        }
      }
    });
  }

  // Legacy support for sendReaction
  dart_async.Future<void> sendReaction(String type) => sendSticker(type);

  void clearLocalReaction(String userId) {
    if (_activeReactions.containsKey(userId)) {
      _activeReactions.remove(userId);
      notifyListeners();
    }
  }

  dart_async.Future<bool> isFriend(String otherUserId) async {
    final myId = currentUserId;
    if (myId == null) return false;

    // Fetch both users to check mutual follow
    final myDoc = await _db.collection('users').doc(myId).get();
    final otherDoc = await _db.collection('users').doc(otherUserId).get();

    if (!myDoc.exists || !otherDoc.exists) return false;

    final myData = myDoc.data();
    final otherData = otherDoc.data();

    if (myData == null || otherData == null) return false;

    final List<dynamic> myFollowing = myData['following'] ?? [];
    final List<dynamic> otherFollowing = otherData['following'] ?? [];

    return myFollowing.contains(otherUserId) && otherFollowing.contains(myId);
  }

  void _startPresenceTimers() {
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();

    // Update 'lastSeen' in room every 20 seconds
    int _consecutiveHeartbeatFailures = 0;
    _heartbeatTimer = dart_async.Timer.periodic(const Duration(seconds: 20), (
      timer,
    ) async {
      if (_roomId != null && currentUserId != null) {
        try {
          final now = DateTime.now().toIso8601String();
          final int deterministicUid = getAgoraUid(currentUserId);
          await _db.collection('rooms').doc(_roomId).update({
            'users.$currentUserId.lastSeen': now,
            'users.$currentUserId.agoraUid': deterministicUid,
            'users.$currentUserId.isMember': _isMember,
          });
          _consecutiveHeartbeatFailures = 0; // Reset on success
        } catch (e) {
          _consecutiveHeartbeatFailures++;
          print("Heartbeat error ($_consecutiveHeartbeatFailures): $e");

          // If 3 heartbeats fail in a row (~60 seconds of total outage),
          // we assume the internet is cut off and show the overlay.
          if (_consecutiveHeartbeatFailures >= 3) {
            print("[Presence] Internet lost. Showing reconnection overlay.");
            _isNetworkLost = true;
            notifyListeners();
          }
        }
      }
    });

    // Cleanup stale users and award mic XP every 60 seconds

    _cleanupTimer = dart_async.Timer.periodic(const Duration(seconds: 60), (
      timer,
    ) {
      _performPresenceCleanup();
      if (_isJoined && (_isBroadcaster || _isGameChannel) && _roomId != null) {
        _awardMicXP();
        if (currentUserId != null) {
          TaskService().incrementTaskProgress(
            currentUserId!,
            TaskType.sitOnChair,
          );
        }
      }
    });

    // Start the fast network monitor (every 2 seconds for instant UI)
    _networkMonitorTimer?.cancel();
    _networkMonitorTimer = dart_async.Timer.periodic(
      const Duration(seconds: 2),
      (timer) {
        _checkFastConnection();
      },
    );

    // Run initial cleanup
    dart_async.Future.delayed(
      const Duration(seconds: 2),
      _performPresenceCleanup,
    );
  }

  dart_async.Future<void> _checkFastConnection() async {
    if (_roomId == null || _isNetworkLost) return;
    try {
      // Lightweight check: lookup google.com (or any stable host)
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        // We have internet
        if (_isNetworkLost) {
          _isNetworkLost = false;
          notifyListeners();
        }
      }
    } catch (_) {
      // Connection failure
      if (!_isNetworkLost) {
        print("[Presence] Fast monitor detected connection loss.");
        _isNetworkLost = true;
        notifyListeners();
      }
    }
  }

  dart_async.Future<void> _performPresenceCleanup() async {
    if (_roomId == null || currentUserId == null) return;

    // To prevent multiple users from writing simultaneously, only the senior person present cleans up.
    // Order: Host > CoOwner > Admin > Longest Present (approximated by uid comparison).
    bool amIAuthority =
        isHost || isCoOwner(currentUserId!) || isAdmin(currentUserId!);
    if (!amIAuthority) return;

    try {
      final roomRef = _db.collection('rooms').doc(_roomId);
      final roomSnap = await roomRef.get();
      if (!roomSnap.exists) return;

      final data = roomSnap.data()!;
      final usersMap = data['users'] as Map<String, dynamic>? ?? {};
      final now = DateTime.now();

      List<String> staleUserIds = [];

      usersMap.forEach((uid, userData) {
        if (uid == currentUserId) return; // Never clean up self

        if (userData is Map) {
          final lastSeenStr = userData['lastSeen'] as String?;
          if (lastSeenStr != null) {
            final lastSeen = DateTime.tryParse(lastSeenStr);
            if (lastSeen != null) {
              final diff = now.difference(lastSeen).inSeconds;
              // Threshold: 120 seconds (2 minutes) of silence = Disconnected.
              if (diff > 120) {
                staleUserIds.add(uid);
              }
            }
          }
        }
      });

      if (staleUserIds.isEmpty) return;

      final WriteBatch batch = _db.batch();
      final seatsList = data['seats'] as List<dynamic>? ?? [];

      for (String staleUid in staleUserIds) {
        batch.update(roomRef, {'users.$staleUid': FieldValue.delete()});

        // Clear seat in the same batch for atomic consistency
        for (int i = 0; i < seatsList.length; i++) {
          final seat = seatsList[i];
          if (seat is Map && seat['userId'] == staleUid) {
            batch.update(roomRef, {'seats.$i': FieldValue.delete()});
          }
        }
      }

      await batch.commit();
    } catch (e) {
      print("[PresenceCleanup] Error: $e");
    }
  }

  dart_async.Future<void> _forceRestorePresence() async {
    if (_roomId == null || currentUserId == null) return;
    try {
      final now = DateTime.now().toIso8601String();
      final int deterministicUid = getAgoraUid(currentUserId);
      
      // Update Firestore
      await _db.collection('rooms').doc(_roomId).update({
        'users.$currentUserId.lastSeen': now,
        'users.$currentUserId.agoraUid': deterministicUid,
        'users.$currentUserId.isMember': _isMember,
      });
      
      // Re-establish RTDB presence
      final presenceRef = _rtdb.ref('rooms/$_roomId/presence/$currentUserId');
      await presenceRef.set({'active': true, 'lastSeen': ServerValue.timestamp});
      dart_async.unawaited(presenceRef.onDisconnect().remove());
      
      print("[Presence] Ghost restored! User silently added back to room.");
    } catch (e) {
      print("[Presence] Failed to restore ghost: $e");
    }
  }

  dart_async.Future<void> retryConnection() async {
    if (_roomId == null || currentUserId == null) return;
    try {
      final now = DateTime.now().toIso8601String();
      final int deterministicUid = getAgoraUid(currentUserId);
      await _db.collection('rooms').doc(_roomId).update({
        'users.$currentUserId.lastSeen': now,
        'users.$currentUserId.agoraUid': deterministicUid,
      });
      // If successful
      _isNetworkLost = false;
      notifyListeners();
    } catch (e) {
      print("Retry connection failed: $e");
      rethrow;
    }
  }

  dart_async.Future<void> _awardMicXP() async {
    if (_roomId == null || currentUserId == null) return;
    try {
      double pointsToAward = RoomLevelSystem.calculateXP(
        minutesOnMic: 1,
      ); // ~3.33 Points
      await RoomLevelSystem.awardPointsToRoom(
        pointsToAward: pointsToAward,
        roomId: _roomId!,
        userId: currentUserId!,
      );
    } catch (e) {
      print("[_awardMicXP] Error: $e");
    }
  }

  /* Global Sync Methods Removed for Instant Private Studio Experience */

  dart_async.Future<void> _syncMusicState(bool isPlaying) async {
    if (_roomId == null || currentUserId == null) return;
    try {
      final roomRef = _db.collection('rooms').doc(_roomId);
      final roomSnap = await roomRef.get();
      if (!roomSnap.exists) return;

      final seats = roomSnap.data()?['seats'];
      if (seats is List) {
        int mySeatIndex = -1;
        List<dynamic> updatedSeats = List.from(seats);
        for (int i = 0; i < seats.length; i++) {
          final s = seats[i];
          if (s != null && s is Map && s['userId'] == currentUserId) {
            mySeatIndex = i;
            // Create a new map to ensure we don't modify read-only data
            final newSeat = Map<String, dynamic>.from(s);
            newSeat['isMusicPlaying'] = isPlaying;
            updatedSeats[i] = newSeat;
            break;
          }
        }

        if (mySeatIndex != -1) {
          await roomRef.update({'seats': updatedSeats});
        }
      }
    } catch (e) {
      print("Error syncing music state: $e");
    }
  }

  // --- Moderation Actions ---

  bool get amIOwner {
    if (_roomId == null || currentUserId == null) return false;
    return _hostId == currentUserId;
  }

  dart_async.Future<bool> _isOwner() async {
    if (_roomId == null || currentUserId == null) return false;
    final roomSnap = await _db.collection('rooms').doc(_roomId).get();
    return roomSnap.data()?['hostId'] == currentUserId;
  }

  dart_async.Future<void> banUser(String targetUserId) async {
    if (_roomId == null) return;
    if (!isAdmin(currentUserId!) && !isCoOwner(currentUserId!) && !isHost) {
      throw Exception("ليس لديك صلاحية القيام بهذا الإجراء");
    }

    await _db.collection('rooms').doc(_roomId).update({
      'bannedUsers.$targetUserId': true,
      // Also remove them from the 'users' list so they are considered "left"
      'users.$targetUserId': FieldValue.delete(),
    });

    // Attempt to remove them from seat if seated
    await _removeUserFromSeat(targetUserId);

    dart_async.unawaited(
      _logPenalty(targetUserId: targetUserId, action: 'ban'),
    );
  }

  dart_async.Future<void> unbanUser(String targetUserId) async {
    if (_roomId == null) return;
    if (!isAdmin(currentUserId!) && !isCoOwner(currentUserId!) && !isHost) {
      throw Exception("ليس لديك صلاحية القيام بهذا الإجراء");
    }

    await _db.collection('rooms').doc(_roomId).update({
      'bannedUsers.$targetUserId': FieldValue.delete(),
    });

    dart_async.unawaited(
      _logPenalty(targetUserId: targetUserId, action: 'unban'),
    );
  }

  Stream<List<Map<String, dynamic>>> getBannedUsers() {
    if (_roomId == null) return Stream.value([]);

    return _db.collection('rooms').doc(_roomId).snapshots().asyncMap((
      doc,
    ) async {
      final bannedMap =
          doc.data()?['bannedUsers'] as Map<String, dynamic>? ?? {};
      final uids = bannedMap.keys.toList();

      if (uids.isEmpty) return [];

      final userFutures = uids.map(
        (uid) => _db.collection('users').doc(uid).get(),
      );
      final userDocs = await dart_async.Future.wait(userFutures);

      List<Map<String, dynamic>> users = [];
      for (int i = 0; i < userDocs.length; i++) {
        final userDoc = userDocs[i];
        if (userDoc.exists) {
          final data = userDoc.data()!;
          users.add({
            'id': uids[i],
            'name': data['username'] ?? 'بدون اسم',
            'avatar': data['profileImage'] ?? '',
            'displayId': data['displayId'] ?? '',
          });
        }
      }
      return users;
    });
  }

  dart_async.Future<void> kickUser(String targetUserId) async {
    if (_roomId == null) return;
    // Kick for 2 hours
    final expiry = DateTime.now()
        .add(const Duration(hours: 2))
        .millisecondsSinceEpoch;

    if (!isAdmin(currentUserId!) && !isCoOwner(currentUserId!) && !isHost) {
      throw Exception("ليس لديك صلاحية القيام بهذا الإجراء");
    }

    await _db.collection('rooms').doc(_roomId).update({
      'kickedUsers.$targetUserId': expiry,
      'users.$targetUserId': FieldValue.delete(),
    });

    await _removeUserFromSeat(targetUserId);

    dart_async.unawaited(
      _logPenalty(targetUserId: targetUserId, action: 'kick'),
    );
  }

  dart_async.Future<void> toggleMuteUser(
    String targetUserId,
    bool shouldMute,
  ) async {
    if (_roomId == null) return;
    if (targetUserId == _hostId) {
      throw Exception("لا يمكن كتم صاحب الغرفة");
    }
    if (!isAdmin(currentUserId!) && !isCoOwner(currentUserId!) && !isHost) {
      throw Exception("ليس لديك صلاحية القيام بهذا الإجراء");
    }

    await _db.collection('rooms').doc(_roomId).update({
      'mutedUsers.$targetUserId': shouldMute ? true : FieldValue.delete(),
    });

    // If seated, also update their seat mute status
    _updateSeatMuteStatus(targetUserId, shouldMute);

    dart_async.unawaited(
      _logPenalty(
        targetUserId: targetUserId,
        action: shouldMute ? 'mute' : 'unmute',
      ),
    );
  }

  dart_async.Future<void> setAdmin(String targetUserId, bool isAdmin) async {
    if (_roomId == null) return;
    if (!await _isOwner()) throw Exception("ليس لديك صلاحية المالك");

    if (isAdmin) {
      // Check if user is a room member first
      final memberDoc = await _db
          .collection('rooms')
          .doc(_roomId)
          .collection('members')
          .doc(targetUserId)
          .get();

      if (!memberDoc.exists) {
        throw Exception("لا يمكن منراف لمستخدم غير منضم لعضوية الغرفة");
      }
    }

    await _db.collection('rooms').doc(_roomId).update({
      'admins.$targetUserId': isAdmin ? true : FieldValue.delete(),
    });

    dart_async.unawaited(
      _logPenalty(
        targetUserId: targetUserId,
        action: isAdmin ? 'set_admin' : 'remove_admin',
      ),
    );

    if (isAdmin) {
      try {
        final userDoc = await _db.collection('users').doc(targetUserId).get();
        final nickname =
            userDoc.data()?['nickname'] ?? userDoc.data()?['username'] ?? 'عضو';
        dart_async.unawaited(
          sendSystemMessage(
            'مبروك لـ $nickname لقد تم ترقيتك الى مشرف من قبل المالك',
          ),
        );
      } catch (e) {
        debugPrint('Error sending promotion message: $e');
      }
    }
  }

  dart_async.Future<void> setCoOwner(
    String targetUserId,
    bool isCoOwner,
  ) async {
    if (_roomId == null) return;
    if (!await _isOwner()) throw Exception("ليس لديك صلاحية المالك");

    if (isCoOwner) {
      // Check if user is a room member first
      final memberDoc = await _db
          .collection('rooms')
          .doc(_roomId)
          .collection('members')
          .doc(targetUserId)
          .get();

      if (!memberDoc.exists) {
        throw Exception("لا يمكن منح رتبة نائب لمستخدم غير منضم لعضوية الغرفة");
      }

      await _db.collection('rooms').doc(_roomId).update({
        'coOwners.$targetUserId': true,
      });

      dart_async.unawaited(
        _logPenalty(targetUserId: targetUserId, action: 'set_co_owner'),
      );

      try {
        final userDoc = await _db.collection('users').doc(targetUserId).get();
        final nickname =
            userDoc.data()?['nickname'] ?? userDoc.data()?['username'] ?? 'عضو';
        dart_async.unawaited(
          sendSystemMessage(
            'مبروك لـ $nickname لقد تم ترقيتك الى نائب من قبل المالك',
          ),
        );
      } catch (e) {
        debugPrint('Error sending promotion message: $e');
      }
    } else {
      await _db.collection('rooms').doc(_roomId).update({
        'coOwners.$targetUserId': FieldValue.delete(),
        'admins.$targetUserId': FieldValue.delete(),
      });

      dart_async.unawaited(
        _logPenalty(targetUserId: targetUserId, action: 'remove_co_owner'),
      );
    }
  }

  dart_async.Future<void> setMicLayoutType(String layoutType) async {
    if (_roomId == null) return;
    if (!await _isOwner()) throw Exception("ليس لديك صلاحية المالك");

    await _db.collection('rooms').doc(_roomId).update({
      'micLayoutType': layoutType,
    });
    notifyListeners();
  }

  dart_async.Future<void> pinAnnouncement(String text) async {
    if (_roomId == null) return;
    if (!isAdmin(currentUserId!) && !isCoOwner(currentUserId!) && !isHost) {
      throw Exception("ليس لديك صلاحية القيام بهذا الإجراء");
    }
    await _db.collection('rooms').doc(_roomId).update({
      'announcement': text.trim(),
    });
  }

  dart_async.Future<void> kickFromSeat(String targetUserId) async {
    if (_roomId == null) return;
    if (targetUserId == _hostId) {
      throw Exception("لا يمكن إنزال صاحب الغرفة من الكرسي");
    }
    if (!isAdmin(currentUserId!) && !isCoOwner(currentUserId!) && !isHost) {
      throw Exception("ليس لديك صلاحية القيام بهذا الإجراء");
    }
    await _removeUserFromSeat(targetUserId);
    dart_async.unawaited(
      _logPenalty(targetUserId: targetUserId, action: 'kick_from_seat'),
    );
  }

  dart_async.Future<void> clearRoomMessages() async {
    if (_roomId == null) return;
    if (!await _isOwner()) throw Exception("ليس لديك صلاحية المالك");

    // 1. Clear Local State immediately for the user
    _messages = [];
    notifyListeners();

    // 2. Clear Realtime Database (RTDB) - The main live feed
    try {
      await _rtdb.ref('rooms/$_roomId/messages').remove();
    } catch (e) {
      print('[clearRoomMessages] RTDB removal failed: $e');
    }

    // 3. Clear Firestore Collection (Historical Archive)
    final roomRef = _db.collection('rooms').doc(_roomId);
    final msgsQuery = await roomRef.collection('messages').get();

    if (msgsQuery.docs.isEmpty) return;

    WriteBatch batch = _db.batch();
    int count = 0;
    for (final doc in msgsQuery.docs) {
      batch.delete(doc.reference);
      count++;
      if (count >= 450) {
        // Safe batch limit (Firestore limit is 500)
        await batch.commit();
        batch = _db.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit();
    }
  }

  dart_async.Future<void> _removeUserFromSeat(String targetUserId) async {
    if (_roomId == null) return;
    final roomRef = _db.collection('rooms').doc(_roomId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;

      final rawSeats = snapshot.data()?['seats'];
      List<dynamic> currentSeats = List.generate(10, (index) => null);

      if (rawSeats is List) {
        for (int i = 0; i < rawSeats.length && i < 10; i++) {
          currentSeats[i] = rawSeats[i];
        }
      }

      bool changed = false;
      for (int i = 0; i < currentSeats.length; i++) {
        final seat = currentSeats[i];
        if (seat != null && seat is Map && seat['userId'] == targetUserId) {
          currentSeats[i] = null;
          changed = true;
        }
      }

      if (changed) {
        transaction.update(roomRef, {'seats': currentSeats});
      }
    });
  }

  dart_async.Future<void> toggleSeatLock(int index) async {
    if (_roomId == null) return;

    // 1. OPTIMISTIC LOCAL UPDATE
    _isTakingSeat = true; // Block snapshots from overwriting local state

    final currentSeat = _seats[index] ?? {};
    final bool newLockState = !(currentSeat['isLocked'] == true);

    // Update local state copy
    _seats[index] = Map<String, dynamic>.from(currentSeat);
    _seats[index]!['isLocked'] = newLockState;

    print(
      "[Admin] toggleSeatLock (Optimistic): Seat $index -> ${newLockState ? 'LOCKED' : 'UNLOCKED'}",
    );

    notifyListeners();

    // 2. BACKGROUND WORK
    dart_async.unawaited(_performSeatLockTransaction(index, newLockState));
  }

  dart_async.Future<void> _performSeatLockTransaction(
    int index,
    bool newLockState,
  ) async {
    try {
      final roomRef = _db.collection('rooms').doc(_roomId);
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;

        List<dynamic> currentSeats = List.from(
          snapshot.data()?['seats'] ?? List.filled(10, null),
        );

        Map<String, dynamic> seatData = {};
        if (index < currentSeats.length && currentSeats[index] is Map) {
          seatData = Map<String, dynamic>.from(currentSeats[index]);
        }

        seatData['isLocked'] = newLockState;

        // Ensure the list is at least long enough
        while (currentSeats.length <= index) currentSeats.add(null);
        currentSeats[index] = seatData;

        transaction.update(roomRef, {'seats': currentSeats});
      }, timeout: const Duration(seconds: 10)); // Safety timeout

      print("[Admin] toggleSeatLock success on server.");
    } catch (e) {
      print("[Admin] toggleSeatLock ERROR: $e");
    } finally {
      // Allow snapshots to resume after a short delay to allow Firestore propagation
      dart_async.Future.delayed(const Duration(seconds: 2), () {
        _isTakingSeat = false;
        notifyListeners(); // Refresh from the actual server state finally
      });
    }
  }

  dart_async.Future<void> inviteToSeat(String userId, int index) async {
    if (_roomId == null) return;
    final myId = currentUserId;
    if (myId == null) return;

    final sender = await UserService().getUser(myId);
    final senderName = sender?.nickname ?? sender?.username ?? "مستخدم ميتو";

    await _rtdb.ref('rooms/$_roomId/invitations/$userId').set({
      'type': 'mic',
      'senderId': myId,
      'senderName': senderName,
      'senderImage': sender?.profileImage,
      'seatIndex': index,
      'timestamp': ServerValue.timestamp,
    });

    dart_async.unawaited(
      _logPenalty(targetUserId: userId, action: 'invite_to_seat'),
    );
  }

  dart_async.Future<void> sendJoinInvitation(String userId) async {
    if (_roomId == null) return;
    final myId = currentUserId;
    if (myId == null) return;

    final sender = await UserService().getUser(myId);
    final senderName = sender?.nickname ?? sender?.username ?? "مستخدم ميتو";

    await _rtdb.ref('rooms/$_roomId/invitations/$userId').set({
      'type': 'join',
      'senderId': myId,
      'senderName': senderName,
      'senderImage': sender?.profileImage,
      'timestamp': ServerValue.timestamp,
    });
  }

  DateTime? _lastRecallTime;

  dart_async.Future<void> recallMembers() async {
    if (_roomId == null) return;

    // Antispam: Once every 5 minutes
    if (_lastRecallTime != null &&
        DateTime.now().difference(_lastRecallTime!).inMinutes < 5) {
      throw 'يمكنك استخدام ميزة الاستدعاء مرة كل 5 دقائق فقط';
    }

    final myId = currentUserId;
    if (myId == null) return;

    final roomData = _currentRoomData;
    if (roomData == null) return;
    final roomName = roomData['name'] ?? 'غرفة صوتية';

    final sender = await UserService().getUser(myId);
    final senderName = sender?.nickname ?? sender?.username ?? "مستخدم ميتو";

    _lastRecallTime = DateTime.now();

    // 1. Fetch all members
    final membersSnap = await _db
        .collection('rooms')
        .doc(_roomId!)
        .collection('members')
        .get();
    if (membersSnap.docs.isEmpty) return;

    final List<String> memberIds = membersSnap.docs
        .map((doc) => doc.id)
        .toList();

    // 2. Send notifications in background
    for (var targetUid in memberIds) {
      if (targetUid == myId) continue;
      _sendRecallNotification(targetUid, senderName, roomName, _roomId!);
    }
  }

  dart_async.Future<void> _sendRecallNotification(
    String targetUid,
    String senderName,
    String roomName,
    String roomId,
  ) async {
    try {
      // 1. Save to Firestore notifications
      await _db.collection('notifications').add({
        'receiverId': targetUid,
        'senderId': currentUserId,
        'senderName': senderName,
        'text': 'يدعوك $senderName للعودة إلى غرفة: $roomName',
        'type': 9, // Type 9 = Room Invite/Recall in main.dart
        'postId': roomId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // 2. Fetch FCM token
      final userDoc = await _db.collection('users').doc(targetUid).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await FCMService.sendNotification(
          deviceToken: fcmToken,
          title: 'استدعاء للأعضاء 🚀',
          body: 'يدعوك $senderName للعودة إلى غرفة: $roomName',
          data: {
            'type': '9',
            'postId': roomId,
            'senderId': currentUserId ?? '',
            'senderName': senderName,
          },
        );
      }
    } catch (e) {
      print('Error sending recall to $targetUid: $e');
    }
  }

  dart_async.Future<void> _updateSeatMuteStatus(
    String targetUserId,
    bool isMuted,
  ) async {
    if (_roomId == null) return;
    final roomRef = _db.collection('rooms').doc(_roomId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;

      final rawSeats = snapshot.data()?['seats'];
      if (rawSeats == null) return;

      List<dynamic> currentSeats = List.generate(10, (index) => null);
      if (rawSeats is List) {
        for (int i = 0; i < rawSeats.length && i < 10; i++) {
          currentSeats[i] = rawSeats[i];
        }
      }

      bool changed = false;
      for (int i = 0; i < currentSeats.length; i++) {
        final seat = currentSeats[i];
        if (seat != null && seat is Map && seat['userId'] == targetUserId) {
          final newSeat = Map<String, dynamic>.from(seat);
          newSeat['muted'] = isMuted;
          currentSeats[i] = newSeat;
          changed = true;
        }
      }

      if (changed) {
        transaction.update(roomRef, {'seats': currentSeats});
      }
    });
  }

  // --- Membership / Following ---

  dart_async.Future<void> followRoom(
    String roomId, {
    int? fee,
    bool justFollow = false,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw 'يجب تسجيل الدخول';

    if (fee != null && fee > 0 && !justFollow) {
      await _db.runTransaction((transaction) async {
        final userRef = _db.collection('users').doc(uid);
        final userSnap = await transaction.get(userRef);
        final int userDiamonds = userSnap.data()?['diamonds'] ?? 0;

        if (userDiamonds < fee) {
          throw 'رصيدك غير كافٍ للإنضمام للعضوية (المطلوب $fee ماسة)';
        }

        // 1. Deduct diamonds
        transaction.update(userRef, {'diamonds': FieldValue.increment(-fee)});

        // 2. Add to followedRooms
        transaction.update(userRef, {
          'followedRooms': FieldValue.arrayUnion([roomId]),
        });

        // 3. Mark as member in room list
        final memberRef = _db
            .collection('rooms')
            .doc(roomId)
            .collection('members')
            .doc(uid);
        transaction.set(memberRef, {
          'joinedAt': FieldValue.serverTimestamp(),
          'uid': uid,
          'paidFee': fee,
        });

        // 4. Record Transaction
        final transRef = _db.collection('membership_payments').doc();
        transaction.set(transRef, {
          'uid': uid,
          'roomId': roomId,
          'amount': fee,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // 5. User joined_rooms (Compatibility)
        final joinedRef = _db
            .collection('users')
            .doc(uid)
            .collection('joined_rooms')
            .doc(roomId);
        transaction.set(joinedRef, {'joinedAt': FieldValue.serverTimestamp()});
      });
    } else {
      // Normal Free Join or Just Follow
      await _db.collection('users').doc(uid).update({
        'followedRooms': FieldValue.arrayUnion([roomId]),
      });

      if (!justFollow) {
        await _db
            .collection('rooms')
            .doc(roomId)
            .collection('members')
            .doc(uid)
            .set({'joinedAt': FieldValue.serverTimestamp(), 'uid': uid});
      }

      // Compatibility
      if (!justFollow) {
        await _db
            .collection('users')
            .doc(uid)
            .collection('joined_rooms')
            .doc(roomId)
            .set({'joinedAt': FieldValue.serverTimestamp()});
      }
    }

    if (roomId == _roomId && !justFollow) {
      _isMember = true;
      notifyListeners();

      // Send join message to chat
      dart_async.unawaited(() async {
        try {
          final user = await UserService().getUser(uid);
          final name = user?.nickname ?? user?.username ?? 'عضو جديد';
          await sendSystemMessage('لقد انضم $name للغرفة');
        } catch (e) {
          debugPrint('Error sending join message: $e');
        }
      }());
    }
  }

  dart_async.Future<void> unfollowRoom(
    String roomId, {
    bool keepFollow = false,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await removeRoomMember(uid, roomId, keepFollow: keepFollow);
  }

  dart_async.Future<void> removeRoomMember(
    String targetUid,
    String roomId, {
    bool keepFollow = false,
  }) async {
    if (!keepFollow) {
      // 1. Update target user's followed list
      await _db.collection('users').doc(targetUid).update({
        'followedRooms': FieldValue.arrayRemove([roomId]),
      });

      // 2. Remove from user's joined_rooms sub-collection
      await _db
          .collection('users')
          .doc(targetUid)
          .collection('joined_rooms')
          .doc(roomId)
          .delete();
    }

    // 3. Remove from room's members sub-collection
    await _db
        .collection('rooms')
        .doc(roomId)
        .collection('members')
        .doc(targetUid)
        .delete();

    // 4. Remove from roles in room doc
    await _db.collection('rooms').doc(roomId).update({
      'admins.$targetUid': FieldValue.delete(),
      'coOwners.$targetUid': FieldValue.delete(),
    });

    if (targetUid == currentUserId && roomId == _roomId) {
      _isMember = false;
      notifyListeners();
    }
  }

  Stream<bool> isRoomFollowedStream(String roomId) {
    final uid = _auth.currentUser?.uid;
    // Optimistic check via user stream if available, or fetch
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return false;
      final data = snap.data();
      final List list = (data?['followedRooms'] as List?) ?? [];
      return list.contains(roomId);
    });
  }

  Stream<bool> isRoomMemberStream(String roomId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('members')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  Stream<List<User>> getRoomMembersStream(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('members')
        .orderBy('joinedAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          final uids = snap.docs.map((d) => d.id).toSet();

          // Ensure Host is included
          try {
            final roomSnap = await _db.collection('rooms').doc(roomId).get();
            final hostId = roomSnap.data()?['hostId'];
            if (hostId != null) {
              uids.add(hostId);
            }
          } catch (e) {
            // fail safe
          }

          if (uids.isEmpty) return <User>[];

          List<User> users = [];
          for (final uid in uids) {
            final user = await UserService().getUser(uid);
            if (user != null) users.add(user);
          }
          return users;
        });
  }

  Timer? _speakerCleanupTimer;

  void _startSpeakerCleanupTimer() {
    _speakerCleanupTimer?.cancel();
    _speakerCleanupTimer = dart_async.Timer.periodic(
      const Duration(milliseconds: 400),
      (timer) {
        if (!_isJoined || _activeSpeakers.isEmpty) return;

        final now = DateTime.now();
        bool changed = false;

        // Filter out speakers who haven't been heard in the last 1.2 seconds
        // Reduced from 2.5s to 1.2s for faster response
        _activeSpeakers.removeWhere((uid) {
          final lastHeard = _talkingHoldMap[uid];
          if (lastHeard == null ||
              now.difference(lastHeard).inMilliseconds > 1200) {
            _userVolumeLevels.remove(uid);
            changed = true;
            return true;
          }
          return false;
        });

        if (changed) {
          notifyListeners();
        }
      },
    );
  }

  @override
  void dispose() {
    _speakerCleanupTimer?.cancel();
    _rtdbPresenceSubscription?.cancel();
    _reactionsSubscription?.cancel();
    _roomSubscription?.cancel();
    _messagesSubscription?.cancel();
    _userDocSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();
    _musicProgressTimer?.cancel();
    _giftBgsSubscription?.cancel();
    _shopBgsSubscription?.cancel();
    _engine.stopAudioMixing();
    _engine.release();
    super.dispose();
  }

  void _startBackgroundSubscriptions() {
    _giftBgsSubscription?.cancel();
    _shopBgsSubscription?.cancel();
    _giftBgsSubscription = null;
    _shopBgsSubscription = null;

    _auth.authStateChanges().listen((user) {
      if (user == null) {
        _giftBgsSubscription?.cancel();
        _shopBgsSubscription?.cancel();
        _giftBgsSubscription = null;
        _shopBgsSubscription = null;
        return;
      }

      if (_giftBgsSubscription == null) {
        _giftBgsSubscription = GiftService().getBackgroundsStream().listen(
          (bgs) {
            _lastGiftBgs = bgs;
            _updateCombinedBackgrounds();
          },
          onError: (e) {
            print("Error fetching gift backgrounds: $e");
          },
          cancelOnError: false,
        );
      }

      if (_shopBgsSubscription == null) {
        _shopBgsSubscription = ShopService()
            .getAllShopBackgroundsStream()
            .listen(
              (bgs) {
                _lastShopBgs = bgs;
                _updateCombinedBackgrounds();
              },
              onError: (e) {
                print("Error fetching shop backgrounds: $e");
              },
              cancelOnError: false,
            );
      }
    });
  }

  void _updateCombinedBackgrounds() {
    final Map<String, RoomBackground> unique = {};
    for (var bg in predefinedBackgrounds) {
      unique[bg.id] = bg;
    }
    for (var bg in _lastGiftBgs) {
      unique[bg.id] = bg;
    }
    for (var bg in _lastShopBgs) {
      unique[bg.id] = bg;
    }
    _allBackgrounds = unique.values.toList();
    notifyListeners();
  }

  dart_async.Future<String?> startRoomTicTacToe() async {
    if (_roomId == null) return null;
    final user = _auth.currentUser;
    if (user == null) return null;

    if (!isHost && !isAdmin(user.uid) && !isCoOwner(user.uid)) {
      return null;
    }

    final userData = await _db.collection('users').doc(user.uid).get();
    final userName =
        userData.data()?['nickname'] ??
        userData.data()?['username'] ??
        'المالك';

    final newGameRef = _db.collection('games').doc();
    await newGameRef.set({
      'type': 'tictactoe',
      'roomId': _roomId,
      'players': [user.uid],
      'playerNames': {user.uid: userName},
      'currentTurn': user.uid,
      'data': {'board': List.filled(9, '')},
      'scores': {user.uid: 0},
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('rooms').doc(_roomId).update({
      'activeGameId': newGameRef.id,
      'activeGameType': 'tictactoe',
    });

    await sendSystemMessage(
      'قام $userName ببدأ لعبة إكس أو! اضغط هنا للانضمام',
      type: 'game_invite',
      senderId: user.uid,
      senderName: userName,
      gameId: newGameRef.id,
    );

    return newGameRef.id;
  }

  dart_async.Future<void> joinRoomGame(String gameId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userData = await _db.collection('users').doc(user.uid).get();
    final userName =
        userData.data()?['nickname'] ?? userData.data()?['username'] ?? 'لاعب';

    final gameDoc = await _db.collection('games').doc(gameId).get();
    if (!gameDoc.exists) return;

    final players = List<String>.from(gameDoc.data()?['players'] ?? []);
    if (players.length >= 2 && !players.contains(user.uid)) {
      return;
    }

    if (!players.contains(user.uid)) {
      await _db.collection('games').doc(gameId).update({
        'players': FieldValue.arrayUnion([user.uid]),
        'playerNames.${user.uid}': userName,
        'status': 'active',
      });
    }
  }
}
