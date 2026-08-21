import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/premium/premium_required.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/theme/otter_theme.dart';
import '../../core/theme/priority_colors.dart';
import '../../core/utils/media_url.dart';
import '../../core/utils/time_utils.dart';
import '../../data/mappers/task_mapper.dart';
import '../../data/models/ui/ui_models.dart';
import '../../features/matrix/matrix_constants.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/keyboard_dismisser.dart';
import '../../shared/widgets/ru_date_time_fields.dart';
import '../../shared/widgets/select_field.dart';
import 'task_attachment_picker.dart';
import 'task_time_sync.dart';

Future<void> showTaskDetailSheet(BuildContext context, Task task) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(taskEditorOverlayProvider.notifier).state = true;
  return showAppBottomSheet<void>(
    context: context,
    dialogMaxWidth: 560,
    builder: (ctx) => TaskDetailSheet(task: task),
  ).whenComplete(() {
    container.read(taskEditorOverlayProvider.notifier).state = false;
  });
}

class TaskDetailSheet extends ConsumerStatefulWidget {
  const TaskDetailSheet({
    super.key,
    required this.task,
    this.embedded = false,
    this.onClosed,
  });

  final Task task;

  /// When true, renders as an inline desktop editor panel (web split view).
  final bool embedded;

  /// Called instead of [Navigator.pop] when [embedded] is true.
  final VoidCallback? onClosed;

  @override
  ConsumerState<TaskDetailSheet> createState() => TaskDetailSheetState();
}

class TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  TimeOfDay? _durationStart;
  TimeOfDay? _durationEnd;
  late Priority _priority;
  String? _notification;
  late RepeatType _repeat;
  late MatrixBlock _matrix;
  late final TextEditingController _customIntervalCtrl;
  late final TextEditingController _customMonthDayCtrl;
  int _customRepeatInterval = 1;
  String _customRepeatUnit = 'week';
  List<int> _customWeekdays = [1];
  int? _customMonthDay;
  String? _repeatIntervalError;
  String? _repeatWeekdaysError;
  String? _repeatMonthDayError;
  String? _imagePath;
  String? _existingImageUrl;
  String? _attachmentName;
  String? _attachmentMimeType;
  int? _attachmentId;
  final List<int> _serverAttachmentIds = [];
  bool _clearImage = false;
  bool _saving = false;
  bool _closePromptOpen = false;
  String? _error;
  String _formSnapshot = '';
  final _timeSync = TaskTimeSync();

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
    (value: RepeatType.custom, label: 'Настроить повторение'),
  ];

  static const _weekDays = [
    (value: 1, label: 'Пн'),
    (value: 2, label: 'Вт'),
    (value: 3, label: 'Ср'),
    (value: 4, label: 'Чт'),
    (value: 5, label: 'Пт'),
    (value: 6, label: 'Сб'),
    (value: 7, label: 'Вс'),
  ];

  @override
  void initState() {
    super.initState();
    // Keep controllers for State lifetime (GlobalKey reuses this State on desktop task switch).
    _title = TextEditingController();
    _description = TextEditingController();
    _customIntervalCtrl = TextEditingController(text: '1');
    _customMonthDayCtrl = TextEditingController();
    _syncFromTask(widget.task);
    _formSnapshot = _serializeForm();
    Future.microtask(() => ref.read(matrixSettingsProvider.notifier).load());
  }

  @override
  void didUpdateWidget(covariant TaskDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id) {
      // Update in place — dispose/recreate broke the right pane (late final + attached fields).
      _syncFromTask(widget.task);
      _formSnapshot = _serializeForm();
      _error = null;
      setState(() {});
    }
  }

  void _finishClose() {
    if (widget.embedded) {
      widget.onClosed?.call();
      return;
    }
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Map<String, Object?> _formPayload() {
    final weekdays = List<int>.from(_customWeekdays)..sort();
    return {
      'title': _title.text,
      'description': _description.text,
      'priority': _priority.name,
      'notification': _notification ?? '',
      'repeat': _repeat.name,
      'matrix': _matrix.name,
      'dueDate': _formatDate(_dueDate),
      'dueTime': _formatTime(_dueTime),
      'durationStart': _formatTime(_durationStart),
      'durationEnd': _formatTime(_durationEnd),
      'customInterval': _customIntervalCtrl.text,
      'customUnit': _customRepeatUnit,
      'customWeekdays': weekdays,
      'customMonthDay': _customMonthDayCtrl.text,
      'imagePath': _imagePath,
      'clearImage': _clearImage,
      'attachmentName': _attachmentName,
      'existingImageUrl': _existingImageUrl,
    };
  }

  String _serializeForm() => jsonEncode(_formPayload());

  bool get _isDirty => _serializeForm() != _formSnapshot;

  void _syncFromTask(Task task) {
    _title.text = task.title;
    _description.text = task.description ?? '';
    _priority = task.priority;
    _notification = task.notification ?? '';
    _repeat = task.repeat;
    _matrix = task.matrixBlock ?? MatrixBlock.notUrgentNotImportant;
    _customRepeatInterval = task.repeatCustom?.interval ?? 1;
    _customRepeatUnit = task.repeatCustom?.unit ?? 'week';
    _customWeekdays = task.repeatCustom?.weekdays?.isNotEmpty == true
        ? List<int>.from(task.repeatCustom!.weekdays!)
        : (task.repeatDays?.isNotEmpty == true
              ? List<int>.from(task.repeatDays!)
              : [1]);
    _customMonthDay = task.repeatCustom?.monthDay;
    _customIntervalCtrl.text = '$_customRepeatInterval';
    _customMonthDayCtrl.text =
        _customMonthDay == null ? '' : '$_customMonthDay';
    _existingImageUrl = task.imageUrl;
    _attachmentId = task.attachmentId;
    _attachmentName = task.attachmentName;
    _attachmentMimeType = task.attachmentMimeType;
    _serverAttachmentIds
      ..clear()
      ..addAll([
        for (final a in task.attachments)
          if (a.id != null) a.id!,
      ]);
    if (_attachmentId != null &&
        !_serverAttachmentIds.contains(_attachmentId)) {
      _serverAttachmentIds.add(_attachmentId!);
    }
    _clearImage = false;
    _imagePath = null;
    _dueDate =
        task.dueDate != null ? DateTime.tryParse(task.dueDate!) : null;
    _dueTime = _parseTime(task.dueTime);
    _durationStart = _parseTime(task.duration?.start);
    _durationEnd = _parseTime(task.duration?.end);
    if (_durationStart != null && _durationEnd == null) {
      _durationEnd = _parseTime(
        defaultDurationEnd(_formatTime(_durationStart)!),
      );
    }
    _timeSync.adoptLoadedDuration(
      _formatTime(_durationStart),
      _formatTime(_durationEnd),
    );
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

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _customIntervalCtrl.dispose();
    _customMonthDayCtrl.dispose();
    super.dispose();
  }

  bool get _hasClock => _dueTime != null || _durationStart != null;

  void _selectNotification(String value) {
    if (!_hasClock && value.isNotEmpty) {
      showAppToast(
        context,
        'Без времени срока напоминание не отправляется. Сначала укажите время срока.',
      );
      return;
    }
    setState(() => _notification = value);
  }

  void _applyDueTimeSync(TimeOfDay time) {
    final formatted = _formatTime(time)!;
    _timeSync.onDueTimeChanged(
      formatted,
      _formatTime(_durationEnd),
      (start, end) {
        setState(() {
          final hadClock = _dueTime != null || _durationStart != null;
          _dueTime = time;
          _durationStart = _parseTime(start);
          _durationEnd = _parseTime(end);
          if (!hadClock && (_notification == null || _notification!.isEmpty)) {
            _notification = '0';
          }
          _error = null;
        });
      },
    );
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

  void _applyEndManual(TimeOfDay time) {
    setState(() {
      _durationEnd = time;
      _timeSync.markEndEdited();
      _error = null;
    });
  }

  void _selectMatrixBlock(MatrixBlock block) {
    if (!isPremiumActive(ref)) {
      openPremiumSubscription(context);
      return;
    }
    setState(() => _matrix = block);
  }

  Future<bool> _save({bool closeOnSuccess = true}) async {
    final durationError = validateDurationFields(
      _formatTime(_durationStart),
      _formatTime(_durationEnd),
    );
    if (durationError != null) {
      setState(() => _error = durationError);
      return false;
    }

    if (_repeat == RepeatType.custom) {
      _customRepeatInterval = int.tryParse(_customIntervalCtrl.text) ?? 1;
      final intervalError = validateRepeatInterval(_customRepeatInterval);
      if (intervalError != null) {
        setState(() {
          _repeatIntervalError = intervalError;
          _error = intervalError;
        });
        return false;
      }
      if (_customRepeatUnit == 'week' && _customWeekdays.isEmpty) {
        setState(() {
          _repeatWeekdaysError = 'Выберите хотя бы один день недели';
          _error = _repeatWeekdaysError;
        });
        return false;
      }
      if (_customRepeatUnit == 'month') {
        _customMonthDay = int.tryParse(_customMonthDayCtrl.text);
        if (_customMonthDay == null ||
            _customMonthDay! < 1 ||
            _customMonthDay! > 31) {
          setState(() {
            _repeatMonthDayError = 'Укажите день месяца от 1 до 31';
            _error = _repeatMonthDayError;
          });
          return false;
        }
      }
    }

    TaskDuration? duration;
    if (_durationStart != null && _durationEnd != null) {
      duration = TaskDuration(
        start: _formatTime(_durationStart)!,
        end: _formatTime(_durationEnd)!,
      );
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(tasksStateProvider.notifier)
          .updateTask(
            widget.task.id,
            PartialTask(
              title: _title.text.trim(),
              description: _description.text.trim().isEmpty
                  ? null
                  : _description.text.trim(),
              clearDescription: _description.text.trim().isEmpty,
              dueDate: _formatDate(_dueDate),
              dueTime: _formatTime(_dueTime),
              duration: duration,
              clearDueDate: _dueDate == null,
              clearDueTime: _formatTime(_dueTime) == null,
              clearDuration: duration == null,
              priority: _priority,
              notification: (_notification == null || _notification!.isEmpty)
                  ? null
                  : _notification,
              clearNotification:
                  _notification == null || _notification!.isEmpty,
              repeat: _repeat,
              repeatDays: _repeat == RepeatType.custom && _customRepeatUnit == 'week'
                  ? List<int>.from(_customWeekdays)
                  : null,
              repeatCustom: _repeat == RepeatType.custom
                  ? RepeatCustom(
                      interval: _customRepeatInterval,
                      unit: _customRepeatUnit,
                      weekdays: _customRepeatUnit == 'week'
                          ? List<int>.from(_customWeekdays)
                          : null,
                      monthDay:
                          _customRepeatUnit == 'month' ? _customMonthDay : null,
                    )
                  : null,
              matrixBlock: _matrix,
              imagePath: _imagePath,
              clearImage: _clearImage && _imagePath == null,
              deleteAttachmentIds: (_clearImage || _imagePath != null)
                  ? List<int>.from(_serverAttachmentIds)
                  : null,
            ),
          );
      if (mounted) {
        await ref.read(matrixStateProvider.notifier).load();
        _formSnapshot = _serializeForm();
        if (closeOnSuccess) _finishClose();
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _error = getApiErrorMessage(e));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAttachment() async {
    KeyboardDismisser.dismiss();
    final picked = await pickTaskAttachment(context);
    if (picked == null || !mounted) return;
    setState(() {
      _imagePath = picked.path;
      _attachmentName = picked.name;
      _attachmentMimeType = picked.mimeType;
      _clearImage = false;
    });
  }

  void _clearAttachment() {
    setState(() {
      _imagePath = null;
      _existingImageUrl = null;
      _attachmentName = null;
      _attachmentMimeType = null;
      _clearImage = true;
    });
  }

  Future<void> _openExistingAttachment() async {
    final url = resolveMediaUrl(_existingImageUrl);
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool get _attachmentIsImage {
    final mime = _attachmentMimeType ?? '';
    if (mime.startsWith('image/')) return true;
    final name = (_attachmentName ?? _imagePath ?? _existingImageUrl ?? '')
        .toLowerCase();
    return name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.gif') ||
        name.endsWith('.webp') ||
        name.endsWith('.heic');
  }

  Widget _fieldLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: OtterColors.muted(isDark),
        ),
      ),
    );
  }

  InputDecoration _textDecoration({String? hint, required bool isDark}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: OtterColors.muted(isDark),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: OtterColors.surfaceAlt(isDark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: OtterColors.border(isDark)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: OtterColors.sberGreen, width: 2),
      ),
    );
  }

  Future<void> _delete() async {
    final task = widget.task;
    if (task.repeat != RepeatType.none) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Удалить повторяющуюся задачу?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Выберите, что именно удалить.',
                  style: TextStyle(fontSize: 13, color: OtterColors.sberGray),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'occurrence'),
                  child: const Text('Удалить только этот повтор'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, 'series'),
                  child: const Text('Удалить все повторения'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (choice == 'occurrence') {
        await ref.read(tasksStateProvider.notifier).deleteOccurrence(task);
      } else if (choice == 'series') {
        await ref.read(tasksStateProvider.notifier).deleteSeries(task.id);
      } else {
        return;
      }
    } else {
      await ref.read(tasksStateProvider.notifier).deleteTask(task.id);
    }
    if (mounted) _finishClose();
  }

  Future<void> _toggleComplete() async {
    await ref.read(tasksStateProvider.notifier).completeTask(widget.task);
    if (mounted) _finishClose();
  }

  Future<void> _requestClose() async {
    if (_saving || _closePromptOpen) return;
    if (!_isDirty) {
      if (mounted) _finishClose();
      return;
    }

    _closePromptOpen = true;
    final action = await _showUnsavedChangesDialog();
    _closePromptOpen = false;
    if (!mounted) return;

    switch (action) {
      case _UnsavedAction.save:
        await _save(closeOnSuccess: true);
      case _UnsavedAction.discard:
        _finishClose();
      case _UnsavedAction.cancel:
      case null:
        break;
    }
  }

  /// Web parity: guard leaving the editor (other task / clear / group switch).
  /// Returns `true` when the caller may proceed.
  Future<bool> confirmLeave() async {
    if (_saving || _closePromptOpen) return false;
    if (!_isDirty) return true;

    _closePromptOpen = true;
    final action = await _showUnsavedChangesDialog();
    _closePromptOpen = false;
    if (!mounted) return false;

    switch (action) {
      case _UnsavedAction.save:
        return _save(closeOnSuccess: false);
      case _UnsavedAction.discard:
        return true;
      case _UnsavedAction.cancel:
      case null:
        return false;
    }
  }

  Future<_UnsavedAction?> _showUnsavedChangesDialog() {
    final isDark = OtterColors.isDarkOf(context);
    return showDialog<_UnsavedAction>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: OtterColors.surface(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Сохранить изменения?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: OtterColors.text(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Есть несохранённые правки в задаче.',
                    style: TextStyle(
                      fontSize: 14,
                      color: OtterColors.muted(isDark),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(ctx, _UnsavedAction.save),
                    style: FilledButton.styleFrom(
                      backgroundColor: OtterColors.sberGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Сохранить',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(ctx, _UnsavedAction.discard),
                    style: FilledButton.styleFrom(
                      foregroundColor: OtterColors.text(isDark),
                      backgroundColor: OtterColors.elevated(isDark),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Не сохранять',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(ctx, _UnsavedAction.cancel),
                    child: Text(
                      'Отмена',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OtterColors.muted(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final settingsDark =
        ref.watch(appSettingsProvider.select((s) => s.theme == 'dark'));
    final isDark = settingsDark || OtterColors.isDarkOf(context);
    final sheetTheme = isDark ? OtterTheme.dark() : OtterTheme.light();
    final surfaceAltColor = OtterColors.surfaceAlt(isDark);
    final borderSubtle = OtterColors.border(isDark);
    final notifyValue = _notification ?? '';
    final completed = widget.task.completed;

    final form = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: widget.embedded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (widget.embedded) ...[
              Text(
                widget.task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: OtterColors.text(isDark),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Priority chip (web TaskDetailModal)
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () async {
                  final picked = await showSelectSheet<Priority>(
                    context: context,
                    title: 'Приоритет',
                    items: Priority.values,
                    itemLabel: priorityLabel,
                    selected: _priority,
                    itemBuilder: (context, item, _) =>
                        prioritySelectDot(item),
                  );
                  if (picked != null) setState(() => _priority = picked);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor(_priority).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      prioritySelectDot(_priority, size: 10),
                      const SizedBox(width: 8),
                      Text(
                        priorityLabel(_priority),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: priorityColor(_priority),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.chevronDown,
                        size: 14,
                        color: priorityColor(_priority),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _fieldLabel('Название', isDark),
            TextField(
              controller: _title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: OtterColors.text(isDark),
              ),
              onTapOutside: dismissKeyboardOnTapOutside,
              decoration: _textDecoration(isDark: isDark),
            ),
            const SizedBox(height: 12),

            _fieldLabel('Описание', isDark),
            TextField(
              controller: _description,
              minLines: widget.embedded ? 2 : 3,
              maxLines: widget.embedded ? 4 : 5,
              style: TextStyle(color: OtterColors.text(isDark)),
              onTapOutside: dismissKeyboardOnTapOutside,
              decoration: _textDecoration(hint: 'Детали, ссылки…', isDark: isDark),
            ),
            const SizedBox(height: 12),

            _fieldLabel('Вложения', isDark),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _pickAttachment,
                icon: const Icon(LucideIcons.paperclip, size: 16),
                label: Text(
                  _imagePath != null
                      ? 'Файл выбран'
                      : (_existingImageUrl != null && !_clearImage)
                          ? 'Заменить файл'
                          : 'Добавить изображение или файл',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OtterColors.sberGreen,
                  backgroundColor: OtterColors.greenTint(isDark),
                  side: BorderSide(
                    color: OtterColors.sberGreen.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_imagePath != null ||
                (_existingImageUrl != null && !_clearImage)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OtterColors.elevated(isDark).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _attachmentIsImage && _imagePath != null
                          ? Image.file(
                              File(_imagePath!),
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            )
                          : _attachmentIsImage &&
                                  _existingImageUrl != null &&
                                  !_clearImage
                              ? Image.network(
                                  resolveMediaUrl(_existingImageUrl),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(LucideIcons.file, size: 24),
                                )
                              : Container(
                                  width: 56,
                                  height: 56,
                                  color: OtterColors.elevated(isDark),
                                  alignment: Alignment.center,
                                  child: const Icon(LucideIcons.file, size: 24),
                                ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _attachmentName ??
                                _imagePath?.split(Platform.pathSeparator).last ??
                                'Вложение',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: OtterColors.text(isDark),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (_existingImageUrl != null &&
                                  _imagePath == null &&
                                  !_clearImage)
                                TextButton(
                                  onPressed: _openExistingAttachment,
                                  child: const Text('Открыть'),
                                ),
                              TextButton(
                                onPressed: _clearAttachment,
                                child: const Text('Удалить'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Date / time grid — editable like web DateFieldRu / TimeFieldRu
            Row(
              children: [
                Expanded(
                  child: RuDateField(
                    label: 'Дата',
                    value: _dueDate,
                    onChanged: (date) {
                      setState(() {
                        _dueDate = date;
                        if (date == null) {
                          _dueTime = null;
                          _durationStart = null;
                          _durationEnd = null;
                          _timeSync.resetEndEdited();
                          _notification = '';
                        }
                        _error = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RuTimeField(
                    label: 'Время срока',
                    value: _dueTime,
                    onChanged: (time) {
                      if (time == null) {
                        setState(() {
                          _dueTime = null;
                          if (_durationStart == null) _notification = '';
                          _error = null;
                        });
                        return;
                      }
                      _applyDueTimeSync(time);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RuTimeField(
                    label: 'Начало',
                    value: _durationStart,
                    onChanged: (time) {
                      if (time == null) {
                        setState(() {
                          _durationStart = null;
                          _error = null;
                        });
                        return;
                      }
                      _applyStartSync(time);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RuTimeField(
                    label: 'Конец',
                    value: _durationEnd,
                    onChanged: (time) {
                      if (time == null) {
                        setState(() {
                          _durationEnd = null;
                          _timeSync.resetEndEdited();
                          _error = null;
                        });
                        return;
                      }
                      _applyEndManual(time);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            SelectField<String>(
              label: 'Уведомление',
              value: notifyValue,
              items: _notifyOptions.map((e) => e.value).toList(),
              itemLabel: (v) =>
                  _notifyOptions.firstWhere((e) => e.value == v).label,
              onChanged: _selectNotification,
            ),
            const SizedBox(height: 12),

            SelectField<RepeatType>(
              label: 'Повтор',
              value: _repeat,
              items: _repeatOptions.map((e) => e.value).toList(),
              itemLabel: (v) =>
                  _repeatOptions.firstWhere((e) => e.value == v).label,
              onChanged: (v) => setState(() {
                _repeat = v;
                _repeatIntervalError = null;
                _repeatWeekdaysError = null;
                _repeatMonthDayError = null;
                _error = null;
              }),
            ),
            if (_repeat == RepeatType.custom) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OtterColors.greenTint(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: OtterColors.sberGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'НАСТРОИТЬ ПОВТОРЕНИЕ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: OtterColors.muted(isDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Каждые',
                          style: TextStyle(
                            fontSize: 14,
                            color: OtterColors.muted(isDark),
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: _customIntervalCtrl,
                            keyboardType: TextInputType.number,
                            onTapOutside: dismissKeyboardOnTapOutside,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: OtterColors.text(isDark),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              errorText: _repeatIntervalError,
                              filled: true,
                              fillColor: OtterColors.surface(isDark),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (_) => setState(() {
                              _repeatIntervalError = null;
                              _error = null;
                            }),
                          ),
                        ),
                        _DetailUnitChip(
                          label: 'Недели',
                          selected: _customRepeatUnit == 'week',
                          isDark: isDark,
                          onTap: () => setState(() {
                            _customRepeatUnit = 'week';
                            _repeatIntervalError = null;
                            _repeatWeekdaysError = null;
                            _error = null;
                          }),
                        ),
                        _DetailUnitChip(
                          label: 'Месяца',
                          selected: _customRepeatUnit == 'month',
                          isDark: isDark,
                          onTap: () => setState(() {
                            _customRepeatUnit = 'month';
                            _repeatIntervalError = null;
                            _repeatMonthDayError = null;
                            _error = null;
                          }),
                        ),
                      ],
                    ),
                    if (_customRepeatUnit == 'week') ...[
                      const SizedBox(height: 12),
                      Text(
                        'ДНИ НЕДЕЛИ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: OtterColors.muted(isDark),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _weekDays.map((day) {
                          final selected = _customWeekdays.contains(day.value);
                          return InkWell(
                            onTap: () {
                              KeyboardDismisser.dismiss();
                              setState(() {
                                if (selected) {
                                  final next = _customWeekdays
                                      .where((d) => d != day.value)
                                      .toList();
                                  // Keep at least one day selected like web.
                                  _customWeekdays =
                                      next.isEmpty ? [day.value] : next;
                                } else {
                                  _customWeekdays = [..._customWeekdays, day.value]
                                    ..sort();
                                }
                                _repeatWeekdaysError = null;
                                _error = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? OtterColors.sberGreen
                                    : OtterColors.surface(isDark),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? OtterColors.sberGreen
                                      : (_repeatWeekdaysError != null
                                          ? OtterColors.priorityHigh
                                          : OtterColors.border(isDark)),
                                ),
                              ),
                              child: Text(
                                day.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : OtterColors.muted(isDark),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_repeatWeekdaysError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _repeatWeekdaysError!,
                          style: const TextStyle(
                            color: OtterColors.priorityHigh,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                    if (_customRepeatUnit == 'month') ...[
                      const SizedBox(height: 12),
                      Text(
                        'ДЕНЬ МЕСЯЦА',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: OtterColors.muted(isDark),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 112,
                        child: TextField(
                          controller: _customMonthDayCtrl,
                          keyboardType: TextInputType.number,
                          onTapOutside: dismissKeyboardOnTapOutside,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: OtterColors.text(isDark),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            errorText: _repeatMonthDayError,
                            filled: true,
                            fillColor: OtterColors.surface(isDark),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (_) => setState(() {
                            _repeatMonthDayError = null;
                            _error = null;
                          }),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            _fieldLabel('Матрица Эйзенхауэра', isDark),
            Builder(
              builder: (context) {
                final settings = ref.watch(matrixSettingsProvider).blocks;
                // Match web TaskDetailModal: compact grid-cols-4 chips.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < kMatrixBlockThemes.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final theme = kMatrixBlockThemes[i];
                            final selected = _matrix == theme.block;
                            final title = settings[theme.block]?.title ??
                                theme.defaultTitle;
                            return Material(
                              color: selected
                                  ? theme.accent.withValues(alpha: 0.08)
                                  : surfaceAltColor,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => _selectMatrixBlock(theme.block),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? theme.accent
                                          : borderSubtle,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: theme.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        title,
                                        textAlign: TextAlign.center,
                                        softWrap: true,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9,
                                          height: 1.2,
                                          fontWeight: FontWeight.w500,
                                          color: OtterColors.text(isDark),
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
                    ],
                  ],
                );
              },
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: OtterColors.priorityHigh,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Footer like web: Save | Complete | Delete | Cancel in one row.
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: OtterColors.sberGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _saving ? '…' : 'Сохранить',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _toggleComplete,
                    style: FilledButton.styleFrom(
                      foregroundColor: completed
                          ? OtterColors.sberBlue
                          : OtterColors.sberGreen,
                      backgroundColor: completed
                          ? OtterColors.sberBlue.withValues(alpha: 0.12)
                          : OtterColors.greenTint(isDark),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      completed ? 'Восстановить' : 'Выполнено',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _delete,
                    style: FilledButton.styleFrom(
                      foregroundColor: OtterColors.priorityHigh,
                      backgroundColor:
                          OtterColors.priorityHigh.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Удалить',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _requestClose,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OtterColors.text(isDark),
                      backgroundColor: OtterColors.elevated(isDark),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
    );

    final scrollable = SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: widget.embedded
          ? const EdgeInsets.fromLTRB(20, 12, 20, 16)
          : EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: form,
    );

    return Theme(
      data: sheetTheme,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _requestClose();
        },
        child: widget.embedded
            ? Material(
                color: OtterColors.surface(isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: scrollable),
                  ],
                ),
              )
            : scrollable,
      ),
    );
  }
}

enum _UnsavedAction { save, discard, cancel }

class _DetailUnitChip extends StatelessWidget {
  const _DetailUnitChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? OtterColors.sberGreen : OtterColors.surface(isDark),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? OtterColors.sberGreen : OtterColors.border(isDark),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : OtterColors.text(isDark),
            ),
          ),
        ),
      ),
    );
  }
}
