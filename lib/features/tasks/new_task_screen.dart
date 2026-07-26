import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/theme/priority_colors.dart';
import '../../core/utils/media_url.dart';
import '../../core/utils/time_utils.dart';
import '../../data/mappers/task_mapper.dart';
import '../../data/models/ui/ui_models.dart';
import '../../features/matrix/matrix_block_setting.dart';
import '../../features/matrix/matrix_constants.dart';
import '../../shared/widgets/app_toast.dart';
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
  final _customNotifyCtrl = TextEditingController(text: '10');
  final _customIntervalCtrl = TextEditingController(text: '1');
  final _customMonthDayCtrl = TextEditingController(
    text: '${DateTime.now().day}',
  );
  final _titleFocus = FocusNode();
  final _timeSync = TaskTimeSync();

  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  TimeOfDay? _durationStart;
  TimeOfDay? _durationEnd;
  Priority _priority = Priority.medium;
  MatrixBlock _matrix = MatrixBlock.notUrgentNotImportant;
  /// Matches otter-app create default: «В момент срока».
  String _notification = _defaultNotification;
  RepeatType _repeat = RepeatType.none;
  int _customNotifyMinutes = 10;
  int _customRepeatInterval = 1;
  String _customRepeatUnit = 'week';
  List<int> _customWeekdays = [1];
  int _customMonthDay = DateTime.now().day;
  String? _repeatIntervalError;
  String? _repeatWeekdaysError;
  String? _repeatMonthDayError;
  _TaskFormTab _activeTab = _TaskFormTab.date;
  bool _explicitNoDeadline = false;
  bool _loading = false;
  bool _descOpen = false;
  bool _completed = false;
  String? _error;
  String? _imagePath;
  String? _existingImageUrl;
  String? _attachmentName;
  String? _attachmentMimeType;
  int? _attachmentId;
  bool _clearImage = false;

  /// otter-app `form.notification: '0'` — «В момент срока».
  static const _defaultNotification = '0';

  static const _notifyPresets = {
    '',
    '0',
    '5',
    '15',
    '30',
    '60',
    '1440',
    'custom',
  };

  static const _notifyOptions = [
    (value: '0', label: 'В момент срока'),
    (value: '5', label: 'За 5 минут'),
    (value: '15', label: 'За 15 минут'),
    (value: '30', label: 'За 30 минут'),
    (value: '60', label: 'За 1 час'),
    (value: '1440', label: 'За 1 день'),
    (value: 'custom', label: 'Своё время…'),
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
    if (widget.initialDueDate != null) {
      _dueDate = DateTime.tryParse(widget.initialDueDate!);
    }
    _dueTime = _parseTime(widget.initialDueTime);
    _durationStart = _parseTime(widget.initialDurationStart) ?? _dueTime;
    final initialEnd = _parseTime(widget.initialDurationEnd);
    if (initialEnd != null) {
      _durationEnd = initialEnd;
    } else if (_durationStart != null) {
      _durationEnd = _parseTime(
        defaultDurationEnd(_formatTime(_durationStart)!),
      );
    } else {
      _durationEnd = null;
    }
    _timeSync.adoptLoadedDuration(
      _formatTime(_durationStart),
      _formatTime(_durationEnd),
    );

    if (widget.initialMatrixBlock != null &&
        widget.initialMatrixBlock!.isNotEmpty) {
      _matrix = MatrixBlockX.fromId(widget.initialMatrixBlock!);
      _activeTab = _TaskFormTab.matrix;
    }

    if (widget.initialPriority != null && widget.initialPriority!.isNotEmpty) {
      _priority = MatrixBlockUiSetting.priorityFromFilter(
        widget.initialPriority!,
      );
    }

    if (widget.initialDueDate != null) {
      _activeTab = _TaskFormTab.date;
    }

    if (widget.isEditMode) {
      _descOpen = true;
      Future.microtask(_loadTask);
    } else {
      _notification = _defaultNotification;
      _scheduleTitleFocus();
    }

    Future.microtask(() => ref.read(matrixSettingsProvider.notifier).load());
  }

  /// Match otter-app: focus the title field when opening create mode.
  /// Retry after the route transition — a single autofocus often loses on Android.
  void _scheduleTitleFocus() {
    void attempt() {
      if (!mounted || widget.isEditMode) return;
      _titleFocus.requestFocus();
      // Soft keyboard (Android); on Windows this still ensures the caret is active.
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attempt();
      Future<void>.delayed(const Duration(milliseconds: 350), attempt);
    });
  }

  Future<void> _loadTask() async {
    setState(() => _loading = true);
    try {
      final task = await ref
          .read(tasksServiceProvider)
          .fetchTask(widget.taskId!);
      _title.text = task.title;
      _description.text = task.description ?? '';
      _priority = task.priority;
      _matrix = task.matrixBlock ?? MatrixBlock.notUrgentNotImportant;
      _repeat = task.repeat;
      final notify = task.notification ?? '';
      if (notify.isNotEmpty && !_notifyPresets.contains(notify)) {
        _notification = 'custom';
        _customNotifyMinutes = int.tryParse(notify) ?? 10;
      } else {
        _notification = notify;
      }
      _completed = task.completed;
      _customRepeatInterval = task.repeatCustom?.interval ?? 1;
      _customRepeatUnit = task.repeatCustom?.unit ??
          (task.repeatDays?.isNotEmpty == true ? 'week' : 'week');
      _customWeekdays = task.repeatCustom?.weekdays?.isNotEmpty == true
          ? List<int>.from(task.repeatCustom!.weekdays!)
          : (task.repeatDays?.isNotEmpty == true
              ? List<int>.from(task.repeatDays!)
              : [1]);
      _customMonthDay =
          task.repeatCustom?.monthDay ?? DateTime.now().day;
      _customIntervalCtrl.text = '$_customRepeatInterval';
      _customMonthDayCtrl.text = '$_customMonthDay';
      if (_notification == 'custom') {
        _customNotifyCtrl.text = '$_customNotifyMinutes';
      }
      if (task.dueDate != null) {
        _dueDate = DateTime.tryParse(task.dueDate!);
      } else {
        _explicitNoDeadline = true;
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
      _existingImageUrl = task.imageUrl;
      _attachmentId = task.attachmentId;
      _attachmentName = task.attachmentName;
      _attachmentMimeType = task.attachmentMimeType;
      _clearImage = false;
      _imagePath = null;
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
    _customNotifyCtrl.dispose();
    _customIntervalCtrl.dispose();
    _customMonthDayCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
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

  Future<void> _toggleComplete() async {
    if (!widget.isEditMode || _loading) return;
    setState(() => _loading = true);
    try {
      final stub = Task(
        id: widget.taskId!,
        title: _title.text.trim().isEmpty ? 'Задача' : _title.text.trim(),
        priority: _priority,
        completed: _completed,
        repeat: _repeat,
        createdAt: DateTime.now().toIso8601String(),
        notification: _notification,
        dueDate: _formatDate(_dueDate),
        dueTime: _formatTime(_dueTime),
        matrixBlock: _matrix,
      );
      await ref.read(tasksStateProvider.notifier).completeTask(stub);
      if (!mounted) return;
      setState(() => _completed = !_completed);
      showAppToast(
        context,
        _completed ? 'Задача отмечена выполненной' : 'Задача восстановлена',
        type: AppToastType.success,
      );
    } catch (e) {
      if (mounted) showAppToast(context, getApiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteTask() async {
    if (!widget.isEditMode || _loading) return;
    final taskId = widget.taskId!;
    final recurring = _repeat != RepeatType.none;

    String? scope;
    if (recurring) {
      scope = await showModalBottomSheet<String>(
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
                  onPressed: () => Navigator.pop(ctx, 'this'),
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
      if (scope == null) return;
    }

    setState(() => _loading = true);
    try {
      final notifier = ref.read(tasksStateProvider.notifier);
      if (scope == 'series') {
        await notifier.deleteSeries(taskId);
      } else if (scope == 'this') {
        final existing = notifier.findTaskById(taskId);
        if (existing != null) {
          await notifier.deleteOccurrence(existing);
        } else {
          await notifier.deleteTask(taskId, scope: 'this');
        }
      } else {
        await notifier.deleteTask(taskId);
      }
      if (mounted) _goBack();
    } catch (e) {
      if (mounted) showAppToast(context, getApiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
        _timeSync.resetEndEdited();
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

    _repeatIntervalError = null;
    _repeatWeekdaysError = null;
    _repeatMonthDayError = null;
    if (_repeat == RepeatType.custom) {
      _customRepeatInterval = int.tryParse(_customIntervalCtrl.text) ?? 1;
      _customMonthDay = int.tryParse(_customMonthDayCtrl.text) ?? 1;
      final intervalError = validateRepeatInterval(_customRepeatInterval);
      var hasError = false;
      if (intervalError != null) {
        _repeatIntervalError = intervalError;
        hasError = true;
      }
      if (_customRepeatUnit == 'week' && _customWeekdays.isEmpty) {
        _repeatWeekdaysError = 'Выберите хотя бы один день недели';
        hasError = true;
      }
      if (_customRepeatUnit == 'month' &&
          (_customMonthDay < 1 || _customMonthDay > 31)) {
        _repeatMonthDayError = 'День месяца должен быть от 1 до 31';
        hasError = true;
      }
      if (hasError) {
        setState(() => _activeTab = _TaskFormTab.repeat);
        return;
      }
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
      final dueDate = _explicitNoDeadline
          ? (_repeat != RepeatType.none
              ? _formatDate(DateTime.now())
              : null)
          : _formatDate(_dueDate);
      final noDeadline = _explicitNoDeadline && _repeat == RepeatType.none;
      final notifyValue = _notification == 'custom'
          ? '${(int.tryParse(_customNotifyCtrl.text) ?? 0).clamp(0, 999999)}'
          : _notification;
      final clearNotify = notifyValue.isEmpty || noDeadline;
      final partial = PartialTask(
        title: _title.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        clearDescription: _description.text.trim().isEmpty,
        dueDate: dueDate,
        dueTime: noDeadline ? null : _formatTime(_dueTime),
        duration: noDeadline ? null : duration,
        clearDueDate: noDeadline,
        clearDueTime: noDeadline || _formatTime(_dueTime) == null,
        clearDuration: noDeadline || duration == null,
        priority: _priority,
        matrixBlock: _matrix,
        notification: clearNotify ? null : notifyValue,
        clearNotification: clearNotify,
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
        imagePath: _imagePath,
        clearImage: _clearImage && _imagePath == null,
        deleteAttachmentId: (_attachmentId != null &&
                (_clearImage || _imagePath != null))
            ? _attachmentId
            : null,
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OtterColors.sberBlack,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _title,
            focusNode: _titleFocus,
            autofocus: !widget.isEditMode,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'Например: отчёт, созвон, встреча…',
              filled: true,
              fillColor: OtterColors.grayLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _descOpen = !_descOpen),
                style: TextButton.styleFrom(
                  foregroundColor: OtterColors.sberGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(
                  _descOpen
                      ? '− Скрыть описание'
                      : '+ Описание (необязательно)',
                ),
              ),
            ),
          ],
          if (widget.isEditMode || _descOpen) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Детали, ссылки…',
                filled: true,
                fillColor: OtterColors.grayLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickAttachment,
            icon: const Icon(LucideIcons.paperclip, size: 16),
            label: Text(
              _imagePath != null
                  ? 'Файл выбран'
                  : (_existingImageUrl != null && !_clearImage)
                      ? 'Изменить файл / фото'
                      : 'Файл / фото',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: OtterColors.sberGreen,
              backgroundColor: OtterColors.sberGreenLight,
              side: BorderSide(
                color: OtterColors.sberGreen.withValues(alpha: 0.4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_imagePath != null ||
              (_existingImageUrl != null && !_clearImage)) ...[
            const SizedBox(height: 8),
            _buildAttachmentPreview(),
          ],
        ],
      ),
    );
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

  Widget _buildAttachmentPreview() {
    final name = _attachmentName ??
        _imagePath?.split('/').last ??
        'Вложение';
    Widget? thumb;
    if (_imagePath != null && _attachmentIsImage) {
      thumb = Image.file(
        File(_imagePath!),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
      );
    } else if (_existingImageUrl != null &&
        !_clearImage &&
        _attachmentIsImage) {
      final url = resolveMediaUrl(_existingImageUrl);
      if (url.isNotEmpty) {
        thumb = Image.network(
          url,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            LucideIcons.file,
            size: 28,
            color: OtterColors.sberGray,
          ),
        );
      }
    }

    return Container(
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
            child: thumb ??
                Container(
                  width: 56,
                  height: 56,
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: const Icon(
                    LucideIcons.file,
                    size: 24,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
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
                      decoration: _imagePath == null &&
                              _existingImageUrl != null &&
                              !_clearImage
                          ? TextDecoration.underline
                          : null,
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
            onPressed: _clearAttachment,
            icon: const Icon(LucideIcons.x, size: 16),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    // Match otter-app: labels for Дата/Приоритет; icon-only for the rest.
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: tabs.map((t) {
            final tab = t.$1;
            final icon = t.$2;
            final label = t.$3;
            final iconOnly = t.$4;
            final active = _activeTab == tab;
            final color =
                active ? OtterColors.sberGreen : OtterColors.sberGray;

            return Expanded(
              child: Tooltip(
                message: label,
                child: InkWell(
                  onTap: () => setState(() => _activeTab = tab),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 24, color: color),
                        if (!iconOnly) ...[
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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
        Row(
          children: [
            Expanded(
              child: _QuickChip(
                label: 'Сегодня',
                selected: _isQuickDateActive('today'),
                onTap: () => _setQuickDate('today'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickChip(
                label: 'Завтра',
                selected: _isQuickDateActive('tomorrow'),
                onTap: () => _setQuickDate('tomorrow'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickChip(
                label: 'Без срока',
                selected: _isQuickDateActive('none'),
                onTap: () => _setQuickDate('none'),
              ),
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
                  onTap: () =>
                      _pickTime(initial: _dueTime, onPicked: _applyDueTimeSync),
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
                    onPicked: _applyEndManual,
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
          final label = p == Priority.none
              ? 'Без приоритета'
              : priorityLabel(p);
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
          final selected = _notification == n.value;
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
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
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
        if (_notification == 'custom') ...[
          const SizedBox(height: 8),
          TextField(
            controller: _customNotifyCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Минут до срока',
              filled: true,
              fillColor: OtterColors.grayLight,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
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
              onTap: () => setState(() {
                _repeat = r.value;
                _repeatIntervalError = null;
                _repeatWeekdaysError = null;
                _repeatMonthDayError = null;
              }),
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
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
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
        if (_repeat == RepeatType.custom) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OtterColors.sberGreenLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: OtterColors.sberGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customIntervalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Интервал',
                          errorText: _repeatIntervalError,
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (_) =>
                            setState(() => _repeatIntervalError = null),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _UnitChip(
                      label: 'Нед.',
                      selected: _customRepeatUnit == 'week',
                      onTap: () => setState(() {
                        _customRepeatUnit = 'week';
                        _repeatIntervalError = null;
                      }),
                    ),
                    const SizedBox(width: 6),
                    _UnitChip(
                      label: 'Мес.',
                      selected: _customRepeatUnit == 'month',
                      onTap: () => setState(() {
                        _customRepeatUnit = 'month';
                        _repeatIntervalError = null;
                      }),
                    ),
                  ],
                ),
                if (_customRepeatUnit == 'week') ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _weekDays.map((day) {
                      final selected = _customWeekdays.contains(day.value);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _customWeekdays = _customWeekdays
                                  .where((d) => d != day.value)
                                  .toList();
                            } else {
                              _customWeekdays = [..._customWeekdays, day.value]
                                ..sort();
                            }
                            _repeatWeekdaysError = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 40,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? OtterColors.sberGreen
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? OtterColors.sberGreen
                                  : OtterColors.grayMid,
                            ),
                          ),
                          child: Text(
                            day.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : OtterColors.sberBlack,
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
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
                if (_customRepeatUnit == 'month') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customMonthDayCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'День месяца',
                      errorText: _repeatMonthDayError,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (_) =>
                        setState(() => _repeatMonthDayError = null),
                  ),
                ],
              ],
            ),
          ),
        ],
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
          // Slightly taller so larger labels can wrap without shrinking.
          childAspectRatio: 1.5,
          children: kMatrixBlockThemes.map((theme) {
            final selected = _matrix == theme.block;
            final title = settings[theme.block]?.title ?? theme.defaultTitle;
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
                      color: selected ? theme.accent : OtterColors.grayLight,
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
        ),
      ],
    );
  }

  Widget _buildFooter() {
    if (!widget.isEditMode) {
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
                    : const Text(
                        'Добавить задачу',
                        style: TextStyle(
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

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: OtterColors.grayLight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _loading ? null : _toggleComplete,
            icon: const Icon(LucideIcons.check, size: 16),
            label: Text(_completed ? 'Восстановить' : 'Выполнено'),
            style: FilledButton.styleFrom(
              foregroundColor:
                  _completed ? OtterColors.sberGray : OtterColors.sberGreen,
              backgroundColor: _completed
                  ? OtterColors.grayLight
                  : OtterColors.sberGreenLight,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _goBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OtterColors.sberBlack,
                    backgroundColor: OtterColors.grayLight,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _deleteTask,
                  icon: const Icon(LucideIcons.trash2, size: 14),
                  label: const Text('Удалить'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF3B30),
                    backgroundColor: const Color(0xFFFFF0EE),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 1,
                child: FilledButton(
                  onPressed: _loading ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: OtterColors.sberGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Сохранить',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
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
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
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
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? OtterColors.sberGreen : OtterColors.grayMid,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : OtterColors.sberBlack,
            ),
          ),
        ),
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  const _UnitChip({
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
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? OtterColors.sberGreen : OtterColors.grayMid,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: OtterColors.sberGray,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: hasValue
                            ? OtterColors.sberBlack
                            : OtterColors.sberGray,
                      ),
                    ),
                  ),
                  Icon(icon, size: 20, color: OtterColors.sberGray),
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
      color: selected ? selectedColor.withValues(alpha: 0.08) : Colors.white,
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
