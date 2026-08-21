import '../../data/models/api/api_models.dart';

/// Matches web [PREMIUM_SUBSCRIPTION.trialDays].
const premiumTrialDays = 30;

/// Free trial is available only once. Prefer backend `trial_available`.
bool canStartPremiumTrial(ApiSubscription? subscription) {
  if (subscription == null) return true;
  if (subscription.isPremium) return false;
  if (subscription.trialAvailable != null) {
    return subscription.trialAvailable!;
  }
  if (subscription.promoUsed == true) return false;
  return subscription.status == 'none';
}

int effectivePromoDays(
  ApiTariff? tariff, {
  ApiSubscription? subscription,
}) {
  if (!canStartPremiumTrial(subscription)) return 0;
  final fromApi = tariff?.promoDays ?? 0;
  return fromApi > 0 ? fromApi : premiumTrialDays;
}
