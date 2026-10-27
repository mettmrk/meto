import 'package:flutter/material.dart';
import '../services/index.dart';

class WithdrawalRequestBottomSheet extends StatefulWidget {
  final String userId;
  final String userName;
  final int maxCoins;
  const WithdrawalRequestBottomSheet({
    super.key,
    required this.userId,
    required this.userName,
    required this.maxCoins,
  });

  @override
  State<WithdrawalRequestBottomSheet> createState() =>
      _WithdrawalRequestBottomSheetState();
}

class _WithdrawalRequestBottomSheetState
    extends State<WithdrawalRequestBottomSheet> {
  final GiftService _giftService = GiftService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _detailsController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final amount = int.parse(_amountController.text);
      await _giftService.requestWithdrawal(
        uid: widget.userId,
        metoChips: amount,
        paymentDetails: _detailsController.text,
        userName: widget.userName,
      );

      if (mounted) {
        Navigator.pop(context, true); // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تقديم طلب السحب بنجاح! سيتم المراجعة قريباً.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'طلب سحب عملة ميتو',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'رصيدك المتاح للسحب: ${widget.maxCoins} ميتو',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'عدد ميتو المراد سحبه',
                hintText: 'الحد الأدنى 60,000 ميتو',
                prefixIcon: const Icon(
                  Icons.monetization_on_rounded,
                  color: Color(0xFF00BFA5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'يرجى إدخال الكمية';
                final val = int.tryParse(value);
                if (val == null) return 'يرجى إدخال رقم صحيح';
                if (val < 60000) return 'الحد الأدنى للسحب هو 60,000 ميتو';
                if (val > widget.maxCoins) return 'الكمية تتجاوز رصيدك الحالي';
                return null;
              },
              onChanged: (value) => setState(() {}),
            ),
            if (_amountController.text.isNotEmpty &&
                int.tryParse(_amountController.text) != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 12),
                child: Text(
                  'ستحصل على: ${(int.parse(_amountController.text) / 6000.0).toStringAsFixed(2)} \$',
                  style: const TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _detailsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'تفاصيل البطاقة أو وسيلة الدفع',
                hintText: 'يرجى إدخال رقم البطاقة، الاسم، أو أي تفاصيل أخرى...',
                prefixIcon: const Icon(
                  Icons.payment_rounded,
                  color: Colors.teal,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال تفاصيل الدفع';
                }
                if (value.length < 10) return 'التفاصيل قصيرة جداً';
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'إرسال الطلب الآن',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
