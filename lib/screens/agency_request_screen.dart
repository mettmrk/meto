import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AgencyRequestScreen extends StatefulWidget {
  const AgencyRequestScreen({super.key});

  @override
  State<AgencyRequestScreen> createState() => _AgencyRequestScreenState();
}

class _AgencyRequestScreenState extends State<AgencyRequestScreen> {
  bool _isTermsAccepted = false;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _provinceController = TextEditingController();
  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _telegramController = TextEditingController();
  final _paymentMethodsController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _provinceController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    _telegramController.dispose();
    _paymentMethodsController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'يجب تسجيل الدخول أولاً';

      // السماح بالتقديم فقط إذا لم يكن هناك طلب "نشط" قيد المراجعة
      final existingPending = await FirebaseFirestore.instance
          .collection('agency_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingPending.docs.isNotEmpty) {
        throw 'لديك طلب نشط بالفعل قيد المراجعة.';
      }

      // التحقق مما إذا كان وكيلاً فعلياً بالفعل
      final agentDoc = await FirebaseFirestore.instance
          .collection('agents')
          .doc(user.uid)
          .get();
      if (agentDoc.exists) {
        throw 'أنت وكيل معتمد بالفعل.';
      }

      await FirebaseFirestore.instance.collection('agency_requests').add({
        'userId': user.uid,
        'username': user.displayName ?? 'بدون اسم',
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'province': _provinceController.text.trim(),
        'address': _addressController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'telegram': _telegramController.text.trim(),
        'paymentMethods': _paymentMethodsController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF001F1D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'تم الإرسال بنجاح',
              style: TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
            ),
            content: const Text(
              'لقد تم استلام طلبك بنجاح. سنقوم بمراجعته والتواصل معك قريباً.',
              style: TextStyle(color: Colors.white70, fontFamily: 'Tajawal'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text(
                  'حسناً',
                  style: TextStyle(color: Color(0xFF00BFA5)),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF001F1D),
        body: Center(
          child: Text(
            'يرجى تسجيل الدخول',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF001F1D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'طلب توثيق وكالة',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('app_settings')
            .doc('global')
            .snapshots(),
        builder: (context, settingsSnapshot) {
          final settings =
              settingsSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final bool isEnabled =
              settings['isAgencyApplicationsEnabled'] ?? true;

          if (!isEnabled) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.amber,
                      size: 80,
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'طلبات الوكالة متوقفة حالياً',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'نعتذر، لقد تم إيقاف استقبال طلبات التوثيق الجديدة مؤقتاً بقرار من الإدارة. يرجى المحاولة في وقت لاحق.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontFamily: 'Tajawal',
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<DocumentSnapshot>(
            // التحقق من حالة الوكيل الفعلي أولاً
            stream: FirebaseFirestore.instance
                .collection('agents')
                .doc(user.uid)
                .snapshots(),
            builder: (context, agentSnapshot) {
              if (agentSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
                );
              }

              final bool isActualAgent =
                  agentSnapshot.hasData && agentSnapshot.data!.exists;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('agency_requests')
                    .where('userId', isEqualTo: user.uid)
                    .orderBy('createdAt', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00BFA5),
                      ),
                    );
                  }

                  // إذا كان وكيلاً فعلياً، نظهر له صفحة القبول
                  if (isActualAgent) {
                    final requestData =
                        (snapshot.hasData && snapshot.data!.docs.isNotEmpty)
                        ? snapshot.data!.docs.first.data()
                              as Map<String, dynamic>
                        : <String, dynamic>{};
                    return _buildStatusView('accepted', requestData);
                  }

                  // إذا لم يكن وكيلاً، نتحقق من حالة آخر طلب
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final request =
                        snapshot.data!.docs.first.data()
                            as Map<String, dynamic>;
                    final status = request['status'] ?? 'pending';

                    // نظهر حالة الانتظار فقط إذا كان الطلب معلقاً
                    if (status == 'pending') {
                      return _buildStatusView(status, request);
                    }

                    // إذا كان مرفوضاً أو مسحوباً (Accepted but not in agents collection)
                    // نترك البرنامج يكمل ليظهر استمارة التقديم كما طلب المستخدم
                  }

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: !_isTermsAccepted
                        ? _buildTermsView()
                        : _buildFormView(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusView(String status, Map<String, dynamic> data) {
    IconData icon;
    Color color;
    String title;
    String message;

    switch (status) {
      case 'accepted':
        icon = Icons.verified_rounded;
        color = const Color(0xFF00BFA5);
        title = 'مبارك! أنت وكيل معتمد';
        message =
            'لقد تم توثيق حسابك كوكيل رسمي لدى ميتو. يمكنك الآن البدء بتقديم خدماتك.';
        break;
      case 'rejected':
        icon = Icons.cancel_rounded;
        color = Colors.redAccent;
        title = 'عذراً، تم رفض الطلب سابقا';
        message =
            'لم يتم قبول طلبك السابق. يمكنك مراجعة الشروط والتقديم مرة أخرى أدناه.';
        break;
      default: // pending
        icon = Icons.pending_actions_rounded;
        color = Colors.amber;
        title = 'طلبك قيد المراجعة حالياً';
        message =
            'نحن نقوم بمراجعة معلوماتك. يرجى الانتظار، سيتم الرد عليك قريباً.';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 80),
            ),
            const SizedBox(height: 30),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  fontFamily: 'Tajawal',
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (status == 'pending' &&
                data['adminFeedback'] != null &&
                data['adminFeedback'].toString().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFA5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFF00BFA5).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'رسالة من الإدارة:',
                      style: TextStyle(
                        color: Color(0xFF00BFA5),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['adminFeedback'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'Tajawal',
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

            // New Chat Section for Pending Requests
            if (status == 'pending') _buildAgencyChat(data, data['userId']),

            const SizedBox(height: 50),
            if (status == 'rejected')
              ElevatedButton(
                onPressed: () => setState(() => _isTermsAccepted = false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                ),
                child: const Text(
                  'تقديم طلب جديد',
                  style: TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                ),
              ),
            if (status != 'rejected')
              SizedBox(
                width: 200,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'الرجوع للخلف',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgencyChat(Map<String, dynamic> data, String userId) {
    final messages = data['messages'] as List? ?? [];
    final msgController = TextEditingController();

    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_rounded,
                color: Color(0xFF00BFA5),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'محادثة مع الإدارة',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: messages.length,
            itemBuilder: (context, idx) {
              final msg = messages[idx];
              bool isUser = msg['sender'] == 'user';
              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF00BFA5)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    msg['text'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: msgController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'اكتب ردك هنا...',
                    hintStyle: TextStyle(
                      color: Colors.white30,
                      fontSize: 12,
                      fontFamily: 'Tajawal',
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFF00BFA5)),
                onPressed: () async {
                  if (msgController.text.trim().isEmpty) return;
                  // Local reference to firestore to send message
                  // In the real app, we should use a service method
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  final q = await FirebaseFirestore.instance
                      .collection('agency_requests')
                      .where('userId', isEqualTo: user.uid)
                      .orderBy('createdAt', descending: true)
                      .limit(1)
                      .get();

                  if (q.docs.isNotEmpty) {
                    await q.docs.first.reference.update({
                      'messages': FieldValue.arrayUnion([
                        {
                          'sender': 'user',
                          'text': msgController.text.trim(),
                          'timestamp': DateTime.now().millisecondsSinceEpoch,
                        },
                      ]),
                      'lastMessageAt': FieldValue.serverTimestamp(),
                    });
                    msgController.clear();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF00BFA5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.gavel_rounded,
                  color: Color(0xFF00BFA5),
                  size: 50,
                ),
                const SizedBox(height: 15),
                const Text(
                  'شروط وكلاء ميتو المعتمدين',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'يرجى قراءة الشروط التالية بعناية قبل تقديم الطلب لضمان فهمك الكامل لالتزامات الوكالة.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontFamily: 'Tajawal',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _buildTermRule(
            '1. الأمانة والمصداقية:',
            'يجب على الوكيل التعامل بصدق وأمانة مع جميع المستخدمين وعدم استغلالهم.',
          ),
          _buildTermRule(
            '2. توقيت العمل:',
            'الالتزام بتوفير الخدمات خلال الأوقات المحددة في ملفك الشخصي.',
          ),
          _buildTermRule(
            '3. حماية البيانات:',
            'يُمنع مشاركة بيانات المستخدمين أو استغلال معرفاتهم لأغراض غير رسمية.',
          ),
          _buildTermRule(
            '4. العمولات:',
            'الالتزام بأسعار الشحن والعمولات المقررة من قبل إدارة تطبيق ميتو.',
          ),
          _buildTermRule(
            '5. التوثيق:',
            'يجب تقديم معلومات حقيقية وصحيحة، وأي تلاعب يؤدي إلى سحب الوكالة فوراً.',
          ),
          _buildTermRule(
            '6. رسوم التوثيق:',
            'تبلغ تكلفة الحصول على توثيق الوكالة 1,125,000 عملة ميتو مايعادل تقريبا 225 دولار امريكي يتم دفعها عند تفعيل الوكالة.',
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: () => setState(() => _isTermsAccepted = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'أوافق على الشروط ومتابعة',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermRule(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF00BFA5),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const Text(
              'استمارة معلومات الوكيل',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'يرجى ملء الحقول التالية بدقة كما ستظهر للمستخدمين لاحقاً.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontFamily: 'Tajawal',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _buildTextField(
              _fullNameController,
              'الاسم الكامل',
              Icons.person_rounded,
            ),
            _buildTextField(
              _phoneController,
              'رقم الهاتف (واتساب)',
              Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              _provinceController,
              'المحافظة',
              Icons.location_city_rounded,
            ),
            _buildTextField(
              _addressController,
              'العنوان بالتفصيل',
              Icons.map_rounded,
            ),
            _buildTextField(
              _landmarkController,
              'أقرب نقطة دالة',
              Icons.assistant_navigation,
            ),
            _buildTextField(
              _telegramController,
              'معرف التليجرام (بدون @)',
              Icons.telegram_rounded,
            ),
            _buildTextField(
              _paymentMethodsController,
              'وسائل الدفع المتاحة للزملاء',
              Icons.payment_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'إرسال الطلب للمراجعة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF00BFA5), size: 20),
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
            fontFamily: 'Tajawal',
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF00BFA5), width: 1),
          ),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
      ),
    );
  }
}
