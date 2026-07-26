import 'dart:convert';

import '../../data/mappers/task_mapper.dart';
import '../../data/models/ui/ui_models.dart';

const otterTasksExportVersion = 1;

Map<String, dynamic> tasksToExportPayload(List<Task> tasks) {
  return {
    'version': otterTasksExportVersion,
    'app': 'otter',
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'tasks': [
      for (final task in tasks)
        {
          'title': task.title,
          if (task.description != null) 'description': task.description,
          if (task.dueDate != null) 'dueDate': task.dueDate,
          if (task.dueTime != null) 'dueTime': task.dueTime,
          if (task.duration != null)
            'duration': {
              'start': task.duration!.start,
              'end': task.duration!.end,
            },
          'priority': task.priority.name,
          'completed': task.completed,
          if (task.notification != null) 'notification': task.notification,
          'repeat': task.repeat.name,
          if (task.repeatDays != null) 'repeatDays': task.repeatDays,
          if (task.repeatCustom != null)
            'repeatCustom': {
              'interval': task.repeatCustom!.interval,
              'unit': task.repeatCustom!.unit,
              if (task.repeatCustom!.weekdays != null)
                'weekdays': task.repeatCustom!.weekdays,
              if (task.repeatCustom!.monthDay != null)
                'monthDay': task.repeatCustom!.monthDay,
            },
          'isAllDay': task.isAllDay,
          if (task.matrixBlock != null)
            'matrixBlock': task.matrixBlock!.id,
        },
    ],
  };
}

String encodeTasksExport(List<Task> tasks) =>
    const JsonEncoder.withIndent('  ').convert(tasksToExportPayload(tasks));

List<PartialTask> parseTasksExport(Object? raw) {
  if (raw is! Map && raw is! List) {
    throw const FormatException('Неверный формат файла');
  }

  final list = raw is List
      ? raw
      : raw is Map && raw['tasks'] is List
          ? raw['tasks'] as List
          : null;
  if (list == null) {
    throw const FormatException('В файле нет списка задач');
  }

  final result = <PartialTask>[];
  for (final item in list) {
    if (item is! Map) continue;
    final title = (item['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) continue;

    TaskDuration? duration;
    final d = item['duration'];
    if (d is Map && d['start'] is String && d['end'] is String) {
      duration = TaskDuration(start: d['start'] as String, end: d['end'] as String);
    }

    RepeatCustom? repeatCustom;
    final rc = item['repeatCustom'];
    if (rc is Map && rc['interval'] is num) {
      final unit = rc['unit'] == 'month' ? 'month' : 'week';
      repeatCustom = RepeatCustom(
        interval: (rc['interval'] as num).toInt(),
        unit: unit,
        weekdays: rc['weekdays'] is List
            ? (rc['weekdays'] as List)
                .whereType<num>()
                .map((e) => e.toInt())
                .toList()
            : null,
        monthDay: rc['monthDay'] is num ? (rc['monthDay'] as num).toInt() : null,
      );
    }

    MatrixBlock? matrixBlock;
    final mb = item['matrixBlock'] as String?;
    if (mb != null && mb.isNotEmpty) {
      matrixBlock = mb.contains('-')
          ? MatrixBlockX.fromId(mb)
          : MatrixBlockX.fromApi(mb);
    }

    result.add(
      PartialTask(
        title: title,
        description: item['description'] as String?,
        dueDate: item['dueDate'] as String?,
        dueTime: item['dueTime'] as String?,
        duration: duration,
        priority: _priorityFrom(item['priority']),
        completed: false,
        notification: item['notification']?.toString(),
        repeat: _repeatFrom(item['repeat']),
        repeatDays: item['repeatDays'] is List
            ? (item['repeatDays'] as List)
                .whereType<num>()
                .map((e) => e.toInt())
                .toList()
            : null,
        repeatCustom: repeatCustom,
        matrixBlock: matrixBlock,
      ),
    );
  }

  if (result.isEmpty) {
    throw const FormatException('В файле нет задач для импорта');
  }
  return result;
}

Priority _priorityFrom(Object? value) {
  final s = value?.toString();
  return switch (s) {
    'high' => Priority.high,
    'medium' => Priority.medium,
    'low' => Priority.low,
    _ => Priority.none,
  };
}

RepeatType _repeatFrom(Object? value) {
  final s = value?.toString();
  return switch (s) {
    'daily' => RepeatType.daily,
    'weekly' => RepeatType.weekly,
    'monthly' => RepeatType.monthly,
    'yearly' => RepeatType.yearly,
    'custom' => RepeatType.custom,
    _ => RepeatType.none,
  };
}
