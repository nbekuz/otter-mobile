import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accessKey = 'otter.access';
const _refreshKey = 'otter.refresh';
const _profileFirstNameKey = 'otter.auth.first-name';
const _profileLastNameKey = 'otter.auth.last-name';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? secure})
      : _secure = secure ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _secure;

  Future<String?> getAccessToken() => _secure.read(key: _accessKey);
  Future<String?> getRefreshToken() => _secure.read(key: _refreshKey);

  Future<void> setTokens({required String access, required String refresh}) async {
    await _secure.write(key: _accessKey, value: access);
    await _secure.write(key: _refreshKey, value: refresh);
  }

  Future<void> clear() async {
    await _secure.delete(key: _accessKey);
    await _secure.delete(key: _refreshKey);
  }

  Future<void> saveProfileNames(String first, String last) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileFirstNameKey, first);
    await prefs.setString(_profileLastNameKey, last);
  }

  Future<({String first, String last})> getProfileNames() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      first: prefs.getString(_profileFirstNameKey) ?? '',
      last: prefs.getString(_profileLastNameKey) ?? '',
    );
  }

  Future<void> clearProfileNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileFirstNameKey);
    await prefs.remove(_profileLastNameKey);
  }
}
