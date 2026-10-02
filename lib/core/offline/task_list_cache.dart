import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/mappers/task_mapper.dart';
import '../../data/models/ui/ui_models.dart';

/// Last successful (or offline-edited) grouped task lists.
abstract final class TaskListCache {
  static const _key = 'otter.tasks.grouped.v1';

  static Future<void> save(Map<TaskGroupKey, List<Task>> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      for (final entry in groups.entries)
        entry.key.name: entry.value.map(_taskToJson).toList(),
    };
    await prefs.setString(_key, jsonEncode(payload));
  }

  static Future<Map<TaskGroupKey, List<Task>>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final groups = <TaskGroupKey, List<Task>>{};
      for (final entry in decoded.entries) {
        final key = TaskGroupKey.values.cast<TaskGroupKey?>().firstWhere(
              (k) => k?.name == entry.key,
              orElse: () => null,
            );
        if (key == null || entry.value is! List) continue;
        groups[key] = [
          for (final item in entry.value as List)
            if (item is Map) _taskFromJson(Map<String, dynamic>.from(item)),
        ];
      }
      return groups;
    } catch (_) {
      return null;
    }
  }
}

Map<String, dynamic> _taskToJson(Task task) => {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'dueDate': task.dueDate,
      'dueTime': task.dueTime,
      'durationStart': task.duration?.start,
      'durationEnd': task.duration?.end,
      'priority': task.priority.name,
      'completed': task.completed,
      'completedAt': task.completedAt,
      'notification': task.notification,
      'repeat': task.repeat.name,
      'repeatDays': task.repeatDays,
      'repeatCustom': task.repeatCustom == null
          ? null
          : {
              'interval': task.repeatCustom!.interval,
              'unit': task.repeatCustom!.unit,
              'weekdays': task.repeatCustom!.weekdays,
              'monthDay': task.repeatCustom!.monthDay,
            },
      'matrixBlock': task.matrixBlock?.apiValue,
      'seriesId': task.seriesId,
      'parentTaskId': task.parentTaskId,
      'createdAt': task.createdAt,
      'isAllDay': task.isAllDay,
    };

Task _taskFromJson(Map<String, dynamic> json) {
  final start = json['durationStart'] as String?;
  final end = json['durationEnd'] as String?;
  final custom = json['repeatCustom'];
  return Task(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    description: json['description'] as String?,
    dueDate: json['dueDate'] as String?,
    dueTime: json['dueTime'] as String?,
    duration: (start != null && end != null)
        ? TaskDuration(start: start, end: end)
        : null,
    priority: Priority.values.firstWhere(
      (p) => p.name == json['priority'],
      orElse: () => Priority.none,
    ),
    completed: json['completed'] == true,
    completedAt: json['completedAt'] as String?,
    notification: json['notification'] as String?,
    repeat: RepeatType.values.firstWhere(
      (r) => r.name == json['repeat'],
      orElse: () => RepeatType.none,
    ),
    repeatDays: (json['repeatDays'] as List?)?.map((e) => (e as num).toInt()).toList(),
    repeatCustom: custom is Map
        ? RepeatCustom(
            interval: (custom['interval'] as num?)?.toInt() ?? 1,
            unit: '${custom['unit'] ?? 'week'}',
            weekdays: (custom['weekdays'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList(),
            monthDay: (custom['monthDay'] as num?)?.toInt(),
          )
        : null,
    matrixBlock: json['matrixBlock'] is String
        ? MatrixBlockX.fromApi(json['matrixBlock'] as String)
        : null,
    seriesId: json['seriesId'] as String?,
    parentTaskId: json['parentTaskId'] as String?,
    createdAt: '${json['createdAt'] ?? DateTime.now().toIso8601String()}',
    isAllDay: json['isAllDay'] == true,
  );
}

Map<String, dynamic> partialToJson(PartialTask partial) => {
      'title': partial.title,
      'description': partial.description,
      'dueDate': partial.dueDate,
      'dueTime': partial.dueTime,
      'durationStart': partial.duration?.start,
      'durationEnd': partial.duration?.end,
      'priority': partial.priority?.name,
      'completed': partial.completed,
      'notification': partial.notification,
      'repeat': partial.repeat?.name,
      'repeatDays': partial.repeatDays,
      'repeatCustom': partial.repeatCustom == null
          ? null
          : {
              'interval': partial.repeatCustom!.interval,
              'unit': partial.repeatCustom!.unit,
              'weekdays': partial.repeatCustom!.weekdays,
              'monthDay': partial.repeatCustom!.monthDay,
            },
      'matrixBlock': partial.matrixBlock?.apiValue,
      'seriesId': partial.seriesId,
      'parentTaskId': partial.parentTaskId,
      'clearImage': partial.clearImage,
      'clearDueDate': partial.clearDueDate,
      'clearDueTime': partial.clearDueTime,
      'clearDuration': partial.clearDuration,
      'clearNotification': partial.clearNotification,
      'clearDescription': partial.clearDescription,
    };

PartialTask partialFromJson(Map<String, dynamic> json) {
  final start = json['durationStart'] as String?;
  final end = json['durationEnd'] as String?;
  final custom = json['repeatCustom'];
  return PartialTask(
    title: json['title'] as String?,
    description: json['description'] as String?,
    dueDate: json['dueDate'] as String?,
    dueTime: json['dueTime'] as String?,
    duration: (start != null && end != null)
        ? TaskDuration(start: start, end: end)
        : null,
    priority: json['priority'] is String
        ? Priority.values.firstWhere(
            (p) => p.name == json['priority'],
            orElse: () => Priority.none,
          )
        : null,
    completed: json['completed'] as bool?,
    notification: json['notification'] as String?,
    repeat: json['repeat'] is String
        ? RepeatType.values.firstWhere(
            (r) => r.name == json['repeat'],
            orElse: () => RepeatType.none,
          )
        : null,
    repeatDays: (json['repeatDays'] as List?)?.map((e) => (e as num).toInt()).toList(),
    repeatCustom: custom is Map
        ? RepeatCustom(
            interval: (custom['interval'] as num?)?.toInt() ?? 1,
            unit: '${custom['unit'] ?? 'week'}',
            weekdays: (custom['weekdays'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList(),
            monthDay: (custom['monthDay'] as num?)?.toInt(),
          )
        : null,
    matrixBlock: json['matrixBlock'] is String
        ? MatrixBlockX.fromApi(json['matrixBlock'] as String)
        : null,
    seriesId: json['seriesId'] as String?,
    parentTaskId: json['parentTaskId'] as String?,
    clearImage: json['clearImage'] == true,
    clearDueDate: json['clearDueDate'] == true,
    clearDueTime: json['clearDueTime'] == true,
    clearDuration: json['clearDuration'] == true,
    clearNotification: json['clearNotification'] == true,
    clearDescription: json['clearDescription'] == true,
  );
}
