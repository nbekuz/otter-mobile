import '../models/api/api_models.dart';
import '../models/ui/ui_models.dart';
import '../../core/network/api_client.dart';

class PomodoroSettingsData {
  PomodoroSettingsData({
    required this.settings,
    this.timerEndSoundDetail,
    this.workSoundDetail,
  });

  final PomodoroSettings settings;
  final ApiSound? timerEndSoundDetail;
  final ApiSound? workSoundDetail;
}

PomodoroSettingsData _mapSettings(ApiPomodoroSettings api) => PomodoroSettingsData(
      settings: PomodoroSettings(
        duration: api.durationMinutes,
        shortBreak: api.shortBreakMinutes,
        longBreak: 15,
        sessionsUntilLong: 4,
        sound: api.timerEndSound,
        workingSound: api.workSound,
        showOnLockScreen: api.showOnLockScreen,
      ),
      timerEndSoundDetail: api.timerEndSoundDetail,
      workSoundDetail: api.workSoundDetail,
    );

class PomodoroService {
  PomodoroService(this._client);
  final ApiClient _client;

  Future<PomodoroSettingsData> fetchSettings() async {
    final data =
        await _client.get<Map<String, dynamic>>('pomodoro/settings/');
    return _mapSettings(ApiPomodoroSettings.fromJson(data));
  }

  Future<PomodoroSettingsData> updateSettings(Map<String, dynamic> patch) async {
    final data = await _client.patch<Map<String, dynamic>>(
      'pomodoro/settings/',
      data: patch,
    );
    return _mapSettings(ApiPomodoroSettings.fromJson(data));
  }

  Future<List<ApiPomodoroSession>> fetchSessions() async {
    final data = await _client.get<List<dynamic>>('pomodoro/sessions/');
    return data
        .map((e) => ApiPomodoroSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ApiPomodoroSession> createSession({
    int? taskId,
    required int durationMinutes,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      'pomodoro/sessions/',
      data: {
        if (taskId != null) 'task': taskId,
        'duration_minutes': durationMinutes,
      },
    );
    return ApiPomodoroSession.fromJson(data);
  }

  Future<ApiPomodoroSession> updateSessionState(
    int sessionId,
    String state,
  ) async {
    final data = await _client.post<Map<String, dynamic>>(
      'pomodoro/sessions/$sessionId/state/',
      data: {'state': state},
    );
    return ApiPomodoroSession.fromJson(data);
  }
}
