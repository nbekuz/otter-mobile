import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/data/models/ui/ui_models.dart';
import 'package:otter_mobile/features/calendar/calendar_timeline.dart';

Task _task({
  required String id,
  required String dueDate,
  String? dueTime,
  TaskDuration? duration,
}) =>
    Task(
      id: id,
      title: id,
      priority: Priority.medium,
      completed: false,
      dueDate: dueDate,
      dueTime: dueTime,
      duration: duration,
      repeat: RepeatType.none,
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  group('weekMinutesToPx', () {
    test('maps minutes inside main band when early/late collapsed', () {
      final hours = visibleWeekHours(collapsedEarly: true, collapsedLate: true);
      expect(hours.first, 6);
      expect(hours.last, 21);

      // 06:00 → top of grid
      expect(weekMinutesToPx(6 * 60, hours: hours), 0);
      // 07:30 → 1.5 hours * 60px
      expect(weekMinutesToPx(7 * 60 + 30, hours: hours), 90);
      // before visible → 0
      expect(weekMinutesToPx(3 * 60, hours: hours), 0);
      // after visible → full height
      expect(
        weekMinutesToPx(23 * 60, hours: hours),
        hours.length * hourHeightPx,
      );
    });

    test('includes early hours when expanded', () {
      final hours = visibleWeekHours(collapsedEarly: false, collapsedLate: true);
      expect(hours.first, 0);
      expect(weekMinutesToPx(0, hours: hours), 0);
      expect(weekMinutesToPx(6 * 60, hours: hours), 6 * hourHeightPx);
    });
  });

  group('buildWeekTimelineTasks', () {
    const day = '2026-07-24';

    test('positions timed tasks in their time slots', () {
      final hours = visibleWeekHours(collapsedEarly: true, collapsedLate: true);
      final laid = buildWeekTimelineTasks(
        [
          _task(
            id: 'a',
            dueDate: day,
            dueTime: '10:00',
            duration: const TaskDuration(start: '10:00', end: '11:00'),
          ),
          _task(
            id: 'b',
            dueDate: day,
            dueTime: '13:50',
            duration: const TaskDuration(start: '13:50', end: '14:50'),
          ),
        ],
        visibleHours: hours,
      );

      expect(laid.length, 2);
      expect(laid[0].topPx, weekMinutesToPx(10 * 60, hours: hours));
      expect(laid[0].heightPx, 60);
      expect(laid[1].topPx, weekMinutesToPx(13 * 60 + 50, hours: hours));
      expect(laid[1].heightPx, 60);
    });

    test('skips tasks fully inside collapsed early band', () {
      final hours = visibleWeekHours(collapsedEarly: true, collapsedLate: true);
      final laid = buildWeekTimelineTasks(
        [
          _task(
            id: 'early',
            dueDate: day,
            dueTime: '03:00',
            duration: const TaskDuration(start: '03:00', end: '04:00'),
          ),
          _task(
            id: 'main',
            dueDate: day,
            dueTime: '09:00',
            duration: const TaskDuration(start: '09:00', end: '10:00'),
          ),
        ],
        visibleHours: hours,
      );
      expect(laid.map((t) => t.task.id), ['main']);
    });

    test('side-by-side columns for overlapping tasks', () {
      final hours = visibleWeekHours(collapsedEarly: true, collapsedLate: true);
      final laid = buildWeekTimelineTasks(
        [
          _task(
            id: 'a',
            dueDate: day,
            dueTime: '10:00',
            duration: const TaskDuration(start: '10:00', end: '11:00'),
          ),
          _task(
            id: 'b',
            dueDate: day,
            dueTime: '10:30',
            duration: const TaskDuration(start: '10:30', end: '11:30'),
          ),
        ],
        visibleHours: hours,
      );
      expect(laid.every((t) => t.layoutCols >= 2), isTrue);
      expect(laid[0].layoutCol, isNot(laid[1].layoutCol));
    });

    test('ignores tasks without a schedule start', () {
      final hours = visibleWeekHours(collapsedEarly: true, collapsedLate: true);
      final laid = buildWeekTimelineTasks(
        [
          _task(id: 'untimed', dueDate: day),
          _task(
            id: 'timed',
            dueDate: day,
            dueTime: '08:00',
            duration: const TaskDuration(start: '08:00', end: '09:00'),
          ),
        ],
        visibleHours: hours,
      );
      expect(laid.map((t) => t.task.id), ['timed']);
    });
  });
}
