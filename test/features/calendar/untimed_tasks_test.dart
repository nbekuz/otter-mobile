import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/core/utils/recurrence.dart';
import 'package:otter_mobile/data/models/ui/ui_models.dart';
import 'package:otter_mobile/features/calendar/calendar_timeline.dart';

Task _task({
  required String id,
  String? dueDate,
  String? dueTime,
  TaskDuration? duration,
  bool isAllDay = false,
}) =>
    Task(
      id: id,
      title: id,
      priority: Priority.medium,
      completed: false,
      dueDate: dueDate,
      dueTime: dueTime,
      duration: duration,
      isAllDay: isAllDay,
      repeat: RepeatType.none,
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  const dateKey = '2026-07-24';

  test('No Time excludes undated tasks (web getUntimedTasksForDate)', () {
    final pool = [
      _task(id: 'nodate-a'),
      _task(id: 'nodate-b'),
      _task(id: 'dated-untimed', dueDate: dateKey),
      _task(id: 'other-day', dueDate: '2026-07-25'),
      _task(
        id: 'timed',
        dueDate: dateKey,
        dueTime: '10:00',
        duration: const TaskDuration(start: '10:00', end: '11:00'),
      ),
      _task(id: 'all-day', dueDate: dateKey, isAllDay: true),
    ];

    // Same pipeline as calendar day/week: expand → untimed filter.
    final dayTasks = expandTasksForDate(pool, dateKey);
    final untimed = untimedTasksForDate(dayTasks, dateKey: dateKey);

    expect(untimed.map((t) => t.id), ['dated-untimed', 'all-day']);
  });

  test('untimedTasksForDate ignores undated even if passed the full pool', () {
    final pool = [
      _task(id: 'nodate'),
      _task(id: 'on-day', dueDate: dateKey),
    ];
    final untimed = untimedTasksForDate(pool, dateKey: dateKey);
    expect(untimed.map((t) => t.id), ['on-day']);
  });

  test('preserves input ordering', () {
    final dayTasks = [
      _task(id: 'a', dueDate: dateKey),
      _task(id: 'b', dueDate: dateKey, isAllDay: true),
      _task(
        id: 'c',
        dueDate: dateKey,
        dueTime: '09:00',
        duration: const TaskDuration(start: '09:00', end: '10:00'),
      ),
      _task(id: 'd', dueDate: dateKey),
    ];
    final untimed = untimedTasksForDate(dayTasks, dateKey: dateKey);
    expect(untimed.map((t) => t.id), ['a', 'b', 'd']);
  });

  test('completed untimed tasks stay in Без времени so they can be struck through', () {
    final dayTasks = [
      _task(id: 'open', dueDate: dateKey),
      _task(id: 'done', dueDate: dateKey).copyWith(completed: true),
    ];
    final untimed = untimedTasksForDate(dayTasks, dateKey: dateKey);
    expect(untimed.map((t) => t.id), ['open', 'done']);
    expect(untimed.last.completed, isTrue);
  });
}
