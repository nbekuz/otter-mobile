import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/theme/priority_colors.dart';
import '../../core/utils/media_url.dart';
import '../../core/utils/time_utils.dart';
import '../../data/mappers/task_mapper.dart';
import '../../data/models/ui/ui_models.dart';
import '../../features/matrix/matrix_constants.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/keyboard_dismisser.dart';
import '../../shared/widgets/ru_date_time_fields.dart';
import '../../shared/widgets/select_field.dart';
import 'task_attachment_picker.dart';
import 'task_time_sync.dart';

Future<void> showTaskDetailSheet(BuildContext context, Task task) {
  return showAppBottomSheet<void>(
    context: context,
    dialogMaxWidth: 560,
    builder: (ctx) => TaskDetailSheet(task: task),
  );
}

class TaskDetailSheet extends ConsumerStatefulWidget {
  const TaskDetailSheet({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
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
  String? _imagePath;
  String? _existingImageUrl;
  String? _attachmentName;
  String? _attachmentMimeType;
  int? _attachmentId;
  final List<int> _serverAttachmentIds = [];
  bool _clearImage = false;
  bool _saving = false;
  String? _error;
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

  @override
  void initState() {
    super.initState();
    _syncFromTask(widget.task);
    Future.microtask(() => ref.read(matrixSettingsProvider.notifier).load());
  }

  void _syncFromTask(Task task) {
    _title = TextEditingController(text: task.title);
    _description = TextEditingController(text: task.description ?? '');
    _priority = task.priority;
    _notification = task.notification ?? '';
    _repeat = task.repeat;
    _matrix = task.matrixBlock ?? MatrixBlock.notUrgentNotImportant;
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
    if (task.dueDate != null) {
      _dueDate = DateTime.tryParse(task.dueDate!);
    }
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
    super.dispose();
  }

  void _applyDueTimeSync(TimeOfDay time) {
    final formatted = _formatTime(time)!;
    _timeSync.onDueTimeChanged(
      formatted,
      _formatTime(_durationEnd),
      (start, end) {
        setState(() {
          _dueTime = time;
          _durationStart = _parseTime(start);
          _durationEnd = _parseTime(end);
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

  Future<void> _save() async {
    final durationError = validateDurationFields(
      _formatTime(_durationStart),
      _formatTime(_durationEnd),
    );
    if (durationError != null) {
      setState(() => _error = durationError);
      return;
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
              repeatDays: _repeat == RepeatType.custom
                  ? widget.task.repeatDays
                  : null,
              repeatCustom: _repeat == RepeatType.custom
                  ? widget.task.repeatCustom
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
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = getApiErrorMessage(e));
      }
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

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: OtterColors.sberGray,
        ),
      ),
    );
  }

  InputDecoration _textDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: OtterColors.grayLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: OtterColors.grayMid),
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
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleComplete() async {
    await ref.read(tasksStateProvider.notifier).completeTask(widget.task);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceAlt = isDark ? OtterColors.darkSurfaceAlt : Colors.white;
    final borderSubtle =
        isDark ? OtterColors.darkBorder : OtterColors.grayLight;
    final notifyValue = _notification ?? '';
    final completed = widget.task.completed;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
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

            _fieldLabel('Название'),
            TextField(
              controller: _title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              onTapOutside: dismissKeyboardOnTapOutside,
              decoration: _textDecoration(),
            ),
            const SizedBox(height: 12),

            _fieldLabel('Описание'),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              onTapOutside: dismissKeyboardOnTapOutside,
              decoration: _textDecoration(hint: 'Детали, ссылки…'),
            ),
            const SizedBox(height: 12),

            _fieldLabel('Вложения'),
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
                  backgroundColor: OtterColors.sberGreenLight,
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
                  color: (isDark
                          ? OtterColors.darkSurfaceAlt
                          : OtterColors.grayLight)
                      .withValues(alpha: 0.6),
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
                                  color: surfaceAlt,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    LucideIcons.file,
                                    size: 24,
                                    color: OtterColors.sberGray,
                                  ),
                                ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _imagePath == null &&
                                _existingImageUrl != null &&
                                !_clearImage
                            ? _openExistingAttachment
                            : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _attachmentName ??
                                  _imagePath?.split('/').last ??
                                  'Вложение',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _imagePath == null &&
                                        _existingImageUrl != null &&
                                        !_clearImage
                                    ? OtterColors.sberGreen
                                    : OtterColors.sberBlack,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _attachmentIsImage
                                  ? 'Изображение прикреплено'
                                  : 'Файл прикреплен',
                              style: const TextStyle(
                                fontSize: 12,
                                color: OtterColors.sberGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Удалить вложение',
                      onPressed: _clearAttachment,
                      icon: const Icon(LucideIcons.x, size: 18),
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
              onChanged: (v) => setState(() => _notification = v),
            ),
            const SizedBox(height: 12),

            SelectField<RepeatType>(
              label: 'Повтор',
              value: _repeat,
              items: _repeatOptions.map((e) => e.value).toList(),
              itemLabel: (v) =>
                  _repeatOptions.firstWhere((e) => e.value == v).label,
              onChanged: (v) => setState(() => _repeat = v),
            ),
            const SizedBox(height: 12),

            _fieldLabel('Матрица Эйзенхауэра'),
            Builder(
              builder: (context) {
                final settings = ref.watch(matrixSettingsProvider).blocks;
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.55,
                  children: kMatrixBlockThemes.map((theme) {
                    final selected = _matrix == theme.block;
                    final title =
                        settings[theme.block]?.title ?? theme.defaultTitle;
                    return Material(
                      color: selected
                          ? theme.accent.withValues(alpha: 0.08)
                          : surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => setState(() => _matrix = theme.block),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? theme.accent : borderSubtle,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: theme.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                title,
                                softWrap: true,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                  color: OtterColors.sberBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
            const SizedBox(height: 20),

            // Footer like web TaskDetailModal: Save | Complete | Delete + Cancel
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: OtterColors.sberGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _saving ? '…' : 'Сохранить',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _toggleComplete,
                    style: FilledButton.styleFrom(
                      foregroundColor: completed
                          ? OtterColors.sberBlue
                          : OtterColors.sberGreen,
                      backgroundColor: completed
                          ? OtterColors.sberBlue.withValues(alpha: 0.12)
                          : OtterColors.sberGreenLight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      completed ? 'Восстановить' : 'Выполнено',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _delete,
                    style: FilledButton.styleFrom(
                      foregroundColor: OtterColors.priorityHigh,
                      backgroundColor:
                          OtterColors.priorityHigh.withValues(alpha: 0.08),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Удалить',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: OtterColors.sberBlack,
                backgroundColor: OtterColors.grayLight,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Отмена',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
