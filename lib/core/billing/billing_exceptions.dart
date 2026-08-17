/// Typed billing errors with Russian user-facing messages.
sealed class BillingException implements Exception {
  const BillingException(this.message);
  final String message;

  @override
  String toString() => message;
}

class BillingUnavailableException extends BillingException {
  const BillingUnavailableException([
    super.message =
        'Платежи недоступны. Установите RuStore и войдите в аккаунт.',
  ]);
}

class BillingNetworkException extends BillingException {
  const BillingNetworkException([
    super.message = 'Нет связи с магазином. Проверьте интернет и попробуйте снова.',
  ]);
}

class PurchaseCancelledException extends BillingException {
  const PurchaseCancelledException([
    super.message = 'Покупка отменена.',
  ]);
}

class ProductNotFoundException extends BillingException {
  const ProductNotFoundException([
    super.message = 'Подписка не найдена в магазине.',
  ]);
}

class VerificationFailedException extends BillingException {
  const VerificationFailedException([
    super.message =
        'Не удалось подтвердить покупку на сервере. Попробуйте позже или нажмите «Восстановить покупки».',
  ]);
}

class ExpiredSubscriptionException extends BillingException {
  const ExpiredSubscriptionException([
    super.message = 'Подписка истекла. Оформите новую, чтобы продолжить.',
  ]);
}

class BillingUnknownException extends BillingException {
  const BillingUnknownException([
    super.message = 'Неизвестная ошибка оплаты. Попробуйте ещё раз.',
  ]);
}

/// Maps any thrown object to a friendly Russian message.
String billingErrorMessage(Object error) {
  if (error is BillingException) return error.message;
  final raw = error.toString().toLowerCase();
  if (raw.contains('cancel') || raw.contains('closed_by_user')) {
    return const PurchaseCancelledException().message;
  }
  if (raw.contains('network') ||
      raw.contains('socket') ||
      raw.contains('timeout') ||
      raw.contains('connection')) {
    return const BillingNetworkException().message;
  }
  if (raw.contains('not found') || raw.contains('product')) {
    return const ProductNotFoundException().message;
  }
  if (raw.contains('expir')) {
    return const ExpiredSubscriptionException().message;
  }
  if (raw.contains('verif') || raw.contains('403') || raw.contains('400')) {
    return const VerificationFailedException().message;
  }
  if (raw.contains('unavailable') || raw.contains('недоступ')) {
    return const BillingUnavailableException().message;
  }
  return const BillingUnknownException().message;
}

/// User-facing message for RuStore [InvalidPurchase] / SDK payment failure.
String rustorePaymentFailureMessage({
  int? errorCode,
  String? productId,
  bool? sandbox,
}) {
  final details = <String>[];
  if (errorCode != null) details.add('код $errorCode');
  if (productId != null && productId.isNotEmpty) {
    details.add('продукт $productId');
  }
  if (sandbox == true) details.add('тестовая покупка');

  if (details.isEmpty) {
    return 'Покупка не прошла. Проверьте вход в RuStore и повторите.';
  }
  return 'Покупка не прошла (${details.join(', ')}). '
      'Убедитесь, что вы вошли в RuStore и приложение опубликовано с тем же ключом подписи.';
}
