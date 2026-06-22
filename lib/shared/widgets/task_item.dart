import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/otter_colors.dart';
import '../../data/models/ui/ui_models.dart';

class TaskItem extends StatelessWidget {
  const TaskItem({
    super.key,
    required this.task,
    required this.onComplete,
    required this.onDelete,
    required this.onTap,
  });

  final Task task;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey(task.id),
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.28,
          children: [
            SlidableAction(
              onPressed: (_) => onComplete(),
              backgroundColor: OtterColors.sberGreen,
              foregroundColor: Colors.white,
              icon: LucideIcons.checkCircle,
              label: 'Готово',
              borderRadius: BorderRadius.circular(OtterColors.radiusMd),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.28,
          children: [
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: OtterColors.priorityHigh,
              foregroundColor: Colors.white,
              icon: LucideIcons.trash2,
              label: 'Удалить',
              borderRadius: BorderRadius.circular(OtterColors.radiusMd),
            ),
          ],
        ),
        child: Material(
          color: isDark ? OtterColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(OtterColors.radiusMd),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(OtterColors.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Checkbox(
                    completed: task.completed,
                    priority: task.priority,
                    onTap: onComplete,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _Content(task: task)),
                  const SizedBox(width: 8),
                  _PriorityDot(priority: task.priority),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({
    required this.completed,
    required this.priority,
    required this.onTap,
  });

  final bool completed;
  final Priority priority;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color border;
    if (completed) {
      border = OtterColors.sberGreen;
    } else {
      border = switch (priority) {
        Priority.high => OtterColors.priorityHigh,
        Priority.medium => OtterColors.priorityMedium,
        Priority.low => OtterColors.priorityLow,
        Priority.none => OtterColors.priorityNone,
      };
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: completed ? OtterColors.sberGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 2),
        ),
        child: completed
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? OtterColors.darkText : OtterColors.sberBlack;

    String? dateTimeLabel;
    if (task.dueDate != null) {
      final d = DateTime.tryParse(task.dueDate!);
      if (d != null) {
        dateTimeLabel = DateFormat('d MMM', 'ru').format(d);
        if (task.dueTime != null) dateTimeLabel = '$dateTimeLabel, ${task.dueTime}';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            decoration: task.completed ? TextDecoration.lineThrough : null,
            color: task.completed ? OtterColors.sberGray : textColor,
          ),
        ),
        if (dateTimeLabel != null ||
            task.duration != null ||
            task.notification != null ||
            task.repeat != RepeatType.none) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (dateTimeLabel != null)
                _Meta(icon: LucideIcons.clock, label: dateTimeLabel),
              if (task.duration != null)
                Text(
                  '${task.duration!.start}–${task.duration!.end}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: OtterColors.sberGray,
                  ),
                ),
              if (task.notification != null)
                const Icon(LucideIcons.bell, size: 14, color: OtterColors.sberGray),
              if (task.repeat != RepeatType.none)
                const Icon(LucideIcons.refreshCw, size: 14, color: OtterColors.sberGray),
            ],
          ),
        ],
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: OtterColors.sberGray),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: OtterColors.sberGray)),
      ],
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});
  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      Priority.high => OtterColors.priorityHigh,
      Priority.medium => OtterColors.priorityMedium,
      Priority.low => OtterColors.priorityLow,
      Priority.none => OtterColors.priorityNone,
    };
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
