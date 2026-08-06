import 'dart:io';

/// How Premium purchase is fulfilled on the current platform.
///
/// - [robokassa] — existing Web/Windows flow (`premium/checkout/` + external URL).
/// - [androidComingSoon] — Android commerce UI hidden; RuStore Billing later.
/// - [rustore] — Android RuStore Billing SDK (`flutter_rustore_billing`).
enum PremiumBillingProvider {
  robokassa,
  androidComingSoon,
  rustore,
}

/// Single switch for Android store billing.
///
/// RuStore Billing is active on Android; Robokassa stays for Windows/desktop.
const PremiumBillingProvider kAndroidBillingProvider =
    PremiumBillingProvider.rustore;

/// Resolves the active billing provider for this process.
PremiumBillingProvider resolvePremiumBillingProvider() {
  if (Platform.isAndroid) {
    return kAndroidBillingProvider;
  }
  // Windows (and any non-Android desktop/mobile target) keeps Robokassa.
  return PremiumBillingProvider.robokassa;
}

/// True when Android must not show or call any paid-subscription commerce
/// (tariffs, prices, trial paywall, Robokassa checkout, consent, etc.).
bool get isAndroidPremiumPurchaseBlocked {
  final provider = resolvePremiumBillingProvider();
  return Platform.isAndroid &&
      provider == PremiumBillingProvider.androidComingSoon;
}
