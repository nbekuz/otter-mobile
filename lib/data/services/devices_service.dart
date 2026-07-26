import '../../core/network/api_client.dart';

class DevicesService {
  DevicesService(this._client);
  final ApiClient _client;

  /// Upsert FCM device. Returns server numeric id when present.
  Future<int?> registerDevice({
    required String token,
    required String deviceId,
    required String platform,
    String? name,
    String? appVersion,
  }) async {
    final data = await _client.post<dynamic>(
      'devices/',
      data: {
        'token': token,
        'device_id': deviceId,
        'platform': platform,
        if (name != null && name.isNotEmpty) 'name': name,
        if (appVersion != null && appVersion.isNotEmpty)
          'app_version': appVersion,
      },
    );
    if (data is! Map) return null;
    final id = data['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return null;
  }

  Future<List<Map<String, dynamic>>> listDevices() async {
    final data = await _client.get<List<dynamic>>('devices/');
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> deleteDevice(int id) async {
    await _client.delete('devices/$id/');
  }
}
