import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/mappers/task_mapper.dart';
import 'task_list_cache.dart';

enum TaskOutboxOp { create, update, delete, complete }

class TaskOutboxItem {
  TaskOutboxItem({
    required this.op,
    required this.id,
    this.partial,
    this.wasCompleted,
    this.scope,
  });

  final TaskOutboxOp op;
  final String id;
  final PartialTask? partial;
  final bool? wasCompleted;
  final String? scope;

  Map<String, dynamic> toJson() => {
        'op': op.name,
        'id': id,
        'partial': partial == null ? null : partialToJson(partial!),
        'wasCompleted': wasCompleted,
        'scope': scope,
      };

  factory TaskOutboxItem.fromJson(Map<String, dynamic> json) {
    final partialRaw = json['partial'];
    return TaskOutboxItem(
      op: TaskOutboxOp.values.firstWhere(
        (o) => o.name == json['op'],
        orElse: () => TaskOutboxOp.update,
      ),
      id: '${json['id'] ?? ''}',
      partial: partialRaw is Map
          ? partialFromJson(Map<String, dynamic>.from(partialRaw))
          : null,
      wasCompleted: json['wasCompleted'] as bool?,
      scope: json['scope'] as String?,
    );
  }
}

/// Pending task mutations made while offline.
abstract final class TaskOutbox {
  static const _key = 'otter.tasks.outbox.v1';

  static Future<List<TaskOutboxItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [
        for (final item in list)
          if (item is Map)
            TaskOutboxItem.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<TaskOutboxItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final item in items) item.toJson()]),
    );
  }

  static Future<void> enqueue(TaskOutboxItem item) async {
    final items = await load();
    items.add(item);
    await save(items);
  }

  static Future<int> pendingCount() async => (await load()).length;
}
