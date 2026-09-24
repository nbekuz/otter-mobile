import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/data/models/api/api_models.dart';
import 'package:otter_mobile/data/models/billing/robokassa_sdk_params.dart';

void main() {
  test('parses mobile checkout sdk without inventing a checkout URL', () {
    final response = ApiPremiumCheckoutResponse.fromJson({
      'provider': 'robokassa',
      'payment': {
        'invoice_id': 123,
        'status': 'pending',
        'checkout_url': '',
      },
      'sdk': {
        'merchant_login': 'ottertime',
        'invoice_id': 123,
        'out_sum': '150.00',
        'description': 'Otter Premium',
        'signature_value': 'abc123',
        'culture': 'ru',
        'encoding': 'utf-8',
        'is_test': true,
        'is_recurring': false,
        'email': 'user@mail.ru',
        'receipt_json': '{"items":[]}',
      },
    });

    expect(response.provider, 'robokassa');
    expect(response.checkoutUrl, isEmpty);
    expect(response.invoiceId, 123);
    expect(response.sdk, isNotNull);
    expect(response.sdk!.isValid, isTrue);
    expect(response.sdk!.merchantLogin, 'ottertime');
    expect(response.sdk!.signatureValue, 'abc123');
    expect(response.sdk!.receiptJson, '{"items":[]}');
  });

  test('channel args keep signature_value for native POST', () {
    const sdk = RobokassaSdkParams(
      merchantLogin: 'ottertime',
      invoiceId: 1,
      outSum: '150.00',
      description: 'Premium',
      signatureValue: 'sig',
      receiptJson: '{"items":[]}',
    );
    final args = sdk.toChannelArgs();
    expect(args['signature_value'], 'sig');
    expect(args.containsKey('password'), isFalse);
    expect(args['receipt_json'], '{"items":[]}');
  });
}
