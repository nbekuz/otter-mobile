import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/core/utils/repeat_weekdays.dart';
import 'package:otter_mobile/data/models/ui/ui_models.dart';

Task _task({
  required String id,
  List<int>? weekdays,
  RepeatType repeat = RepeatType.none,
}) =>
    Task(
      id: id,
      title: 'T',
      priority: Priority.medium,
      completed: false,
      repeat: repeat,
      repeatDays: weekdays,
      repeatCustom: weekdays != null
          ? RepeatCustom(interval: 1, unit: 'week', weekdays: weekdays)
          : null,
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  test('normalizeRepeatWeekdays unique sorted 1..7', () {
    expect(normalizeRepeatWeekdays([5, 1, 1, 8, 0, 3]), [1, 3, 5]);
    expect(normalizeRepeatWeekdays(null), isEmpty);
  });

  test('recurringRepeatFields forces custom when weekdays present', () {
    final source = _task(
      id: '1',
      weekdays: const [2, 4],
      repeat: RepeatType.weekly,
    );
    final fields = recurringRepeatFields(source);
    expect(fields.repeat, RepeatType.custom);
    expect(fields.repeatDays, [2, 4]);
    expect(fields.repeatCustom?.weekdays, [2, 4]);
  });

  test('resolveTaskWeekdays prefers repeatCustom.weekdays', () {
    final task = Task(
      id: '1',
      title: 'T',
      priority: Priority.medium,
      completed: false,
      repeat: RepeatType.custom,
      repeatDays: const [1],
      repeatCustom: const RepeatCustom(
        interval: 1,
        unit: 'week',
        weekdays: [2, 5],
      ),
      createdAt: '2026-01-01T00:00:00Z',
    );
    expect(resolveTaskWeekdays(task), [2, 5]);
  });

  test('plain weekly has no weekdays', () {
    final task = _task(id: '1', repeat: RepeatType.weekly);
    expect(resolveTaskWeekdays(task), isEmpty);
    final fields = recurringRepeatFields(task);
    expect(fields.repeat, RepeatType.weekly);
    expect(fields.repeatDays, isNull);
  });
}
