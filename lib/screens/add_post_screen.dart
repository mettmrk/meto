// ignore_for_file: prefer_final_fields, curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../services/storage_service.dart';
import '../services/task_service.dart';
import '../models/index.dart';
import '../models/task_model.dart';
import '../models/user_model.dart' as model;

class AddPostScreen extends StatefulWidget {
  final Post? post; // إذا تم تمرير بوست، فنحن في وضع التعديل
  const AddPostScreen({super.key, this.post});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  late TextEditingController _contentController;
  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  model.User? _currentUser;

  bool get isEditing => widget.post != null;

  // قوائم البيانات المطلوبة
  final List<String> _provinces = [
    'بغداد',
    'البصرة',
    'نينوى',
    'أربيل',
    'النجف',
    'كربلاء',
    'كركوك',
    'ديالى',
    'بابل',
    'الأنبار',
    'ذي قار',
    'ميسان',
    'المثنى',
    'القادسية',
    'صلاح الدين',
    'دهوك',
    'السليمانية',
    'حلبجة',
  ];

  final List<String> _categories = [
    'المستمسكات الشخصية والثبوتية',
    'المقتنيات المالية والمصرفية',
    'الأجهزة الإلكترونية والشخصية',
    'المفاتيح والمتعلقات اليومية',
    'الحقائب والأغراض المحمولة',
    'مقتنيات ثمينة ومتنوعة',
    'أطفال مفقودين',
    'حيوانات أليفة',
    'أخرى',
  ];

  String? _selectedProvince;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.post?.content ?? '',
    );
    _selectedProvince = widget.post?.province;
    _selectedCategory = widget.post?.category;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final data = await UserService().getUser(user.uid);
      if (mounted) setState(() => _currentUser = data);
    }
  }

  int get postsLeft {
    if (_currentUser == null) return 3;
    final nowIraq = DateTime.now().toUtc().add(const Duration(hours: 3));
    final todayDateStr = "${nowIraq.year}-${nowIraq.month.toString().padLeft(2, '0')}-${nowIraq.day.toString().padLeft(2, '0')}";
    
    String? lastResetDateStr;
    if (_currentUser!.lastPostResetDate != null) {
      final lastResetDate = _currentUser!.lastPostResetDate!.toUtc().add(const Duration(hours: 3));
      lastResetDateStr = "${lastResetDate.year}-${lastResetDate.month.toString().padLeft(2, '0')}-${lastResetDate.day.toString().padLeft(2, '0')}";
    }
    
    if (lastResetDateStr != todayDateStr) {
      return 3;
    } else {
      return (3 - _currentUser!.dailyPostsCount).clamp(0, 3);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  bool _isPickingImage = false;

  Future<void> _pickImages() async {
    if (_isPickingImage) return;

    setState(() {
      _isPickingImage = true;
    });

    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((image) => File(image.path)));
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  void _publishOrUpdatePost() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى كتابة وصف للمفقود')));
      return;
    }
    if (_selectedProvince == null || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المحافظة ونوع المفقود')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (isEditing) {
        // تحديث البوست
        await PostService().updatePost(
          postId: widget.post!.id,
          content: _contentController.text.trim(),
          province: _selectedProvince,
          category: _selectedCategory,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث المنشور بنجاح')),
          );
          Navigator.pop(context);
        }
      } else {
        // نشر بوست جديد
        List<String> imageUrls = [];
        if (_selectedImages.isNotEmpty) {
          for (var file in _selectedImages) {
            final url = await StorageService().uploadPostImage(
              userId: user.uid,
              file: file,
            );
            imageUrls.add(url);
          }
        }

        await PostService().createPost(
          userId: user.uid,
          username:
              _currentUser?.nickname ?? _currentUser?.username ?? 'مستخدم',
          content: _contentController.text.trim(),
          province: _selectedProvince!,
          category: _selectedCategory!,
          userProfileImage: _currentUser?.profileImage,
          images: imageUrls,
        );

        if (mounted) {
          // مهمة: نشر منشور
          TaskService().incrementTaskProgress(user.uid, TaskType.addPost);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Off-white background
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل المنشور' : 'بلاغ عن مفقود'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ElevatedButton(
              onPressed: (_isLoading || (postsLeft == 0 && !isEditing)) ? null : _publishOrUpdatePost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isEditing ? 'تحديث' : 'نشر',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info (Optional, adds a nice touch)
            if (_currentUser != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: _currentUser!.profileImage != null
                          ? NetworkImage(_currentUser!.profileImage!)
                          : null,
                      backgroundColor: Colors.grey[200],
                      child: _currentUser!.profileImage == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser!.nickname ?? _currentUser!.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const Text(
                          'جاري إنشاء بلاغ جديد...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            if (_currentUser != null && !isEditing)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: postsLeft > 0 ? Colors.teal.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: postsLeft > 0 ? Colors.teal.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      postsLeft > 0 ? Icons.info_outline : Icons.warning_amber_rounded,
                      color: postsLeft > 0 ? Colors.teal.shade700 : Colors.red.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            postsLeft > 0 
                              ? 'البلاغات المتاحة لك اليوم: $postsLeft من أصل 3'
                              : 'لقد استنفدت صلاحية النشر اليوم',
                            style: TextStyle(
                              color: postsLeft > 0 ? Colors.teal.shade900 : Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            postsLeft > 0
                              ? 'يتم تجديد الصلاحية يومياً في تمام الساعة 00:00 بتوقيت العراق'
                              : 'سيتم تجديد الصلاحية (3 بلاغات) في تمام الساعة 00:00 بتوقيت العراق',
                            style: TextStyle(
                              color: postsLeft > 0 ? Colors.teal.shade700 : Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Selectors Row
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField(
                    value: _selectedProvince,
                    hint: 'المحافظة',
                    icon: Icons.location_on_outlined,
                    items: _provinces,
                    onChanged: (val) => setState(() => _selectedProvince = val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownField(
                    value: _selectedCategory,
                    hint: 'النوع',
                    icon: Icons.category_outlined,
                    items: _categories,
                    onChanged: (val) => setState(() => _selectedCategory = val),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Content Input
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _contentController,
                maxLines: 8,
                style: const TextStyle(fontSize: 16, height: 1.5),
                decoration: InputDecoration(
                  hintText:
                      'اكتب تفاصيل المفقود هنا...\n\nمثال: فقدت محفظة سوداء تحتوي على هوية في منطقة المنصور - بغداد، الساعة ٥ عصراً.',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Images Section
            if (!isEditing) ...[
              const Text(
                'الصور المرفقة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Add Button
                    InkWell(
                      onTap: _pickImages,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.teal.shade200,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: Colors.teal.shade700,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'إضافة',
                              style: TextStyle(
                                color: Colors.teal.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Selected Images
                    ..._selectedImages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                image: DecorationImage(
                                  image: FileImage(file),
                                  fit: BoxFit.cover,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: -8,
                              right: -8,
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => _selectedImages.removeAt(index),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                hint,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          isExpanded: true,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
