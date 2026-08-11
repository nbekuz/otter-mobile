class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors,
    this.code,
  });

  final String message;
  final int? statusCode;
  final Map<String, String>? fieldErrors;

  /// Machine-readable error/success code from the API (e.g. ACTIVE_SUBSCRIPTION_EXISTS).
  final String? code;

  @override
  String toString() => message;
}

String getApiErrorMessage(Object? error, [String fallback = 'Ошибка запроса']) {
  if (error is ApiException) return error.message;
  if (error is Exception) return error.toString();
  return fallback;
}

String? getApiFieldError(Object? error, String field) {
  if (error is ApiException) return error.fieldErrors?[field];
  return null;
}
