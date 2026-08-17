import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// «Запомнить» on login — same keys as web `auth-session.ts`.
class RememberLoginStorage {
  RememberLoginStorage({FlutterSecureStorage? secure})
    : _secure =
          secure ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _flagKey = 'otter.auth.remember-login';
  static const _emailKey = 'otter.auth.saved-login-email';
  static const _passwordKey = 'otter.auth.saved-login-password';

  final FlutterSecureStorage _secure;

  Future<({String email, String password})?> read() async {
    final flag = await _secure.read(key: _flagKey);
    if (flag != '1') return null;
    final email = await _secure.read(key: _emailKey) ?? '';
    final password = await _secure.read(key: _passwordKey) ?? '';
    if (email.isEmpty) return null;
    return (email: email, password: password);
  }

  Future<void> write(String email, String password) async {
    await _secure.write(key: _flagKey, value: '1');
    await _secure.write(key: _emailKey, value: email);
    await _secure.write(key: _passwordKey, value: password);
  }

  Future<void> clear() async {
    await _secure.delete(key: _flagKey);
    await _secure.delete(key: _emailKey);
    await _secure.delete(key: _passwordKey);
  }
}
