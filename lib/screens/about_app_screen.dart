import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/level_badge.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  final Color primaryColor = const Color(0xFF1A1A2E);
  final Color accentColor = const Color(0xFF00BFA5);
  final Color backgroundColor = const Color(0xFFF8F9FD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('حول ميتو MeTo', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // لوجو التطبيق وشكله العام
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: primaryColor.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.asset(
                  'assets/images/logo.png', // تأكد من وجود شعار أو صورة مناسبة
                  width: 100,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) => const LevelBadge(level: 90, size: 80),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'MeTo',
              style: GoogleFonts.tajawal(fontSize: 28, fontWeight: FontWeight.w900, color: primaryColor, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Text(
              'الإصدار 1.1.0 (PRO)',
              style: GoogleFonts.tajawal(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            // وصف التطبيق
            _buildAboutCard(
              title: 'ما هو "ميتو"؟',
              content: 'MeTo هو تطبيق تواصل اجتماعي يعتمد على غرف المحادثة الصوتية عالية الجودة. يهدف ميتو لربط الناس من مختلف بقاع العالم في بيئة آمنة، ممتعة، ومليئة بالفعاليات الترفيهية.',
            ),
            const SizedBox(height: 16),

            // أهدافنا
            _buildAboutCard(
              title: 'قيمنا وأهدافنا',
              content: 'نسعى في ميتو لتوفير تجربة مستخدم خالية من التعقيد، مع التركيز التام على جودة الصوت، الخصوصية، وبناء مجتمع إيجابي قائم على الاحترام المتبادل.',
            ),
            const SizedBox(height: 40),

            // روابط التواصل أو الشروط
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSmallLink('سياسة الخصوصية', () => Navigator.of(context).pushNamed('/privacy-policy')),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('|', style: TextStyle(color: Colors.grey)),
                ),
                _buildSmallLink('شروط الاستخدام', () => Navigator.of(context).pushNamed('/terms-of-use')),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'حقوق الطبع والنشر © 2026 MeTo Team\nجميع الحقوق محفوظة',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(fontSize: 11, color: Colors.grey, height: 1.6),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard({required String title, required String content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.bold, color: primaryColor),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.tajawal(fontSize: 14, height: 1.7, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w600, color: accentColor),
      ),
    );
  }
}
