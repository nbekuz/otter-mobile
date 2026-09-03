import '../../../core/billing/rustore_config.dart';

/// Store subscription product for UI (RuStore-backed).
class SubscriptionProduct {
  const SubscriptionProduct({
    required this.productId,
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.periodLabel,
    this.currency,
    this.rawPrice,
    this.freeTrialLabel,
  });

  final String productId;
  final String title;
  final String description;

  /// Main recurring price from RuStore (after trial).
  final String priceLabel;
  final String periodLabel;
  final String? currency;
  final int? rawPrice;

  /// Human-readable trial length from RuStore, e.g. «1 месяц».
  final String? freeTrialLabel;

  String get tariffCode => switch (productId) {
        RuStoreConfig.yearlyProductId => 'yearly',
        _ => 'monthly',
      };

  bool get isYearly => productId == RuStoreConfig.yearlyProductId;

  bool get hasFreeTrial =>
      freeTrialLabel != null && freeTrialLabel!.trim().isNotEmpty;

  /// Short billing cadence for «… /мес» or «/год».
  String get billingCadenceShort => isYearly ? 'год' : 'мес';

  /// Recurring price for card copy (150 ₽ instead of 150.00 ₽ when whole).
  String get displayPriceLabel {
    if (rawPrice != null) {
      final major = rawPrice! / 100;
      if (major == major.roundToDouble()) {
        return '${major.round()} ₽';
      }
      return '${major.toStringAsFixed(2).replaceAll('.', ',')} ₽';
    }
    return priceLabel.replaceAll(RegExp(r'\.00(?=\s*₽)'), '');
  }

  /// Price shown for checkout today (RuStore trial → 0 ₽).
  String get nowPriceLabel => hasFreeTrial ? '0 ₽' : priceLabel;

  /// Strikethrough list price on trial cards (e.g. 150 ₽).
  String? get trialStrikethroughPrice =>
      hasFreeTrial ? displayPriceLabel : null;

  /// Today’s checkout price on trial cards.
  String? get trialTodayPriceLabel => hasFreeTrial ? '0 ₽ сегодня' : null;

  /// When recurring billing starts after the free trial.
  String? get trialFutureLine {
    if (!hasFreeTrial) return null;
    return 'Со следующего месяца — $displayPriceLabel/$billingCadenceShort';
  }

  /// Primary CTA on the paywall (variant A).
  String get purchaseButtonLabel =>
      hasFreeTrial ? 'Подключить бесплатно' : 'Купить $priceLabel';

  /// Footnote under the purchase button.
  String get purchaseFootnote {
    if (!hasFreeTrial) {
      return 'Premium активируется после подтверждения покупки на сервере.';
    }
    final trialPhrase = switch (freeTrialLabel) {
      'месяц' => 'пробного месяца',
      'год' => 'пробного года',
      final label? => 'пробного периода ($label)',
      null => 'пробного периода',
    };
    return 'После $trialPhrase подписка продлится автоматически за '
        '$displayPriceLabel/$billingCadenceShort. '
        'Отменить можно в RuStore в любой момент.';
  }
}
