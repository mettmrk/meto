import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'store_screen.dart';
import '../services/voice_room_service.dart';
import '../models/user_model.dart';
import '../widgets/background_selection_bottom_sheet.dart';
import '../utils/room_tier_system.dart';

void showRoomMenu({
  required BuildContext context,
  required VoiceRoomService service,
  required String roomId,
  required Map<String, dynamic> roomData,
  VoidCallback? onShareTap,
}) {
  final currentUid = service.currentUserId ?? "";
  final isHost = currentUid == roomData['hostId'];
  final isCoOwner = service.isCoOwner(currentUid);
  final isAdmin = service.isAdmin(currentUid);
  final canRecall = isHost || isCoOwner;
  final canShowSettings = isHost;
  final canPinAnnouncement = isHost || isCoOwner || isAdmin;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Consumer<VoiceRoomService>(
      builder: (context, service, _) => Container(
        height: MediaQuery.of(context).size.height * 0.5, // Half screen (50%)
        decoration: const BoxDecoration(
          color: Color(0xFF101920),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 20),
                  // --- SECTION 1: TOP TOOLS (Unlabeled) ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    childAspectRatio: 0.72,
                    children: [
                      _buildMenuItem(
                        icon: Icons.reply_rounded,
                        label: "مشاركة",
                        color: Colors.blueAccent,
                        onTap: () {
                          Navigator.pop(ctx);
                          onShareTap?.call();
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.mic_none_rounded,
                        label: "مشكلات الصوت",
                        color: Colors.blueAccent,
                        onTap: () {},
                      ),
                      _buildMenuItem(
                        icon: Icons.equalizer_rounded,
                        label: "تقليل الضوضاء",
                        color: Colors.tealAccent,
                        hasSwitch: true,
                        isToggled: service.noiseReductionEnabled,
                        onTap: () => service.toggleNoiseReduction(),
                      ),
                      _buildMenuItem(
                        imageAsset: 'assets/images/purple_gift_box.png',
                        label: "إعدادات الهدايا",
                        color: Colors.blueAccent,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Eye Care row (right aligned)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildMenuItem(
                        icon: Icons.bubble_chart_rounded,
                        label: "الفقاعات",
                        color: Colors.lightBlueAccent,
                        hasSwitch: true,
                        isToggled: service.showAmbientBubbles,
                        onTap: () => service.toggleAmbientBubbles(),
                      ),
                      const SizedBox(width: 15),
                      _buildMenuItem(
                        icon: Icons.bedtime_rounded,
                        label: "راحة العين",
                        color: Colors.lightBlueAccent,
                        hasSwitch: true,
                        isToggled: service.eyeCareEnabled,
                        onTap: () => service.toggleEyeCare(),
                      ),
                    ],
                  ),

                  // --- SECTION 2: ROOM SETTINGS ---
                  if (canShowSettings || canPinAnnouncement) ...[
                    _buildSectionHeader("إعدادات الغرفة"),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      childAspectRatio: 0.72,
                      mainAxisSpacing: 15,
                      children: [
                        if (canShowSettings) ...[
                          _buildMenuItem(
                            icon: Icons.palette_rounded,
                            label: "موضوع",
                            color: Colors.orangeAccent,
                            onTap: () {
                              Navigator.pop(ctx);
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) =>
                                    BackgroundSelectionBottomSheet(
                                      roomId: roomId,
                                      currentBackgroundId:
                                          roomData['backgroundId'] ??
                                          roomData['roomBackground'] ??
                                          'default_cosmic',
                                    ),
                              );
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.lock_rounded,
                            label: "قفل الغرفة",
                            color: Colors.amber,
                            onTap: () {
                              Navigator.pop(ctx);
                              _showLockRoomDialog(context, service, roomId);
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.vertical_align_top_rounded,
                            label: "التثبيت الأعلى",
                            color: Colors.greenAccent,
                            onTap: () {
                              Navigator.pop(ctx);
                              _showPinToTopDialog(context, service, roomId);
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.settings_voice_rounded,
                            label: "نمط المايكات",
                            color: Colors.amber,
                            onTap: () {
                              Navigator.pop(ctx);
                              _showMicLayoutDialog(
                                context,
                                service,
                                roomId,
                                roomData,
                              );
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.cleaning_services_rounded,
                            label: "مسح الرسائل",
                            color: Colors.yellowAccent,
                            onTap: () {
                              Navigator.pop(ctx);
                              _showClearMessagesConfirmDialog(context, service);
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.workspace_premium_rounded,
                            label: "ترقية",
                            color: Colors.purpleAccent,
                            onTap: () {
                              Navigator.pop(ctx);
                              _showUpgradeRoomDialog(
                                context,
                                service,
                                roomId,
                                roomData,
                              );
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.credit_card_rounded,
                            label: "المكافآت اليومية",
                            color: Colors.amber,
                            onTap: () {},
                          ),
                          _buildMenuItem(
                            icon: Icons.settings_rounded,
                            label: "الإعدادات",
                            color: Colors.amberAccent,
                            onTap: () {
                              Navigator.pop(ctx);
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) => _PremiumSettingsSheet(
                                  service: service,
                                  roomId: roomId,
                                  initialData: roomData,
                                ),
                              );
                            },
                          ),
                          if (roomData['roomTier'] == 5) ...[
                            _buildMenuItem(
                              icon: Icons.auto_awesome_rounded,
                              label: "ترحيب مخصص",
                              color: Colors.pinkAccent,
                              onTap: () {
                                Navigator.pop(ctx);
                                _showCustomWelcomeDialog(
                                  context,
                                  service,
                                  roomData,
                                );
                              },
                            ),
                            _buildMenuItem(
                              icon: Icons.chair_rounded,
                              label: "لون الكراسي",
                              color: Colors.cyanAccent,
                              onTap: () {
                                Navigator.pop(ctx);
                                _showChairColorPicker(
                                  context,
                                  service,
                                  roomData,
                                );
                              },
                            ),
                          ],
                        ],
                        if (canPinAnnouncement)
                          _buildMenuItem(
                            icon: Icons.announcement_rounded,
                            label: "تثبيت إعلان",
                            color: Colors.cyanAccent,
                            onTap: () {
                              Navigator.pop(ctx);
                              _showEditAnnouncementDialog(
                                context,
                                service,
                                roomData['announcement'] ?? '',
                              );
                            },
                          ),
                      ],
                    ),
                  ],

                  // --- SECTION 3: HOST/ADMIN EXTENDED (Gifts, Earnings, Rewards, etc.) ---
                  // --- SECTION 3: OTHERS ---
                  _buildSectionHeader("أخرى"),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    childAspectRatio: 0.72,
                    children: [
                      _buildMenuItem(
                        imageAsset: 'assets/images/opnebox.png',
                        label: "أرباحي",
                        color: Colors.amber,
                        onTap: () {},
                      ),
                      _buildMenuItem(
                        icon: Icons.shopping_cart_rounded,
                        label: "المتجر",
                        color: Colors.amber,
                        onTap: () {
                          Navigator.pop(ctx);
                          final currentUserId = service.currentUserId ?? '';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) =>
                                  StoreScreen(userId: currentUserId),
                            ),
                          );
                        },
                      ),
                      _buildMenuItem(
                        icon: Icons.thumb_up_rounded,
                        label: "توصية للأصدقاء",
                        color: Colors.tealAccent,
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            await service.recommendRoomToFriends(roomId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تمت التوصية بالغرفة لأصدقائك بنجاح!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ: $e')),
                              );
                            }
                          }
                        },
                      ),
                      if (canRecall)
                        _buildMenuItem(
                          icon: Icons.campaign_rounded,
                          label: "استدعاء الأعضاء",
                          color: Colors.amber,
                          onTap: () async {
                            try {
                              await service.recallMembers();
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "تم إرسال استدعاء لجميع أعضاء الغرفة 🚀",
                                    ),
                                    backgroundColor: Colors.green,
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
                      if (!service.isHost)
                        _buildMenuItem(
                          icon: Icons.report_problem_rounded,
                          label: "إبلاغ",
                          color: Colors.redAccent,
                          onTap: () {
                            Navigator.pop(ctx);
                            _showReportRoomDialog(context, service, roomId);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showEditAnnouncementDialog(
  BuildContext context,
  VoiceRoomService service,
  String currentAnnouncement,
) {
  final controller = TextEditingController(text: currentAnnouncement);
  final focusNode = FocusNode();

  void insertNewline() {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final newText = text.replaceRange(start, end, '\n');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
    focusNode.requestFocus();
  }

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A242D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text(
        "إعلان الوكلاء",
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Tajawal',
          fontSize: 14,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 6,
            minLines: 3,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            onSubmitted: (_) => insertNewline(),
            cursorColor: Colors.tealAccent,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontFamily: 'Tajawal',
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black26,
              hintText: "أدخل نص الإشعار هنا...",
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.tealAccent,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("إلغاء", style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            await service.pinAnnouncement(controller.text);
            Navigator.pop(ctx);
          },
          child: const Text(
            "حفظ",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSectionHeader(String title) {
  return Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(top: 25, bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [Color(0xFF154359), Color(0xFF101920)],
        ),
        borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal',
        ),
      ),
    ),
  );
}

Widget _buildMenuItem({
  IconData? icon,
  String? imageAsset,
  required String label,
  required Color color,
  required VoidCallback onTap,
  bool hasSwitch = false,
  bool isToggled = false,
}) {
  return InkWell(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF15222E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: imageAsset != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          imageAsset,
                          width: 38,
                          height: 38,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Icon(icon, color: color, size: 28),
              ),
            ),
            if (hasSwitch)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 32,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isToggled ? Colors.greenAccent : Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        left: isToggled ? 18 : 2,
                        top: 2,
                        bottom: 2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32, // Fixed height for text area to ensure stability
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10, // Slightly smaller font
                height: 1.1,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

void _showBannedUsersSheet(BuildContext context, VoiceRoomService service) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'قائمة حظر دخول الغرفة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),
            const Divider(color: Colors.white10),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: service.getBannedUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF48C9B0),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'حدث خطأ: ${snapshot.error}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    );
                  }
                  final bannedList = snapshot.data ?? [];
                  if (bannedList.isEmpty) {
                    return const Center(
                      child: Text(
                        'لا توجد حسابات محظورة حالياً',
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: bannedList.length,
                    itemBuilder: (context, index) {
                      final user = bannedList[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['avatar'].toString().isNotEmpty
                              ? NetworkImage(user['avatar'].toString())
                              : null,
                          backgroundColor: Colors.grey[800],
                          child: user['avatar'].toString().isEmpty
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        title: Text(
                          user['name'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'ID: ${user['displayId'] ?? ''}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.2),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            try {
                              await service.unbanUser(user['id']);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'تم رفع الحظر عن العضو بنجاح',
                                      style: TextStyle(fontFamily: 'Tajawal'),
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'خطأ: $e',
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text(
                            'فك الحظر',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _showMicLayoutDialog(
  BuildContext context,
  VoiceRoomService service,
  String roomId,
  Map<String, dynamic> roomData,
) {
  final int roomLevel = roomData['roomLevel'] ?? 1;
  final String currentLayout = roomData['micLayoutType'] ?? 'layout_10_grid';

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'MicLayout',
    barrierColor: Colors.black.withOpacity(0.7),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) {
      return Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "تغيير نمط المايكات",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "اختر التخطيط المناسب لغرفتك",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 24),
                _buildLayoutOption(
                  context: context,
                  service: service,
                  id: 'layout_2',
                  label: 'مايكين (2)',
                  color: Colors.blueAccent,
                  isSelected: currentLayout == 'layout_2',
                  isLocked: false,
                ),
                _buildLayoutOption(
                  context: context,
                  service: service,
                  id: 'layout_5',
                  label: '5 مايكات (صف واحد)',
                  color: Colors.tealAccent,
                  isSelected: currentLayout == 'layout_5',
                  isLocked: false,
                ),
                _buildLayoutOption(
                  context: context,
                  service: service,
                  id: 'layout_10_grid',
                  label: '10 مايكات (افتراضي)',
                  color: Colors.amberAccent,
                  isSelected: currentLayout == 'layout_10_grid',
                  isLocked: roomLevel < 10,
                  levelRequired: 10,
                ),
                _buildLayoutOption(
                  context: context,
                  service: service,
                  id: 'layout_10_pyramid',
                  label: '10 مايكات (هرمي)',
                  color: Colors.purpleAccent,
                  isSelected: currentLayout == 'layout_10_pyramid',
                  isLocked: roomLevel < 10,
                  levelRequired: 10,
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "إلغاء",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: child,
        ),
      );
    },
  );
}

Widget _buildLayoutOption({
  required BuildContext context,
  required VoiceRoomService service,
  required String id,
  required String label,
  required Color color,
  required bool isSelected,
  required bool isLocked,
  int? levelRequired,
}) {
  return GestureDetector(
    onTap: () async {
      if (isLocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              "هذا النمط يتطلب مستوى غرفة $levelRequired فما فوق",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
        return;
      }
      try {
        await service.setMicLayoutType(id);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text("تم تغيير نمط المايكات"),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("فشل التغيير: $e")));
      }
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? color.withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? color : Colors.white.withOpacity(0.05),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: _buildMicPreview(id, color)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isLocked ? Colors.white24 : Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
          if (isLocked)
            const Row(
              children: [
                Icon(Icons.lock_rounded, color: Colors.amber, size: 16),
                SizedBox(width: 4),
                Text(
                  "مستوى 10",
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          else if (isSelected)
            Icon(Icons.check_circle_rounded, color: color, size: 24),
        ],
      ),
    ),
  );
}

Widget _buildMicPreview(String id, Color color) {
  switch (id) {
    case 'layout_2':
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(color, size: 10),
          const SizedBox(width: 8),
          _dot(color, size: 10),
        ],
      );
    case 'layout_5':
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _dot(color, size: 5),
          ),
        ),
      );
    case 'layout_10_grid':
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              5,
              (_) => Padding(
                padding: const EdgeInsets.all(1.5),
                child: _dot(color, size: 4),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              5,
              (_) => Padding(
                padding: const EdgeInsets.all(1.5),
                child: _dot(color, size: 4),
              ),
            ),
          ),
        ],
      );
    case 'layout_10_pyramid':
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dot(color, size: 4),
              const SizedBox(width: 4),
              _dot(color, size: 4),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.all(1.5),
                child: _dot(color, size: 4),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.all(1.5),
                child: _dot(color, size: 4),
              ),
            ),
          ),
        ],
      );
    default:
      return Icon(Icons.mic_none_rounded, color: color, size: 20);
  }
}

Widget _dot(Color color, {double size = 8}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.4),
          blurRadius: 2,
          spreadRadius: 0.5,
        ),
      ],
    ),
  );
}

void _showClearMessagesConfirmDialog(
  BuildContext context,
  VoiceRoomService service,
) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "ClearMessagesDialog",
    barrierColor: Colors.black.withOpacity(0.8),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cleaning_services_rounded,
                    color: Colors.orangeAccent,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "مسح جميع الرسائل؟",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "هل أنت متأكد من رغبتك في حذف كافة الرسائل من تاريخ الدردشة؟ لا يمكن التراجع عن هذه العملية.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontFamily: 'Tajawal',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "إلغاء",
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () async {
                          try {
                            await service.clearRoomMessages();
                            if (context.mounted) Navigator.pop(context);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("تم مسح الرسائل بنجاح"),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("فشل المسح: $e")),
                              );
                            }
                          }
                        },
                        child: const Text("مسح الآن"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim1, child: child),
      );
    },
  );
}

void _showLockRoomDialog(
  BuildContext context,
  VoiceRoomService service,
  String roomId,
) {
  final TextEditingController controller = TextEditingController();
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "LockDialog",
    barrierColor: Colors.black.withOpacity(0.8),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) {
      bool isLockingInProgress = false;

      return StatefulBuilder(
        builder: (context, setDialogState) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2C3E50), Color(0xFF000000)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      color: Colors.amber,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "قفل الغرفة الخاصة",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "التكلفة: 150 ",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const Icon(
                        Icons.diamond_rounded,
                        color: Colors.lightBlueAccent,
                        size: 18,
                      ),
                      const Text(
                        " (لمدة ساعة)",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 4,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: "",
                      hintText: "0 0 0 0",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.1),
                        letterSpacing: 8,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.amber,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            "إلغاء",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 16,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLockingInProgress
                              ? null
                              : () async {
                                  if (controller.text.length != 4) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("يرجى إدخال 4 أرقام"),
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(
                                    () => isLockingInProgress = true,
                                  );

                                  try {
                                    await service.lockRoom(
                                      roomId,
                                      controller.text,
                                    );
                                    if (context.mounted) Navigator.pop(context);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("تم قفل الغرفة بنجاح"),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(
                                      () => isLockingInProgress = false,
                                    );
                                    if (e.toString().contains('غير كافٍ')) {
                                      _showInsufficientDiamondsDialog(
                                        context,
                                        service,
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: isLockingInProgress
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text(
                                  "قفل الآن",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim1, child: child),
      );
    },
  );
}

void _showPinToTopDialog(
  BuildContext context,
  VoiceRoomService service,
  String roomId,
) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "PinDialog",
    barrierColor: Colors.black.withOpacity(0.8),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) {
      bool isPinningInProgress = false;

      return StatefulBuilder(
        builder: (context, setDialogState) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1D2671), Color(0xFFC33764)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.upgrade_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "تثبيت الغرفة في الأعلى",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "ستبقى غرفتك في مقدمة قائمة الغرف الشائعة لمدة ساعة كاملة لتجذب المزيد من الزوار.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "التكلفة: 5000 ",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const Icon(
                        Icons.diamond_rounded,
                        color: Colors.lightBlueAccent,
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            "إلغاء",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 16,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isPinningInProgress
                              ? null
                              : () async {
                                  setDialogState(
                                    () => isPinningInProgress = true,
                                  );
                                  try {
                                    await service.pinRoomToTop(roomId);
                                    if (context.mounted) Navigator.pop(context);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "تم تثبيت الغرفة في الأعلى بنجاح",
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(
                                      () => isPinningInProgress = false,
                                    );
                                    if (e.toString().contains('غير كافٍ')) {
                                      _showInsufficientDiamondsDialog(
                                        context,
                                        service,
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFC33764),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: isPinningInProgress
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFC33764),
                                  ),
                                )
                              : const Text(
                                  "تأكيد التثبيت",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim1, child: child),
      );
    },
  );
}

void _showUpgradeRoomDialog(
  BuildContext context,
  VoiceRoomService service,
  String roomId,
  Map<String, dynamic> roomData,
) {
  final int currentTierLevel = roomData['roomTier'] ?? 0;
  final bool isMaxTier = currentTierLevel >= RoomTierSystem.tiers.length - 1;
  final currentTier = RoomTierSystem.getTier(currentTierLevel);
  final nextTier = isMaxTier
      ? null
      : RoomTierSystem.getTier(currentTierLevel + 1);

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'UpgradeDialog',
    barrierColor: Colors.black.withOpacity(0.85),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, anim1, anim2) {
      return StatefulBuilder(
        builder: (context, setState) {
          bool isUpgrading = false;
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A1035), Color(0xFF0D1B2A)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.purpleAccent.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFF673AB7)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ترقية الغرفة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isMaxTier
                          ? 'وصلت غرفتك إلى أعلى مستوى 🏆'
                          : 'ارقِّ غرفتك للحصول على مزايا أكثر',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        fontFamily: 'Tajawal',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Current Tier Card
                    _buildTierCard(
                      label: 'المستوى الحالي',
                      tier: currentTier,
                      color: Colors.blueAccent,
                      isActive: true,
                    ),

                    if (!isMaxTier && nextTier != null) ...[
                      const SizedBox(height: 10),
                      // Arrow
                      const Icon(
                        Icons.keyboard_double_arrow_down_rounded,
                        color: Colors.purpleAccent,
                        size: 28,
                      ),
                      const SizedBox(height: 10),

                      // Next Tier Card
                      _buildTierCard(
                        label: 'المستوى التالي',
                        tier: nextTier,
                        color: Colors.purpleAccent,
                        isActive: false,
                      ),

                      const SizedBox(height: 24),

                      // Cost Row
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.purpleAccent.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.monetization_on_rounded,
                              color: Colors.amberAccent,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'التكلفة: ${_formatNumber(nextTier.cost)} عملة ميتو',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Upgrade Button
                      StatefulBuilder(
                        builder: (ctx, setBtn) {
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: isUpgrading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.flash_on_rounded,
                                      size: 20,
                                    ),
                              label: Text(
                                isUpgrading ? 'جارٍ الترقية...' : 'ترقية الآن',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                              onPressed: isUpgrading
                                  ? null
                                  : () async {
                                      setBtn(() => isUpgrading = true);
                                      try {
                                        await service.upgradeRoomTier();
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            backgroundColor: Colors.green,
                                            content: Row(
                                              children: [
                                                const Icon(
                                                  Icons.check_circle_rounded,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'تمت ترقية الغرفة إلى ${nextTier.title} 🎉',
                                                  style: const TextStyle(
                                                    fontFamily: 'Tajawal',
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        setBtn(() => isUpgrading = false);
                                        final msg = e is Exception
                                            ? e.toString().replaceFirst(
                                                'Exception: ',
                                                '',
                                              )
                                            : e.toString();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            backgroundColor: Colors.redAccent,
                                            content: Text(
                                              msg,
                                              style: const TextStyle(
                                                fontFamily: 'Tajawal',
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9C27B0),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                          );
                        },
                      ),
                    ] else if (isMaxTier) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              color: Colors.amber,
                              size: 28,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'أنت في القمة! لا يوجد مستوى أعلى',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(
                          color: Colors.white38,
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim1, child: child),
      );
    },
  );
}

Widget _buildTierCard({
  required String label,
  required RoomTier tier,
  required Color color,
  required bool isActive,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(isActive ? 0.12 : 0.06),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: color.withOpacity(isActive ? 0.5 : 0.2),
        width: 1.2,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),
            const Spacer(),
            Text(
              tier.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _tierStat(Icons.people_rounded, '${tier.maxMembers}', 'عضو', color),
            _tierStat(
              Icons.admin_panel_settings_rounded,
              '${tier.maxModerators}',
              'مشرف',
              color,
            ),
            _tierStat(Icons.star_rounded, '${tier.maxCoOwners}', 'شريك', color),
          ],
        ),
      ],
    ),
  );
}

Widget _tierStat(IconData icon, String value, String label, Color color) {
  return Column(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal',
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 10,
          fontFamily: 'Tajawal',
        ),
      ),
    ],
  );
}

String _formatNumber(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}م';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}ك';
  return n.toString();
}

void _showInsufficientDiamondsDialog(
  BuildContext context,
  VoiceRoomService service,
) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "LowBalanceDialog",
    barrierColor: Colors.black.withOpacity(0.85),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, anim1, anim2) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.82,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.redAccent.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.1),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.diamond_outlined,
                    color: Colors.redAccent,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "رصيد غير كافٍ",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "عذراً، ليس لديك رصيد كافٍ من الماس لإتمام هذه العملية. يمكنك الشحن من المتجر والمتابعة.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 32),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoreScreen(
                                userId: service.currentUserId ?? '',
                                initialTab: 1,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "اشحن الآن",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "ربما لاحقاً",
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 15,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: child,
        ),
      );
    },
  );
}

class _PremiumSettingsSheet extends StatefulWidget {
  final VoiceRoomService service;
  final String roomId;
  final Map<String, dynamic> initialData;

  const _PremiumSettingsSheet({
    required this.service,
    required this.roomId,
    required this.initialData,
  });

  @override
  State<_PremiumSettingsSheet> createState() => _PremiumSettingsSheetState();
}

class _PremiumSettingsSheetState extends State<_PremiumSettingsSheet> {
  late Map<String, dynamic> roomData;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    roomData = Map<String, dynamic>.from(widget.initialData);
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final url = await widget.service.uploadRoomImage(File(image.path));
        if (url != null) {
          setState(() {
            roomData['imageUrl'] = url;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("فشل رفع الصورة: $e")));
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _editField(String key, String title) async {
    print("DEBUG: _editField called for key: $key, title: $title");
    try {
      final rawValue = roomData[key];
      print("DEBUG: rawValue type: ${rawValue.runtimeType}, value: $rawValue");
      final String initialText = rawValue?.toString() ?? "";
      final controller = TextEditingController(text: initialText);
      final isMultiLine = key == 'announcement' || key == 'notice';

      Future<void> saveValue() async {
        final val = isMultiLine
            ? controller.text.trim()
            : controller.text.trim();
        print("DEBUG: Saving value: $val for key: $key");

        // Allow saving empty value for multi-line fields (announcement/notice) to "clear" it
        if (val.isNotEmpty || isMultiLine) {
          final isFee = key == 'entranceFee';
          final finalVal = isFee
              ? (int.tryParse(val.toString()) ?? 0)
              : val.toString();
          setState(() => roomData[key] = finalVal);

          int? feeToSend;
          if (isFee) feeToSend = int.tryParse(val.toString()) ?? 0;

          await widget.service.updateRoomSettings(
            name: key == 'name'
                ? (val.isNotEmpty ? val.toString() : null)
                : null,
            announcement: key == 'announcement' ? val.toString() : null,
            notice: key == 'notice' ? val.toString() : null,
            noticeTitle: key == 'noticeTitle' ? val.toString() : null,
            entranceFee: feeToSend,
          );
        }
      }

      if (isMultiLine) {
        // Use BottomSheet for announcement so the keyboard return key works natively
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    maxLines: null, // unlimited lines
                    minLines: 3,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Tajawal',
                    ),
                    decoration: InputDecoration(
                      hintText: "اكتب الإشعار... (اضغط Enter للسطر الجديد)",
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        fontSize: 13,
                        fontFamily: 'Tajawal',
                      ),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          "إلغاء",
                          style: TextStyle(
                            color: Colors.white54,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          await saveValue();
                          if (mounted) Navigator.pop(ctx);
                        },
                        child: const Text(
                          "حفظ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // Keep AlertDialog for other single-line fields
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Tajawal',
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: key == 'entranceFee'
                  ? TextInputType.number
                  : TextInputType.text,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "أدخل $title الجديد",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await saveValue();
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("حفظ"),
              ),
            ],
          ),
        );
      }
    } catch (e, stack) {
      print("DEBUG: ERROR in _editField: $e");
      print("DEBUG: STACKTRACE: $stack");
    }
  }

  Future<void> _showMembershipFeeDialog() async {
    final controller = TextEditingController(
      text: (roomData['entranceFee']?.toString()) ?? "0",
    );

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "MembershipFee",
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setDialogState) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F3D2E), Color(0xFF05110E)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.diamond_rounded,
                      color: Colors.blueAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "رسوم العضوية",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "حدد كمية الماس المطلوبة للدخول",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 13,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Input Field
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 20,
                        ),
                        suffixIcon: const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(
                            Icons.diamond_rounded,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFF7DCD9D),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "إلغاء",
                              style: TextStyle(color: Colors.white38),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7DCD9D),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: () async {
                              final text = controller.text.trim();
                              final int fee = int.tryParse(text) ?? 0;
                              setState(() => roomData['entranceFee'] = fee);
                              await widget.service.updateRoomSettings(
                                entranceFee: fee,
                              );
                              if (mounted) Navigator.pop(context);
                            },
                            child: const Text(
                              "تأكيد",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showRemoveMembersDialog() async {
    String searchQuery = "";

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101920),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    "إزالة الأعضاء",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Search Bar - Modern Elegant Style
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color.fromARGB(
                          255,
                          8,
                          8,
                          8,
                        ).withValues(alpha: 0.15),
                      ),
                    ),
                    child: TextField(
                      onChanged: (v) {
                        setSheetState(() {
                          searchQuery = v.toLowerCase();
                        });
                      },
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 8, 1, 1),
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: "...ابحث عن عضو باسمه أو معرفه",
                        hintStyle: TextStyle(
                          color: const Color.fromARGB(
                            255,
                            7,
                            7,
                            7,
                          ).withValues(alpha: 0.9),
                          fontSize: 13,
                          fontFamily: 'Tajawal',
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: const Color.fromARGB(
                            255,
                            0,
                            0,
                            0,
                          ).withValues(alpha: 0.6),
                          size: 22,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<List<User>>(
                      stream: widget.service.getRoomMembersStream(
                        widget.roomId,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(
                            child: Text(
                              "لا يوجد أعضاء في هذه الغرفة",
                              style: TextStyle(color: Colors.white38),
                            ),
                          );
                        }

                        // Filter by search and exclude host
                        final members = snapshot.data!.where((m) {
                          final isHost = m.uid == roomData['hostId'];
                          if (isHost) return false;

                          if (searchQuery.isEmpty) return true;

                          final String nickname = (m.nickname ?? m.username)
                              .toLowerCase();
                          final String displayId = (m.displayId ?? "")
                              .toLowerCase();

                          return nickname.contains(searchQuery) ||
                              displayId.contains(searchQuery);
                        }).toList();

                        if (members.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 40),
                              child: Text(
                                "لم يتم العثور على نتائج للبحث",
                                style: TextStyle(
                                  color: Colors.white24,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final user = members[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundImage: user.profileImage != null
                                    ? NetworkImage(user.profileImage!)
                                    : null,
                                child: user.profileImage == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(
                                user.nickname ?? user.username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                              subtitle: Text(
                                "ID: ${user.displayId ?? user.uid.substring(0, 5)}",
                                style: const TextStyle(
                                  color: Colors.white24,
                                  fontSize: 10,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withValues(
                                    alpha: 0.15,
                                  ),
                                  foregroundColor: Colors.redAccent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: Colors.redAccent.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E1E1E),
                                      title: const Text(
                                        "تأكيد الإزالة",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Tajawal',
                                        ),
                                      ),
                                      content: Text(
                                        "هل أنت متأكد من إزالة ${user.nickname} من عضوية الغرفة؟",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontFamily: 'Tajawal',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text("إلغاء"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            "إزالة",
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    try {
                                      await widget.service.removeRoomMember(
                                        user.uid,
                                        widget.roomId,
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    }
                                  }
                                },
                                child: const Text(
                                  "إزالة",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showChatRestrictionsDialog() async {
    final String currentMode = roomData['chatMode'] ?? "الجميع";

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "ChatRestrictions",
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F3D2E), Color(0xFF05110E)],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "قيود المراسلة",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildModeOption("الجميع", currentMode == "الجميع"),
                  const SizedBox(height: 12),
                  _buildModeOption("الأعضاء فقط", currentMode == "الأعضاء فقط"),
                  const SizedBox(height: 12),
                  _buildModeOption(
                    "المشرفون فقط",
                    currentMode == "المشرفون فقط",
                  ),
                  const SizedBox(height: 12),
                  _buildModeOption(
                    "إيقاف التكست للجميع",
                    currentMode == "إيقاف التكست للجميع",
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeOption(String label, bool isSelected) {
    return InkWell(
      onTap: () async {
        setState(() => roomData['chatMode'] = label);
        await widget.service.updateRoomSettings(chatMode: label);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4A6B43)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.white38 : Colors.white10,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white, size: 20)
            else
              const SizedBox(width: 20),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMicPermissionsDialog() async {
    final String currentMode = roomData['micMode'] ?? "الجميع";

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "MicPermissions",
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F3D2E), Color(0xFF05110E)],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "إذن المايك",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildMicModeOption("الجميع", currentMode == "الجميع"),
                  const SizedBox(height: 12),
                  _buildMicModeOption(
                    "الأعضاء فقط",
                    currentMode == "الأعضاء فقط",
                  ),
                  const SizedBox(height: 12),
                  _buildMicModeOption(
                    "المشرفون فقط",
                    currentMode == "المشرفون فقط",
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMicModeOption(String label, bool isSelected) {
    return InkWell(
      onTap: () async {
        setState(() => roomData['micMode'] = label);
        await widget.service.updateRoomSettings(micMode: label);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4A6B43)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.white38 : Colors.white10,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white, size: 20)
            else
              const SizedBox(width: 20),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdminsListDialog() async {
    final Map<String, dynamic> adminsMap = Map<String, dynamic>.from(
      roomData['admins'] ?? {},
    );
    final List<String> adminIds = adminsMap.keys.toList();

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "AdminManagement",
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setDialogState) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F3D2E), Color(0xFF05110E)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Text(
                      "صلاحيات المشرف",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Global Admin Capabilities
                    _buildAdminCapSwitch(
                      "تغيير موضوع الغرفة والإعلان",
                      roomData['adminCanModifyRoom'] == true,
                      (val) async {
                        setState(() => roomData['adminCanModifyRoom'] = val);
                        setDialogState(() {});
                        await widget.service.updateRoomSettings(
                          adminCanModifyRoom: val,
                        );
                      },
                    ),
                    _buildAdminCapSwitch(
                      "قفل/فتح المايكات",
                      roomData['adminCanManageSeats'] == true,
                      (val) async {
                        setState(() => roomData['adminCanManageSeats'] = val);
                        setDialogState(() {});
                        await widget.service.updateRoomSettings(
                          adminCanManageSeats: val,
                        );
                      },
                    ),
                    _buildAdminCapSwitch(
                      "دعوة الأعضاء للصعود للمايك",
                      roomData['adminCanInviteUsers'] == true,
                      (val) async {
                        setState(() => roomData['adminCanInviteUsers'] = val);
                        setDialogState(() {});
                        await widget.service.updateRoomSettings(
                          adminCanInviteUsers: val,
                        );
                      },
                    ),
                    _buildAdminCapSwitch(
                      "بدء وإنهاء ألعاب الغرفة",
                      roomData['adminCanControlGames'] == true,
                      (val) async {
                        setState(() => roomData['adminCanControlGames'] = val);
                        setDialogState(() {});
                        await widget.service.updateRoomSettings(
                          adminCanControlGames: val,
                        );
                      },
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Colors.white10),
                    ),

                    // Add Admin Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7DCD9D),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () => _showAddAdminPicker(setDialogState),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text(
                        "إضافة مشرف جديد",
                        style: TextStyle(fontFamily: 'Tajawal'),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Expanded(
                      child: adminIds.isEmpty
                          ? const Center(
                              child: Text(
                                "لا توجد مشرفين حالياً",
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: adminIds.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final String uid = adminIds[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Row(
                                    children: [
                                      const CircleAvatar(
                                        backgroundColor: Colors.white10,
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white38,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "مشرف ($uid)",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                        onPressed: () async {
                                          await widget.service.setAdmin(
                                            uid,
                                            false,
                                          );
                                          setDialogState(() {
                                            adminIds.remove(uid);
                                            roomData['admins']?.remove(uid);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "إغلاق",
                        style: TextStyle(
                          color: Colors.white38,
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
      },
    );
  }

  Widget _buildAdminCapSwitch(
    String title,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: (val) => onChanged(val),
            activeColor: const Color(0xFF7DCD9D),
            activeTrackColor: const Color(0xFF2D5D4E),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAdminPicker(Function setParentState) async {
    // Show a list of current room users who are NOT admins
    final List<User> candidates = widget.service.roomUsers
        .where(
          (u) =>
              u.uid != roomData['hostId'] &&
              !(roomData['admins']?.containsKey(u.uid) ?? false),
        )
        .toList();

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101920),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "اختر مستخدماً لتعيينه مشرفاً",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: candidates.isEmpty
                  ? const Center(
                      child: Text(
                        "لا توجد مرشحين متاحين في الغرفة حالياً",
                        style: TextStyle(
                          color: Colors.white38,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final user = candidates[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user.profileImage != null
                                ? NetworkImage(user.profileImage!)
                                : null,
                            child: user.profileImage == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            user.nickname ?? user.username,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () async {
                            await widget.service.setAdmin(user.uid, true);
                            setParentState(() {
                              if (roomData['admins'] == null)
                                roomData['admins'] = {};
                              roomData['admins'][user.uid] = true;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F3D2E), Color(0xFF071F18)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 28,
                  ),
                ),
                const Expanded(
                  child: Text(
                    "الإعدادات",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
                const SizedBox(width: 28), // Spacer for center alignment
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Top Card: Info & Image (Editable)
                _buildModernCard(
                  customChild: Row(
                    children: [
                      // Left side arrows
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_left,
                            color: Colors.white24,
                            size: 20,
                          ),
                          SizedBox(height: 35),
                          Icon(
                            Icons.arrow_left,
                            color: Colors.white24,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),

                      // Text Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () => _editField('name', 'اسم الغرفة'),
                              child: Text(
                                roomData['name'] ?? "اسم الغرفة",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _dashedDivider(),
                            const SizedBox(height: 12),
                            // Room Private Announcement
                            const Text(
                              "عنوان الإعلان",
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  _editField('noticeTitle', 'عنوان الإعلان'),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  roomData['noticeTitle'] ?? "إعلان الغرفة",
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12,
                                    fontFamily: 'Tajawal',
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "محتوى الإعلان",
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  _editField('notice', 'محتوى الإعلان'),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  roomData['notice'] ??
                                      "أضف إعلان غرفتك الخاص هنا...",
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12,
                                    fontFamily: 'Tajawal',
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Divider
                      Container(height: 80, width: 1, color: Colors.white12),
                      const SizedBox(width: 12),

                      // Image
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          alignment: Alignment.bottomLeft,
                          children: [
                            Container(
                              width: 85,
                              height: 85,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                image: DecorationImage(
                                  image:
                                      (roomData['imageUrl'] != null &&
                                          roomData['imageUrl'] != "")
                                      ? NetworkImage(roomData['imageUrl'])
                                      : const AssetImage(
                                              'assets/images/default_room.png',
                                            )
                                            as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: _isUploading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF4A6B43),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Mic & Message Restrictions
                _buildModernCard(
                  child: Column(
                    children: [
                      _buildSettingItem(
                        title: "إذن المايك",
                        value: roomData['micMode'] ?? "الجميع",
                        onTap: () => _showMicPermissionsDialog(),
                      ),
                      _dashedDivider(),
                      _buildSettingItem(
                        title: "قيود المراسلة",
                        subtitle: roomData['chatMode'] ?? "الجميع",
                        onTap: () => _showChatRestrictionsDialog(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Admin & Membership Fee
                _buildModernCard(
                  child: Column(
                    children: [
                      _buildSettingItem(
                        title: "قائمة المشرفين",
                        onTap: () => _showAdminsListDialog(),
                      ),
                      _dashedDivider(),
                      _buildSettingItem(
                        title: "رسوم العضوية",
                        value: (roomData['entranceFee']?.toString()) ?? "0",
                        icon: Icons.diamond_rounded,
                        iconColor: Colors.blueAccent,
                        onTap: () {
                          _showMembershipFeeDialog();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Auto Clean & Extra Lists
                _buildModernCard(
                  child: Column(
                    children: [
                      _buildSettingItem(
                        title: "إزالة الأعضاء غير النشطين تلقائياً",
                        hasSwitch: true,
                        switchValue: roomData['autoClearInactive'] ?? false,
                        onChanged: (v) {
                          setState(() => roomData['autoClearInactive'] = v);
                          widget.service.updateRoomSettings(
                            autoClearInactive: v,
                          );
                        },
                      ),
                      _dashedDivider(),
                      _buildSettingItem(
                        title: "إزالة الأعضاء",
                        onTap: () => _showRemoveMembersDialog(),
                      ),
                      _dashedDivider(),
                      _buildSettingItem(
                        title: "قائمة حظر دخول الغرفة",
                        onTap: () {
                          Navigator.pop(
                            context,
                          ); // Close the settings menu first
                          _showBannedUsersSheet(context, widget.service);
                        },
                      ),
                      _dashedDivider(),
                      _buildSettingItem(
                        title: "تسجيلات عملية العقوبات",
                        onTap: () => _showPenaltyLogsDialog(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCard({Widget? child, Widget? customChild}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: customChild ?? child,
    );
  }

  Widget _buildSettingItem({
    required String title,
    String? value,
    String? subtitle,
    IconData? icon,
    Color? iconColor,
    VoidCallback? onTap,
    bool hasSwitch = false,
    bool switchValue = false,
    Function(bool)? onChanged,
  }) {
    return InkWell(
      onTap: hasSwitch ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (hasSwitch)
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: switchValue,
                  onChanged: onChanged,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.white24,
                ),
              )
            else ...[
              const Icon(Icons.arrow_left, color: Colors.white38, size: 20),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF7DCD9D),
                    fontSize: 13,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 4),
                  Icon(icon, color: iconColor, size: 16),
                ],
              ],
            ],
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashedDivider() {
    return Row(
      children: List.generate(
        150,
        (index) => Expanded(
          child: Container(
            color: index % 2 == 0 ? Colors.transparent : Colors.white10,
            height: 1,
          ),
        ),
      ),
    );
  }

  Future<void> _showPenaltyLogsDialog() async {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "PenaltyLogs",
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F3D2E), Color(0xFF05110E)],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  const Text(
                    "سجل العقوبات اليومي",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const Text(
                    "يتم تصفير السجل تلقائياً عند الساعة 00:00",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: widget.service.getPenaltyLogsStream(
                        widget.roomId,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              "خطأ: ${snapshot.error}",
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final logs = snapshot.data ?? [];
                        if (logs.isEmpty) {
                          return const Center(
                            child: Text(
                              "لا توجد عقوبات مسجلة اليوم",
                              style: TextStyle(
                                color: Colors.white24,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return _buildPenaltyLogItem(log);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "إغلاق",
                      style: TextStyle(
                        color: Colors.white54,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPenaltyLogItem(Map<String, dynamic> log) {
    final String action = log['action'] ?? '';
    final String executor = log['executorName'] ?? 'مجهول';
    final String target = log['targetName'] ?? 'عضو';

    String actionText = "";
    IconData icon = Icons.info_outline;
    Color color = Colors.white70;

    switch (action) {
      case 'mute':
        actionText = "كتم";
        icon = Icons.mic_off;
        color = Colors.orangeAccent;
        break;
      case 'unmute':
        actionText = "إلغاء كتم";
        icon = Icons.mic;
        color = Colors.greenAccent;
        break;
      case 'kick':
        actionText = "طرد مؤقت";
        icon = Icons.exit_to_app;
        color = Colors.redAccent;
        break;
      case 'ban':
        actionText = "حظر نهائي";
        icon = Icons.block;
        color = Colors.red;
        break;
      case 'unban':
        actionText = "إلغاء حظر";
        icon = Icons.check_circle_outline;
        color = Colors.blueAccent;
        break;
      case 'set_admin':
        actionText = "تعيين مشرف";
        icon = Icons.admin_panel_settings;
        color = Colors.amber;
        break;
      case 'remove_admin':
        actionText = "إزالة مشرف";
        icon = Icons.person_remove_alt_1;
        color = Colors.grey;
        break;
      case 'set_co_owner':
        actionText = "تعيين نائب";
        icon = Icons.star;
        color = Colors.purpleAccent;
        break;
      case 'remove_co_owner':
        actionText = "إزالة نائب";
        icon = Icons.star_border;
        color = Colors.blueGrey;
        break;
      case 'kick_from_seat':
        actionText = "إنزال من الكرسي";
        icon = Icons.event_seat_rounded;
        color = Colors.orange;
        break;
      case 'invite_to_seat':
        actionText = "دعوة للكرسي";
        icon = Icons.person_add_alt_1_rounded;
        color = Colors.green;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                    children: [
                      TextSpan(
                        text: executor,
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text: " قام بـ ",
                        style: TextStyle(color: Colors.white70),
                      ),
                      TextSpan(
                        text: actionText,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text: " لـ ",
                        style: TextStyle(color: Colors.white70),
                      ),
                      TextSpan(
                        text: target,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (log['timestamp'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(log['timestamp']),
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return "";
    try {
      // Using dynamic to avoid 'Timestamp' type resolution issues in this file
      final DateTime dt = (ts as dynamic).toDate();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "";
    }
  }
}

void _showReportRoomDialog(
  BuildContext context,
  VoiceRoomService service,
  String roomId,
) {
  final reasons = [
    "محتوى غير لائق",
    "إساءة أو مضايقة",
    "نشر كراهية",
    "انتحال شخصية",
    "غير ذلك",
  ];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E272E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "إبلاغ عن الغرفة",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            "يرجى اختيار سبب الإبلاغ:",
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: reasons.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(
                  reasons[index],
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white24,
                  size: 14,
                ),
                onTap: () async {
                  try {
                    await service.reportRoom(roomId, reasons[index]);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "شكرًا لك.. تم إرسال بلاغك للإدارة للمراجعة.",
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("فشل إرسال البلاغ: $e")),
                      );
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showCustomWelcomeDialog(
  BuildContext context,
  VoiceRoomService service,
  Map<String, dynamic> roomData,
) {
  final controller = TextEditingController(
    text: roomData['customEntryMessage'] ?? "",
  );
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A242D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text(
        "رسالة ترحيب مخصصة",
        style: TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "استخدم {name} للإشارة لاسم العضو",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w500,
            ),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "مثلاً: أهلاً بك يا {name} في غرفتنا",
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontFamily: 'Tajawal',
              ),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.2),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.pinkAccent),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.pinkAccent,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("إلغاء", style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pinkAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            await service.updateRoomSettings(
              customEntryMessage: controller.text.trim(),
            );
            Navigator.pop(ctx);
          },
          child: const Text(
            "حفظ",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

void _showChairColorPicker(
  BuildContext context,
  VoiceRoomService service,
  Map<String, dynamic> roomData,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF101920),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        const Text(
          "اختر لون أو شكل الكراسي",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 120,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('shop_items')
                .where('type', isEqualTo: 14)
                .snapshots(),
            builder: (context, snapshot) {
              final List<Map<String, dynamic>> colors = [
                {'name': 'افتراضي', 'color': null},
                {'name': 'مايك', 'color': 'image:mic'},
              ];

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  colors.add({
                    'name': data['name'] ?? 'شكل',
                    'color': 'url:${data['imageUrl']}',
                  });
                }
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: colors.length,
                itemBuilder: (context, index) {
                  final item = colors[index];
                  final isSelected = roomData['seatColor'] == item['color'];
                  final colorStr = item['color']?.toString();
                  final isImage = colorStr?.startsWith('image:') == true;
                  final isUrl = colorStr?.startsWith('url:') == true;

                  return GestureDetector(
                    onTap: () async {
                      await service.updateRoomSettings(
                        seatColor: item['color'] ?? 'clear',
                      );
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 15),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color:
                                  (item['color'] != null && !isImage && !isUrl)
                                  ? Color(int.parse("0xFF${item['color']}"))
                                  : Colors.white12,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: [
                                if (item['color'] != null && !isImage && !isUrl)
                                  BoxShadow(
                                    color: Color(
                                      int.parse("0xFF${item['color']}"),
                                    ).withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: item['color'] == null
                                ? const Icon(
                                    Icons.event_seat_rounded,
                                    color: Colors.white54,
                                  )
                                : isImage
                                ? Center(
                                    child: Image.asset(
                                      'assets/images/mick/mic.png',
                                      width: 30,
                                      height: 30,
                                    ),
                                  )
                                : isUrl
                                ? ClipOval(
                                    child: Image.network(
                                      colorStr!.substring(4),
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.broken_image,
                                                color: Colors.white54,
                                              ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['name'],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white54,
                              fontSize: 12,
                              fontFamily: 'Tajawal',
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
        const SizedBox(height: 30),
      ],
    ),
  );
}
