import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/core/utils/time_utils.dart';

void main() {
  test('toApiDateTime appends local timezone offset', () {
    final offset = formatLocalTimezoneOffset();
    expect(toApiDateTime('2026-07-28', '16:30'), '2026-07-28T16:30:00.000$offset');
  });

  test('toApiDateTime normalizes HH:mm:ss to HH:mm', () {
    final offset = formatLocalTimezoneOffset();
    expect(toApiDateTime('2026-07-28', '09:05:00'), '2026-07-28T09:05:00.000$offset');
  });

  test('formatLocalTimezoneOffset matches DateTime.now offset', () {
    final offset = DateTime.now().timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final expected =
        '$sign${abs.inHours.toString().padLeft(2, '0')}:${(abs.inMinutes % 60).toString().padLeft(2, '0')}';
    expect(formatLocalTimezoneOffset(), expected);
  });
}
