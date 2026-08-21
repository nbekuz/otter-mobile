import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/api_exception.dart';
import '../../core/premium/premium_required.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/theme/otter_theme.dart';
import '../../data/models/api/api_models.dart';
import '../../data/models/ui/ui_models.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/keyboard_dismisser.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(pomodoroStateProvider.notifier).loadAll();
      if (ref.read(tasksStateProvider).groups.isEmpty) {
        await ref.read(tasksStateProvider.notifier).loadGrouped();
      }
    });
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  List<Task> _activeTasks() {
    final groups = ref.read(tasksStateProvider).groups;
    return groups.values
        .expand((tasks) => tasks)
        .where((t) => !t.completed)
        .toList();
  }

  Task? _selectedTask(PomodoroUiState state) {
    if (state.selectedTaskId == null) return null;
    for (final task in _activeTasks()) {
      if (task.id == state.selectedTaskId) return task;
    }
    return null;
  }

  Color _priorityColor(Priority priority) => switch (priority) {
    Priority.high => const Color(0xFFFF3B30),
    Priority.medium => const Color(0xFFFF9500),
    Priority.low => const Color(0xFF34C759),
    Priority.none => const Color(0xFF8E8E93),
  };

  Future<void> _toggleTimer() async {
    final notifier = ref.read(pomodoroStateProvider.notifier);
    final current = ref.read(pomodoroStateProvider);
    if (current.timerState == 'running') {
      await notifier.pause();
      return;
    }
    try {
      await notifier.start();
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.code == 'PREMIUM_REQUIRED') {
        showPremiumRequiredModal(context, 'pomodoro');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(getApiErrorMessage(e, 'Не удалось запустить таймер')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        ref.watch(appSettingsProvider.select((s) => s.theme == 'dark'));
    final state = ref.watch(pomodoroStateProvider);
    final selectedTask = _selectedTask(state);
    final progress = state.progress.clamp(0.0, 1.0);
    final wide = Responsive.isWide(context);
    final sheetTheme = isDark ? OtterTheme.dark() : OtterTheme.light();

    return Theme(
      data: sheetTheme,
      child: Scaffold(
        backgroundColor: OtterColors.pageBg(isDark),
        body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 6, wide ? 24 : 12, 10),
              child: Row(
                children: [
                  Text(
                    'Помодоро',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: OtterColors.text(isDark),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _openSettings(context, state),
                    icon: const Icon(LucideIcons.settings),
                    style: IconButton.styleFrom(
                      backgroundColor: OtterColors.surface(isDark),
                      foregroundColor: OtterColors.text(isDark),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ResponsiveContent(
                maxWidth: wide ? 900 : double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Web: task + sound on top, large timer card below (centered).
                    final body = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TaskSoundRow(
                          selectedTaskTitle: selectedTask?.title,
                          workSounds: state.workBackgroundSounds,
                          selectedWorkSound: state.settings.workingSound,
                          sideBySide: wide,
                          onPickTask: () => _openTaskPicker(context),
                          onSelectWorkSound: (sound) => ref
                              .read(pomodoroStateProvider.notifier)
                              .setWorkSound(sound),
                        ),
                        const SizedBox(height: 16),
                        if (wide)
                          Expanded(
                            child: _PomodoroTimerCard(
                              state: state,
                              progress: progress,
                              formatTime: _formatTime,
                              expand: true,
                              onToggle: _toggleTimer,
                              onStop: () async {
                                await ref
                                    .read(pomodoroStateProvider.notifier)
                                    .stop();
                              },
                            ),
                          )
                        else
                          _PomodoroTimerCard(
                            state: state,
                            progress: progress,
                            formatTime: _formatTime,
                            onToggle: _toggleTimer,
                            onStop: () async {
                              await ref
                                  .read(pomodoroStateProvider.notifier)
                                  .stop();
                            },
                          ),
                      ],
                    );

                    if (wide) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: body,
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: body,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _openTaskPicker(BuildContext context) async {
    final searchController = TextEditingController();
    final isDark =
        ref.read(appSettingsProvider).theme == 'dark';
    await showAppBottomSheet<void>(
      context: context,
      backgroundColor: OtterColors.surface(isDark),
      builder: (ctx) {
        return Theme(
          data: isDark ? OtterTheme.dark() : OtterTheme.light(),
          child: StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.toLowerCase();
            final tasks = _activeTasks()
                .where(
                  (t) => query.isEmpty || t.title.toLowerCase().contains(query),
                )
                .toList();
            final selectedId = ref.read(pomodoroStateProvider).selectedTaskId;
            // Fixed height so Column+Expanded works (only the list scrolls).
            final sheetH = MediaQuery.sizeOf(ctx).height * 0.75;

            return SizedBox(
              height: sheetH,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fixed header: title + search + «Без задачи».
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Выбрать задачу',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: OtterColors.text(isDark),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchController,
                          onTapOutside: dismissKeyboardOnTapOutside,
                          onEditingComplete: KeyboardDismisser.dismiss,
                          style: TextStyle(
                            color: OtterColors.text(isDark),
                            fontWeight: FontWeight.w500,
                          ),
                          cursorColor: OtterColors.sberGreen,
                          decoration: InputDecoration(
                            hintText: 'Поиск...',
                            hintStyle: TextStyle(color: OtterColors.muted(isDark)),
                            prefixIcon: Icon(
                              LucideIcons.search,
                              size: 18,
                              color: OtterColors.muted(isDark),
                            ),
                            filled: true,
                            fillColor: OtterColors.surfaceAlt(isDark),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: OtterColors.border(isDark),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: OtterColors.border(isDark),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: OtterColors.sberGreen,
                                width: 2,
                              ),
                            ),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            LucideIcons.x,
                            size: 18,
                            color: OtterColors.text(isDark),
                          ),
                          title: Text(
                            'Без задачи',
                            style: TextStyle(color: OtterColors.text(isDark)),
                          ),
                          onTap: () {
                            ref
                                .read(pomodoroStateProvider.notifier)
                                .selectTask(null);
                            Navigator.pop(context);
                          },
                        ),
                        Divider(
                          height: 1,
                          color: OtterColors.border(isDark),
                        ),
                      ],
                    ),
                  ),
                  // Only the task list scrolls.
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: tasks.length,
                      itemBuilder: (_, i) {
                        final task = tasks[i];
                        final selected = selectedId == task.id;
                        return ListTile(
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _priorityColor(task.priority),
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: OtterColors.text(isDark)),
                          ),
                          trailing: selected
                              ? const Icon(
                                  LucideIcons.check,
                                  color: OtterColors.sberGreen,
                                )
                              : null,
                          selected: selected,
                          selectedTileColor: OtterColors.elevated(isDark),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () {
                            ref
                                .read(pomodoroStateProvider.notifier)
                                .selectTask(task.id);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        );
      },
    );
    searchController.dispose();
  }

  Future<void> _openSettings(
    BuildContext context,
    PomodoroUiState state,
  ) async {
    final isDark =
        ref.read(appSettingsProvider).theme == 'dark';
    await showAppBottomSheet<void>(
      context: context,
      backgroundColor: OtterColors.surface(isDark),
      builder: (ctx) {
        return Theme(
          data: isDark ? OtterTheme.dark() : OtterTheme.light(),
          child: StatefulBuilder(
          builder: (context, setModalState) {
            final current = ref.watch(pomodoroStateProvider);
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Настройки Помодоро',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: OtterColors.text(isDark),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SettingsSection(
                      title: 'Длительность: ${current.settings.duration} мин',
                      isDark: isDark,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [15, 20, 25, 30, 45, 60].map((d) {
                          final selected = current.settings.duration == d;
                          return _ChipButton(
                            label: '$d мин',
                            selected: selected,
                            selectedColor: OtterColors.sberGreen,
                            isDark: isDark,
                            onTap: () async {
                              await ref
                                  .read(pomodoroStateProvider.notifier)
                                  .updateSettings(duration: d);
                              setModalState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    _SettingsSection(
                      title:
                          'Короткий перерыв: ${current.settings.shortBreak} мин',
                      isDark: isDark,
                      child: Wrap(
                        spacing: 8,
                        children: [3, 5, 7, 10].map((d) {
                          final selected = current.settings.shortBreak == d;
                          return _ChipButton(
                            label: '$d мин',
                            selected: selected,
                            selectedColor: OtterColors.sberBlue,
                            isDark: isDark,
                            onTap: () async {
                              await ref
                                  .read(pomodoroStateProvider.notifier)
                                  .updateSettings(shortBreak: d);
                              setModalState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    if (defaultTargetPlatform != TargetPlatform.windows)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Показывать при блокировке',
                          style: TextStyle(color: OtterColors.text(isDark)),
                        ),
                        subtitle: Text(
                          'На экране блокировки смартфона',
                          style: TextStyle(
                            fontSize: 12,
                            color: OtterColors.muted(isDark),
                          ),
                        ),
                        value: current.settings.showOnLockScreen,
                        activeThumbColor: OtterColors.sberGreen,
                        onChanged: (v) async {
                          await ref
                              .read(pomodoroStateProvider.notifier)
                              .updateSettings(showOnLockScreen: v);
                          setModalState(() {});
                        },
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Звук завершения',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: OtterColors.text(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: current.timerEndSounds.map((sound) {
                        final selected = current.settings.sound == sound.key;
                        return _ChipButton(
                          label: '${sound.emoji} ${sound.title}',
                          selected: selected,
                          selectedColor: OtterColors.sberGreen,
                          isDark: isDark,
                          onTap: () async {
                            await ref
                                .read(pomodoroStateProvider.notifier)
                                .setTimerEndSound(sound);
                            setModalState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        KeyboardDismisser.dismiss();
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: OtterColors.sberGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Готово',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        );
      },
    );
  }
}

class _PomodoroTimerCard extends StatelessWidget {
  const _PomodoroTimerCard({
    required this.state,
    required this.progress,
    required this.formatTime,
    required this.onToggle,
    required this.onStop,
    this.expand = false,
  });

  final PomodoroUiState state;
  final double progress;
  final String Function(int seconds) formatTime;
  final Future<void> Function() onToggle;
  final Future<void> Function() onStop;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: expand ? 40 : 24,
        vertical: expand ? 32 : 24,
      ),
      decoration: BoxDecoration(
        color: OtterColors.surface(isDark),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: expand
          ? SizedBox.expand(child: _timerBody(context, isDark))
          : _timerBody(context, isDark),
    );
  }

  Widget _timerBody(BuildContext context, bool isDark) {
    return Column(
      mainAxisAlignment:
          expand ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(state.settings.sessionsUntilLong, (i) {
            final filled =
                state.sessionCount > 0 &&
                i < state.sessionCount % state.settings.sessionsUntilLong;
            return Container(
              width: 32,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: filled
                    ? OtterColors.sberGreen
                    : OtterColors.border(isDark),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        SizedBox(height: expand ? 28 : 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxByWidth = constraints.maxWidth;
            final maxByHeight = expand
                ? (MediaQuery.sizeOf(context).height * 0.42)
                : 280.0;
            final timerSize = (maxByWidth * (expand ? 0.55 : 0.65)).clamp(
              180.0,
              expand ? maxByHeight.clamp(220.0, 448.0) : 280.0,
            );
            return SizedBox(
              width: timerSize,
              height: timerSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: timerSize,
                    height: timerSize,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: expand ? 12 : 10,
                      backgroundColor: OtterColors.border(isDark),
                      color: state.isBreak
                          ? OtterColors.sberBlue
                          : OtterColors.sberGreen,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatTime(state.secondsLeft),
                        style: TextStyle(
                          fontSize: timerSize * (expand ? 0.22 : 0.2),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: OtterColors.text(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.timerState == 'paused'
                            ? 'На паузе'
                            : state.isBreak
                            ? 'Перерыв'
                            : state.timerState == 'running'
                            ? 'Фокус'
                            : 'Готов',
                        style: TextStyle(
                          fontSize: 14,
                          color: state.isBreak
                              ? OtterColors.sberBlue
                              : OtterColors.muted(isDark),
                          fontWeight: state.isBreak
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        SizedBox(height: expand ? 36 : 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CircleControl(
              icon: LucideIcons.square,
              enabled: state.timerState != 'idle',
              onPressed: onStop,
            ),
            const SizedBox(width: 24),
            _MainControl(
              isRunning: state.timerState == 'running',
              onPressed: onToggle,
            ),
            const SizedBox(width: 24),
            _CircleControl(
              icon: LucideIcons.skipForward,
              enabled: true,
              onPressed: onStop,
            ),
          ],
        ),
      ],
    );
  }
}

class _TaskSoundRow extends StatelessWidget {
  const _TaskSoundRow({
    required this.selectedTaskTitle,
    required this.workSounds,
    required this.selectedWorkSound,
    required this.onPickTask,
    required this.onSelectWorkSound,
    this.sideBySide = false,
  });

  final String? selectedTaskTitle;
  final List<ApiSound> workSounds;
  final String selectedWorkSound;
  final VoidCallback onPickTask;
  final ValueChanged<ApiSound> onSelectWorkSound;
  final bool sideBySide;

  Widget _taskCard(bool isDark) {
    return Material(
      color: OtterColors.surface(isDark),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onPickTask,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: OtterColors.border(isDark)),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.target,
                color: OtterColors.sberGreen,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Задача для фокуса',
                      style: TextStyle(
                        fontSize: 12,
                        color: OtterColors.muted(isDark),
                      ),
                    ),
                    Text(
                      selectedTaskTitle ?? 'Выбрать задачу...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: OtterColors.text(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: OtterColors.muted(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _soundButtons(bool isDark) {
    // Keep all sound chips on one row (scale down if space is tight).
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < workSounds.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Builder(
              builder: (context) {
                final sound = workSounds[i];
                final selected = selectedWorkSound == sound.key;
                return InkWell(
                  onTap: () => onSelectWorkSound(sound),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 36,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? OtterColors.sberGreen
                          : OtterColors.elevated(isDark),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      sound.emoji,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1,
                        color:
                            selected ? Colors.white : OtterColors.muted(isDark),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _soundCard({required bool compactRow, required bool isDark}) {
    if (compactRow) {
      // Web lg: icon + label + sound chips in one horizontal bar.
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: OtterColors.surface(isDark),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: OtterColors.border(isDark)),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.music,
              size: 20,
              color: OtterColors.muted(isDark),
            ),
            const SizedBox(width: 12),
            Text(
              'Звук фоновый',
              style: TextStyle(
                fontSize: 14,
                color: OtterColors.muted(isDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _soundButtons(isDark)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OtterColors.surface(isDark),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: OtterColors.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.music,
                size: 20,
                color: OtterColors.muted(isDark),
              ),
              const SizedBox(width: 12),
              Text(
                'Звук фоновый',
                style: TextStyle(
                  fontSize: 14,
                  color: OtterColors.muted(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: _soundButtons(isDark),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    if (sideBySide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _taskCard(isDark)),
            const SizedBox(width: 12),
            Expanded(child: _soundCard(compactRow: true, isDark: isDark)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _taskCard(isDark),
        const SizedBox(height: 12),
        _soundCard(compactRow: false, isDark: isDark),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    required this.isDark,
  });

  final String title;
  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: OtterColors.text(isDark),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedColor : OtterColors.elevated(isDark),
          border: Border.all(
            color: selected ? selectedColor : OtterColors.border(isDark),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : OtterColors.text(isDark),
          ),
        ),
      ),
    );
  }
}

class _CircleControl extends StatelessWidget {
  const _CircleControl({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: OtterColors.elevated(isDark),
        foregroundColor: OtterColors.text(isDark),
        disabledForegroundColor: OtterColors.muted(isDark),
        minimumSize: const Size(48, 48),
      ),
    );
  }
}

class _MainControl extends StatelessWidget {
  const _MainControl({required this.isRunning, required this.onPressed});

  final bool isRunning;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(isRunning ? LucideIcons.pause : LucideIcons.play),
      style: IconButton.styleFrom(
        backgroundColor: isRunning
            ? OtterColors.sberBlue
            : OtterColors.sberGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(80, 80),
        iconSize: 32,
      ),
    );
  }
}
