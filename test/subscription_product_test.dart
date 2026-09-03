import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/core/billing/rustore_config.dart';
import 'package:otter_mobile/data/models/billing/subscription_product.dart';

SubscriptionProduct _product({
  required String productId,
  String priceLabel = '150.00 ₽',
  String? freeTrialLabel,
}) {
  return SubscriptionProduct(
    productId: productId,
    title: 'Test',
    description: '',
    priceLabel: priceLabel,
    periodLabel: productId == RuStoreConfig.yearlyProductId ? 'год' : 'месяц',
    freeTrialLabel: freeTrialLabel,
  );
}

void main() {
  test('monthly trial shows variant A copy', () {
    final p = _product(
      productId: RuStoreConfig.monthlyProductId,
      freeTrialLabel: 'месяц',
    );

    expect(p.hasFreeTrial, isTrue);
    expect(p.displayPriceLabel, '150 ₽');
    expect(p.trialStrikethroughPrice, '150 ₽');
    expect(p.trialTodayPriceLabel, '0 ₽ сегодня');
    expect(p.trialFutureLine, 'Со следующего месяца — 150 ₽/мес');
    expect(p.purchaseButtonLabel, 'Подключить бесплатно');
    expect(p.billingCadenceShort, 'мес');
    expect(
      p.purchaseFootnote,
      contains('После пробного месяца'),
    );
  });

  test('yearly trial uses /год cadence', () {
    final p = _product(
      productId: RuStoreConfig.yearlyProductId,
      priceLabel: '1500.00 ₽',
      freeTrialLabel: 'месяц',
    );

    expect(p.displayPriceLabel, '1500 ₽');
    expect(p.trialFutureLine, 'Со следующего месяца — 1500 ₽/год');
    expect(p.billingCadenceShort, 'год');
    expect(
      p.purchaseFootnote,
      contains('1500 ₽/год'),
    );
  });

  test('without trial keeps paid copy', () {
    final p = _product(productId: RuStoreConfig.monthlyProductId);

    expect(p.hasFreeTrial, isFalse);
    expect(p.nowPriceLabel, '150.00 ₽');
    expect(p.purchaseButtonLabel, 'Купить 150.00 ₽');
    expect(p.trialFutureLine, isNull);
  });
}
