import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoomLevelSystem {
  static const int maxLevel = 65;

  /// Calculate the XP required to reach the next level from the current level.
  /// Formula: Higher levels require progressively more XP.
  static double getRequiredXPForLevel(int level) {
    if (level < 1) return 5000;
    if (level >= maxLevel) return 0;
    
    // Example curve: 
    // Level 1 -> 2: 5,000
    // Level 10 -> 11: 15,000
    // Level 40 -> 41: 1.6M
    // Level 64 -> 65: ~4.2M
    return (pow(level, 2) * 1000).toDouble() + 5000.0;
  }

  /// Get progress towards the next level (0.0 to 1.0)
  static double getLevelProgress(int currentLevel, double currentXP) {
    if (currentLevel >= maxLevel) return 1.0;
    double required = getRequiredXPForLevel(currentLevel);
    if (required <= 0) return 1.0;
    return (currentXP / required).clamp(0.0, 1.0);
  }

  /// Convert currency/time into Room XP
  static double calculateXP({
    int diamonds = 0,
    int gold = 0,
    int meto = 0,
    int minutesOnMic = 0,
  }) {
    double xp = 0.0;

    // 1 Diamond = 1 Point (So 200 Diamonds = 200 Points Daily Cap)
    xp += diamonds * 1.0;

    // 20,000 Gold = 200 Points => 1 Gold = 0.01 Points (100 Gold = 1 Point)
    xp += gold * 0.01;

    // Meto chips (if used) matching diamond value
    xp += meto * 1.0;

    // 30 Minutes on Seat = 200 Points => 1 Minute = 6.6666... Points
    xp += minutesOnMic * (200 / 30.0);

    return xp;
  }

  /// Central method to award points to a room with a daily user-specific cap of 200.
  /// This handles:
  /// 1. 00:00 reset check
  /// 2. User's daily contribution quota (Max 200)
  /// 3. Room leveling up
  static Future<void> awardPointsToRoom({
    required double pointsToAward,
    required String roomId,
    required String userId,
    Transaction? activeTransaction, // Allows participating in an existing transaction (e.g. Gift transaction)
  }) async {
    final FirebaseFirestore db = FirebaseFirestore.instance;
    
    // Helper to execute the logic either inside a transaction or standalone
    Future<void> runLogic(Transaction transaction) async {
       final userRef = db.collection('users').doc(userId);
       final roomRef = db.collection('rooms').doc(roomId);
        
       // 1. Fetch User Data for Quota
       final userSnapshot = await transaction.get(userRef);
       final roomSnapshot = await transaction.get(roomRef);
        
       if (!userSnapshot.exists || !roomSnapshot.exists) return;
        
       final userData = userSnapshot.data() as Map<String, dynamic>;
       final roomData = roomSnapshot.data() as Map<String, dynamic>;

       // --- Daily Quota Logic (Resets at 00:00) ---
       final now = DateTime.now();
       final lastResetStr = userData['lastRoomPointsReset'];
       double todayPointsUsed = (userData['dailyRoomPointsContributed'] ?? 0.0).toDouble();
        
       bool needsReset = false;
       if (lastResetStr == null) {
         needsReset = true;
       } else {
         final lastReset = DateTime.parse(lastResetStr);
         // Check if current day is different from last reset day (at 00:00 local)
         if (now.year != lastReset.year || now.month != lastReset.month || now.day != lastReset.day) {
           needsReset = true;
         }
       }
        
       if (needsReset) {
         todayPointsUsed = 0.0;
       }
        
       const double dailyCap = 200.0;
       final double remainingQuota = (dailyCap - todayPointsUsed).clamp(0.0, dailyCap);
        
       // Final points actual added to room
       final double actualXPAdded = pointsToAward.clamp(0.0, remainingQuota);
        
       if (actualXPAdded <= 0) return; // Quota reached for today

       // --- Update User Quota ---
       transaction.update(userRef, {
         'dailyRoomPointsContributed': todayPointsUsed + actualXPAdded,
         'lastRoomPointsReset': DateTime(now.year, now.month, now.day).toIso8601String(),
       });

       // --- Update Room Level ---
       int currentRoomLevel = roomData['roomLevel'] ?? 1;
       double currentRoomXP = (roomData['roomXP'] ?? 0.0).toDouble();
       double requiredXP = getRequiredXPForLevel(currentRoomLevel);
        
       double newRoomXP = currentRoomXP + actualXPAdded;
       int newRoomLevel = currentRoomLevel;
        
       while (newRoomLevel < maxLevel && newRoomXP >= requiredXP) {
         newRoomXP -= requiredXP;
         newRoomLevel++;
         requiredXP = getRequiredXPForLevel(newRoomLevel);
       }

       transaction.update(roomRef, {
         'roomLevel': newRoomLevel,
         'roomXP': newRoomXP,
       });
    }

    try {
      if (activeTransaction != null) {
        await runLogic(activeTransaction);
      } else {
        await db.runTransaction((transaction) => runLogic(transaction));
      }
    } catch (e) {
      print("[awardPointsToRoom] Error: $e");
      rethrow; // Important to rethrow so transaction knows it failed
    }
  }
}
