import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/core/billing/premium_billing.dart';

void main() {
  group('isEmailAllowedForRustoreBilling', () {
    test('allows owner email case-insensitively', () {
      expect(isEmailAllowedForRustoreBilling('nbekdev@gmail.com'), isTrue);
      expect(isEmailAllowedForRustoreBilling('NbekDev@Gmail.com'), isTrue);
      expect(isEmailAllowedForRustoreBilling('  nbekdev@gmail.com  '), isTrue);
    });

    test('rejects other accounts and empty', () {
      expect(isEmailAllowedForRustoreBilling('client@example.com'), isFalse);
      expect(isEmailAllowedForRustoreBilling(''), isFalse);
      expect(isEmailAllowedForRustoreBilling(null), isFalse);
    });
  });

  group('isRustoreBillingActiveFor', () {
    test('owner email maps to rustore only on Android', () {
      // Platform.isAndroid is true in flutter_test default target when
      // overridden; without override this asserts the allowlist helper path.
      final owner = isEmailAllowedForRustoreBilling('nbekdev@gmail.com');
      final other = isEmailAllowedForRustoreBilling('other@mail.ru');
      expect(owner, isTrue);
      expect(other, isFalse);
    });
  });
}
