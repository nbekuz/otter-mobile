import 'dart:math' as math;

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
import '../../core/utils/recurrence.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/ui/ui_models.dart';
import '../../data/services/calendar_service.dart';
import '../tasks/task_detail_sheet.dart';
import 'calendar_task_block.dart';
import 'calendar_timeline.dart';
import 'calendar_grid.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      final hasTasks = ref.read(calendarStateProvider).tasks.isNotEmpty ||
          ref.read(tasksStateProvider).groups.values.any((g) => g.isNotEmpty);
      // Avoid full-screen spinner when returning from new-task with optimistic data.
      ref.read(calendarStateProvider.notifier).load(silent: hasTasks);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(calendarStateProvider.notifier).load(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarStateProvider);
    final tasksState = ref.watch(tasksStateProvider);
    // Web getTasksForDate: union grouped tasks + calendar tasks so a just-created
    // task stays visible even if the calendar endpoint is briefly stale.
    final tasks = poolCalendarTasks(
      calendarTasks: state.tasks,
      groups: tasksState.groups,
    );
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
                  : switch (state.view) {
                      CalendarView.day => _DayView(
                        date: date,
                        tasks: tasks,
                        collapsedEarlyHours: state.collapsedEarlyHours,
                        collapsedLateHours: state.collapsedLateHours,
                        onToggleEarlyHours: () => ref
                            .read(calendarStateProvider.notifier)
                            .toggleEarlyHours(),
                        onToggleLateHours: () => ref
                            .read(calendarStateProvider.notifier)
                            .toggleLateHours(),
                        onTaskTap: (t) => showTaskDetailSheet(
                          context,
                          t.id.contains('__')
                              ? t.copyWith(id: resolveRealTaskId(t.id))
                              : t,
                        ),
                        onHourTap: (hour) =>
                            _openNewTaskAtHour(context, date, hour),
                        onToggleComplete: (id) async {
                          final realId = resolveRealTaskId(id);
                          final task = tasks.firstWhere(
                            (t) => resolveRealTaskId(t.id) == realId,
                          );
                          try {
                            await ref
                                .read(tasksStateProvider.notifier)
                                .completeTask(task);
                          } catch (e) {
                            if (context.mounted) {
                              showAppToast(
                                context,
                                getApiErrorMessage(
                                  e,
                                  'Не удалось обновить задачу',
                                ),
                              );
                            }
                          }
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
                      ),
                      CalendarView.week => _WeekView(
                        date: date,
                        tasks: tasks,
                        collapsedEarlyHours: state.collapsedEarlyHours,
                        collapsedLateHours: state.collapsedLateHours,
                        onToggleEarlyHours: () => ref
                            .read(calendarStateProvider.notifier)
                            .toggleEarlyHours(),
                        onToggleLateHours: () => ref
                            .read(calendarStateProvider.notifier)
                            .toggleLateHours(),
                        onTaskTap: (t) => showTaskDetailSheet(
                          context,
                          t.id.contains('__')
                              ? t.copyWith(id: resolveRealTaskId(t.id))
                              : t,
                        ),
                        onDayTap: (d) => ref
                            .read(calendarStateProvider.notifier)
                            .load(view: CalendarView.day, date: d),
                        onHourTap: (d, hour) =>
                            _openNewTaskAtHour(context, d, hour),
                        onToggleComplete: (id) async {
                          final realId = resolveRealTaskId(id);
                          final task = tasks.firstWhere(
                            (t) => resolveRealTaskId(t.id) == realId,
                          );
                          try {
                            await ref
                                .read(tasksStateProvider.notifier)
                                .completeTask(task);
                          } catch (e) {
                            if (context.mounted) {
                              showAppToast(
                                context,
                                getApiErrorMessage(
                                  e,
                                  'Не удалось обновить задачу',
                                ),
                              );
                            }
                          }
                        },
                        onReschedule: (task, start, end, {dueDate}) async {
                          try {
                            await ref
                                .read(calendarStateProvider.notifier)
                                .rescheduleTask(
                                  task,
                                  start,
                                  end,
                                  dueDate: dueDate,
                                );
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
                      ),
                      CalendarView.month => _MonthView(
                        date: date,
                        tasks: tasks,
                        onTaskTap: (t) => showTaskDetailSheet(
                          context,
                          t.id.contains('__')
                              ? t.copyWith(id: resolveRealTaskId(t.id))
                              : t,
                        ),
                        onDayNumberTap: (d) => ref
                            .read(calendarStateProvider.notifier)
                            .load(view: CalendarView.week, date: d),
                        onEmptyCellTap: (d) =>
                            _openNewTaskOnDate(context, d),
                      ),
                      CalendarView.year => _YearView(
                        date: date,
                        tasks: tasks,
                        onMonthTap: (monthIndex) {
                          final d = DateTime(date.year, monthIndex + 1, 1);
                          ref.read(calendarStateProvider.notifier).load(
                                view: CalendarView.month,
                                date: d,
                              );
                        },
                        onDayTap: (d) => ref
                            .read(calendarStateProvider.notifier)
                            .load(view: CalendarView.day, date: d),
                      ),
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _openNewTaskAtHour(BuildContext context, DateTime date, int hour) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final slotStart = '${hour.toString().padLeft(2, '0')}:00';
    final slotEnd = defaultDurationEnd(slotStart);
    final returnTo = Uri.encodeComponent('/app/calendar');
    context.push(
      '/app/new-task?returnTo=$returnTo&dueDate=$dateStr&dueTime=$slotStart&durationStart=$slotStart&durationEnd=$slotEnd',
    );
  }

  void _openNewTaskOnDate(BuildContext context, DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final returnTo = Uri.encodeComponent('/app/calendar');
    context.push(
      '/app/new-task?returnTo=$returnTo&dueDate=$dateStr',
    );
  }
}

class _Header extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isDay = state.view == CalendarView.day;
    final title = state.displayLabel;
    final inbox = ref.watch(notificationsInboxProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? OtterColors.darkSurface : Colors.white;
    final chipBg = isDark ? OtterColors.darkSurfaceAlt : OtterColors.grayLight;

    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _viewLabel(state.view) == 'День'
                          ? 'Календарь'
                          : _viewLabel(state.view),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? OtterColors.darkText
                            : OtterColors.sberBlack,
                      ),
                    ),
                    if (isDay) ...[
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white54
                              : OtterColors.sberGray,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => context.push('/app/notifications'),
                style: IconButton.styleFrom(
                  backgroundColor: chipBg,
                  foregroundColor: isDark
                      ? OtterColors.darkText
                      : OtterColors.sberGray,
                ),
                icon: Badge(
                  isLabelVisible: inbox.unreadCount > 0,
                  smallSize: 8,
                  backgroundColor: Colors.red,
                  child: const Icon(LucideIcons.bell, size: 20),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: onToday,
                style: TextButton.styleFrom(
                  backgroundColor: OtterColors.sberGreenLight,
                  foregroundColor: OtterColors.sberGreen,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Сегодня',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              PopupMenuButton<CalendarView>(
                icon: Icon(
                  LucideIcons.layoutGrid,
                  color: isDark ? OtterColors.darkText : OtterColors.sberGray,
                ),
                style: IconButton.styleFrom(backgroundColor: chipBg),
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
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(LucideIcons.chevronLeft),
                style: IconButton.styleFrom(
                  backgroundColor: chipBg,
                  foregroundColor: isDark
                      ? OtterColors.darkText
                      : OtterColors.sberBlack,
                ),
              ),
              Expanded(
                child: isDay
                    ? _WeekStrip(date: date, onPickDate: onPickDate)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? OtterColors.darkText
                                : OtterColors.sberBlack,
                          ),
                        ),
                      ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(LucideIcons.chevronRight),
                style: IconButton.styleFrom(
                  backgroundColor: chipBg,
                  foregroundColor: isDark
                      ? OtterColors.darkText
                      : OtterColors.sberBlack,
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
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onPickDate(d),
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      height: 52,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? OtterColors.sberGreen
                            : isToday
                            ? OtterColors.sberGreenLight
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('E', 'ru').format(d).substring(0, 1),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : isToday
                                  ? OtterColors.sberGreen
                                  : OtterColors.sberGray,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1,
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
    required this.collapsedEarlyHours,
    required this.collapsedLateHours,
    required this.onToggleEarlyHours,
    required this.onToggleLateHours,
    required this.onTaskTap,
    required this.onHourTap,
    required this.onToggleComplete,
    required this.onReschedule,
  });

  final DateTime date;
  final List<Task> tasks;
  final bool collapsedEarlyHours;
  final bool collapsedLateHours;
  final VoidCallback onToggleEarlyHours;
  final VoidCallback onToggleLateHours;
  final void Function(Task task) onTaskTap;
  final void Function(int hour) onHourTap;
  final Future<void> Function(String id) onToggleComplete;
  final Future<void> Function(Task task, int start, int end) onReschedule;

  @override
  State<_DayView> createState() => _DayViewState();
}

class _DayViewState extends State<_DayView> {
  double _untimedHeight = untimedDefaultPx;
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

    // Keep drag preview until save finishes (matches web) so the block does
    // not snap back to the old slot while the PATCH is in flight.
    _ignoreNextTap = true;
    try {
      await widget.onReschedule(savedTask, savedStart, savedEnd);
    } catch (_) {
      // Toast shown by parent; optimistic state reverted in rescheduleTask.
    } finally {
      if (mounted) {
        setState(() {
          _dragTask = null;
          _dragMode = null;
          _dragPreview = null;
          _didDrag = false;
        });
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

  Widget _hoursToggle({
    required String label,
    required bool collapsed,
    required VoidCallback onTap,
  }) {
    return Material(
      color: OtterColors.grayLight,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: OtterColors.sberGray,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Divider(height: 1, color: OtterColors.grayMid),
              ),
              const SizedBox(width: 8),
              Icon(
                collapsed ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                size: 16,
                color: OtterColors.sberGray,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hourRows(
    List<int> hours, {
    required List<CalendarTimelineTask> timeline,
    double? nowOffsetPx,
  }) {
    final height = hours.length * hourHeightPx;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Column(
            children: hours.map((h) {
              return SizedBox(
                height: hourHeightPx,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, right: 8),
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
                                top: BorderSide(color: Color(0xFFE5E5EA)),
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
          if (nowOffsetPx != null)
            Positioned(
              top: nowOffsetPx,
              left: 56,
              right: 0,
              child: IgnorePointer(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Expanded(
                      child: Divider(height: 2, thickness: 2, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 56,
            right: 0,
            top: 0,
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final timelineWidth = constraints.maxWidth;
                // Paint order matches web zIndex: (dragging ? 35 : 1) + layoutCol
                final items = [...timeline]..sort((a, b) {
                  final az =
                      (_dragPreview?.taskId == a.task.id ? 35 : 1) +
                      a.layoutCol;
                  final bz =
                      (_dragPreview?.taskId == b.task.id ? 35 : 1) +
                      b.layoutCol;
                  return az.compareTo(bz);
                });
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const SizedBox.expand(),
                    ...items.map((item) {
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
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = DateFormat('yyyy-MM-dd').format(widget.date);
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dayTasks = expandTasksForDate(widget.tasks, dateKey);
    final untimed = untimedTasksForDate(dayTasks, dateKey: dateKey);
    final dayTimeline = buildDayTimelineTasks(
      dayTasks,
      dragPreview: _dragPreview,
    );

    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final showNow = dateKey == todayKey;
    final nowOffsetPx = showNow ? nowMinutes * minuteHeightPx : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (untimed.isNotEmpty)
          Material(
            color: Colors.white,
            elevation: 1,
            shadowColor: Colors.black26,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      const Text(
                        'Без времени',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: OtterColors.sberGray,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${untimed.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: OtterColors.sberGray,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: _untimedHeight,
                  child: ListView(
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    children: untimed.map((task) {
                      final color = priorityColor(task.priority);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          onTap: () => _handleTaskTap(task),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                left: BorderSide(color: color, width: 3),
                                top: BorderSide(
                                  color: color.withValues(alpha: 0.25),
                                ),
                                right: BorderSide(
                                  color: color.withValues(alpha: 0.25),
                                ),
                                bottom: BorderSide(
                                  color: color.withValues(alpha: 0.25),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    task.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      _untimedHeight =
                          (_untimedHeight + details.delta.dy).clamp(
                        untimedMinPx,
                        untimedMaxPx,
                      );
                    });
                  },
                  child: const SizedBox(
                    height: 16,
                    child: Center(
                      child: SizedBox(
                        width: 40,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: OtterColors.grayMid,
                            borderRadius:
                                BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            physics: _dragTask != null
                ? const NeverScrollableScrollPhysics()
                : null,
            padding: const EdgeInsets.only(bottom: 100),
            child: ColoredBox(
              color: Colors.white,
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hourRows(
                    dayHours,
                    timeline: dayTimeline,
                    nowOffsetPx: nowOffsetPx,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.date,
    required this.tasks,
    required this.onTaskTap,
    required this.onDayNumberTap,
    required this.onEmptyCellTap,
  });

  final DateTime date;
  final List<Task> tasks;
  final void Function(Task task) onTaskTap;
  final void Function(DateTime day) onDayNumberTap;
  final void Function(DateTime day) onEmptyCellTap;

  static const _dayHeaderH = 22.0;
  static const _pillSlotH = 18.0;
  static const _overflowH = 14.0;
  static const _cellPadV = 6.0;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final cells = buildMonthCells(anchor: date, today: today);

    return LayoutBuilder(
      builder: (context, constraints) {
        final colW = (constraints.maxWidth - 8) / 7;
        // Taller than square so more pills fit (reference month denseness).
        final cellH = math.max(colW * 1.45, 102.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 100),
          child: Column(
            children: [
              Row(
                children: [
                  for (final label in weekdayHeadersRu)
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: OtterColors.sberGray,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (var row = 0; row < cells.length ~/ 7; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var col = 0; col < 7; col++)
                        Expanded(
                          child: _MonthCell(
                            cell: cells[row * 7 + col],
                            height: cellH,
                            tasks: monthCellTasks(
                              tasks,
                              cells[row * 7 + col].dateKey,
                            ),
                            dayHeaderH: _dayHeaderH,
                            pillSlotH: _pillSlotH,
                            overflowH: _overflowH,
                            cellPadV: _cellPadV,
                            onDayNumberTap: onDayNumberTap,
                            onEmptyCellTap: onEmptyCellTap,
                            onTaskTap: onTaskTap,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.cell,
    required this.height,
    required this.tasks,
    required this.dayHeaderH,
    required this.pillSlotH,
    required this.overflowH,
    required this.cellPadV,
    required this.onDayNumberTap,
    required this.onEmptyCellTap,
    required this.onTaskTap,
  });

  final CalendarMonthCell cell;
  final double height;
  final List<Task> tasks;
  final double dayHeaderH;
  final double pillSlotH;
  final double overflowH;
  final double cellPadV;
  final void Function(DateTime day) onDayNumberTap;
  final void Function(DateTime day) onEmptyCellTap;
  final void Function(Task task) onTaskTap;

  int _visibleCount(int total) {
    final body = height - cellPadV - dayHeaderH;
    if (body <= 0 || total <= 0) return 0;
    final maxFit = (body / pillSlotH).floor();
    if (total <= maxFit) return total;
    final withBadge = ((body - overflowH) / pillSlotH).floor();
    return withBadge.clamp(0, total);
  }

  @override
  Widget build(BuildContext context) {
    final day = DateTime.parse(cell.dateKey);
    final visible = _visibleCount(tasks.length);
    final hidden = tasks.length - visible;
    final shown = tasks.take(visible).toList(growable: false);

    return Opacity(
      opacity: cell.isCurrentMonth ? 1 : 0.35,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onEmptyCellTap(day),
          child: SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.fromLTRB(2, cellPadV / 2, 2, cellPadV / 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: dayHeaderH,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: InkWell(
                        onTap: () => onDayNumberTap(day),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cell.isToday
                                ? OtterColors.sberGreen
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${cell.day}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cell.isToday
                                  ? Colors.white
                                  : OtterColors.sberBlack,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final task in shown)
                              SizedBox(
                                height: pillSlotH,
                                child: _MonthTaskChip(
                                  task: task,
                                  onTap: () => onTaskTap(task),
                                ),
                              ),
                          ],
                        ),
                        if (hidden > 0)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: () => onDayNumberTap(day),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: OtterColors.grayLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+$hidden',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: OtterColors.sberGray,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthTaskChip extends StatelessWidget {
  const _MonthTaskChip({
    required this.task,
    required this.onTap,
  });

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(task.priority);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Opacity(
        opacity: task.completed ? 0.45 : 1,
        child: Material(
          color: color.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(3),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: OtterColors.sberBlack,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _YearView extends StatelessWidget {
  const _YearView({
    required this.date,
    required this.tasks,
    required this.onMonthTap,
    required this.onDayTap,
  });

  final DateTime date;
  final List<Task> tasks;
  final void Function(int monthIndex) onMonthTap;
  final void Function(DateTime day) onDayTap;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final months = buildYearMonths(year: date.year, today: today);
    final byDate = groupTasksByDate(
      tasks,
      '${date.year}-01-01',
      '${date.year}-12-31',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 3 columns like web — tighter gaps so month cards fit on phones.
          const gap = 8.0;
          final cardW = (constraints.maxWidth - gap * 2) / 3;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final month in months)
                SizedBox(
                  width: cardW,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => onMonthTap(month.index),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        // Was 12 — reduced so title + 6 week rows fit comfortably.
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              month.name,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.0,
                                fontWeight: FontWeight.w700,
                                color: OtterColors.sberBlack,
                              ),
                            ),
                            // Was 8 — less space under month title.
                            const SizedBox(height: 4),
                            for (var row = 0; row < 6; row++)
                              Row(
                                children: [
                                  for (var col = 0; col < 7; col++)
                                    Expanded(
                                      child: _YearDayCell(
                                        cell: month.cells[row * 7 + col],
                                        dots: dotsForDate(
                                          byDate,
                                          month.cells[row * 7 + col].dateKey ??
                                              '',
                                          limit: 1,
                                        ),
                                        onDayTap: onDayTap,
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _YearDayCell extends StatelessWidget {
  const _YearDayCell({
    required this.cell,
    required this.dots,
    required this.onDayTap,
  });

  final CalendarYearDayCell cell;
  final List<Color> dots;
  final void Function(DateTime day) onDayTap;

  static const double _dayDisc = 16;
  static const double _dotsSlot = 5;
  static const double _cellHeight = _dayDisc + _dotsSlot;

  @override
  Widget build(BuildContext context) {
    final day = cell.day;
    final dateKey = cell.dateKey;

    // Fixed height + Stack avoids Column sub-pixel RenderFlex overflow (~0.97px)
    // that appeared under denser months (e.g. July with task dots).
    return SizedBox(
      height: _cellHeight,
      child: InkWell(
        onTap: dateKey == null
            ? null
            : () => onDayTap(DateTime.parse(dateKey)),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            if (day != null)
              Container(
                width: _dayDisc,
                height: _dayDisc,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cell.isToday
                      ? OtterColors.sberGreen
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$day',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.0,
                    fontWeight:
                        cell.isToday ? FontWeight.w600 : FontWeight.w400,
                    color: cell.isToday
                        ? Colors.white
                        : OtterColors.sberGray,
                  ),
                ),
              ),
            if (dots.isNotEmpty)
              Positioned(
                top: _dayDisc + 1,
                left: 0,
                right: 0,
                height: 4,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in dots)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekView extends StatefulWidget {
  const _WeekView({
    required this.date,
    required this.tasks,
    required this.collapsedEarlyHours,
    required this.collapsedLateHours,
    required this.onToggleEarlyHours,
    required this.onToggleLateHours,
    required this.onTaskTap,
    required this.onDayTap,
    required this.onHourTap,
    required this.onToggleComplete,
    required this.onReschedule,
  });

  final DateTime date;
  final List<Task> tasks;
  final bool collapsedEarlyHours;
  final bool collapsedLateHours;
  final VoidCallback onToggleEarlyHours;
  final VoidCallback onToggleLateHours;
  final void Function(Task task) onTaskTap;
  final void Function(DateTime day) onDayTap;
  final void Function(DateTime day, int hour) onHourTap;
  final Future<void> Function(String id) onToggleComplete;
  final Future<void> Function(
    Task task,
    int start,
    int end, {
    String? dueDate,
  }) onReschedule;

  @override
  State<_WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<_WeekView> {
  static const _hourH = hourHeightPx;
  static const _gutter = weekGutterWidth;
  static const _gridBorder = Color(0xFFC8CFDB);

  double _untimedHeight = untimedDefaultPx;
  CalendarDragPreview? _dragPreview;
  CalendarTimelineTask? _dragTask;
  CalendarTaskDragMode? _dragMode;
  double _dragStartDy = 0;
  double _dragStartDx = 0;
  int _initialStart = 0;
  int _initialEnd = 0;
  DateTime? _sourceDay;
  double _colWidth = 0;
  bool _didDrag = false;
  bool _ignoreNextTap = false;

  String _dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  List<DateTime> _weekDays() {
    final weekStart = widget.date.subtract(
      Duration(days: widget.date.weekday - 1),
    );
    return List.generate(7, (i) => weekStart.add(Duration(days: i)));
  }

  void _beginDrag(
    CalendarTimelineTask item,
    CalendarTaskDragMode mode,
    DateTime day,
  ) {
    setState(() {
      _dragTask = item;
      _dragMode = mode;
      _dragStartDy = 0;
      _dragStartDx = 0;
      _initialStart = item.rawStart;
      _initialEnd = item.rawEnd;
      _sourceDay = DateTime(day.year, day.month, day.day);
      _didDrag = false;
      _dragPreview = CalendarDragPreview(
        taskId: item.task.id,
        start: item.rawStart,
        end: item.rawEnd,
        date: _dayKey(_sourceDay!),
      );
    });
  }

  void _updateDrag(DragUpdateDetails details, CalendarTaskDragMode mode) {
    if (_dragTask == null || _dragMode != mode) return;

    _dragStartDy += details.delta.dy;
    if (mode == CalendarTaskDragMode.move) {
      _dragStartDx += details.delta.dx;
    }
    final deltaMinutes = _dragStartDy / minuteHeightPx;

    if (deltaMinutes.abs() >= 1.5 || _dragStartDx.abs() >= 12) {
      _didDrag = true;
    }

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

    String? nextDate = _sourceDay != null ? _dayKey(_sourceDay!) : null;
    if (mode == CalendarTaskDragMode.move &&
        _sourceDay != null &&
        _colWidth > 0) {
      final days = _weekDays();
      final srcIndex = days.indexWhere(
        (d) =>
            d.year == _sourceDay!.year &&
            d.month == _sourceDay!.month &&
            d.day == _sourceDay!.day,
      );
      if (srcIndex >= 0) {
        final dayDelta = (_dragStartDx / _colWidth).round();
        final nextIndex = (srcIndex + dayDelta).clamp(0, days.length - 1);
        nextDate = _dayKey(days[nextIndex]);
      }
    }

    setState(() {
      _dragPreview = CalendarDragPreview(
        taskId: _dragTask!.task.id,
        start: nextStart,
        end: nextEnd,
        date: nextDate,
      );
    });
  }

  Future<void> _endDrag() async {
    final task = _dragTask;
    final preview = _dragPreview;
    final didDrag = _didDrag;
    final sourceKey = _sourceDay != null ? _dayKey(_sourceDay!) : null;

    if (!didDrag || task == null || preview == null) {
      setState(() {
        _dragTask = null;
        _dragMode = null;
        _dragPreview = null;
        _sourceDay = null;
        _didDrag = false;
      });
      return;
    }

    final dateChanged =
        preview.date != null && sourceKey != null && preview.date != sourceKey;
    if (preview.start == task.rawStart &&
        preview.end == task.rawEnd &&
        !dateChanged) {
      setState(() {
        _dragTask = null;
        _dragMode = null;
        _dragPreview = null;
        _sourceDay = null;
        _didDrag = false;
      });
      return;
    }

    final savedTask = task.task;
    final savedStart = preview.start;
    final savedEnd = preview.end;
    final savedDate = dateChanged ? preview.date : null;

    _ignoreNextTap = true;
    try {
      await widget.onReschedule(
        savedTask,
        savedStart,
        savedEnd,
        dueDate: savedDate,
      );
    } catch (_) {
      // Toast shown by parent; optimistic state reverted in rescheduleTask.
    } finally {
      if (mounted) {
        setState(() {
          _dragTask = null;
          _dragMode = null;
          _dragPreview = null;
          _sourceDay = null;
          _didDrag = false;
        });
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

  List<Task> _timedDayTasks(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    return expandTasksForDate(widget.tasks, key)
        .where(
          (t) =>
              taskScheduleStart(
                dueTime: t.dueTime,
                durationStart: t.duration?.start,
              ) !=
              null,
        )
        .toList();
  }

  Widget _weekHourBlock({
    required List<DateTime> days,
    required List<int> hours,
    required List<CalendarTimelineTask> Function(List<Task> dayTasks)
        buildTimeline,
  }) {
    final height = hours.length * _hourH;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _gutter,
            child: Column(
              children: [
                for (final h in hours)
                  SizedBox(
                    height: _hourH,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, right: 8),
                        child: Text(
                          '${h.toString().padLeft(2, '0')}:00',
                          style: const TextStyle(
                            fontSize: 12,
                            color: OtterColors.sberGray,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final d in days)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final colW = constraints.maxWidth;
                  if (_colWidth != colW && colW > 0) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _colWidth != colW) {
                        setState(() => _colWidth = colW);
                      }
                    });
                  }
                  final dayKey = _dayKey(d);
                  var dayTasks = _timedDayTasks(d);
                  final preview = _dragPreview;
                  if (preview?.date != null && _dragTask != null) {
                    final previewId = resolveRealTaskId(preview!.taskId);
                    if (preview.date != dayKey) {
                      dayTasks = dayTasks
                          .where(
                            (t) => resolveRealTaskId(t.id) != previewId,
                          )
                          .toList();
                    } else if (!dayTasks.any(
                      (t) => resolveRealTaskId(t.id) == previewId,
                    )) {
                      dayTasks = [...dayTasks, _dragTask!.task];
                    }
                  }
                  final timeline = buildTimeline(dayTasks);
                  final items = [...timeline]..sort((a, b) {
                    final az =
                        (_dragPreview?.taskId == a.task.id ? 35 : 1) +
                        a.layoutCol;
                    final bz =
                        (_dragPreview?.taskId == b.task.id ? 35 : 1) +
                        b.layoutCol;
                    return az.compareTo(bz);
                  });
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Column(
                        children: [
                          for (final h in hours)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => widget.onHourTap(d, h),
                              child: Container(
                                height: _hourH,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: _gridBorder),
                                    left: BorderSide(color: _gridBorder),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Absolute overlay — same as web `pointer-events-none absolute inset-0`.
                      ...items.map((item) {
                        final dragging =
                            _dragPreview?.taskId == item.task.id;
                        return CalendarTaskBlock(
                          item: item,
                          timelineWidth: colW,
                          isDragging: dragging,
                          pad: weekOverlapPad,
                          gap: weekOverlapGap,
                          cornerRadius: 4,
                          onTap: () => _handleTaskTap(item.task),
                          onToggleComplete: () =>
                              widget.onToggleComplete(item.task.id),
                          onDragStart: (mode) =>
                              _beginDrag(item, mode, d),
                          onDragUpdate: _updateDrag,
                          onDragEnd: _endDrag,
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _weekHoursToggle({
    required String label,
    required bool collapsed,
    required VoidCallback onTap,
  }) {
    return Material(
      color: OtterColors.grayLight,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: _gutter,
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 10,
                    color: OtterColors.sberGray,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Divider(height: 1, color: OtterColors.grayMid),
              ),
              const SizedBox(width: 6),
              Icon(
                collapsed ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                size: 16,
                color: OtterColors.sberGray,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _untimedChip(Task task) {
    final color = priorityColor(task.priority);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Opacity(
        opacity: task.completed ? 0.45 : 1,
        child: Material(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            onTap: () => widget.onTaskTap(task),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border(
                  left: BorderSide(color: color, width: 3),
                  top: BorderSide(color: color.withValues(alpha: 0.25)),
                  right: BorderSide(color: color.withValues(alpha: 0.25)),
                  bottom: BorderSide(color: color.withValues(alpha: 0.25)),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => widget.onToggleComplete(task.id),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        border: Border.all(color: color, width: 1.2),
                        color: task.completed ? color : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = widget.date.subtract(
      Duration(days: widget.date.weekday - 1),
    );
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final today = DateTime.now();
    final hasUntimed = days.any((d) {
      final key = DateFormat('yyyy-MM-dd').format(d);
      return untimedTasksForDate(
        expandTasksForDate(widget.tasks, key),
        dateKey: key,
      ).isNotEmpty;
    });
    final hours = visibleWeekHours(
      collapsedEarly: false,
      collapsedLate: false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pinned day headers (+ untimed) — matches web sticky week chrome.
        ColoredBox(
          color: OtterColors.grayLight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                child: Row(
                  children: [
                    const SizedBox(width: _gutter),
                    for (final d in days)
                      Expanded(
                        child: InkWell(
                          onTap: () => widget.onDayTap(d),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: [
                                Text(
                                  DateFormat('E', 'ru').format(d).substring(0, 2),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: OtterColors.sberGray,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: d.year == today.year &&
                                            d.month == today.month &&
                                            d.day == today.day
                                        ? OtterColors.sberGreen
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${d.day}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: d.year == today.year &&
                                              d.month == today.month &&
                                              d.day == today.day
                                          ? Colors.white
                                          : OtterColors.sberBlack,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (hasUntimed) ...[
                SizedBox(
                  height: _untimedHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(
                        width: _gutter,
                        child: Padding(
                          padding: EdgeInsets.only(top: 6, right: 4),
                          child: Text(
                            'Без\nвр.',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: OtterColors.sberGray,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      for (final d in days)
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final key =
                                  DateFormat('yyyy-MM-dd').format(d);
                              final untimed = untimedTasksForDate(
                                expandTasksForDate(widget.tasks, key),
                                dateKey: key,
                              );
                              return Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: _gridBorder),
                                  ),
                                ),
                                child: ListView(
                                  primary: false,
                                  children: [
                                    for (final task in untimed)
                                      _untimedChip(task),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      _untimedHeight = (_untimedHeight + details.delta.dy)
                          .clamp(untimedMinPx, untimedMaxPx);
                    });
                  },
                  child: const SizedBox(
                    height: 16,
                    child: Center(
                      child: SizedBox(
                        width: 40,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: OtterColors.grayMid,
                            borderRadius:
                                BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: _dragTask != null
                ? const NeverScrollableScrollPhysics()
                : null,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 100),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _gridBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _weekHourBlock(
                              days: days,
                              hours: hours,
                              buildTimeline: (dayTasks) =>
                                  buildWeekTimelineTasks(
                                dayTasks,
                                visibleHours: hours,
                                dragPreview: _dragPreview,
                              ),
                            ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
