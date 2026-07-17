import '../models/api/api_models.dart';
import '../../core/network/api_client.dart';

class PremiumService {
  PremiumService(this._client);
  final ApiClient _client;

  Future<List<ApiTariff>> fetchTariffs() async {
    final data = await _client.get<List<dynamic>>('premium/tariffs/');
    final list =
        data.map((e) => ApiTariff.fromJson(e as Map<String, dynamic>)).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  Future<ApiSubscription> fetchSubscription() async {
    final data = await _client.get<Map<String, dynamic>>(
      'premium/subscription/',
    );
    return ApiSubscription.fromJson(data);
  }

  Future<ApiSubscription> startTrial({
    required String tariff,
    bool recurringConsent = false,
    String offerVersion = '2026-07-01',
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      'premium/trial/',
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
      'premium/checkout/',
      data: {
        'tariff': tariff,
        'recurring_consent': recurringConsent,
        'offer_version': offerVersion,
      },
    );
    return ApiPremiumCheckoutResponse.fromJson(data);
  }

  Future<ApiSubscription> cancel() async {
    final data = await _client.post<Map<String, dynamic>>(
      'premium/cancel/',
      data: <String, dynamic>{},
    );
    return ApiSubscription.fromJson(data);
  }

  Future<List<ApiPremiumFeature>> fetchFeatures() async {
    final data = await _client.get<List<dynamic>>('premium/features/');
    return data
        .map((e) => ApiPremiumFeature.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
