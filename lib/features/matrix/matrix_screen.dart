import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../data/models/ui/ui_models.dart';
import '../tasks/task_detail_sheet.dart';
import 'matrix_block_setting.dart';
import 'matrix_constants.dart';
import 'matrix_settings_sheet.dart';

class MatrixScreen extends ConsumerStatefulWidget {
  const MatrixScreen({super.key});

  @override
  ConsumerState<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends ConsumerState<MatrixScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(matrixSettingsProvider.notifier).load();
      await ref.read(matrixStateProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final matrix = ref.watch(matrixStateProvider);
    final settings = ref.watch(matrixSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? OtterColors.darkBg : OtterColors.grayLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _MatrixHeader(
              isDark: isDark,
              onSettingsTap: () => showMatrixSettingsSheet(context, ref),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref.read(matrixSettingsProvider.notifier).load();
                  await ref.read(matrixStateProvider.notifier).load();
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: constraints.maxHeight,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Expanded(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildQuadrant(
                                        context,
                                        kMatrixBlockThemes[0],
                                        settings,
                                        matrix,
                                        isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildQuadrant(
                                        context,
                                        kMatrixBlockThemes[1],
                                        settings,
                                        matrix,
                                        isDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildQuadrant(
                                        context,
                                        kMatrixBlockThemes[2],
                                        settings,
                                        matrix,
                                        isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildQuadrant(
                                        context,
                                        kMatrixBlockThemes[3],
                                        settings,
                                        matrix,
                                        isDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _priorityQuery(Priority priority) => switch (priority) {
    Priority.high => 'high',
    Priority.medium => 'medium',
    Priority.low => 'low',
    Priority.none => 'none',
  };

  Widget _buildQuadrant(
    BuildContext context,
    MatrixBlockTheme theme,
    MatrixSettingsState settings,
    Map<String, List<Task>> matrix,
    bool isDark,
  ) {
    final block = theme.block;
    final blockSetting = settings.blocks[block];
    final title = blockSetting?.title ?? theme.defaultTitle;
    final defaultPriority = MatrixBlockUiSetting.defaultPriorityFor(
      block,
      blockSetting,
    );
    final tasks = matrix[block.id] ?? [];

    return _MatrixQuadrant(
      block: block,
      title: title,
      bgColor: theme.bgColor,
      accent: theme.accent,
      tasks: tasks,
      isDark: isDark,
      onAccept: (task) =>
          ref.read(matrixStateProvider.notifier).moveTask(task.id, block),
      onTaskTap: (task) => showTaskDetailSheet(context, task),
      onAddTap: () async {
        final priority = _priorityQuery(defaultPriority);
        await context.push(
          '/app/new-task?returnTo=${Uri.encodeComponent('/app/matrix')}&matrixBlock=${block.id}&priority=$priority',
        );
        if (mounted) {
          await ref.read(matrixStateProvider.notifier).load();
        }
      },
      onComplete: (task) async {
        await ref.read(tasksStateProvider.notifier).completeTask(task);
        await ref.read(matrixStateProvider.notifier).load();
      },
    );
  }
}

class _MatrixHeader extends StatelessWidget {
  const _MatrixHeader({required this.isDark, required this.onSettingsTap});

  final bool isDark;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? OtterColors.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? OtterColors.darkBorder : Colors.transparent,
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Матрица Эйзенхауэра',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? OtterColors.darkText : OtterColors.sberBlack,
              ),
            ),
          ),
          Material(
            color: isDark ? OtterColors.darkSurfaceAlt : OtterColors.grayLight,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onSettingsTap,
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  LucideIcons.settings,
                  size: 20,
                  color: OtterColors.sberGray,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixQuadrant extends StatefulWidget {
  const _MatrixQuadrant({
    required this.block,
    required this.title,
    required this.bgColor,
    required this.accent,
    required this.tasks,
    required this.isDark,
    required this.onAccept,
    required this.onTaskTap,
    required this.onAddTap,
    required this.onComplete,
  });

  final MatrixBlock block;
  final String title;
  final Color bgColor;
  final Color accent;
  final List<Task> tasks;
  final bool isDark;
  final void Function(Task task) onAccept;
  final void Function(Task task) onTaskTap;
  final VoidCallback onAddTap;
  final Future<void> Function(Task task) onComplete;

  @override
  State<_MatrixQuadrant> createState() => _MatrixQuadrantState();
}

class _MatrixQuadrantState extends State<_MatrixQuadrant> {
  bool _dragOver = false;

  @override
  Widget build(BuildContext context) {
    final containerColor = widget.isDark
        ? widget.accent.withValues(alpha: 0.07)
        : widget.bgColor;
    final borderColor = widget.accent.withValues(
      alpha: widget.isDark ? 0.25 : 0.15,
    );

    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) => d.data.matrixBlock != widget.block,
      onAcceptWithDetails: (d) {
        setState(() => _dragOver = false);
        widget.onAccept(d.data);
      },
      onMove: (_) {
        if (!_dragOver) setState(() => _dragOver = true);
      },
      onLeave: (_) {
        if (_dragOver) setState(() => _dragOver = false);
      },
      builder: (context, candidate, rejected) {
        final isActive = candidate.isNotEmpty || _dragOver;
        return Container(
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QuadrantHeader(
                title: widget.title,
                accent: widget.accent,
                count: widget.tasks.length,
                borderColor: widget.accent.withValues(alpha: 0.19),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    _DropZone(
                      accent: widget.accent,
                      bgColor: widget.isDark
                          ? OtterColors.darkSurface
                          : widget.bgColor,
                      isActive: isActive,
                      isDark: widget.isDark,
                      onTap: widget.onAddTap,
                    ),
                    ...widget.tasks.map(
                      (task) => _MatrixTaskCard(
                        task: task,
                        accent: widget.accent,
                        isDark: widget.isDark,
                        onTap: () => widget.onTaskTap(task),
                        onComplete: () => widget.onComplete(task),
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

class _QuadrantHeader extends StatelessWidget {
  const _QuadrantHeader({
    required this.title,
    required this.accent,
    required this.count,
    required this.borderColor,
  });

  final String title;
  final Color accent;
  final int count;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: accent,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.accent,
    required this.bgColor,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  final Color accent;
  final Color bgColor;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dashColor = accent.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark
                            ? OtterColors.darkSurfaceAlt
                            : Colors.white.withValues(alpha: 0.9))
                      : bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '+',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isActive ? 'Отпустите здесь' : 'перетащите',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DashedBorderPainter(
                      color: dashColor,
                      radius: 12,
                      strokeWidth: 2,
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

class _MatrixTaskCard extends StatelessWidget {
  const _MatrixTaskCard({
    required this.task,
    required this.accent,
    required this.isDark,
    required this.onTap,
    required this.onComplete,
  });

  final Task task;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final card = _MatrixTaskCardBody(
      task: task,
      accent: accent,
      isDark: isDark,
      onTap: onTap,
      onComplete: onComplete,
    );

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return Draggable<Task>(
        data: task,
        feedback: _dragFeedback(card),
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: MouseRegion(cursor: SystemMouseCursors.grab, child: card),
      );
    }

    return LongPressDraggable<Task>(
      data: task,
      feedback: _dragFeedback(card),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  Widget _dragFeedback(Widget card) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 180, child: Opacity(opacity: 0.95, child: card)),
    );
  }
}

class _MatrixTaskCardBody extends StatelessWidget {
  const _MatrixTaskCardBody({
    required this.task,
    required this.accent,
    required this.isDark,
    required this.onTap,
    required this.onComplete,
  });

  final Task task;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? OtterColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6, top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? OtterColors.darkBorder : Colors.transparent,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onComplete,
                  child: Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: task.completed ? accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: accent, width: 1.5),
                    ),
                    child: task.completed
                        ? const Icon(Icons.check, size: 10, color: Colors.white)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.completed
                            ? OtterColors.sberGray
                            : (isDark
                                  ? OtterColors.darkText
                                  : OtterColors.sberBlack),
                      ),
                    ),
                    if (_formatTaskMeta(task) != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.clock,
                            size: 10,
                            color: OtterColors.sberGray,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _formatTaskMeta(task)!,
                              style: const TextStyle(
                                fontSize: 10,
                                color: OtterColors.sberGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _formatTaskMeta(Task task) {
    final parts = <String>[];
    if (task.dueDate != null) {
      final d = DateTime.tryParse(task.dueDate!);
      if (d != null) {
        parts.add(DateFormat('d MMMM', 'ru').format(d));
      }
    }
    if (task.dueTime != null) parts.add(task.dueTime!);
    return parts.isEmpty ? null : parts.join(', ');
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    const dashWidth = 5.0;
    const gapWidth = 4.0;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
