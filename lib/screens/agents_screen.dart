import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class AgentsScreen extends StatelessWidget {
  const AgentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F1D),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF001F1D),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text(
                'الوكلاء المعتمدون',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Tajawal',
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF00BFA5).withOpacity(0.2),
                      const Color(0xFF001F1D),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                   _buildAgencyRequestCard(context),
                   const SizedBox(height: 12),
                   _buildIntroCard(),
                   const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('agents').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF00BFA5))),
                );
              }
              
              var docs = snapshot.data?.docs ?? [];
              
              if (docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.support_agent_rounded, size: 80, color: Colors.white12),
                        const SizedBox(height: 16),
                        const Text(
                          'لا يوجد وكلاء متاحون حالياً',
                          style: TextStyle(color: Colors.white38, fontSize: 16, fontFamily: 'Tajawal'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'سيتم إضافة الوكلاء المعتمدين قريباً',
                          style: TextStyle(color: Colors.white24, fontSize: 12, fontFamily: 'Tajawal'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final sortedDocs = docs.toList();
              sortedDocs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aRating = aData['rating'] ?? 0;
                final bRating = bData['rating'] ?? 0;
                return bRating.compareTo(aRating);
              });

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final data = sortedDocs[index].data() as Map<String, dynamic>;
                      return _buildAgentCard(context, sortedDocs[index].id, data);
                    },
                    childCount: sortedDocs.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _buildAgencyRequestCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF00BFA5),
            Color(0xFF00897B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BFA5).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, '/agency-request');
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.business_center_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'طلب توثيق وكالة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'هل ترغب في الانضمام كوكيل معتمد؟ قدم طلبك الآن',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF00BFA5), size: 30),
          const SizedBox(width: 15),
          const Expanded(
            child: Text(
              'يمكنك التواصل مع الوكلاء المعتمدين لشحن رصيدك بأمان وثقة تامة.',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Tajawal'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(BuildContext context, String agentId, Map<String, dynamic> data) {
    final String agentFullName = (data['fullName'] ?? data['agentFullName'])?.toString().trim() ?? '';
    String name = agentFullName.isNotEmpty ? agentFullName : (data['name'] ?? data['username'] ?? 'وكيل معتمد');
    if (name == 'بدون اسم') name = 'وكيل معتمد';
    final province = data['fullName'] != null ? (data['province'] ?? 'غير محدد') : (data['agentProvince'] ?? 'غير محدد');
    final phone = (data['phone'] ?? data['agentPhone'] ?? '').toString();
    final telegram = (data['telegram'] ?? data['agentTelegram'] ?? '').toString();

    return GestureDetector(
      onTap: () => _showAgentDetails(context, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              children: [
                Stack(
                  children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(agentId).snapshots(),
                  builder: (context, userSnapshot) {
                    String? displayPhoto;
                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                      displayPhoto = userData['profileImage'] ?? userData['photoUrl'];
                    }
                    displayPhoto ??= data['photoUrl'];

                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF00BFA5), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.grey[900],
                        backgroundImage: (displayPhoto != null && displayPhoto.isNotEmpty && !displayPhoto.startsWith('assets/')) 
                            ? NetworkImage(displayPhoto) 
                            : null,
                        child: (displayPhoto != null && displayPhoto.startsWith('assets/'))
                            ? ClipOval(child: Image.asset(displayPhoto, fit: BoxFit.cover, width: 70, height: 70))
                            : (displayPhoto == null || displayPhoto.isEmpty)
                                ? const Icon(Icons.person, color: Colors.white24, size: 35)
                                : null,
                      ),
                    );
                  },
                ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00BFA5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (index) {
                    final int rating = data['rating'] ?? 0;
                    return Icon(
                      index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 14,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white38, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        province,
                        style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Tajawal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'وكيل معتمد',
                      style: TextStyle(
                        color: Color(0xFF00BFA5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                if (telegram.isNotEmpty)
                  _buildContactButton(
                    icon: Icons.telegram,
                    color: const Color(0xFF26A6E1), // Telegram Blue
                    onTap: () {
                      final username = telegram.startsWith('@') ? telegram.substring(1) : telegram;
                      // Handle case where user might have entered the full link
                      final cleanUsername = username.replaceAll('https://t.me/', '').replaceAll('t.me/', '');
                      _launchURL('https://t.me/$cleanUsername');
                    },
                  ),
                const SizedBox(height: 10),
                if (phone.isNotEmpty)
                  _buildContactButton(
                    icon: Icons.phone_rounded,
                    color: Colors.blueAccent,
                    onTap: () => _launchURL('tel:$phone'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAgentDetails(BuildContext context, Map<String, dynamic> data) {
    final photoUrl = data['photoUrl'];
    
    final String agentFullName = (data['fullName'] ?? data['agentFullName'])?.toString().trim() ?? '';
    String detailName = agentFullName.isNotEmpty ? agentFullName : (data['name'] ?? data['username'] ?? 'وكيل معتمد');
    if (detailName == 'بدون اسم') detailName = 'وكيل معتمد';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF001F1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25), side: BorderSide(color: const Color(0xFF00BFA5).withOpacity(0.3))),
        title: const Text('تفاصيل الوكيل', style: TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(data['uid'] ?? data['id'] ?? '').snapshots(),
                builder: (context, userSnapshot) {
                  String? displayPhoto = photoUrl;
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                    displayPhoto = userData['profileImage'] ?? userData['photoUrl'] ?? displayPhoto;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00BFA5), width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[900],
                      backgroundImage: (displayPhoto != null && displayPhoto.isNotEmpty && !displayPhoto.startsWith('assets/')) 
                          ? NetworkImage(displayPhoto) 
                          : null,
                      child: (displayPhoto != null && displayPhoto.startsWith('assets/'))
                          ? ClipOval(child: Image.asset(displayPhoto, fit: BoxFit.cover, width: 100, height: 100))
                          : (displayPhoto == null || displayPhoto.isEmpty)
                              ? const Icon(Icons.person, size: 50, color: Colors.white24)
                              : null,
                    ),
                  );
                },
              ),
              _detailRow(Icons.person, 'الاسم الكامل', detailName),
              _detailRow(Icons.phone, 'رقم الهاتف', (data['phone'] ?? data['agentPhone'] ?? 'غير متوفر').toString()),
              _detailRow(Icons.location_city, 'المحافظة', (data['province'] ?? data['agentProvince'] ?? 'غير متوفر').toString()),
              _detailRow(Icons.map, 'العنوان', (data['address'] ?? data['agentAddress'] ?? 'غير متوفر').toString()),
              _detailRow(Icons.assistant_navigation, 'أقرب نقطة دالة', (data['landmark'] ?? data['agentLandmark'] ?? 'غير متوفر').toString()),
              GestureDetector(
                onTap: () {
                  final telegram = (data['telegram'] ?? data['agentTelegram'] ?? '');
                  if (telegram.isNotEmpty) {
                    final username = telegram.startsWith('@') ? telegram.substring(1) : telegram;
                    final cleanUsername = username.replaceAll('https://t.me/', '').replaceAll('t.me/', '');
                    _launchURL('https://t.me/$cleanUsername');
                  }
                },
                child: _detailRow(Icons.telegram, 'معرف التليجرام', (data['telegram'] ?? data['agentTelegram'] ?? 'غير متوفر').toString()),
              ),
              _detailRow(Icons.payment, 'وسائل الدفع', (data['paymentMethods'] ?? data['agentPaymentMethods'] ?? 'غير متوفر').toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق', style: TextStyle(color: Color(0xFF00BFA5), fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00BFA5), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Tajawal')),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Tajawal')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Future<void> _launchURL(String? url) async {
    if (url == null || url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
