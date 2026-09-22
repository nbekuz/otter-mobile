/// RuStore Billing product ids and app identity for Android.
abstract final class RuStoreConfig {
  static const packageName = 'com.nbekdev.otter';

  /// Dedicated Pay-return scheme. Must not collide with go_router app routes.
  /// Manifest `<data android:scheme>` and [deeplinkUri] must share this scheme.
  static const deeplinkScheme = 'com.nbekdev.otter.rustore';
  static const deeplinkUri = 'com.nbekdev.otter.rustore://iamback';

  /// Legacy scheme used before the dedicated billing scheme.
  static const legacyDeeplinkScheme = 'otter';

  /// RuStore: product already purchased (pre_confirmed / confirmed).
  static const alreadyPurchasedErrorCode = 40012;

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

  static bool isAlreadyPurchasedError({int? errorCode, Object? error}) {
    if (errorCode == alreadyPurchasedErrorCode) return true;
    final s = error?.toString().toLowerCase() ?? '';
    if (s.isEmpty) return false;
    return s.contains('40012') ||
        s.contains('уже приобретен') ||
        s.contains('already purchased') ||
        s.contains('product_already') ||
        s.contains('already_owned');
  }

  /// RuStore Pay returns e.g.
  /// `com.nbekdev.otter.rustore://iamback//ru.rustore.sdk.billingclient.back?...`.
  /// go_router must not treat these as app routes (Page Not Found).
  static bool isBillingReturnUri(Uri uri) {
    if (uri.scheme == deeplinkScheme) return true;
    return isBillingReturnLocation(uri.toString());
  }

  static bool isBillingReturnLocation(String location) {
    final s = location.toLowerCase();
    if (s.contains('iamback') ||
        s.contains('rustore.sdk.billingclient') ||
        s.contains('paylib_sp=') ||
        s.startsWith('$deeplinkScheme:')) {
      return true;
    }
    // Old APKs returned via otter://…billingclient.back
    return s.startsWith('$legacyDeeplinkScheme:') &&
        (s.contains('billingclient') ||
            s.contains('iamback') ||
            s.contains('paylib'));
  }
}
