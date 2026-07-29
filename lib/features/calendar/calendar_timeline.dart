import '../../core/utils/time_utils.dart';
import '../../data/models/ui/ui_models.dart';

const earlyHours = [0, 1, 2, 3, 4, 5];
const mainHours = [
  6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
];
const lateHours = [22, 23];
const dayHours = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
  12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
];

const earlyStartMinutes = 0;
const earlyEndMinutes = 6 * 60;
const mainStartMinutes = 6 * 60;
const mainEndMinutes = 22 * 60;
const lateStartMinutes = 22 * 60;
const lateEndMinutes = 24 * 60;
const dayStartMinutes = 0;
const dayEndMinutes = 24 * 60;

const hourHeightPx = 60.0;
const minuteHeightPx = hourHeightPx / 60;
const minVisualDurationMinutes = 15;

const untimedRowPx = 36.0;
const untimedMinPx = 40.0;
const untimedMaxPx = 360.0;
const untimedDefaultPx = untimedRowPx * 3;

/// Matches otter-app week time gutter `w-14` (3.5rem ≈ 56px).
const weekGutterWidth = 56.0;

/// Week timed cards use pad/gap 2 (day uses 4/3).
const weekOverlapPad = 2.0;
const weekOverlapGap = 2.0;

class CalendarDragPreview {
  const CalendarDragPreview({
    required this.taskId,
    required this.start,
    required this.end,
    this.date,
  });

  final String taskId;
  final int start;
  final int end;
  /// Week view target day (`yyyy-MM-dd`) while dragging across columns.
  final String? date;
}

class CalendarTimelineTask {
  CalendarTimelineTask({
    required this.task,
    required this.topPx,
    required this.heightPx,
    required this.labelTime,
    required this.rawStart,
    required this.rawEnd,
    this.layoutCol = 0,
    this.layoutCols = 1,
    this.isContinuation = false,
    this.continuesAfter = false,
  });

  final Task task;
  final double topPx;
  final double heightPx;
  final String labelTime;
  final int rawStart;
  final int rawEnd;
  final int layoutCol;
  final int layoutCols;
  final bool isContinuation;
  final bool continuesAfter;
}

bool intervalsOverlapHalfOpen(int aStart, int aEnd, int bStart, int bEnd) =>
    aStart < bEnd && bStart < aEnd;

/// Side-by-side columns for overlapping timed events (Google Calendar style).
/// Port of otter-app `utils/overlap-layout.ts` → `assignTimelineOverlapLayout`.
/// Returns one slot per input segment (same order) — index-based to avoid id collisions.
List<({int col, int cols})> assignTimelineOverlapLayout(
  List<({int rawStart, int rawEnd})> segments,
) {
  final n = segments.length;
  final result = List<({int col, int cols})>.generate(
    n,
    (_) => (col: 0, cols: 1),
  );
  if (n == 0) return result;

  final visited = List.filled(n, false);

  for (var startIdx = 0; startIdx < n; startIdx++) {
    if (visited[startIdx]) continue;

    final stack = <int>[startIdx];
    visited[startIdx] = true;
    final comp = <int>[];

    while (stack.isNotEmpty) {
      final u = stack.removeLast();
      comp.add(u);
      for (var v = 0; v < n; v++) {
        if (visited[v]) continue;
        if (intervalsOverlapHalfOpen(
          segments[u].rawStart,
          segments[u].rawEnd,
          segments[v].rawStart,
          segments[v].rawEnd,
        )) {
          visited[v] = true;
          stack.add(v);
        }
      }
    }

    final endpoints = <({int t, int d})>[];
    for (final idx in comp) {
      final s = segments[idx];
      endpoints.add((t: s.rawStart, d: 1));
      endpoints.add((t: s.rawEnd, d: -1));
    }
    endpoints.sort((a, b) {
      if (a.t != b.t) return a.t.compareTo(b.t);
      return a.d.compareTo(b.d);
    });

    var sweep = 0;
    var maxConc = 0;
    for (final e in endpoints) {
      sweep += e.d;
      if (sweep > maxConc) maxConc = sweep;
    }
    final cols = maxConc < 1 ? 1 : maxConc;

    final sortedIdx = [...comp]
      ..sort((ai, bi) {
        final a = segments[ai];
        final b = segments[bi];
        if (a.rawStart != b.rawStart) {
          return a.rawStart.compareTo(b.rawStart);
        }
        return b.rawEnd.compareTo(a.rawEnd);
      });

    final columnEnds = <int>[];
    for (final idx in sortedIdx) {
      final t = segments[idx];
      var col = columnEnds.indexWhere((end) => end <= t.rawStart);
      if (col == -1) {
        col = columnEnds.length;
        columnEnds.add(t.rawEnd);
      } else {
        columnEnds[col] = t.rawEnd;
      }
      result[idx] = (col: col, cols: cols);
    }
  }

  return result;
}

/// Port of otter-app `timelineTaskHorizontalStyle` (pixel form of the CSS calc).
({double left, double width}) timelineTaskHorizontalStyle({
  required int layoutCols,
  required int layoutCol,
  required double timelineWidth,
  double pad = 4,
  double gap = 3,
}) {
  final cols = layoutCols < 1 ? 1 : layoutCols;
  final col = layoutCol.clamp(0, cols - 1);

  if (cols <= 1) {
    final width = (timelineWidth - 2 * pad).clamp(0.0, timelineWidth);
    return (left: pad, width: width);
  }

  final innerPx = 2 * pad + gap * (cols - 1);
  final width = (timelineWidth - innerPx) / cols;
  final left = pad + (timelineWidth - innerPx) * col / cols + gap * col;
  return (left: left, width: width);
}

List<CalendarTimelineTask> buildSectionTimelineTasks(
  List<Task> tasks, {
  required int rangeStart,
  required int rangeEnd,
  required bool Function(int startHour) hourFilter,
  CalendarDragPreview? dragPreview,
  double pxPerMinute = minuteHeightPx,
  bool markContinuesAfter = true,
}) {
  final base =
      <
        ({
          Task task,
          int rawStart,
          int rawEnd,
          double topPx,
          double heightPx,
          String labelTime,
          bool isContinuation,
          bool continuesAfter,
        })
      >[];

  for (final task in tasks) {
    final scheduleStart = taskScheduleStart(
      dueTime: task.dueTime,
      durationStart: task.duration?.start,
    );
    if (scheduleStart == null || scheduleStart.isEmpty) continue;

    final preview = dragPreview?.taskId == task.id ? dragPreview : null;
    final startMinutes = preview?.start ?? parseTimeToMinutes(scheduleStart);
    final startHour = startMinutes ~/ 60;
    if (!hourFilter(startHour)) continue;

    final durationMinutes = preview != null
        ? (preview.end - preview.start)
        : taskDurationMinutes(
            durationStart: task.duration?.start,
            durationEnd: task.duration?.end,
          );
    final endMinutes = startMinutes + durationMinutes;
    if (endMinutes <= rangeStart || startMinutes >= rangeEnd) continue;

    final clippedStart = startMinutes < rangeStart ? rangeStart : startMinutes;
    final clippedEnd = endMinutes > rangeEnd ? rangeEnd : endMinutes;
    final clippedDuration = (clippedEnd - clippedStart).clamp(
      minVisualDurationMinutes,
      24 * 60,
    );

    final labelTime = preview != null
        ? '${formatMinutesToTime(preview.start)} – ${formatMinutesToTime(preview.end)}'
        : task.duration != null
        ? '${task.duration!.start} – ${task.duration!.end}'
        : scheduleStart;

    base.add((
      task: task,
      rawStart: startMinutes,
      rawEnd: endMinutes,
      topPx: (clippedStart - rangeStart) * pxPerMinute,
      heightPx: clippedDuration * pxPerMinute,
      labelTime: labelTime,
      isContinuation: startMinutes < rangeStart,
      continuesAfter: markContinuesAfter && endMinutes > rangeEnd,
    ));
  }

  final layout = assignTimelineOverlapLayout(
    base.map((e) => (rawStart: e.rawStart, rawEnd: e.rawEnd)).toList(),
  );

  return [
    for (var i = 0; i < base.length; i++)
      CalendarTimelineTask(
        task: base[i].task,
        topPx: base[i].topPx,
        heightPx: base[i].heightPx,
        labelTime: base[i].labelTime,
        rawStart: base[i].rawStart,
        rawEnd: base[i].rawEnd,
        layoutCol: layout[i].col,
        layoutCols: layout[i].cols,
        isContinuation: base[i].isContinuation,
        continuesAfter: base[i].continuesAfter,
      ),
  ];
}

List<CalendarTimelineTask> buildEarlyTimelineTasks(
  List<Task> tasks, {
  CalendarDragPreview? dragPreview,
}) {
  return buildSectionTimelineTasks(
    tasks,
    rangeStart: earlyStartMinutes,
    rangeEnd: earlyEndMinutes,
    hourFilter: (h) => h < 6,
    dragPreview: dragPreview,
  );
}

List<CalendarTimelineTask> buildLateTimelineTasks(
  List<Task> tasks, {
  CalendarDragPreview? dragPreview,
}) {
  return buildSectionTimelineTasks(
    tasks,
    rangeStart: lateStartMinutes,
    rangeEnd: lateEndMinutes,
    hourFilter: (h) => h >= 22,
    dragPreview: dragPreview,
  );
}

/// Full-day band 00:00–24:00 (no early/late split).
List<CalendarTimelineTask> buildDayTimelineTasks(
  List<Task> tasks, {
  CalendarDragPreview? dragPreview,
}) {
  return buildSectionTimelineTasks(
    tasks,
    rangeStart: dayStartMinutes,
    rangeEnd: dayEndMinutes,
    hourFilter: (_) => true,
    dragPreview: dragPreview,
    markContinuesAfter: false,
  );
}

/// Main band 06:00–22:00 (matches web `dayTimelineTasks`).
List<CalendarTimelineTask> buildMainTimelineTasks(
  List<Task> tasks, {
  CalendarDragPreview? dragPreview,
}) {
  return buildSectionTimelineTasks(
    tasks,
    rangeStart: mainStartMinutes,
    rangeEnd: mainEndMinutes,
    hourFilter: (_) => true,
    dragPreview: dragPreview,
    markContinuesAfter: false,
  );
}

List<int> visibleWeekHours({
  required bool collapsedEarly,
  required bool collapsedLate,
}) => [
  if (!collapsedEarly) ...earlyHours,
  ...mainHours,
  if (!collapsedLate) ...lateHours,
];

double weekMinutesToPx(
  int min, {
  required List<int> hours,
}) {
  if (hours.isEmpty) return 0;
  final firstMin = hours.first * 60;
  final lastMin = (hours.last + 1) * 60;
  final totalPx = hours.length * hourHeightPx;
  if (min <= firstMin) return 0;
  if (min >= lastMin) return totalPx;

  final hour = min ~/ 60;
  final idx = hours.indexOf(hour);
  if (idx < 0) {
    return hour < mainHours.first ? 0 : totalPx;
  }
  return idx * hourHeightPx + (min - hour * 60) * minuteHeightPx;
}

List<CalendarTimelineTask> buildWeekTimelineTasks(
  List<Task> tasks, {
  required List<int> visibleHours,
  CalendarDragPreview? dragPreview,
}) {
  if (visibleHours.isEmpty) return const [];

  final firstMin = visibleHours.first * 60;
  final lastMin = (visibleHours.last + 1) * 60;

  final base =
      <
        ({
          Task task,
          int rawStart,
          int rawEnd,
          double topPx,
          double heightPx,
          String labelTime,
        })
      >[];

  for (final task in tasks) {
    final scheduleStart = taskScheduleStart(
      dueTime: task.dueTime,
      durationStart: task.duration?.start,
    );
    if (scheduleStart == null || scheduleStart.isEmpty) continue;

    final preview = dragPreview?.taskId == task.id ? dragPreview : null;
    final startMinutes = preview?.start ?? parseTimeToMinutes(scheduleStart);
    final durationMinutes = preview != null
        ? (preview.end - preview.start)
        : taskDurationMinutes(
            durationStart: task.duration?.start,
            durationEnd: task.duration?.end,
          );
    final endMinutes = startMinutes + durationMinutes;

    // Skip tasks that fall entirely inside a collapsed section.
    if (endMinutes <= firstMin || startMinutes >= lastMin) continue;

    final topPx = weekMinutesToPx(startMinutes, hours: visibleHours);
    final bottomPx = weekMinutesToPx(endMinutes, hours: visibleHours);
    final heightPx = (bottomPx - topPx).clamp(hourHeightPx * 0.35, double.infinity);

    final labelTime = preview != null
        ? '${formatMinutesToTime(preview.start)} – ${formatMinutesToTime(preview.end)}'
        : task.duration != null
        ? '${task.duration!.start} – ${task.duration!.end}'
        : scheduleStart;

    base.add((
      task: task,
      rawStart: startMinutes,
      rawEnd: endMinutes,
      topPx: topPx,
      heightPx: heightPx,
      labelTime: labelTime,
    ));
  }

  final layout = assignTimelineOverlapLayout(
    base.map((e) => (rawStart: e.rawStart, rawEnd: e.rawEnd)).toList(),
  );

  return [
    for (var i = 0; i < base.length; i++)
      CalendarTimelineTask(
        task: base[i].task,
        topPx: base[i].topPx,
        heightPx: base[i].heightPx,
        labelTime: base[i].labelTime,
        rawStart: base[i].rawStart,
        rawEnd: base[i].rawEnd,
        layoutCol: layout[i].col,
        layoutCols: layout[i].cols,
      ),
  ];
}

/// Port of otter-app `getUntimedTasksForDate`.
///
/// Web: `getTasksForDate(date).filter(t => t.isAllDay || (!getTaskScheduleStart(t) && !!t.dueDate))`.
/// Call with [expandTasksForDate] output (or any list already scoped to [dateKey]).
/// Tasks with no date (`dueDate` null/empty) never qualify — matching `!!t.dueDate`.
List<Task> untimedTasksForDate(List<Task> tasks, {required String dateKey}) {
  return [
    for (final t in tasks)
      if (_isUntimedForSelectedDate(t, dateKey)) t,
  ];
}

bool _isUntimedForSelectedDate(Task t, String dateKey) {
  final due = t.dueDate;
  // Selected day only; undated / other days must not appear in "Без времени".
  if (due == null || due.isEmpty || due != dateKey) return false;
  if (t.isAllDay) return true;
  final start = taskScheduleStart(
    dueTime: t.dueTime,
    durationStart: t.duration?.start,
  );
  return start == null || start.isEmpty;
}

int clampMoveStart(int start, int duration) {
  const min = 0;
  final max = 24 * 60 - duration;
  return start.clamp(min, max);
}

bool calendarHasEarlyTasks(List<Task> tasks) {
  for (final task in tasks) {
    final start = taskScheduleStart(
      dueTime: task.dueTime,
      durationStart: task.duration?.start,
    );
    if (start == null || start.isEmpty) continue;
    if (parseTimeToMinutes(start) ~/ 60 < 6) return true;
  }
  return false;
}

bool calendarHasLateTasks(List<Task> tasks) {
  for (final task in tasks) {
    final start = taskScheduleStart(
      dueTime: task.dueTime,
      durationStart: task.duration?.start,
    );
    if (start == null || start.isEmpty) continue;
    final hour = parseTimeToMinutes(start) ~/ 60;
    final endHour = task.duration?.end != null
        ? parseTimeToMinutes(task.duration!.end) ~/ 60
        : hour;
    if (hour >= 21 || endHour >= 21) return true;
  }
  return false;
}
