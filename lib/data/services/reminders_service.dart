import '../../core/network/api_client.dart';

class RemindersService {
  RemindersService(this._client);
  final ApiClient _client;

  Future<void> complete(int taskId) async {
    await _client.post('reminders/$taskId/complete/', data: {});
  }

  Future<void> snooze(int taskId, {int minutes = 10}) async {
    await _client.post(
      'reminders/$taskId/snooze/',
      data: {'minutes': minutes.clamp(1, 1440)},
    );
  }

  Future<void> ack(int taskId) async {
    await _client.post('reminders/$taskId/ack/', data: {});
  }

  Future<List<Map<String, dynamic>>> due() async {
    final data = await _client.get<List<dynamic>>('reminders/due/');
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
