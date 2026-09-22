import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/core/billing/rustore_config.dart';

void main() {
  group('RuStoreConfig billing return', () {
    test('dedicated scheme is a billing return', () {
      final uri = Uri.parse(
        'com.nbekdev.otter.rustore://iamback//ru.rustore.sdk.billingclient.back?paylib_sp=success',
      );
      expect(RuStoreConfig.isBillingReturnUri(uri), isTrue);
    });

    test('legacy otter billing callback is still recognized', () {
      const raw =
          'otter://ru.rustore.sdk.billingclient.back?paylib_sp=success';
      expect(RuStoreConfig.isBillingReturnLocation(raw), isTrue);
    });

    test('plain otter app route is not a billing return', () {
      expect(
        RuStoreConfig.isBillingReturnLocation('otter://app/settings'),
        isFalse,
      );
    });

    test('app path is not a billing return', () {
      expect(RuStoreConfig.isBillingReturnLocation('/app/settings'), isFalse);
    });
  });

  group('RuStoreConfig already purchased', () {
    test('detects error code 40012', () {
      expect(
        RuStoreConfig.isAlreadyPurchasedError(errorCode: 40012),
        isTrue,
      );
    });

    test('detects Russian already-purchased text', () {
      expect(
        RuStoreConfig.isAlreadyPurchasedError(
          error: Exception('Продукт уже приобретен'),
        ),
        isTrue,
      );
    });

    test('ignores unrelated errors', () {
      expect(
        RuStoreConfig.isAlreadyPurchasedError(
          errorCode: 50202,
          error: Exception('Покупка недоступна'),
        ),
        isFalse,
      );
    });
  });
}
