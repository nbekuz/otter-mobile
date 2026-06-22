import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/otter_colors.dart';
import 'keyboard_dismisser.dart';

class InputField extends StatelessWidget {
  const InputField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.icon,
    this.keyboardType,
    this.error,
    this.onToggleObscure,
    this.obscureVisible = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? error;
  final VoidCallback? onToggleObscure;
  final bool obscureVisible;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? OtterColors.sberGray : OtterColors.sberGray,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          obscureText: obscure && !obscureVisible,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.done,
          onTapOutside: dismissKeyboardOnTapOutside,
          onEditingComplete: KeyboardDismisser.dismiss,
          decoration: InputDecoration(
            hintText: hint,
            errorText: error,
            prefixIcon: icon != null
                ? Icon(icon, color: OtterColors.sberGray, size: 20)
                : null,
            suffixIcon: onToggleObscure != null
                ? IconButton(
                    icon: Icon(
                      obscureVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                      color: OtterColors.sberGray,
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
