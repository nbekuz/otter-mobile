import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../data/models/api/api_models.dart';
import '../tasks/task_detail_sheet.dart';

class NotificationDetailScreen extends ConsumerStatefulWidget {
  const NotificationDetailScreen({super.key, required this.notificationId});

  final int notificationId;

  @override
  ConsumerState<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState
    extends ConsumerState<NotificationDetailScreen> {
  ApiNotificationItem? _item;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await ref
          .read(notificationsInboxProvider.notifier)
          .fetchById(widget.notificationId);
      if (!mounted) return;
      setState(() {
        _item = item;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = getApiErrorMessage(e, 'Не удалось загрузить уведомление');
      });
    }
  }

  Future<void> _openTask() async {
    final item = _item;
    if (item == null) return;
    final taskId =
        item.data['task_id'] ??
        (item.task != null ? item.task.toString() : '');
    if (taskId.isEmpty) return;
    final task = ref.read(tasksStateProvider.notifier).findTaskById(taskId);
    if (task != null) {
      await showTaskDetailSheet(context, task);
      return;
    }
    if (!mounted) return;
    context.push(
      '/app/new-task?taskId=$taskId&returnTo=/app/notifications/${widget.notificationId}',
    );
  }

  Future<void> _delete() async {
    try {
      await ref
          .read(notificationsInboxProvider.notifier)
          .remove(widget.notificationId);
      if (!mounted) return;
      context.go('/app/notifications');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getApiErrorMessage(e, 'Не удалось удалить'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final isDark = settings.theme == 'dark';
    final item = _item;
    final taskId = item == null
        ? ''
        : (item.data['task_id'] ??
              (item.task != null ? item.task.toString() : ''));

    return Scaffold(
      backgroundColor: isDark ? OtterColors.darkBg : OtterColors.grayLight,
      appBar: AppBar(
        title: const Text('Уведомление'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/app/notifications');
            }
          },
        ),
        actions: [
          if (item != null)
            IconButton(
              tooltip: 'Удалить',
              onPressed: _delete,
              icon: const Icon(LucideIcons.trash2),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Повторить')),
                  ],
                ),
              ),
            )
          : item == null
          ? const Center(child: Text('Уведомление не найдено'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Material(
                  color: isDark ? OtterColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? OtterColors.darkText
                                : OtterColors.sberBlack,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.body,
                          style: TextStyle(
                            height: 1.45,
                            color: OtterColors.muted(isDark),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _formatDate(item.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: OtterColors.muted(isDark),
                          ),
                        ),
                        if (item.type.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Тип: ${item.type}',
                            style: TextStyle(
                              fontSize: 12,
                              color: OtterColors.muted(isDark),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (taskId.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _openTask,
                    child: const Text('Открыть задачу'),
                  ),
                ],
              ],
            ),
    );
  }

  String _formatDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());
  }
}
