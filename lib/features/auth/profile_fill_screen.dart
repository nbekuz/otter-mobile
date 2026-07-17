import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/primary_button.dart';

class ProfileFillScreen extends ConsumerStatefulWidget {
  const ProfileFillScreen({super.key});

  @override
  ConsumerState<ProfileFillScreen> createState() => _ProfileFillScreenState();
}

class _ProfileFillScreenState extends ConsumerState<ProfileFillScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      showAppToast(context, 'Заполните имя и фамилию');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .updateProfile(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
          );
      await ref
          .read(tokenStorageProvider)
          .saveProfileNames(_firstName.text.trim(), _lastName.text.trim());
      await ref.read(authStateProvider.notifier).refreshProfile();
      if (mounted) context.go('/app');
    } catch (e) {
      if (mounted) showAppToast(context, getApiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      fillHeight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Завершите профиль',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Укажите имя и фамилию для продолжения',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          InputField(
            controller: _firstName,
            label: 'Имя',
            icon: LucideIcons.user,
          ),
          const SizedBox(height: 16),
          InputField(
            controller: _lastName,
            label: 'Фамилия',
            icon: LucideIcons.user,
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Продолжить',
            loading: _loading,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
