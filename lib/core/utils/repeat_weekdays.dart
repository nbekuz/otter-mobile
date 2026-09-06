import '../../data/models/ui/ui_models.dart';

/// ISO weekdays 1=Mon … 7=Sun.
/// Backend is the source of truth for `repeat_weekdays` — no local cache.

/// Unique, sorted, clamped to 1…7 (API validation contract).
List<int> normalizeRepeatWeekdays(Iterable<dynamic>? days) {
  if (days == null) return const [];
  final seen = <int>{};
  final out = <int>[];
  for (final raw in days) {
    final n = raw is int ? raw : int.tryParse('$raw');
    if (n == null || n < 1 || n > 7 || seen.contains(n)) continue;
    seen.add(n);
    out.add(n);
  }
  out.sort();
  return out;
}

/// Resolve ISO weekdays from a UI task.
List<int> resolveTaskWeekdays(Task task) {
  if (task.repeatCustom?.weekdays?.isNotEmpty == true) {
    return normalizeRepeatWeekdays(task.repeatCustom!.weekdays);
  }
  if (task.repeatDays?.isNotEmpty == true) {
    return normalizeRepeatWeekdays(task.repeatDays);
  }
  return const [];
}

/// Repeat fields to send / pin when spawning or finalizing the next occurrence.
({
  RepeatType repeat,
  List<int>? repeatDays,
  RepeatCustom? repeatCustom,
}) recurringRepeatFields(Task source) {
  final weekdays = resolveTaskWeekdays(source);
  if (weekdays.isEmpty) {
    return (
      repeat: source.repeat,
      repeatDays: source.repeatDays,
      repeatCustom: source.repeatCustom,
    );
  }
  return (
    repeat: RepeatType.custom,
    repeatDays: weekdays,
    repeatCustom: RepeatCustom(
      interval: source.repeatCustom?.interval ?? 1,
      unit: source.repeatCustom?.unit ?? 'week',
      weekdays: weekdays,
      monthDay: source.repeatCustom?.monthDay,
    ),
  );
}
