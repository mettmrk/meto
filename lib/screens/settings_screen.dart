import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/user_service.dart';
import '../models/user_model.dart' as user_model;
import 'users_list_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'support_screen.dart';
import 'about_app_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _privateAccount = false;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  firebase_auth.User? _user;
  user_model.User? _firestoreUser;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      setState(() {
        _darkModeEnabled = prefs.getBool('isDarkMode') ?? false;
        _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
        _privateAccount = prefs.getBool('privateAccount') ?? false;
      });
    }

    if (_user != null) {
      final userService = UserService();
      final userDoc = await userService.getUser(_user!.uid);
      if (userDoc != null && mounted) {
        setState(() {
          _firestoreUser = userDoc;
          _privateAccount = userDoc.isPrivate;
        });
        await prefs.setBool('privateAccount', userDoc.isPrivate);
      }
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF8FAFF),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 90.0,
            floating: false,
            pinned: true,
            elevation: 0,
            stretch: true,
            backgroundColor: primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                'الإعدادات',
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileCard(context),
                  const SizedBox(height: 20),

                  _buildSectionHeader('الحساب والخصوصية'),
                  _buildSettingsGroup([
                    _SettingsTile(
                      icon: Icons.lock_outline_rounded,
                      color: Colors.orange,
                      title: 'تغيير كلمة المرور',
                      onTap: _handleChangePassword,
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.vpn_key_outlined,
                      color: Colors.teal,
                      title: 'حساب خاص',
                      value: _privateAccount,
                      onChanged: (val) async {
                        setState(() => _privateAccount = val);
                        _updateSetting('privateAccount', val);
                        if (_user != null) {
                          try {
                            await UserService().updateUser(
                              uid: _user!.uid,
                              data: {'isPrivate': val},
                            );
                          } catch (e) {
                            debugPrint(
                              'Error updating private account status: $e',
                            );
                          }
                        }
                      },
                    ),
                  ]),

                  const SizedBox(height: 16),

                  _buildSectionHeader('أمان الحساب والروابط'),
                  _buildSettingsGroup([
                    _buildSecurityTile(
                      icon: Icons.alternate_email_rounded,
                      color: Colors.blue,
                      title: 'البريد الإلكتروني',
                      subtitle: _user?.email ?? 'غير مرتببط',
                      isLinked: _user?.email != null,
                    ),
                    _buildSecurityTile(
                      icon: Icons.phone_android_rounded,
                      color: Colors.green,
                      title: 'رقم الهاتف',
                      subtitle: _user?.phoneNumber ?? 'غير مرتبط',
                      isLinked: _user?.phoneNumber != null,
                    ),
                    _buildSecurityTile(
                      icon: Icons.g_mobiledata_rounded,
                      color: Colors.red,
                      title: 'حساب جوجل',
                      subtitle: _isProviderLinked('google.com')
                          ? 'مرتبط'
                          : 'غير مرتبط',
                      isLinked: _isProviderLinked('google.com'),
                      onTap: _linkWithGoogle,
                    ),
                    _buildSecurityTile(
                      icon: Icons.facebook_outlined,
                      color: Colors.blue.shade900,
                      title: 'حساب فيسبوك',
                      subtitle: _isProviderLinked('facebook.com')
                          ? 'مرتبط'
                          : 'غير مرتبط',
                      isLinked: _isProviderLinked('facebook.com'),
                      onTap: _linkWithFacebook,
                    ),
                  ]),

                  const SizedBox(height: 16),

                  _buildSectionHeader('إدارة الحسابات'),
                  _buildSettingsGroup([
                    _SettingsTile(
                      icon: Icons.block_flipped,
                      color: Colors.redAccent,
                      title: 'الحسابات المحجوبة',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UsersListScreen(type: ListType.blocked),
                        ),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.volume_off_rounded,
                      color: Colors.amber.shade700,
                      title: 'الحسابات المصمتة',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UsersListScreen(type: ListType.muted),
                        ),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.list_alt_rounded,
                      color: Colors.blueGrey,
                      title: 'القائمة السوداء',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              UsersListScreen(type: ListType.blacklisted),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  _buildSectionHeader('التطبيق والمظهر'),
                  _buildSettingsGroup([
                    _SettingsSwitchTile(
                      icon: Icons.notifications_active_outlined,
                      color: Colors.purple,
                      title: 'الإشعارات',
                      value: _notificationsEnabled,
                      onChanged: (val) {
                        setState(() => _notificationsEnabled = val);
                        _updateSetting('notificationsEnabled', val);
                      },
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.dark_mode_outlined,
                      color: Colors.indigo,
                      title: 'الوضع الليلي',
                      value: _darkModeEnabled,
                      onChanged: (val) async {
                        setState(() => _darkModeEnabled = val);
                        themeNotifier.value = val
                            ? ThemeMode.dark
                            : ThemeMode.light;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('isDarkMode', val);
                      },
                    ),
                  ]),

                  const SizedBox(height: 16),
                  _buildColorTile(context),

                  const SizedBox(height: 16),

                  _buildSectionHeader('المساعدة والمعلومات'),
                  _buildSettingsGroup([
                    _SettingsTile(
                      icon: Icons.help_outline_rounded,
                      color: Colors.cyan,
                      title: 'مركز المساعدة',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SupportScreen(),
                        ),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      color: Colors.blueGrey,
                      title: 'حول التطبيق',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AboutAppScreen(),
                        ),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      color: Colors.teal,
                      title: 'سياسة الخصوصية',
                      onTap: () =>
                          Navigator.of(context).pushNamed('/privacy-policy'),
                    ),
                    _SettingsTile(
                      icon: Icons.description_outlined,
                      color: Colors.orangeAccent,
                      title: 'شروط الاستخدام',
                      onTap: () =>
                          Navigator.of(context).pushNamed('/terms-of-use'),
                    ),
                  ]),

                  const SizedBox(height: 32),

                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade600],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showLogoutConfirmation,
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.logout_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'تسجيل الخروج',
                                style: GoogleFonts.tajawal(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: Column(
                      children: [
                        Text(
                          'METO',
                          style: GoogleFonts.tajawal(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الإصدار 1.1.0',
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isProviderLinked(String providerId) {
    if (_user == null) return false;
    return _user!.providerData.any((p) => p.providerId == providerId);
  }

  Future<void> _linkWithGoogle() async {
    if (_isProviderLinked('google.com')) return;
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final firebase_auth.OAuthCredential credential =
          firebase_auth.GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

      await _user!.linkWithCredential(credential);
      setState(() => _user = _auth.currentUser);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم ربط حساب جوجل بنجاح')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الربط: $e')));
    }
  }

  Future<void> _linkWithFacebook() async {
    if (_isProviderLinked('facebook.com')) return;
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final firebase_auth.OAuthCredential credential = firebase_auth
            .FacebookAuthProvider.credential(result.accessToken!.tokenString);
        await _user!.linkWithCredential(credential);
        setState(() => _user = _auth.currentUser);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم ربط حساب فيسبوك بنجاح')),
          );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الربط: $e')));
    }
  }

  Widget _buildSecurityTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isLinked,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        title,
        style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.tajawal(
          fontSize: 11,
          color: isLinked ? Colors.green : Colors.grey,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isLinked
              ? Colors.green.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isLinked ? 'مرتبط' : 'ربط الآن',
          style: GoogleFonts.tajawal(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isLinked ? Colors.green : Colors.grey.shade700,
          ),
        ),
      ),
      onTap: isLinked
          ? null
          : (onTap ??
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('سيتم تفعيل ميزة الربط في التحديث القادم'),
                    ),
                  );
                }),
    );
  }

  void _handleChangePassword() async {
    final user = _user;
    final email = user?.email;

    if (user == null || email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً، لا يوجد بريد إلكتروني مرتبط بهذا الحساب'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'تغيير كلمة المرور',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.mail_lock_rounded,
                size: 60,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'سيتم إرسال رابط لإعادة تعيين كلمة المرور إلى بريدك الإلكتروني:',
                style: GoogleFonts.tajawal(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                email,
                style: GoogleFonts.tajawal(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: GoogleFonts.tajawal(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await firebase_auth.FirebaseAuth.instance
                      .sendPasswordResetEmail(email: email);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'تم إرسال الرابط بنجاح، تفقد بريدك الإلكتروني',
                              style: GoogleFonts.tajawal(),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'إرسال الآن',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String realName =
        _firestoreUser?.nickname ??
        _firestoreUser?.username ??
        _user?.displayName ??
        'مستخدم ميتو';
    final String? profileImage =
        _firestoreUser?.profileImage ?? _user?.photoURL;
    final String email =
        _firestoreUser?.email ?? _user?.email ?? 'لا يوجد بريد إلكتروني';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  const Color(0xFF4DB6AC),
                ],
              ),
            ),
            child: Center(
              child: profileImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(27),
                      child: _buildAvatarImage(profileImage, 54),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  realName,
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  email,
                  style: GoogleFonts.tajawal(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/editProfile'),
            icon: Icon(
              Icons.edit_rounded,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(String imagePath, double size) {
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.person_rounded, color: Colors.white, size: size / 2),
      );
    } else {
      String cleanPath = imagePath.replaceAll('file:///assets/', 'assets/');
      if (!cleanPath.startsWith('assets/')) cleanPath = 'assets/$cleanPath';
      return Image.asset(
        cleanPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.person_rounded, color: Colors.white, size: size / 2),
      );
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.tajawal(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> tiles) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          int idx = entry.key;
          Widget tile = entry.value;
          return Column(
            children: [
              tile,
              if (idx != tiles.length - 1)
                Divider(
                  height: 1,
                  indent: 60,
                  endIndent: 16,
                  color: Colors.grey.withValues(alpha: 0.1),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'تسجيل الخروج',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
            style: GoogleFonts.tajawal(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: GoogleFonts.tajawal(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await firebase_auth.FirebaseAuth.instance.signOut();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('sessionId');
                  if (mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'خروج',
                style: GoogleFonts.tajawal(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildColorTile(BuildContext context) {
    return _buildSettingsGroup([
      ValueListenableBuilder<Color>(
        valueListenable: primaryColorNotifier,
        builder: (context, currentPrimary, _) {
          return _SettingsTile(
            icon: Icons.palette_outlined,
            color: currentPrimary,
            title: 'لون التطبيق الموحد',
            trailing: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: currentPrimary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: currentPrimary.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            onTap: () => _showColorPickerBottomSheet(context),
          );
        },
      ),
    ]);
  }

  void _showColorPickerBottomSheet(BuildContext context) {
    final List<Color> colors = [
      const Color(0xFF009688),
      const Color(0xFF2196F3),
      const Color(0xFF9C27B0),
      const Color.fromARGB(255, 37, 57, 235),
      const Color.fromARGB(255, 128, 53, 105),
      const Color.fromARGB(255, 28, 97, 30),
      const Color.fromARGB(255, 167, 13, 13),
      const Color(0xFF3F51B5),
      const Color(0xFF673AB7),
      const Color.fromARGB(255, 8, 142, 160),
      const Color.fromARGB(255, 7, 74, 129),
      const Color.fromARGB(255, 86, 110, 121),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'اختر لون التطبيق',
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سيتم تغيير لون الواجهة والخطوط الرئيسية بناءً على اختيارك',
              style: GoogleFonts.tajawal(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
              ),
              itemCount: colors.length,
              itemBuilder: (context, index) {
                return ValueListenableBuilder<Color>(
                  valueListenable: primaryColorNotifier,
                  builder: (context, selectedColor, _) {
                    final isSelected =
                        selectedColor.value == colors[index].value;
                    return GestureDetector(
                      onTap: () async {
                        primaryColorNotifier.value = colors[index];
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('primaryColor', colors[index].value);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: colors[index],
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colors[index].withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        title,
        style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      trailing:
          trailing ??
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: Colors.grey,
          ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsSwitchTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).primaryColor,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
