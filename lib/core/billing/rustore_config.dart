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
}
