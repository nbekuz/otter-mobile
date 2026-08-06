import 'package:flutter/foundation.dart';

/// Structured logs for RuStore Billing (never log full purchase tokens).
abstract final class BillingLogger {
  static const _tag = '[RuStoreBilling]';

  static void info(String message) => debugPrint('$_tag $message');

  static void error(String message, [Object? error, StackTrace? stack]) {
    debugPrint('$_tag ERROR $message${error != null ? ': $error' : ''}');
    if (stack != null) debugPrint('$stack');
  }

  static String truncateToken(String? token) {
    if (token == null || token.isEmpty) return '(empty)';
    if (token.length <= 12) return '***';
    return '${token.substring(0, 6)}…${token.substring(token.length - 4)}';
  }
}
