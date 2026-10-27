import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class DominoPlayerProfileBottomSheet extends StatefulWidget {
  final String uid;
  final String name;
  final String? photo;
  final bool isMuted;
  final Function(bool) onMuteChanged;
  final VoidCallback? onSendMessage;

  const DominoPlayerProfileBottomSheet({
    Key? key,
    required this.uid,
    required this.name,
    this.photo,
    required this.isMuted,
    required this.onMuteChanged,
    this.onSendMessage,
  }) : super(key: key);

  static void show(
    BuildContext context, {
    required String uid,
    required String name,
    String? photo,
    required bool isMuted,
    required Function(bool) onMuteChanged,
    VoidCallback? onSendMessage,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DominoPlayerProfileBottomSheet(
        uid: uid,
        name: name,
        photo: photo,
        isMuted: isMuted,
        onMuteChanged: onMuteChanged,
        onSendMessage: onSendMessage,
      ),
    );
  }

  @override
  State<DominoPlayerProfileBottomSheet> createState() =>
      _DominoPlayerProfileBottomSheetState();
}

class _DominoPlayerProfileBottomSheetState
    extends State<DominoPlayerProfileBottomSheet> {
  User? _user;
  User? _currentUser;
  bool _isLoading = true;
  bool _isFriend = false;
  final String _currentUid = fb.FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await UserService().getUser(widget.uid);
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
        _checkFriendship();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkFriendship() async {
    if (_currentUid.isEmpty) return;
    final currentUser = await UserService().getUser(_currentUid);
    if (currentUser != null && mounted) {
      setState(() {
        _currentUser = currentUser;
        _isFriend =
            (currentUser.following.contains(widget.uid)) &&
            (currentUser.followers.contains(widget.uid));
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUid.isEmpty) return;
    try {
      await UserService().followUser(
        currentUserId: _currentUid,
        currentUsername: _currentUser?.username ?? 'لاعب',
        currentUserProfileImage: _currentUser?.profileImage,
        userToFollowId: widget.uid,
      );
      await _checkFriendship();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب الصداقة/المتابعة')),
        );
      }
    } catch (e) {
      debugPrint('Error following: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 10, spreadRadius: 5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Profile Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.cyanAccent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: widget.photo != null
                        ? (widget.photo!.startsWith('http')
                              ? Image.network(widget.photo!, fit: BoxFit.cover)
                              : Image.asset(widget.photo!, fit: BoxFit.cover))
                        : const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white54,
                          ),
                  ),
                ),
                const SizedBox(width: 20),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${widget.uid.substring(0, 8).toUpperCase()}',
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                      if (_user != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'المستوى ${_user!.level}',
                              style: GoogleFonts.tajawal(
                                color: Colors.amber,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Stats / Bio (Simplified)
          if (!_isLoading && _user != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('متابعين', '${_user!.followersCount}'),
                  _buildStatItem('يتابع', '${_user!.followingCount}'),
                  _buildStatItem('المجموع', '${_user!.gamesPlayed}'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Domino specific stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Text(
                      'إحصائيات الدومينو',
                      style: GoogleFonts.tajawal(
                        color: Colors.cyanAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSmallStat(
                          'لعب',
                          '${_user!.gameStats['domino']?['played'] ?? 0}',
                        ),
                        _buildSmallStat(
                          'فوز',
                          '${_user!.gameStats['domino']?['wins'] ?? 0}',
                        ),
                        _buildSmallStat(
                          'خسارة',
                          '${_user!.gameStats['domino']?['losses'] ?? 0}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                // Friend / Follow Button
                Expanded(
                  flex: 2,
                  child: _isFriend
                      ? _buildActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: 'رسالة',
                          color: Colors.cyanAccent,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onSendMessage?.call();
                          },
                        )
                      : _buildActionButton(
                          icon: Icons.person_add_outlined,
                          label: 'إضافة صديق',
                          color: Colors.cyanAccent,
                          onTap: _toggleFollow,
                        ),
                ),
                const SizedBox(width: 12),
                // Mute Button
                Expanded(
                  flex: 1,
                  child: _buildActionButton(
                    icon: widget.isMuted ? Icons.volume_off : Icons.volume_up,
                    label: widget.isMuted ? 'ملغى' : 'كتم',
                    color: widget.isMuted ? Colors.redAccent : Colors.white54,
                    onTap: () {
                      widget.onMuteChanged(!widget.isMuted);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.tajawal(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSmallStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.tajawal(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.tajawal(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
