import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/layout/responsive.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/utils/email_policy.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/keyboard_dismisser.dart';
import '../../shared/widgets/legal_acceptance_text.dart';
import '../../shared/widgets/otter_checkbox.dart';
import '../../shared/widgets/primary_button.dart';
import 'forgot_password_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _showPassword = false;
  bool _remember = false;
  bool _loading = false;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadRememberedLogin());
    });
  }

  Future<void> _loadRememberedLogin() async {
    final saved = await ref.read(rememberLoginStorageProvider).read();
    if (!mounted || saved == null) return;
    setState(() {
      _email.text = saved.email;
      _password.text = saved.password;
      _remember = true;
    });
  }

  Future<void> _persistRememberedLogin() async {
    final storage = ref.read(rememberLoginStorageProvider);
    if (_remember) {
      await storage.write(_email.text.trim(), _password.text);
    } else {
      await storage.clear();
    }
  }

  Future<void> _onRememberChanged(bool? value) async {
    setState(() => _remember = value ?? false);
    await _persistRememberedLogin();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_loading) return;
    KeyboardDismisser.dismiss();
    context.go('/');
  }

  String _loginErrorMessage(Object e) {
    final status = e is ApiException ? e.statusCode : null;
    final fieldEmail = getApiFieldError(e, 'email');
    final fieldPassword = getApiFieldError(e, 'password');
    final detail = getApiErrorMessage(e, '');

    if (fieldEmail != null) return fieldEmail;
    if (fieldPassword != null) return fieldPassword;

    final lower = detail.toLowerCase();
    if (status == 404 ||
        lower.contains('not found') ||
        lower.contains('не найден') ||
        lower.contains('no active account') ||
        lower.contains('user with this') ||
        lower.contains('does not exist')) {
      return 'Такой учётной записи нет, зарегистрируйтесь';
    }
    if (status == 400 || status == 401 || status == 403) {
      return detail.isNotEmpty ? detail : 'Неверный email или пароль';
    }
    if (detail.isNotEmpty) return detail;
    return 'Неверный email или пароль';
  }

  bool _validate() {
    final emailError = validateEmail(_email.text);
    String? passwordError;
    if (_password.text.isEmpty) {
      passwordError = 'Введите пароль';
    }
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    return emailError == null && passwordError == null;
  }

  Future<void> _login() async {
    if (_loading) return;
    if (!_validate()) return;

    // Loading BEFORE keyboard dismiss: disables Back / PopScope so an Android
    // IME layout-shift cannot re-target the same tap onto the chevron.
    setState(() => _loading = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      KeyboardDismisser.dismiss();
    });

    try {
      await _persistRememberedLogin();
      await ref
          .read(authStateProvider.notifier)
          .login(_email.text.trim(), _password.text);
      await ref.read(appSettingsProvider.notifier).load();
      if (mounted) context.go('/app');
    } catch (e) {
      if (!mounted) return;
      final message = _loginErrorMessage(e);
      final emailField = getApiFieldError(e, 'email');
      final passwordField = getApiFieldError(e, 'password');
      setState(() {
        if (emailField != null && passwordField == null) {
          _emailError = emailField;
          _passwordError = null;
        } else if (passwordField != null && emailField == null) {
          _emailError = null;
          _passwordError = passwordField;
        } else if (message.contains('учётной записи')) {
          _emailError = message;
          _passwordError = null;
        } else {
          _emailError = message;
          _passwordError = message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    if (_loading) return;
    setState(() => _loading = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      KeyboardDismisser.dismiss();
    });
    try {
      final token = await FirebaseBootstrap.signInWithGoogle();
      if (token == null) {
        if (mounted) showAppToast(context, 'Вход отменён');
        return;
      }
      await ref.read(authStateProvider.notifier).loginWithGoogle(token);
      await ref.read(appSettingsProvider.notifier).load();
      if (mounted) context.go('/app');
    } catch (e) {
      if (!mounted) return;
      final message = e is StateError
          ? e.message
          : getApiErrorMessage(e, 'Ошибка Google входа');
      // Config / OAuth errors are global — not Email/Password field validation.
      setState(() {
        _emailError = null;
        _passwordError = null;
      });
      showAppToast(context, message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForgotPassword() async {
    KeyboardDismisser.dismiss();
    final message = await showForgotPasswordDialog(
      context,
      ref,
      initialEmail: _email.text.trim(),
    );
    if (message != null && mounted) {
      showAppToast(context, message, type: AppToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    return PopScope(
      canPop: !_loading,
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _loading ? null : _goBack,
                  icon: const Icon(LucideIcons.chevronLeft),
                  style: IconButton.styleFrom(
                    backgroundColor: OtterColors.elevated(isDark),
                    foregroundColor: OtterColors.text(isDark),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Войти',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: OtterColors.text(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Введите данные вашей учётной записи для входа в Оттер',
              style: TextStyle(color: OtterColors.muted(isDark), height: 1.5),
            ),
            const SizedBox(height: 24),
            InputField(
              controller: _email,
              label: 'Email',
              hint: 'example@mail.ru',
              icon: LucideIcons.mail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              error: _emailError,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 16),
            InputField(
              controller: _password,
              focusNode: _passwordFocus,
              label: 'Пароль',
              hint: 'Введите пароль',
              icon: LucideIcons.lock,
              obscure: true,
              obscureVisible: _showPassword,
              textInputAction: TextInputAction.done,
              onToggleObscure: () =>
                  setState(() => _showPassword = !_showPassword),
              error: _passwordError,
              onSubmitted: (_) {
                if (!_loading) _login();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OtterCheckbox(
                    value: _remember,
                    onChanged: _loading ? (_) {} : _onRememberChanged,
                    child: const Text('Запомнить'),
                  ),
                ),
                TextButton(
                  onPressed: _loading ? null : _openForgotPassword,
                  child: const Text(
                    'Забыли пароль?',
                    style: TextStyle(
                      color: OtterColors.sberGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Войти',
              loading: _loading,
              dismissOnPress: false,
              onPressed: _login,
            ),
            if (FirebaseBootstrap.windowsConfigError != null) ...[
              const SizedBox(height: 16),
              _WindowsGoogleConfigBanner(
                message: FirebaseBootstrap.windowsConfigError!,
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loading ||
                      FirebaseBootstrap.windowsConfigError != null
                  ? null
                  : _googleLogin,
              icon: const Icon(LucideIcons.globe),
              label: const Text('Войти через Google'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loading ? null : () => context.push('/register'),
              child: const Text(
                'Нет аккаунта? Зарегистрироваться',
                style: TextStyle(color: OtterColors.sberGreen),
              ),
            ),
            const SizedBox(height: 16),
            const LegalAcceptanceText(),
          ],
        ),
      ),
    );
  }
}

class _WindowsGoogleConfigBanner extends StatelessWidget {
  const _WindowsGoogleConfigBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OtterColors.dangerSoft(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: OtterColors.priorityHigh.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.circleAlert,
            size: 18,
            color: isDark ? const Color(0xFFFF6B6B) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: OtterColors.text(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
