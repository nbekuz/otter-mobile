import '../../core/utils/time_utils.dart';

/// Синхронизация «Время срока» ↔ «Начало»; при смене срока — конец +1 ч.
class TaskTimeSync {
  bool _syncing = false;

  void onDueTimeChanged(
    String? dueTime,
    void Function(String start, String end) apply,
  ) {
    if (_syncing || dueTime == null || dueTime.isEmpty) return;
    _syncing = true;
    apply(dueTime, addMinutesToTime(dueTime, 60));
    _syncing = false;
  }

  void onDurationStartChanged(
    String? start,
    String? currentDueTime,
    String? currentEnd,
    void Function(String dueTime, String end) apply,
  ) {
    if (_syncing) return;
    _syncing = true;
    if (start != null && start.isNotEmpty) {
      final end =
          (currentEnd == null ||
              currentEnd.isEmpty ||
              currentEnd == currentDueTime)
          ? addMinutesToTime(start, 60)
          : currentEnd;
      apply(start, end);
    }
    _syncing = false;
  }
}
