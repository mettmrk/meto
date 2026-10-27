import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import '../services/index.dart';

class WalletScreen extends StatefulWidget {
  final String userId;
  const WalletScreen({super.key, required this.userId});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with TickerProviderStateMixin {
  final GiftService _giftService = GiftService();
  final RewardService _rewardService = RewardService();
  final ReferralService _referralService = ReferralService();
  int _userCoins = 0;
  int _userDiamonds = 0;
  bool _isProcessingWithdraw = false;

  void _showSuccess(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF003833),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF00BFA5),
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'حسناً',
              style: GoogleFonts.tajawal(color: const Color(0xFF00BFA5)),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF330000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'حسناً',
              style: GoogleFonts.tajawal(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  late AnimationController _bgController;
  late AnimationController _contentController;
  late AnimationController _chipsController;

  @override
  void initState() {
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _chipsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    super.initState();
    _startChipsAnimation();
    _loadBalance();
    _rewardService.cleanupExpiredTransactions(widget.userId);

    // احتساب مكافآت الدعوات اليومية تلقائياً عند فتح المحفظة
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final added = await _referralService.rewardInviterForActiveReferrals(
        widget.userId,
      );
      if (mounted && added > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إضافة $added ذهب من دعوات الأصدقاء النشطين اليوم',
            ),
          ),
        );
      }
    });
  }

  bool _isChipsLooping = false;
  void _startChipsAnimation() async {
    if (_isChipsLooping) return;
    _isChipsLooping = true;

    // Initial delay to let the UI settle
    await Future.delayed(const Duration(seconds: 2));

    while (mounted) {
      await _chipsController.forward(from: 0.0);
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _contentController.dispose();
    _chipsController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final coins = await _giftService.getUserCoins(widget.userId);
      final diamonds = await _giftService.getUserDiamonds(widget.userId);
      if (mounted) {
        setState(() {
          _userCoins = coins;
          _userDiamonds = diamonds;
        });
        _contentController.forward();
      }
    } catch (e) {
      // Error handled by stream
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F1D),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFF00BFA5),
            ),
            onPressed: () => _showTransactionHistory(),
          ),
          const SizedBox(width: 10),
        ],
        title: const Text(
          'محفظتي الذكية',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            fontFamily: 'Tajawal',
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .snapshots(),
            builder: (context, userSnap) {
              if (userSnap.hasData && userSnap.data!.exists) {
                final userData = userSnap.data!.data() as Map<String, dynamic>;
                final bool isAgent = userData['isAgent'] == true;
                _userDiamonds = userData['diamonds'] ?? 0;
                _userCoins = userData['coins'] ?? 0;
                final int userMetoChips = userData['meto_chips'] ?? 0;

                return _buildWalletBody(
                  isAgent: isAgent,
                  userMetoChips: userMetoChips,
                );
              }
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWalletBody({required bool isAgent, int userMetoChips = 0}) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                _fadeInUp(
                  delay: 100,
                  child: _buildMainWalletCard(
                    isAgent: isAgent,
                    userMetoChips: userMetoChips,
                  ),
                ),
                const SizedBox(height: 16),
                _fadeInUp(
                  delay: 300,
                  child: _buildExchangePriceSection(userMetoChips),
                ),
                _fadeInUp(
                  delay: 500,
                  child: _buildSectionHeader(
                    'سجل التحويلات',
                    Icons.swap_horiz_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTransferHistory(),
                const SizedBox(height: 24),
                _fadeInUp(
                  delay: 600,
                  child: _buildSectionHeader(
                    'سجل طلبات السحب',
                    Icons.history_edu_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                _buildWithdrawalHistory(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: DeepMeshPainter(animation: _bgController.value),
        );
      },
    );
  }

  Widget _fadeInUp({required int delay, required Widget child}) {
    final Animation<double> animation = CurvedAnimation(
      parent: _contentController,
      curve: Interval(
        (delay / 1200).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOutBack,
      ),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final val = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - val)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  String _formatNumber(num number) {
    if (number >= 1000000000000) {
      return '${(number / 1000000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}t';
    }
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}b';
    }
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}m';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k';
    }
    return number.toString();
  }

  Widget _buildMainWalletCard({required bool isAgent, int userMetoChips = 0}) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF141E30),
            Color(0xFF243B55),
          ], // Premium Dark Blue-Grey
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF243B55).withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative Background Shapes
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAgent ? 'رصيد المحفظة  ' : 'رصيد المحفظة',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    // Gold Section
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 35,
                            height: 35,
                            child: Lottie.asset(
                              'assets/lottie/Fake 3D vector coin.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            isAgent ? 'ذهب ' : 'الذهب',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatNumber(_userCoins),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildVerticalDivider(),
                    // Meto Chips Section (The Green one)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Image.asset(
                              'assets/images/coinsmeto.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'ميتو',
                            style: TextStyle(
                              color: Color(0xFF00BFA5),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatNumber(userMetoChips),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildVerticalDivider(),
                    // Diamonds Section
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 35,
                            height: 35,
                            child: Lottie.asset(
                              'assets/lottie/Diomand Loading.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'الألماس',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatNumber(_userDiamonds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.1),
      margin: const EdgeInsets.symmetric(horizontal: 5),
    );
  }

  Widget _buildExchangePriceSection(int userMetoChips) {
    double usdValue = userMetoChips / 6000.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${usdValue.toStringAsFixed(2)} \$',
                  style: const TextStyle(
                    color: Color(0xFF64FFDA),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: userMetoChips >= 60000
                    ? () => _handleWithdrawal(userMetoChips)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: userMetoChips >= 60000 ? 5 : 0,
                ),
                child: Text(
                  'سحب الأرباح',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: userMetoChips >= 60000
                        ? Colors.white
                        : Colors.white24,
                  ),
                ),
              ),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.userId)
                    .snapshots(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return const SizedBox.shrink();
                  }
                  final data = userSnap.data!.data() as Map<String, dynamic>?;
                  final bool isAgent = data?['isAgent'] == true;
                  final int userMetoChips = data?['meto_chips'] ?? 0;

                  if (!isAgent) return const SizedBox.shrink();

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton(
                          onPressed: () =>
                              _showTransferMetoChipsDialog(userMetoChips),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BFA5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'تحويل عملات MeTo',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00BFA5), size: 22),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _handleWithdrawal(int userMetoChips) {
    if (userMetoChips < 60000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً، الحد الأدنى للسحب هو 60,000 ميتو (10 دولار)'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _showWithdrawDialog(userMetoChips);
  }

  void _showTransferMetoChipsDialog(int userMetoChips) {
    showDialog(
      context: context,
      builder: (context) => _TransferMetoDialog(
        currentUserId: widget.userId,
        userMetoChips: userMetoChips,
        giftService: _giftService,
      ),
    );
  }

  void _showWithdrawDialog(int userMetoChips) {
    final TextEditingController amountController = TextEditingController(
      text: userMetoChips.toString(),
    );
    final TextEditingController detailsController = TextEditingController();
    final TextEditingController masterController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text(
          'طلب سحب أرباح',
          style: GoogleFonts.tajawal(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          textAlign: TextAlign.center,
        ),
        content: StatefulBuilder(
          builder: (context, setModalState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildWithdrawField(
                  controller: amountController,
                  label: 'عدد ميتو (مضاعفات 6000)',
                  hint: 'أقل كمية 60,000',
                  icon: Icons.monetization_on_rounded,
                  isNumber: true,
                  onChanged: (val) => setModalState(() {}),
                ),
                const SizedBox(height: 16),
                _buildWithdrawField(
                  controller: masterController,
                  label: 'رقم الماستر للتحويل',
                  hint: 'أدخل رقم الماستر بدقة',
                  icon: Icons.payment_rounded,
                ),
                const SizedBox(height: 16),
                _buildWithdrawField(
                  controller: detailsController,
                  label: 'تفاصيل إضافية (اختياري)',
                  hint: 'رقم المحفظة أو ملاحظات أخرى',
                  icon: Icons.info_outline_rounded,
                  maxLines: 2,
                ),
                const Divider(color: Colors.white12, height: 32),
                Row(
                  children: [
                    const Icon(Icons.money, color: Colors.amber, size: 15),
                    const SizedBox(width: 8),
                    Text(
                      'المبلغ: ${((int.tryParse(amountController.text) ?? 0) / 6000.0).toStringAsFixed(2)} دولار ',
                      style: GoogleFonts.tajawal(
                        color: Colors.amber,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          StatefulBuilder(
            builder: (context, setModalState) {
              // Persistent state for the builder should be handled carefully.
              // I will use his parent's state or a better local approach.
              // Actually, I'll use a local variable inside _showWithdrawDialog scope.
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isProcessingWithdraw
                        ? null
                        : () => Navigator.pop(context),
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.tajawal(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isProcessingWithdraw
                        ? null
                        : () async {
                            final amountStr = amountController.text.trim();
                            final details = detailsController.text.trim();
                            final master = masterController.text.trim();
                            final int? amountValue = int.tryParse(amountStr);

                            if (amountValue == null || amountValue < 60000) {
                              _showError('الحد الأدنى للسحب هو 60,000 ميتو');
                              return;
                            }
                            if (amountValue > userMetoChips) {
                              _showError('رصيدك الحالي غير كافٍ');
                              return;
                            }
                            if (master.isEmpty) {
                              _showError('يرجى إدخال رقم الماستر');
                              return;
                            }

                            setState(() => _isProcessingWithdraw = true);
                            setModalState(() {}); // update dialog UI

                            try {
                              await _giftService.requestWithdrawal(
                                uid: widget.userId,
                                metoChips: amountValue,
                                paymentDetails: details.isEmpty
                                    ? 'رقم الماستر: $master'
                                    : details,
                                masterNumber: master,
                                userName:
                                    'User_${widget.userId.substring(0, 5)}',
                              );
                              if (mounted) {
                                setState(() => _isProcessingWithdraw = false);
                                Navigator.pop(context); // Close dialog
                                _showSuccess('تم إرسال طلب السحب بنجاح');
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(() => _isProcessingWithdraw = false);
                                setModalState(() {}); // update dialog UI
                                _showError('فشل الطلب: $e');
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessingWithdraw
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'إرسال الآن',
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.tajawal(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF00BFA5), size: 20),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                color: Color(0xFF00BFA5),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ],
    );
  }

  void _showTransferDetailSheet(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'sent';
    final isSent = type == 'sent';
    final amount = data['amount'] ?? 0;

    // الاسم: نأخذ otherUserName أولاً، ثم receiverName/senderName كبديل
    final String otherName = () {
      final v = data['otherUserName'] as String? ?? '';
      if (v.isNotEmpty) return v;
      return isSent
          ? (data['receiverName'] as String? ?? '')
          : (data['senderName'] as String? ?? '');
    }();

    // الـ displayId: نأخذ otherUserDisplayId أولاً، ثم receiverDisplayId/senderDisplayId
    final String otherDisplayId = () {
      final v = data['otherUserDisplayId'] as String? ?? '';
      if (v.isNotEmpty) return v;
      return isSent
          ? (data['receiverDisplayId'] as String? ??
                data['receiverId'] as String? ??
                '')
          : (data['senderDisplayId'] as String? ??
                data['senderId'] as String? ??
                '');
    }();

    final createdAt = (data['timestamp'] as Timestamp?)?.toDate();

    final accentColor = isSent ? Colors.redAccent : const Color(0xFF00BFA5);
    final label = isSent ? 'تحويل صادر' : 'تحويل وارد';
    final icon = isSent
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF001F1D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),

            // Icon + label
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, color: accentColor, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 8),

            // Amount
            Text(
              '${isSent ? '-' : '+'} ${_formatNumber(amount)} عملة',
              style: TextStyle(
                color: isSent ? Colors.redAccent : Colors.greenAccent,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),

            // Details
            _transferDetailRow(
              icon: Icons.person_rounded,
              label: isSent ? 'المستلم' : 'المرسل',
              value: otherName.isNotEmpty ? otherName : '—',
            ),
            const SizedBox(height: 14),
            _transferDetailRow(
              icon: Icons.badge_rounded,
              label: isSent ? 'ID المستلم' : 'ID المرسل',
              value: otherDisplayId.isNotEmpty ? otherDisplayId : '—',
            ),
            const SizedBox(height: 14),
            _transferDetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'التاريخ',
              value: createdAt != null
                  ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}'
                  : '—',
            ),
            const SizedBox(height: 14),
            _transferDetailRow(
              icon: Icons.access_time_rounded,
              label: 'الوقت',
              value: createdAt != null
                  ? '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}:${createdAt.second.toString().padLeft(2, '0')}'
                  : '—',
            ),
            const SizedBox(height: 14),
            _transferDetailRow(
              icon: Icons.monetization_on_rounded,
              label: 'المبلغ الكامل',
              value: '$amount عملة',
              valueColor: isSent ? Colors.redAccent : Colors.greenAccent,
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.07),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'إغلاق',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transferDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF00BFA5), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransferHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('coin_transfers')
          .where('userId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'خطأ في التحميل: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
          );
        }

        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final ta =
              (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final tb =
              (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swap_horiz_rounded, color: Colors.white24, size: 48),
                SizedBox(height: 12),
                Text(
                  'لا توجد تحويلات سابقة',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final type = data['type'] as String? ?? 'sent';
            final isSent = type == 'sent';
            final amount = data['amount'] ?? 0;
            final otherName = data['otherUserName'] ?? '';
            final createdAt = (data['timestamp'] as Timestamp?)?.toDate();

            return GestureDetector(
              onTap: () => _showTransferDetailSheet(data),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSent
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : const Color(0xFF00BFA5).withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSent
                            ? Colors.redAccent.withValues(alpha: 0.1)
                            : const Color(0xFF00BFA5).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSent
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: isSent
                            ? Colors.redAccent
                            : const Color(0xFF00BFA5),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSent
                                ? 'تحويل إلى: $otherName'
                                : 'استلام من: $otherName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (createdAt != null)
                            Text(
                              '${createdAt.day}/${createdAt.month}/${createdAt.year}  ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${isSent ? '-' : '+'}${_formatNumber(amount)}',
                          style: TextStyle(
                            color: isSent
                                ? Colors.redAccent
                                : Colors.greenAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white24,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWithdrawalHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('withdrawal_requests')
          .where('userId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'خطأ في التحميل: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
          );
        }

        // Client-side sorting to avoid requiring a composite index
        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final ta =
              (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final tb =
              (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta); // Descending
        });

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, color: Colors.white24, size: 48),
                SizedBox(height: 12),
                Text(
                  'لا توجد طلبات سحب سابقة',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

            Color statusColor;
            String statusText;
            switch (status) {
              case 'pending':
                statusColor = Colors.orange;
                statusText = 'قيد الانتظار';
                break;
              case 'completed':
                statusColor = Colors.greenAccent;
                statusText = 'تم التحويل';
                break;
              case 'rejected':
                statusColor = Colors.redAccent;
                statusText = 'مرفوض';
                break;
              default:
                statusColor = Colors.grey;
                statusText = status;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status == 'completed'
                          ? Icons.check_circle_rounded
                          : status == 'rejected'
                          ? Icons.cancel_rounded
                          : Icons.pending_rounded,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سحب ${_formatNumber(data['metoChips'] ?? data['coins'] ?? 0)} ميتو',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          createdAt != null
                              ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
                              : '',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(data['amountUsd'] ?? 0).toStringAsFixed(2)} \$',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTransactionHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF002B28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'سجل العمليات',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('userId', isEqualTo: widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'خطأ في التحميل: ${snapshot.error}',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد عمليات مسجلة حالياً',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  );
                }

                // Client-side sorting
                final docs = snapshot.data!.docs.toList();
                docs.sort((a, b) {
                  final ta =
                      (a.data() as Map<String, dynamic>)['timestamp']
                          as Timestamp?;
                  final tb =
                      (b.data() as Map<String, dynamic>)['timestamp']
                          as Timestamp?;
                  if (ta == null) return 1;
                  if (tb == null) return -1;
                  return tb.compareTo(ta);
                });

                return ListView.builder(
                  itemCount: docs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final type = data['type'] ?? '';
                    final isCounter = type == 'counter_reward';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 5,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isCounter ? Colors.green : Colors.blueAccent)
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCounter ? Icons.timer_outlined : Icons.history,
                          color: isCounter
                              ? Colors.greenAccent
                              : Colors.blueAccent,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        data['title'] ?? 'شحن',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCounter
                                ? 'ستُحذف تلقائياً بعد 30 يوم'
                                : (data['usdPrice'] ?? data['type'] ?? ''),
                            style: TextStyle(
                              color: isCounter
                                  ? Colors.orangeAccent.withValues(alpha: 0.6)
                                  : Colors.cyanAccent.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: isCounter
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          if (data['timestamp'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${(data['timestamp'] as Timestamp).toDate().day}/${(data['timestamp'] as Timestamp).toDate().month}/${(data['timestamp'] as Timestamp).toDate().year} - ${(data['timestamp'] as Timestamp).toDate().hour}:${(data['timestamp'] as Timestamp).toDate().minute}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 9,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isCounter) ...[
                            if ((data['coinsAdded'] ?? 0) > 0)
                              Text(
                                '+${data['coinsAdded']} ذهب',
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            if ((data['metoChipsAdded'] ?? 0) > 0)
                              Text(
                                '+${data['metoChipsAdded']} ميتو',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                          ] else ...[
                            Text(
                              '${(data['amount'] ?? 0) >= 0 ? '+' : ''}${data['amount'] ?? 0}',
                              style: TextStyle(
                                color: (data['amount'] ?? 0) >= 0
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                          if (data['diamondsAdded'] != null &&
                              data['diamondsAdded'] > 0)
                            Text(
                              '+${data['diamondsAdded']} ماسة',
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DeepMeshPainter extends CustomPainter {
  final double animation;
  DeepMeshPainter({required this.animation});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    final x = size.width / 2;
    final y = size.height / 2;
    paint.color = const Color(0xFF00BFA5).withValues(alpha: 0.15);
    canvas.drawCircle(
      Offset(x + math.sin(animation * 2 * math.pi) * 50, y),
      200,
      paint,
    );
    paint.color = const Color(0xFF00796B).withValues(alpha: 0.1);
    canvas.drawCircle(
      Offset(x, y + math.cos(animation * 2 * math.pi) * 50),
      250,
      paint,
    );
  }

  @override
  bool shouldRepaint(DeepMeshPainter old) => old.animation != animation;
}

class _TransferMetoDialog extends StatefulWidget {
  final String currentUserId;
  final int userMetoChips;
  final GiftService giftService;

  const _TransferMetoDialog({
    required this.currentUserId,
    required this.userMetoChips,
    required this.giftService,
  });

  @override
  State<_TransferMetoDialog> createState() => _TransferMetoDialogState();
}

class _TransferMetoDialogState extends State<_TransferMetoDialog> {
  final TextEditingController _receiverIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  Map<String, dynamic>? _foundUser;
  bool _isLoadingSearch = false;
  String? _searchError;
  bool _isTransferring = false;

  Future<void> _searchUser() async {
    final String receiverAppId = _receiverIdController.text.trim();
    if (receiverAppId.isEmpty) return;

    setState(() {
      _isLoadingSearch = true;
      _foundUser = null;
      _searchError = null;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('displayId', isEqualTo: receiverAppId)
          .limit(1)
          .get();

      final DocumentSnapshot receiverSnapshot;
      if (query.docs.isNotEmpty) {
        receiverSnapshot = query.docs.first;
      } else {
        receiverSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(receiverAppId)
            .get();
      }

      if (receiverSnapshot.exists) {
        if (receiverSnapshot.id == widget.currentUserId) {
          throw 'لا يمكنك التحويل لحسابك الشخصي';
        }
        setState(() {
          _foundUser = receiverSnapshot.data() as Map<String, dynamic>?;
        });
      } else {
        throw 'المستخدم غير موجود';
      }
    } catch (e) {
      setState(() {
        _searchError = e.toString();
      });
    } finally {
      setState(() {
        _isLoadingSearch = false;
      });
    }
  }

  Future<void> _processTransfer() async {
    final String amountStr = _amountController.text.trim();
    final int? amount = int.tryParse(amountStr);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('مبلغ التحويل غير صحيح')));
      return;
    }
    if (amount > widget.userMetoChips) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رصيد ميتو غير كافٍ للتحويل')),
      );
      return;
    }

    setState(() {
      _isTransferring = true;
    });

    try {
      await widget.giftService.transferMetoChips(
        senderId: widget.currentUserId,
        receiverAppId: _receiverIdController.text.trim(),
        amount: amount,
      );

      if (mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحويل ميتو بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحويل ميتو: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF001F1D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'تحويل عملات ميتو',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _receiverIdController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'رقم ID المستلم',
                labelStyle: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
                hintText: 'أدخل رقم ID المستلم بدقة',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                prefixIcon: const Icon(
                  Icons.person_search_rounded,
                  color: Color(0xFF00BFA5),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFF00BFA5)),
                  onPressed: _searchUser,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.transparent),
                  borderRadius: BorderRadius.circular(16),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: Color(0xFF00BFA5),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onSubmitted: (_) => _searchUser(),
            ),
            if (_isLoadingSearch)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
                ),
              ),
            if (_searchError != null && !_isLoadingSearch)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  _searchError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_foundUser != null && !_isLoadingSearch) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: _foundUser!['profileImage'] != null
                          ? (_foundUser!['profileImage'].toString().startsWith(
                                      'assets/',
                                    )
                                    ? AssetImage(_foundUser!['profileImage'])
                                    : NetworkImage(_foundUser!['profileImage']))
                                as ImageProvider
                          : null,
                      child: _foundUser!['profileImage'] == null
                          ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 25,
                            )
                          : null,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _foundUser!['name'] ??
                                _foundUser!['username'] ??
                                'مستخدم',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${_foundUser!['displayId'] ?? ''}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.greenAccent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Color(0xFF00BFA5),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'كمية ميتو',
                  labelStyle: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                  hintText: 'مثال: 5000',
                  hintStyle: const TextStyle(
                    color: Colors.white24,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  prefixIcon: const Icon(
                    Icons.toll_rounded,
                    color: Color(0xFF00BFA5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.transparent),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Color(0xFF00BFA5),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'سيتم خصم ميتو من رصيدك وتحويله فوراً للمستلم.',
                style: TextStyle(color: Color(0xFF00BFA5), fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
        ),
        if (_foundUser != null)
          ElevatedButton(
            onPressed: _isTransferring ? null : _processTransfer,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isTransferring
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'تأكيد التحويل',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
      ],
    );
  }
}
