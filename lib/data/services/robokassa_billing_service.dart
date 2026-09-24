import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/billing/robokassa_sdk_params.dart';

/// Result of the native Robokassa pay UI (Android WebView POST of backend `sdk`).
enum RobokassaPayStatus { success, cancelled, error }

class RobokassaPayResult {
  const RobokassaPayResult({
    required this.status,
    this.message,
    this.invoiceId,
  });

  final RobokassaPayStatus status;
  final String? message;
  final int? invoiceId;

  bool get isSuccess => status == RobokassaPayStatus.success;
  bool get isCancelled => status == RobokassaPayStatus.cancelled;
}

/// Launches Robokassa payment with pre-signed [RobokassaSdkParams].
///
/// Does not compute SignatureValue. Android posts `sdk` fields to Index.aspx.
class RobokassaBillingService {
  static const _channel = MethodChannel('com.nbekdev.otter/robokassa');

  Future<RobokassaPayResult> pay(RobokassaSdkParams sdk) async {
    if (!Platform.isAndroid) {
      return const RobokassaPayResult(
        status: RobokassaPayStatus.error,
        message: 'Robokassa SDK доступен только на Android.',
      );
    }
    if (!sdk.isValid) {
      return const RobokassaPayResult(
        status: RobokassaPayStatus.error,
        message: 'Некорректные параметры оплаты Robokassa.',
      );
    }
    try {
      final raw = await _channel.invokeMethod<dynamic>(
        'startPay',
        sdk.toChannelArgs(),
      );
      return _parseResult(raw, fallbackInvoiceId: sdk.invoiceId);
    } on PlatformException catch (e) {
      return RobokassaPayResult(
        status: RobokassaPayStatus.error,
        message: e.message ?? e.code,
        invoiceId: sdk.invoiceId,
      );
    } catch (e) {
      return RobokassaPayResult(
        status: RobokassaPayStatus.error,
        message: e.toString(),
        invoiceId: sdk.invoiceId,
      );
    }
  }

  RobokassaPayResult _parseResult(
    dynamic raw, {
    required int fallbackInvoiceId,
  }) {
    if (raw is! Map) {
      return RobokassaPayResult(
        status: RobokassaPayStatus.cancelled,
        invoiceId: fallbackInvoiceId,
      );
    }
    final map = Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry('$k', v)),
    );
    final statusRaw = '${map['status'] ?? ''}'.toLowerCase();
    final invoiceRaw = map['invoice_id'];
    final invoiceId = invoiceRaw is int
        ? invoiceRaw
        : int.tryParse('$invoiceRaw') ?? fallbackInvoiceId;
    final message = map['message'] as String?;
    final status = switch (statusRaw) {
      'success' => RobokassaPayStatus.success,
      'error' => RobokassaPayStatus.error,
      _ => RobokassaPayStatus.cancelled,
    };
    return RobokassaPayResult(
      status: status,
      message: message,
      invoiceId: invoiceId,
    );
  }
}

/// Debug helper: never used for payment — documents forbidden client URL build.
String debugDescribeSdk(RobokassaSdkParams sdk) =>
    jsonEncode(sdk.toChannelArgs()..remove('signature_value'));
