import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/premium/premium_required.dart';
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
    icon: LucideIcons.calendarDays,
    label: 'Календарь',
  ),
  BottomNavItem(
    id: 'matrix',
    path: '/app/matrix',
    icon: LucideIcons.layoutGrid,
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

class OtterBottomNav extends ConsumerWidget {
  const OtterBottomNav({
    super.key,
    required this.order,
    required this.currentPath,
  });

  final List<String> order;
  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateFormat('d').format(DateTime.now());
    final byId = {for (final i in kAllNavItems) i.id: i};
    final items = order
        .map((id) => byId[id])
        .whereType<BottomNavItem>()
        .toList();

    final isDark = OtterColors.isDarkOf(context);

    return Container(
      decoration: BoxDecoration(
        color: OtterColors.surface(isDark),
        border: Border(
          top: BorderSide(color: OtterColors.border(isDark)),
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
              final inactiveColor = OtterColors.muted(isDark);
              return InkWell(
                onTap: () => navigateAppTab(context, ref, item.path),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
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
                                : inactiveColor,
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
                                      ? OtterColors.greenTint(isDark)
                                      : OtterColors.elevated(isDark),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  today,
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: active
                                        ? OtterColors.sberGreen
                                        : inactiveColor,
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
                              : inactiveColor,
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
    final current = currentPath.endsWith('/') && currentPath.length > 1
        ? currentPath.substring(0, currentPath.length - 1)
        : currentPath;
    if (path == '/app') return current == '/app';
    return current == path || current.startsWith('$path/');
  }
}
