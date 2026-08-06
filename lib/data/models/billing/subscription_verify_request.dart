/// Body for `POST subscription/verify/`.
class SubscriptionVerifyRequest {
  const SubscriptionVerifyRequest({
    required this.productId,
    required this.purchaseToken,
    required this.orderId,
    required this.purchaseTime,
    required this.developerPayload,
    required this.packageName,
  });

  final String productId;
  final String purchaseToken;
  final String orderId;
  final String purchaseTime;
  final String developerPayload;
  final String packageName;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'purchaseToken': purchaseToken,
        'orderId': orderId,
        'purchaseTime': purchaseTime,
        'developerPayload': developerPayload,
        'packageName': packageName,
      };
}
