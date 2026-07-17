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
  final _search = TextEditingController();
  bool _searchVisible = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(tasksStateProvider.notifier).loadGrouped();
      ref.read(appSettingsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasksStateProvider);
    final settings = ref.watch(appSettingsProvider);
    final isDark = settings.theme == 'dark';
    final showingSearch = _searchVisible || state.searchQuery.isNotEmpty;
    final groups = TaskGroupKey.values;
    final wide = Responsive.isWide(context);

    final overdue = state.groups[TaskGroupKey.overdue]?.length ?? 0;
    final today = state.groups[TaskGroupKey.today]?.length ?? 0;
    final completed = state.groups[TaskGroupKey.completed]?.length ?? 0;

    return Scaffold(
      backgroundColor: isDark ? OtterColors.darkBg : OtterColors.grayLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                  if (!wide)
                    IconButton(
                      tooltip: 'FAQ',
                      onPressed: () => context.push('/app/faq'),
                      icon: const Icon(LucideIcons.helpCircle),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? OtterColors.darkSurface
                            : Colors.white,
                      ),
                    ),
                  if (!wide)
                    IconButton(
                      tooltip: 'Документы',
                      onPressed: () => context.push('/app/legal'),
                      icon: const Icon(LucideIcons.fileText, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? OtterColors.darkSurface
                            : Colors.white,
                      ),
                    ),
                  if (wide)
                    IconButton(
                      tooltip: 'Обновить',
                      onPressed: () =>
                          ref.read(tasksStateProvider.notifier).loadGrouped(),
                      icon: const Icon(LucideIcons.refreshCw, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark
                            ? OtterColors.darkSurface
                            : Colors.white,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Поиск',
                    onPressed: () =>
                        setState(() => _searchVisible = !_searchVisible),
                    icon: const Icon(LucideIcons.search),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? OtterColors.darkSurface
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (showingSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _search,
                  autofocus: !wide,
                  onChanged: (q) =>
                      ref.read(tasksStateProvider.notifier).search(q),
                  onTapOutside: dismissKeyboardOnTapOutside,
                  onEditingComplete: KeyboardDismisser.dismiss,
                  decoration: InputDecoration(
                    hintText: 'Поиск задач...',
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                    suffixIcon: state.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 18),
                            onPressed: () {
                              _search.clear();
                              ref.read(tasksStateProvider.notifier).search('');
                            },
                          )
                        : null,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                      label: 'Готово',
                      count: completed,
                      color: OtterColors.sberGreen,
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
                              bottomPadding: wide ? 24 : 100,
                              onComplete: _complete,
                              onDelete: _delete,
                              onOpen: _openDetail,
                            )
                          : ListView(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                wide ? 24 : 100,
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
    await ref.read(tasksStateProvider.notifier).deleteTask(task.id);
  }

  void _openDetail(Task task) {
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
            title: key.titleRu,
            tasks: state.groups[key] ?? [],
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
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
        children: [
          for (final key in keys)
            TaskGroupWidget(
              title: key.titleRu,
              tasks: state.groups[key] ?? [],
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
