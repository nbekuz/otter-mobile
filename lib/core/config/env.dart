import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class Env {
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // .env optional in tests
    }
  }

  static String get apiBaseUrl {
    final raw =
        dotenv.env['API_BASE_URL'] ?? 'https://admin.skkamni.ru/api/v1/';
    return raw.endsWith('/') ? raw : '$raw/';
  }

  /// Web / Windows (Firebase Console web app).
  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';

  /// Android — from `google-services.json` → `api_key.current_key`.
  static String get firebaseAndroidApiKey =>
      dotenv.env['FIREBASE_ANDROID_API_KEY'] ??
      'AIzaSyCBQdQbu0sLjzxW4GpCXjuwzxYmLc6rc1I';

  static String get firebaseAuthDomain =>
      dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? 'otter-6bdac.firebaseapp.com';
  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ?? 'otter-6bdac';
  static String get firebaseStorageBucket =>
      dotenv.env['FIREBASE_STORAGE_BUCKET'] ??
      'otter-6bdac.firebasestorage.app';
  static String get firebaseMessagingSenderId =>
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '911773858551';

  /// Web app id (optional on Android).
  static String get firebaseAppId => dotenv.env['FIREBASE_APP_ID'] ?? '';

  /// Android — `mobilesdk_app_id` in `google-services.json`.
  static String get firebaseAndroidAppId =>
      dotenv.env['FIREBASE_ANDROID_APP_ID'] ??
      '1:911773858551:android:7ede2334df1f5c5874f1f2';

  /// OAuth Web client (client_type 3) — Android [GoogleSignIn.serverClientId].
  static String get firebaseGoogleServerClientId =>
      dotenv.env['FIREBASE_GOOGLE_SERVER_CLIENT_ID'] ??
      '911773858551-23po5m63ppifv4kqmi9uphkcoo1iq6fb.apps.googleusercontent.com';

  /// OAuth Web client ID — Windows desktop Google Sign-In
  /// ([GoogleSignInDart.register] / loopback OAuth in the system browser).
  ///
  /// Use the **Web application** client from Google Cloud Console, not a
  /// separate "Desktop" OAuth client. Falls back to [firebaseGoogleServerClientId].
  static String get firebaseGoogleWebClientId =>
      dotenv.env['FIREBASE_GOOGLE_WEB_CLIENT_ID'] ??
      firebaseGoogleServerClientId;

  static String? get firebaseMeasurementId =>
      dotenv.env['FIREBASE_MEASUREMENT_ID'];
}
