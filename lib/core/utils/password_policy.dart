const passwordMinLength = 8;
const passwordMaxLength = 20;

/// Returns an error message or `null` when valid.
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
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
    return 'Пароль должен содержать минимум один специальный символ (!, @, # и т.п.)';
  }
  return null;
}
