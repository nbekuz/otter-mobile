import '../../data/models/ui/ui_models.dart';

bool isRecurringTask(Task task) => task.repeat != RepeatType.none;

int _isoWeekday(DateTime d) => d.weekday; // 1=Mon … 7=Sun

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _matchesCustom(Task task, DateTime day, DateTime anchor) {
  final custom = task.repeatCustom;
  if (custom == null) {
    if (_isoWeekday(day) != _isoWeekday(anchor)) return false;
    return !day.isBefore(anchor);
  }
  final interval = custom.interval < 1 ? 1 : custom.interval;
  if (custom.unit == 'week') {
    final weekdays = custom.weekdays?.isNotEmpty == true
        ? custom.weekdays!
        : (task.repeatDays?.isNotEmpty == true
            ? task.repeatDays!
            : [_isoWeekday(anchor)]);
    if (!weekdays.contains(_isoWeekday(day))) return false;
    final weeks = day.difference(anchor).inDays ~/ 7;
    return weeks >= 0 && weeks % interval == 0;
  }
  final monthDay = custom.monthDay ?? anchor.day;
  final dim = DateTime(day.year, day.month + 1, 0).day;
  final targetDay = monthDay > dim ? dim : monthDay;
  if (day.day != targetDay) return false;
  final months =
      (day.year - anchor.year) * 12 + (day.month - anchor.month);
  return months >= 0 && months % interval == 0;
}

bool taskOccursOnDate(Task task, DateTime date) {
  final dueStr = task.dueDate;
  if (dueStr == null || dueStr.isEmpty) return false;
  final due = DateTime.tryParse(dueStr);
  if (due == null) return false;

  final day = _dateOnly(date);
  final anchor = _dateOnly(due);

  if (task.completed) return day == anchor;
  if (day.isBefore(anchor)) return false;
  if (day == anchor) return true;

  switch (task.repeat) {
    case RepeatType.none:
      return false;
    case RepeatType.daily:
      final interval = task.repeatCustom?.interval ?? 1;
      return day.difference(anchor).inDays % interval == 0;
    case RepeatType.weekly:
      if (_isoWeekday(day) != _isoWeekday(anchor)) return false;
      final weeks = day.difference(anchor).inDays ~/ 7;
      final interval = task.repeatCustom?.interval ?? 1;
      return weeks >= 0 && weeks % interval == 0;
    case RepeatType.monthly:
      final dim = DateTime(day.year, day.month + 1, 0).day;
      final targetDay = anchor.day > dim ? dim : anchor.day;
      if (day.day != targetDay) return false;
      final months =
          (day.year - anchor.year) * 12 + (day.month - anchor.month);
      final interval = task.repeatCustom?.interval ?? 1;
      return months >= 0 && months % interval == 0;
    case RepeatType.yearly:
      if (day.month != anchor.month) return false;
      final dim = DateTime(day.year, day.month + 1, 0).day;
      final targetDay = anchor.day > dim ? dim : anchor.day;
      if (day.day != targetDay) return false;
      final interval = task.repeatCustom?.interval ?? 1;
      return (day.year - anchor.year) % interval == 0;
    case RepeatType.custom:
      return _matchesCustom(task, day, anchor);
  }
}

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Next open occurrence date (yyyy-MM-dd) after the current one.
String? computeNextOccurrenceDate(Task task) {
  if (!isRecurringTask(task)) return null;

  final today = _dateOnly(DateTime.now());
  final parsed = task.dueDate != null ? DateTime.tryParse(task.dueDate!) : null;
  final anchor = parsed != null ? _dateOnly(parsed) : today;
  var cursor = anchor.isBefore(today) ? today : anchor.add(const Duration(days: 1));
  final probe = task.copyWith(completed: false, dueDate: _fmt(anchor));
  final limit = anchor.add(const Duration(days: 365 * 3));

  while (!cursor.isAfter(limit)) {
    if (taskOccursOnDate(probe, cursor)) return _fmt(cursor);
    cursor = cursor.add(const Duration(days: 1));
  }
  return null;
}

/// Port of otter-app: show only real persisted instances on their dueDate.
/// Recurring tasks are NOT virtually expanded onto future dates.
List<Task> expandTasksForDate(List<Task> tasks, String dateStr) {
  return [
    for (final task in tasks)
      if (task.dueDate != null &&
          task.dueDate!.isNotEmpty &&
          task.dueDate == dateStr)
        task,
  ];
}

/// Port of otter-app: filter real tasks whose dueDate falls in [startDate, endDate].
List<Task> expandTasksForRange(
  List<Task> tasks,
  String startDate,
  String endDate,
) {
  final start = DateTime.tryParse(startDate);
  final end = DateTime.tryParse(endDate);
  if (start == null || end == null) return const [];

  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  final seen = <String>{};
  final result = <Task>[];

  for (final task in tasks) {
    final dueStr = task.dueDate;
    if (dueStr == null || dueStr.isEmpty) continue;
    final due = DateTime.tryParse(dueStr);
    if (due == null) continue;
    final day = DateTime(due.year, due.month, due.day);
    if (day.isBefore(startDay) || day.isAfter(endDay)) continue;
    if (!seen.add(task.id)) continue;
    result.add(task);
  }
  return result;
}

String resolveRealTaskId(String taskId) {
  final sep = taskId.indexOf('__');
  if (sep == -1) return taskId;
  final maybeDate = taskId.substring(sep + 2);
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(maybeDate)) {
    return taskId.substring(0, sep);
  }
  return taskId;
}

/// Union of grouped tasks + calendar tasks (web `getTasksForDate` pool).
/// Grouped/main list wins on id collision so a just-created task stays visible
/// even if the calendar endpoint briefly returns a stale list.
List<Task> poolCalendarTasks({
  required List<Task> calendarTasks,
  required Map<TaskGroupKey, List<Task>> groups,
}) {
  final pool = <String, Task>{};
  for (final list in groups.values) {
    for (final t in list) {
      pool[t.id] = t;
    }
  }
  for (final t in calendarTasks) {
    pool.putIfAbsent(t.id, () => t);
  }
  return pool.values.toList(growable: false);
}
