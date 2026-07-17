import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/core/network/api_client.dart';
import 'package:otter_mobile/core/providers/providers.dart';
import 'package:otter_mobile/core/storage/token_storage.dart';
import 'package:otter_mobile/data/models/api/api_models.dart';
import 'package:otter_mobile/data/services/premium_service.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://example.invalid/api/v1/');
  });

  test(
    'deduplicates concurrent polling and stops after cancellation',
    () async {
      final response = Completer<ApiSubscription>();
      final service = _FakePremiumService(() {
        return response.future;
      });
      final container = ProviderContainer(
        overrides: [premiumServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(premiumStateProvider.notifier);
      final first = notifier.pollForPayment();
      final second = notifier.pollForPayment();
      await Future<void>.delayed(Duration.zero);

      expect(service.fetchCount, 1);
      notifier.cancelPaymentPolling();
      response.complete(_subscription());

      expect(await first, PremiumPaymentPollingResult.stopped);
      expect(await second, PremiumPaymentPollingResult.stopped);
      expect(container.read(premiumStateProvider).paymentPolling, isFalse);
    },
  );

  test('does not treat an existing trial as payment success', () async {
    final responses = <ApiSubscription>[
      _subscription(status: 'trial', isPremium: true),
      _subscription(status: 'trial', isPremium: true),
      _subscription(status: 'active', isPremium: true),
    ];
    final service = _FakePremiumService(() async => responses.removeAt(0));
    final container = ProviderContainer(
      overrides: [premiumServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await container.read(premiumStateProvider.notifier).refreshSubscription();

    final result = await container
        .read(premiumStateProvider.notifier)
        .pollForPayment(
          interval: const Duration(milliseconds: 1),
          timeout: const Duration(seconds: 2),
        );

    expect(result, PremiumPaymentPollingResult.success);
    expect(service.fetchCount, 3);
  });

  test('stops when the backend reports a terminal payment status', () async {
    final service = _FakePremiumService(
      () async => _subscription(status: 'failed'),
    );
    final container = ProviderContainer(
      overrides: [premiumServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(premiumStateProvider.notifier)
        .pollForPayment(
          interval: const Duration(milliseconds: 1),
          timeout: const Duration(seconds: 1),
        );

    expect(result, PremiumPaymentPollingResult.cancelled);
    expect(service.fetchCount, 1);
  });

  test('enforces the polling timeout', () async {
    final service = _FakePremiumService(() async => _subscription());
    final container = ProviderContainer(
      overrides: [premiumServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final result = await container
        .read(premiumStateProvider.notifier)
        .pollForPayment(
          interval: const Duration(milliseconds: 1),
          timeout: const Duration(milliseconds: 10),
        );

    expect(result, PremiumPaymentPollingResult.timeout);
    expect(service.fetchCount, greaterThan(0));
  });
}

class _FakePremiumService extends PremiumService {
  _FakePremiumService(this._fetch) : super(ApiClient(TokenStorage(), null));

  final Future<ApiSubscription> Function() _fetch;
  int fetchCount = 0;

  @override
  Future<ApiSubscription> fetchSubscription() {
    fetchCount++;
    return _fetch();
  }
}

ApiSubscription _subscription({
  String status = 'none',
  bool isPremium = false,
}) {
  return ApiSubscription(
    status: status,
    recurringEnabled: false,
    isPremium: isPremium,
    updatedAt: '',
  );
}
