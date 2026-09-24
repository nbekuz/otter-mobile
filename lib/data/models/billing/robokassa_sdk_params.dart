/// Pre-signed Robokassa fields from `POST mobile/premium/checkout/` (`sdk`).
///
/// Pass these into the native pay UI as-is. Never rebuild SignatureValue or
/// assemble a Merchant/Index.aspx query string on the client (error 29).
class RobokassaSdkParams {
  const RobokassaSdkParams({
    required this.merchantLogin,
    required this.invoiceId,
    required this.outSum,
    required this.description,
    required this.signatureValue,
    this.culture = 'ru',
    this.encoding = 'utf-8',
    this.isTest = false,
    this.isRecurring = false,
    this.email,
    this.receiptJson,
    this.receipt,
    this.paymentUrl,
  });

  final String merchantLogin;
  final int invoiceId;
  final String outSum;
  final String description;
  final String signatureValue;
  final String culture;
  final String encoding;
  final bool isTest;
  final bool isRecurring;
  final String? email;

  /// Fiscal receipt JSON string from backend (preferred for POST body).
  final String? receiptJson;

  /// Structured receipt when `receipt_json` is absent.
  final Map<String, dynamic>? receipt;

  /// Optional override; defaults to Robokassa Index.aspx in native code.
  final String? paymentUrl;

  factory RobokassaSdkParams.fromJson(Map<String, dynamic> json) {
    final invoiceRaw = json['invoice_id'];
    final invoiceId = invoiceRaw is int
        ? invoiceRaw
        : int.tryParse('$invoiceRaw') ?? 0;
    final receipt = json['receipt'];
    return RobokassaSdkParams(
      merchantLogin: (json['merchant_login'] as String? ?? '').trim(),
      invoiceId: invoiceId,
      outSum: '${json['out_sum'] ?? ''}'.trim(),
      description: (json['description'] as String? ?? '').trim(),
      signatureValue: (json['signature_value'] as String? ?? '').trim(),
      culture: (json['culture'] as String? ?? 'ru').trim().isEmpty
          ? 'ru'
          : (json['culture'] as String).trim(),
      encoding: (json['encoding'] as String? ?? 'utf-8').trim().isEmpty
          ? 'utf-8'
          : (json['encoding'] as String).trim(),
      isTest: json['is_test'] as bool? ?? false,
      isRecurring: json['is_recurring'] as bool? ?? false,
      email: (json['email'] as String?)?.trim(),
      receiptJson: (json['receipt_json'] as String?)?.trim(),
      receipt: receipt is Map<String, dynamic>
          ? Map<String, dynamic>.from(receipt)
          : null,
      paymentUrl: (json['payment_url'] as String?)?.trim(),
    );
  }

  bool get isValid =>
      merchantLogin.isNotEmpty &&
      invoiceId > 0 &&
      outSum.isNotEmpty &&
      signatureValue.isNotEmpty;

  /// Payload for the Android MethodChannel (snake_case mirrors backend `sdk`).
  Map<String, dynamic> toChannelArgs() => {
        'merchant_login': merchantLogin,
        'invoice_id': invoiceId,
        'out_sum': outSum,
        'description': description,
        'signature_value': signatureValue,
        'culture': culture,
        'encoding': encoding,
        'is_test': isTest,
        'is_recurring': isRecurring,
        if (email != null && email!.isNotEmpty) 'email': email,
        if (receiptJson != null && receiptJson!.isNotEmpty)
          'receipt_json': receiptJson,
        if (receipt != null) 'receipt': receipt,
        if (paymentUrl != null && paymentUrl!.isNotEmpty)
          'payment_url': paymentUrl,
      };
}
