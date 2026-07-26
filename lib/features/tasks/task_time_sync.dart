import '../../core/utils/time_utils.dart';

/// Синхронизация «Время срока» ↔ «Начало»;
/// конец = начало + 1 час (clamp 23:59), пока пользователь не правил «Конец».
class TaskTimeSync {
  bool _syncing = false;
  bool endManuallyEdited = false;

  void markEndEdited() => endManuallyEdited = true;

  void resetEndEdited() => endManuallyEdited = false;

  /// After loading a task: non-default end is treated as manually set.
  void adoptLoadedDuration(String? start, String? end) {
    if (start != null &&
        start.isNotEmpty &&
        end != null &&
        end.isNotEmpty &&
        !isDefaultDurationEnd(start, end)) {
      endManuallyEdited = true;
    } else {
      endManuallyEdited = false;
    }
  }

  String _endForStart(String start, String? currentEnd) {
    if (endManuallyEdited &&
        currentEnd != null &&
        currentEnd.isNotEmpty) {
      return currentEnd;
    }
    return defaultDurationEnd(start);
  }

  void onDueTimeChanged(
    String? dueTime,
    String? currentEnd,
    void Function(String start, String end) apply,
  ) {
    if (_syncing || dueTime == null || dueTime.isEmpty) return;
    _syncing = true;
    apply(dueTime, _endForStart(dueTime, currentEnd));
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
      apply(start, _endForStart(start, currentEnd));
    }
    _syncing = false;
  }
}
