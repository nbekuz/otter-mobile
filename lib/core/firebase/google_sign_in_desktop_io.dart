import 'package:flutter/foundation.dart';
import 'package:google_sign_in_dartio/google_sign_in_dartio.dart';

/// Registers the Dart Google Sign-In implementation used on Windows desktop.
///
/// Must run before the first [GoogleSignIn.signIn] call on Windows.
Future<void> configureGoogleSignInDesktop({required String clientId}) async {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    await GoogleSignInDart.register(clientId: clientId);
  }
}
