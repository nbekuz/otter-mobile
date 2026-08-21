import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/network/api_exception.dart';
import '../../core/layout/responsive.dart';
import '../../core/premium/premium_required.dart';
import '../../core/providers/providers.dart';
import '../../shared/widgets/app_toast.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/theme/otter_theme.dart';
import '../../core/theme/priority_colors.dart';
import '../../core/utils/recurrence.dart';
import '../../core/utils/time_utils.dart';
import '../../data/models/ui/ui_models.dart';
import '../../data/services/calendar_service.dart';
import '../tasks/task_detail_sheet.dart';
import 'calendar_task_block.dart';
import 'calendar_timeline.dart';
import 'calendar_grid.dart';

/// Day/week timeline scroll inset — matches web `pb-2`, not a large FAB dead zone.
double _calendarDayWeekScrollBottomPad(BuildContext context) =>
    Responsive.isWide(context) ? 8 : 16;

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
    Future.microtask(() async {
      final hasTasks = ref.read(calendarStateProvider).tasks.isNotEmpty ||
          ref.read(tasksStateProvider).groups.values.any((g) => g.isNotEmpty);
      // Avoid full-screen spinner when returning from new-task with optimistic data.
      final premiumRequired = await ref
          .read(calendarStateProvider.notifier)
          .load(silent: hasTasks);
      _showPremiumRequiredIfNeeded(premiumRequired);
    });
  }

  void _showPremiumRequiredIfNeeded(bool premiumRequired) {
    if (!premiumRequired || !mounted) return;
    showPremiumRequiredModal(context, 'calendar');
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
    final tasks = state.premiumBlocked
        ? const <Task>[]
        : poolCalendarTasks(
            calendarTasks: state.tasks,
            groups: tasksState.groups,
          );
    final date = state.date ?? DateTime.now();
    // Prefer settings.theme — MaterialApp themeMode can lag behind AppShell.
    final isDark =
        ref.watch(appSettingsProvider.select((s) => s.theme == 'dark'));

    return Theme(
      data: isDark ? OtterTheme.dark() : OtterTheme.light(),
      child: Scaffold(
        backgroundColor: OtterColors.pageBg(isDark),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
            _Header(
              state: state,
              date: date,
              onToday: () async {
                final premium = await ref
                    .read(calendarStateProvider.notifier)
                    .goToday();
                _showPremiumRequiredIfNeeded(premium);
              },
              onPrev: () async {
                final premium = await ref
                    .read(calendarStateProvider.notifier)
                    .navigate(-1);
                _showPremiumRequiredIfNeeded(premium);
              },
              onNext: () async {
                final premium = await ref
                    .read(calendarStateProvider.notifier)
                    .navigate(1);
                _showPremiumRequiredIfNeeded(premium);
              },
              onSetView: (v) async {
                final premium =
                    await ref.read(calendarStateProvider.notifier).setView(v);
                _showPremiumRequiredIfNeeded(premium);
              },
              onPickDate: (d) async {
                final premium = await ref
                    .read(calendarStateProvider.notifier)
                    .load(date: d);
                _showPremiumRequiredIfNeeded(premium);
              },
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
                        onMoveToUntimed: (task, dueDate) async {
                          try {
                            await ref
                                .read(calendarStateProvider.notifier)
                                .moveTaskToUntimed(task, dueDate);
                          } catch (e) {
                            if (context.mounted) {
                              showAppToast(
                                context,
                                getApiErrorMessage(
                                  e,
                                  'Не удалось сохранить задачу',
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
                        onMoveTask: (task, dueDate) async {
                          try {
                            await ref
                                .read(calendarStateProvider.notifier)
                                .moveTaskToDate(task, dueDate);
                          } catch (e) {
                            if (context.mounted) {
                              showAppToast(
                                context,
                                getApiErrorMessage(
                                  e,
                                  'Не удалось перенести задачу',
                                ),
                              );
                            }
                          }
                        },
                      ),
                      CalendarView.year => _YearView(
                        date: date,
                        tasks: tasks,
                        onMonthTap: (monthIndex) async {
                          final d = DateTime(date.year, monthIndex + 1, 1);
                          final premium = await ref
                              .read(calendarStateProvider.notifier)
                              .load(
                                view: CalendarView.month,
                                date: d,
                              );
                          _showPremiumRequiredIfNeeded(premium);
                        },
                        onDayTap: (d) async {
                          final premium = await ref
                              .read(calendarStateProvider.notifier)
                              .load(view: CalendarView.day, date: d);
                          _showPremiumRequiredIfNeeded(premium);
                        },
                      ),
                    },
            ),
          ],
        ),
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
    final isDark =
        ref.watch(appSettingsProvider.select((s) => s.theme == 'dark'));
    final surface = OtterColors.surface(isDark);
    final chipBg = OtterColors.surfaceAlt(isDark);

    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
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
                        fontWeight: FontWeight.w800,
                        color: OtterColors.text(isDark),
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
                          color: OtterColors.muted(isDark),
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
                  foregroundColor: OtterColors.muted(isDark),
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
                  backgroundColor: OtterColors.greenTint(isDark),
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
                  color: OtterColors.muted(isDark),
                ),
                style: IconButton.styleFrom(backgroundColor: chipBg),
                color: OtterColors.surface(isDark),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: onSetView,
                itemBuilder: (context) => CalendarView.values.map((v) {
                  final selected = state.view == v;
                  return PopupMenuItem<CalendarView>(
                    value: v,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? OtterColors.sberGreen
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _viewLabel(v),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : OtterColors.text(isDark),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(LucideIcons.chevronLeft),
                style: IconButton.styleFrom(
                  backgroundColor: chipBg,
                  foregroundColor: OtterColors.text(isDark),
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
                            fontWeight: FontWeight.w800,
                            color: OtterColors.text(isDark),
                          ),
                        ),
                      ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(LucideIcons.chevronRight),
                style: IconButton.styleFrom(
                  backgroundColor: chipBg,
                  foregroundColor: OtterColors.text(isDark),
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
    final isDark = OtterColors.isDarkOf(context);
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
                            ? OtterColors.greenTint(isDark)
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
                                  : OtterColors.muted(isDark),
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
                                  : OtterColors.text(isDark),
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

/// Calendar «Без времени» row — same checkbox + strikethrough as timed blocks.
class _UntimedTaskCard extends StatelessWidget {
  const _UntimedTaskCard({
    required this.task,
    required this.isDark,
    required this.onTap,
    required this.onToggleComplete,
    this.dense = false,
  });

  final Task task;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(task.priority);
    final boxSize = dense ? 10.0 : 14.0;
    final radius = dense ? 3.0 : 12.0;
    final titleColor = task.completed
        ? OtterColors.muted(isDark)
        : OtterColors.text(isDark);

    return Opacity(
      opacity: task.completed ? 0.45 : 1,
      child: Material(
        color: color.withValues(alpha: dense ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border(
              left: BorderSide(color: color, width: dense ? 2 : 3),
              top: BorderSide(color: color.withValues(alpha: 0.25)),
              right: BorderSide(color: color.withValues(alpha: 0.25)),
              bottom: BorderSide(color: color.withValues(alpha: 0.25)),
            ),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: onToggleComplete,
                borderRadius: BorderRadius.circular(dense ? 4 : 8),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    dense ? 4 : 8,
                    dense ? 2 : 6,
                    dense ? 4 : 6,
                    dense ? 2 : 6,
                  ),
                  child: Container(
                    width: boxSize,
                    height: boxSize,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: color,
                        width: dense ? 1.5 : 2,
                      ),
                      color: task.completed ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(dense ? 2 : 4),
                    ),
                    child: task.completed
                        ? Icon(
                            Icons.check,
                            size: dense ? 7 : 10,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(radius),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      dense ? 1 : 6,
                      dense ? 4 : 8,
                      dense ? 1 : 6,
                    ),
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: dense ? 10 : 14,
                        fontWeight: FontWeight.w500,
                        height: dense ? 1.2 : null,
                        color: titleColor,
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: titleColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    required bool isDark,
  }) {
    return Material(
      color: OtterColors.elevated(isDark),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: OtterColors.muted(isDark),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(height: 1, color: OtterColors.border(isDark)),
              ),
              const SizedBox(width: 8),
              Icon(
                collapsed ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                size: 16,
                color: OtterColors.muted(isDark),
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
    required bool isDark,
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
                          style: TextStyle(
                            fontSize: 12,
                            color: OtterColors.muted(isDark),
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
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: OtterColors.border(isDark)),
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
    final isDark = OtterColors.isDarkOf(context);
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
            color: OtterColors.surface(isDark),
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
                      Text(
                        'Без времени',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: OtterColors.muted(isDark),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${untimed.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: OtterColors.muted(isDark),
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _UntimedTaskCard(
                          task: task,
                          isDark: isDark,
                          onTap: () => _handleTaskTap(task),
                          onToggleComplete: () =>
                              widget.onToggleComplete(task.id),
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
                  child: SizedBox(
                    height: 16,
                    child: Center(
                      child: SizedBox(
                        width: 40,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: OtterColors.border(isDark),
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
            // Mobile FAB floats over the grid; avoid a large empty strip after 23:00.
            padding: EdgeInsets.only(
              bottom: _calendarDayWeekScrollBottomPad(context),
            ),
            child: ColoredBox(
              // Web day/week grid sits on page bg (no white card).
              color: OtterColors.pageBg(isDark),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hourRows(
                    dayHours,
                    timeline: dayTimeline,
                    nowOffsetPx: nowOffsetPx,
                    isDark: isDark,
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
    required this.onMoveTask,
  });

  final DateTime date;
  final List<Task> tasks;
  final void Function(Task task) onTaskTap;
  final void Function(DateTime day) onDayNumberTap;
  final void Function(DateTime day) onEmptyCellTap;
  final Future<void> Function(Task task, String dueDate) onMoveTask;

  static const _dayHeaderH = 22.0;
  static const _pillSlotH = 18.0;
  static const _overflowH = 14.0;
  static const _cellPadV = 6.0;
  static const _weekdayHeaderH = 18.0;
  static const _headerGap = 6.0;
  static const _rowGap = 2.0;

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    final today = DateTime.now();
    final cells = buildMonthCells(anchor: date, today: today);
    final rowCount = cells.length ~/ 7;
    final wide = Responsive.isWide(context);
    // Desktop: fit all weeks in the viewport like web (no scroll).
    // Mobile: keep a little bottom inset for the FAB when scrolling is needed.
    final topPad = wide ? 8.0 : 8.0;
    final bottomPad = wide ? 8.0 : 100.0;
    final hPad = 4.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chrome =
            topPad + bottomPad + _weekdayHeaderH + _headerGap +
            _rowGap * math.max(0, rowCount - 1);
        final availableH = math.max(0.0, constraints.maxHeight - chrome);
        final fitCellH = rowCount > 0 ? availableH / rowCount : 0.0;
        // Prefer filling the screen; only scroll if rows would be too short to use.
        const minReadableCellH = 72.0;
        final needsScroll = !wide && fitCellH < minReadableCellH;
        final cellH = needsScroll
            ? math.max(fitCellH, minReadableCellH)
            : fitCellH;

        final grid = Column(
          children: [
            SizedBox(
              height: _weekdayHeaderH,
              child: Row(
                children: [
                  for (final label in weekdayHeadersRu)
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: OtterColors.muted(isDark),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: _headerGap),
            if (needsScroll)
              for (var row = 0; row < rowCount; row++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: row < rowCount - 1 ? _rowGap : 0,
                  ),
                  child: _monthRow(
                    cells: cells,
                    row: row,
                    height: cellH,
                  ),
                )
            else
              Expanded(
                child: Column(
                  children: [
                    for (var row = 0; row < rowCount; row++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: row < rowCount - 1 ? _rowGap : 0,
                          ),
                          child: LayoutBuilder(
                            builder: (context, rowConstraints) {
                              return _monthRow(
                                cells: cells,
                                row: row,
                                height: rowConstraints.maxHeight,
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );

        if (needsScroll) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, bottomPad),
            child: grid,
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, bottomPad),
          child: grid,
        );
      },
    );
  }

  Widget _monthRow({
    required List<CalendarMonthCell> cells,
    required int row,
    required double height,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var col = 0; col < 7; col++)
          Expanded(
            child: _MonthCell(
              cell: cells[row * 7 + col],
              height: height,
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
              onMoveTask: onMoveTask,
            ),
          ),
      ],
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
    required this.onMoveTask,
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
  final Future<void> Function(Task task, String dueDate) onMoveTask;

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
    final isDark = OtterColors.isDarkOf(context);
    final day = DateTime.parse(cell.dateKey);
    final visible = _visibleCount(tasks.length);
    final hidden = tasks.length - visible;
    final shown = tasks.take(visible).toList(growable: false);

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) {
        final from = details.data.dueDate;
        return from != cell.dateKey;
      },
      onAcceptWithDetails: (details) {
        onMoveTask(details.data, cell.dateKey);
      },
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return Opacity(
          opacity: cell.isCurrentMonth ? 1 : 0.35,
          child: Material(
            color: highlight
                ? OtterColors.sberGreen.withValues(alpha: 0.08)
                : Colors.transparent,
            child: InkWell(
              onTap: () => onEmptyCellTap(day),
              child: SizedBox(
                height: height,
                child: Padding(
                  padding:
                      EdgeInsets.fromLTRB(2, cellPadV / 2, 2, cellPadV / 2),
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
                                      : OtterColors.text(isDark),
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
                                      color: OtterColors.elevated(isDark),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '+$hidden',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: OtterColors.muted(isDark),
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
      },
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
    final isDark = OtterColors.isDarkOf(context);
    final color = priorityColor(task.priority);
    final chip = Opacity(
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
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.2,
                color: OtterColors.text(isDark),
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Draggable<Task>(
        data: task,
        maxSimultaneousDrags: 1,
        feedback: Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(3),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, maxWidth: 160),
            child: Opacity(opacity: 0.95, child: chip),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: chip),
        child: chip,
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

  static const _yearWeekdayLabels = [
    'пн',
    'вт',
    'ср',
    'чт',
    'пт',
    'сб',
    'вс',
  ];

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
    final wide = Responsive.isWide(context);
    const gap = 8.0;
    final pad = EdgeInsets.fromLTRB(8, 8, 8, wide ? 8 : 100);

    // Desktop: fill viewport with a 3×4 grid (no dead zone under Dec).
    // Mobile: keep scrollable wrap when the screen is too short.
    if (wide) {
      return Padding(
        padding: pad,
        child: Column(
          children: [
            for (var row = 0; row < 4; row++) ...[
              if (row > 0) const SizedBox(height: gap),
              Expanded(
                child: Row(
                  children: [
                    for (var col = 0; col < 3; col++) ...[
                      if (col > 0) const SizedBox(width: gap),
                      Expanded(
                        child: _YearMonthCard(
                          month: months[row * 3 + col],
                          byDate: byDate,
                          weekdayLabels: _yearWeekdayLabels,
                          onMonthTap: onMonthTap,
                          onDayTap: onDayTap,
                          expandDays: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: pad,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardW = (constraints.maxWidth - gap * 2) / 3;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final month in months)
                SizedBox(
                  width: cardW,
                  child: _YearMonthCard(
                    month: month,
                    byDate: byDate,
                    weekdayLabels: _yearWeekdayLabels,
                    onMonthTap: onMonthTap,
                    onDayTap: onDayTap,
                    expandDays: false,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _YearMonthCard extends StatelessWidget {
  const _YearMonthCard({
    required this.month,
    required this.byDate,
    required this.weekdayLabels,
    required this.onMonthTap,
    required this.onDayTap,
    required this.expandDays,
  });

  final CalendarYearMonth month;
  final Map<String, List<Task>> byDate;
  final List<String> weekdayLabels;
  final void Function(int monthIndex) onMonthTap;
  final void Function(DateTime day) onDayTap;
  final bool expandDays;

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    final dayGrid = Column(
      children: [
        for (var row = 0; row < 6; row++)
          expandDays
              ? Expanded(
                  child: Row(
                    children: [
                      for (var col = 0; col < 7; col++)
                        Expanded(
                          child: _YearDayCell(
                            cell: month.cells[row * 7 + col],
                            dots: dotsForDate(
                              byDate,
                              month.cells[row * 7 + col].dateKey ?? '',
                              limit: 1,
                            ),
                            onDayTap: onDayTap,
                            expand: true,
                          ),
                        ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: _YearDayCell(
                          cell: month.cells[row * 7 + col],
                          dots: dotsForDate(
                            byDate,
                            month.cells[row * 7 + col].dateKey ?? '',
                            limit: 1,
                          ),
                          onDayTap: onDayTap,
                          expand: false,
                        ),
                      ),
                  ],
                ),
      ],
    );

    return Material(
      color: OtterColors.surface(isDark),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onMonthTap(month.index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(expandDays ? 12 : 8),
          child: Column(
            mainAxisSize: expandDays ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                month.name,
                style: TextStyle(
                  fontSize: expandDays ? 14 : 12,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                  color: OtterColors.text(isDark),
                ),
              ),
              SizedBox(height: expandDays ? 6 : 4),
              Row(
                children: [
                  for (final label in weekdayLabels)
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: expandDays ? 10 : 8,
                          height: 1.0,
                          fontWeight: FontWeight.w600,
                          color: OtterColors.muted(isDark),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: expandDays ? 4 : 2),
              if (expandDays) Expanded(child: dayGrid) else dayGrid,
            ],
          ),
        ),
      ),
    );
  }
}

class _YearDayCell extends StatelessWidget {
  const _YearDayCell({
    required this.cell,
    required this.dots,
    required this.onDayTap,
    this.expand = false,
  });

  final CalendarYearDayCell cell;
  final List<Color> dots;
  final void Function(DateTime day) onDayTap;
  final bool expand;

  static const double _dayDisc = 16;
  static const double _dotsSlot = 5;
  static const double _cellHeight = _dayDisc + _dotsSlot;

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    final day = cell.day;
    final dateKey = cell.dateKey;

    Widget content({
      required double disc,
      required double fontSize,
      required double dotSize,
    }) {
      return InkWell(
        onTap: dateKey == null
            ? null
            : () => onDayTap(DateTime.parse(dateKey)),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            if (day != null)
              Container(
                width: disc,
                height: disc,
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
                    fontSize: fontSize,
                    height: 1.0,
                    fontWeight:
                        cell.isToday ? FontWeight.w600 : FontWeight.w400,
                    color: cell.isToday
                        ? Colors.white
                        : OtterColors.muted(isDark),
                  ),
                ),
              ),
            if (dots.isNotEmpty)
              Positioned(
                top: disc + 1,
                left: 0,
                right: 0,
                height: dotSize,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in dots)
                      Container(
                        width: dotSize,
                        height: dotSize,
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
      );
    }

    if (!expand) {
      // Fixed height + Stack avoids Column sub-pixel RenderFlex overflow.
      return SizedBox(
        height: _cellHeight,
        child: content(disc: _dayDisc, fontSize: 9, dotSize: 4),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final disc = (math.min(w, h * 0.72)).clamp(14.0, 28.0);
        final fontSize = (disc * 0.55).clamp(9.0, 13.0);
        final dotSize = (disc * 0.22).clamp(3.0, 5.0);
        return SizedBox.expand(
          child: content(disc: disc, fontSize: fontSize, dotSize: dotSize),
        );
      },
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
    required this.onMoveToUntimed,
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
  final Future<void> Function(Task task, String dueDate) onMoveToUntimed;

  @override
  State<_WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<_WeekView> {
  static const _hourH = hourHeightPx;
  static const _gutter = weekGutterWidth;

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

  Future<void> _dropOnUntimed(Task task, DateTime day) async {
    _ignoreNextTap = true;
    try {
      await widget.onMoveToUntimed(task, _dayKey(day));
    } catch (_) {
      // Toast shown by parent.
    } finally {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _ignoreNextTap = false;
      });
    }
  }

  Future<void> _dropOnHour(Task task, DateTime day, int hour) async {
    final scheduleStart = taskScheduleStart(
      dueTime: task.dueTime,
      durationStart: task.duration?.start,
    );
    final minutePart = (scheduleStart != null && scheduleStart.isNotEmpty)
        ? parseTimeToMinutes(scheduleStart) % 60
        : 0;
    final nextStart = hour * 60 + minutePart;
    final duration = taskDurationMinutes(
      durationStart: task.duration?.start,
      durationEnd: task.duration?.end,
    );
    final nextEnd = math.min(nextStart + duration, 24 * 60 - 1);
    final end = math.max(nextStart + calendarMinDurationMinutes, nextEnd);
    _ignoreNextTap = true;
    try {
      await widget.onReschedule(
        task,
        nextStart,
        end,
        dueDate: _dayKey(day),
      );
    } catch (_) {
      // Toast shown by parent.
    } finally {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _ignoreNextTap = false;
      });
    }
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
    required bool isDark,
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
                          style: TextStyle(
                            fontSize: 12,
                            color: OtterColors.muted(isDark),
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
                  return DragTarget<Task>(
                    onWillAcceptWithDetails: (_) => true,
                    onAcceptWithDetails: (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box == null || !box.hasSize) {
                        _dropOnHour(details.data, d, hours.first);
                        return;
                      }
                      final local = box.globalToLocal(details.offset);
                      final y = local.dy.clamp(0.0, height - 1);
                      final hourIndex =
                          (y / _hourH).floor().clamp(0, hours.length - 1);
                      _dropOnHour(details.data, d, hours[hourIndex]);
                    },
                    builder: (context, candidate, rejected) {
                      final highlight = candidate.isNotEmpty;
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
                                    decoration: BoxDecoration(
                                      color: highlight
                                          ? OtterColors.sberGreen
                                              .withValues(alpha: 0.06)
                                          : null,
                                      border: Border(
                                        top: BorderSide(
                                          color: OtterColors.border(isDark),
                                        ),
                                        left: BorderSide(
                                          color: OtterColors.border(isDark),
                                        ),
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
                              weekTypography: true,
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
    required bool isDark,
  }) {
    return Material(
      color: OtterColors.elevated(isDark),
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
                  style: TextStyle(
                    fontSize: 10,
                    color: OtterColors.muted(isDark),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Divider(height: 1, color: OtterColors.border(isDark)),
              ),
              const SizedBox(width: 6),
              Icon(
                collapsed ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                size: 16,
                color: OtterColors.muted(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _untimedChip(Task task, {required bool isDark}) {
    final chip = _UntimedTaskCard(
      task: task,
      isDark: isDark,
      dense: true,
      onTap: () => _handleTaskTap(task),
      onToggleComplete: () => widget.onToggleComplete(task.id),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Draggable<Task>(
        data: task,
        maxSimultaneousDrags: 1,
        feedback: Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(3),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, maxWidth: 140),
            child: Opacity(opacity: 0.95, child: chip),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: chip),
        child: chip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
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
          color: OtterColors.pageBg(isDark),
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: OtterColors.muted(isDark),
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
                                      fontWeight: FontWeight.w800,
                                      color: d.year == today.year &&
                                              d.month == today.month &&
                                              d.day == today.day
                                          ? Colors.white
                                          : OtterColors.text(isDark),
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
                      SizedBox(
                        width: _gutter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6, right: 4),
                          child: Text(
                            'Без\nвр.',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: OtterColors.muted(isDark),
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      for (final d in days)
                        Expanded(
                          child: DragTarget<Task>(
                            onWillAcceptWithDetails: (_) => true,
                            onAcceptWithDetails: (details) {
                              _dropOnUntimed(details.data, d);
                            },
                            builder: (context, candidate, rejected) {
                              final key =
                                  DateFormat('yyyy-MM-dd').format(d);
                              final untimed = untimedTasksForDate(
                                expandTasksForDate(widget.tasks, key),
                                dateKey: key,
                              );
                              final highlight = candidate.isNotEmpty;
                              return Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: highlight
                                      ? OtterColors.sberGreen
                                          .withValues(alpha: 0.08)
                                      : null,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: OtterColors.border(isDark),
                                    ),
                                  ),
                                ),
                                child: ListView(
                                  primary: false,
                                  children: [
                                    for (final task in untimed)
                                      _untimedChip(task, isDark: isDark),
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
                  child: SizedBox(
                    height: 16,
                    child: Center(
                      child: SizedBox(
                        width: 40,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: OtterColors.border(isDark),
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
            padding: EdgeInsets.fromLTRB(
              8,
              0,
              8,
              _calendarDayWeekScrollBottomPad(context),
            ),
            child: ColoredBox(
              // Web: transparent over page bg — no bordered surface card.
              color: OtterColors.pageBg(isDark),
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
                              isDark: isDark,
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
