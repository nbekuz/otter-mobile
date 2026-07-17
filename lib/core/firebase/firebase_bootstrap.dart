import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/env.dart';
import 'firebase_options.dart';
import 'google_sign_in_desktop.dart';

abstract final class FirebaseBootstrap {
  static Future<void> init() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      _ensureWindowsFirebaseConfigured();
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // FlutterFire Windows example: register after Firebase.initializeApp.
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await configureGoogleSignInDesktop(
        clientId: Env.firebaseGoogleWebClientId,
      );
    }
  }

  static Future<String?> signInWithGoogle() async {
    if (kIsWeb) return null;

    if (defaultTargetPlatform == TargetPlatform.windows) {
      _ensureWindowsFirebaseConfigured();
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

  static void _ensureWindowsFirebaseConfigured() {
    if (Env.firebaseApiKey.isEmpty || Env.firebaseAppId.isEmpty) {
      throw StateError(
        'Windows Firebase is not configured. Set FIREBASE_API_KEY and '
        'FIREBASE_APP_ID in .env (Firebase Console → Web app).',
      );
    }
    if (Env.firebaseGoogleWebClientId.isEmpty) {
      throw StateError(
        'Windows Google Sign-In is not configured. Set '
        'FIREBASE_GOOGLE_WEB_CLIENT_ID in .env (Google Cloud → Web OAuth client).',
      );
    }
  }
}
