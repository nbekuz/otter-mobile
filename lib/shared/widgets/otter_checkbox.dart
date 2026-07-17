import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/otter_colors.dart';

class OtterCheckbox extends StatelessWidget {
  const OtterCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.child,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    void toggle() => onChanged(!value);

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            toggle();
            return null;
          },
        ),
      },
      child: Semantics(
        checked: value,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: toggle,
            borderRadius: BorderRadius.circular(8),
            mouseCursor: SystemMouseCursors.click,
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? OtterColors.sberGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: value
                          ? OtterColors.sberGreen
                          : OtterColors.grayMid,
                      width: 2,
                    ),
                  ),
                  child: value
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
