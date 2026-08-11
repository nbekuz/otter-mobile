/// Body for `POST mobile/premium/rustore/verify/` (and restore).
///
/// Uses RuStore `purchaseId` (UUID), not Google Play `purchaseToken`.
class RustoreVerifyRequest {
  const RustoreVerifyRequest({
    required this.productId,
    required this.purchaseId,
    this.orderId,
    required this.packageName,
  });

  final String productId;
  final String purchaseId;
  final String? orderId;
  final String packageName;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'productId': productId,
      'purchaseId': purchaseId,
      'packageName': packageName,
    };
    final oid = orderId?.trim();
    if (oid != null && oid.isNotEmpty) {
      map['orderId'] = oid;
    }
    return map;
  }
}

/// Success / error payload from RuStore verify or restore.
class RustoreVerifyResponse {
  const RustoreVerifyResponse({
    required this.code,
    this.provider,
    this.subscription,
  });

  final String code;
  final String? provider;
  final ApiSubscriptionRef? subscription;

  bool get isOk =>
      code == 'SUBSCRIPTION_CREATED' || code == 'SUBSCRIPTION_RESTORED';

  factory RustoreVerifyResponse.fromJson(Map<String, dynamic> json) {
    final subRaw = json['subscription'];
    return RustoreVerifyResponse(
      code: json['code'] as String? ?? '',
      provider: json['provider'] as String?,
      subscription: subRaw is Map<String, dynamic>
          ? ApiSubscriptionRef.fromJson(subRaw)
          : null,
    );
  }
}

/// Minimal subscription fields returned inside verify/restore responses.
class ApiSubscriptionRef {
  const ApiSubscriptionRef({
    required this.isPremium,
    this.provider,
  });

  final bool isPremium;
  final String? provider;

  factory ApiSubscriptionRef.fromJson(Map<String, dynamic> json) =>
      ApiSubscriptionRef(
        isPremium: json['is_premium'] as bool? ?? false,
        provider: json['provider'] as String?,
      );
}
