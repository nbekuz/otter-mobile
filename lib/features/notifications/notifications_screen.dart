import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../data/models/api/api_models.dart';
import '../tasks/task_detail_sheet.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(notificationsInboxProvider.notifier).load(),
    );
  }

  Future<void> _open(ApiNotificationItem item) async {
    if (!item.isRead) {
      try {
        await ref.read(notificationsInboxProvider.notifier).markRead(item.id);
      } catch (_) {}
    }
    final taskId =
        item.data['task_id'] ??
        (item.task != null ? item.task.toString() : '');
    if (taskId.isEmpty || !mounted) return;
    final task = ref.read(tasksStateProvider.notifier).findTaskById(taskId);
    if (task != null) {
      await showTaskDetailSheet(context, task);
      return;
    }
    if (!mounted) return;
    context.push('/app/new-task?taskId=$taskId&returnTo=/app/notifications');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final state = ref.watch(notificationsInboxProvider);
    final isDark = settings.theme == 'dark';

    return Scaffold(
      backgroundColor: isDark ? OtterColors.darkBg : OtterColors.grayLight,
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsInboxProvider.notifier).markAllRead(),
              child: const Text('Прочитать все'),
            ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => ref
                          .read(notificationsInboxProvider.notifier)
                          .load(),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            )
          : state.items.isEmpty
          ? const Center(child: Text('Нет уведомлений'))
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(notificationsInboxProvider.notifier).load(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return Material(
                    color: isDark
                        ? (item.isRead
                              ? OtterColors.darkSurface
                              : const Color(0xFF1C2230))
                        : (item.isRead
                              ? Colors.white
                              : const Color(0xFFE8F8EC)),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _open(item),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: item.isRead
                                    ? Colors.transparent
                                    : OtterColors.sberGreen,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? OtterColors.darkText
                                          : OtterColors.sberBlack,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.body,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : OtterColors.sberGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Удалить',
                              onPressed: () => ref
                                  .read(notificationsInboxProvider.notifier)
                                  .remove(item.id),
                              icon: const Icon(LucideIcons.trash2, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
