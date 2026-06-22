import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/otter_colors.dart';
import '../../data/models/ui/ui_models.dart';
import 'task_item.dart';

class TaskGroupWidget extends StatefulWidget {
  const TaskGroupWidget({
    super.key,
    required this.title,
    required this.tasks,
    required this.onComplete,
    required this.onDelete,
    required this.onOpen,
    this.initiallyExpanded = true,
  });

  final String title;
  final List<Task> tasks;
  final void Function(Task task) onComplete;
  final void Function(Task task) onDelete;
  final void Function(Task task) onOpen;
  final bool initiallyExpanded;

  @override
  State<TaskGroupWidget> createState() => _TaskGroupWidgetState();
}

class _TaskGroupWidgetState extends State<TaskGroupWidget> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Material(
          color: isDark ? OtterColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(OtterColors.radiusMd),
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(OtterColors.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.title} (${widget.tasks.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? OtterColors.darkText : OtterColors.sberBlack,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 20,
                    color: OtterColors.sberGray,
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
