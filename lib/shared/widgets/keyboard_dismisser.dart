import 'package:flutter/material.dart';

abstract final class KeyboardDismisser {
  static void dismiss() {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

void dismissKeyboardOnTapOutside(PointerDownEvent _) {
  KeyboardDismisser.dismiss();
}

/// Dismisses the soft keyboard without competing in the gesture arena.
///
/// Uses [Listener] instead of [GestureDetector] so mouse clicks on Windows
/// still reach [FilledButton], [InkWell], [ListTile], etc.
class KeyboardDismissScope extends StatelessWidget {
  const KeyboardDismissScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => KeyboardDismisser.dismiss(),
      child: child,
    );
  }
}

/// Scroll view that fills the viewport when height is bounded and dismisses
/// the keyboard on pointer-down without blocking child buttons.
class DismissKeyboardScrollView extends StatelessWidget {
  const DismissKeyboardScrollView({
    super.key,
    required this.child,
    this.padding,
    this.controller,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final hasBoundedHeight = maxH.isFinite && maxH > 0;

        Widget content = KeyboardDismissScope(child: child);
        if (hasBoundedHeight) {
          content = ConstrainedBox(
            constraints: BoxConstraints(minHeight: maxH),
            child: content,
          );
        }

        return SingleChildScrollView(
          controller: controller,
          padding: padding,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: content,
        );
      },
    );
  }
}
