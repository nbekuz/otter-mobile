import 'package:flutter_timezone/flutter_timezone.dart';

/// Best-effort IANA timezone for settings sync.
Future<String> deviceTimezone() async {
  try {
    final tz = await FlutterTimezone.getLocalTimezone();
    if (tz.isNotEmpty) return tz;
  } catch (_) {}
  return 'UTC';
}
