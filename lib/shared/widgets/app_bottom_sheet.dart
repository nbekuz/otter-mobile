import 'package:flutter/material.dart';

import '../../core/layout/responsive.dart';

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

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useSafeArea = true,
  Color? backgroundColor,
  ShapeBorder? shape,
  double dialogMaxWidth = 520,
}) {
  if (Responsive.isWide(context)) {
    return showDialog<T>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: backgroundColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
            ),
            child: builder(ctx),
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
      return appBottomSheetWrap(
        ctx,
        Material(
          color: backgroundColor ?? Colors.white,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: builder(ctx),
        ),
      );
    },
  );
}
