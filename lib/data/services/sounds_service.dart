import '../models/api/api_models.dart';
import '../../core/network/api_client.dart';

class SoundsService {
  SoundsService(this._client);
  final ApiClient _client;

  Future<List<ApiSound>> fetchByCategory(String category) async {
    final data = await _client.get<List<dynamic>>(
      'sounds/',
      queryParameters: {'category': category},
    );
    return data
        .map((e) => ApiSound.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<({List<ApiSound> workBackground, List<ApiSound> timerEnd})>
  fetchAll() async {
    final results = await Future.wait([
      fetchByCategory('work_background'),
      fetchByCategory('timer_end'),
    ]);
    return (workBackground: results[0], timerEnd: results[1]);
  }
}
