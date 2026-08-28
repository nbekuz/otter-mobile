import 'package:flutter/material.dart';

/// Bottom system inset for [AppShell] body when the tab bar is hidden.
///
/// Uses [MediaQuery.viewPadding] so keyboard (viewInsets) does not change
/// navigation-bar spacing.
double shellBodyBottomInset(BuildContext context) =>
    MediaQuery.viewPaddingOf(context).bottom;

/// Bottom padding for modal bottom sheets: keyboard when open, otherwise the
/// system navigation/gesture area.
double bottomSheetBottomInset(BuildContext context) {
  final mq = MediaQuery.of(context);
  return mq.viewInsets.bottom > 0 ? mq.viewInsets.bottom : mq.viewPadding.bottom;
}
