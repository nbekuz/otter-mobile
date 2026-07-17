import '../mappers/task_mapper.dart';
import '../models/api/api_models.dart';
import '../models/ui/ui_models.dart';
import '../../core/network/api_client.dart';

class MatrixService {
  MatrixService(this._client);
  final ApiClient _client;

  Future<Map<String, List<Task>>> fetchMatrix() async {
    final data = await _client.get<List<dynamic>>('matrix/');
    final result = <String, List<Task>>{};
    for (final item in data) {
      final block = ApiMatrixBlockData.fromJson(item as Map<String, dynamic>);
      final uiId = MatrixBlockX.fromApi(block.block).id;
      result[uiId] = block.tasks.map(TaskMapper.apiToUi).toList();
    }
    return result;
  }

  Future<List<ApiMatrixSetting>> fetchSettings() async {
    final data = await _client.get<List<dynamic>>('matrix/settings/');
    return data
        .map((e) => ApiMatrixSetting.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateSetting({
    required String block,
    String? title,
    List<String>? allowedPriorities,
    String? dateFilter,
  }) async {
    await _client.patch(
      'matrix/settings/',
      data: {
        'block': block,
        'title': ?title,
        'allowed_priorities': ?allowedPriorities,
        'date_filter': ?dateFilter,
      },
    );
  }
}
