import '../../core/utils/time_utils.dart';
import '../../data/models/ui/ui_models.dart';

const mainHours = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
const mainStartMinutes = 6 * 60;
const mainEndMinutes = 22 * 60;
const hourHeightPx = 60.0;
const minuteHeightPx = hourHeightPx / 60;

class CalendarDragPreview {
  const CalendarDragPreview({
    required this.taskId,
    required this.start,
    required this.end,
  });

  final String taskId;
  final int start;
  final int end;
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
  });

  final Task task;
  final double topPx;
  final double heightPx;
  final String labelTime;
  final int rawStart;
  final int rawEnd;
  final int layoutCol;
  final int layoutCols;
}

bool _intervalsOverlap(int aStart, int aEnd, int bStart, int bEnd) =>
    aStart < bEnd && bStart < aEnd;

Map<String, ({int col, int cols})> _assignOverlapLayout(
  List<({String id, int rawStart, int rawEnd})> segments,
) {
  final layout = <String, ({int col, int cols})>{};
  if (segments.isEmpty) return layout;

  final visited = List.filled(segments.length, false);

  for (var startIdx = 0; startIdx < segments.length; startIdx++) {
    if (visited[startIdx]) continue;

    final stack = <int>[startIdx];
    visited[startIdx] = true;
    final comp = <int>[];

    while (stack.isNotEmpty) {
      final u = stack.removeLast();
      comp.add(u);
      for (var v = 0; v < segments.length; v++) {
        if (visited[v]) continue;
        if (_intervalsOverlap(
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

    final sortedIdx = [...comp]..sort((ai, bi) {
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
      layout[t.id] = (col: col, cols: cols);
    }
  }

  return layout;
}

List<CalendarTimelineTask> buildDayTimelineTasks(
  List<Task> tasks, {
  CalendarDragPreview? dragPreview,
}) {
  final base = <({
    Task task,
    int rawStart,
    int rawEnd,
    double topPx,
    double heightPx,
    String labelTime,
  })>[];

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
    final endMinutes =
        (startMinutes + durationMinutes).clamp(0, mainEndMinutes);
    final clippedStart =
        startMinutes < mainStartMinutes ? mainStartMinutes : startMinutes;
    final clippedDuration = (endMinutes - clippedStart).clamp(15, 24 * 60);

    if (clippedStart >= mainEndMinutes) continue;

    final labelTime = preview != null
        ? '${formatMinutesToTime(preview.start)} – ${formatMinutesToTime(preview.end)}'
        : task.duration != null
            ? '${task.duration!.start} – ${task.duration!.end}'
            : scheduleStart;

    base.add((
      task: task,
      rawStart: startMinutes,
      rawEnd: startMinutes + durationMinutes,
      topPx: (clippedStart - mainStartMinutes) * minuteHeightPx,
      heightPx: clippedDuration * minuteHeightPx,
      labelTime: labelTime,
    ));
  }

  final layout = _assignOverlapLayout(
    base
        .map((e) => (id: e.task.id, rawStart: e.rawStart, rawEnd: e.rawEnd))
        .toList(),
  );

  return base.map((e) {
    final slot = layout[e.task.id] ?? (col: 0, cols: 1);
    return CalendarTimelineTask(
      task: e.task,
      topPx: e.topPx,
      heightPx: e.heightPx,
      labelTime: e.labelTime,
      rawStart: e.rawStart,
      rawEnd: e.rawEnd,
      layoutCol: slot.col,
      layoutCols: slot.cols,
    );
  }).toList();
}

List<Task> untimedTasksForDate(List<Task> tasks) {
  return tasks
      .where(
        (t) =>
            taskScheduleStart(
              dueTime: t.dueTime,
              durationStart: t.duration?.start,
            ) ==
            null,
      )
      .toList();
}

int clampMoveStart(int start, int duration) {
  const min = 0;
  final max = 24 * 60 - duration;
  return start.clamp(min, max);
}
