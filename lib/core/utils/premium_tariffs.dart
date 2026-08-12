import '../../data/models/api/api_models.dart';
import '../billing/rustore_config.dart';

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

/// Keep API price/promo as-is; only clean description for UI.
ApiTariff normalizeTariffForDisplay(ApiTariff tariff) {
  return ApiTariff(
    code: tariff.code,
    title: tariff.title,
    description: sanitizeTariffDescription(tariff.description),
    price: tariff.price,
    currency: tariff.currency,
    durationDays: tariff.durationDays,
    promoDays: tariff.promoDays,
    isRecurring: tariff.isRecurring,
    sortOrder: tariff.sortOrder,
    rustoreProductId: tariff.rustoreProductId,
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

/// Prefer Admin `rustore_product_id`, fall back to known Console ids.
String rustoreProductIdForTariff(ApiTariff tariff) {
  final id = tariff.rustoreProductId?.trim();
  if (id != null && id.isNotEmpty) return id;
  return RuStoreConfig.productIdForTariff(tariff.code);
}

String rustoreProductIdForTariffCode(
  String code, {
  List<ApiTariff> tariffs = const [],
}) {
  for (final t in tariffs) {
    if (t.code == code) return rustoreProductIdForTariff(t);
  }
  return RuStoreConfig.productIdForTariff(code);
}

String tariffCodeForRustoreProduct(
  String productId, {
  List<ApiTariff> tariffs = const [],
}) {
  for (final t in tariffs) {
    final id = t.rustoreProductId?.trim();
    if (id != null && id == productId) return t.code;
  }
  return RuStoreConfig.tariffCodeForProduct(productId);
}

List<String> rustoreProductIdsFromTariffs(List<ApiTariff> tariffs) {
  final ids = <String>{};
  for (final t in tariffs) {
    ids.add(rustoreProductIdForTariff(t));
  }
  if (ids.isEmpty) return List<String>.from(RuStoreConfig.productIds);
  return ids.toList();
}
