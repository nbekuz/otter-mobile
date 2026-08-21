import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/data/mappers/task_mapper.dart';
import 'package:otter_mobile/data/models/ui/ui_models.dart';

void main() {
  test('date-only task does not send reminder_offset_minutes 0', () {
    final payload = TaskMapper.uiToApiPayload(
      PartialTask(
        title: 'No time',
        dueDate: '2026-08-21',
        notification: '0',
      ),
      includeMatrixBlock: false,
    );

    expect(payload['reminder_offset_minutes'], isNull);
    expect(payload['reminder_at'], isNull);
  });

  test('timed task with at-due sends reminder_offset_minutes 0', () {
    final payload = TaskMapper.uiToApiPayload(
      PartialTask(
        title: 'Timed',
        dueDate: '2026-08-21',
        dueTime: '18:00',
        notification: '0',
      ),
      includeMatrixBlock: false,
    );

    expect(payload['reminder_offset_minutes'], 0);
    expect(payload.containsKey('reminder_at'), isFalse);
  });

  test('Без уведомления omits a live reminder offset', () {
    final payload = TaskMapper.uiToApiPayload(
      PartialTask(
        title: 'Silent',
        dueDate: '2026-08-21',
        dueTime: '18:00',
        notification: '',
        clearNotification: true,
      ),
      includeMatrixBlock: false,
    );

    expect(payload['reminder_offset_minutes'], isNull);
  });
}
