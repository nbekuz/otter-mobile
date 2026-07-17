import 'package:flutter/material.dart';

abstract final class KeyboardDismisser {
  static void dismiss() {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

void dismissKeyboardOnTapOutside(PointerDownEvent _) {
  KeyboardDismisser.dismiss();
}
