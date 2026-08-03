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
    this.pad = 4,
    this.gap = 3,
    this.cornerRadius,
    this.weekTypography = false,
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
  final double pad;
  final double gap;
  /// When set, overrides the compact/regular radius (web week uses ~4).
  final double? cornerRadius;
  /// Week view: two-line black text (time + title), slightly smaller than day.
  final bool weekTypography;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(item.task.priority);
    final style = timelineTaskHorizontalStyle(
      layoutCols: item.layoutCols,
      layoutCol: item.layoutCol,
      timelineWidth: timelineWidth,
      pad: pad,
      gap: gap,
    );
    final left = style.left;
    final colWidth = style.width;

    final blockHeight = item.heightPx.clamp(28.0, double.infinity);
    final compact = blockHeight < 52;
    final medium = blockHeight < 76;
    final radius = cornerRadius ?? (compact ? 8.0 : 12.0);

    Widget dragHandle(CalendarTaskDragMode mode, {required bool isTop}) {
      final handleHeight = compact ? 12.0 : 18.0;
      final handleWidth = (colWidth * 0.55).clamp(28.0, 56.0);
      return Positioned(
        top: isTop ? 0 : null,
        bottom: isTop ? null : 0,
        left: 0,
        right: 0,
        height: handleHeight,
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) => onDragStart(mode),
            onVerticalDragUpdate: (d) => onDragUpdate(d, mode),
            onVerticalDragEnd: (_) => onDragEnd(),
            onVerticalDragCancel: onDragEnd,
            child: SizedBox(
              width: handleWidth,
              height: handleHeight,
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
          ),
        ),
      );
    }

    Widget checkbox({bool expandTap = false}) {
      final size = compact ? 12.0 : 14.0;
      final box = Container(
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
      );
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggleComplete,
          child: expandTap
              ? SizedBox(
                  width: size + 12,
                  height: size + 12,
                  child: Align(alignment: Alignment.topLeft, child: box),
                )
              : box,
        ),
      );
    }

    Widget bodyContent() {
      if (item.isContinuation) {
        return const SizedBox.expand();
      }

      // Web week: two lines, text-sber-black, slightly smaller than day text-sm.
      if (weekTypography) {
        final timeStyle = TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: OtterColors.sberBlack,
        );
        final titleStyle = TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: OtterColors.sberBlack,
          decoration:
              item.task.completed ? TextDecoration.lineThrough : null,
        );

        if (compact && blockHeight < 36) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 4, 2),
            child: Text(
              item.continuesAfter
                  ? '${item.task.title} ↓'
                  : item.labelTime,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: timeStyle,
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(18, compact ? 2 : 4, 4, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!item.continuesAfter)
                Text(
                  item.labelTime,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: timeStyle,
                ),
              Text(
                item.continuesAfter
                    ? '${item.task.title} ↓'
                    : item.task.title,
                maxLines: blockHeight >= 52 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ],
          ),
        );
      }

      if (compact) {
        return Center(
          child: Text(
            item.labelTime,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        );
      }

      if (medium) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.continuesAfter
                      ? '${item.task.title} ↓'
                      : '${item.labelTime} · ${item.task.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
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
        padding: const EdgeInsets.fromLTRB(22, 6, 8, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!item.continuesAfter)
                    Text(
                      item.labelTime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  Text(
                    item.task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: OtterColors.sberBlack,
                      decoration: item.task.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (item.continuesAfter)
                    const Text(
                      'продолжается ↓',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: OtterColors.sberGray,
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
      // Match web: zIndex = (dragging ? 35 : 1) + layoutCol
      child: MouseRegion(
        cursor: isDragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: isDragging ? 0.92 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: colWidth,
            height: blockHeight,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDragging ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(radius),
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
                if (item.isContinuation)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(radius),
                        ),
                      ),
                    ),
                  ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  onPanStart: (_) =>
                      onDragStart(CalendarTaskDragMode.move),
                  onPanUpdate: (d) =>
                      onDragUpdate(d, CalendarTaskDragMode.move),
                  onPanEnd: (_) => onDragEnd(),
                  onPanCancel: onDragEnd,
                  child: bodyContent(),
                ),
                if (!item.isContinuation)
                  dragHandle(CalendarTaskDragMode.resizeStart, isTop: true),
                dragHandle(CalendarTaskDragMode.resizeEnd, isTop: false),
                // Above resize handles so complete taps are not swallowed.
                if (!item.isContinuation && (!compact || weekTypography))
                  Positioned(
                    top: weekTypography ? 3 : (medium ? 6 : 4),
                    left: weekTypography ? 2 : 2,
                    child: checkbox(expandTap: true),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
