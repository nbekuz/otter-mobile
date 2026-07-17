Future<String?> signInWithGoogleDesktop({required String clientId}) {
  throw UnsupportedError('Desktop Google Sign-In is Windows-only.');
}

Future<void> signOutGoogleDesktop() async {}

Future<String?> refreshGoogleFirebaseTokenDesktop({
  bool forceRefresh = true,
}) async => null;
