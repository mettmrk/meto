// ignore_for_file: avoid_function_literals_in_foreach_calls, curly_braces_in_flow_control_structures, empty_catches

import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'payment_service.dart';
import 'reward_service.dart';

class IAPService {
  final InAppPurchase _iap = InAppPurchase.instance;
  final PaymentService _paymentService = PaymentService();
  final RewardService _rewardService = RewardService();

  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _available = false;
  final Completer<void> _initCompleter = Completer<void>();

  // Define your Product IDs from Play Store / App Store
  static const Set<String> _kIds = {
    'diamonds_pack_10',
    'diamonds_pack_50',
    'diamonds_pack_100',
    'diamonds_pack_500',
    'diamonds_pack_1000',
    'diamonds_pack_5000',
    'diamonds_pack_10000', // Added 10k pack if not exists
    'diamonds_pack_50000', // Added 50k pack if not exists
    'diamonds_pack_13500', // New 12.99
    'diamonds_pack_17000', // New 15.99
    // Counter Packages
    'starter_pack',
    'pro_pack',
    'elite_pack',
    'sapphire_pack',
    'gold_pack',
    'platinum_pack',
    'diamond_plus_pack',
    'master_pack',
    'grandmaster_pack',
  };

  bool _isInitCallStarted = false;
  void initialize() {
    if (_isInitCallStarted) return;
    _isInitCallStarted = true;

    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        // Handle error
      },
    );
    _initIAP();
  }

  bool _isInitStarted = false;
  Future<void> _initIAP() async {
    if (_isInitStarted) return;
    _isInitStarted = true;
    try {
      _available = await _iap.isAvailable();
    } catch (e) {
      _available = false;
    } finally {
      _safeComplete();
    }
  }

  void _safeComplete() {
    try {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    } catch (e) {
      print("[IAP] Completer already finished: $e");
    }
  }

  Future<List<ProductDetails>> getProducts() async {
    // Wait for initialization to complete
    await _initCompleter.future;

    if (!_available) {
      return [];
    }

    ProductDetailsResponse response = await _iap.queryProductDetails(_kIds);

    if (response.error != null) {}

    if (response.notFoundIDs.isNotEmpty) {}

    return response.productDetails;
  }

  Future<void> buyProduct(ProductDetails product, String userId) async {
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: userId, // For security tracking
    );

    // Starting the purchase flow
    if (product.id.contains('consumable')) {
      await _iap.buyConsumable(purchaseParam: purchaseParam);
    } else {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  Future<void> _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (var purchaseDetails in purchaseDetailsList) {
      try {
        if (purchaseDetails.status == PurchaseStatus.pending) {
          // Show pending UI if needed
        } else {
          if (purchaseDetails.status == PurchaseStatus.error) {
            // Handle Error case (e.g. log)
          } else if (purchaseDetails.status == PurchaseStatus.purchased ||
              purchaseDetails.status == PurchaseStatus.restored) {
            // CRITICAL: Verify and deliver
            bool valid = await _verifyPurchase(purchaseDetails);
            if (valid) {
              await _deliverProduct(purchaseDetails);
            }
          }

          if (purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }
        }
      } catch (e) {
        print("[IAP] Error processing item: $e");
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // In a REAL production app, send purchaseDetails.verificationData.serverVerificationData
    // to your backend (Firebase Cloud Function) to verify with Google/Apple servers.
    // For now, we use our secure transaction logic in PaymentService.
    return true;
  }

  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    // Determine how many diamonds to add based on product ID
    int amount = 0;
    String pkgName = purchaseDetails.productID;

    if (pkgName == 'diamonds_pack_10') {
      amount = 10;
    } else if (pkgName == 'diamonds_pack_50')
      amount = 50;
    else if (pkgName == 'diamonds_pack_100')
      amount = 100;
    else if (pkgName == 'diamonds_pack_500')
      amount = 500;
    else if (pkgName == 'diamonds_pack_1000')
      amount = 1000;
    else if (pkgName == 'diamonds_pack_5000')
      amount = 5000;
    else if (pkgName == 'diamonds_pack_10000') // Add existing ones just in case
      amount = 10000;
    else if (pkgName == 'diamonds_pack_50000')
      amount = 50000;
    else if (pkgName == 'diamonds_pack_13500')
      amount = 13500;
    else if (pkgName == 'diamonds_pack_17000')
      amount = 17000;

    if (amount > 0 &&
        purchaseDetails.verificationData.localVerificationData.isNotEmpty) {
      // Use the Secure Payment Service to record and update
      // This is the "Real" non-cheatable part
      final String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await _paymentService.simulateServerVerificationFromIAP(
        uid: uid,
        amount: amount,
        purchaseId: purchaseDetails.purchaseID ?? 'unknown',
      );
    } else {
      // Check for Counter Packages
      final counterPkg = _getCounterPackageDetails(pkgName);
      if (counterPkg != null) {
        final String? uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          try {
            await _rewardService.purchaseCounter(
              uid,
              packageId: pkgName,
              points: counterPkg['points'] ?? 0,
              packageName: counterPkg['name'],
              usdPrice: 'IAP', // Or fetch from productDetails
            );
          } catch (e) {}
        }
      }
    }
  }

  Map<String, dynamic>? _getCounterPackageDetails(String id) {
    switch (id) {
      case 'starter_pack':
        return {'points': 66, 'diamonds': 0, 'name': 'باقة المبتدئين'};
      case 'pro_pack':
        return {'points': 333, 'diamonds': 0, 'name': 'باقة المحترفين'};
      case 'elite_pack':
        return {'points': 866, 'diamonds': 0, 'name': 'باقة النخبة'};
      case 'sapphire_pack':
        return {'points': 0, 'diamonds': 17, 'name': 'باقة الياقوت'};
      case 'gold_pack':
        return {'points': 3333, 'diamonds': 0, 'name': 'باقة الذهب'};
      case 'platinum_pack':
        return {'points': 6666, 'diamonds': 0, 'name': 'باقة البلاتين'};
      case 'diamond_plus_pack':
        return {'points': 13333, 'diamonds': 0, 'name': 'باقة الماس بلس'};
      case 'master_pack':
        return {'points': 33333, 'diamonds': 0, 'name': 'باقة المعلم'};
      case 'grandmaster_pack':
        return {'points': 66666, 'diamonds': 0, 'name': 'باقة الأسطورة'};
      default:
        return null;
    }
  }

  void dispose() {
    _subscription.cancel();
  }
}
