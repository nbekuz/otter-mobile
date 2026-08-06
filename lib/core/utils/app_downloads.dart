import 'package:dio/dio.dart';

import '../config/env.dart';

/// Match web `DESKTOP_APP` / `APP_PUBLIC_URL` in `otter-app/utils/site-info.ts`.
abstract final class AppDownloads {
  static const publicSiteUrl = 'https://ottertime.ru';
  static const windowsLabel = 'Скачать для Windows';
  static const rustoreLabel = 'Скачать в RuStore';
  static const siteLabel = 'Сайт ottertime.ru';
  static const windowsUnavailable =
      'Десктопная версия пока не загружена. Скачивание будет доступно позже.';
  static const rustoreUnavailable = 'Приложение пока недоступно в RuStore.';

  /// Public endpoints live under `/api/app/`, not `/api/v1/`.
  static String distributionBaseUrl() {
    final v1 = Env.apiBaseUrl;
    final stripped = v1.replaceFirst(RegExp(r'/v1/?$'), '/');
    return stripped.endsWith('/') ? stripped : '$stripped/';
  }

  static String? _nullableUrl(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Future<String?> fetchWindowsDownloadUrl() async {
    final dio = Dio(BaseOptions(
      baseUrl: distributionBaseUrl(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    final response = await dio.get<Map<String, dynamic>>('app/windows');
    return _nullableUrl(response.data?['download_url']);
  }

  static Future<String?> fetchRustoreUrl() async {
    final dio = Dio(BaseOptions(
      baseUrl: distributionBaseUrl(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    final response = await dio.get<Map<String, dynamic>>('app/mobile');
    final data = response.data;
    return _nullableUrl(data?['rustore']) ??
        _nullableUrl(data?['google_play']) ??
        _nullableUrl(data?['app_store']);
  }
}
