import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      debugPrint('[openExternalUrl] could not launch: $url');
    }
    return launched;
  } catch (e, st) {
    debugPrint('[openExternalUrl] failed for $url: $e\n$st');
    return false;
  }
}
