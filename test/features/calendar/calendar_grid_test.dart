import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/data/models/ui/ui_models.dart';
import 'package:otter_mobile/features/calendar/calendar_grid.dart';

Task _task({
  required String id,
  String? dueDate,
  String? dueTime,
}) =>
    Task(
      id: id,
      title: id,
      priority: Priority.high,
      completed: false,
      dueDate: dueDate,
      dueTime: dueTime,
      repeat: RepeatType.none,
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  group('buildMonthCells', () {
    test('pads to complete weeks Mon-first', () {
      // July 2026 starts on Wednesday
      final cells = buildMonthCells(
        anchor: DateTime(2026, 7, 15),
        today: DateTime(2026, 7, 24),
      );
      expect(cells.length % 7, 0);
      expect(cells.first.isCurrentMonth, isFalse); // June padding
      expect(cells.where((c) => c.isCurrentMonth).length, 31);
      expect(cells.any((c) => c.isToday && c.day == 24), isTrue);
    });
  });

  group('buildYearMonths', () {
    test('each month has 42 cells and named months', () {
      final months = buildYearMonths(
        year: 2026,
        today: DateTime(2026, 7, 24),
      );
      expect(months.length, 12);
      expect(months[0].name, 'Янв');
      expect(months[6].name, 'Июл');
      for (final m in months) {
        expect(m.cells.length, 42);
      }
      final julyToday = months[6].cells.where((c) => c.isToday).toList();
      expect(julyToday.length, 1);
      expect(julyToday.first.day, 24);
    });
  });

  group('monthCellTasks / dateTaskDots', () {
    test('returns all dated tasks by default; dots still capped at 3', () {
      final pool = [
        _task(id: 'a', dueDate: '2026-07-24'),
        _task(id: 'b', dueDate: '2026-07-24', dueTime: '10:00'),
        _task(id: 'c', dueDate: '2026-07-24'),
        _task(id: 'd', dueDate: '2026-07-24'),
        _task(id: 'nodate'),
        _task(id: 'other', dueDate: '2026-07-25'),
      ];
      final cell = monthCellTasks(pool, '2026-07-24');
      expect(cell.map((t) => t.id), ['a', 'b', 'c', 'd']);
      expect(monthCellTasks(pool, '2026-07-24', limit: 3).map((t) => t.id), [
        'a',
        'b',
        'c',
      ]);
      expect(dateTaskDots(pool, '2026-07-24').length, 3);
      expect(dateTaskDots(pool, '2026-07-25').length, 1);
      expect(dateTaskDots(pool, '2026-07-26'), isEmpty);
    });
  });
}
