import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
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

final class WindowsGoogleOAuth {
  WindowsGoogleOAuth({required this.clientId});

  final String clientId;

  static const _authorizationEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const _tokenEndpoint = 'https://oauth2.googleapis.com/token';
  static const _callbackPath = '/oauth2/callback';
  static const _timeout = Duration(minutes: 5);

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

    final verifier = _randomUrlSafeString(64);
    final challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
    final state = _randomUrlSafeString(48);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
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

      final callback = await _waitForCallback(server);
      final query = callback.uri.queryParameters;
      final error = query['error'];

      if (error != null) {
        await _respond(
          callback,
          title: 'Вход отменён',
          message: 'Вернитесь в приложение Otter.',
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

      await _respond(
        callback,
        title: 'Вход выполнен',
        message: 'Можно закрыть эту вкладку и вернуться в Otter.',
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
      final request = await client.postUrl(Uri.parse(_tokenEndpoint));
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(
        Uri(
          queryParameters: {
            'client_id': clientId,
            'code': code,
            'code_verifier': verifier,
            'grant_type': 'authorization_code',
            'redirect_uri': redirectUri,
          },
        ).query,
      );

      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      final decoded = body.isEmpty
          ? const <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      if (response.statusCode != HttpStatus.ok) {
        final error = decoded['error'] as String? ?? 'token-exchange-failed';
        final description =
            decoded['error_description'] as String? ??
            'Google не смог обменять код авторизации.';
        throw WindowsGoogleOAuthException(error, description);
      }

      final accessToken = decoded['access_token'] as String?;
      final idToken = decoded['id_token'] as String?;
      if (accessToken == null || idToken == null) {
        throw const WindowsGoogleOAuthException(
          'missing-tokens',
          'Google не вернул необходимые токены.',
        );
      }
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
}
