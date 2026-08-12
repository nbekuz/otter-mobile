import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/layout/responsive.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/theme/priority_colors.dart';
import '../../data/models/ui/ui_models.dart';
import '../../shared/widgets/keyboard_dismisser.dart';
import '../../shared/widgets/task_group.dart';
import '../../shared/widgets/task_item.dart';
import 'task_detail_sheet.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  static const _searchTapGroup = Object();
  static const _allGroupId = 'all';

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _desktopDetailKey = GlobalKey<TaskDetailSheetState>();
  bool _searchVisible = false;
  String _activeGroupId = _allGroupId;
  String? _selectedTaskId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(tasksStateProvider.notifier).loadGrouped();
      ref.read(appSettingsProvider.notifier).load();
      ref.read(notificationsInboxProvider.notifier).fetchUnreadCount();
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchVisible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    final hadQuery = _search.text.isNotEmpty ||
        ref.read(tasksStateProvider).searchQuery.isNotEmpty;
    if (!_searchVisible && !hadQuery) return;

    _search.clear();
    ref.read(tasksStateProvider.notifier).search('');
    _searchFocus.unfocus();
    setState(() => _searchVisible = false);
  }

  void _toggleSearch() {
    if (_searchVisible) {
      _closeSearch();
    } else {
      _openSearch();
    }
  }

  /// Local device time: 05–11 утро, 12–16 день, 17–22 вечер, 23–04 ночь.
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Доброе утро';
    if (hour >= 12 && hour < 17) return 'Добрый день';
    if (hour >= 17 && hour < 23) return 'Добрый вечер';
    return 'Доброй ночи';
  }

  List<_DesktopGroup> _desktopGroups(TasksState state, AppSettings settings) {
    final allTasks = <Task>[
      for (final key in TaskGroupKey.values)
        ...?state.groups[key],
    ];
    // Deduplicate by id while preserving order.
    final seen = <String>{};
    final uniqueAll = <Task>[];
    for (final task in allTasks) {
      if (seen.add(task.id)) uniqueAll.add(task);
    }

    final groups = <_DesktopGroup>[
      _DesktopGroup(
        id: _allGroupId,
        title: 'Все задачи',
        color: const Color(0xFF5856D6),
        tasks: uniqueAll,
      ),
      for (final key in TaskGroupKey.values)
        if (settings.visibleGroups.contains(
          key == TaskGroupKey.nodate ? 'nodate' : key.name,
        ))
          _DesktopGroup(
            id: key == TaskGroupKey.nodate ? 'nodate' : key.name,
            title: key == TaskGroupKey.completed ? 'Готово' : key.titleRu,
            color: taskGroupAccent(key),
            tasks: state.groups[key] ?? const [],
          ),
    ];
    return groups;
  }

  _DesktopGroup? _activeGroup(List<_DesktopGroup> groups) {
    return groups.cast<_DesktopGroup?>().firstWhere(
          (g) => g?.id == _activeGroupId,
          orElse: () => groups.isEmpty ? null : groups.first,
        );
  }

  Task? _selectedTask(TasksState state) {
    final id = _selectedTaskId;
    if (id == null) return null;
    for (final group in state.groups.values) {
      for (final task in group) {
        if (task.id == id) return task;
      }
    }
    for (final task in state.searchResults) {
      if (task.id == id) return task;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasksStateProvider);
    final settings = ref.watch(appSettingsProvider);
    final inbox = ref.watch(notificationsInboxProvider);
    final isDark = settings.theme == 'dark';
    final showingSearch = _searchVisible || state.searchQuery.isNotEmpty;
    final groups = TaskGroupKey.values;
    final wide = Responsive.isWide(context);
    final desktopGroups = _desktopGroups(state, settings);
    final active = _activeGroup(desktopGroups);
    final selected = _selectedTask(state);

    // Keep selection valid when active group changes.
    if (wide &&
        selected != null &&
        active != null &&
        _activeGroupId != _allGroupId &&
        !active.tasks.any((t) => t.id == selected.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedTaskId = null);
      });
    }

    final overdue = state.groups[TaskGroupKey.overdue]?.length ?? 0;
    final today = state.groups[TaskGroupKey.today]?.length ?? 0;
    final tomorrow = state.groups[TaskGroupKey.tomorrow]?.length ?? 0;

    return Scaffold(
      backgroundColor: isDark ? OtterColors.darkBg : OtterColors.grayLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _greeting(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? OtterColors.darkText
                            : OtterColors.sberBlack,
                      ),
                    ),
                  ),
                  if (wide)
                    IconButton(
                      tooltip: 'Обновить',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await ref
                            .read(tasksStateProvider.notifier)
                            .loadGrouped();
                        if (!mounted) return;
                        final err = ref.read(tasksStateProvider).error;
                        if (err != null) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Не удалось обновить задачи: $err',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(LucideIcons.refreshCw, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? OtterColors.darkSurface
                            : Colors.white,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Уведомления',
                    onPressed: () => context.push('/app/notifications'),
                    icon: Badge(
                      isLabelVisible: inbox.unreadCount > 0,
                      label: Text(
                        inbox.unreadCount > 99
                            ? '99+'
                            : '${inbox.unreadCount}',
                      ),
                      child: const Icon(LucideIcons.bell),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? OtterColors.darkSurface
                          : Colors.white,
                    ),
                  ),
                  TapRegion(
                    groupId: _searchTapGroup,
                    child: IconButton(
                      tooltip: 'Поиск',
                      onPressed: _toggleSearch,
                      icon: const Icon(LucideIcons.search),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? OtterColors.darkSurface
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showingSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: TapRegion(
                  groupId: _searchTapGroup,
                  onTapOutside: (_) => _closeSearch(),
                  child: TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    autofocus: true,
                    onChanged: (q) =>
                        ref.read(tasksStateProvider.notifier).search(q),
                    onEditingComplete: () {
                      KeyboardDismisser.dismiss();
                    },
                    decoration: InputDecoration(
                      hintText: 'Поиск задач...',
                      prefixIcon: const Icon(LucideIcons.search, size: 20),
                      suffixIcon: state.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 18),
                              onPressed: () {
                                _search.clear();
                                ref
                                    .read(tasksStateProvider.notifier)
                                    .search('');
                                _searchFocus.requestFocus();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              )
            else if (wide)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: _DesktopGroupChips(
                  groups: desktopGroups,
                  activeId: active?.id ?? _allGroupId,
                  isDark: isDark,
                  onSelect: (id) async {
                    if (id == (active?.id ?? _allGroupId)) return;
                    final canLeave = await _confirmLeaveDesktopDetail();
                    if (!canLeave || !mounted) return;
                    setState(() {
                      _activeGroupId = id;
                      _selectedTaskId = null;
                    });
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: Row(
                  children: [
                    _StatChip(
                      label: 'Просрочено',
                      count: overdue,
                      color: priorityColor(Priority.high),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Сегодня',
                      count: today,
                      color: const Color(0xFFFF9500),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Завтра',
                      count: tomorrow,
                      color: const Color(0xFF007AFF),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: state.loading && state.groups.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(tasksStateProvider.notifier).loadGrouped(),
                      child: wide && !showingSearch
                          ? _DesktopSplitTasks(
                              isDark: isDark,
                              group: active,
                              selectedTask: selected,
                              detailKey: _desktopDetailKey,
                              onSelectTask: _selectDesktopTask,
                              onClearSelection: _clearDesktopSelection,
                              onForceClearSelection: () {
                                setState(() => _selectedTaskId = null);
                              },
                              onComplete: _complete,
                              onDelete: _delete,
                            )
                          : ListView(
                              padding: EdgeInsets.fromLTRB(
                                12,
                                0,
                                12,
                                wide ? 16 : 100,
                              ),
                              children: _buildTaskListChildren(
                                groups: groups,
                                settings: settings,
                                state: state,
                                showingSearch: showingSearch,
                                onComplete: _complete,
                                onDelete: _delete,
                                onOpen: _openDetail,
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _complete(Task task) async {
    await ref.read(tasksStateProvider.notifier).completeTask(task);
  }

  Future<void> _delete(Task task) async {
    if (task.repeat != RepeatType.none) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Удалить повторяющуюся задачу?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Выберите, что именно удалить.',
                  style: TextStyle(fontSize: 13, color: OtterColors.sberGray),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'occurrence'),
                  child: const Text('Удалить только этот повтор'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'series'),
                  child: const Text('Удалить все повторения'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
              ],
            ),
          ),
        ),
      );
      if (choice == 'occurrence') {
        await ref.read(tasksStateProvider.notifier).deleteOccurrence(task);
      } else if (choice == 'series') {
        await ref.read(tasksStateProvider.notifier).deleteSeries(task.id);
      }
      if (_selectedTaskId == task.id) {
        setState(() => _selectedTaskId = null);
      }
      return;
    }
    await ref.read(tasksStateProvider.notifier).deleteTask(task.id);
    if (_selectedTaskId == task.id) {
      setState(() => _selectedTaskId = null);
    }
  }

  Future<bool> _confirmLeaveDesktopDetail() async {
    final state = _desktopDetailKey.currentState;
    if (state == null) return true;
    return state.confirmLeave();
  }

  Future<void> _selectDesktopTask(Task task) async {
    if (_selectedTaskId == task.id) return;
    final canLeave = await _confirmLeaveDesktopDetail();
    if (!canLeave || !mounted) return;
    setState(() => _selectedTaskId = task.id);
  }

  Future<void> _clearDesktopSelection() async {
    if (_selectedTaskId == null) return;
    final canLeave = await _confirmLeaveDesktopDetail();
    if (!canLeave || !mounted) return;
    setState(() => _selectedTaskId = null);
  }

  void _openDetail(Task task) {
    _closeSearch();
    if (Responsive.isWide(context)) {
      // ignore: discarded_futures
      _selectDesktopTask(task);
      return;
    }
    showTaskDetailSheet(context, task);
  }

  List<Widget> _buildTaskListChildren({
    required List<TaskGroupKey> groups,
    required AppSettings settings,
    required TasksState state,
    required bool showingSearch,
    required Future<void> Function(Task) onComplete,
    required Future<void> Function(Task) onDelete,
    required void Function(Task) onOpen,
  }) {
    return [
      if (state.error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Text(state.error!, style: const TextStyle(color: Colors.red)),
              TextButton(
                onPressed: () =>
                    ref.read(tasksStateProvider.notifier).loadGrouped(),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      if (showingSearch && state.searchQuery.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Результаты (${state.searchResults.length})',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OtterColors.sberGray,
            ),
          ),
        ),
        if (state.searchResults.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Ничего не найдено',
                style: TextStyle(color: OtterColors.sberGray),
              ),
            ),
          ),
      ],
      if (showingSearch && state.searchQuery.isNotEmpty)
        ...state.searchResults.map(
          (t) => TaskItem(
            key: ValueKey('search-${t.id}'),
            task: t,
            onComplete: () => onComplete(t),
            onDelete: () => onDelete(t),
            onTap: () => onOpen(t),
          ),
        )
      else
        ..._visibleGroupWidgets(
          groups: groups,
          settings: settings,
          state: state,
          onComplete: onComplete,
          onDelete: onDelete,
          onOpen: onOpen,
        ),
    ];
  }

  List<Widget> _visibleGroupWidgets({
    required List<TaskGroupKey> groups,
    required AppSettings settings,
    required TasksState state,
    required Future<void> Function(Task) onComplete,
    required Future<void> Function(Task) onDelete,
    required void Function(Task) onOpen,
  }) {
    return [
      for (final key in groups)
        if (settings.visibleGroups.contains(
          key == TaskGroupKey.nodate ? 'nodate' : key.name,
        ))
          TaskGroupWidget(
            key: ValueKey('group-${key.name}'),
            title: key.titleRu,
            tasks: state.groups[key] ?? [],
            accentColor: taskGroupAccent(key),
            surfaceColor: taskGroupSurfaceTint(key),
            initiallyExpanded: false,
            onComplete: onComplete,
            onDelete: onDelete,
            onOpen: onOpen,
          ),
    ];
  }
}

class _DesktopGroup {
  const _DesktopGroup({
    required this.id,
    required this.title,
    required this.color,
    required this.tasks,
  });

  final String id;
  final String title;
  final Color color;
  final List<Task> tasks;
}

class _DesktopGroupChips extends StatelessWidget {
  const _DesktopGroupChips({
    required this.groups,
    required this.activeId,
    required this.isDark,
    required this.onSelect,
  });

  final List<_DesktopGroup> groups;
  final String activeId;
  final bool isDark;
  final Future<void> Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = groups.isEmpty ? 1 : groups.length;
        return Row(
          children: [
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _DesktopGroupChip(
                  group: groups[i],
                  selected: groups[i].id == activeId,
                  isDark: isDark,
                  onTap: () => onSelect(groups[i].id),
                ),
              ),
            ],
            if (count == 0) const Spacer(),
          ],
        );
      },
    );
  }
}

class _DesktopGroupChip extends StatelessWidget {
  const _DesktopGroupChip({
    required this.group,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final _DesktopGroup group;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? OtterColors.sberGreen.withValues(alpha: isDark ? 0.18 : 0.12)
          : (isDark ? OtterColors.darkSurface : Colors.white),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? OtterColors.sberGreen
                  : (isDark ? OtterColors.darkBorder : Colors.transparent),
            ),
            boxShadow: isDark || selected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${group.tasks.length}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: group.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                group.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: OtterColors.muted(isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopSplitTasks extends StatefulWidget {
  const _DesktopSplitTasks({
    required this.isDark,
    required this.group,
    required this.selectedTask,
    required this.detailKey,
    required this.onSelectTask,
    required this.onClearSelection,
    required this.onForceClearSelection,
    required this.onComplete,
    required this.onDelete,
  });

  final bool isDark;
  final _DesktopGroup? group;
  final Task? selectedTask;
  final GlobalKey<TaskDetailSheetState> detailKey;
  final Future<void> Function(Task) onSelectTask;
  final Future<void> Function() onClearSelection;
  /// Clears selection after the sheet already handled save/discard/delete.
  final VoidCallback onForceClearSelection;
  final Future<void> Function(Task) onComplete;
  final Future<void> Function(Task) onDelete;

  @override
  State<_DesktopSplitTasks> createState() => _DesktopSplitTasksState();
}

class _DesktopSplitTasksState extends State<_DesktopSplitTasks> {
  /// Matches web: clamp left pane between 34% and 72%.
  static const _minFraction = 0.34;
  static const _maxFraction = 0.72;
  static const _minLeftPx = 360.0;

  /// Default: middle (50/50), as requested for desktop.
  double _leftFraction = 0.5;

  double _clampLeftWidth(double desired, double totalWidth) {
    final minByPx = totalWidth <= 0
        ? _minLeftPx
        : (_minLeftPx / totalWidth).clamp(_minFraction, _maxFraction);
    final minF = minByPx > _minFraction ? minByPx : _minFraction;
    final fraction = (desired / totalWidth).clamp(minF, _maxFraction);
    return fraction * totalWidth;
  }

  void _onResizeDrag(double deltaDx, double totalWidth) {
    if (totalWidth <= 0) return;
    setState(() {
      final current = _leftFraction * totalWidth;
      final nextWidth = _clampLeftWidth(current + deltaDx, totalWidth);
      _leftFraction = nextWidth / totalWidth;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final group = widget.group;
    final selectedTask = widget.selectedTask;
    final tasks = group?.tasks ?? const <Task>[];
    final surface = isDark ? OtterColors.darkSurface : Colors.white;
    final border =
        isDark ? OtterColors.darkBorder : OtterColors.grayMid.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final leftWidth = _clampLeftWidth(
                _leftFraction * totalWidth,
                totalWidth,
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: leftWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: group?.color ?? OtterColors.sberGray,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  group?.title ?? 'Задачи',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: OtterColors.text(isDark),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: OtterColors.elevated(isDark),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${tasks.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: OtterColors.muted(isDark),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  // ignore: discarded_futures
                                  widget.onClearSelection();
                                },
                                child: const Text(
                                  'Снять выбор',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: OtterColors.sberGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: tasks.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'В этом разделе пока нет задач',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: OtterColors.muted(isDark),
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 16),
                                  itemCount: tasks.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final task = tasks[index];
                                    final selected =
                                        selectedTask?.id == task.id;
                                    return _DesktopTaskRow(
                                      task: task,
                                      selected: selected,
                                      isDark: isDark,
                                      onTap: () {
                                        // ignore: discarded_futures
                                        widget.onSelectTask(task);
                                      },
                                      onComplete: () =>
                                          widget.onComplete(task),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  _DesktopSplitResizeHandle(
                    isDark: isDark,
                    onDrag: (dx) => _onResizeDrag(dx, totalWidth),
                  ),
                  Expanded(
                    child: selectedTask == null
                        ? Center(
                            child: Text(
                              'Выберите задачу слева',
                              style: TextStyle(
                                color: OtterColors.muted(isDark),
                                fontSize: 14,
                              ),
                            ),
                          )
                        : TaskDetailSheet(
                            key: widget.detailKey,
                            task: selectedTask,
                            embedded: true,
                            onClosed: widget.onForceClearSelection,
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Draggable vertical divider between list and detail (web parity).
class _DesktopSplitResizeHandle extends StatefulWidget {
  const _DesktopSplitResizeHandle({
    required this.isDark,
    required this.onDrag,
  });

  final bool isDark;
  final ValueChanged<double> onDrag;

  @override
  State<_DesktopSplitResizeHandle> createState() =>
      _DesktopSplitResizeHandleState();
}

class _DesktopSplitResizeHandleState extends State<_DesktopSplitResizeHandle> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovering || _dragging;
    final line = widget.isDark ? OtterColors.darkBorder : OtterColors.grayLight;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        child: SizedBox(
          width: 6,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 3 : 1,
              color: active
                  ? OtterColors.sberGreen.withValues(alpha: 0.35)
                  : line,
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopTaskRow extends StatelessWidget {
  const _DesktopTaskRow({
    required this.task,
    required this.selected,
    required this.isDark,
    required this.onTap,
    required this.onComplete,
  });

  final Task task;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onComplete;

  bool get _hasMeta {
    final notify = task.notification?.trim() ?? '';
    return (task.dueDate != null && task.dueDate!.isNotEmpty) ||
        (task.dueTime != null && task.dueTime!.isNotEmpty) ||
        (task.duration != null &&
            task.duration!.start.isNotEmpty &&
            task.duration!.end.isNotEmpty) ||
        notify.isNotEmpty ||
        task.repeat != RepeatType.none;
  }

  /// Web `formatDesktopTaskDate` → `DD.MM.YY`.
  String? _formatDate(String? dueDate) {
    if (dueDate == null || dueDate.isEmpty) return null;
    final d = DateTime.tryParse(dueDate);
    if (d == null) return dueDate;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = (d.year % 100).toString().padLeft(2, '0');
    return '$dd.$mm.$yy';
  }

  @override
  Widget build(BuildContext context) {
    final accent = priorityColor(task.priority);
    final muted = OtterColors.muted(isDark);
    final mid = isDark ? OtterColors.darkMuted : OtterColors.grayMid;
    final dateLabel = _formatDate(task.dueDate);
    final dueTime = task.dueTime?.trim();
    final duration = task.duration;
    final hasDuration = duration != null &&
        duration.start.isNotEmpty &&
        duration.end.isNotEmpty;
    final hasNotify = (task.notification?.trim() ?? '').isNotEmpty;
    final hasRepeat = task.repeat != RepeatType.none;

    return Material(
      color: selected
          ? OtterColors.sberGreen.withValues(alpha: isDark ? 0.18 : 0.12)
          : (isDark ? OtterColors.darkSurfaceAlt : Colors.white),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: (!task.completed && task.priority != Priority.none)
                  ? BorderSide(color: accent, width: 3)
                  : BorderSide(
                      color: selected
                          ? OtterColors.sberGreen
                          : (isDark
                              ? OtterColors.darkBorder
                              : OtterColors.grayLight),
                    ),
              top: BorderSide(
                color: selected
                    ? OtterColors.sberGreen
                    : (isDark ? OtterColors.darkBorder : OtterColors.grayLight),
              ),
              right: BorderSide(
                color: selected
                    ? OtterColors.sberGreen
                    : (isDark ? OtterColors.darkBorder : OtterColors.grayLight),
              ),
              bottom: BorderSide(
                color: selected
                    ? OtterColors.sberGreen
                    : (isDark ? OtterColors.darkBorder : OtterColors.grayLight),
              ),
            ),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: onComplete,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: task.completed ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: accent),
                  ),
                  child: task.completed
                      ? const Icon(LucideIcons.check, size: 12, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: task.completed
                        ? muted
                        : selected
                            ? OtterColors.sberGreen
                            : OtterColors.text(isDark),
                    decoration:
                        task.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (_hasMeta) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        if (dateLabel != null)
                          Text(
                            dateLabel,
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        if (dateLabel != null &&
                            dueTime != null &&
                            dueTime.isNotEmpty)
                          Text('–', style: TextStyle(fontSize: 11, color: mid)),
                        if (dueTime != null && dueTime.isNotEmpty)
                          Text(
                            dueTime,
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        if (hasDuration) ...[
                          Text('–', style: TextStyle(fontSize: 11, color: mid)),
                          Text(
                            '${duration.start}–${duration.end}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: OtterColors.sberBlue,
                            ),
                          ),
                        ],
                        if (hasNotify)
                          Icon(LucideIcons.bell, size: 12, color: muted),
                        if (hasRepeat)
                          Icon(LucideIcons.refreshCw, size: 12, color: muted),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
    required this.isDark,
  });

  final String label;
  final int count;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? OtterColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: OtterColors.sberGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
