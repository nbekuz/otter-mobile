import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../data/models/api/api_models.dart';
import '../../shared/widgets/app_toast.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final Set<int> _selectedIds = {};
  bool _bulkDeleting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(notificationsInboxProvider.notifier).load(),
    );
  }

  Future<void> _open(ApiNotificationItem item) async {
    if (!mounted) return;
    context.push('/app/notifications/${item.id}');
  }

  void _pruneSelection(List<ApiNotificationItem> items) {
    final alive = items.map((e) => e.id).toSet();
    _selectedIds.removeWhere((id) => !alive.contains(id));
  }

  void _syncSelectionWithItems(List<ApiNotificationItem> items) {
    final before = _selectedIds.length;
    _pruneSelection(items);
    if (_selectedIds.length != before && mounted) {
      setState(() {});
    }
  }

  void _toggleSelectAll(List<ApiNotificationItem> items) {
    final allSelected =
        items.isNotEmpty && items.every((e) => _selectedIds.contains(e.id));
    setState(() {
      if (allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(items.map((e) => e.id));
      }
    });
  }

  void _toggleOne(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteOne(int id) async {
    try {
      await ref.read(notificationsInboxProvider.notifier).remove(id);
      if (!mounted) return;
      setState(() => _selectedIds.remove(id));
    } catch (e) {
      if (!mounted) return;
      showAppToast(
        context,
        getApiErrorMessage(e, 'Не удалось удалить'),
      );
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty || _bulkDeleting) return;
    final ids = _selectedIds.toList();
    setState(() => _bulkDeleting = true);
    try {
      await ref.read(notificationsInboxProvider.notifier).removeMany(ids);
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _bulkDeleting = false;
      });
      showAppToast(
        context,
        ids.length == 1
            ? 'Уведомление удалено'
            : 'Удалено уведомлений: ${ids.length}',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _bulkDeleting = false);
      // Keep remaining selected ids that still exist.
      final items = ref.read(notificationsInboxProvider).items;
      _pruneSelection(items);
      showAppToast(context, getApiErrorMessage(e, 'Не удалось удалить'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final state = ref.watch(notificationsInboxProvider);
    final isDark = settings.theme == 'dark';

    ref.listen<NotificationsInboxState>(notificationsInboxProvider, (prev, next) {
      if (prev?.items != next.items) {
        _syncSelectionWithItems(next.items);
      }
    });

    final allSelected = state.items.isNotEmpty &&
        state.items.every((e) => _selectedIds.contains(e.id));
    final hasSelection = _selectedIds.isNotEmpty;

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
          : Column(
              children: [
                _BulkActionsBar(
                  isDark: isDark,
                  allSelected: allSelected,
                  hasSelection: hasSelection,
                  deleting: _bulkDeleting,
                  selectedCount: _selectedIds.length,
                  onToggleSelectAll: () => _toggleSelectAll(state.items),
                  onDeleteSelected: _deleteSelected,
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await ref
                          .read(notificationsInboxProvider.notifier)
                          .load();
                      if (mounted) {
                        setState(() {
                          _pruneSelection(
                            ref.read(notificationsInboxProvider).items,
                          );
                        });
                      }
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: state.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = state.items[index];
                        final selected = _selectedIds.contains(item.id);
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
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _toggleOne(item.id),
                                      child: _SelectBox(value: selected),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                    onPressed: _bulkDeleting
                                        ? null
                                        : () => _deleteOne(item.id),
                                    icon: const Icon(
                                      LucideIcons.trash2,
                                      size: 18,
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
    );
  }
}

class _BulkActionsBar extends StatelessWidget {
  const _BulkActionsBar({
    required this.isDark,
    required this.allSelected,
    required this.hasSelection,
    required this.deleting,
    required this.selectedCount,
    required this.onToggleSelectAll,
    required this.onDeleteSelected,
  });

  final bool isDark;
  final bool allSelected;
  final bool hasSelection;
  final bool deleting;
  final int selectedCount;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? Colors.white70 : OtterColors.sberGray;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          const Spacer(),
          InkWell(
            onTap: deleting ? null : onToggleSelectAll,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ВЫДЕЛИТЬ ВСЕ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SelectBox(
                    value: allSelected,
                    onChanged: deleting ? () {} : onToggleSelectAll,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: hasSelection && !deleting ? onDeleteSelected : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: OtterColors.priorityHigh,
              disabledForegroundColor:
                  OtterColors.priorityHigh.withValues(alpha: 0.35),
              side: BorderSide(
                color: hasSelection && !deleting
                    ? OtterColors.priorityHigh
                    : OtterColors.priorityHigh.withValues(alpha: 0.35),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: deleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    selectedCount > 0
                        ? 'УДАЛИТЬ ВЫДЕЛЕННЫЕ ($selectedCount)'
                        : 'УДАЛИТЬ ВЫДЕЛЕННЫЕ',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({
    required this.value,
    this.onChanged,
  });

  final bool value;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: value ? OtterColors.sberGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value ? OtterColors.sberGreen : OtterColors.grayMid,
          width: 2,
        ),
      ),
      child: value
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );

    if (onChanged == null) return box;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onChanged,
        borderRadius: BorderRadius.circular(6),
        child: box,
      ),
    );
  }
}
