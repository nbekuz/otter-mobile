import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/legal_acceptance_text.dart';
import '../../shared/widgets/keyboard_dismisser.dart';
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
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _loading = true);
    try {
      await ref.read(authStateProvider.notifier).register(
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
      if (mounted) showAppToast(context, getApiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      child: DismissKeyboardScrollView(
        padding: EdgeInsets.zero,
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
                  'Регистрация',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            InputField(
              controller: _firstName,
              label: 'Имя',
              hint: 'Иван',
              icon: LucideIcons.user,
            ),
            const SizedBox(height: 16),
            InputField(
              controller: _lastName,
              label: 'Фамилия',
              hint: 'Иванов',
              icon: LucideIcons.user,
            ),
            const SizedBox(height: 16),
            InputField(
              controller: _email,
              label: 'Email',
              hint: 'example@mail.ru',
              icon: LucideIcons.mail,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            InputField(
              controller: _password,
              label: 'Пароль',
              hint: 'Минимум 8 символов',
              icon: LucideIcons.lock,
              obscure: true,
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
