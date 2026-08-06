import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('otter/window_theme');

/// Syncs the Windows title bar with the in-app light/dark theme.
Future<void> syncWindowsTitleBarTheme(bool isDark) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
  try {
    await _channel.invokeMethod<void>('setTitleBarDark', isDark);
  } catch (_) {
    // Channel missing on non-Windows builds / older runners — ignore.
  }
}
