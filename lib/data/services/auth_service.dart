import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../models/api/api_models.dart';

class AuthTokens {
  AuthTokens({required this.access, required this.refresh});
  final String access;
  final String refresh;
}

class AuthService {
  AuthService(this._client);
  final ApiClient _client;

  Future<AuthTokens> login(String email, String password) async {
    final data = await _client.post<Map<String, dynamic>>(
      'auth/login/',
      data: {'email': email, 'password': password},
    );
    final tokens = data['tokens'] as Map<String, dynamic>;
    return AuthTokens(
      access: tokens['access'] as String,
      refresh: tokens['refresh'] as String,
    );
  }

  Future<({AuthTokens tokens, BackendUser user})> register({
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      'auth/register/',
      data: {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
      },
    );
    final tokens = data['tokens'] as Map<String, dynamic>;
    final user = BackendUser.fromJson(data['user'] as Map<String, dynamic>);
    return (
      tokens: AuthTokens(
        access: tokens['access'] as String,
        refresh: tokens['refresh'] as String,
      ),
      user: user,
    );
  }

  Future<({AuthTokens tokens, BackendUser user})> loginWithGoogle(
    String firebaseToken,
  ) async {
    final data = await _client.post<Map<String, dynamic>>(
      'auth/google/',
      data: {'firebase_token': firebaseToken},
    );
    final tokens = data['tokens'] as Map<String, dynamic>;
    final user = BackendUser.fromJson(data['user'] as Map<String, dynamic>);
    return (
      tokens: AuthTokens(
        access: tokens['access'] as String,
        refresh: tokens['refresh'] as String,
      ),
      user: user,
    );
  }

  Future<BackendUser> fetchProfile() async {
    final data = await _client.get<Map<String, dynamic>>('profile/');
    return BackendUser.fromJson(data);
  }

  Future<BackendUser> updateProfile({
    required String firstName,
    required String lastName,
    String? avatarPath,
  }) async {
    final formData = FormData.fromMap({
      'first_name': firstName,
      'last_name': lastName,
      if (avatarPath != null)
        'avatar': await MultipartFile.fromFile(avatarPath),
    });
    final data = await _client.put<Map<String, dynamic>>(
      'profile/',
      data: formData,
    );
    return BackendUser.fromJson(data);
  }

  Future<void> forgotPassword(String email) async {
    await _client.post('auth/forgot-password/', data: {'email': email});
  }

  Future<String> forgotPasswordVerify(String email, String code) async {
    final data = await _client.post<Map<String, dynamic>>(
      'auth/forgot-password/verify/',
      data: {'email': email, 'code': code},
    );
    return data['reset_token'] as String;
  }

  Future<String> forgotPasswordConfirm(
    String resetToken,
    String newPassword,
  ) async {
    final data = await _client.post<Map<String, dynamic>>(
      'auth/forgot-password/confirm/',
      data: {'reset_token': resetToken, 'new_password': newPassword},
    );
    return data['detail'] as String? ?? 'Пароль обновлён';
  }

  Future<void> changePassword(String newPassword) async {
    await _client.post(
      'profile/change-password/',
      data: {'new_password': newPassword},
    );
  }
}
