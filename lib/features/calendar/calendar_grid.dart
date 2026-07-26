import 'package:flutter/material.dart';

import '../../core/theme/priority_colors.dart';
import '../../core/utils/recurrence.dart';
import '../../data/models/ui/ui_models.dart';

/// Mon-first month cell — port of otter-app `utils/calendar-grid.ts`.
class CalendarMonthCell {
  const CalendarMonthCell({
    required this.dateKey,
    required this.day,
    required this.isCurrentMonth,
    required this.isToday,
  });

  final String dateKey;
  final int day;
  final bool isCurrentMonth;
  final bool isToday;
}

class CalendarYearDayCell {
  const CalendarYearDayCell({
    this.day,
    this.dateKey,
    required this.isToday,
  });

  final int? day;
  final String? dateKey;
  final bool isToday;
}

class CalendarYearMonth {
  const CalendarYearMonth({
    required this.index,
    required this.name,
    required this.cells,
  });

  final int index;
  final String name;
  final List<CalendarYearDayCell> cells;
}

const yearMonthNamesRu = [
  'Янв',
  'Фев',
  'Мар',
  'Апр',
  'Май',
  'Июн',
  'Июл',
  'Авг',
  'Сен',
  'Окт',
  'Ноя',
  'Дек',
];

const weekdayHeadersRu = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

String _fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Mon-first month grid with leading/trailing padding to complete weeks.
List<CalendarMonthCell> buildMonthCells({
  required DateTime anchor,
  required DateTime today,
}) {
  final startOfMonth = DateTime(anchor.year, anchor.month, 1);
  final endOfMonth = DateTime(anchor.year, anchor.month + 1, 0);
  final startDow = (startOfMonth.weekday - 1) % 7; // Mon = 0
  final todayKey = _fmt(_dateOnly(today));

  final cells = <CalendarMonthCell>[];
  for (var i = 0; i < startDow; i++) {
    final day = startOfMonth.subtract(Duration(days: startDow - i));
    final key = _fmt(day);
    cells.add(
      CalendarMonthCell(
        dateKey: key,
        day: day.day,
        isCurrentMonth: false,
        isToday: key == todayKey,
      ),
    );
  }
  for (var i = 1; i <= endOfMonth.day; i++) {
    final day = DateTime(anchor.year, anchor.month, i);
    final key = _fmt(day);
    cells.add(
      CalendarMonthCell(
        dateKey: key,
        day: i,
        isCurrentMonth: true,
        isToday: key == todayKey,
      ),
    );
  }
  while (cells.length % 7 != 0) {
    final last = DateTime.parse(cells.last.dateKey).add(const Duration(days: 1));
    final key = _fmt(last);
    cells.add(
      CalendarMonthCell(
        dateKey: key,
        day: last.day,
        isCurrentMonth: false,
        isToday: key == todayKey,
      ),
    );
  }
  return cells;
}

/// Always 6 weeks (42 cells) so year mini-months share a stable height.
List<CalendarYearDayCell> buildYearMonthCells({
  required int year,
  required int monthIndex,
  required DateTime today,
}) {
  final startOfMonth = DateTime(year, monthIndex + 1, 1);
  final daysInMonth = DateTime(year, monthIndex + 2, 0).day;
  final startDow = (startOfMonth.weekday - 1) % 7;
  final todayKey = _fmt(_dateOnly(today));

  final cells = <CalendarYearDayCell>[];
  for (var j = 0; j < startDow; j++) {
    cells.add(const CalendarYearDayCell(isToday: false));
  }
  for (var j = 1; j <= daysInMonth; j++) {
    final d = DateTime(year, monthIndex + 1, j);
    final key = _fmt(d);
    cells.add(
      CalendarYearDayCell(day: j, dateKey: key, isToday: key == todayKey),
    );
  }
  while (cells.length < 42) {
    cells.add(const CalendarYearDayCell(isToday: false));
  }
  return cells.take(42).toList(growable: false);
}

List<CalendarYearMonth> buildYearMonths({
  required int year,
  required DateTime today,
}) =>
    [
      for (var i = 0; i < 12; i++)
        CalendarYearMonth(
          index: i,
          name: yearMonthNamesRu[i],
          cells: buildYearMonthCells(
            year: year,
            monthIndex: i,
            today: today,
          ),
        ),
    ];

/// Port of otter-app `getMonthCellTasks` — dated tasks only, max 3.
List<Task> monthCellTasks(List<Task> pool, String dateKey, {int limit = 3}) {
  return expandTasksForDate(pool, dateKey)
      .where((t) => t.dueDate != null && t.dueDate!.isNotEmpty)
      .take(limit)
      .toList(growable: false);
}

/// Expand [pool] across [startKey]–[endKey] and group by due date.
Map<String, List<Task>> groupTasksByDate(
  List<Task> pool,
  String startKey,
  String endKey,
) {
  final map = <String, List<Task>>{};
  for (final t in expandTasksForRange(pool, startKey, endKey)) {
    final due = t.dueDate;
    if (due == null || due.isEmpty) continue;
    map.putIfAbsent(due, () => []).add(t);
  }
  return map;
}

/// Priority-colored dots for a date (max 3) from a pre-grouped map.
List<Color> dotsForDate(
  Map<String, List<Task>> byDate,
  String dateKey, {
  int limit = 3,
}) {
  final list = byDate[dateKey];
  if (list == null || list.isEmpty) return const [];
  return [
    for (final t in list.take(limit)) priorityColor(t.priority),
  ];
}

/// Port of otter-app `getDateDots` — priority colors, max 3.
List<Color> dateTaskDots(List<Task> pool, String dateKey, {int limit = 3}) {
  return [
    for (final t in monthCellTasks(pool, dateKey, limit: limit))
      priorityColor(t.priority),
  ];
}
