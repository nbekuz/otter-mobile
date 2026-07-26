import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/otter_colors.dart';
import '../../data/models/ui/ui_models.dart';
import 'task_item.dart';

Color taskGroupAccent(TaskGroupKey key) => switch (key) {
  TaskGroupKey.overdue => const Color(0xFFFF3B30),
  TaskGroupKey.today => const Color(0xFFFF9500),
  TaskGroupKey.tomorrow => const Color(0xFF007AFF),
  TaskGroupKey.later => const Color(0xFFAF52DE),
  TaskGroupKey.nodate => const Color(0xFF8E8E93),
  TaskGroupKey.completed => const Color(0xFF21A038),
};

/// Soft pastel accordion surfaces (light theme).
Color taskGroupSurfaceTint(TaskGroupKey key) => switch (key) {
  TaskGroupKey.overdue => const Color(0xFFFDEAEA),
  TaskGroupKey.today => const Color(0xFFFFF7E0),
  TaskGroupKey.tomorrow => const Color(0xFFEEF4FF),
  TaskGroupKey.later => const Color(0xFFF6EEFF),
  TaskGroupKey.nodate => const Color(0xFFFFF8E6),
  TaskGroupKey.completed => const Color(0xFFECF8EF),
};

class TaskGroupWidget extends StatefulWidget {
  const TaskGroupWidget({
    super.key,
    required this.title,
    required this.tasks,
    required this.onComplete,
    required this.onDelete,
    required this.onOpen,
    this.accentColor,
    this.surfaceColor,
    this.initiallyExpanded = false,
  });

  final String title;
  final List<Task> tasks;
  final void Function(Task task) onComplete;
  final void Function(Task task) onDelete;
  final void Function(Task task) onOpen;
  final Color? accentColor;
  final Color? surfaceColor;
  final bool initiallyExpanded;

  @override
  State<TaskGroupWidget> createState() => _TaskGroupWidgetState();
}

class _TaskGroupWidgetState extends State<TaskGroupWidget> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    // Groups start collapsed when opening the Tasks page.
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? OtterColors.sberGray;
    final headerBg = isDark
        ? Color.alphaBlend(accent.withValues(alpha: 0.18), OtterColors.darkSurface)
        : (widget.surfaceColor ?? Colors.white);

    return Column(
      children: [
        Material(
          color: headerBg,
          borderRadius: BorderRadius.circular(OtterColors.radiusMd),
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(OtterColors.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${widget.title} (${widget.tasks.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 20,
                    color: accent,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          ...widget.tasks.map(
            (t) => TaskItem(
              task: t,
              onComplete: () => widget.onComplete(t),
              onDelete: () => widget.onDelete(t),
              onTap: () => widget.onOpen(t),
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}
