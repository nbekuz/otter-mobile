import '../models/api/api_models.dart';
import '../models/ui/ui_models.dart';
import '../../core/network/api_client.dart';

class SettingsService {
  SettingsService(this._client);
  final ApiClient _client;

  AppSettings _apiToUi(ApiAppSettings data) {
    final visible = <String>[];
    if (data.showOverdue) visible.add('overdue');
    if (data.showToday) visible.add('today');
    if (data.showTomorrow) visible.add('tomorrow');
    if (data.showLater) visible.add('later');
    if (data.showNoDeadline) visible.add('nodate');
    if (data.showCompleted) visible.add('completed');

    return AppSettings(
      language: data.language,
      theme: 'light',
      visibleGroups: visible.isNotEmpty
          ? visible
          : AppSettings.defaults().visibleGroups,
      notifications: AppSettings.defaults().notifications,
      vibration: data.vibrationEnabled,
      notificationSound: data.notificationSound,
      completionSound: data.completionSound,
      bottomNavItems: data.bottomTabs.isNotEmpty
          ? data.bottomTabs
          : AppSettings.defaults().bottomNavItems,
      timezone: data.timezone,
      isPremium: data.isPremium,
    );
  }

  Map<String, dynamic> _uiToPatch(AppSettings settings) => {
    'language': settings.language,
    if (settings.timezone != null && settings.timezone!.isNotEmpty)
      'timezone': settings.timezone,
    'vibration_enabled': settings.vibration,
    'notification_sound': settings.notificationSound,
    'completion_sound': settings.completionSound,
    'bottom_tabs': settings.bottomNavItems,
    'show_overdue': settings.visibleGroups.contains('overdue'),
    'show_today': settings.visibleGroups.contains('today'),
    'show_tomorrow': settings.visibleGroups.contains('tomorrow'),
    'show_later': settings.visibleGroups.contains('later'),
    'show_no_deadline': settings.visibleGroups.contains('nodate'),
    'show_completed': settings.visibleGroups.contains('completed'),
  };

  Future<AppSettings> fetchSettings() async {
    final data = await _client.get<Map<String, dynamic>>('settings/');
    return _apiToUi(ApiAppSettings.fromJson(data));
  }

  Future<AppSettings> patchSettings(AppSettings settings) async {
    final data = await _client.patch<Map<String, dynamic>>(
      'settings/',
      data: _uiToPatch(settings),
    );
    return _apiToUi(ApiAppSettings.fromJson(data));
  }

  Future<List<ApiHelpItem>> fetchHelp({String? search}) async {
    final data = await _client.get<List<dynamic>>(
      'help/',
      queryParameters: search != null && search.trim().isNotEmpty
          ? {'search': search.trim()}
          : null,
    );
    return data
        .map((e) => ApiHelpItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendHelpMessage(String message, {String? screenshotPath}) async {
    final trimmed = message.trim();
    if (screenshotPath != null) {
      // multipart if needed — screenshot path reserved for future upload
    }
    await _client.post('help/', data: {'message': trimmed});
  }

  Future<String> callStubAction() async {
    final data = await _client.post<Map<String, dynamic>>(
      'settings/stub-action/',
    );
    return data['detail'] as String? ??
        'Уже разрабатываем, скоро будет готово :)';
  }

  Future<List<ApiPremiumFeature>> fetchPremiumFeatures() async {
    final data = await _client.get<List<dynamic>>('premium/features/');
    return data
        .map((e) => ApiPremiumFeature.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ApiLegalDocument>> fetchLegalDocuments() async {
    final data = await _client.get<List<dynamic>>('legal/documents/');
    return data
        .map((e) => ApiLegalDocument.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
