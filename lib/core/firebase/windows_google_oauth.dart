import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

final class WindowsGoogleTokens {
  const WindowsGoogleTokens({required this.accessToken, required this.idToken});

  final String accessToken;
  final String idToken;
}

final class WindowsGoogleOAuthException implements Exception {
  const WindowsGoogleOAuthException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'WindowsGoogleOAuthException($code): $message';
}

/// Manual Google OAuth 2.0 Authorization Code + PKCE for Windows installed apps.
///
/// Uses a Desktop ("installed") OAuth client and loopback redirect, then returns
/// Google `access_token` + `id_token` for Firebase `signInWithCredential`.
///
/// See: https://developers.google.com/identity/protocols/oauth2/native-app
final class WindowsGoogleOAuth {
  WindowsGoogleOAuth({
    required this.clientId,
    this.clientSecret = '',
  });

  /// Desktop OAuth client ID from Google Cloud Console.
  final String clientId;

  /// Desktop clients created in Cloud Console include a client_secret.
  /// Google's native-app docs mark it Optional, but the token endpoint returns
  /// `client_secret is missing` when a Console-issued Desktop secret is omitted.
  /// Never hardcode this value in source — load from env / local config.
  final String clientSecret;

  static const _authorizationEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const _callbackPath = '/oauth2/callback';
  static const _timeout = Duration(minutes: 5);
  static const _logTag = '[otter:windows-google-oauth]';

  Future<WindowsGoogleTokens?> signIn() async {
    if (!Platform.isWindows) {
      throw const WindowsGoogleOAuthException(
        'unsupported-platform',
        'Google OAuth desktop flow is available only on Windows.',
      );
    }
    if (clientId.isEmpty) {
      throw const WindowsGoogleOAuthException(
        'missing-client-id',
        'Windows Desktop OAuth Client ID не настроен.',
      );
    }
    if (clientSecret.isEmpty) {
      throw const WindowsGoogleOAuthException(
        'missing-client-secret',
        'Windows Desktop OAuth Client Secret не настроен. '
        'Укажите FIREBASE_GOOGLE_DESKTOP_CLIENT_SECRET в .env '
        '(Google Cloud → Desktop OAuth client → Client secret).',
      );
    }

    // RFC 7636: 43–128 chars from unreserved set.
    final verifier = _randomUrlSafeString(64);
    final challenge = _codeChallengeS256(verifier);
    final state = _randomUrlSafeString(48);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    // Google native-app docs: http://127.0.0.1:port (any free port).
    final redirectUri = 'http://127.0.0.1:${server.port}$_callbackPath';

    final authorizationUri = Uri.parse(_authorizationEndpoint).replace(
      queryParameters: {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'state': state,
        'include_granted_scopes': 'true',
        'prompt': 'select_account',
      },
    );

    _log(
      'authorization request',
      {
        'endpoint': _authorizationEndpoint,
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'code_challenge_method': 'S256',
        'code_challenge': _redact(challenge),
        'code_verifier_length': verifier.length,
        'state': _redact(state),
        'client_secret_configured': clientSecret.isNotEmpty,
      },
    );

    try {
      final opened = await launchUrl(
        authorizationUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw const WindowsGoogleOAuthException(
          'browser-launch-failed',
          'Не удалось открыть системный браузер.',
        );
      }
      _log('browser launched', {'uri_host': authorizationUri.host});

      final callback = await _waitForCallback(server);
      final query = callback.uri.queryParameters;
      final error = query['error'];

      _log(
        'redirect received',
        {
          'path': callback.uri.path,
          'has_code': query.containsKey('code'),
          'has_state': query.containsKey('state'),
          'error': error,
        },
      );

      if (error != null) {
        await _respond(
          callback,
          title: 'Вход отменён',
          message: 'Вернитесь в приложение Оттер.',
        );
        if (error == 'access_denied') return null;
        throw WindowsGoogleOAuthException(
          error,
          query['error_description'] ?? 'Google OAuth завершился с ошибкой.',
        );
      }

      final returnedState = query['state'];
      final code = query['code'];
      if (returnedState != state) {
        await _respond(
          callback,
          title: 'Ошибка входа',
          message: 'Проверка безопасности не пройдена.',
        );
        throw const WindowsGoogleOAuthException(
          'invalid-state',
          'Некорректный OAuth state. Повторите вход.',
        );
      }
      if (code == null || code.isEmpty) {
        await _respond(
          callback,
          title: 'Ошибка входа',
          message: 'Google не вернул код авторизации.',
        );
        throw const WindowsGoogleOAuthException(
          'missing-code',
          'Google не вернул код авторизации.',
        );
      }

      _log(
        'authorization code',
        {
          'code': _redact(code),
          'code_length': code.length,
          'state_ok': true,
        },
      );

      await _respond(
        callback,
        title: 'Вход выполнен',
        message: 'Можно закрыть эту вкладку и вернуться в Оттер.',
      );
      return await _exchangeCode(
        code: code,
        verifier: verifier,
        redirectUri: redirectUri,
      );
    } on TimeoutException {
      throw const WindowsGoogleOAuthException(
        'callback-timeout',
        'Время ожидания Google входа истекло.',
      );
    } on SocketException {
      throw const WindowsGoogleOAuthException(
        'network-error',
        'Нет подключения к интернету. Попробуйте ещё раз.',
      );
    } finally {
      await server.close(force: true);
    }
  }

  Future<HttpRequest> _waitForCallback(HttpServer server) {
    return server
        .firstWhere((request) => request.uri.path == _callbackPath)
        .timeout(_timeout);
  }

  Future<WindowsGoogleTokens> _exchangeCode({
    required String code,
    required String verifier,
    required String redirectUri,
  }) async {
    final client = HttpClient();
    try {
      // Google native-app token request fields:
      // client_id, code, code_verifier, grant_type, redirect_uri,
      // and client_secret when the Desktop client was issued with one.
      final bodyFields = <String, String>{
        'client_id': clientId,
        'client_secret': clientSecret,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      };

      _log(
        'token exchange request',
        {
          'endpoint': _tokenEndpoint,
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'code': _redact(code),
          'code_verifier_length': verifier.length,
          'client_secret_sent': true,
          // Never log the secret or full verifier.
        },
      );

      final request = await client.postUrl(Uri.parse(_tokenEndpoint));
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(Uri(queryParameters: bodyFields).query);

      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      final decoded = body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      final error = decoded['error'] as String?;
      _log(
        'token exchange response',
        {
          'status_code': response.statusCode,
          'error': error,
          'error_description': decoded['error_description'],
          'has_access_token': decoded['access_token'] is String,
          'has_id_token': decoded['id_token'] is String,
          'has_refresh_token': decoded['refresh_token'] is String,
          'token_type': decoded['token_type'],
          'expires_in': decoded['expires_in'],
          'scope': decoded['scope'],
        },
      );

      if (response.statusCode != HttpStatus.ok) {
        final description =
            decoded['error_description'] as String? ??
            'Google не смог обменять код авторизации.';
        throw WindowsGoogleOAuthException(
          error ?? 'token-exchange-failed',
          description,
        );
      }

      final accessToken = decoded['access_token'] as String?;
      final idToken = decoded['id_token'] as String?;
      if (accessToken == null || idToken == null) {
        throw const WindowsGoogleOAuthException(
          'missing-tokens',
          'Google не вернул необходимые токены.',
        );
      }

      _log(
        'google tokens received',
        {
          'access_token': _redact(accessToken),
          'id_token': _redact(idToken),
        },
      );

      return WindowsGoogleTokens(accessToken: accessToken, idToken: idToken);
    } on FormatException {
      throw const WindowsGoogleOAuthException(
        'invalid-token-response',
        'Google вернул некорректный ответ.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _respond(
    HttpRequest request, {
    required String title,
    required String message,
  }) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write('''
<!doctype html>
<html lang="ru">
  <head><meta charset="utf-8"><title>$title</title></head>
  <body style="font-family:system-ui,sans-serif;padding:32px">
    <h2>$title</h2><p>$message</p>
  </body>
</html>
''');
    await request.response.close();
  }

  /// BASE64URL-ENCODE(SHA256(ASCII(code_verifier))) without padding (RFC 7636).
  static String _codeChallengeS256(String verifier) {
    return base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
  }

  String _randomUrlSafeString(int length) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
      growable: false,
    ).join();
  }

  static String _redact(String value) {
    if (value.isEmpty) return '(empty)';
    if (value.length <= 8) return '***(${value.length})';
    return '${value.substring(0, 4)}…${value.substring(value.length - 4)}'
        '(${value.length})';
  }

  static void _log(String event, Map<String, Object?> data) {
    debugPrint('$_logTag $event $data');
  }
}
