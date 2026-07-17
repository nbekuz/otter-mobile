import '../mappers/task_mapper.dart';
import '../models/api/api_models.dart';
import '../models/ui/ui_models.dart';
import '../../core/network/api_client.dart';

class TasksService {
  TasksService(this._client);
  final ApiClient _client;

  Future<Map<TaskGroupKey, List<Task>>> fetchGrouped() async {
    final data = await _client.get<List<dynamic>>('tasks/grouped/');
    final map = <TaskGroupKey, List<Task>>{};
    for (final item in data) {
      final group = ApiTaskGroup.fromJson(item as Map<String, dynamic>);
      final key = TaskGroupKeyX.fromApi(group.key);
      map[key] = group.tasks.map(TaskMapper.apiToUi).toList();
    }
    return map;
  }

  Future<Task> createTask(PartialTask partial) async {
    final data = await _client.post<Map<String, dynamic>>(
      'tasks/',
      data: TaskMapper.uiToApiPayload(partial),
    );
    return TaskMapper.apiToUi(ApiTask.fromJson(data));
  }

  Future<Task> updateTask(String id, PartialTask partial) async {
    final data = await _client.patch<Map<String, dynamic>>(
      'tasks/$id/',
      data: TaskMapper.uiToApiPayload(partial),
    );
    return TaskMapper.apiToUi(ApiTask.fromJson(data));
  }

  Future<void> deleteTask(String id) async {
    await _client.delete('tasks/$id/');
  }

  Future<Task> toggleComplete(String id, {required bool wasCompleted}) async {
    final endpoint = wasCompleted ? 'uncomplete' : 'complete';
    final data = await _client.post<Map<String, dynamic>>(
      'tasks/$id/$endpoint/',
    );
    return TaskMapper.apiToUi(ApiTask.fromJson(data));
  }

  Future<Task> moveToMatrix(String id, MatrixBlock block) async {
    final data = await _client.patch<Map<String, dynamic>>(
      'tasks/$id/',
      data: {'matrix_block': block.apiValue},
    );
    return TaskMapper.apiToUi(ApiTask.fromJson(data));
  }

  Future<Task> fetchTask(String id) async {
    final data = await _client.get<Map<String, dynamic>>('tasks/$id/');
    return TaskMapper.apiToUi(ApiTask.fromJson(data));
  }

  Future<List<Task>> searchTasks(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _client.get<Map<String, dynamic>>(
      'tasks/',
      queryParameters: {'search': query.trim(), 'limit': 50},
    );
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .map(
          (e) =>
              TaskMapper.apiToUi(ApiTask.fromJson(e as Map<String, dynamic>)),
        )
        .toList();
  }
}
