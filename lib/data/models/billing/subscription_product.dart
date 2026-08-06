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
  });

  final String productId;
  final String title;
  final String description;
  final String priceLabel;
  final String periodLabel;
  final String? currency;
  final int? rawPrice;

  String get tariffCode => switch (productId) {
        'otter_year' => 'yearly',
        _ => 'monthly',
      };
}
