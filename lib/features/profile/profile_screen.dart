import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
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
  final _picker = ImagePicker();

  bool get _isWindowsDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

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
      await ref
          .read(authServiceProvider)
          .updateProfile(
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

  Future<ImageSource?> _showPhotoSourceSheet() {
    return showAppBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Изменить фото',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(LucideIcons.camera),
                  title: const Text('Сделать фото'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.image),
                  title: const Text('Выбрать из галереи'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.x),
                  title: const Text('Отмена'),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Returns false when the user denied access (toast already shown).
  Future<bool> _ensurePermission(ImageSource source) async {
    // Windows/desktop: no runtime camera/gallery permission model.
    if (kIsWeb || _isWindowsDesktop) return true;

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isGranted || status.isLimited) return true;
      if (!mounted) return false;
      showAppToast(
        context,
        status.isPermanentlyDenied
            ? 'Разрешите доступ к камере в настройках устройства'
            : 'Нет доступа к камере',
      );
      return false;
    }

    // Gallery: Android Photo Picker (API 33+) needs no permission.
    // On older Android, request storage only if currently denied.
    final photos = await Permission.photos.status;
    if (photos.isGranted || photos.isLimited) return true;

    final storage = await Permission.storage.status;
    if (storage.isGranted) return true;

    if (photos.isDenied) {
      final result = await Permission.photos.request();
      if (result.isGranted || result.isLimited || result.isRestricted) {
        return true;
      }
      if (result.isPermanentlyDenied && mounted) {
        showAppToast(
          context,
          'Разрешите доступ к фото в настройках устройства',
        );
        return false;
      }
    }

    if (storage.isDenied) {
      final result = await Permission.storage.request();
      if (result.isGranted) return true;
      if (result.isPermanentlyDenied && mounted) {
        showAppToast(
          context,
          'Разрешите доступ к фото в настройках устройства',
        );
        return false;
      }
    }

    // Allow the pick attempt — the system picker may still work.
    return true;
  }

  Future<XFile?> _pickImage(ImageSource source) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
    } on PlatformException catch (e) {
      debugPrint('[Profile] pickImage($source) failed: ${e.code} ${e.message}');
      if (!mounted) return null;

      final msg = e.message?.toLowerCase() ?? '';
      final denied = e.code.contains('permission') ||
          e.code.contains('access') ||
          msg.contains('permission') ||
          msg.contains('denied');

      if (denied) {
        showAppToast(
          context,
          source == ImageSource.camera
              ? 'Нет доступа к камере'
              : 'Нет доступа к галерее',
        );
        return null;
      }

      if (source == ImageSource.camera) {
        // Windows (and some devices) have no system camera UI for image_picker.
        showAppToast(
          context,
          'Камера недоступна — выберите фото из галереи',
        );
        return _pickImage(ImageSource.gallery);
      }

      showAppToast(context, 'Не удалось выбрать изображение');
      return null;
    } catch (e) {
      debugPrint('[Profile] pickImage($source) error: $e');
      if (mounted) {
        showAppToast(context, 'Не удалось выбрать изображение');
      }
      return null;
    }
  }

  Future<void> _pickAvatar() async {
    final source = await _showPhotoSourceSheet();
    if (source == null || !mounted) return;

    var effectiveSource = source;
    if (source == ImageSource.camera && _isWindowsDesktop) {
      // image_picker has no default camera UI on Windows — fall back gracefully.
      if (mounted) {
        showAppToast(
          context,
          'Камера на Windows недоступна — выберите фото из галереи',
        );
      }
      effectiveSource = ImageSource.gallery;
    } else {
      final allowed = await _ensurePermission(source);
      if (!allowed || !mounted) return;
    }

    final file = await _pickImage(effectiveSource);
    if (file == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .updateProfile(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            avatarPath: file.path,
          );
      await ref.read(authStateProvider.notifier).refreshProfile();
      if (mounted) {
        showAppToast(context, 'Фото обновлено', type: AppToastType.success);
      }
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: OtterColors.sberGreen,
                    backgroundImage: user?.avatar != null
                        ? NetworkImage(user!.avatar!)
                        : null,
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
            InputField(
              controller: _firstName,
              label: 'Имя',
              maxLength: 64,
            ),
            const SizedBox(height: 16),
            InputField(
              controller: _lastName,
              label: 'Фамилия',
              maxLength: 64,
            ),
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
