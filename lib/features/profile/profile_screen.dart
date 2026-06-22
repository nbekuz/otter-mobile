import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/input_field.dart';
import '../../shared/widgets/primary_button.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  final _newPassword = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController();
    _lastName = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authStateProvider).user;
      final parts = user?.name.split(' ') ?? [];
      _firstName.text = parts.isNotEmpty ? parts.first : '';
      _lastName.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    });
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).updateProfile(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
          );
      await ref.read(authStateProvider.notifier).refreshProfile();
      if (mounted) {
        showAppToast(context, 'Профиль сохранён', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) showAppToast(context, getApiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).updateProfile(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            avatarPath: file.path,
          );
      await ref.read(authStateProvider.notifier).refreshProfile();
    } catch (e) {
      if (mounted) showAppToast(context, getApiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPassword.text.length < 8) {
      showAppToast(context, 'Минимум 8 символов');
      return;
    }
    try {
      await ref.read(authServiceProvider).changePassword(_newPassword.text);
      _newPassword.clear();
      if (mounted) {
        showAppToast(context, 'Пароль изменён', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) showAppToast(context, getApiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ResponsiveContent(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: OtterColors.sberGreen,
                backgroundImage:
                    user?.avatar != null ? NetworkImage(user!.avatar!) : null,
                child: user?.avatar == null
                    ? Text(
                        (user?.name.isNotEmpty == true
                                ? user!.name[0]
                                : 'A')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _pickAvatar,
              icon: const Icon(LucideIcons.camera, size: 18),
              label: const Text('Изменить фото'),
            ),
          ),
          const SizedBox(height: 24),
          InputField(controller: _firstName, label: 'Имя'),
          const SizedBox(height: 16),
          InputField(controller: _lastName, label: 'Фамилия'),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Сохранить',
            loading: _loading,
            onPressed: _saveProfile,
          ),
          const SizedBox(height: 32),
          const Text(
            'Новый пароль',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          InputField(
            controller: _newPassword,
            label: 'Пароль',
            obscure: true,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Сменить пароль',
            outline: true,
            onPressed: _changePassword,
          ),
        ],
        ),
      ),
    );
  }
}
