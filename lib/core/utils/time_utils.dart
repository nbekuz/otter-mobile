/// API datetime as wall-clock (no TZ shift), e.g. `2026-06-12T10:19:00+03:00` → 10:19.
({String date, String time})? parseApiWallClock(String iso) {
  final match = RegExp(r'^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2})').firstMatch(iso);
  if (match == null) return null;
  return (date: match.group(1)!, time: '${match.group(2)}:${match.group(3)}');
}

int parseTimeToMinutes(String time) {
  final parts = time.split(':');
  if (parts.length < 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}

String formatMinutesToTime(int totalMinutes) {
  final clamped = totalMinutes.clamp(0, 23 * 60 + 59);
  final hours = clamped ~/ 60;
  final minutes = clamped % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
}

String addMinutesToTime(String time, int deltaMinutes) =>
    formatMinutesToTime(parseTimeToMinutes(time) + deltaMinutes);

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
