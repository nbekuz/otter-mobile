import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/select_field.dart';
import 'task_time_sync.dart';

Future<void> showTaskDetailSheet(BuildContext context, Task task) {
  return showAppBottomSheet<void>(
    context: context,
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
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
    if (picked != null) {
      onPicked(picked);
    }
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
              deleteAttachmentId: (_attachmentId != null &&
                      (_clearImage || _imagePath != null))
                  ? _attachmentId
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    final file = result?.files.single;
    if (file == null || file.path == null) return;
    setState(() {
      _imagePath = file.path;
      _attachmentName = file.name;
      _attachmentMimeType = null;
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

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                InkWell(
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
                      color: priorityColor(_priority).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: priorityColor(_priority).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        prioritySelectDot(_priority, size: 8),
                        const SizedBox(width: 8),
                        Text(
                          priorityLabel(_priority),
                          style: TextStyle(
                            fontSize: 12,
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
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(LucideIcons.calendar, size: 18),
                    label: Text(
                      _dueDate != null
                          ? DateFormat('d MMM yyyy', 'ru').format(_dueDate!)
                          : 'Дата',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(
                      initial: _dueTime,
                      onPicked: _applyDueTimeSync,
                    ),
                    icon: const Icon(LucideIcons.clock, size: 18),
                    label: Text(_formatTime(_dueTime) ?? 'Срок'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(
                      initial: _durationStart,
                      onPicked: _applyStartSync,
                    ),
                    child: Text(
                      'Начало: ${_formatTime(_durationStart) ?? '—'}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(
                      initial: _durationEnd,
                      onPicked: _applyEndManual,
                    ),
                    child: Text('Конец: ${_formatTime(_durationEnd) ?? '—'}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showSelectSheet<String>(
                  context: context,
                  title: 'Уведомление',
                  items: _notifyOptions.map((e) => e.value).toList(),
                  itemLabel: (v) =>
                      _notifyOptions.firstWhere((e) => e.value == v).label,
                  selected: _notification ?? '',
                );
                if (picked != null) setState(() => _notification = picked);
              },
              icon: const Icon(LucideIcons.bell, size: 18),
              label: Text(
                _notifyOptions
                    .firstWhere(
                      (e) => e.value == (_notification ?? ''),
                      orElse: () => _notifyOptions.first,
                    )
                    .label,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showSelectSheet<RepeatType>(
                  context: context,
                  title: 'Повтор',
                  items: _repeatOptions.map((e) => e.value).toList(),
                  itemLabel: (v) =>
                      _repeatOptions.firstWhere((e) => e.value == v).label,
                  selected: _repeat,
                );
                if (picked != null) setState(() => _repeat = picked);
              },
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: Text(
                _repeatOptions
                    .firstWhere(
                      (e) => e.value == _repeat,
                      orElse: () => _repeatOptions.first,
                    )
                    .label,
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Матрица Эйзенхауэра',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OtterColors.sberGray,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final settings = ref.watch(matrixSettingsProvider).blocks;
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.5,
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
                                softWrap: true,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
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
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickAttachment,
              icon: const Icon(LucideIcons.paperclip, size: 18),
              label: Text(
                _imagePath != null
                    ? 'Файл выбран'
                    : (_existingImageUrl != null && !_clearImage)
                        ? 'Изменить файл'
                        : 'Добавить файл',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: OtterColors.sberGreen,
                backgroundColor: OtterColors.sberGreenLight,
              ),
            ),
            if (_imagePath != null ||
                (_existingImageUrl != null && !_clearImage)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: OtterColors.grayLight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: OtterColors.grayLight),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _attachmentIsImage && _imagePath != null
                          ? Image.file(
                              File(_imagePath!),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            )
                          : _attachmentIsImage &&
                                  _existingImageUrl != null &&
                                  !_clearImage
                              ? Image.network(
                                  resolveMediaUrl(_existingImageUrl),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(LucideIcons.file, size: 22),
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.white,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    LucideIcons.file,
                                    size: 22,
                                    color: OtterColors.sberGray,
                                  ),
                                ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _imagePath == null &&
                                _existingImageUrl != null &&
                                !_clearImage
                            ? _openExistingAttachment
                            : null,
                        child: Text(
                          _attachmentName ??
                              _imagePath?.split('/').last ??
                              'Вложение',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _imagePath == null &&
                                    _existingImageUrl != null &&
                                    !_clearImage
                                ? OtterColors.sberGreen
                                : OtterColors.sberBlack,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _clearAttachment,
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: _saving ? 'Сохранение…' : 'Сохранить',
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 8),
            if (widget.task.completed)
              OutlinedButton(
                onPressed: _toggleComplete,
                child: const Text('Восстановить'),
              )
            else ...[
              OutlinedButton(
                onPressed: _toggleComplete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: OtterColors.sberGreen,
                  backgroundColor: OtterColors.sberGreenLight,
                ),
                child: const Text('Выполнено'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _delete,
                child: const Text(
                  'Удалить',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
