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
    // Bust intermediaries that may cache bare GET /tasks/grouped/ on desktop.
    final data = await _client.get<List<dynamic>>(
      'tasks/grouped/',
      queryParameters: {'_': DateTime.now().millisecondsSinceEpoch},
      headers: const {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
      },
    );
    final map = <TaskGroupKey, List<Task>>{};
    for (final item in data) {
      if (item is! Map) continue;
      final json = Map<String, dynamic>.from(item);
      final key = TaskGroupKeyX.fromApi('${json['key'] ?? 'no_deadline'}');
      final tasks = <Task>[];
      for (final raw in (json['tasks'] as List<dynamic>? ?? const [])) {
        if (raw is! Map) continue;
        try {
          tasks.add(
            TaskMapper.apiToUi(
              ApiTask.fromJson(Map<String, dynamic>.from(raw)),
            ),
          );
        } catch (_) {
          // Skip a single bad payload so one task cannot block the whole refresh.
        }
      }
      map[key] = [...?map[key], ...tasks];
    }
    return map;
  }

  Future<Object> _payloadFor(
    PartialTask partial, {
    bool includeMatrixBlock = true,
  }) async {
    final json = TaskMapper.uiToApiPayload(
      partial,
      includeMatrixBlock: includeMatrixBlock,
    );
    final paths = partial.resolvedImagePaths;
    if (paths.isEmpty && !partial.clearImage) return json;

    final form = FormData.fromMap({
      for (final e in json.entries)
        if (e.value != null) e.key: e.value is bool ? e.value : '${e.value}',
      // Keep legacy single `image` field for first file (older API paths).
      if (paths.isNotEmpty)
        'image': await MultipartFile.fromFile(paths.first),
      if (partial.clearImage && paths.isEmpty) 'image': '',
    });
    return form;
  }

  Future<Task> createTask(
    PartialTask partial, {
    bool includeMatrixBlock = true,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      'tasks/',
      data: await _payloadFor(
        partial,
        includeMatrixBlock: includeMatrixBlock,
      ),
    );
    var task = TaskMapper.apiToUi(ApiTask.fromJson(data));
    for (final path in partial.resolvedImagePaths) {
      try {
        await uploadAttachment(task.id, path);
      } catch (_) {}
    }
    if (partial.resolvedImagePaths.isNotEmpty) {
      try {
        task = await fetchTask(task.id);
      } catch (_) {}
    }
    return task;
  }

  Future<Task> updateTask(
    String id,
    PartialTask partial, {
    bool includeMatrixBlock = true,
  }) async {
    final data = await _client.patch<Map<String, dynamic>>(
      'tasks/$id/',
      data: await _payloadFor(
        partial,
        includeMatrixBlock: includeMatrixBlock,
      ),
    );
    var task = TaskMapper.apiToUi(ApiTask.fromJson(data));

    final deleteIds = <int>{...partial.resolvedDeleteAttachmentIds};
    // When clearing the attachment, also drop any ids still present on the
    // PATCH response (e.g. only legacy image_url was tracked in the form).
    if (partial.clearImage && partial.resolvedImagePaths.isEmpty) {
      for (final a in task.attachments) {
        if (a.id != null) deleteIds.add(a.id!);
      }
    }

    Object? deleteError;
    for (final attachmentId in deleteIds) {
      try {
        await deleteAttachment(id, attachmentId);
      } catch (e) {
        deleteError ??= e;
      }
    }

    for (final path in partial.resolvedImagePaths) {
      try {
        await uploadAttachment(id, path);
      } catch (_) {}
    }

    if (partial.resolvedImagePaths.isNotEmpty || deleteIds.isNotEmpty) {
      try {
        task = await fetchTask(id);
      } catch (_) {}
    }

    // Clearing must not leave a stale file behind — surface delete failures.
    if (partial.clearImage &&
        partial.resolvedImagePaths.isEmpty &&
        (task.attachments.isNotEmpty ||
            (task.imageUrl != null && task.imageUrl!.isNotEmpty))) {
      for (final a in task.attachments) {
        if (a.id == null) continue;
        await deleteAttachment(id, a.id!);
      }
      task = await fetchTask(id);
    } else if (deleteError != null &&
        partial.clearImage &&
        partial.resolvedImagePaths.isEmpty) {
      throw deleteError;
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
