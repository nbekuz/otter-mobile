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
    // Normalize accidental `https://host//api/...` from mis-copied .env values.
    final uri = Uri.parse(raw);
    final normalized = uri.replace(path: uri.path).toString();
    final withSlash = normalized.endsWith('/') ? normalized : '$normalized/';
    return withSlash.replaceAll(RegExp(r'(?<!:)/{2,}'), '/');
  }

  /// RuStore Console application id (https://console.rustore.ru/apps/{id}).
  /// Required for Android billing; override via `.env` / `--dart-define`.
  static String get rustoreConsoleAppId =>
      _envOr('RUSTORE_CONSOLE_APP_ID', '');

  /// Web / Windows (Firebase Console web app) — same defaults as otter-app.
  static String get firebaseApiKey => _envOr(
        'FIREBASE_API_KEY',
        'AIzaSyDQ_2x_veKhySiORFRc_6HpjcDaPlx6KBE',
      );

  /// Android — from `google-services.json` → `api_key.current_key`.
  static String get firebaseAndroidApiKey => _envOr(
        'FIREBASE_ANDROID_API_KEY',
        'AIzaSyDR84j5YLZhyO5SxJV92TUpZMwLuQMVLZw',
      );

  static String get firebaseAuthDomain =>
      _envOr('FIREBASE_AUTH_DOMAIN', 'otter-78857.firebaseapp.com');
  static String get firebaseProjectId =>
      _envOr('FIREBASE_PROJECT_ID', 'otter-78857');
  static String get firebaseStorageBucket =>
      _envOr('FIREBASE_STORAGE_BUCKET', 'otter-78857.firebasestorage.app');
  static String get firebaseMessagingSenderId =>
      _envOr('FIREBASE_MESSAGING_SENDER_ID', '523879790697');

  /// Android Firebase project (`google-services.json`).
  /// Same project as web/Windows (`otter-78857`); kept separate so keys can differ.
  static String get firebaseAndroidProjectId =>
      _envOr('FIREBASE_ANDROID_PROJECT_ID', 'otter-78857');
  static String get firebaseAndroidStorageBucket => _envOr(
        'FIREBASE_ANDROID_STORAGE_BUCKET',
        'otter-78857.firebasestorage.app',
      );
  static String get firebaseAndroidMessagingSenderId =>
      _envOr('FIREBASE_ANDROID_MESSAGING_SENDER_ID', '523879790697');

  /// Web / Windows app id (Firebase Console → Web app).
  static String get firebaseAppId => _envOr(
        'FIREBASE_APP_ID',
        '1:523879790697:web:113c764eaab668bebacaf8',
      );

  /// Android — `mobilesdk_app_id` in `google-services.json`.
  static String get firebaseAndroidAppId => _envOr(
        'FIREBASE_ANDROID_APP_ID',
        '1:523879790697:android:4f5748deb0e257ddbacaf8',
      );

  /// OAuth Web client (client_type 3) — Android [GoogleSignIn.serverClientId].
  static String get firebaseGoogleServerClientId => _envOr(
        'FIREBASE_GOOGLE_SERVER_CLIENT_ID',
        '523879790697-6k1mjnk4aqsqhns4iu2bv0gvge3hv8p2.apps.googleusercontent.com',
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
        '382071855330-u3a784h8ukfnns0eltnsn7cbgj81f41e.apps.googleusercontent.com',
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
    final value = _envOr('FIREBASE_MEASUREMENT_ID', 'G-BENPFYCBZM');
    if (value.isEmpty) return null;
    return value;
  }
}
