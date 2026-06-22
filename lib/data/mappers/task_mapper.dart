import '../models/api/api_models.dart';
import '../models/ui/ui_models.dart';
import '../../core/utils/time_utils.dart';

abstract final class TaskMapper {
  static Task apiToUi(ApiTask task) {
    final dueFields =
        task.dueAt != null ? parseApiWallClock(task.dueAt!) : null;
    final startFields =
        task.startAt != null ? parseApiWallClock(task.startAt!) : null;
    final endFields =
        task.endAt != null ? parseApiWallClock(task.endAt!) : null;
    final scheduleDay = startFields ?? dueFields;

    String? dueTime;
    if (dueFields != null && dueFields.time != '00:00') {
      dueTime = dueFields.time;
    }

    TaskDuration? duration;
    if (startFields != null && endFields != null) {
      duration = TaskDuration(
        start: startFields.time,
        end: endFields.time,
      );
    }

    return Task(
      id: task.id.toString(),
      title: task.title,
      description: task.description,
      dueDate: scheduleDay?.date,
      dueTime: dueTime,
      duration: duration,
      priority: _apiPriorityToUi(task.priority),
      completed: task.isCompleted,
      completedAt: task.completedAt != null
          ? DateTime.tryParse(task.completedAt!)?.toIso8601String().split('T').first
          : null,
      notification: _reminderMinutes(task.dueAt, task.reminderAt),
      repeat: _repeatToUi(task.repeatUnit),
      imageUrl: task.image,
      matrixBlock: MatrixBlockX.fromApi(task.matrixBlock),
      createdAt: task.createdAt,
    );
  }

  static PartialTask mergePartial(Task existing, PartialTask updates) {
    return PartialTask(
      title: updates.title ?? existing.title,
      description: updates.description ?? existing.description,
      dueDate: updates.dueDate ?? existing.dueDate,
      dueTime: updates.dueTime ?? existing.dueTime,
      duration: updates.duration ?? existing.duration,
      priority: updates.priority ?? existing.priority,
      completed: updates.completed ?? existing.completed,
      notification: updates.notification ?? existing.notification,
      repeat: updates.repeat ?? existing.repeat,
      matrixBlock: updates.matrixBlock ?? existing.matrixBlock,
    );
  }

  static Map<String, dynamic> uiToApiPayload(PartialTask task) {
    final dueAt = _buildDueAt(task.dueDate, task.dueTime);
    final startEnd = _buildStartEnd(task.dueDate, task.duration);

    return {
      'title': task.title,
      'description': task.description,
      'due_at': dueAt,
      'start_at': startEnd.$1,
      'end_at': startEnd.$2,
      'reminder_at': _buildReminderAt(dueAt, task.notification),
      'repeat_unit': _repeatToApi(task.repeat ?? RepeatType.none),
      'repeat_interval': 1,
      'priority': _uiPriorityToApi(task.priority ?? Priority.medium),
      'matrix_block': (task.matrixBlock ?? MatrixBlock.notUrgentNotImportant)
          .apiValue,
      if (task.completed != null) 'is_completed': task.completed,
    };
  }

  static Priority _apiPriorityToUi(String priority) => switch (priority) {
        'critical' || 'high' => Priority.high,
        'low' => Priority.low,
        'medium' => Priority.medium,
        _ => Priority.medium,
      };

  static String _uiPriorityToApi(Priority priority) => switch (priority) {
        Priority.none => 'medium',
        Priority.high => 'high',
        Priority.low => 'low',
        Priority.medium => 'medium',
      };

  static String? _reminderMinutes(String? dueAt, String? reminderAt) {
    if (dueAt == null || reminderAt == null) return null;
    final due = DateTime.tryParse(dueAt);
    final rem = DateTime.tryParse(reminderAt);
    if (due == null || rem == null) return null;
    final diff = due.difference(rem).inMinutes;
    if (diff < 0) return null;
    return diff.toString();
  }

  static String? _buildDueAt(String? dueDate, String? dueTime) {
    if (dueDate == null) return null;
    final time = dueTime ?? '00:00';
    return DateTime.parse('${dueDate}T$time').toIso8601String();
  }

  static String? _buildReminderAt(String? dueAt, String? notification) {
    if (dueAt == null || notification == null) return null;
    final minutes = int.tryParse(notification);
    if (minutes == null || minutes < 0) return null;
    final due = DateTime.parse(dueAt);
    return due.subtract(Duration(minutes: minutes)).toIso8601String();
  }

  static (String?, String?) _buildStartEnd(
    String? dueDate,
    TaskDuration? duration,
  ) {
    if (dueDate == null || duration == null) return (null, null);
    if (parseTimeToMinutes(duration.end) <= parseTimeToMinutes(duration.start)) {
      return (null, null);
    }
    return (
      DateTime.parse('${dueDate}T${duration.start}').toIso8601String(),
      DateTime.parse('${dueDate}T${duration.end}').toIso8601String(),
    );
  }

  static RepeatType _repeatToUi(String unit) => switch (unit) {
        'day' => RepeatType.daily,
        'week' => RepeatType.weekly,
        'month' => RepeatType.monthly,
        'year' => RepeatType.yearly,
        _ => RepeatType.none,
      };

  static String _repeatToApi(RepeatType repeat) => switch (repeat) {
        RepeatType.daily => 'day',
        RepeatType.weekly => 'week',
        RepeatType.monthly => 'month',
        RepeatType.yearly => 'year',
        RepeatType.custom => 'week',
        RepeatType.none => 'none',
      };
}

class PartialTask {
  PartialTask({
    this.title,
    this.description,
    this.dueDate,
    this.dueTime,
    this.duration,
    this.priority,
    this.completed,
    this.notification,
    this.repeat,
    this.matrixBlock,
  });

  final String? title;
  final String? description;
  final String? dueDate;
  final String? dueTime;
  final TaskDuration? duration;
  final Priority? priority;
  final bool? completed;
  final String? notification;
  final RepeatType? repeat;
  final MatrixBlock? matrixBlock;
}
