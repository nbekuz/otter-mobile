import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import 'windows_google_oauth.dart';

Future<String?> signInWithGoogleDesktop({required String clientId}) async {
  _ensureWindows();

  try {
    final tokens = await WindowsGoogleOAuth(clientId: clientId).signIn();
    if (tokens == null) return null;

    final credential = GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    return result.user?.getIdToken();
  } on WindowsGoogleOAuthException catch (error) {
    throw StateError(error.message);
  } on FirebaseAuthException catch (error) {
    throw StateError(_firebaseErrorMessage(error));
  } on SocketException {
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
