import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NewsTicker extends StatefulWidget {
  final double speed;
  final double height;
  final Color backgroundColor;
  final Color textColor;

  const NewsTicker({
    super.key,
    this.speed = 100.0,
    this.height = 36.0,
    this.backgroundColor = Colors.transparent,
    this.textColor = Colors.black,
  });

  @override
  State<NewsTicker> createState() => _NewsTickerState();
}

class _NewsTickerState extends State<NewsTicker>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(initialScrollOffset: 10000);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.repeat();
    });
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final currentOffset = _scrollController.offset;
      final double nextOffset = currentOffset + (widget.speed / 60);
      _scrollController.jumpTo(nextOffset);
      if (nextOffset > 20000) {
        _scrollController.jumpTo(10000);
      }
    }
  }

  @override
  void dispose() {
    _animationController.removeListener(_scrollListener);
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ticker_news').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildTicker(['Meto - خطأ في الاتصال بقاعدة البيانات']);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildTicker(['أهلاً بكم في ميتو - وجهتكم للتواصل الفعال']);
        }

        // Filter and sort locally
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['active'] == true;
        }).toList();

        if (docs.isEmpty) {
          return _buildTicker(['ميتو ميديا - استمتع بأحدث الغرف الصوتية']);
        }

        docs.sort((a, b) {
          final t1 =
              (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final t2 =
              (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (t1 == null) return 1;
          if (t2 == null) return -1;
          return t2.compareTo(t1);
        });

        final items = docs
            .map(
              (doc) =>
                  (doc.data() as Map<String, dynamic>)['content']?.toString() ??
                  '',
            )
            .where((s) => s.isNotEmpty)
            .toList();

        if (items.isEmpty) {
          return _buildTicker(['مرحباً بك في ميتو']);
        }

        return _buildTicker(items);
      },
    );
  }

  Widget _buildTicker(List<String> items) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        border: Border.symmetric(
          horizontal: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final itemIndex = index % items.length;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  items[itemIndex],
                  style: const TextStyle(
                    color: Colors.black, // Changed to black as requested
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
              _buildSeparator(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSeparator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Colors.purple,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'MeTo',
            style: TextStyle(
              color: Colors.purple,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Colors.purple,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
