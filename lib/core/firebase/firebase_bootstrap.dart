import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/env.dart';
import 'firebase_options.dart';
import 'google_sign_in_desktop.dart';

abstract final class FirebaseBootstrap {
  /// Set when Windows Google/Firebase env is incomplete (survives swallowed init).
  static String? windowsConfigError;

  static Future<void> init() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      windowsConfigError = _windowsConfigErrorMessage();
      if (windowsConfigError != null) {
        throw StateError(windowsConfigError!);
      }
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  static Future<String?> signInWithGoogle() async {
    if (kIsWeb) return null;

    if (defaultTargetPlatform == TargetPlatform.windows) {
      windowsConfigError = _windowsConfigErrorMessage();
      if (windowsConfigError != null) {
        throw StateError(windowsConfigError!);
      }
      return signInWithGoogleDesktop(
        clientId: Env.firebaseGoogleDesktopClientId,
        clientSecret: Env.firebaseGoogleDesktopClientSecret,
      );
    }

    final googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: defaultTargetPlatform == TargetPlatform.android
          ? Env.firebaseGoogleServerClientId
          : null,
    );

    final account = await googleSignIn.signIn();
    if (account == null) return null;

    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );

    final userCredential = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    return userCredential.user?.getIdToken();
  }

  static Future<void> signOut() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await signOutGoogleDesktop();
    }
  }

  static Future<String?> refreshIdToken({bool forceRefresh = true}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return refreshGoogleFirebaseTokenDesktop(forceRefresh: forceRefresh);
    }
    return FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);
  }

  /// Human-readable blocker for Windows Google Sign-In, or null if ready.
  static String? _windowsConfigErrorMessage() {
    if (Env.firebaseApiKey.isEmpty || Env.firebaseAppId.isEmpty) {
      return 'Windows Firebase не настроен. Укажите FIREBASE_API_KEY и '
          'FIREBASE_APP_ID в .env (Firebase Console → Web app).';
    }
    if (Env.firebaseGoogleDesktopClientId.isEmpty) {
      return 'Windows Google Sign-In: задайте FIREBASE_GOOGLE_DESKTOP_CLIENT_ID '
          'в .env (Google Cloud → Desktop OAuth client).';
    }
    if (Env.firebaseGoogleDesktopClientSecret.isEmpty) {
      return 'Windows Google Sign-In: задайте FIREBASE_GOOGLE_DESKTOP_CLIENT_SECRET '
          'в .env. Скопируйте .env.example → .env и вставьте Client secret из '
          'Google Cloud → Credentials → Desktop OAuth client '
          '(файл .env в Git не попадает).';
    }
    return null;
  }
}
