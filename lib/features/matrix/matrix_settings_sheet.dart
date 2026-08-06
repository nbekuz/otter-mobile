import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../data/models/ui/ui_models.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/keyboard_dismisser.dart';
import '../../shared/widgets/primary_button.dart';
import 'matrix_block_setting.dart';
import 'matrix_constants.dart';

/// Stronger secondary text than [OtterColors.muted] — light gray reads too
/// faintly on Windows; closer to web body/label contrast.
Color _matrixSettingsSecondary(bool isDark) =>
    isDark ? const Color(0xFFC0C7D1) : const Color(0xFF5C5C62);

Future<void> showMatrixSettingsSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  await ref.read(matrixSettingsProvider.notifier).load();
  if (!context.mounted) return;

  final initial = Map<MatrixBlock, MatrixBlockUiSetting>.from(
    ref.read(matrixSettingsProvider).blocks,
  );

  await showAppBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _MatrixSettingsSheet(initialBlocks: initial),
  );
}

class _MatrixSettingsSheet extends ConsumerStatefulWidget {
  const _MatrixSettingsSheet({required this.initialBlocks});

  final Map<MatrixBlock, MatrixBlockUiSetting> initialBlocks;

  @override
  ConsumerState<_MatrixSettingsSheet> createState() =>
      _MatrixSettingsSheetState();
}

class _MatrixSettingsSheetState extends ConsumerState<_MatrixSettingsSheet> {
  late Map<MatrixBlock, MatrixBlockUiSetting> _blocks;
  final _titleControllers = <MatrixBlock, TextEditingController>{};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _blocks = Map<MatrixBlock, MatrixBlockUiSetting>.from(widget.initialBlocks);
    for (final block in MatrixBlock.values) {
      _titleControllers[block] = TextEditingController(
        text: _blocks[block]?.title ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _titleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final next = <MatrixBlock, MatrixBlockUiSetting>{};
    for (final entry in _blocks.entries) {
      next[entry.key] = entry.value.copyWith(
        title: _titleControllers[entry.key]!.text.trim(),
      );
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(matrixSettingsProvider.notifier).saveAll(next);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _error = getApiErrorMessage(e, 'Не удалось сохранить'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleDate(MatrixBlock block, String filter) {
    setState(() {
      final current = List<String>.from(_blocks[block]!.dateFilters);
      if (current.contains(filter)) {
        current.remove(filter);
      } else {
        current.add(filter);
      }
      _blocks[block] = _blocks[block]!.copyWith(dateFilters: current);
    });
  }

  void _togglePriority(MatrixBlock block, String filter) {
    setState(() {
      final current = List<String>.from(_blocks[block]!.priorityFilters);
      if (current.contains(filter)) {
        current.remove(filter);
      } else {
        current.add(filter);
      }
      _blocks[block] = _blocks[block]!.copyWith(priorityFilters: current);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    final wide = Responsive.isWide(context);
    final maxH = wide
        ? MediaQuery.sizeOf(context).height * 0.85
        : appBottomSheetMaxHeight(context);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Настройки блоков',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: OtterColors.text(isDark),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'В каждом блоке выбранные условия работают как множественный фильтр (ИЛИ): '
            'задача попадает в блок, если подходит хотя бы одно из них — по дате или по приоритету.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _matrixSettingsSecondary(isDark),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );

    final blocksList = Column(
      children: [
        for (var i = 0; i < kMatrixBlockThemes.length; i++) ...[
          _BlockSection(
            setting: _blocks[kMatrixBlockThemes[i].block]!,
            theme: kMatrixBlockThemes[i],
            titleController: _titleControllers[kMatrixBlockThemes[i].block]!,
            onToggleDate: (f) => _toggleDate(kMatrixBlockThemes[i].block, f),
            onTogglePriority: (f) =>
                _togglePriority(kMatrixBlockThemes[i].block, f),
          ),
          if (i < kMatrixBlockThemes.length - 1)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 20),
              child: Divider(height: 1, color: OtterColors.border(isDark)),
            ),
        ],
      ],
    );

    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              _error!,
              style: const TextStyle(color: OtterColors.priorityHigh),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PrimaryButton(
            label: 'Сохранить',
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ),
      ],
    );

    final scroll = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: blocksList,
    );

    if (wide) {
      return SizedBox(
        height: maxH,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: scroll),
            footer,
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: OtterColors.border(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        header,
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (maxH - 200).clamp(200.0, maxH),
          ),
          child: scroll,
        ),
        footer,
      ],
    );
  }
}

class _BlockSection extends StatelessWidget {
  const _BlockSection({
    required this.setting,
    required this.theme,
    required this.titleController,
    required this.onToggleDate,
    required this.onTogglePriority,
  });

  final MatrixBlockUiSetting setting;
  final MatrixBlockTheme theme;
  final TextEditingController titleController;
  final void Function(String filter) onToggleDate;
  final void Function(String filter) onTogglePriority;

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    final borderColor = OtterColors.border(isDark);
    // Web: space-y-2 between field groups, mb-3 under block title.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                setting.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: OtterColors.text(isDark),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Название блока',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _matrixSettingsSecondary(isDark),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: titleController,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: OtterColors.text(isDark),
          ),
          onTapOutside: dismissKeyboardOnTapOutside,
          onEditingComplete: KeyboardDismisser.dismiss,
          decoration: InputDecoration(
            filled: true,
            fillColor: OtterColors.surfaceAlt(isDark),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: OtterColors.sberGreen),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Фильтр по дате',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _matrixSettingsSecondary(isDark),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: kMatrixDateFilters.map((f) {
            final selected = setting.dateFilters.contains(f.id);
            return _FilterChip(
              label: f.label,
              selected: selected,
              selectedColor: theme.accent,
              onTap: () => onToggleDate(f.id),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          'Фильтр по приоритету',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _matrixSettingsSecondary(isDark),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: kMatrixPriorityFilters.map((f) {
            final selected = setting.priorityFilters.contains(f.id);
            return _FilterChip(
              label: f.label,
              selected: selected,
              selectedColor: f.color,
              onTap: () => onTogglePriority(f.id),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    final isDark = OtterColors.isDarkOf(context);
    final unselectedBg = OtterColors.surfaceAlt(isDark);
    final unselectedBorder =
        isDark ? OtterColors.darkBorder : const Color(0xFFB0B0B5);
    // Web: w-20 px-2 py-1 rounded-xl text-xs font-medium border
    return Material(
      color: selected ? selectedColor : unselectedBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.transparent : unselectedBorder,
            ),
            color: selected ? selectedColor : unselectedBg,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : _matrixSettingsSecondary(isDark),
            ),
          ),
        ),
      ),
    );
  }
}
