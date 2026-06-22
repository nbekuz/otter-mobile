import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../data/models/ui/ui_models.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/primary_button.dart';
import 'matrix_block_setting.dart';
import 'matrix_constants.dart';

Future<void> showMatrixSettingsSheet(BuildContext context, WidgetRef ref) async {
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
      _titleControllers[block] =
          TextEditingController(text: _blocks[block]?.title ?? '');
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
    final maxH = appBottomSheetMaxHeight(context);
    const headerFooter = 160.0;

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
              color: OtterColors.grayMid,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(
            'Настройки блоков',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: OtterColors.sberBlack,
                ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (maxH - headerFooter).clamp(200.0, maxH),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              children: [
                for (var i = 0; i < kMatrixBlockThemes.length; i++) ...[
                  _BlockSection(
                    setting: _blocks[kMatrixBlockThemes[i].block]!,
                    theme: kMatrixBlockThemes[i],
                    titleController:
                        _titleControllers[kMatrixBlockThemes[i].block]!,
                    onToggleDate: (f) =>
                        _toggleDate(kMatrixBlockThemes[i].block, f),
                    onTogglePriority: (f) =>
                        _togglePriority(kMatrixBlockThemes[i].block, f),
                  ),
                  if (i < kMatrixBlockThemes.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: OtterColors.grayLight),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: OtterColors.sberBlack,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Название блока',
          style: TextStyle(fontSize: 12, color: OtterColors.sberGray),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: titleController,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: OtterColors.grayLight,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Фильтр по дате',
          style: TextStyle(fontSize: 12, color: OtterColors.sberGray),
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 12),
        const Text(
          'Фильтр по приоритету',
          style: TextStyle(fontSize: 12, color: OtterColors.sberGray),
        ),
        const SizedBox(height: 8),
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
    return Material(
      color: selected ? selectedColor : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? selectedColor : OtterColors.grayMid,
            ),
            color: selected ? selectedColor : Colors.white,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : OtterColors.sberGray,
            ),
          ),
        ),
      ),
    );
  }
}
