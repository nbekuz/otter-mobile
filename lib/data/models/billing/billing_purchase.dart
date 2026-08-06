/// Local mirror of a RuStore purchase used for backend verification.
class BillingPurchase {
  const BillingPurchase({
    this.purchaseId,
    this.productId,
    this.productType,
    this.purchaseTime,
    this.orderId,
    this.purchaseState,
    this.developerPayload,
    this.subscriptionToken,
    this.invoiceId,
  });

  final String? purchaseId;
  final String? productId;
  final String? productType;
  final String? purchaseTime;
  final String? orderId;
  final String? purchaseState;
  final String? developerPayload;
  final String? subscriptionToken;
  final String? invoiceId;

  bool get isActive {
    final state = (purchaseState ?? '').toUpperCase();
    return state == 'PAID' ||
        state == 'CONFIRMED' ||
        state == 'ACTIVE' ||
        state == 'CONSUMED';
  }

  bool get isSubscription {
    final type = (productType ?? '').toUpperCase();
    return type.contains('SUBSCRIPTION') ||
        productId == 'otter_month' ||
        productId == 'otter_year';
  }

  bool get isExpired {
    final state = (purchaseState ?? '').toUpperCase();
    return state == 'CLOSED' || state == 'CANCELLED' || state == 'CANCELED';
  }
}

enum PurchaseResultStatus { success, cancelled, failed }

class PurchaseResult {
  const PurchaseResult({
    required this.status,
    this.purchase,
    this.message,
    this.productId,
    this.purchaseId,
    this.orderId,
    this.subscriptionToken,
  });

  final PurchaseResultStatus status;
  final BillingPurchase? purchase;
  final String? message;
  final String? productId;
  final String? purchaseId;
  final String? orderId;
  final String? subscriptionToken;

  bool get isSuccess => status == PurchaseResultStatus.success;
  bool get isCancelled => status == PurchaseResultStatus.cancelled;

  factory PurchaseResult.success({
    required String productId,
    required String purchaseId,
    String? orderId,
    String? subscriptionToken,
    BillingPurchase? purchase,
  }) =>
      PurchaseResult(
        status: PurchaseResultStatus.success,
        productId: productId,
        purchaseId: purchaseId,
        orderId: orderId,
        subscriptionToken: subscriptionToken,
        purchase: purchase,
      );

  factory PurchaseResult.cancelled([String? message]) => PurchaseResult(
        status: PurchaseResultStatus.cancelled,
        message: message ?? 'Покупка отменена.',
      );

  factory PurchaseResult.failed(String message) => PurchaseResult(
        status: PurchaseResultStatus.failed,
        message: message,
      );
}
