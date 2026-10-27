import 'dart:async';
import 'package:flutter/material.dart';

class DailyEarningCounter extends StatefulWidget {
  final int dailyAmount;
  final DateTime startTime;
  final bool isDiamonds;
  final bool isMeto;
  final bool isGold;

  const DailyEarningCounter({
    super.key,
    required this.dailyAmount,
    required this.startTime,
    this.isDiamonds = false,
    this.isMeto = false,
    this.isGold = true,
  });

  @override
  State<DailyEarningCounter> createState() => _DailyEarningCounterState();
}

class _DailyEarningCounterState extends State<DailyEarningCounter> {
  Timer? _timer;
  double _currentEarnings = 0.0;

  @override
  void initState() {
    super.initState();
    _updateEarnings();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateEarnings();
    });
  }

  void _updateEarnings() {
    final now = DateTime.now().toUtc();
    final start = widget.startTime.isUtc
        ? widget.startTime
        : widget.startTime.toUtc();

    // Calculate elapsed seconds
    final elapsed = now.difference(start);

    if (elapsed.isNegative) {
      if (mounted) {
        setState(() {
          _currentEarnings = 0.0;
        });
      }
      return;
    }

    // Daily amount / 24 hours / 60 minutes / 60 seconds = 86400 seconds
    final double perSecond = widget.dailyAmount / 86400.0;
    double calculated = perSecond * elapsed.inSeconds;

    // Cap at daily amount
    if (calculated > widget.dailyAmount) {
      calculated = widget.dailyAmount.toDouble();
    }

    if (mounted) {
      setState(() {
        _currentEarnings = calculated;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDiamonds
              ? Colors.lightBlueAccent
              : widget.isMeto
                  ? const Color(0xFF00BFA5)
                  : Colors.amber,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (widget.isDiamonds
                    ? Colors.blue
                    : widget.isMeto
                        ? const Color(0xFF00BFA5)
                        : Colors.amber)
                .withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.isDiamonds
                ? 'أرباح الماس الحالية'
                : widget.isMeto
                    ? 'أرباح ميتو الحالية'
                    : 'أرباح الذهب الحالية',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isDiamonds
                    ? Icons.diamond_outlined
                    : widget.isMeto
                        ? Icons.toll_rounded
                        : Icons.monetization_on_outlined,
                color: widget.isDiamonds
                    ? Colors.lightBlueAccent
                    : widget.isMeto
                        ? const Color(0xFF00BFA5)
                        : Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              // Show with 5 decimal places to suggest precision and activity
              Text(
                _currentEarnings.toStringAsFixed(5),
                style: TextStyle(
                  color: widget.isDiamonds
                      ? Colors.lightBlueAccent
                      : widget.isMeto
                          ? const Color(0xFF00BFA5)
                          : Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
