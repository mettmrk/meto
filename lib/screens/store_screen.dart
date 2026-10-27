import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import '../services/index.dart';

class StoreScreen extends StatefulWidget {
  final String userId;
  final int initialTab; // 0: Counter, 1: Diamonds, 2: Coins
  const StoreScreen({super.key, required this.userId, this.initialTab = 0});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with TickerProviderStateMixin {
  final IAPService _iapService = IAPService();
  int _selectedTab = 0;
  bool _isProcessingStore = false;

  late AnimationController _contentController;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _iapService.initialize();
    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _iapService.dispose();
    super.dispose();
  }

  Widget _fadeInUp({required Widget child, required int delay}) {
    return AnimatedBuilder(
      animation: _contentController,
      builder: (context, anim) {
        final double opacity = math.min(
          1.0,
          math.max(0.0, (_contentController.value * 2) - (delay / 1000)),
        );
        final double slide = 20 * (1.0 - opacity);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(offset: Offset(0, slide), child: child),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F1D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'متجر ميتو الذكي',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: const [],
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
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
            );
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final int userChips = userData['meto_chips'] ?? 0;

          return Column(
            children: [
              const SizedBox(height: 10),
              _buildTabs(),
              _buildBalanceHeader(userChips),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildGrid(userData),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalanceHeader(int chips) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF004D40).withValues(alpha: 0.9),
            const Color(0xFF001F1D).withValues(alpha: 0.7),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00BFA5).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA5).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wallet_rounded,
                    color: Color(0xFF00BFA5),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'رصيد عملة ميتو',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Transform.translate(
                      offset: const Offset(0, -3.5),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: Image.asset(
                          'assets/images/coinsmeto.png',
                          width: 18,
                          height: 18,
                        ),
                      ),
                    ),
                  ),
                  TextSpan(
                    text: _formatNumber(chips),
                    style: const TextStyle(
                      color: Color(0xFF00BFA5),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _tabItem(0, 'باقات العداد', Icons.av_timer_rounded),
          _tabItem(1, 'الألماس', Icons.diamond_rounded),
          _tabItem(2, 'الذهب', Icons.monetization_on_rounded),
        ],
      ),
    );
  }

  Widget _tabItem(int index, String label, IconData icon) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00BFA5) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white38,
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(Map<String, dynamic> userData) {
    if (_selectedTab == 0) return _buildCounterGrid(userData);
    if (_selectedTab == 1) return _buildDiamondGrid();
    return _buildGoldGrid();
  }

  Widget _buildCounterGrid(Map<String, dynamic> userData) {
    final List<Map<String, dynamic>> items = [
      {
        'id': 'starter_pack',
        'name': 'باقة المبتدئين',
        'benefit': '77',
        'costParams': 6000,
        'costLabel': '6,000',
        'points': 77,
        'color': Colors.amber,
      },
      {
        'id': 'pro_pack',
        'name': 'باقة المحترفين',
        'benefit': '333',
        'costParams': 20000,
        'costLabel': '20,000',
        'points': 333,
        'color': Colors.orange,
      },
      {
        'id': 'elite_pack',
        'name': 'باقة النخبة',
        'benefit': '866',
        'costParams': 52000,
        'costLabel': '52,000',
        'points': 866,
        'color': Colors.pinkAccent,
      },
      {
        'id': 'gold_pack',
        'name': 'باقة الذهب',
        'benefit': '3,300',
        'costParams': 200000,
        'costLabel': '200,000',
        'points': 3300,
        'color': Colors.amberAccent,
      },
      {
        'id': 'platinum_pack',
        'name': 'باقة البلاتين',
        'benefit': '6,600',
        'costParams': 400000,
        'costLabel': '400,000',
        'points': 6600,
        'color': Colors.blueGrey,
      },
      {
        'id': 'diamond_plus_pack',
        'name': 'باقة الماس بلس',
        'benefit': '10,000',
        'costParams': 800000,
        'costLabel': '800,000',
        'points': 10000,
        'color': Colors.lightBlue,
      },
    ];

    final Map<String, dynamic> packageHistory =
        userData['packageHistory'] as Map<String, dynamic>? ?? {};

    return _gridBuilder(
      items,
      (item) => _buildModernCard(
        item,
        isCounter: true,
        packageHistory: packageHistory,
      ),
    );
  }

  Widget _buildDiamondGrid() {
    final List<Map<String, dynamic>> pkgs = [
      {
        'id': 'diamonds_pack_500',
        'name': 'باقة 500 ماسة',
        'val': '500',
        'amount': 500,
        'meto': 6000,
        'price': '6,000',
        'color': Colors.cyanAccent,
      },
      {
        'id': 'diamonds_pack_1900',
        'name': 'باقة 1900 ماسة',
        'val': '1,900',
        'amount': 1900,
        'meto': 24000,
        'price': '24,000',
        'color': Colors.blue,
      },
      {
        'id': 'diamonds_pack_5100',
        'name': 'باقة 5100 ماسة',
        'val': '5,100',
        'amount': 5100,
        'meto': 60000,
        'price': '60,000',
        'color': Colors.indigoAccent,
      },
      {
        'id': 'diamonds_pack_16100',
        'name': 'باقة 16100 ماسة',
        'val': '16,100',
        'amount': 16100,
        'meto': 180000,
        'price': '180,000',
        'color': Colors.pink,
      },
      {
        'id': 'diamonds_pack_53800',
        'name': 'باقة 53800 ماسة',
        'val': '53,800',
        'amount': 53800,
        'meto': 600000,
        'price': '600,000',
        'color': Colors.tealAccent,
      },
      {
        'id': 'diamonds_pack_161700',
        'name': 'باقة 161700 ماسة',
        'val': '161,700',
        'amount': 161700,
        'meto': 1800000,
        'price': '1,800,000',
        'color': Colors.purple,
      },
    ];
    return _gridBuilder(pkgs, (pkg) => _buildDiamondCard(pkg));
  }

  Widget _buildGoldGrid() {
    final List<Map<String, dynamic>> pkgs = [
      {
        'id': 'gold_33000',
        'name': 'باقة 33000 ذهب',
        'val': '33,000',
        'amount': 33000,
        'meto': 6000,
        'price': '6,000',
        'color': Colors.amber,
      },
      {
        'id': 'gold_130000',
        'name': 'باقة 130000 ذهب',
        'val': '130,000',
        'amount': 130000,
        'meto': 18000,
        'price': '18,000',
        'color': Colors.amber,
      },
      {
        'id': 'gold_670000',
        'name': 'باقة 670000 ذهب',
        'val': '670,000',
        'amount': 670000,
        'meto': 54000,
        'price': '54,000',
        'color': Colors.deepOrange,
      },
      {
        'id': 'gold_2700000',
        'name': 'باقة 2.7 مليون ذهب',
        'val': '2,700,000',
        'amount': 2700000,
        'meto': 108000,
        'price': '108,000',
        'color': Colors.redAccent,
      },
      {
        'id': 'gold_7700000',
        'name': 'باقة 7.7 مليون ذهب',
        'val': '7,700,000',
        'amount': 7700000,
        'meto': 240000,
        'price': '240,000',
        'color': Colors.purpleAccent,
      },
      {
        'id': 'gold_17000000',
        'name': 'باقة 17 مليون ذهب',
        'val': '17,000,000',
        'amount': 17000000,
        'meto': 420000,
        'price': '420,000',
        'color': Colors.blueAccent,
      },
    ];
    return _gridBuilder(pkgs, (pkg) => _buildGoldCard(pkg));
  }

  Widget _gridBuilder(List items, Widget Function(dynamic) cardBuilder) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _fadeInUp(delay: index * 100, child: cardBuilder(items[index])),
    );
  }

  Widget _buildModernCard(
    Map<String, dynamic> item, {
    bool isCounter = false,
    Map<String, dynamic>? packageHistory,
  }) {
    bool isDisabled = false;
    String statusLabel = item['costLabel'] ?? item['cost'];

    if (isCounter && packageHistory != null) {
      final String packageId = item['id'];
      List<dynamic> rawHistory = [];
      if (packageHistory.containsKey(packageId)) {
        var hist = packageHistory[packageId];
        if (hist is List) {
          rawHistory = List.from(hist);
        } else if (hist is Timestamp) {
          rawHistory = [hist];
        }
      }

      final now = DateTime.now();
      List<Timestamp> validHistory = rawHistory
          .whereType<Timestamp>()
          .where((ts) => now.difference(ts.toDate()).inDays < 180)
          .toList();

      int maxPurchases = (packageId == 'starter_pack') ? 2 : 1;

      if (validHistory.length >= maxPurchases) {
        isDisabled = true;
        final oldestValid = validHistory.reduce(
          (a, b) => a.compareTo(b) < 0 ? a : b,
        );
        final remainingDays = 180 - now.difference(oldestValid.toDate()).inDays;
        statusLabel = 'تم الاشتراك - باقي $remainingDays يوم';
      }
    }

    return GestureDetector(
      onTap: isDisabled ? null : () => _handlePurchase(item),
      child: Container(
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.withValues(alpha: 0.1)
              : item['color'].withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.withValues(alpha: 0.2)
                : item['color'].withValues(alpha: 0.3),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              item['name'],
              style: TextStyle(
                color: isDisabled ? Colors.white38 : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            SizedBox(
              width: 50,
              height: 50,
              child: isDisabled
                  ? const Opacity(
                      opacity: 0.4,
                      child: Icon(
                        Icons.lock_clock_rounded,
                        color: Colors.grey,
                        size: 40,
                      ),
                    )
                  : Image.asset('assets/images/adad.png', fit: BoxFit.contain),
            ),
            const Spacer(),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: item['benefit'],
                    style: TextStyle(
                      color: isDisabled ? Colors.grey : item['color'],
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      shadows: isDisabled
                          ? null
                          : [
                              Shadow(
                                color: item['color'].withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ],
                    ),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Transform.translate(
                      offset: const Offset(
                        0,
                        -2,
                      ), // Nudge the image UP to match the high text
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: Image.asset(
                          'assets/images/coinsmeto.png',
                          width:
                              15, // Slightly reduced to better match font level
                          height: 15,
                          color: isDisabled ? Colors.grey : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDisabled ? Colors.black45 : Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: statusLabel,
                        style: TextStyle(
                          color: isDisabled ? Colors.grey : Colors.white,
                          fontSize: isDisabled ? 10 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!statusLabel.contains('يوم'))
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Transform.translate(
                            offset: const Offset(0, -1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: Image.asset(
                                'assets/images/coinsmeto.png',
                                width: 11,
                                height: 11,
                                color: isDisabled ? Colors.grey : null,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiamondCard(Map<String, dynamic> pkg) {
    return GestureDetector(
      onTap: () => _handlePurchase(pkg, type: 'diamond'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(pkg['color'], BlendMode.modulate),
                child: Lottie.asset(
                  'assets/lottie/dimond.json',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${pkg['val']} ماسة',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: pkg['price'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Transform.translate(
                        offset: const Offset(0, -1),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Image.asset(
                            'assets/images/coinsmeto.png',
                            width: 11,
                            height: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldCard(Map<String, dynamic> pkg) {
    return GestureDetector(
      onTap: () => _handlePurchase(pkg, type: 'gold'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: Lottie.asset('assets/bag.json', fit: BoxFit.contain),
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: pkg['val'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Transform.translate(
                      offset: const Offset(0, -1.5),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: Image.asset(
                          'assets/images/drhim.png',
                          width: 14,
                          height: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: pkg['price'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Transform.translate(
                        offset: const Offset(0, -1),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Image.asset(
                            'assets/images/coinsmeto.png',
                            width: 11,
                            height: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePurchase(
    Map<String, dynamic> item, {
    String type = 'counter',
  }) async {
    if (_isProcessingStore) return;
    _showPurchaseConfirmation(item, type);
  }

  void _showPurchaseConfirmation(Map<String, dynamic> item, String type) {
    String itemName = '';
    String itemValue = '';
    Color themeColor = const Color(0xFF00BFA5);
    Widget previewIcon;

    if (type == 'diamond') {
      itemName = 'ألماس';
      itemValue = '${item['val']}';
      themeColor = item['color'];
      previewIcon = SizedBox(
        width: 100,
        height: 100,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(themeColor, BlendMode.modulate),
          child: Lottie.asset('assets/lottie/dimond.json', fit: BoxFit.contain),
        ),
      );
    } else if (type == 'gold') {
      itemName = 'ذهب';
      itemValue = item['val'];
      themeColor = Colors.amber;
      previewIcon = SizedBox(
        width: 100,
        height: 100,
        child: Lottie.asset('assets/bag.json', fit: BoxFit.contain),
      );
    } else {
      itemName = item['name'];
      itemValue = item['benefit'];
      previewIcon = Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.timer_rounded, color: Colors.amber, size: 60),
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F1D),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: themeColor.withValues(alpha: 0.2)),
        ),
        title: Column(
          children: [
            previewIcon,
            const SizedBox(height: 15),
            const Text(
              'تأكيد العملية',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'هل أنت متأكد من شراء $itemValue $itemName مقابل ${item['price']} من عملة ميتو؟',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontFamily: 'Tajawal',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (type == 'counter') {
                        _purchaseWithMeto(item, isCounter: true);
                      } else {
                        _purchaseWithMeto(item, isCounter: false, type: type);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'تأكيد الشراء',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchaseWithMeto(
    Map<String, dynamic> item, {
    bool isCounter = true,
    String type = 'counter',
  }) async {
    _isProcessingStore = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
      ),
    );
    try {
      if (isCounter) {
        final rewardService = RewardService();
        await rewardService.purchaseCounterWithMeto(
          widget.userId,
          packageId: item['id'],
          packageName: item['name'],
          points: item['points'],
          costInMeto: item['costParams'],
        );
      } else if (type == 'diamond') {
        final rewardService = RewardService();
        await rewardService.purchaseDiamondsWithMeto(
          widget.userId,
          packageId: item['id'],
          packageName: item['name'],
          amount: item['amount'],
          costInMeto: item['meto'],
        );
      } else if (type == 'gold') {
        final rewardService = RewardService();
        await rewardService.purchaseGoldWithMeto(
          widget.userId,
          packageId: item['id'],
          packageName: item['name'],
          amount: item['amount'],
          costInMeto: item['meto'],
        );
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم شراء ${item['name']} بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _isProcessingStore = false;
    }
  }

  String _formatNumber(num number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }
}

class math {
  static double min(double a, double b) => a < b ? a : b;
  static double max(double a, double b) => a > b ? a : b;
}
