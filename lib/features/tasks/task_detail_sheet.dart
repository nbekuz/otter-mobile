import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/priority_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../data/mappers/task_mapper.dart';
import '../../data/models/ui/ui_models.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/select_field.dart';
import '../../shared/widgets/keyboard_dismisser.dart';
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
  bool _saving = false;
  String? _error;
  final _timeSync = TaskTimeSync();

  @override
  void initState() {
    super.initState();
    _syncFromTask(widget.task);
  }

  void _syncFromTask(Task task) {
    _title = TextEditingController(text: task.title);
    _description = TextEditingController(text: task.description ?? '');
    _priority = task.priority;
    if (task.dueDate != null) {
      _dueDate = DateTime.tryParse(task.dueDate!);
    }
    _dueTime = _parseTime(task.dueTime);
    _durationStart = _parseTime(task.duration?.start);
    _durationEnd = _parseTime(task.duration?.end);
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
              dueDate: _formatDate(_dueDate),
              dueTime: _formatTime(_dueTime),
              duration: duration,
              priority: _priority,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _error = getApiErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    await ref.read(tasksStateProvider.notifier).deleteTask(widget.task.id);
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
              onTapOutside: dismissKeyboardOnTapOutside,
              onEditingComplete: KeyboardDismisser.dismiss,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              onTapOutside: dismissKeyboardOnTapOutside,
              onEditingComplete: KeyboardDismisser.dismiss,
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
                      onPicked: (t) => setState(() {
                        _durationEnd = t;
                        _error = null;
                      }),
                    ),
                    child: Text('Конец: ${_formatTime(_durationEnd) ?? '—'}'),
                  ),
                ),
              ],
            ),
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
            else
              TextButton(
                onPressed: _delete,
                child: const Text(
                  'Удалить',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
