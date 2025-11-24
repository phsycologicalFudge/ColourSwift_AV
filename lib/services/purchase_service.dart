import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static const String _proId = 'cs_security_pro';
  static bool _available = false;
  static bool _isPro = false;

  static Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) return;

    _iap.purchaseStream.listen(_handlePurchaseUpdates, onError: (_) {});
    await restore();
  }

  static Future<bool> hasPro() async => _isPro;

  static Future<void> buyPro() async {
    if (!_available) throw 'Play Billing unavailable';
    final details = await _iap.queryProductDetails({_proId});
    if (details.notFoundIDs.isNotEmpty) throw 'Product not found on Play Console';
    final product = details.productDetails.first;
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  static Future<bool> restore() async {
    if (!_available) return false;

    // Ask Play to resend past purchases through the stream.
    await _iap.restorePurchases();

    // Extra step: re-check for ownership by querying product details
    // (some Play versions require this to confirm entitlement)
    final response = await _iap.queryProductDetails({_proId});
    if (response.productDetails.isNotEmpty) {
      for (final d in response.productDetails) {
        if (d.id == _proId) {
          // this doesn’t prove purchase, but ensures product exists
        }
      }
    }

    // Wait briefly to allow the stream to deliver any restored purchases
    await Future.delayed(const Duration(seconds: 3));
    return _isPro;
  }

  static void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.productID == _proId &&
          (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) &&
          p.verificationData.serverVerificationData.isNotEmpty) {
        _isPro = true;
      }
      if (p.pendingCompletePurchase) {
        _iap.completePurchase(p);
      }
    }
  }
}
