import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/data/models/ui/ui_models.dart';
import 'package:otter_mobile/features/calendar/calendar_timeline.dart';

Task _t(String id, String start, String end) => Task(
      id: id,
      title: id,
      priority: Priority.medium,
      completed: false,
      dueDate: '2026-07-24',
      dueTime: start,
      duration: TaskDuration(start: start, end: end),
      repeat: RepeatType.none,
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  test('overlapping tasks get distinct side-by-side columns', () {
    final laid = buildMainTimelineTasks([
      _t('a', '10:00', '11:00'),
      _t('b', '10:30', '11:30'),
      _t('c', '10:15', '10:45'),
    ]);
    expect(laid.length, 3);
    expect(laid.every((t) => t.layoutCols >= 2), isTrue);
    expect(laid.map((t) => t.layoutCol).toSet().length, greaterThan(1));

    // No two overlapping tasks share the same column.
    for (var i = 0; i < laid.length; i++) {
      for (var j = i + 1; j < laid.length; j++) {
        final a = laid[i];
        final b = laid[j];
        final overlaps =
            a.rawStart < b.rawEnd && b.rawStart < a.rawEnd;
        if (overlaps) {
          expect(a.layoutCol, isNot(b.layoutCol));
        }
      }
    }
  });

  test('duplicate task ids still get independent columns', () {
    final laid = buildMainTimelineTasks([
      _t('same', '10:00', '11:00'),
      _t('same', '10:30', '11:30'),
    ]);
    expect(laid.length, 2);
    expect(laid[0].layoutCols, 2);
    expect(laid[1].layoutCols, 2);
    expect(laid[0].layoutCol, isNot(laid[1].layoutCol));
  });

  test('non-overlapping tasks stay full width', () {
    final laid = buildMainTimelineTasks([
      _t('a', '10:00', '11:00'),
      _t('b', '12:00', '13:00'),
    ]);
    expect(laid.every((t) => t.layoutCols == 1 && t.layoutCol == 0), isTrue);
  });

  test('horizontal style matches web CSS calc', () {
    const pad = 4.0;
    const gap = 3.0;
    const cols = 2;
    const col = 1;
    const timelineWidth = 100.0;
    final style = timelineTaskHorizontalStyle(
      layoutCols: cols,
      layoutCol: col,
      timelineWidth: timelineWidth,
      pad: pad,
      gap: gap,
    );
    const innerPx = 2 * pad + gap * (cols - 1);
    const expectedWidth = (timelineWidth - innerPx) / cols;
    const expectedLeft =
        pad + (timelineWidth - innerPx) * col / cols + gap * col;
    expect(style.width, closeTo(expectedWidth, 0.001));
    expect(style.left, closeTo(expectedLeft, 0.001));
  });

  test('assignTimelineOverlapLayout matches web concurrency', () {
    final slots = assignTimelineOverlapLayout([
      (rawStart: 600, rawEnd: 660),
      (rawStart: 630, rawEnd: 690),
      (rawStart: 615, rawEnd: 645),
    ]);
    expect(slots.every((s) => s.cols == 3), isTrue);
    expect(slots.map((s) => s.col).toSet(), {0, 1, 2});
  });
}
