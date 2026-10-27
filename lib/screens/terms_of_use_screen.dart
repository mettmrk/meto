import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          'شروط الاستخدام',
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
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 60,
                  color: Colors.amber.shade700,
                ),
              ),
            ),
            const SizedBox(height: 30),
            _buildSection(
              '1. الموافقة على الشروط',
              'من خلال الاستمرار في استخدام تطبيق ميتو، فإنك توافق على الالتزام بشروط الاستخدام هذه. إذا كنت لا توافق على هذه الشروط، يرجى التوقف عن استخدام التطبيق.',
            ),
            _buildSection(
              '2. الحساب والأمان',
              'أنت مسؤول عن الحفاظ على سرية معلومات حسابك وكلمة مرورك. كما أنك مسؤول عن جميع الأنشطة التي تحدث تحت حسابك.',
            ),
            _buildSection(
              '3. قواعد السلوك',
              'يُحظر استخدام التطبيق لأي أهداف غير قانونية أو لانتهاك حقوق الآخرين. لا يُسمح بالمحتوى المسيء، أو الهجمات الشخصية، أو المحتوى المحمي بحقوق الملكية الفكرية دون إذن.',
            ),
            _buildSection(
              '4. الملكية الفكرية',
              'جميع حقوق الملكية الفكرية في التطبيق والمحتوى الأصلي هي ملك لميتو. لا يجوز لك نسخ أو تعديل أو توزيع المحتوى دون إذن مسبق.',
            ),
            _buildSection(
              '5. تحديد المسؤولية',
              'يتم تقديم التطبيق "كما هو" وبدون أي ضمانات. لا ننتحمل مسؤولية أي أضرار ناتجة عن استخدامك للتطبيق أو تعذر الوصول إليه.',
            ),
            _buildSection(
              '6. التغييرات على الشروط',
              'نحتفظ بالحق في تعديل هذه الشروط في أي وقت. سيتم إخطارك بالتعديلات الرئيسية عبر التطبيق.',
            ),
            _buildSection(
              '7. القانون السائد',
              'تخضع هذه الشروط لقوانين الدولة المحددة لمقر ميتو، وأي نزاع سيتم التعامل معه وفقاً للاختصاص القضائي المعني.',
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
