import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/otter_colors.dart';

class BottomNavItem {
  const BottomNavItem({
    required this.id,
    required this.path,
    required this.icon,
    required this.label,
  });

  final String id;
  final String path;
  final IconData icon;
  final String label;
}

const kAllNavItems = [
  BottomNavItem(
    id: 'tasks',
    path: '/app',
    icon: LucideIcons.checkSquare,
    label: 'Задачи',
  ),
  BottomNavItem(
    id: 'calendar',
    path: '/app/calendar',
    icon: LucideIcons.calendar,
    label: 'Календарь',
  ),
  BottomNavItem(
    id: 'matrix',
    path: '/app/matrix',
    icon: LucideIcons.grid,
    label: 'Матрица',
  ),
  BottomNavItem(
    id: 'pomodoro',
    path: '/app/pomodoro',
    icon: LucideIcons.timer,
    label: 'Помодоро',
  ),
  BottomNavItem(
    id: 'settings',
    path: '/app/settings',
    icon: LucideIcons.settings,
    label: 'Настройки',
  ),
];

class OtterBottomNav extends StatelessWidget {
  const OtterBottomNav({
    super.key,
    required this.order,
    required this.currentPath,
  });

  final List<String> order;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('d').format(DateTime.now());
    final byId = {for (final i in kAllNavItems) i.id: i};
    final items = order
        .map((id) => byId[id])
        .whereType<BottomNavItem>()
        .toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? OtterColors.darkBg : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? OtterColors.darkBorder : OtterColors.grayMid,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              final active = _isActive(item.path);
              return InkWell(
                onTap: () => context.go(item.path),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            item.icon,
                            size: 24,
                            color: active
                                ? OtterColors.sberGreen
                                : OtterColors.sberGray,
                          ),
                          if (item.id == 'calendar')
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? OtterColors.sberGreenLight
                                      : OtterColors.grayLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  today,
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: active
                                        ? OtterColors.sberGreen
                                        : OtterColors.sberGray,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: active
                              ? OtterColors.sberGreen
                              : OtterColors.sberGray,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  bool _isActive(String path) {
    if (path == '/app') return currentPath == '/app';
    return currentPath.startsWith(path);
  }
}
