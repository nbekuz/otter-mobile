import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/core/premium/premium_trial.dart';
import 'package:otter_mobile/data/models/api/api_models.dart';

ApiSubscription _sub({
  String status = 'none',
  bool isPremium = false,
  bool? trialAvailable,
  bool? promoUsed,
}) {
  return ApiSubscription(
    status: status,
    recurringEnabled: false,
    isPremium: isPremium,
    updatedAt: '',
    trialAvailable: trialAvailable,
    promoUsed: promoUsed,
  );
}

void main() {
  test('trial_available true shows the trial button', () {
    expect(canStartPremiumTrial(_sub(trialAvailable: true)), isTrue);
  });

  test('trial_available false hides trial even when status is none', () {
    expect(
      canStartPremiumTrial(_sub(status: 'none', trialAvailable: false)),
      isFalse,
    );
  });

  test('already used trial (expired) cannot start again', () {
    expect(
      canStartPremiumTrial(
        _sub(status: 'expired', trialAvailable: false, promoUsed: true),
      ),
      isFalse,
    );
  });

  test('active premium cannot start trial', () {
    expect(
      canStartPremiumTrial(_sub(status: 'active', isPremium: true)),
      isFalse,
    );
  });

  test('missing trial_available falls back to status none', () {
    expect(canStartPremiumTrial(_sub(status: 'none')), isTrue);
    expect(canStartPremiumTrial(_sub(status: 'expired', promoUsed: true)), isFalse);
  });
}
