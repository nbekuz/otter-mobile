import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class Env {
  static bool loadedFromFile = false;

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
      loadedFromFile = true;
    } catch (e) {
      // .env optional in tests; Windows Google Sign-In needs a local .env.
      loadedFromFile = false;
      // ignore: avoid_print
      print(
        '[Env] Failed to load .env ($e). '
        'Copy .env.example → .env and fill FIREBASE_GOOGLE_DESKTOP_CLIENT_SECRET.',
      );
    }
  }

  /// Prefer non-empty `.env` value; otherwise [fallback].
  /// Empty `KEY=` in `.env.example` must not block defaults (`??` alone won't).
  static String _envOr(String key, String fallback) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  static String get apiBaseUrl {
    final raw = _envOr('API_BASE_URL', 'https://admin.ottertime.ru/api/v1/');
    return raw.endsWith('/') ? raw : '$raw/';
  }

  /// RuStore Console application id (https://console.rustore.ru/apps/{id}).
  /// Required for Android billing; override via `.env` / `--dart-define`.
  static String get rustoreConsoleAppId =>
      _envOr('RUSTORE_CONSOLE_APP_ID', '');

  /// Web / Windows (Firebase Console web app) — same defaults as otter-app.
  static String get firebaseApiKey => _envOr(
        'FIREBASE_API_KEY',
        'AIzaSyCwg8YuF1oNhGbhqTwo08wQTjjtYEe9_S4',
      );

  /// Android — from `google-services.json` → `api_key.current_key`.
  static String get firebaseAndroidApiKey => _envOr(
        'FIREBASE_ANDROID_API_KEY',
        'AIzaSyCBQdQbu0sLjzxW4GpCXjuwzxYmLc6rc1I',
      );

  static String get firebaseAuthDomain =>
      _envOr('FIREBASE_AUTH_DOMAIN', 'otter-6bdac.firebaseapp.com');
  static String get firebaseProjectId =>
      _envOr('FIREBASE_PROJECT_ID', 'otter-6bdac');
  static String get firebaseStorageBucket =>
      _envOr('FIREBASE_STORAGE_BUCKET', 'otter-6bdac.firebasestorage.app');
  static String get firebaseMessagingSenderId =>
      _envOr('FIREBASE_MESSAGING_SENDER_ID', '911773858551');

  /// Web / Windows app id (Firebase Console → Web app).
  static String get firebaseAppId => _envOr(
        'FIREBASE_APP_ID',
        '1:911773858551:web:dd939daa464da5af74f1f2',
      );

  /// Android — `mobilesdk_app_id` in `google-services.json`.
  static String get firebaseAndroidAppId => _envOr(
        'FIREBASE_ANDROID_APP_ID',
        '1:911773858551:android:7ede2334df1f5c5874f1f2',
      );

  /// OAuth Web client (client_type 3) — Android [GoogleSignIn.serverClientId].
  static String get firebaseGoogleServerClientId => _envOr(
        'FIREBASE_GOOGLE_SERVER_CLIENT_ID',
        '911773858551-23po5m63ppifv4kqmi9uphkcoo1iq6fb.apps.googleusercontent.com',
      );

  /// OAuth Web client ID used by the existing web configuration.
  static String get firebaseGoogleWebClientId => _envOr(
        'FIREBASE_GOOGLE_WEB_CLIENT_ID',
        firebaseGoogleServerClientId,
      );

  /// OAuth Desktop ("installed") client for Windows loopback PKCE sign-in.
  ///
  /// Must match Google Cloud Console → Credentials → Desktop client.
  /// Public identifier (safe to embed); override via .env when needed.
  static String get firebaseGoogleDesktopClientId => _envOr(
        'FIREBASE_GOOGLE_DESKTOP_CLIENT_ID',
        '911773858551-bbjtglnabr6hcakovna9qbvm9c0tegr9.apps.googleusercontent.com',
      );

  /// Desktop client secret from Google Cloud Console (no source default).
  ///
  /// Google's native-app docs mark `client_secret` Optional, but Desktop
  /// clients created in Cloud Console are issued with a secret and the token
  /// endpoint returns `client_secret is missing` if it is omitted. Load only
  /// from `.env` — never hardcode in Dart sources.
  static String get firebaseGoogleDesktopClientSecret =>
      dotenv.env['FIREBASE_GOOGLE_DESKTOP_CLIENT_SECRET']?.trim() ?? '';

  static String? get firebaseMeasurementId {
    final value = dotenv.env['FIREBASE_MEASUREMENT_ID']?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
