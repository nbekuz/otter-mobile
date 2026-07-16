import 'package:flutter/material.dart';

import '../../core/theme/otter_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.outline = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    if (outline) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: OtterColors.sberGreen,
            side: const BorderSide(color: OtterColors.sberGreen, width: 2),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(OtterColors.radiusMd),
            ),
          ),
          child: _child(),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: OtterColors.sberGreen,
          disabledBackgroundColor: OtterColors.grayMid,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OtterColors.radiusMd),
          ),
        ),
        child: _child(),
      ),
    );
  }

  Widget _child() {
    final textColor = outline ? OtterColors.sberGreen : Colors.white;
    if (loading) {
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: textColor,
        ),
      );
    }
    return Text(
      label,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    );
  }
}
