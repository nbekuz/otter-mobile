import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../shared/widgets/app_toast.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/theme/priority_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/ui/ui_models.dart';
import '../../data/services/calendar_service.dart';
import '../tasks/task_detail_sheet.dart';
import 'calendar_task_block.dart';
import 'calendar_timeline.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(calendarStateProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarStateProvider);
    final date = state.date ?? DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? OtterColors.darkBg : OtterColors.grayLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              state: state,
              date: date,
              onToday: () => ref.read(calendarStateProvider.notifier).goToday(),
              onPrev: () =>
                  ref.read(calendarStateProvider.notifier).navigate(-1),
              onNext: () =>
                  ref.read(calendarStateProvider.notifier).navigate(1),
              onSetView: (v) =>
                  ref.read(calendarStateProvider.notifier).setView(v),
              onPickDate: (d) =>
                  ref.read(calendarStateProvider.notifier).load(date: d),
            ),
            Expanded(
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : state.view == CalendarView.day
                  ? _DayView(
                      date: date,
                      tasks: state.tasks,
                      onTaskTap: (t) => showTaskDetailSheet(context, t),
                      onHourTap: (hour) =>
                          _openNewTaskAtHour(context, date, hour),
                      onToggleComplete: (id) async {
                        final task = state.tasks.firstWhere((t) => t.id == id);
                        await ref
                            .read(tasksStateProvider.notifier)
                            .completeTask(task);
                        await ref.read(calendarStateProvider.notifier).load();
                      },
                      onReschedule: (task, start, end) async {
                        try {
                          await ref
                              .read(calendarStateProvider.notifier)
                              .rescheduleTask(task, start, end);
                        } catch (e) {
                          if (context.mounted) {
                            showAppToast(
                              context,
                              getApiErrorMessage(
                                e,
                                'Не удалось сохранить время',
                              ),
                            );
                          }
                          rethrow;
                        }
                      },
                    )
                  : _SimpleListView(
                      tasks: state.tasks,
                      onTaskTap: (t) => showTaskDetailSheet(context, t),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNewTaskAtHour(BuildContext context, DateTime date, int hour) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final slotStart = '${hour.toString().padLeft(2, '0')}:00';
    final slotEnd = addMinutesToTime(slotStart, 60);
    final returnTo = Uri.encodeComponent('/app/calendar');
    context.push(
      '/app/new-task?returnTo=$returnTo&dueDate=$dateStr&dueTime=$slotStart&durationStart=$slotStart&durationEnd=$slotEnd',
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.date,
    required this.onToday,
    required this.onPrev,
    required this.onNext,
    required this.onSetView,
    required this.onPickDate,
  });

  final CalendarUiState state;
  final DateTime date;
  final VoidCallback onToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(CalendarView view) onSetView;
  final void Function(DateTime date) onPickDate;

  @override
  Widget build(BuildContext context) {
    final isDay = state.view == CalendarView.day;
    final title = state.displayLabel;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onToday,
                style: TextButton.styleFrom(
                  backgroundColor: OtterColors.sberGreenLight,
                  foregroundColor: OtterColors.sberGreen,
                ),
                child: const Text('Сегодня', style: TextStyle(fontSize: 12)),
              ),
              PopupMenuButton<CalendarView>(
                icon: const Icon(LucideIcons.layoutGrid),
                onSelected: onSetView,
                itemBuilder: (context) => CalendarView.values
                    .map(
                      (v) =>
                          PopupMenuItem(value: v, child: Text(_viewLabel(v))),
                    )
                    .toList(),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(LucideIcons.chevronLeft),
                style: IconButton.styleFrom(
                  backgroundColor: OtterColors.grayLight,
                ),
              ),
              Expanded(
                child: isDay
                    ? _WeekStrip(date: date, onPickDate: onPickDate)
                    : Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(LucideIcons.chevronRight),
                style: IconButton.styleFrom(
                  backgroundColor: OtterColors.grayLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _viewLabel(CalendarView v) => switch (v) {
    CalendarView.day => 'День',
    CalendarView.week => 'Неделя',
    CalendarView.month => 'Месяц',
    CalendarView.year => 'Год',
  };
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.date, required this.onPickDate});

  final DateTime date;
  final void Function(DateTime date) onPickDate;

  @override
  Widget build(BuildContext context) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    final today = DateTime.now();
    final selectedKey = DateFormat('yyyy-MM-dd').format(date);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: List.generate(7, (i) {
            final d = start.add(Duration(days: i));
            final key = DateFormat('yyyy-MM-dd').format(d);
            final isSelected = key == selectedKey;
            final isToday =
                d.year == today.year &&
                d.month == today.month &&
                d.day == today.day;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => onPickDate(d),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? OtterColors.sberGreen
                          : isToday
                          ? OtterColors.sberGreenLight
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E', 'ru').format(d).substring(0, 1),
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                ? OtterColors.sberGreen
                                : OtterColors.sberGray,
                          ),
                        ),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                ? OtterColors.sberGreen
                                : OtterColors.sberBlack,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _DayView extends StatefulWidget {
  const _DayView({
    required this.date,
    required this.tasks,
    required this.onTaskTap,
    required this.onHourTap,
    required this.onToggleComplete,
    required this.onReschedule,
  });

  final DateTime date;
  final List<Task> tasks;
  final void Function(Task task) onTaskTap;
  final void Function(int hour) onHourTap;
  final Future<void> Function(String id) onToggleComplete;
  final Future<void> Function(Task task, int start, int end) onReschedule;

  @override
  State<_DayView> createState() => _DayViewState();
}

class _DayViewState extends State<_DayView> {
  CalendarDragPreview? _dragPreview;
  CalendarTimelineTask? _dragTask;
  CalendarTaskDragMode? _dragMode;
  double _dragStartDy = 0;
  int _initialStart = 0;
  int _initialEnd = 0;
  bool _didDrag = false;
  bool _ignoreNextTap = false;

  void _beginDrag(CalendarTimelineTask item, CalendarTaskDragMode mode) {
    setState(() {
      _dragTask = item;
      _dragMode = mode;
      _dragStartDy = 0;
      _initialStart = item.rawStart;
      _initialEnd = item.rawEnd;
      _didDrag = false;
      _dragPreview = CalendarDragPreview(
        taskId: item.task.id,
        start: item.rawStart,
        end: item.rawEnd,
      );
    });
  }

  void _updateDrag(DragUpdateDetails details, CalendarTaskDragMode mode) {
    if (_dragTask == null || _dragMode != mode) return;

    _dragStartDy += details.delta.dy;
    final deltaMinutes = _dragStartDy / minuteHeightPx;

    if (deltaMinutes.abs() >= 1.5) _didDrag = true;

    var nextStart = _initialStart;
    var nextEnd = _initialEnd;
    final delta = deltaMinutes.round();

    if (mode == CalendarTaskDragMode.move) {
      final duration = _initialEnd - _initialStart;
      nextStart = snapMinutes(clampMoveStart(_initialStart + delta, duration));
      nextEnd = nextStart + duration;
    } else if (mode == CalendarTaskDragMode.resizeStart) {
      nextStart = snapMinutes(
        (_initialStart + delta).clamp(
          0,
          _initialEnd - calendarMinDurationMinutes,
        ),
      );
    } else {
      nextEnd = snapMinutes(
        (_initialEnd + delta).clamp(
          _initialStart + calendarMinDurationMinutes,
          24 * 60,
        ),
      );
    }

    setState(() {
      _dragPreview = CalendarDragPreview(
        taskId: _dragTask!.task.id,
        start: nextStart,
        end: nextEnd,
      );
    });
  }

  Future<void> _endDrag() async {
    final task = _dragTask;
    final preview = _dragPreview;
    final didDrag = _didDrag;

    if (!didDrag || task == null || preview == null) {
      setState(() {
        _dragTask = null;
        _dragMode = null;
        _dragPreview = null;
        _didDrag = false;
      });
      return;
    }

    if (preview.start == task.rawStart && preview.end == task.rawEnd) {
      setState(() {
        _dragTask = null;
        _dragMode = null;
        _dragPreview = null;
        _didDrag = false;
      });
      return;
    }

    final savedTask = task.task;
    final savedStart = preview.start;
    final savedEnd = preview.end;

    _ignoreNextTap = true;
    final saveFuture = widget.onReschedule(savedTask, savedStart, savedEnd);

    setState(() {
      _dragTask = null;
      _dragMode = null;
      _dragPreview = null;
      _didDrag = false;
    });

    try {
      await saveFuture;
    } catch (_) {
      // Toast shown by parent; optimistic state reverted in rescheduleTask.
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _ignoreNextTap = false;
        });
      }
    }
  }

  void _handleTaskTap(Task task) {
    if (_ignoreNextTap) {
      _ignoreNextTap = false;
      return;
    }
    widget.onTaskTap(task);
  }

  @override
  Widget build(BuildContext context) {
    final untimed = untimedTasksForDate(widget.tasks);
    final timeline = buildDayTimelineTasks(
      widget.tasks,
      dragPreview: _dragPreview,
    );
    final timelineHeight = (mainEndMinutes - mainStartMinutes) * minuteHeightPx;

    return LayoutBuilder(
      builder: (context, constraints) {
        final timelineWidth = constraints.maxWidth - 56;

        return ListView(
          physics: _dragTask != null
              ? const NeverScrollableScrollPhysics()
              : null,
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            if (untimed.isNotEmpty)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: untimed.map((task) {
                    final color = priorityColor(task.priority);
                    return InkWell(
                      onTap: () => widget.onTaskTap(task),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          border: Border.all(
                            color: color.withValues(alpha: 0.35),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            decoration: task.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            Container(
              color: Colors.white,
              child: Stack(
                children: [
                  Column(
                    children: mainHours.map((h) {
                      return SizedBox(
                        height: hourHeightPx,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 56,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  right: 8,
                                ),
                                child: Text(
                                  '${h.toString().padLeft(2, '0')}:00',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: OtterColors.sberGray,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => widget.onHourTap(h),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: Color(0xFFE5E5EA),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  Positioned(
                    left: 56,
                    right: 0,
                    top: 0,
                    height: timelineHeight,
                    child: Stack(
                      children: timeline.map((item) {
                        final dragging = _dragPreview?.taskId == item.task.id;
                        return CalendarTaskBlock(
                          item: item,
                          timelineWidth: timelineWidth,
                          isDragging: dragging,
                          onTap: () => _handleTaskTap(item.task),
                          onToggleComplete: () =>
                              widget.onToggleComplete(item.task.id),
                          onDragStart: (mode) => _beginDrag(item, mode),
                          onDragUpdate: _updateDrag,
                          onDragEnd: _endDrag,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SimpleListView extends StatelessWidget {
  const _SimpleListView({required this.tasks, required this.onTaskTap});

  final List<Task> tasks;
  final void Function(Task task) onTaskTap;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          'Нет задач на этот период',
          style: TextStyle(color: OtterColors.sberGray),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (_, i) {
        final t = tasks[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(t.title),
            subtitle: Text(
              [
                if (t.dueTime != null) t.dueTime,
                if (t.duration != null)
                  '${t.duration!.start}–${t.duration!.end}',
              ].whereType<String>().join(' · '),
            ),
            leading: Icon(
              LucideIcons.circle,
              color: priorityColor(t.priority),
              size: 12,
            ),
            onTap: () => onTaskTap(t),
          ),
        );
      },
    );
  }
}
