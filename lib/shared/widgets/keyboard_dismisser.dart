import 'package:flutter/material.dart';

abstract final class KeyboardDismisser {
  static void dismiss() {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

void dismissKeyboardOnTapOutside(PointerDownEvent _) {
  KeyboardDismisser.dismiss();
}

/// Scroll view that fills the viewport and dismisses the keyboard on outside tap
/// or drag.
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
        return SingleChildScrollView(
          controller: controller,
          padding: padding,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: GestureDetector(
              onTap: KeyboardDismisser.dismiss,
              behavior: HitTestBehavior.translucent,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
