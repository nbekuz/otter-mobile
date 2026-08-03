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
import 'task_detail_sheet.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  static const _searchTapGroup = Object();

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchVisible = false;

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasksStateProvider);
    final settings = ref.watch(appSettingsProvider);
    final inbox = ref.watch(notificationsInboxProvider);
    final isDark = settings.theme == 'dark';
    final showingSearch = _searchVisible || state.searchQuery.isNotEmpty;
    final groups = TaskGroupKey.values;
    final wide = Responsive.isWide(context);

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
                      // Keep field ready for more typing; only hide IME.
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
                          ? _WideTaskGroups(
                              groups: groups,
                              settings: settings,
                              state: state,
                              bottomPadding: wide ? 16 : 100,
                              onComplete: _complete,
                              onDelete: _delete,
                              onOpen: _openDetail,
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
      return;
    }
    await ref.read(tasksStateProvider.notifier).deleteTask(task.id);
  }

  void _openDetail(Task task) {
    _closeSearch();
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
          (t) => TaskGroupWidget(
            title: t.title,
            tasks: [t],
            initiallyExpanded: true,
            onComplete: onComplete,
            onDelete: onDelete,
            onOpen: onOpen,
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

class _WideTaskGroups extends StatelessWidget {
  const _WideTaskGroups({
    required this.groups,
    required this.settings,
    required this.state,
    required this.bottomPadding,
    required this.onComplete,
    required this.onDelete,
    required this.onOpen,
  });

  final List<TaskGroupKey> groups;
  final AppSettings settings;
  final TasksState state;
  final double bottomPadding;
  final Future<void> Function(Task) onComplete;
  final Future<void> Function(Task) onDelete;
  final void Function(Task) onOpen;

  @override
  Widget build(BuildContext context) {
    final visibleGroups = groups
        .where(
          (key) => settings.visibleGroups.contains(
            key == TaskGroupKey.nodate ? 'nodate' : key.name,
          ),
        )
        .toList();
    final split = (visibleGroups.length / 2).ceil();
    final left = visibleGroups.take(split).toList();
    final right = visibleGroups.skip(split).toList();

    Widget columnFor(List<TaskGroupKey> keys) {
      return ListView(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding),
        children: [
          for (final key in keys)
            TaskGroupWidget(
              key: ValueKey('wide-group-${key.name}'),
              title: key.titleRu,
              tasks: state.groups[key] ?? [],
              accentColor: taskGroupAccent(key),
              surfaceColor: taskGroupSurfaceTint(key),
              initiallyExpanded: false,
              onComplete: onComplete,
              onDelete: onDelete,
              onOpen: onOpen,
            ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: columnFor(left)),
        Expanded(child: columnFor(right)),
      ],
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
