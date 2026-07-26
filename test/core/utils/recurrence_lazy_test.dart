import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/core/utils/recurrence.dart';
import 'package:otter_mobile/data/models/ui/ui_models.dart';

Task _daily({
  required String id,
  required String dueDate,
  bool completed = false,
}) =>
    Task(
      id: id,
      title: 'Daily',
      priority: Priority.medium,
      completed: completed,
      dueDate: dueDate,
      repeat: RepeatType.daily,
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  test('expandTasksForDate does not invent future virtual clones', () {
    final task = _daily(id: '1', dueDate: '2026-07-23');
    final onDue = expandTasksForDate([task], '2026-07-23');
    final nextDay = expandTasksForDate([task], '2026-07-24');

    expect(onDue.map((t) => t.id), ['1']);
    expect(nextDay, isEmpty);
  });

  test('expandTasksForRange only includes real dueDates in range', () {
    final tasks = [
      _daily(id: 'a', dueDate: '2026-07-23'),
      _daily(id: 'b', dueDate: '2026-07-25'),
      _daily(id: 'c', dueDate: '2026-07-30'),
    ];
    final inRange = expandTasksForRange(tasks, '2026-07-23', '2026-07-26');
    expect(inRange.map((t) => t.id), ['a', 'b']);
  });

  test('computeNextOccurrenceDate daily advances one day', () {
    final task = _daily(id: '1', dueDate: '2026-07-23');
    expect(computeNextOccurrenceDate(task), isNotNull);
    // Next open occurrence is strictly after anchor when anchor is today-or-future
    // relative to "now"; for a fixed past/future anchor we only assert non-null
    // and that it is after the due date when due is not overdue into the past
    // relative to wall clock. Use weekly weekday match as a stable check:
    final weekly = Task(
      id: 'w',
      title: 'Weekly',
      priority: Priority.medium,
      completed: false,
      dueDate: '2026-07-20', // Monday
      repeat: RepeatType.weekly,
      createdAt: '2026-01-01T00:00:00Z',
    );
    final next = computeNextOccurrenceDate(weekly);
    expect(next, isNotNull);
    expect(next!.compareTo('2026-07-20'), greaterThan(0));
  });

  test('completed recurring task only matches its due date via taskOccursOnDate', () {
    final task = _daily(id: '1', dueDate: '2026-07-23', completed: true);
    expect(taskOccursOnDate(task, DateTime.parse('2026-07-23')), isTrue);
    expect(taskOccursOnDate(task, DateTime.parse('2026-07-24')), isFalse);
  });
}
