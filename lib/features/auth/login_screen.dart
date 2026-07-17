import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/layout/responsive.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/input_field.dart';
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
  bool _showPassword = false;
  bool _remember = false;
  bool _loading = false;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
    if (_email.text.trim().isEmpty) {
      setState(() => _emailError = 'Введите email');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _passwordError = 'Введите пароль');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref
          .read(authStateProvider.notifier)
          .login(_email.text.trim(), _password.text);
      await ref.read(appSettingsProvider.notifier).load();
      if (mounted) context.go('/app');
    } catch (e) {
      if (mounted) {
        showAppToast(context, getApiErrorMessage(e, 'Ошибка входа'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _loading = true);
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
      if (mounted) {
        final message = e is StateError
            ? e.message
            : getApiErrorMessage(e, 'Ошибка Google входа');
        showAppToast(context, message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForgotPassword() async {
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
    return ResponsivePage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(LucideIcons.chevronLeft),
                style: IconButton.styleFrom(
                  backgroundColor: OtterColors.grayLight,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Войти',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Введите данные вашей учётной записи для входа в Otter',
            style: TextStyle(color: OtterColors.sberGray, height: 1.5),
          ),
          const SizedBox(height: 24),
          InputField(
            controller: _email,
            label: 'Email',
            hint: 'example@mail.ru',
            icon: LucideIcons.mail,
            keyboardType: TextInputType.emailAddress,
            error: _emailError,
          ),
          const SizedBox(height: 16),
          InputField(
            controller: _password,
            label: 'Пароль',
            hint: 'Введите пароль',
            icon: LucideIcons.lock,
            obscure: true,
            obscureVisible: _showPassword,
            onToggleObscure: () =>
                setState(() => _showPassword = !_showPassword),
            error: _passwordError,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OtterCheckbox(
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v ?? false),
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
          PrimaryButton(label: 'Войти', loading: _loading, onPressed: _login),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loading ? null : _googleLogin,
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
            onPressed: () => context.push('/register'),
            child: const Text(
              'Нет аккаунта? Зарегистрироваться',
              style: TextStyle(color: OtterColors.sberGreen),
            ),
          ),
          const SizedBox(height: 16),
          const LegalAcceptanceText(),
        ],
      ),
    );
  }
}
