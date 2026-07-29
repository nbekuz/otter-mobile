/// API datetime as wall-clock (no TZ shift), e.g. `2026-06-12T10:19:00+03:00` → 10:19.
({String date, String time})? parseApiWallClock(String iso) {
  final match = RegExp(r'^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2})').firstMatch(iso);
  if (match == null) return null;
  return (date: match.group(1)!, time: '${match.group(2)}:${match.group(3)}');
}

/// Local UTC offset as ISO suffix, e.g. `+05:00` / `-07:00`.
///
/// Uses [DateTime.now] so we never depend on how [DateTime.parse] treats
/// timezone-less strings on a given platform.
String formatLocalTimezoneOffset([DateTime? at]) {
  final offset = (at ?? DateTime.now()).timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final oh = abs.inHours.toString().padLeft(2, '0');
  final om = (abs.inMinutes % 60).toString().padLeft(2, '0');
  return '$sign$oh:$om';
}

/// Wall-clock `dueDate` + `HH:mm` with the device timezone offset.
///
/// Example: `2026-07-28T16:30:00.000+05:00`
String toApiDateTime(String dueDate, String time) {
  final day = dueDate.trim();
  if (day.isEmpty || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
    throw ArgumentError.value(dueDate, 'dueDate', 'Expected yyyy-MM-dd');
  }
  final raw = time.trim();
  final hhmm = raw.length >= 5 ? raw.substring(0, 5) : raw;
  if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(hhmm)) {
    throw ArgumentError.value(time, 'time', 'Expected HH:mm');
  }
  return '${day}T$hhmm:00.000${formatLocalTimezoneOffset()}';
}

int parseTimeToMinutes(String time) {
  final parts = time.split(':');
  if (parts.length < 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}

String formatMinutesToTime(int totalMinutes) {
  // Never roll into the next day — clamp to 23:59.
  final clamped = totalMinutes.clamp(0, 23 * 60 + 59);
  final hours = clamped ~/ 60;
  final minutes = clamped % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
}

/// Add minutes to HH:mm; results past 23:59 are clamped to 23:59 (no day rollover).
String addMinutesToTime(String time, int deltaMinutes) =>
    formatMinutesToTime(parseTimeToMinutes(time) + deltaMinutes);

/// Default duration end = start + 1 hour (clamped to 23:59).
String defaultDurationEnd(String start) => addMinutesToTime(start, 60);

bool isDefaultDurationEnd(String start, String end) =>
    start.trim().isNotEmpty &&
    end.trim().isNotEmpty &&
    end == defaultDurationEnd(start);

const durationEndAfterStartMessage =
    'Время окончания должно быть позже времени начала.';

const durationBothRequiredMessage = 'Укажите и начало, и конец длительности';

String? validateDurationFields(String? start, String? end) {
  final hasStart = start?.trim().isNotEmpty == true;
  final hasEnd = end?.trim().isNotEmpty == true;

  if (hasStart != hasEnd) {
    return durationBothRequiredMessage;
  }

  if (hasStart &&
      hasEnd &&
      parseTimeToMinutes(end!) <= parseTimeToMinutes(start!)) {
    return durationEndAfterStartMessage;
  }

  return null;
}

String? taskScheduleStart({String? dueTime, String? durationStart}) =>
    durationStart ?? dueTime;

int taskDurationMinutes({String? durationStart, String? durationEnd}) {
  if (durationStart != null &&
      durationEnd != null &&
      durationStart.isNotEmpty &&
      durationEnd.isNotEmpty) {
    final start = parseTimeToMinutes(durationStart);
    final end = parseTimeToMinutes(durationEnd);
    if (end > start) return end - start;
    if (end < start) return (24 * 60 - start) + end;
  }
  return 60;
}

int snapMinutes(int minutes) =>
    ((minutes / 5).round() * 5).clamp(0, 23 * 60 + 59);

const calendarMinDurationMinutes = 10;

const repeatIntervalMax = 31;
const repeatIntervalMaxMessage =
    'Интервал повторения должен быть не больше 31';

String? validateRepeatInterval(int interval) {
  if (interval < 1) {
    return 'Интервал повторения должен быть не меньше 1';
  }
  if (interval > repeatIntervalMax) {
    return repeatIntervalMaxMessage;
  }
  return null;
}
