import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'support_inbox_screen.dart';
import 'faq_screen.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  final Color primaryColor = const Color(0xFF1A1A2E); // كحلي عميق
  final Color accentColor = const Color(0xFF00BFA5);  // تركواز
  final Color backgroundColor = const Color(0xFFF8F9FD);

  Future<void> _launchURL(String url, BuildContext context) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح الرابط')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('دعم MeTo التقني', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // هيدر جذاب
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [primaryColor, const Color(0xFF2B2B4E)]),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: accentColor.withOpacity(0.3), width: 3),
                            boxShadow: [
                              BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/avatar/12.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'كيف يمكننا مساعدتك اليوم؟',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'نحن هنا لضمان أفضل تجربة لك داخل ميتو',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'خيارات التواصل المتاحة',
                      style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // خيارات الدعم
                  _SupportOptionCard(
                    icon: Icons.forum_rounded,
                    color: Colors.orange,
                    title: 'مراسلة من نفس التطبيق',
                    subtitle: 'دردشة مباشرة مع الفريق التقني (أسرع خيار)',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportInboxScreen()));
                    },
                  ),
                  const SizedBox(height: 16),

                  _SupportOptionCard(
                    icon: Icons.send_rounded,
                    color: const Color(0xFF26A6E1),
                    title: 'دعم تليجرام الرسمي',
                    subtitle: 'تواصل معنا مباشرة عبر تطبيق تليجرام',
                    onTap: () => _launchURL('https://t.me/metoapp1', context),
                  ),
                  const SizedBox(height: 16),

                  _SupportOptionCard(
                    icon: Icons.email_rounded,
                    color: const Color(0xFFD44638),
                    title: 'البريد الإلكتروني',
                    subtitle: 'للمراسلات الرسمية والاستفسارات العامة',
                    onTap: () => _launchURL('mailto:support@meto.com', context),
                  ),
                  const SizedBox(height: 16),

                  _SupportOptionCard(
                    icon: Icons.help_center_rounded,
                    color: accentColor,
                    title: 'مركز المعرفة (FAQ)',
                    subtitle: 'حلول سريعة لأكثر المشاكل شيوعاً',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const FAQScreen()));
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  Text(
                    'MeTo Team v1.1.0',
                    style: GoogleFonts.tajawal(fontSize: 10, color: Colors.grey.shade400, letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportOptionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportOptionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1A1A2E)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.tajawal(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
