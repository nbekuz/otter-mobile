import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

typedef OnUnauthorized = Future<void> Function();

class ApiClient {
  ApiClient(this._tokenStorage, this._onUnauthorized) {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        headers: {'Content-Type': 'application/json'},
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    _dio.interceptors.add(_AuthInterceptor(this));
  }

  final TokenStorage _tokenStorage;
  final OnUnauthorized? _onUnauthorized;
  late final Dio _dio;

  Future<String?>? _refreshFuture;

  Dio get dio => _dio;

  Future<String?> refreshAccessToken() async {
    if (_refreshFuture != null) return _refreshFuture;
    _refreshFuture = _doRefresh();
    try {
      return await _refreshFuture;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<String?> _doRefresh() async {
    final refresh = await _tokenStorage.getRefreshToken();
    if (refresh == null || refresh.isEmpty) return null;

    final client = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        headers: {'Content-Type': 'application/json'},
      ),
    );
    try {
      final response = await client.post<Map<String, dynamic>>(
        'auth/token/refresh/',
        data: {'refresh': refresh},
      );
      final data = response.data;
      if (data == null) return null;
      final access = data['access'] as String?;
      if (access == null) return null;
      await _tokenStorage.setTokens(
        access: access,
        refresh: (data['refresh'] as String?) ?? refresh,
      );
      return access;
    } catch (_) {
      return null;
    }
  }

  Future<void> handleUnauthorized() async {
    await _tokenStorage.clear();
    await _onUnauthorized?.call();
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await _request(
      () => _dio.get<T>(path, queryParameters: queryParameters),
    );
    return response.data as T;
  }

  Future<T> post<T>(String path, {Object? data}) async {
    final response = await _request(() => _dio.post<T>(path, data: data));
    return response.data as T;
  }

  Future<T> put<T>(String path, {Object? data}) async {
    final response = await _request(() => _dio.put<T>(path, data: data));
    return response.data as T;
  }

  Future<T> patch<T>(String path, {Object? data}) async {
    final response = await _request(() => _dio.patch<T>(path, data: data));
    return response.data as T;
  }

  Future<T> delete<T>(String path) async {
    final response = await _request(() => _dio.delete<T>(path));
    return response.data as T;
  }

  Future<Response<T>> _request<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ApiException _mapError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      if (data['detail'] is String) {
        return ApiException(data['detail'] as String, statusCode: status);
      }
      final fieldErrors = <String, String>{};
      for (final entry in data.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty && v.first is String) {
          fieldErrors[entry.key] = v.first as String;
        } else if (v is String) {
          fieldErrors[entry.key] = v;
        }
      }
      if (fieldErrors.isNotEmpty) {
        return ApiException(
          fieldErrors.values.first,
          statusCode: status,
          fieldErrors: fieldErrors,
        );
      }
    }
    return ApiException(e.message ?? 'Ошибка запроса', statusCode: status);
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._client);

  final ApiClient _client;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.baseUrl = Env.apiBaseUrl;
    final token = await _client._tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    if (options.data is FormData) {
      options.headers.remove('Content-Type');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;
    final isAuthPath =
        path.contains('auth/token/refresh/') ||
        path.contains('auth/login/') ||
        path.contains('auth/register/') ||
        path.contains('auth/forgot-password');

    if (status == 401 && !isAuthPath) {
      final extra = err.requestOptions.extra;
      if (extra['_retry'] == true) {
        await _client.handleUnauthorized();
        return handler.next(err);
      }

      final access = await _client.refreshAccessToken();
      if (access != null) {
        final opts = err.requestOptions;
        opts.extra['_retry'] = true;
        opts.headers['Authorization'] = 'Bearer $access';
        try {
          final response = await _client.dio.fetch(opts);
          return handler.resolve(response);
        } catch (e) {
          if (e is DioException) return handler.next(e);
        }
      }
      await _client.handleUnauthorized();
    }
    handler.next(err);
  }
}
