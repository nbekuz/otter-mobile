import '../../data/mappers/task_mapper.dart';
import '../../data/models/ui/ui_models.dart';
import '../network/api_exception.dart';

/// Connection / timeout failures that should be queued, not treated as API errors.
bool isOfflineFailure(Object error) {
  if (error is ApiException && error.networkFailure) return true;
  if (error is! Exception) {
    final raw = error.toString().toLowerCase();
    return _looksOffline(raw);
  }
  final status = _statusCode(error);
  if (status != null) return false;
  return _looksOffline(error.toString().toLowerCase());
}

int? _statusCode(Object error) {
  try {
    final dynamic e = error;
    final code = e.statusCode;
    if (code is int) return code;
  } catch (_) {}
  return null;
}

bool _looksOffline(String raw) {
  return raw.contains('socket') ||
      raw.contains('connection') ||
      raw.contains('network') ||
      raw.contains('timeout') ||
      raw.contains('timed out') ||
      raw.contains('failed host') ||
      raw.contains('offline') ||
      raw.contains('unreachable') ||
      raw.contains('xmlhttprequest') ||
      raw.contains('connection refused') ||
      raw.contains('connection reset') ||
      raw.contains('no address') ||
      raw.contains('semaphore') ||
      raw.contains('no such host') ||
      raw.contains('errno = 121') ||
      raw.contains('errno = 1231') ||
      raw.contains('errno = 10051') ||
      raw.contains('errno = 10060') ||
      raw.contains('errno = 10065') ||
      raw.contains('errno = 11001');
}

/// Fired when a request proves the API is reachable or not.
void Function(bool offline)? onNetworkReachabilityChanged;

void notifyNetworkReachability(bool offline) =>
    onNetworkReachabilityChanged?.call(offline);

/// Fired after a mutation is stored in the outbox (UI banner).
void Function()? onTaskOutboxChanged;

void notifyTaskOutboxChanged() => onTaskOutboxChanged?.call();

bool isLocalTaskId(String id) => id.startsWith('local-');

String newLocalTaskId() =>
    'local-${DateTime.now().microsecondsSinceEpoch}';

Task taskFromPartial(PartialTask partial, String id) {
  return Task(
    id: id,
    title: (partial.title ?? '').trim().isEmpty ? 'Задача' : partial.title!.trim(),
    description: partial.description,
    dueDate: partial.dueDate,
    dueTime: partial.dueTime,
    duration: partial.duration,
    priority: partial.priority ?? Priority.none,
    completed: partial.completed ?? false,
    notification: partial.notification,
    repeat: partial.repeat ?? RepeatType.none,
    repeatDays: partial.repeatDays,
    repeatCustom: partial.repeatCustom,
    matrixBlock: partial.matrixBlock,
    seriesId: partial.seriesId,
    parentTaskId: partial.parentTaskId,
    createdAt: DateTime.now().toIso8601String(),
  );
}
