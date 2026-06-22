import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/theme/priority_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../data/mappers/task_mapper.dart';
import '../../data/models/ui/ui_models.dart';
import '../../features/matrix/matrix_block_setting.dart';
import '../../features/matrix/matrix_constants.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/keyboard_dismisser.dart';
import '../../shared/widgets/select_field.dart';
import 'task_time_sync.dart';

enum _TaskFormTab { date, priority, notify, repeat, matrix }

class NewTaskScreen extends ConsumerStatefulWidget {
  const NewTaskScreen({
    super.key,
    this.taskId,
    this.initialDueDate,
    this.initialDueTime,
    this.initialDurationStart,
    this.initialDurationEnd,
    this.initialMatrixBlock,
    this.initialPriority,
    this.returnTo,
  });

  final String? taskId;
  final String? initialDueDate;
  final String? initialDueTime;
  final String? initialDurationStart;
  final String? initialDurationEnd;
  final String? initialMatrixBlock;
  final String? initialPriority;
  final String? returnTo;

  bool get isEditMode => taskId != null && taskId!.isNotEmpty;

  @override
  ConsumerState<NewTaskScreen> createState() => _NewTaskScreenState();
}

class _NewTaskScreenState extends ConsumerState<NewTaskScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _timeSync = TaskTimeSync();

  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  TimeOfDay? _durationStart;
  TimeOfDay? _durationEnd;
  Priority _priority = Priority.medium;
  MatrixBlock _matrix = MatrixBlock.notUrgentNotImportant;
  String? _notification;
  RepeatType _repeat = RepeatType.none;
  _TaskFormTab _activeTab = _TaskFormTab.date;
  bool _explicitNoDeadline = false;
  bool _loading = false;
  bool _descOpen = false;
  String? _error;

  static const _notifyOptions = [
    (value: '0', label: 'В момент срока'),
    (value: '5', label: 'За 5 минут'),
    (value: '15', label: 'За 15 минут'),
    (value: '30', label: 'За 30 минут'),
    (value: '60', label: 'За 1 час'),
    (value: '1440', label: 'За 1 день'),
    (value: '', label: 'Без уведомления'),
  ];

  static const _repeatOptions = [
    (value: RepeatType.none, label: 'Не повторять'),
    (value: RepeatType.daily, label: 'Каждый день'),
    (value: RepeatType.weekly, label: 'Каждую неделю'),
    (value: RepeatType.monthly, label: 'Каждый месяц'),
    (value: RepeatType.yearly, label: 'Каждый год'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDueDate != null) {
      _dueDate = DateTime.tryParse(widget.initialDueDate!);
    }
    _dueTime = _parseTime(widget.initialDueTime);
    _durationStart = _parseTime(widget.initialDurationStart) ?? _dueTime;
    _durationEnd = _parseTime(widget.initialDurationEnd) ??
        (_dueTime != null
            ? _parseTime(addMinutesToTime(_formatTime(_dueTime)!, 60))
            : null);

    if (widget.initialMatrixBlock != null &&
        widget.initialMatrixBlock!.isNotEmpty) {
      _matrix = MatrixBlockX.fromId(widget.initialMatrixBlock!);
      _activeTab = _TaskFormTab.matrix;
    }

    if (widget.initialPriority != null &&
        widget.initialPriority!.isNotEmpty) {
      _priority =
          MatrixBlockUiSetting.priorityFromFilter(widget.initialPriority!);
    }

    if (widget.initialDueDate != null) {
      _activeTab = _TaskFormTab.date;
    }

    if (widget.isEditMode) {
      _descOpen = true;
      Future.microtask(_loadTask);
    }

    Future.microtask(
      () => ref.read(matrixSettingsProvider.notifier).load(),
    );
  }

  Future<void> _loadTask() async {
    setState(() => _loading = true);
    try {
      final task =
          await ref.read(tasksServiceProvider).fetchTask(widget.taskId!);
      _title.text = task.title;
      _description.text = task.description ?? '';
      _priority = task.priority;
      _matrix = task.matrixBlock ?? MatrixBlock.notUrgentNotImportant;
      _repeat = task.repeat;
      _notification = task.notification;
      if (task.dueDate != null) {
        _dueDate = DateTime.tryParse(task.dueDate!);
      } else {
        _explicitNoDeadline = true;
      }
      _dueTime = _parseTime(task.dueTime);
      _durationStart = _parseTime(task.duration?.start);
      _durationEnd = _parseTime(task.duration?.end);
      setState(() {});
    } catch (e) {
      if (mounted) showAppToast(context, getApiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String? _formatTime(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String? _formatDate(DateTime? d) =>
      d == null ? null : DateFormat('yyyy-MM-dd').format(d);

  String _displayDate(DateTime? d) =>
      d == null ? 'ДД.ММ.ГГГГ' : DateFormat('dd.MM.yyyy').format(d);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _goBack() {
    final returnTo = widget.returnTo;
    if (returnTo != null && returnTo.isNotEmpty) {
      context.go(Uri.decodeComponent(returnTo));
    } else {
      context.pop();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        _explicitNoDeadline = false;
      });
    }
  }

  Future<void> _pickTime({
    required void Function(TimeOfDay) onPicked,
    TimeOfDay? initial,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
    );
    if (picked != null) onPicked(picked);
  }

  void _applyDueTimeSync(TimeOfDay time) {
    final formatted = _formatTime(time)!;
    _timeSync.onDueTimeChanged(formatted, (start, end) {
      setState(() {
        _dueTime = time;
        _durationStart = _parseTime(start);
        _durationEnd = _parseTime(end);
        _error = null;
      });
    });
  }

  void _applyStartSync(TimeOfDay time) {
    final formatted = _formatTime(time)!;
    _timeSync.onDurationStartChanged(
      formatted,
      _formatTime(_dueTime),
      _formatTime(_durationEnd),
      (due, end) {
        setState(() {
          _durationStart = time;
          _dueTime = _parseTime(due);
          _durationEnd = _parseTime(end);
          _error = null;
        });
      },
    );
  }

  void _setQuickDate(String id) {
    final now = DateTime.now();
    setState(() {
      if (id == 'today') {
        _dueDate = DateTime(now.year, now.month, now.day);
        _explicitNoDeadline = false;
      } else if (id == 'tomorrow') {
        final t = now.add(const Duration(days: 1));
        _dueDate = DateTime(t.year, t.month, t.day);
        _explicitNoDeadline = false;
      } else {
        _dueDate = null;
        _dueTime = null;
        _durationStart = null;
        _durationEnd = null;
        _explicitNoDeadline = true;
      }
    });
  }

  bool _isQuickDateActive(String id) {
    if (id == 'none') return _explicitNoDeadline;
    if (_dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
    if (id == 'today') return due == today;
    if (id == 'tomorrow') {
      final tomorrow = today.add(const Duration(days: 1));
      return due == tomorrow;
    }
    return false;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showAppToast(context, 'Введите название');
      return;
    }

    final durationError = validateDurationFields(
      _formatTime(_durationStart),
      _formatTime(_durationEnd),
    );
    if (durationError != null) {
      setState(() {
        _error = durationError;
        _activeTab = _TaskFormTab.date;
      });
      return;
    }

    TaskDuration? duration;
    if (_durationStart != null && _durationEnd != null) {
      duration = TaskDuration(
        start: _formatTime(_durationStart)!,
        end: _formatTime(_durationEnd)!,
      );
    }

    setState(() => _loading = true);
    try {
      final partial = PartialTask(
        title: _title.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        dueDate: _explicitNoDeadline ? null : _formatDate(_dueDate),
        dueTime: _formatTime(_dueTime),
        duration: duration,
        priority: _priority,
        matrixBlock: _matrix,
        notification:
            (_notification == null || _notification!.isEmpty)
                ? null
                : _notification,
        repeat: _repeat,
      );

      if (widget.isEditMode) {
        await ref
            .read(tasksStateProvider.notifier)
            .updateTask(widget.taskId!, partial);
      } else {
        await ref.read(tasksStateProvider.notifier).addTask(partial);
      }
      if (mounted) _goBack();
    } catch (e) {
      if (mounted) showAppToast(context, getApiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && widget.isEditMode && _title.text.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: OtterColors.grayLight,
      body: SafeArea(
        child: ResponsiveContent(
          maxWidth: Responsive.isWide(context) ? 720 : double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTitleSection(),
                      _buildTabBar(),
                      Expanded(child: _buildTabContent()),
                      _buildFooter(),
                    ],
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
      color: Colors.white,
      child: Row(
        children: [
          Material(
            color: OtterColors.grayLight,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _goBack,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(LucideIcons.chevronLeft, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.isEditMode ? 'Редактирование задачи' : 'Новая задача',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: OtterColors.sberBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Название задачи',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OtterColors.sberBlack,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            onTapOutside: dismissKeyboardOnTapOutside,
            decoration: InputDecoration(
              hintText: 'Например: отчёт, созвон, встреча…',
              filled: true,
              fillColor: OtterColors.grayLight,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: OtterColors.grayMid),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: OtterColors.sberGreen,
                  width: 2,
                ),
              ),
            ),
          ),
          if (!widget.isEditMode) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _descOpen = !_descOpen),
              child: Text(
                _descOpen
                    ? '− Скрыть описание'
                    : '+ Описание (необязательно)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OtterColors.sberGreen,
                ),
              ),
            ),
          ],
          if (widget.isEditMode || _descOpen) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              maxLines: 2,
              onTapOutside: dismissKeyboardOnTapOutside,
              decoration: InputDecoration(
                hintText: 'Детали, ссылки…',
                filled: true,
                fillColor: OtterColors.grayLight,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                showAppToast(context, 'Вложения скоро будут доступны'),
            icon: const Icon(LucideIcons.paperclip, size: 14),
            label: const Text(
              'Файл / фото',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: OtterColors.sberGreen,
              backgroundColor: OtterColors.sberGreenLight,
              side: BorderSide(color: OtterColors.sberGreen.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    const tabs = [
      (_TaskFormTab.date, LucideIcons.calendar, 'Дата', false),
      (_TaskFormTab.priority, LucideIcons.flag, 'Приоритет', false),
      (_TaskFormTab.notify, LucideIcons.bell, 'Уведомление', true),
      (_TaskFormTab.repeat, LucideIcons.refreshCw, 'Повтор', true),
      (_TaskFormTab.matrix, LucideIcons.grid2x2, 'Матрица', true),
    ];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: OtterColors.grayLight)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: tabs.map((t) {
            final active = _activeTab == t.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 2),
              child: InkWell(
                onTap: () => setState(() => _activeTab = t.$1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: t.$4 ? 10 : 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active ? OtterColors.sberGreenLight : null,
                    border: Border(
                      bottom: BorderSide(
                        color: active
                            ? OtterColors.sberGreen
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        t.$2,
                        size: 14,
                        color: active
                            ? OtterColors.sberGreen
                            : OtterColors.sberGray,
                      ),
                      if (!t.$4) ...[
                        const SizedBox(width: 4),
                        Text(
                          t.$3,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: active
                                ? OtterColors.sberGreen
                                : OtterColors.sberGray,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: switch (_activeTab) {
        _TaskFormTab.date => _buildDateTab(),
        _TaskFormTab.priority => _buildPriorityTab(),
        _TaskFormTab.notify => _buildNotifyTab(),
        _TaskFormTab.repeat => _buildRepeatTab(),
        _TaskFormTab.matrix => _buildMatrixTab(),
      },
    );
  }

  Widget _buildDateTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Дата выполнения'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _QuickChip(
              label: 'Сегодня',
              selected: _isQuickDateActive('today'),
              onTap: () => _setQuickDate('today'),
            ),
            _QuickChip(
              label: 'Завтра',
              selected: _isQuickDateActive('tomorrow'),
              onTap: () => _setQuickDate('tomorrow'),
            ),
            _QuickChip(
              label: 'Без срока',
              selected: _isQuickDateActive('none'),
              onTap: () => _setQuickDate('none'),
            ),
          ],
        ),
        if (!_explicitNoDeadline) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateTimeField(
                  label: 'Дата',
                  value: _displayDate(_dueDate),
                  icon: LucideIcons.calendar,
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateTimeField(
                  label: 'Время срока',
                  value: _formatTime(_dueTime) ?? 'ЧЧ:ММ',
                  icon: LucideIcons.clock,
                  onTap: () => _pickTime(
                    initial: _dueTime,
                    onPicked: _applyDueTimeSync,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateTimeField(
                  label: 'Начало',
                  value: _formatTime(_durationStart) ?? 'ЧЧ:ММ',
                  icon: LucideIcons.clock,
                  onTap: () => _pickTime(
                    initial: _durationStart,
                    onPicked: _applyStartSync,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateTimeField(
                  label: 'Конец',
                  value: _formatTime(_durationEnd) ?? 'ЧЧ:ММ',
                  icon: LucideIcons.clock,
                  onTap: () => _pickTime(
                    initial: _durationEnd,
                    onPicked: (t) => setState(() {
                      _durationEnd = t;
                      _error = null;
                    }),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 12,
                color: OtterColors.priorityHigh,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPriorityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Приоритет'),
        const SizedBox(height: 8),
        ...Priority.values.map((p) {
          final selected = _priority == p;
          final color = priorityColor(p);
          final label = p == Priority.none ? 'Без приоритета' : priorityLabel(p);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _SelectCard(
              selected: selected,
              selectedColor: color,
              onTap: () => setState(() => _priority = p),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected ? color : OtterColors.sberBlack,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      LucideIcons.check,
                      size: 16,
                      color: OtterColors.sberGreen,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNotifyTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Уведомление'),
        const SizedBox(height: 8),
        ..._notifyOptions.map((n) {
          final selected = (_notification ?? '') == n.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _SelectCard(
              selected: selected,
              selectedColor: OtterColors.sberGreen,
              onTap: () => setState(() => _notification = n.value),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.bell,
                    size: 16,
                    color: selected
                        ? OtterColors.sberGreen
                        : OtterColors.sberGray,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      n.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? OtterColors.sberGreen
                            : OtterColors.sberBlack,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      LucideIcons.check,
                      size: 16,
                      color: OtterColors.sberGreen,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRepeatTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Повторение'),
        const SizedBox(height: 8),
        ..._repeatOptions.map((r) {
          final selected = _repeat == r.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _SelectCard(
              selected: selected,
              selectedColor: OtterColors.sberGreen,
              onTap: () => setState(() => _repeat = r.value),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.refreshCw,
                    size: 16,
                    color: selected
                        ? OtterColors.sberGreen
                        : OtterColors.sberGray,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? OtterColors.sberGreen
                            : OtterColors.sberBlack,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      LucideIcons.check,
                      size: 16,
                      color: OtterColors.sberGreen,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMatrixTab() {
    final settings = ref.watch(matrixSettingsProvider).blocks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Блок матрицы'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: kMatrixBlockThemes.map((theme) {
            final selected = _matrix == theme.block;
            final title =
                settings[theme.block]?.title ?? theme.defaultTitle;
            return Material(
              color: selected
                  ? theme.accent.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => setState(() => _matrix = theme.block),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? theme.accent
                          : OtterColors.grayLight,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: OtterColors.sberBlack,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: OtterColors.grayLight)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _loading ? null : _goBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: OtterColors.sberBlack,
                backgroundColor: OtterColors.grayLight,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Отмена',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _loading ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: OtterColors.sberGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.isEditMode ? 'Сохранить' : 'Добавить задачу',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: OtterColors.sberGray,
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? OtterColors.sberGreen : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? OtterColors.sberGreen : OtterColors.grayMid,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : OtterColors.sberBlack,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != 'ДД.ММ.ГГГГ' && value != 'ЧЧ:ММ';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: OtterColors.sberGray,
          ),
        ),
        const SizedBox(height: 4),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: OtterColors.sberGreen.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: hasValue
                            ? OtterColors.sberBlack
                            : OtterColors.sberGray,
                      ),
                    ),
                  ),
                  Icon(icon, size: 14, color: OtterColors.sberGray),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.selected,
    required this.selectedColor,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? selectedColor.withValues(alpha: 0.08)
          : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? selectedColor : OtterColors.grayLight,
              width: selected ? 2 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
