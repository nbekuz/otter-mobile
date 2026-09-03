import '../../data/models/ui/ui_models.dart';

/// Resolve ISO weekdays (1=Mon … 7=Sun) from a UI task.
/// Backend is the source of truth for `repeat_weekdays` — no local cache.
List<int> resolveTaskWeekdays(Task task) {
  if (task.repeatCustom?.weekdays?.isNotEmpty == true) {
    return List<int>.from(task.repeatCustom!.weekdays!);
  }
  if (task.repeatDays?.isNotEmpty == true) {
    return List<int>.from(task.repeatDays!);
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
