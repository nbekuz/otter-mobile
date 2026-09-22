const passwordMinLength = 8;
const passwordMaxLength = 20;

/// Returns an error message or `null` when valid.
/// Rules: 8–20 chars, ≥1 lowercase, ≥1 uppercase Latin letter, ≥1 digit.
String? validateNewPassword(String password) {
  if (password.length < passwordMinLength) {
    return 'Пароль должен содержать не менее $passwordMinLength символов';
  }
  if (password.length > passwordMaxLength) {
    return 'Пароль должен содержать не более $passwordMaxLength символов';
  }
  if (!RegExp(r'[a-z]').hasMatch(password)) {
    return 'Пароль должен содержать минимум одну строчную латинскую букву';
  }
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Пароль должен содержать минимум одну заглавную латинскую букву';
  }
  if (!RegExp(r'\d').hasMatch(password)) {
    return 'Пароль должен содержать минимум одну цифру';
  }
  return null;
}
