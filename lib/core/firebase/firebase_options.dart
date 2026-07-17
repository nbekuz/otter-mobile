import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import '../config/env.dart';

/// FlutterFire options per platform.
///
/// Windows uses the same Firebase **Web app** credentials as the browser build
/// (`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_AUTH_DOMAIN`, …).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        return android;
    }
  }

  static bool get isWindowsConfigured =>
      Env.firebaseApiKey.isNotEmpty && Env.firebaseAppId.isNotEmpty;

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: Env.firebaseApiKey,
    appId: Env.firebaseAppId,
    messagingSenderId: Env.firebaseMessagingSenderId,
    projectId: Env.firebaseProjectId,
    authDomain: Env.firebaseAuthDomain,
    storageBucket: Env.firebaseStorageBucket,
    measurementId: Env.firebaseMeasurementId,
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: Env.firebaseAndroidApiKey,
    appId: Env.firebaseAndroidAppId,
    messagingSenderId: Env.firebaseMessagingSenderId,
    projectId: Env.firebaseProjectId,
    storageBucket: Env.firebaseStorageBucket,
  );

  /// Windows desktop — Firebase Web app configuration.
  static FirebaseOptions get windows => FirebaseOptions(
    apiKey: Env.firebaseApiKey,
    appId: Env.firebaseAppId,
    messagingSenderId: Env.firebaseMessagingSenderId,
    projectId: Env.firebaseProjectId,
    authDomain: Env.firebaseAuthDomain,
    storageBucket: Env.firebaseStorageBucket,
  );
}
