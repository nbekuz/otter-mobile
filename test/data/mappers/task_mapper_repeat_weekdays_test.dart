import 'package:flutter_test/flutter_test.dart';
import 'package:otter_mobile/data/mappers/task_mapper.dart';
import 'package:otter_mobile/data/models/api/api_models.dart';
import 'package:otter_mobile/data/models/ui/ui_models.dart';

ApiTask _api({
  required String unit,
  int interval = 1,
  List<int> weekdays = const [],
}) =>
    ApiTask(
      id: 1,
      title: 'T',
      repeatUnit: unit,
      repeatInterval: interval,
      repeatWeekdays: weekdays,
      priority: 'medium',
      matrixBlock: 'not_urgent_not_important',
      isCompleted: false,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
    );

void main() {
  test('week + weekdays maps to custom Настроить повторение', () {
    final ui = TaskMapper.apiToUi(
      _api(unit: 'week', weekdays: const [1, 2, 3, 4, 5]),
    );
    expect(ui.repeat, RepeatType.custom);
    expect(ui.repeatDays, [1, 2, 3, 4, 5]);
    expect(ui.repeatCustom?.weekdays, [1, 2, 3, 4, 5]);
  });

  test('week + empty weekdays maps to plain Каждую неделю', () {
    final ui = TaskMapper.apiToUi(_api(unit: 'week', weekdays: const []));
    expect(ui.repeat, RepeatType.weekly);
    expect(ui.repeatDays, isNull);
    expect(ui.repeatCustom, isNull);
  });

  test('payload always sends repeat_weekdays array', () {
    final custom = TaskMapper.uiToApiPayload(
      PartialTask(
        title: 'T',
        repeat: RepeatType.custom,
        repeatDays: const [1, 3, 5],
        repeatCustom: const RepeatCustom(
          interval: 1,
          unit: 'week',
          weekdays: [1, 3, 5],
        ),
      ),
    );
    expect(custom['repeat_unit'], 'week');
    expect(custom['repeat_weekdays'], [1, 3, 5]);

    final weekly = TaskMapper.uiToApiPayload(
      PartialTask(title: 'T', repeat: RepeatType.weekly),
    );
    expect(weekly['repeat_unit'], 'week');
    expect(weekly['repeat_weekdays'], <int>[]);
  });
}
