import '../models/api/api_models.dart';
import '../models/ui/ui_models.dart';
import '../../core/utils/time_utils.dart';

abstract final class TaskMapper {
  static Task apiToUi(ApiTask task) {
    final dueFields = task.dueAt != null
        ? parseApiWallClock(task.dueAt!)
        : null;
    final startFields = task.startAt != null
        ? parseApiWallClock(task.startAt!)
        : null;
    final endFields = task.endAt != null
        ? parseApiWallClock(task.endAt!)
        : null;
    final scheduleDay = startFields ?? dueFields;
    final firstAttachment =
        task.attachments.isNotEmpty ? task.attachments.first : null;
    final uiAttachments = task.attachments
        .map(
          (a) => TaskAttachmentItem(
            id: a.id,
            name: a.originalName.isNotEmpty
                ? a.originalName
                : (a.fileUrl.split('/').last),
            url: a.fileUrl,
            mimeType: a.contentType.isNotEmpty ? a.contentType : null,
          ),
        )
        .toList();
    // Legacy single image_url without attachments[] entry.
    if (uiAttachments.isEmpty) {
      final legacyUrl = task.imageUrl ?? task.image;
      if (legacyUrl != null && legacyUrl.isNotEmpty) {
        uiAttachments.add(
          TaskAttachmentItem(name: 'Вложение', url: legacyUrl, mimeType: null),
        );
      }
    }
    final baseRepeat = _repeatToUi(task.repeatUnit);
    final hasCustomInterval =
        task.repeatUnit != 'none' && task.repeatInterval > 1;
    final customUnit = task.repeatUnit == 'month' ? 'month' : 'week';

    String? dueTime;
    if (dueFields != null && dueFields.time != '00:00') {
      dueTime = dueFields.time;
    }

    TaskDuration? duration;
    if (startFields != null && endFields != null) {
      duration = TaskDuration(start: startFields.time, end: endFields.time);
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
      completedAt: _completedAtLocalDate(task.completedAt),
      notification: task.reminderOffsetMinutes != null
          ? task.reminderOffsetMinutes.toString()
          : _reminderMinutes(task.dueAt, task.reminderAt),
      repeat: hasCustomInterval ? RepeatType.custom : baseRepeat,
      repeatCustom: hasCustomInterval
          ? RepeatCustom(interval: task.repeatInterval, unit: customUnit)
          : null,
      imageUrl: task.imageUrl ??
          task.image ??
          firstAttachment?.fileUrl,
      attachmentId: firstAttachment?.id,
      attachmentName: firstAttachment?.originalName.isNotEmpty == true
          ? firstAttachment!.originalName
          : null,
      attachmentMimeType: firstAttachment?.contentType.isNotEmpty == true
          ? firstAttachment!.contentType
          : null,
      attachments: uiAttachments,
      isAllDay: task.isAllDay,
      listKey: task.listKey != null
          ? TaskGroupKeyX.fromApi(task.listKey!)
          : null,
      matrixBlock: MatrixBlockX.fromApi(task.matrixBlock),
      seriesId: task.seriesId,
      parentTaskId: task.parentTask?.toString(),
      createdAt: task.createdAt,
    );
  }

  /// Keep the schedule the client just wrote when the API echoes UTC/`Z`.
  /// Uses [Task.copyWith] non-null wins: omitted client fields keep [fromApi].
  static Task preferClientSchedule(Task fromApi, PartialTask client) {
    return fromApi.copyWith(
      dueDate: client.dueDate,
      dueTime: client.dueTime,
      duration: client.duration,
    );
  }

  static String? _completedAtLocalDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static PartialTask mergePartial(Task existing, PartialTask updates) {
    final clearDue = updates.clearDueDate;
    return PartialTask(
      title: updates.title ?? existing.title,
      description: updates.clearDescription
          ? null
          : (updates.description ?? existing.description),
      dueDate: clearDue ? null : (updates.dueDate ?? existing.dueDate),
      dueTime: clearDue || updates.clearDueTime
          ? null
          : (updates.dueTime ?? existing.dueTime),
      duration: clearDue || updates.clearDuration
          ? null
          : (updates.duration ?? existing.duration),
      priority: updates.priority ?? existing.priority,
      completed: updates.completed ?? existing.completed,
      notification: updates.clearNotification
          ? null
          : (updates.notification ?? existing.notification),
      repeat: updates.repeat ?? existing.repeat,
      repeatDays: updates.repeat != null
          ? updates.repeatDays
          : (updates.repeatDays ?? existing.repeatDays),
      repeatCustom: updates.repeat != null
          ? updates.repeatCustom
          : (updates.repeatCustom ?? existing.repeatCustom),
      matrixBlock: updates.matrixBlock ?? existing.matrixBlock,
      imagePath: updates.imagePath,
      imagePaths: updates.imagePaths,
      clearImage: updates.clearImage,
      deleteAttachmentId: updates.deleteAttachmentId,
      deleteAttachmentIds: updates.deleteAttachmentIds,
    );
  }

  static Map<String, dynamic> uiToApiPayload(
    PartialTask task, {
    bool includeMatrixBlock = true,
  }) {
    final dueAt = _buildDueAt(task.dueDate, task.dueTime);
    final startEnd = _buildStartEnd(task.dueDate, task.duration);
    final hasSchedule = dueAt != null || startEnd.$1 != null;
    final offset = !hasSchedule ||
            task.notification == null ||
            task.notification!.isEmpty
        ? null
        : int.tryParse(task.notification!);
    final repeatResolved = _resolveRepeatApi(task);

    return {
      'title': task.title,
      'description': task.description,
      'due_at': dueAt,
      'start_at': startEnd.$1,
      'end_at': startEnd.$2,
      // Prefer offset minutes so backend computes reminder_at in user timezone.
      // Backend rejects reminder_offset_minutes without due_at/start_at.
      if (offset != null) 'reminder_offset_minutes': offset,
      if (offset == null) 'reminder_at': null,
      if (offset == null) 'reminder_offset_minutes': null,
      'repeat_unit': repeatResolved.$1,
      'repeat_interval': repeatResolved.$2,
      'priority': _uiPriorityToApi(task.priority ?? Priority.medium),
      if (includeMatrixBlock)
        'matrix_block':
            (task.matrixBlock ?? MatrixBlock.notUrgentNotImportant).apiValue,
      if (task.completed != null) 'is_completed': task.completed,
    };
  }

  static (String, int) _resolveRepeatApi(PartialTask task) {
    final repeat = task.repeat ?? RepeatType.none;
    if (repeat == RepeatType.custom && task.repeatCustom != null) {
      final unit =
          task.repeatCustom!.unit == 'month' ? 'month' : 'week';
      final interval = task.repeatCustom!.interval.clamp(1, 31);
      return (unit, interval);
    }
    if (repeat != RepeatType.none && task.repeatCustom?.interval != null) {
      return (
        _repeatToApi(repeat),
        task.repeatCustom!.interval.clamp(1, 31),
      );
    }
    return (_repeatToApi(repeat), 1);
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
    if (dueDate == null || dueDate.trim().isEmpty) return null;
    final time = (dueTime == null || dueTime.isEmpty) ? '00:00' : dueTime;
    return toApiDateTime(dueDate, time);
  }

  static (String?, String?) _buildStartEnd(
    String? dueDate,
    TaskDuration? duration,
  ) {
    if (dueDate == null || dueDate.trim().isEmpty || duration == null) {
      return (null, null);
    }
    if (parseTimeToMinutes(duration.end) <=
        parseTimeToMinutes(duration.start)) {
      return (null, null);
    }
    return (
      toApiDateTime(dueDate, duration.start),
      toApiDateTime(dueDate, duration.end),
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
    this.repeatDays,
    this.repeatCustom,
    this.matrixBlock,
    this.imagePath,
    this.imagePaths,
    this.clearImage = false,
    this.clearDueDate = false,
    this.clearDueTime = false,
    this.clearDuration = false,
    this.clearNotification = false,
    this.clearDescription = false,
    this.deleteAttachmentId,
    this.deleteAttachmentIds,
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
  final List<int>? repeatDays;
  final RepeatCustom? repeatCustom;
  final MatrixBlock? matrixBlock;
  final String? imagePath;
  final List<String>? imagePaths;
  final bool clearImage;
  final bool clearDueDate;
  final bool clearDueTime;
  final bool clearDuration;
  final bool clearNotification;
  final bool clearDescription;
  final int? deleteAttachmentId;
  final List<int>? deleteAttachmentIds;

  List<String> get resolvedImagePaths {
    final paths = <String>[
      ...?imagePaths,
      if (imagePath != null && imagePath!.isNotEmpty) imagePath!,
    ];
    return paths.toSet().toList();
  }

  List<int> get resolvedDeleteAttachmentIds {
    final ids = <int>[
      ...?deleteAttachmentIds,
      if (deleteAttachmentId != null) deleteAttachmentId!,
    ];
    return ids.toSet().toList();
  }
}
