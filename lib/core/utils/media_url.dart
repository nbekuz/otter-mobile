import '../config/env.dart';

/// Resolves API media URLs for native audio players (Android blocks cleartext HTTP).
String resolveMediaUrl(String? raw) {
  if (raw == null || raw.isEmpty) return '';

  var url = raw.trim();

  if (url.startsWith('http://')) {
    url = 'https://${url.substring('http://'.length)}';
  } else if (!url.startsWith('https://')) {
    final origin = Uri.parse(Env.apiBaseUrl).origin;
    url = url.startsWith('/') ? '$origin$url' : '$origin/$url';
  }

  return url;
}
