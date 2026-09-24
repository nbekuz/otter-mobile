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

/// Single switch for Android store billing capability.
///
/// When [rustore], only [kRustoreBillingAllowlistEmails] use RuStore SDK;
/// every other Android account pays via otter-app web Robokassa checkout.
const PremiumBillingProvider kAndroidBillingProvider =
    PremiumBillingProvider.rustore;

/// Android accounts allowed to use RuStore Billing (QA / owner).
/// Everyone else on Android uses Robokassa through otter-app `/premium/pay`.
const Set<String> kRustoreBillingAllowlistEmails = {
  'nbekdev@gmail.com',
};

bool isEmailAllowedForRustoreBilling(String? email) {
  final normalized = email?.trim().toLowerCase() ?? '';
  if (normalized.isEmpty) return false;
  return kRustoreBillingAllowlistEmails.contains(normalized);
}

/// Resolves the active billing provider for this process / signed-in user.
PremiumBillingProvider resolvePremiumBillingProvider({String? userEmail}) {
  if (!Platform.isAndroid) {
    // Windows (and any non-Android target) keeps Robokassa.
    return PremiumBillingProvider.robokassa;
  }

  switch (kAndroidBillingProvider) {
    case PremiumBillingProvider.androidComingSoon:
      return PremiumBillingProvider.androidComingSoon;
    case PremiumBillingProvider.rustore:
      if (isEmailAllowedForRustoreBilling(userEmail)) {
        return PremiumBillingProvider.rustore;
      }
      return PremiumBillingProvider.robokassa;
    case PremiumBillingProvider.robokassa:
      return PremiumBillingProvider.robokassa;
  }
}

bool isRustoreBillingActiveFor(String? userEmail) =>
    resolvePremiumBillingProvider(userEmail: userEmail) ==
    PremiumBillingProvider.rustore;

/// Android Robokassa path — opens otter-app web checkout (not native SDK).
bool isAndroidRobokassaBillingFor(String? userEmail) =>
    Platform.isAndroid &&
    resolvePremiumBillingProvider(userEmail: userEmail) ==
        PremiumBillingProvider.robokassa;

/// True when Android must not show or call any paid-subscription commerce
/// (tariffs, prices, trial paywall, Robokassa checkout, consent, etc.).
bool get isAndroidPremiumPurchaseBlocked {
  return Platform.isAndroid &&
      kAndroidBillingProvider == PremiumBillingProvider.androidComingSoon;
}
