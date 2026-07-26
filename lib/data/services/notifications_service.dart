import '../../core/network/api_client.dart';
import '../models/api/api_models.dart';

class NotificationsService {
  NotificationsService(this._client);
  final ApiClient _client;

  Future<ApiNotificationsPage> list({
    bool? isRead,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      'notifications/',
      queryParameters: {
        if (isRead != null) 'is_read': isRead,
        'limit': limit,
        'offset': offset,
      },
    );
    return ApiNotificationsPage.fromJson(data);
  }

  Future<int> unreadCount() async {
    final data = await _client.get<Map<String, dynamic>>(
      'notifications/unread-count/',
    );
    return data['unread_count'] as int? ?? 0;
  }

  Future<void> markRead(int id) async {
    await _client.post('notifications/$id/read/', data: {});
  }

  Future<int> markAllRead() async {
    final data = await _client.post<Map<String, dynamic>>(
      'notifications/read-all/',
      data: {},
    );
    return data['unread_count'] as int? ?? 0;
  }

  Future<void> delete(int id) async {
    await _client.delete('notifications/$id/');
  }
}
