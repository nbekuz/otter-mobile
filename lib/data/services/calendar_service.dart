import '../mappers/task_mapper.dart';
import '../models/api/api_models.dart';
import '../models/ui/ui_models.dart';
import '../../core/network/api_client.dart';

enum CalendarView { day, week, month, year }

extension CalendarViewX on CalendarView {
  String get apiValue => name;
}

class CalendarService {
  CalendarService(this._client);
  final ApiClient _client;

  Future<List<Task>> fetchCalendar({
    required CalendarView view,
    required String date,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      'calendar/',
      queryParameters: {'view': view.apiValue, 'date': date},
    );
    final response = ApiCalendarResponse.fromJson(data);
    return response.tasks.map(TaskMapper.apiToUi).toList();
  }
}
