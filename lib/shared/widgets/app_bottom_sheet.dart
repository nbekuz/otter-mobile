import 'package:flutter/material.dart';

import '../../core/layout/responsive.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/theme/otter_theme.dart';

/// Max bottom sheet height — 90% of viewport (CSS `90vh`).
const bottomSheetMaxHeightFactor = 0.9;

double appBottomSheetMaxHeight(BuildContext context) =>
    MediaQuery.sizeOf(context).height * bottomSheetMaxHeightFactor;

/// Caps sheet content at [bottomSheetMaxHeightFactor] of the screen height.
Widget appBottomSheetConstraints(BuildContext context, Widget child) {
  return ConstrainedBox(
    constraints: BoxConstraints(maxHeight: appBottomSheetMaxHeight(context)),
    child: child,
  );
}

/// Wraps sheet content so it stays anchored to the bottom (not stretched upward).
Widget appBottomSheetWrap(BuildContext context, Widget child) {
  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: appBottomSheetConstraints(context, child),
    ),
  );
}

ThemeData _sheetTheme(BuildContext context) {
  // Prefer the caller's theme (AppShell may force dark while MaterialApp lags).
  final brightness = Theme.of(context).brightness;
  return brightness == Brightness.dark ? OtterTheme.dark() : OtterTheme.light();
}

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useSafeArea = true,
  Color? backgroundColor,
  ShapeBorder? shape,
  double dialogMaxWidth = 520,
}) {
  final sheetTheme = _sheetTheme(context);
  final isDark = sheetTheme.brightness == Brightness.dark;
  final surface =
      backgroundColor ??
      sheetTheme.dialogTheme.backgroundColor ??
      OtterColors.surface(isDark);

  if (Responsive.isWide(context)) {
    return showDialog<T>(
      context: context,
      builder: (ctx) {
        return Theme(
          data: sheetTheme,
          child: Builder(
            builder: (themedCtx) {
              return Dialog(
                backgroundColor: surface,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: dialogMaxWidth,
                    maxHeight: MediaQuery.sizeOf(themedCtx).height * 0.85,
                  ),
                  child: builder(themedCtx),
                ),
              );
            },
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor ?? Colors.transparent,
    shape:
        shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
    builder: (ctx) {
      final radius = shape is RoundedRectangleBorder
          ? shape.borderRadius
          : const BorderRadius.vertical(top: Radius.circular(24));
      return Theme(
        data: sheetTheme,
        child: Builder(
          builder: (themedCtx) {
            return appBottomSheetWrap(
              themedCtx,
              Material(
                color: surface,
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: builder(themedCtx),
              ),
            );
          },
        ),
      );
    },
  );
}
