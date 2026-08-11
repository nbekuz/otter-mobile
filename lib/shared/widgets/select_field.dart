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
      // Read after showAppBottomSheet Theme wrap so dark mode is correct.
      final isDark = OtterColors.isDarkOf(ctx);
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
                  color: OtterColors.border(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: OtterColors.text(isDark),
                  ),
                ),
              ),
              ...items.map((item) {
                final isSelected = item == selected;
                return Material(
                  color: isSelected
                      ? OtterColors.greenTint(isDark)
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
                                color: OtterColors.text(isDark),
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
    final isDark = OtterColors.isDarkOf(context);
    final display = itemLabel(value);
    final borderColor = OtterColors.border(isDark);
    final fill = OtterColors.surfaceAlt(isDark);
    final textColor = OtterColors.text(isDark);
    final muted = OtterColors.muted(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: muted,
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
              color: fill,
              borderRadius: BorderRadius.circular(OtterColors.radiusMd),
              child: InkWell(
                onTap: () => _openPicker(context),
                borderRadius: BorderRadius.circular(OtterColors.radiusMd),
                child: InputDecorator(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: fill,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OtterColors.radiusMd),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(OtterColors.radiusMd),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    suffixIcon: Icon(
                      LucideIcons.chevronDown,
                      size: 20,
                      color: muted,
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
                            fontWeight: FontWeight.w500,
                            color: display.isNotEmpty ? textColor : muted,
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
