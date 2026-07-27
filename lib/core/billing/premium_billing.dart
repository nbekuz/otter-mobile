import 'dart:io';

/// How Premium purchase is fulfilled on the current platform.
///
/// - [robokassa] — existing Web/Windows flow (`premium/checkout/` + external URL).
/// - [androidComingSoon] — Android purchases temporarily disabled (UI still shown).
/// - [rustore] — reserved for future RuStore Billing integration.
enum PremiumBillingProvider {
  robokassa,
  androidComingSoon,
  rustore,
}

/// Single switch for Android store billing.
/// Flip to [PremiumBillingProvider.rustore] when RuStore Billing is ready;
/// keep Robokassa untouched for Windows/desktop.
const PremiumBillingProvider kAndroidBillingProvider =
    PremiumBillingProvider.androidComingSoon;

/// Resolves the active billing provider for this process.
PremiumBillingProvider resolvePremiumBillingProvider() {
  if (Platform.isAndroid) {
    return kAndroidBillingProvider;
  }
  // Windows (and any non-Android desktop/mobile target) keeps Robokassa.
  return PremiumBillingProvider.robokassa;
}

/// True when the pay action must not call Robokassa / open a checkout URL.
bool get isAndroidPremiumPurchaseBlocked {
  final provider = resolvePremiumBillingProvider();
  return Platform.isAndroid &&
      provider == PremiumBillingProvider.androidComingSoon;
}
