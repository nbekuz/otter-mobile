import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'app_bottom_sheet.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/theme/priority_colors.dart';
import '../../data/models/ui/ui_models.dart';

typedef SelectItemBuilder<T> =
    Widget Function(BuildContext context, T item, bool selected);

Future<T?> showSelectSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T item) itemLabel,
  required T selected,
  SelectItemBuilder<T>? itemBuilder,
}) {
  return showAppBottomSheet<T>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: OtterColors.grayMid,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: OtterColors.sberBlack,
                  ),
                ),
              ),
              ...items.map((item) {
                final isSelected = item == selected;
                return Material(
                  color: isSelected
                      ? OtterColors.sberGreenLight
                      : Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx, item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          if (itemBuilder != null) ...[
                            itemBuilder(ctx, item, isSelected),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              itemLabel(item),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: OtterColors.sberBlack,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              LucideIcons.check,
                              size: 20,
                              color: OtterColors.sberGreen,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

class SelectField<T> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.itemBuilder,
    this.hint,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T> onChanged;
  final SelectItemBuilder<T>? itemBuilder;
  final String? hint;

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showSelectSheet<T>(
      context: context,
      title: label,
      items: items,
      itemLabel: itemLabel,
      selected: value,
      itemBuilder: itemBuilder,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = itemLabel(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: OtterColors.sberGray,
          ),
        ),
        const SizedBox(height: 8),
        FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _openPicker(context);
                return null;
              },
            ),
          },
          child: Semantics(
            button: true,
            label: label,
            value: display,
            child: Material(
              color:
                  theme.inputDecorationTheme.fillColor ?? OtterColors.grayLight,
              borderRadius: BorderRadius.circular(OtterColors.radiusMd),
              child: InkWell(
                onTap: () => _openPicker(context),
                borderRadius: BorderRadius.circular(OtterColors.radiusMd),
                child: InputDecorator(
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OtterColors.radiusMd),
                      borderSide: const BorderSide(color: OtterColors.grayMid),
                    ),
                    suffixIcon: const Icon(
                      LucideIcons.chevronDown,
                      size: 20,
                      color: OtterColors.sberGray,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (itemBuilder != null) ...[
                        itemBuilder!(context, value, true),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          display.isNotEmpty ? display : (hint ?? ''),
                          style: TextStyle(
                            fontSize: 16,
                            color: display.isNotEmpty
                                ? OtterColors.sberBlack
                                : OtterColors.sberGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget prioritySelectDot(Priority priority, {double size = 10}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: priorityColor(priority),
      shape: BoxShape.circle,
    ),
  );
}

String priorityLabel(Priority priority) => switch (priority) {
  Priority.high => 'Высокий',
  Priority.medium => 'Средний',
  Priority.low => 'Низкий',
  Priority.none => 'Нет',
};
