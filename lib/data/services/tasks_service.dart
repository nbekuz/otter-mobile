import 'package:dio/dio.dart';

import '../mappers/task_mapper.dart';
import '../models/api/api_models.dart';
import '../models/ui/ui_models.dart';
import '../../core/network/api_client.dart';

class CompleteTaskResult {
  CompleteTaskResult({required this.task, this.nextTask});
  final Task task;
  final Task? nextTask;
}

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

  Future<Object> _payloadFor(PartialTask partial) async {
    final json = TaskMapper.uiToApiPayload(partial);
    if (partial.imagePath == null && !partial.clearImage) return json;

    final form = FormData.fromMap({
      for (final e in json.entries)
        if (e.value != null) e.key: e.value is bool ? e.value : '${e.value}',
      if (partial.imagePath != null)
        'image': await MultipartFile.fromFile(partial.imagePath!),
      if (partial.clearImage) 'image': '',
    });
    return form;
  }

  Future<Task> createTask(PartialTask partial) async {
    final data = await _client.post<Map<String, dynamic>>(
      'tasks/',
      data: await _payloadFor(partial),
    );
    var task = TaskMapper.apiToUi(ApiTask.fromJson(data));
    if (partial.imagePath != null) {
      try {
        await uploadAttachment(task.id, partial.imagePath!);
        task = await fetchTask(task.id);
      } catch (_) {}
    }
    return task;
  }

  Future<Task> updateTask(String id, PartialTask partial) async {
    final data = await _client.patch<Map<String, dynamic>>(
      'tasks/$id/',
      data: await _payloadFor(partial),
    );
    var task = TaskMapper.apiToUi(ApiTask.fromJson(data));

    if (partial.deleteAttachmentId != null) {
      try {
        await deleteAttachment(id, partial.deleteAttachmentId!);
        task = await fetchTask(id);
      } catch (_) {}
    }

    if (partial.imagePath != null) {
      try {
        await uploadAttachment(id, partial.imagePath!);
        task = await fetchTask(id);
      } catch (_) {}
    }
    return task;
  }

  Future<void> deleteTask(String id, {String? scope}) async {
    await _client.delete(
      'tasks/$id/',
      queryParameters: scope != null ? {'scope': scope} : null,
    );
  }

  Future<CompleteTaskResult> toggleComplete(
    String id, {
    required bool wasCompleted,
  }) async {
    final endpoint = wasCompleted ? 'uncomplete' : 'complete';
    final data = await _client.post<Map<String, dynamic>>(
      'tasks/$id/$endpoint/',
    );
    final api = ApiTask.fromJson(data);
    return CompleteTaskResult(
      task: TaskMapper.apiToUi(api),
      nextTask: api.nextTask != null
          ? TaskMapper.apiToUi(api.nextTask!)
          : null,
    );
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

  Future<ApiAttachment> uploadAttachment(String taskId, String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final data = await _client.post<Map<String, dynamic>>(
      'tasks/$taskId/attachments/',
      data: form,
    );
    return ApiAttachment.fromJson(data);
  }

  Future<void> deleteAttachment(String taskId, int attachmentId) async {
    await _client.delete('tasks/$taskId/attachments/$attachmentId/');
  }
}
