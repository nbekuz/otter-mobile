import '../../data/models/api/api_models.dart';

/// Display overrides while backend tariffs catch up to product pricing.
const Map<String, ({double price, int promoDays})> premiumTariffDisplay = {
  'monthly': (price: 150, promoDays: 30),
  'yearly': (price: 1500, promoDays: 30),
};

final _promoSideNote = RegExp(
  r'промо-период\s+настраивается\s+на\s+стороне\s+otter\.?',
  caseSensitive: false,
);

bool isPurchaseableTariff(ApiTariff tariff) {
  final code = tariff.code.toLowerCase();
  if (code == 'lifetime' || code == 'forever' || code == 'навсегда') {
    return false;
  }
  if (tariff.durationDays == 0) return false;
  return true;
}

String sanitizeTariffDescription(String description) {
  return description
      .replaceAll(_promoSideNote, '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

ApiTariff normalizeTariffForDisplay(ApiTariff tariff) {
  final override = premiumTariffDisplay[tariff.code];
  return ApiTariff(
    code: tariff.code,
    title: tariff.title,
    description: sanitizeTariffDescription(tariff.description),
    price: override != null ? override.price.toStringAsFixed(0) : tariff.price,
    currency: tariff.currency,
    durationDays: tariff.durationDays,
    promoDays: override?.promoDays ?? tariff.promoDays,
    isRecurring: tariff.isRecurring,
    sortOrder: tariff.sortOrder,
  );
}

List<ApiTariff> normalizeTariffsForDisplay(List<ApiTariff> tariffs) {
  final list = tariffs
      .where(isPurchaseableTariff)
      .map(normalizeTariffForDisplay)
      .toList();
  list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return list;
}
