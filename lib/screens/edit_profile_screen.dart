import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/storage_service.dart';
import '../services/task_service.dart';
import '../models/task_model.dart';
import '../models/user_model.dart' as model;
import '../widgets/framed_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late TextEditingController _cityController;
  late TextEditingController _workController;
  late TextEditingController _relationshipController;

  File? _imageFile;
  File? _coverFile;
  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedCountry;

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
    {'code': 'TR', 'name': 'تركيا', 'flag': '🇹🇷'},
    {'code': 'US', 'name': 'الولايات المتحدة', 'flag': '🇺🇸'},
    {'code': 'GB', 'name': 'المملكة المتحدة', 'flag': '🇬🇧'},
    {'code': 'DE', 'name': 'ألمانيا', 'flag': '🇩🇪'},
    {'code': 'FR', 'name': 'فرنسا', 'flag': '🇫🇷'},
    {'code': 'IT', 'name': 'إيطاليا', 'flag': '🇮🇹'},
    {'code': 'ES', 'name': 'إسبانيا', 'flag': '🇪🇸'},
    {'code': 'CA', 'name': 'كندا', 'flag': '🇨🇦'},
    {'code': 'AU', 'name': 'أستراليا', 'flag': '🇦🇺'},
    {'code': 'IN', 'name': 'الهند', 'flag': '🇮🇳'},
    {'code': 'PK', 'name': 'باكستان', 'flag': '🇵🇰'},
    {'code': 'ID', 'name': 'إندونيسيا', 'flag': '🇮🇩'},
    {'code': 'MY', 'name': 'ماليزيا', 'flag': '🇲🇾'},
    {'code': 'PH', 'name': 'الفلبين', 'flag': '🇵🇭'},
  ];

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  model.User? _currentUser;

  final List<String> _cartoonAvatars = [
    'assets/images/avatar/1.png',
    'assets/images/avatar/6.png',
    'assets/images/avatar/7.png',
    'assets/images/avatar/8.png',
    'assets/images/avatar/9.png',
    'assets/images/avatar/10.png',
    'assets/images/avatar/11.png',
    'assets/images/avatar/12.png',
    'assets/images/avatar/13.png',
    'assets/images/avatar/14.png',
    'assets/images/avatar/15.png',
    'assets/images/avatar/16.png',
    'assets/images/avatar/17.png',
    'assets/images/avatar/18.png',
    'assets/images/avatar/19.png',
    'assets/images/avatar/20.png',
    'assets/images/avatar/21.png',
    'assets/images/avatar/22.png',
    'assets/images/avatar/23.png',
    'assets/images/avatar/24.png',
    'assets/images/avatar/25.png',
    'assets/images/avatar/26.png',
    'assets/images/avatar/27.png',
    'assets/images/avatar/28.png',
    'assets/images/avatar/29.png',
    'assets/images/avatar/30.png',
    'assets/images/avatar/31.png',
    'assets/images/avatar/32.png',
    'assets/images/avatar/33.png',
    'assets/images/avatar/34.png',
    'assets/images/avatar/35.png',
    'assets/images/avatar/36.png',
    'assets/images/avatar/37.png',
    'assets/images/avatar/38.png',
    'assets/images/avatar/39.png',
    'assets/images/avatar/5.png',
    'assets/images/avatar/4.png',
    'assets/images/avatar/2.png',
    'assets/images/avatar/3.png',
  ];

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _nicknameController = TextEditingController();
    _bioController = TextEditingController();
    _cityController = TextEditingController();
    _workController = TextEditingController();
    _relationshipController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await UserService().getUser(user.uid);
      if (userData != null) {
        setState(() {
          _currentUser = userData;
          _usernameController.text = userData.username;
          _nicknameController.text = userData.nickname ?? '';
          _bioController.text = userData.bio ?? '';
          _cityController.text = userData.city ?? '';
          _workController.text = userData.work ?? '';
          _relationshipController.text = userData.relationshipStatus ?? '';
          _selectedDate = userData.birthDate;
          _selectedGender = userData.gender;
          _selectedCountry = userData.country;
          _selectedAnimatedPhoto = userData.profilePhotoAnimation;
        });
      }
    }
    setState(() => _isLoading = false);
  }

  String? _selectedAnimatedPhoto;
  File? _animatedFile;

  @override
  void dispose() {
    _usernameController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _workController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final storageService = StorageService();
      String? profileImageUrl = _currentUser?.profileImage;
      String? coverImageUrl = _currentUser?.coverImage;

      // Upload profile image if changed
      if (_imageFile != null) {
        profileImageUrl = await storageService.uploadProfileImage(
          uid: user.uid,
          file: _imageFile!,
        );
      }

      // Upload cover image if changed
      if (_coverFile != null) {
        coverImageUrl = await storageService.uploadCoverImage(
          uid: user.uid,
          file: _coverFile!,
        );
      }

      // Upload animated profile photo if changed
      if (_animatedFile != null) {
        _selectedAnimatedPhoto = await storageService.uploadProfileImage(
          uid: user.uid,
          file: _animatedFile!,
        );
      }

      // Update data in Firestore
      await UserService().updateUser(
        uid: user.uid,
        data: {
          'username': _usernameController.text.trim(),
          'nickname': _nicknameController.text.trim(),
          'bio': _bioController.text.trim(),
          'city': _cityController.text.trim(),
          'work': _workController.text.trim(),
          'relationshipStatus': _relationshipController.text.trim(),
          'birthDate': _selectedDate?.toIso8601String(),
          'gender': _selectedGender,
          'country': _selectedCountry,
          'profileImage': profileImageUrl,
          'coverImage': coverImageUrl,
          'profilePhotoAnimation': _selectedAnimatedPhoto,
        },
      );

      // تنظيف الذاكرة المؤقتة لكي تظهر الصورة المتحركة الجديدة مباشرة
      FramedAvatar.updateUserFrameCache(user.uid, null, animatedPhoto: null);

      // زيادة تقدم مهمة تغيير الصورة الشخصية إذا تم تغييرها
      if (_imageFile != null) {
        await TaskService().incrementTaskProgress(
          user.uid,
          TaskType.changeProfile,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ البيانات بنجاح')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage(bool forCover) async {
    if (forCover) {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _coverFile = File(image.path);
        });
      }
      return;
    }

    // Show selection menu for profile image
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                'تغيير الصورة الشخصية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: _buildImageOptionCard(
                      icon: Icons.photo_library_rounded,
                      label: 'الاستوديو',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromStudio();
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildImageOptionCard(
                      icon: Icons.face_retouching_natural_rounded,
                      label: 'صور كرتونية',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        _showCartoonSelector();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageOptionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCartoonSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5, // Fixed height to prevent dragging
          child: Column(
            children: [
              const SizedBox(height: 15),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'اختر صورة كرتونية',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5, // 5 images per row
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: _cartoonAvatars.length,
                  itemBuilder: (context, index) {
                    final avatarPath = _cartoonAvatars[index];
                    bool isSelected = _currentUser?.profileImage == avatarPath;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _imageFile = null;
                          _animatedFile = null;
                          _selectedAnimatedPhoto = null;
                          if (_currentUser != null) {
                            _currentUser = _currentUser!.copyWith(profileImage: avatarPath);
                          }
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.teal : Colors.grey.shade100,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(avatarPath, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromStudio() async {
    final XFile? media = await _picker.pickImage(source: ImageSource.gallery);
    if (media != null) {
      if (media.path.toLowerCase().endsWith('.mp4') ||
          media.path.toLowerCase().endsWith('.gif')) {
        setState(() {
          _animatedFile = File(media.path);
          _selectedAnimatedPhoto = media.path;
          _imageFile = null;
          if (_currentUser != null) {
            _currentUser = _currentUser!.copyWith(profileImage: '');
          }
        });
      } else {
        setState(() {
          _imageFile = File(media.path);
          _animatedFile = null;
          _selectedAnimatedPhoto = null;
          if (_currentUser != null) {
            _currentUser = _currentUser!.copyWith(profileImage: '');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('تعديل الملف الشخصي'),
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveProfile,
                  child: const Text(
                    'حفظ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Premium Cover and Profile Images Stack
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  // 1. Cover Image (At the back)
                  GestureDetector(
                    onTap: () => _pickImage(true),
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_coverFile != null)
                            Image.file(_coverFile!, fit: BoxFit.cover)
                          else if (_currentUser?.coverImage != null &&
                              _currentUser!.coverImage!.isNotEmpty)
                            Image.network(
                              _currentUser!.coverImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: Colors.grey.shade100),
                            ),
                          if (_coverFile == null &&
                              _currentUser?.coverImage == null)
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: Colors.teal.shade200,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'إضافة صورة غلاف',
                                    style: TextStyle(
                                      color: Colors.teal.shade300,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.3),
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Wall Hanging (Above Cover)
                  if (_currentUser?.activeWallHanging != null &&
                      _currentUser!.activeWallHanging!.isNotEmpty)
                    Positioned(
                      top: -10,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: double.infinity,
                            height: 300,
                            child:
                                _currentUser!.activeWallHanging!.endsWith(
                                      '.json',
                                    ) ||
                                    _currentUser!.activeWallHanging!.contains(
                                      'lottie',
                                    )
                                ? Lottie.network(
                                    _currentUser!.activeWallHanging!,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.topCenter,
                                  )
                                : (_currentUser!.activeWallHanging!.startsWith(
                                        'http',
                                      )
                                      ? Image.network(
                                          _currentUser!.activeWallHanging!,
                                          fit: BoxFit.contain,
                                          alignment: Alignment.topCenter,
                                        )
                                      : Image.asset(
                                          _currentUser!.activeWallHanging!,
                                          fit: BoxFit.contain,
                                          alignment: Alignment.topCenter,
                                        )),
                          ),
                        ),
                      ),
                    ),

                  // 3. Profile Image (On the very top and Centered)
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _pickImage(false),
                        child: SizedBox(
                          width: 90,
                          height: 90,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // Shadow and Border
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                              ),
                              // Avatar
                              FramedAvatar(
                                userId: _currentUser?.uid,
                                imageUrl: _imageFile != null
                                    ? _imageFile!.path
                                    : _currentUser?.profileImage,
                                radius: 40,
                                manualAnimatedPhoto: _selectedAnimatedPhoto,
                                disableAnimation: false,
                                useProfileFrameFallback: true,
                              ),
                              // Small Aesthetic Camera Icon
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.teal.shade400,
                                        Colors.teal.shade700,
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('المعرف (@username)'),
                  _buildElegantTextField(
                    controller: _usernameController,
                    hint: 'المعرف الفريد للحساب',
                    icon: Icons.alternate_email_rounded,
                    readOnly: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.teal),
                      onPressed: _showChangeIdentifierDialog,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('الكنية (الاسم الظاهر)'),
                  _buildElegantTextField(
                    controller: _nicknameController,
                    hint: 'الاسم الذي يظهر بدلاً من المعرف',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('السيرة الذاتية'),
                  _buildElegantTextField(
                    controller: _bioController,
                    hint: 'أخبر الآخرين عن نفسك...',
                    icon: Icons.info_outline,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('تاريخ الميلاد'),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: _buildSelectorCard(
                      icon: Icons.cake_outlined,
                      text: _selectedDate == null
                          ? 'اختر تاريخ الميلاد'
                          : _formatDate(_selectedDate!),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('الجنس'),
                  Row(
                    children: [
                      _buildGenderOption('male', 'ذكر'),
                      const SizedBox(width: 12),
                      _buildGenderOption('female', 'أنثى'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const SizedBox(height: 20),

                  _buildLabel('الدولة'),
                  GestureDetector(
                    onTap: () => _showCountryPicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          if (_selectedCountry == null) ...[
                            const Icon(Icons.flag_outlined, color: Colors.teal),
                            const SizedBox(width: 12),
                            const Text(
                              'اختر الدولة',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: 8),
                            Text(
                              _selectedCountry!.split(' ').first,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ],
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('المدينة'),
                  _buildElegantTextField(
                    controller: _cityController,
                    hint: 'المدينة الحالية',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('العمل'),
                  _buildElegantTextField(
                    controller: _workController,
                    hint: 'أين تعمل؟',
                    icon: Icons.work_outline,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('الحالة الاجتماعية'),
                  _buildElegantTextField(
                    controller: _relationshipController,
                    hint: 'متزوج، أعزب...',
                    icon: Icons.favorite_outline,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildElegantTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade100,
        prefixIcon: Icon(icon, color: Colors.teal),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  void _showChangeIdentifierDialog() {
    if (_currentUser == null) return;
    final TextEditingController newIdController = TextEditingController(
      text: _usernameController.text,
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'تغيير المعرف',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'تغيير المعرف يكلف 50 عملة ميتو. هل ترغب في المتابعة؟',
                style: TextStyle(fontFamily: 'Tajawal'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newIdController,
                decoration: InputDecoration(
                  hintText: 'المعرف الجديد',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                if (_currentUser!.coins < 50) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('رصيد العملات غير كافٍ (تحتاج 50 عملة)'),
                    ),
                  );
                  return;
                }
                final newId = newIdController.text.trim();
                if (newId.isEmpty) return;

                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await UserService().updateUser(
                    uid: _currentUser!.uid,
                    data: {
                      'username': newId,
                      'coins': FieldValue.increment(-50), // deduction
                    },
                  );
                  setState(() {
                    _usernameController.text = newId;
                    _currentUser = _currentUser!.copyWith(
                      username: newId,
                      coins: _currentUser!.coins - 50,
                    );
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تغيير المعرف وخصم 50 عملة بنجاح'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text(
                'تأكيد ودفع 50',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectorCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildGenderOption(String value, String label) {
    bool isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.teal : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                value == 'male'
                    ? 'assets/images/maile/Male.png'
                    : 'assets/images/maile/Female.png',
                width: 20,
                height: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.teal : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showCountryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          height: 500,
          child: Column(
            children: [
              const Text(
                'اختر الدولة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: _countries.length,
                  itemBuilder: (context, index) {
                    final country = _countries[index];
                    return ListTile(
                      leading: Text(
                        country['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(country['name']!),
                      onTap: () {
                        setState(() {
                          _selectedCountry =
                              '${country['flag']} ${country['name']}';
                        });
                        Navigator.pop(context);
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
}
