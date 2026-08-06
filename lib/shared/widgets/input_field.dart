import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/otter_colors.dart';
import 'keyboard_dismisser.dart';

class InputField extends StatelessWidget {
  const InputField({
    super.key,
    required this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.obscure = false,
    this.icon,
    this.keyboardType,
    this.textInputAction,
    this.error,
    this.onToggleObscure,
    this.obscureVisible = false,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLength,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final bool obscure;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? error;
  final VoidCallback? onToggleObscure;
  final bool obscureVisible;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    final muted = OtterColors.muted(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          obscureText: obscure && !obscureVisible,
          keyboardType: keyboardType,
          maxLength: maxLength,
          textInputAction: textInputAction ??
              (obscure ? TextInputAction.done : TextInputAction.next),
          onSubmitted: onSubmitted,
          // Mouse/stylus only — touch outside is handled by KeyboardDismissOnTap.
          // Always-unfocus onTapOutside kills the keyboard after the 1st char on Android.
          onTapOutside: dismissKeyboardOnTapOutside,
          decoration: InputDecoration(
            hintText: hint,
            errorText: error,
            errorMaxLines: 3,
            counterText: maxLength != null ? '' : null,
            prefixIcon: icon != null
                ? Icon(icon, color: muted, size: 20)
                : null,
            suffixIcon: onToggleObscure != null
                ? IconButton(
                    icon: Icon(
                      obscureVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                      color: muted,
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
