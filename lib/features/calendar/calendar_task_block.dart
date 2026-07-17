import 'package:flutter/material.dart';

import '../../core/theme/otter_colors.dart';
import '../../core/theme/priority_colors.dart';
import 'calendar_timeline.dart';

enum CalendarTaskDragMode { move, resizeStart, resizeEnd }

class CalendarTaskBlock extends StatelessWidget {
  const CalendarTaskBlock({
    super.key,
    required this.item,
    required this.timelineWidth,
    required this.isDragging,
    required this.onTap,
    required this.onToggleComplete,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final CalendarTimelineTask item;
  final double timelineWidth;
  final bool isDragging;
  final VoidCallback onTap;
  final VoidCallback onToggleComplete;
  final void Function(CalendarTaskDragMode mode) onDragStart;
  final void Function(DragUpdateDetails details, CalendarTaskDragMode mode)
  onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(item.task.priority);
    final leftFraction = item.layoutCol / item.layoutCols;
    const pad = 4.0;
    const gap = 3.0;
    final innerWidth = timelineWidth - pad * 2;
    final colWidth = item.layoutCols <= 1
        ? innerWidth
        : (innerWidth - gap * (item.layoutCols - 1)) / item.layoutCols;
    final left = pad + colWidth * leftFraction + gap * item.layoutCol;

    final blockHeight = item.heightPx;
    final compact = blockHeight < 52;
    final medium = blockHeight < 76;

    Widget dragHandle(CalendarTaskDragMode mode, {required bool isTop}) {
      final handleHeight = compact ? 12.0 : 18.0;
      return Positioned(
        top: isTop ? 0 : null,
        bottom: isTop ? null : 0,
        left: 0,
        right: 0,
        height: handleHeight,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: (_) => onDragStart(mode),
          onVerticalDragUpdate: (d) => onDragUpdate(d, mode),
          onVerticalDragEnd: (_) => onDragEnd(),
          onVerticalDragCancel: onDragEnd,
          child: Align(
            alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                top: isTop ? 2 : 0,
                bottom: isTop ? 0 : 2,
              ),
              child: Container(
                width: compact ? 32 : 44,
                height: 3,
                decoration: BoxDecoration(
                  color: OtterColors.sberGray.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget checkbox() {
      final size = compact ? 12.0 : 14.0;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onToggleComplete,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(color: color, width: compact ? 1.5 : 2),
              color: item.task.completed ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(compact ? 3 : 4),
            ),
            child: item.task.completed
                ? Icon(Icons.check, size: compact ? 8 : 10, color: Colors.white)
                : null,
          ),
        ),
      );
    }

    Widget bodyContent() {
      if (compact) {
        return Center(
          child: Text(
            item.labelTime,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        );
      }

      if (medium) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              checkbox(),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${item.labelTime} · ${item.task.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                    decoration: item.task.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: checkbox()),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.labelTime,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    item.task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: OtterColors.sberBlack,
                      decoration: item.task.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Positioned(
      top: item.topPx,
      left: left,
      width: colWidth,
      height: blockHeight,
      child: MouseRegion(
        cursor: isDragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: isDragging ? 0.92 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDragging ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(compact ? 8 : 12),
              border: Border(
                left: BorderSide(color: color, width: compact ? 2 : 3),
              ),
              boxShadow: isDragging
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  onVerticalDragStart: (_) =>
                      onDragStart(CalendarTaskDragMode.move),
                  onVerticalDragUpdate: (d) =>
                      onDragUpdate(d, CalendarTaskDragMode.move),
                  onVerticalDragEnd: (_) => onDragEnd(),
                  onVerticalDragCancel: onDragEnd,
                  child: bodyContent(),
                ),
                dragHandle(CalendarTaskDragMode.resizeStart, isTop: true),
                dragHandle(CalendarTaskDragMode.resizeEnd, isTop: false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
