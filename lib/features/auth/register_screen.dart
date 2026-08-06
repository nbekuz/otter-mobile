import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/utils/email_policy.dart';
import '../../core/utils/password_policy.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/keyboard_dismisser.dart';
import '../../shared/widgets/legal_acceptance_text.dart';
import '../../shared/widgets/primary_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  bool _showPassword = false;
  String? _emailError;
  String? _passwordError;
  String? _firstNameError;
  String? _lastNameError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_loading) return;
    KeyboardDismisser.dismiss();
    context.go('/');
  }

  bool _validate() {
    final emailError = validateEmail(_email.text);
    final passwordError = validateNewPassword(_password.text);
    String? firstNameError;
    String? lastNameError;
    if (_firstName.text.trim().isEmpty) {
      firstNameError = 'Введите имя';
    }
    if (_lastName.text.trim().isEmpty) {
      lastNameError = 'Введите фамилию';
    }

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _firstNameError = firstNameError;
      _lastNameError = lastNameError;
    });

    return emailError == null &&
        passwordError == null &&
        firstNameError == null &&
        lastNameError == null;
  }

  Future<void> _register() async {
    if (_loading) return;
    if (!_validate()) return;

    setState(() => _loading = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      KeyboardDismisser.dismiss();
    });
    try {
      await ref
          .read(authStateProvider.notifier)
          .register(
            email: _email.text.trim(),
            password: _password.text,
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
          );
      await ref.read(appSettingsProvider.notifier).load();
      if (!mounted) return;
      final auth = ref.read(authStateProvider);
      if (auth.requiresProfileFill) {
        context.go('/profile-fill');
      } else {
        context.go('/app');
      }
    } catch (e) {
      if (!mounted) return;
      // Stay on this screen — only show field errors (never pop/navigate).
      final emailField =
          getApiFieldError(e, 'email') ?? getApiFieldError(e, 'username');
      final passwordField = getApiFieldError(e, 'password');
      final firstNameField = getApiFieldError(e, 'first_name');
      final lastNameField = getApiFieldError(e, 'last_name');
      final general = getApiErrorMessage(e, 'Некорректные данные');

      setState(() {
        _firstNameError = firstNameField;
        _lastNameError = lastNameField;
        _emailError = emailField;
        _passwordError = passwordField;

        if (_emailError == null &&
            _passwordError == null &&
            _firstNameError == null &&
            _lastNameError == null) {
          _emailError = general;
          _passwordError = general;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
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
                  'Регистрация',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: OtterColors.text(isDark),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          InputField(
            controller: _firstName,
            focusNode: _firstNameFocus,
            label: 'Имя',
            hint: 'Иван',
            icon: LucideIcons.user,
            textInputAction: TextInputAction.next,
            error: _firstNameError,
            onSubmitted: (_) => _lastNameFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          InputField(
            controller: _lastName,
            focusNode: _lastNameFocus,
            label: 'Фамилия',
            hint: 'Иванов',
            icon: LucideIcons.user,
            textInputAction: TextInputAction.next,
            error: _lastNameError,
            onSubmitted: (_) => _emailFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          InputField(
            controller: _email,
            focusNode: _emailFocus,
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
            hint: 'A-z, 0-9, спец, 8–20 символов',
            icon: LucideIcons.lock,
            obscure: true,
            obscureVisible: _showPassword,
            onToggleObscure: () =>
                setState(() => _showPassword = !_showPassword),
            textInputAction: TextInputAction.done,
            error: _passwordError,
            onSubmitted: (_) {
              if (!_loading) _register();
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Пароль: 8–20 символов, латиница (A–z), цифра и спецсимвол (!@#…).',
            style: TextStyle(
              fontSize: 12,
              color: OtterColors.sberGray,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Создать аккаунт',
            loading: _loading,
            onPressed: _register,
          ),
          const SizedBox(height: 16),
          const LegalAcceptanceText(),
        ],
      ),
      ),
    );
  }
}
