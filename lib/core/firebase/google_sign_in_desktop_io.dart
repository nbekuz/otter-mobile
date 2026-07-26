import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'windows_google_oauth.dart';

const _logTag = '[otter:windows-google-auth]';

Future<String?> signInWithGoogleDesktop({
  required String clientId,
  required String clientSecret,
}) async {
  _ensureWindows();

  try {
    debugPrint(
      '$_logTag starting Google OAuth '
      '(client_id=$clientId, client_secret_configured=${clientSecret.isNotEmpty})',
    );

    final tokens = await WindowsGoogleOAuth(
      clientId: clientId,
      clientSecret: clientSecret,
    ).signIn();
    if (tokens == null) {
      debugPrint('$_logTag user cancelled Google OAuth');
      return null;
    }

    debugPrint(
      '$_logTag Firebase signInWithCredential '
      '(has_access_token=${tokens.accessToken.isNotEmpty}, '
      'has_id_token=${tokens.idToken.isNotEmpty})',
    );

    final credential = GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    final firebaseToken = await result.user?.getIdToken();

    debugPrint(
      '$_logTag Firebase sign-in OK '
      '(uid=${result.user?.uid}, has_firebase_id_token=${firebaseToken != null})',
    );

    return firebaseToken;
  } on WindowsGoogleOAuthException catch (error) {
    debugPrint('$_logTag OAuth failed (${error.code}): ${error.message}');
    throw StateError(error.message);
  } on FirebaseAuthException catch (error) {
    debugPrint(
      '$_logTag Firebase failed (${error.code}): ${error.message}',
    );
    throw StateError(_firebaseErrorMessage(error));
  } on SocketException {
    debugPrint('$_logTag network error');
    throw StateError('Нет подключения к интернету. Попробуйте ещё раз.');
  }
}

Future<void> signOutGoogleDesktop() async {
  _ensureWindows();
  await FirebaseAuth.instance.signOut();
}

Future<String?> refreshGoogleFirebaseTokenDesktop({
  bool forceRefresh = true,
}) async {
  _ensureWindows();
  return FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh);
}

void _ensureWindows() {
  if (!Platform.isWindows) {
    throw UnsupportedError('Desktop Google Sign-In is Windows-only.');
  }
}

String _firebaseErrorMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'account-exists-with-different-credential' =>
      'Аккаунт с этим email уже использует другой способ входа.',
    'invalid-credential' =>
      'Google отклонил данные входа. Проверьте Desktop OAuth Client ID.',
    'network-request-failed' =>
      'Нет подключения к интернету. Попробуйте ещё раз.',
    'operation-not-allowed' =>
      'Google вход не включён в настройках Firebase Authentication.',
    'too-many-requests' => 'Слишком много попыток входа. Попробуйте позже.',
    'user-disabled' => 'Этот аккаунт отключён.',
    _ => error.message ?? 'Не удалось войти через Google.',
  };
}
