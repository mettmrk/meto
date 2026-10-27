import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'سياسة الخصوصية',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF009688),
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.privacy_tip_outlined,
                  size: 60,
                  color: Colors.teal.shade700,
                ),
              ),
            ),
            const SizedBox(height: 30),
            _buildSection(
              '1. مقدمة',
              'نحن نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية. توضح سياسة الخصوصية هذه كيفية جمع بياناتك واستخدامها وحمايتها عند استخدام تطبيق ميتو.',
            ),
            _buildSection(
              '2. البيانات التي نجمعها',
              'نقوم بجمع المعلومات التي تقدمها لنا مباشرة عند إنشاء حساب، مثل الاسم، البريد الإلكتروني، وصورة الملف الشخصي. كما نجمع بيانات تقنية حول جهازك وكيفية استخدامك للتطبيق لتقديم تجربة أفضل.',
            ),
            _buildSection(
              '3. كيف نستخدم بياناتك',
              'نستخدم البيانات لتقديم خدماتنا، وتحسين جودة التطبيق، والتواصل معك بشأن التحديثات أو العروض، وضمان أمان حسابك ومنع أي نشاط غير قانوني.',
            ),
            _buildSection(
              '4. مشاركة البيانات',
              'لا نقوم ببيع بياناتك الشخصية لأطراف ثالثة. قد نشارك البيانات فقط مع شركاء الخدمة الموثوقين لغرض تشغيل التطبيق أو إذا كان ذلك مطلوباً بموجب القانون.',
            ),
            _buildSection(
              '5. حماية البيانات',
              'نتخذ تدابير أمنية تقنية وإدارية قوية لحماية بياناتك من الوصول غير المصرح به أو الفقدان أو التعديل.',
            ),
            _buildSection(
              '6. حقوقك',
              'لديك الحق في الوصول إلى بياناتك الشخصية، وتصحيحها، أو طلب حذفها في أي وقت عبر إعدادات التطبيق أو التواصل مع الدعم الفني.',
            ),
            _buildSection(
              '7. التغييرات على السياسة',
              'قد نقوم بتحديث سياسة الخصوصية هذه من وقت لآخر. سيتم إخطارك بأي تغييرات جوهرية من خلال التطبيق.',
            ),
            const SizedBox(height: 40),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'آخر تحديث: مارس 2026',
                  style: GoogleFonts.tajawal(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF009688),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.tajawal(
              fontSize: 15,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
