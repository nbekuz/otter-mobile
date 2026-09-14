/// RuStore Billing product ids and app identity for Android.
abstract final class RuStoreConfig {
  static const packageName = 'com.nbekdev.otter';

  /// Deeplink scheme registered in AndroidManifest (SBP / SberPay return).
  static const deeplinkScheme = 'otter';
  static const deeplinkUri = 'otter://iamback';

  static const monthlyProductId = 'otter_month';
  static const yearlyProductId = 'otter_year';

  static const productIds = [monthlyProductId, yearlyProductId];

  /// Maps RuStore productId → backend tariff code.
  static String tariffCodeForProduct(String productId) => switch (productId) {
        yearlyProductId => 'yearly',
        _ => 'monthly',
      };

  /// Maps backend tariff code → RuStore productId.
  static String productIdForTariff(String tariffCode) => switch (tariffCode) {
        'yearly' => yearlyProductId,
        _ => monthlyProductId,
      };

  /// RuStore Pay returns e.g. `otter://iamback//ru.rustore.sdk.billingclient.back?...`.
  /// go_router must not treat these as app routes (Page Not Found).
  static bool isBillingReturnUri(Uri uri) {
    if (uri.scheme == deeplinkScheme) return true;
    return isBillingReturnLocation(uri.toString());
  }

  static bool isBillingReturnLocation(String location) {
    final s = location.toLowerCase();
    return s.contains('iamback') ||
        s.contains('rustore.sdk.billingclient') ||
        s.startsWith('$deeplinkScheme:');
  }
}
