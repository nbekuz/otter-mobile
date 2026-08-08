import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

/// Support inbox used by «Написать нам».
const kSupportEmail = 'nab1985nab@gmail.com';

/// Deliver a contact message to [kSupportEmail] via FormSubmit.
/// Falls back to the system mail client if HTTP delivery fails.
Future<void> deliverSupportEmail({
  required String message,
  String? fromEmail,
  String? fromName,
}) async {
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('Введите сообщение');
  }

  final body = <String, dynamic>{
    'message': trimmed,
    '_subject': 'Обращение из Оттер',
    '_template': 'table',
    '_captcha': 'false',
  };
  if (fromEmail != null && fromEmail.isNotEmpty) {
    body['email'] = fromEmail;
  }
  if (fromName != null && fromName.isNotEmpty) {
    body['name'] = fromName;
  }

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  try {
    final response = await dio.post<dynamic>(
      'https://formsubmit.co/ajax/$kSupportEmail',
      data: body,
    );
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) return;
  } catch (_) {
    // Fall through to mailto.
  }

  final uri = Uri(
    scheme: 'mailto',
    path: kSupportEmail,
    queryParameters: {
      'subject': 'Обращение из Оттер',
      'body': trimmed,
    },
  );
  final launched = await launchUrl(uri);
  if (!launched) {
    throw DioException(
      requestOptions: RequestOptions(path: uri.toString()),
      message: 'Не удалось отправить сообщение на $kSupportEmail',
    );
  }
}
