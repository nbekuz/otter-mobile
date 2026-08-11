import '../models/api/api_models.dart';
import '../models/billing/subscription_verify_request.dart';
import '../../core/network/api_client.dart';

/// Premium API for the Flutter app.
///
/// Android RuStore uses `mobile/premium/...` (see RUSTORE_ANDROID_PREMIUM.md).
/// Robokassa checkout/trial stay on classic `premium/...` paths.
class PremiumService {
  PremiumService(this._client);
  final ApiClient _client;

  static const _mobilePremium = 'mobile/premium';
  static const _premium = 'premium';

  Future<List<ApiTariff>> fetchTariffs() async {
    final data = await _client.get<List<dynamic>>('$_mobilePremium/tariffs/');
    final list =
        data.map((e) => ApiTariff.fromJson(e as Map<String, dynamic>)).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  Future<ApiSubscription> fetchSubscription() async {
    final data = await _client.get<Map<String, dynamic>>(
      '$_mobilePremium/subscription/',
    );
    return ApiSubscription.fromJson(data);
  }

  Future<ApiSubscription> startTrial({
    required String tariff,
    bool recurringConsent = false,
    String offerVersion = '2026-07-01',
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '$_premium/trial/',
      data: {
        'tariff': tariff,
        'recurring_consent': recurringConsent,
        'offer_version': offerVersion,
      },
    );
    return ApiSubscription.fromJson(data);
  }

  Future<ApiPremiumCheckoutResponse> checkout({
    required String tariff,
    bool recurringConsent = false,
    String offerVersion = '2026-07-01',
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '$_premium/checkout/',
      data: {
        'tariff': tariff,
        'recurring_consent': recurringConsent,
        'offer_version': offerVersion,
      },
    );
    return ApiPremiumCheckoutResponse.fromJson(data);
  }

  /// Verifies a RuStore purchase on the backend. Does not grant Premium locally.
  Future<RustoreVerifyResponse> verifyRustorePurchase(
    RustoreVerifyRequest request,
  ) async {
    final data = await _client.post<Map<String, dynamic>>(
      '$_mobilePremium/rustore/verify/',
      data: request.toJson(),
    );
    return RustoreVerifyResponse.fromJson(data);
  }

  /// Restores / re-attaches a RuStore purchase. Body is optional.
  Future<RustoreVerifyResponse> restoreRustorePurchase([
    RustoreVerifyRequest? request,
  ]) async {
    final data = await _client.post<Map<String, dynamic>>(
      '$_mobilePremium/rustore/restore/',
      data: request?.toJson() ?? <String, dynamic>{},
    );
    return RustoreVerifyResponse.fromJson(data);
  }

  Future<ApiSubscription> cancel() async {
    final data = await _client.post<Map<String, dynamic>>(
      '$_mobilePremium/cancel/',
      data: <String, dynamic>{},
    );
    return ApiSubscription.fromJson(data);
  }

  Future<List<ApiPremiumFeature>> fetchFeatures() async {
    final data = await _client.get<List<dynamic>>('$_premium/features/');
    return data
        .map((e) => ApiPremiumFeature.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
