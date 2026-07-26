/// Simple email format check for auth forms.
String? validateEmail(String email) {
  final value = email.trim();
  if (value.isEmpty) {
    return 'Введите email';
  }
  final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  if (!ok) {
    return 'Введите корректный email';
  }
  return null;
}
