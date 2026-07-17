import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/layout/responsive.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
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
    } else {
      await notifier.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pomodoroStateProvider);
    final selectedTask = _selectedTask(state);
    final progress = state.progress.clamp(0.0, 1.0);
    final wide = Responsive.isWide(context);

    return Scaffold(
      backgroundColor: OtterColors.grayLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  const Text(
                    'Помодоро',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: OtterColors.sberBlack,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _openSettings(context, state),
                    icon: const Icon(LucideIcons.settings),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: OtterColors.sberBlack,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ResponsiveContent(
                maxWidth: wide ? 900 : double.infinity,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _PomodoroTimerCard(
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
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _TaskSoundRow(
                                selectedTaskTitle: selectedTask?.title,
                                workSounds: state.workBackgroundSounds,
                                selectedWorkSound: state.settings.workingSound,
                                onPickTask: () => _openTaskPicker(context),
                                onSelectWorkSound: (sound) => ref
                                    .read(pomodoroStateProvider.notifier)
                                    .setWorkSound(sound),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _TaskSoundRow(
                              selectedTaskTitle: selectedTask?.title,
                              workSounds: state.workBackgroundSounds,
                              selectedWorkSound: state.settings.workingSound,
                              onPickTask: () => _openTaskPicker(context),
                              onSelectWorkSound: (sound) => ref
                                  .read(pomodoroStateProvider.notifier)
                                  .setWorkSound(sound),
                            ),
                            const SizedBox(height: 16),
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
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTaskPicker(BuildContext context) async {
    final searchController = TextEditingController();
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = searchController.text.toLowerCase();
            final tasks = _activeTasks()
                .where(
                  (t) => query.isEmpty || t.title.toLowerCase().contains(query),
                )
                .toList();
            final selectedId = ref.read(pomodoroStateProvider).selectedTaskId;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Выбрать задачу',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onTapOutside: dismissKeyboardOnTapOutside,
                      onEditingComplete: KeyboardDismisser.dismiss,
                      decoration: InputDecoration(
                        hintText: 'Поиск...',
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        filled: true,
                        fillColor: OtterColors.grayLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(LucideIcons.x, size: 18),
                      title: const Text('Без задачи'),
                      onTap: () {
                        ref
                            .read(pomodoroStateProvider.notifier)
                            .selectTask(null);
                        Navigator.pop(context);
                      },
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
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
                          ),
                          trailing: selected
                              ? const Icon(
                                  LucideIcons.check,
                                  color: OtterColors.sberGreen,
                                )
                              : null,
                          selected: selected,
                          onTap: () {
                            ref
                                .read(pomodoroStateProvider.notifier)
                                .selectTask(task.id);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  Future<void> _openSettings(
    BuildContext context,
    PomodoroUiState state,
  ) async {
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
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
                    const Text(
                      'Настройки Помодоро',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SettingsSection(
                      title: 'Длительность: ${current.settings.duration} мин',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [15, 20, 25, 30, 45, 60].map((d) {
                          final selected = current.settings.duration == d;
                          return _ChipButton(
                            label: '$d мин',
                            selected: selected,
                            selectedColor: OtterColors.sberGreen,
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
                      child: Wrap(
                        spacing: 8,
                        children: [3, 5, 7, 10].map((d) {
                          final selected = current.settings.shortBreak == d;
                          return _ChipButton(
                            label: '$d мин',
                            selected: selected,
                            selectedColor: OtterColors.sberBlue,
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
                        title: const Text('Показывать при блокировке'),
                        subtitle: const Text(
                          'На экране блокировки смартфона',
                          style: TextStyle(fontSize: 12),
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
                    const Text(
                      'Звук завершения',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: OtterColors.sberGreen,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Готово'),
                    ),
                  ],
                ),
              ),
            );
          },
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
  });

  final PomodoroUiState state;
  final double progress;
  final String Function(int seconds) formatTime;
  final Future<void> Function() onToggle;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
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
                  color: filled ? OtterColors.sberGreen : OtterColors.grayMid,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final timerSize = (constraints.maxWidth * 0.65).clamp(
                180.0,
                280.0,
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
                        strokeWidth: 10,
                        backgroundColor: OtterColors.grayMid,
                        color: OtterColors.sberGreen,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatTime(state.secondsLeft),
                          style: TextStyle(
                            fontSize: timerSize * 0.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.timerState == 'paused'
                              ? 'На паузе'
                              : state.timerState == 'running'
                              ? 'Фокус'
                              : 'Готов',
                          style: const TextStyle(
                            fontSize: 14,
                            color: OtterColors.sberGray,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
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
      ),
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
  });

  final String? selectedTaskTitle;
  final List<ApiSound> workSounds;
  final String selectedWorkSound;
  final VoidCallback onPickTask;
  final ValueChanged<ApiSound> onSelectWorkSound;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: onPickTask,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Задача для фокуса',
                          style: TextStyle(
                            fontSize: 12,
                            color: OtterColors.sberGray,
                          ),
                        ),
                        Text(
                          selectedTaskTitle ?? 'Выбрать задачу...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: OtterColors.sberGray,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.music,
                    size: 20,
                    color: OtterColors.sberGray,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Звук фоновый',
                    style: TextStyle(fontSize: 14, color: OtterColors.sberGray),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: workSounds.map((sound) {
                    final selected = selectedWorkSound == sound.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => onSelectWorkSound(sound),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? OtterColors.sberGreen
                                : OtterColors.grayLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sound.emoji,
                            style: TextStyle(
                              fontSize: 16,
                              color: selected
                                  ? Colors.white
                                  : OtterColors.sberGray,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
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
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          border: Border.all(
            color: selected ? selectedColor : OtterColors.grayMid,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : OtterColors.sberBlack,
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
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: OtterColors.grayLight,
        foregroundColor: OtterColors.sberBlack,
        disabledForegroundColor: OtterColors.grayMid,
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
