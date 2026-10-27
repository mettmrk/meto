import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/referral_service.dart';
import 'package:email_otp/email_otp.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _referralCodeController;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isTermsAccepted = false;
  bool _isLoading = false;
  String? _selectedGender;
  String? _selectedCountry;
  bool _isVerifyingEmail = false;
  final TextEditingController _otpController = TextEditingController();

  final List<Map<String, String>> _countries = [
    {'code': 'SA', 'name': 'السعودية', 'flag': '🇸🇦'},
    {'code': 'AE', 'name': 'الإمارات', 'flag': '🇦🇪'},
    {'code': 'KW', 'name': 'الكويت', 'flag': '🇰🇼'},
    {'code': 'QA', 'name': 'قطر', 'flag': '🇶🇦'},
    {'code': 'BH', 'name': 'البحرين', 'flag': '🇧🇭'},
    {'code': 'OM', 'name': 'عمان', 'flag': '🇴🇲'},
    {'code': 'EG', 'name': 'مصر', 'flag': '🇪🇬'},
    {'code': 'IQ', 'name': 'العراق', 'flag': '🇮🇶'},
    {'code': 'JO', 'name': 'الأردن', 'flag': '🇯🇴'},
    {'code': 'LB', 'name': 'لبنان', 'flag': '🇱🇧'},
    {'code': 'PS', 'name': 'فلسطين', 'flag': '🇵🇸'},
    {'code': 'SY', 'name': 'سوريا', 'flag': '🇸🇾'},
    {'code': 'YE', 'name': 'اليمن', 'flag': '🇾🇪'},
    {'code': 'LY', 'name': 'ليبيا', 'flag': '🇱🇾'},
    {'code': 'SD', 'name': 'السودان', 'flag': '🇸🇩'},
    {'code': 'DZ', 'name': 'الجزائر', 'flag': '🇩🇿'},
    {'code': 'MA', 'name': 'المغرب', 'flag': '🇲🇦'},
    {'code': 'TN', 'name': 'تونس', 'flag': '🇹🇳'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _referralCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _signUp() async {
    // التحقق من البيانات
    if (_nameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty ||
        _selectedGender == null ||
        _selectedCountry == null) {
      if (mounted) {
        String missingFields = 'يرجى ملء جميع الحقول';
        if (_selectedGender == null && _selectedCountry == null) {
          missingFields = 'يرجى اختيار الجنس والبلد';
        } else if (_selectedGender == null) {
          missingFields = 'يرجى اختيار الجنس';
        } else if (_selectedCountry == null) {
          missingFields = 'يرجى اختيار البلد';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(missingFields)));
      }
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('كلمات المرور غير متطابقة')),
        );
      }
      return;
    }

    if (_passwordController.text.length < 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
          ),
        );
      }
      return;
    }

    // فحص البريد واسم المستخدم في قاعدة البيانات فوراً قبل أي خطوة أخرى
    setState(() => _isLoading = true);
    try {
      final String targetEmail = _emailController.text.trim().toLowerCase();
      print("Checking existence for email: $targetEmail");

      // 1. فحص البريد الإلكتروني
      final emailQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: targetEmail)
          .get();

      print("Email check found ${emailQuery.docs.length} documents");

      if (emailQuery.docs.isNotEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هذا البريد الإلكتروني مسجل بالفعل، يرجى تسجيل الدخول'),
            backgroundColor: Colors.red, // لون أحمر للتنبيه القوي
          ),
        );
        return;
      }

      // 2. فحص اسم المستخدم
      final String targetUsername = _usernameController.text.trim();
      final usernameQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: targetUsername)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اسم المستخدم هذا مأخوذ بالفعل، اختر اسماً آخر'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } catch (e) {
      print("Check error: $e");
    }
    setState(() => _isLoading = false);

    if (!_isVerifyingEmail) {
      _startEmailVerification();
      return;
    }

    _completeSignUp();
  }

  void _startEmailVerification() async {
    setState(() => _isLoading = true);

    EmailOTP.config(
      appName: "MeTo",
      otpLength: 6,
      otpType: OTPType.numeric,
      emailTheme: EmailTheme.v4,
    );

    // وضع الرسالة المخصصة بتنسيق HTML احترافي لتجنب الـ Spam
    EmailOTP.setTemplate(
      template: """
      <div style='direction: rtl; text-align: center; font-family: sans-serif; padding: 20px;'>
        <h2 style='color: #009688;'>مرحباً بك في MeTo</h2>
        <p style='font-size: 16px;'>استخدم الرمز التالي لتأكيد حسابك والاستمتاع بمميزات التطبيق:</p>
        <div style='background-color: #f2f2f2; padding: 20px; border-radius: 10px; margin: 20px 0; display: inline-block;'>
          <span style='font-size: 32px; font-weight: bold; color: #333; letter-spacing: 10px;'>{{otp}}</span>
        </div>
        <p style='font-size: 12px; color: #777;'>هذا الرمز صالح لمدة 5 دقائق. إذا لم تطلب هذا الرمز، يرجى تجاهل الرسالة.</p>
        <div style='margin-top: 30px; border-top: 1px solid #eee; padding-top: 10px; font-size: 10px; color: #aaa;'>
          جميع الحقوق محفوظة &copy; تطبيق ميتو 2026
        </div>
      </div>
      """,
    );

    // TODO: يجب إعداد خادم الإرسال (SMTP) لكي تصل الرسائل فعلياً
    // يمكنك استخدام Gmail أو أي خدمة أخرى
    EmailOTP.setSMTP(
      host: "smtp.gmail.com",
      emailPort: EmailPort.port465,
      secureType: SecureType.ssl,
      username: "metoapp12@gmail.com",
      password: "rqla fnol wxco htqw", // تذكر استبدال هذا بالـ 16 حرفاً من جوجل
    );

    try {
      if (await EmailOTP.sendOTP(email: _emailController.text.trim())) {
        setState(() {
          _isVerifyingEmail = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رمز التحقق إلى بريدك الإلكتروني بنجاح'),
            backgroundColor: Colors.teal,
          ),
        );
      } else {
        throw "فشل إرسال الرمز، تأكد من صحة البريد الإلكتروني";
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // إظهار الخطأ الحقيقي للمساعدة في التشخيص
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في الإرسال: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      print("SMTP Error: $e");
    }
  }

  void _completeSignUp() async {
    if (!EmailOTP.verifyOTP(otp: _otpController.text.trim())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('رمز التحقق غير صحيح')));
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final authService = AuthService();
      final userService = UserService();
      final referralService = ReferralService();

      final result = await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (result != null) {
        final userCredential = result['userCredential'] as dynamic;
        final sessionId = result['sessionId'] as String?;

        if (userCredential != null && userCredential.user != null) {
          if (sessionId != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('sessionId', sessionId);
          }

          final newUid = userCredential.user!.uid;

          await userService.createUser(
            uid: newUid,
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            nickname: _nameController.text.trim(),
            sessionId: sessionId,
            gender: _selectedGender,
            country: _selectedCountry,
          );

          // تطبيق كود الدعوة (إن وُجد) بعد إنشاء ملف المستخدم
          final referralCode = _referralCodeController.text.trim();
          if (referralCode.isNotEmpty) {
            await referralService.applyReferralCode(
              newUserId: newUid,
              referralCode: referralCode,
            );
          }
        }
      }

      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleSocialSignIn(
    Future<UserCredential?> Function() signInMethod,
  ) async {
    // Check if country/gender is selected during social sign in flow as well?
    // Actually social sign in in this screen is for registration primarily if it's new.
    // However, usually we should ask for these after social login if they are missing.
    // For now, I'll allow social sign in without these or with defaults.
    // Let's stick to email signup requirements.

    setState(() => _isLoading = true);
    try {
      final result = await signInMethod();
      if (result != null && result.user != null) {
        // Check if user document exists
        final userDoc = await UserService().getUser(result.user!.uid);
        if (userDoc == null) {
          // New user (or missing doc): create it
          String username = result.user!.displayName ?? 'User';
          // Ensure we wait for creation to complete
          await UserService().createUser(
            uid: result.user!.uid,
            username: username,
            email: result.user!.email ?? '',
            nickname: username,
            profileImage: result.user!.photoURL,
            gender: _selectedGender, // Optional: capture if already selected
            country: _selectedCountry, // Optional: capture if already selected
          );

          // تطبيق كود الدعوة (إن وُجد) أيضاً مع التسجيل الاجتماعي
          final referralCode = _referralCodeController.text.trim();
          if (referralCode.isNotEmpty) {
            await ReferralService().applyReferralCode(
              newUserId: result.user!.uid,
              referralCode: referralCode,
            );
          }
        }

        if (mounted) {
          // Small delay to ensure Firestore propagation
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTermItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF009688),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF009688),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 26),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.gavel_rounded,
            size: 60,
            color: Colors.teal.shade700,
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'شروط الاستخدام والخصوصية',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'يرجى قراءة والموافقة على الشروط للمتابعة',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTermItem(
                'السلوك:',
                'يُحظر نشر أي محتوى مسيء أو غير قانوني أو هجمات شخصية.',
              ),
              _buildTermItem(
                'الأمان:',
                'أنت مسؤول بشكل كامل عن حماية بيانات دخولك ونشاط حسابك.',
              ),
              _buildTermItem(
                'المحتوى:',
                'نحتفظ بالحق في حذف أي محتوى يخالف معايير مجتمع ميتو.',
              ),
              _buildTermItem(
                'البيانات:',
                'نقوم بحماية بياناتك وخصوصيتك بأعلى معايير التشفير.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 50),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: () => setState(() => _isTermsAccepted = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009688),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 5,
            ),
            child: const Text(
              'أوافق والمتابعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'إلغاء والعودة',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(leading: const BackButton(color: Colors.white)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: !_isTermsAccepted
                ? _buildTermsView()
                : _isVerifyingEmail
                ? _buildVerificationView()
                : Column(
                    key: const ValueKey('signup_form'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar Picker
                      GestureDetector(
                        onTap: () {
                          // TODO: Image Picker
                        },
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withValues(alpha: 0.15),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.teal.shade50,
                                  Colors.teal.shade100,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              Icons.add_a_photo_rounded,
                              size: 40,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title Section
                      const SizedBox(height: 24),
                      const Text(
                        'إنشاء حساب جديد',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'انضم إلينا وابدأ رحلتك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Name, Username & Email
                      _buildElegantTextField(
                        controller: _nameController,
                        hintText: 'الاسم',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 16),

                      _buildElegantTextField(
                        controller: _usernameController,
                        hintText: 'المعرف الفريد (ID/Username)',
                        icon: Icons.alternate_email_rounded,
                      ),
                      const SizedBox(height: 16),

                      _buildElegantTextField(
                        controller: _emailController,
                        hintText: 'البريد الإلكتروني',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      // Selection Section (Gender and Country)
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showGenderPicker(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _selectedGender == 'male'
                                          ? Icons.male_rounded
                                          : _selectedGender == 'female'
                                          ? Icons.female_rounded
                                          : Icons.people_outline_rounded,
                                      color: Colors.teal.shade300,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _selectedGender == 'male'
                                          ? 'ذكر'
                                          : _selectedGender == 'female'
                                          ? 'أنثى'
                                          : 'الجنس',
                                      style: TextStyle(
                                        color: _selectedGender == null
                                            ? Colors.grey.shade400
                                            : Colors.black87,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showCountryPicker(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_selectedCountry == null) ...[
                                      const Text(
                                        '🏳️',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'البلد',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        _selectedCountry!.split(' ').last,
                                        style: const TextStyle(fontSize: 28),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Referral code (optional)
                      _buildElegantTextField(
                        controller: _referralCodeController,
                        hintText: 'رمز دعوة صديق (اختياري)',
                        icon: Icons.card_giftcard_rounded,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 16),

                      _buildElegantTextField(
                        controller: _passwordController,
                        hintText: 'كلمة المرور',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        isPasswordVisible: _isPasswordVisible,
                        onVisibilityChanged: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildElegantTextField(
                        controller: _confirmPasswordController,
                        hintText: 'تأكيد كلمة المرور',
                        icon: Icons.lock_reset_rounded,
                        isPassword: true,
                        isPasswordVisible: _isConfirmPasswordVisible,
                        onVisibilityChanged: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                      const SizedBox(height: 40),

                      // Sign Up Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signUp,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 8,
                            shadowColor: Colors.teal.withValues(alpha: 0.4),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF009688), Color(0xFF4DB6AC)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'إنشاء حساب',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Social Sign In
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'أو التسجيل عبر',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSocialButton(
                            onTap: () => _handleSocialSignIn(
                              AuthService().signInWithGoogle,
                            ),
                            icon: Icons.g_mobiledata_rounded, // Fallback icon
                            label: 'Google',
                            color: Colors.red.shade600,
                          ),
                          _buildSocialButton(
                            onTap: () => _handleSocialSignIn(
                              AuthService().signInWithFacebook,
                            ),
                            icon: Icons.facebook_rounded,
                            label: 'Facebook',
                            color: const Color(0xFF1877F2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'هل لديك حساب بالفعل؟ ',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(
                                context,
                              ).pushReplacementNamed('/login');
                            },
                            child: Text(
                              'دخول',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade700,
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.teal.shade200,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Terms and Privacy
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            Text(
                              'بإنشائك للحساب، فإنك توافق على ',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(
                                context,
                              ).pushNamed('/terms-of-use'),
                              child: Text(
                                'شروط الاستخدام',
                                style: TextStyle(
                                  color: Colors.teal.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              ' و ',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(
                                context,
                              ).pushNamed('/privacy-policy'),
                              child: Text(
                                'سياسة الخصوصية',
                                style: TextStyle(
                                  color: Colors.teal.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اختر الجنس',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildGenderOption(
                  'male',
                  'ذكر',
                  Icons.male_rounded,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildGenderOption(
                  'female',
                  'أنثى',
                  Icons.female_rounded,
                  Colors.pink,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderOption(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    bool isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedGender = value);
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.1)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const Text(
              'اختر البلد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _countries.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final country = _countries[index];
                  final countryString = "${country['name']} ${country['flag']}";
                  return ListTile(
                    leading: Text(
                      country['flag']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(country['name']!),
                    trailing: _selectedCountry == countryString
                        ? const Icon(Icons.check_circle, color: Colors.teal)
                        : null,
                    onTap: () {
                      setState(() => _selectedCountry = countryString);
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

  Widget _buildSocialButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElegantTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool? isPasswordVisible,
    VoidCallback? onVisibilityChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && (isPasswordVisible != true),
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: Icon(icon, color: Colors.teal.shade300, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible == true
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: onVisibilityChanged,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mark_email_read_rounded,
            size: 60,
            color: Colors.teal.shade700,
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'تأكيد البريد الإلكتروني',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          'تم إرسال رمز التحقق إلى ${_emailController.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: TextStyle(color: Colors.grey.shade300),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.teal.shade100),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFF009688)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'أدخل الرمز المكون من 6 أرقام للمتابعة',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 50),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _signUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009688),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 5,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'تأكيد وإنشاء الحساب',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => setState(() => _isVerifyingEmail = false),
          child: const Text(
            'تعديل البريد الإلكتروني',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
