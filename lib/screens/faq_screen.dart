import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  final Color primaryColor = const Color(0xFF1A1A2E);
  final Color accentColor = const Color(0xFF00BFA5);
  final Color backgroundColor = const Color(0xFFF8F9FD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('مركز المعرفة (FAQ)', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildFAQCategory('المنتجات والعملات', [
            _FAQItem(
              question: 'كيف يمكنني شراء العملات؟',
              answer: 'يمكنك شراء العملات من خلال متجر التطبيق عبر الضغط على أيقونة المحفظة في صفحتك الشخصية واختيار طريقة الدفع المناسبة.',
            ),
            _FAQItem(
              question: 'ما هي فوائد المستوى الذهبي؟',
              answer: 'المستوى الذهبي يمنحك شارات حصرية، إمكانية دخول الغرف الممتلئة، وهدايا مجانية يومية.',
            ),
          ]),
          const SizedBox(height: 24),
          _buildFAQCategory('إدارة الغرف', [
            _FAQItem(
              question: 'كيف أرقي شخصاً لمنصب مشرف؟',
              answer: 'داخل الغرفة، اضغط على صورة الشخص ثم اختر "تعيين كمشرف" من القائمة المنبثقة.',
            ),
            _FAQItem(
              question: 'هل يمكنني تغيير خلفية الغرفة؟',
              answer: 'نعم، من إعدادات الغرفة يمكنك اختيار خلفيات مسبقة الصنع أو رفع صورة خاصة إذا كنت تملك اشتراكاً مميزاً.',
            ),
          ]),
          const SizedBox(height: 24),
          _buildFAQCategory('الحساب والخصوصية', [
            _FAQItem(
              question: 'كيف يمكنني تفعيل الحساب الخاص؟',
              answer: 'اذهب إلى الإعدادات > الحساب والخصوصية > فعل خيار "حساب خاص" لإخفاء ظهورك ونشاطاتك.',
            ),
            _FAQItem(
              question: 'نسيت كلمة المرور، ماذا أفعل؟',
              answer: 'في صفحة تسجيل الدخول، اضغط على "نسيت كلمة المرور" وسيصلك رابط إعادة التعيين على بريدك المسجل.',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildFAQCategory(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 12),
          child: Text(
            title,
            style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800, color: primaryColor),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FAQItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            question,
            style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E)),
          ),
          iconColor: const Color(0xFF00BFA5),
          collapsedIconColor: Colors.grey,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              answer,
              style: GoogleFonts.tajawal(fontSize: 13, height: 1.6, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
