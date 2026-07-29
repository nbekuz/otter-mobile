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

  test('parseApiWallClock converts UTC Z to local wall-clock', () {
    // Instant = 11:30 UTC. Local display must use device offset, not "11:30".
    final offset = DateTime.now().timeZoneOffset;
    final local = DateTime.utc(2026, 7, 28, 11, 30).toLocal();
    final expectedDate =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final expectedTime =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    final parsed = parseApiWallClock('2026-07-28T11:30:00.000Z');
    expect(parsed, isNotNull);
    expect(parsed!.date, expectedDate);
    expect(parsed.time, expectedTime);
    // Sanity: with a non-zero offset the time digits must move off 11:30.
    if (offset.inMinutes != 0) {
      expect(parsed.time, isNot('11:30'));
    }
  });

  test('parseApiWallClock round-trips local offset strings', () {
    final sent = toApiDateTime('2026-07-28', '16:30');
    final parsed = parseApiWallClock(sent);
    expect(parsed, isNotNull);
    expect(parsed!.date, '2026-07-28');
    expect(parsed.time, '16:30');
  });
}
