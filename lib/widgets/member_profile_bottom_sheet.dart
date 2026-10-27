import 'package:flutter/material.dart';
import 'package:mmmm/screens/profile_screen.dart';
import '../models/user_model.dart';
import '../services/voice_room_service.dart';
import '../screens/chat_screen.dart';
import 'gift_selection_bottom_sheet.dart';
import 'frame_selection_bottom_sheet.dart';
import 'room_user_management_sheet.dart';
import 'package:mmmm/services/user_service.dart';
import 'framed_avatar.dart';

class MemberProfileBottomSheet extends StatelessWidget {
  final User user;
  final VoiceRoomService service;
  final Function(String)? onMention;

  const MemberProfileBottomSheet({
    super.key,
    required this.user,
    required this.service,
    this.onMention,
  });

  static void show(
    BuildContext context,
    VoiceRoomService service,
    User user, {
    Function(String)? onMention,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MemberProfileBottomSheet(
        user: user,
        service: service,
        onMention: onMention,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<User?>>(
      future: Future.wait([
        UserService().getUser(user.uid),
        UserService().getUser(service.currentUserId ?? ""),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final List<User?> users = snapshot.data ?? [null, null];
        final displayUser = users[0] ?? user;
        final currentUser = users[1];

        final myId = service.currentUserId;
        final bool isUserMuted = service.isUserMuted(displayUser.uid);
        final bool isMe = myId == displayUser.uid;
        service.seats.any((s) => s != null && s['userId'] == displayUser.uid);

        // Check for follow relationship (Robust check from both sides)
        final bool iAmFollowing =
            currentUser?.following.contains(displayUser.uid) ?? false;
        final bool heIsFollowerOfMe = displayUser.followers.contains(myId);

        final bool isFollowing = iAmFollowing || heIsFollowerOfMe;

        // Hierarchical Permissions
        final bool amIOwner = service.hostId == myId;
        final bool amIDeputy = service.isCoOwner(myId ?? "");
        final bool amIAdmin = service.isAdmin(myId ?? "");

        final bool isTargetOwner = displayUser.uid == service.hostId;
        final bool isTargetDeputy = service.isCoOwner(displayUser.uid);
        final bool isTargetAdmin = service.isAdmin(displayUser.uid);

        bool canManageTarget = false;
        if (amIOwner) {
          canManageTarget = !isMe;
        } else if (amIDeputy) {
          canManageTarget = !isMe && !isTargetOwner && !isTargetDeputy;
        } else if (amIAdmin) {
          canManageTarget =
              !isMe && !isTargetOwner && !isTargetDeputy && !isTargetAdmin;
        }

        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // 0. Tap-to-Dismiss Layer (Transparent background)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
            // 1. Main Content Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.95),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.only(
                top: 55,
                bottom: 30,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name & Gender/Age Row
                  SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayUser.nickname ?? displayUser.username,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontSize: 18,

                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Gender Icon with background
                      if (displayUser.gender != null &&
                          displayUser.gender!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (displayUser.gender!.toLowerCase() == 'male' ||
                                    displayUser.gender == 'ذكر')
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.pink.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Image.asset(
                            (displayUser.gender!.toLowerCase() == 'male' ||
                                    displayUser.gender == 'ذكر')
                                ? 'assets/images/maile/Male.png'
                                : 'assets/images/maile/Female.png',
                            width: 18,
                            height: 18,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ID & Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatItem(
                        "ID: ${displayUser.displayId ?? displayUser.uid}",
                        Icons.fingerprint,
                      ),
                      const SizedBox(width: 15),
                      _buildStatItem(
                        "${displayUser.followersCount} متابع",
                        Icons.people_outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Badges Row (Modern Tags)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      // Level Tag
                      _buildModernTag(
                        label: "Lv.${displayUser.level}",
                        color: Colors.green.shade400,
                      ),
                      // Country Tag
                      _buildModernTag(
                        label: _getCountryName(displayUser.country),
                        color: Colors.blue.shade400,
                        emoji: _getCountryFlag(displayUser.country),
                      ),
                      // Role Tag
                      if (isTargetOwner)
                        _buildModernTag(
                          label: "المالك",
                          color: Colors.purple.shade400,
                          icon: Icons.stars,
                        )
                      else if (isTargetDeputy)
                        _buildModernTag(
                          label: "النائب",
                          color: Colors.amber.shade400,
                          icon: Icons.shield,
                        )
                      else if (isTargetAdmin)
                        _buildModernTag(
                          label: "المشرف",
                          color: Colors.teal.shade400,
                          icon: Icons.security,
                        ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Bottom Action Bar (Modern Horizontal Icons)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildBottomAction(
                          icon: Icons.person_outline_rounded,
                          label: "فتح الملف",
                          color: Colors.blue.shade300,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProfileScreen(uid: displayUser.uid),
                              ),
                            );
                          },
                        ),
                        if (!isMe && isFollowing)
                          _buildBottomAction(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: "دردشة",
                            color: Colors.purple.shade300,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    receiverId: displayUser.uid,
                                    receiverName:
                                        displayUser.nickname ??
                                        displayUser.username,
                                    receiverImage: displayUser.profileImage,
                                  ),
                                ),
                              );
                            },
                          )
                        else if (!isMe)
                          _buildBottomAction(
                            icon: Icons.person_add_alt_1_rounded,
                            label: "متابعة",
                            color: Colors.green.shade300,
                            onTap: () async {
                              try {
                                await UserService().followUser(
                                  currentUserId: myId!,
                                  currentUsername:
                                      currentUser?.nickname ??
                                      currentUser?.username ??
                                      "",
                                  currentUserProfileImage:
                                      currentUser?.profileImage,
                                  userToFollowId: displayUser.uid,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("تمت المتابعة بنجاح"),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            },
                          ),
                        if (canManageTarget)
                          _buildBottomAction(
                            icon: isUserMuted
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            label: isUserMuted ? "إلغاء كتم" : "كتم",
                            color: isUserMuted
                                ? Colors.green.shade400
                                : Colors.white60,
                            onTap: () async {
                              if (isUserMuted)
                                await service.unmuteUser(displayUser.uid);
                              else
                                await service.muteUser(displayUser.uid);
                              if (!context.mounted) return;
                              Navigator.pop(context);
                            },
                          ),
                        // Frame Action
                        _buildBottomAction(
                          imageAsset: 'assets/images/itar.png',
                          label: "إطار",
                          color: Colors.amber.shade400,
                          onTap: () {
                            Navigator.pop(context);
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => FrameSelectionBottomSheet(
                                targetUserId: displayUser.uid,
                                targetUserName:
                                    displayUser.nickname ??
                                    displayUser.username,
                                targetUserAvatar: displayUser.profileImage,
                              ),
                            );
                          },
                        ),
                        // Gift Action (Moved to Main Bar)
                        if (!isMe)
                          _buildBottomAction(
                            icon: Icons.card_giftcard_rounded,
                            label: "هدية",
                            color: Colors.pink.shade300,
                            onTap: () {
                              Navigator.pop(context);
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => GiftSelectionBottomSheet(
                                  receiverId: displayUser.uid,
                                  receiverName:
                                      displayUser.nickname ??
                                      displayUser.username,
                                  roomId: service.currentRoomId,
                                  senderId: service.currentUserId ?? '',
                                  senderName: currentUser?.nickname ??
                                      currentUser?.username ??
                                      'أنت',
                                ),
                              );
                            },
                          ),
                        // Management Action (Replaces More)
                        if (canManageTarget)
                          _buildBottomAction(
                            icon: Icons.settings_suggest_rounded,
                            label: "إدارة",
                            color: Colors.orange.shade400,
                            onTap: () {
                              Navigator.pop(context);
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) => RoomUserManagementSheet(
                                  targetUser: displayUser,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Avatar (Floating Above)
            Positioned(
              bottom: 275, // Adjust based on content height
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1A1A1A), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: FramedAvatar(
                  userId: displayUser.uid,
                  imageUrl: displayUser.profileImage,
                  radius: 45,
                  useProfileFrameFallback: false,
                ),
              ),
            ),

            // 3. Report Button (Top Right of Card)
            if (!isMe)
              Positioned(
                bottom: 250,
                right: 20,
                child: IconButton(
                  icon: const Icon(
                    Icons.report_gmailerrorred_rounded,
                    color: Colors.white38,
                    size: 24,
                  ),
                  onPressed: () =>
                      _showReportDialog(context, displayUser, service),
                ),
              ),

            // 4. Mention Button (Top Left of Card)
            if (!isMe && onMention != null)
              Positioned(
                bottom: 250,
                left: 20,
                child: IconButton(
                  icon: const Icon(
                    Icons.alternate_email_rounded,
                    color: Colors.white38,
                    size: 24,
                  ),
                  onPressed: () {
                    onMention!(displayUser.nickname ?? displayUser.username);
                    Navigator.pop(context);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  // Helper to build a stat item (ID, Followers)
  Widget _buildStatItem(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white30, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Helper to build a modern capsule tag
  Widget _buildModernTag({
    required String label,
    required Color color,
    IconData? icon,
    String? emoji,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, color: color, size: 12),
          if (emoji != null) Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build bottom action bar items
  Widget _buildBottomAction({
    IconData? icon,
    String? imageAsset,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageAsset != null)
            Image.asset(imageAsset, width: 26, height: 26)
          else if (icon != null)
            Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  // Show a secondary sheet for less frequent actions (Manage/Gift)

  String _getCountryName(String? code) {
    if (code == null || code.isEmpty) return "عالمي";
    // Remove flag emojis and extra spaces from the name
    return code
        .replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true), '')
        .trim();
  }

  String _getCountryFlag(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return "🌍";

    final flagRegex = RegExp(r'[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true);
    final match = flagRegex.firstMatch(countryCode);
    if (match != null) return match.group(0)!;

    final Map<String, String> countryToFlag = {
      'Iraq': '🇮🇶',
      'العراق': '🇮🇶',
      'عراق': '🇮🇶',
      'Saudi Arabia': '🇸🇦',
      'السعودية': '🇸🇦',
      'سعودية': '🇸🇦',
      'Egypt': '🇪🇬',
      'مصر': '🇪🇬',
      'Jordan': '🇯🇴',
      'الأردن': '🇯🇴',
      'UAE': '🇦🇪',
      'الإمارات': '🇦🇪',
      'Kuwait': '🇰🇼',
      'الكويت': '🇰🇼',
      'Qatar': '🇶🇦',
      'قطر': '🇶🇦',
      'Morocco': '🇲🇦',
      'المغرب': '🇲🇦',
    };

    final String trimmed = countryCode.trim();
    if (countryToFlag.containsKey(trimmed)) return countryToFlag[trimmed]!;

    if (trimmed.length == 2) {
      try {
        return trimmed.toUpperCase().replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) =>
              String.fromCharCode(match.group(0)!.codeUnitAt(0) + 127397),
        );
      } catch (e) {
        return "🌍";
      }
    }
    return "🌍";
  }

  void _showReportDialog(
    BuildContext context,
    User targetUser,
    VoiceRoomService service,
  ) {
    String? selectedReason;
    final TextEditingController textController = TextEditingController();
    final List<String> quickReasons = [
      "سلوك غير لائق",
      "إزعاج في الغرفة",
      "انتحال شخصية",
      "كلام بذيء",
      "أخرى",
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: const Text(
            "إبلاغ عن مستخدم",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: quickReasons.map((reason) {
                    final bool isSelected = selectedReason == reason;
                    return ChoiceChip(
                      label: Text(
                        reason,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(
                          () => selectedReason = selected ? reason : null,
                        );
                      },
                      selectedColor: const Color(0xFFC2185B),
                      backgroundColor: Colors.grey.shade100,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: "اكتب سبب البلاغ هنا...",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC2185B),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () async {
                    final finalReason =
                        selectedReason ?? textController.text.trim();
                    if (finalReason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى اختيار سبب للبلاغ')),
                      );
                      return;
                    }

                    try {
                      final currentUid = service.currentUserId;
                      if (currentUid == null) return;

                      await UserService().reportUser(
                        currentUserId: currentUid,
                        userToReportId: targetUser.uid,
                        reason: finalReason,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إرسال بلاغك بنجاح.. شكراً لك'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل إرسال البلاغ: $e')),
                        );
                      }
                    }
                  },
                  child: const Text(
                    "إرسال البلاغ الآن",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
