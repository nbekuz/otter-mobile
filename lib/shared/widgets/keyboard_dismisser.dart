import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

abstract final class KeyboardDismisser {
  static void dismiss() {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

/// Safe [TextField.onTapOutside] handler.
///
/// On Android, opening the IME after the first character resizes the view and
/// often fires a false "tap outside", which would kill the keyboard if we
/// always [unfocus]. Only dismiss for pointer kinds that do not have that bug
/// (mouse / trackpad / stylus). Touch outside-taps are handled by
/// [KeyboardDismissOnTap] instead.
void dismissKeyboardOnTapOutside(PointerDownEvent event) {
  switch (event.kind) {
    case PointerDeviceKind.mouse:
    case PointerDeviceKind.trackpad:
    case PointerDeviceKind.stylus:
    case PointerDeviceKind.invertedStylus:
      KeyboardDismisser.dismiss();
      return;
    case PointerDeviceKind.touch:
    case PointerDeviceKind.unknown:
      return;
  }
}

/// Dismisses the soft keyboard when the user taps empty space.
///
/// Uses [HitTestBehavior.deferToChild] so taps on buttons (e.g. back) are not
/// stolen / re-routed after the IME resizes the layout.
class KeyboardDismissOnTap extends StatelessWidget {
  const KeyboardDismissOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: KeyboardDismisser.dismiss,
      behavior: HitTestBehavior.deferToChild,
      child: child,
    );
  }
}
