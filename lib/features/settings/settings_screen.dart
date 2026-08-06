import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/billing/android_premium_coming_soon.dart';
import '../../core/billing/premium_billing.dart';
import '../../core/layout/responsive.dart';
import '../../core/locale/app_languages.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/utils/open_url.dart';
import '../../core/utils/password_policy.dart';
import '../../core/utils/task_export.dart';
import '../../core/utils/timezone_utils.dart';
import '../../data/models/ui/ui_models.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../../shared/widgets/keyboard_dismisser.dart';
import '../../shared/widgets/otter_checkbox.dart';
import '../../shared/widgets/primary_button.dart';
import 'windows_premium_payment_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    this.openContact = false,
    this.openPremium = false,
  });

  final bool openContact;
  final bool openPremium;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _contactController = TextEditingController();
  bool _contactVisible = false;
  bool _premiumVisible = false;
  bool _recurringConsent = false;

  @override
  void initState() {
    super.initState();
    _contactVisible = widget.openContact;
    _premiumVisible = widget.openPremium;
    Future.microtask(() async {
      await ref.read(appSettingsProvider.notifier).load();
      await ref.read(feedbackAudioProvider).ensureLoaded();
      if (!isAndroidPremiumPurchaseBlocked) {
        await ref.read(premiumStateProvider.notifier).loadAll();
      }
      if (mounted) setState(() {});
      if (widget.openPremium && !isAndroidPremiumPurchaseBlocked) {
        setState(() => _premiumVisible = true);
      }
    });
  }

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _openPremium() async {
    setState(() => _premiumVisible = true);
    if (isAndroidPremiumPurchaseBlocked) return;
    await ref.read(premiumStateProvider.notifier).loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final auth = ref.watch(authStateProvider);
    final premium = ref.watch(premiumStateProvider);
    final isDark = settings.theme == 'dark';
    final wide = Responsive.isWide(context);
    final isPremium = premium.isPremium || settings.isPremium;
    final expiresLabel = _premiumExpiresLabel(premium, auth);

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Настройки',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => _confirmLogout(context),
              child: const Text(
                'Выйти',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ProfileCard(
          auth: auth,
          isDark: isDark,
          isPremium: isPremium,
          expiresLabel: expiresLabel,
          bannerTitle: _premiumBannerTitle(premium, isPremium),
          bannerSubtitle: _premiumBannerSubtitle(premium, isPremium, expiresLabel),
          onPremiumTap: _openPremium,
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Аккаунт',
          isDark: isDark,
          children: [
            _SettingsRow(
              icon: LucideIcons.user,
              label: 'Профиль',
              onTap: () => context.go('/app/profile'),
            ),
            _SettingsRow(
              icon: LucideIcons.lock,
              label: 'Пароль',
              onTap: _openPasswordModal,
            ),
            _SettingsRow(
              icon: LucideIcons.crown,
              iconColor: isDark
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFFEAB308),
              label: 'Премиум',
              labelColor: isDark
                  ? const Color(0xFFFCD34D)
                  : const Color(0xFFCA8A04),
              onTap: _openPremium,
            ),
          ],
        ),
        if (_premiumVisible)
          isAndroidPremiumPurchaseBlocked
              ? AndroidPremiumUnavailablePanel(
                  onClose: () => setState(() => _premiumVisible = false),
                )
              : _PremiumPanel(
                  state: premium,
                  recurringConsent: _recurringConsent,
                  onConsentChanged: (v) =>
                      setState(() => _recurringConsent = v ?? false),
                  onClose: () => setState(() => _premiumVisible = false),
                  onSelectTariff: (code) => ref
                      .read(premiumStateProvider.notifier)
                      .selectTariff(code),
                  onTrial: _startTrial,
                  onCheckout: _purchasePremium,
                  onRefresh: _refreshPremium,
                  onCancel: _cancelPremium,
                ),
        _BottomMenuSection(
          settings: settings,
          isDark: isDark,
          onToggle: (id, enabled) => _toggleNavItem(id, enabled, settings),
          onReorder: (orderedIds) {
            final enabled = [
              for (final id in orderedIds)
                if (settings.bottomNavItems.contains(id)) id,
            ];
            if (!enabled.contains('settings')) enabled.add('settings');
            ref
                .read(appSettingsProvider.notifier)
                .update(settings.copyWith(bottomNavItems: enabled));
          },
        ),
        _Section(
          title: 'Приложение',
          isDark: isDark,
          children: [
            _ThemeBlock(
              isDark: isDark,
              onSetTheme: (theme) {
                ref.read(appSettingsProvider.notifier).setTheme(theme);
                ref.read(themeModeProvider.notifier).state = theme;
              },
            ),
            _SettingsRow(
              icon: LucideIcons.paintbrush,
              label: 'Вид',
              value: _calendarViewLabel(settings.calendarDefaultView),
              onTap: () => _openViewSettings(settings),
            ),
            _SettingsRow(
              icon: LucideIcons.clock,
              label: 'Дата и время',
              value: settings.timezone?.isNotEmpty == true
                  ? settings.timezone!
                  : 'Не задан',
              onTap: () => _openDateTimeSettings(settings),
            ),
            _SettingsRow(
              icon: LucideIcons.download,
              label: 'Интеграции и импорт',
              onTap: _openIntegrationsSettings,
            ),
          ],
        ),
        _Section(
          title: 'Звуки и уведомления',
          isDark: isDark,
          children: [
            _ToggleRow(
              icon: LucideIcons.bell,
              label: 'Уведомления',
              value: settings.notifications,
              onChanged: (v) => ref
                  .read(appSettingsProvider.notifier)
                  .update(settings.copyWith(notifications: v)),
            ),
            _ToggleRow(
              icon: LucideIcons.vibrate,
              label: 'Вибрация',
              value: settings.vibration,
              onChanged: (v) => ref
                  .read(appSettingsProvider.notifier)
                  .update(settings.copyWith(vibration: v)),
            ),
            _SettingsRow(
              icon: LucideIcons.volume2,
              label: 'Звук уведомления',
              value: ref
                  .watch(feedbackAudioProvider)
                  .label('notification', settings.notificationSound),
              onTap: () => _pickSound(
                title: 'Звук уведомления',
                category: 'notification',
                currentKey: settings.notificationSound,
                onSelected: (key) => ref
                    .read(appSettingsProvider.notifier)
                    .update(settings.copyWith(notificationSound: key)),
              ),
            ),
            _SettingsRow(
              icon: LucideIcons.circleCheck,
              label: 'Звук подтверждения',
              value: ref
                  .watch(feedbackAudioProvider)
                  .label('completion', settings.completionSound),
              onTap: () => _pickSound(
                title: 'Звук подтверждения',
                category: 'completion',
                currentKey: settings.completionSound,
                onSelected: (key) => ref
                    .read(appSettingsProvider.notifier)
                    .update(settings.copyWith(completionSound: key)),
              ),
            ),
          ],
        ),
        _Section(
          title: 'Разделы списка задач',
          isDark: isDark,
          children: [
            for (final g in _kTaskGroups)
              _GroupToggle(
                label: g.label,
                group: g.id,
                color: g.color,
                settings: settings,
              ),
          ],
        ),
        _Section(
          title: 'Общее',
          isDark: isDark,
          children: [
            _SettingsRow(
              icon: LucideIcons.globe,
              label: 'Язык',
              value: appLanguageLabel(settings.language),
              onTap: () => _pickLanguage(settings),
            ),
          ],
        ),
        _Section(
          title: 'Помощь и информация',
          isDark: isDark,
          children: [
            _SettingsRow(
              icon: LucideIcons.helpCircle,
              label: 'Частые вопросы (FAQ)',
              onTap: () => context.push('/app/faq'),
            ),
            _SettingsRow(
              icon: LucideIcons.fileText,
              label: 'Юридические документы',
              onTap: () => context.push('/app/legal'),
            ),
            _SettingsRow(
              icon: LucideIcons.share2,
              label: 'Рекомендовать друзьям',
              onTap: _shareApp,
            ),
            _SettingsRow(
              icon: LucideIcons.messageSquare,
              label: 'Написать нам',
              trailingIcon: _contactVisible
                  ? LucideIcons.chevronUp
                  : LucideIcons.chevronDown,
              onTap: () => setState(() => _contactVisible = !_contactVisible),
            ),
            if (_contactVisible) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _contactController,
                  maxLines: 4,
                  onTapOutside: dismissKeyboardOnTapOutside,
                  onEditingComplete: KeyboardDismisser.dismiss,
                  decoration: const InputDecoration(
                    hintText: 'Ваше сообщение...',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton(
                  onPressed: _sendContact,
                  style: FilledButton.styleFrom(
                    backgroundColor: OtterColors.sberGreen,
                  ),
                  child: const Text('Отправить'),
                ),
              ),
            ],
            _SettingsRow(
              icon: LucideIcons.info,
              label: 'О приложении',
              onTap: _showAbout,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: isDark
              ? OtterColors.priorityHigh.withValues(alpha: 0.1)
              : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _confirmDeleteAccount(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? OtterColors.priorityHigh.withValues(alpha: 0.35)
                      : const Color(0xFFFECACA),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'Удалить аккаунт',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: wide ? 16 : 80),
      ],
    );

    return Scaffold(
      backgroundColor: OtterColors.pageBg(isDark),
      body: SafeArea(
        bottom: false,
        child: content,
      ),
    );
  }

  static const _kTaskGroups = [
    (id: 'overdue', label: 'Просрочено', color: Color(0xFFFF3B30)),
    (id: 'today', label: 'Сегодня', color: Color(0xFFFF9500)),
    (id: 'tomorrow', label: 'Завтра', color: Color(0xFF007AFF)),
    (id: 'later', label: 'Позже', color: Color(0xFFAF52DE)),
    (id: 'nodate', label: 'Без срока', color: Color(0xFF8E8E93)),
    (id: 'completed', label: 'Готово', color: Color(0xFF21A038)),
  ];

  String? _premiumExpiresLabel(PremiumState premium, AuthState auth) {
    final raw = premium.subscription?.expiresAt;
    if (raw == null || raw.isEmpty) return null;
    final date = DateTime.tryParse(raw);
    if (date == null) return null;
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String _premiumBannerTitle(PremiumState premium, bool isPremium) {
    if (!isPremium) return 'Подключить Premium';
    final status = premium.subscription?.status;
    if (status == 'trial') return 'Пробный период активен';
    if (status == 'cancelled') return 'Premium активен (без автопродления)';
    return 'Premium активен';
  }

  String? _premiumBannerSubtitle(
    PremiumState premium,
    bool isPremium,
    String? until,
  ) {
    if (!isPremium) return null;
    final tariff = premium.subscription?.tariff?.title;
    if (tariff != null && until != null) return '$tariff · до $until';
    if (tariff != null) return tariff;
    if (until != null) return 'до $until';
    return null;
  }

  void _toggleNavItem(String id, bool enabled, AppSettings settings) {
    var items = List<String>.from(settings.bottomNavItems);
    if (enabled) {
      if (!items.contains(id)) items.add(id);
    } else {
      if (items.length <= 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нужно оставить минимум 2 вкладки')),
        );
        return;
      }
      items.remove(id);
    }
    if (!items.contains('settings')) items.add('settings');
    ref
        .read(appSettingsProvider.notifier)
        .update(settings.copyWith(bottomNavItems: items));
  }

  Future<void> _openNameModal() async {
    final user = ref.read(authStateProvider).user;
    final parts = user?.name.trim().split(RegExp(r'\s+')) ?? [];
    final firstCtrl = TextEditingController(
      text: parts.isNotEmpty ? parts.first : '',
    );
    final lastCtrl = TextEditingController(
      text: parts.length > 1 ? parts.sublist(1).join(' ') : '',
    );
    String? error;

    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Имя и фамилия',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Имя',
                    style: TextStyle(fontSize: 13, color: OtterColors.sberGray),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: firstCtrl,
                    onTapOutside: dismissKeyboardOnTapOutside,
                    decoration: const InputDecoration(hintText: 'Имя'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Фамилия',
                    style: TextStyle(fontSize: 13, color: OtterColors.sberGray),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: lastCtrl,
                    onTapOutside: dismissKeyboardOnTapOutside,
                    decoration: const InputDecoration(hintText: 'Фамилия'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Сохранить',
                    onPressed: () async {
                      try {
                        await ref.read(authServiceProvider).updateProfile(
                              firstName: firstCtrl.text.trim(),
                              lastName: lastCtrl.text.trim(),
                            );
                        await ref
                            .read(authStateProvider.notifier)
                            .refreshProfile();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setModal(
                          () => error = getApiErrorMessage(e),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    firstCtrl.dispose();
    lastCtrl.dispose();
  }

  Future<void> _openPasswordModal() async {
    final nextCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;

    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Пароль',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Новый: 8–20 символов, Aa + цифра + спецсимвол (!, @ …).',
                    style: TextStyle(fontSize: 12, color: OtterColors.sberGray),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nextCtrl,
                    obscureText: true,
                    onTapOutside: dismissKeyboardOnTapOutside,
                    decoration: const InputDecoration(
                      hintText: 'Новый пароль',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: true,
                    onTapOutside: dismissKeyboardOnTapOutside,
                    decoration: const InputDecoration(
                      hintText: 'Повторите новый пароль',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Сохранить',
                    onPressed: () async {
                      final next = nextCtrl.text;
                      final policy = validateNewPassword(next);
                      if (policy != null) {
                        setModal(() => error = policy);
                        return;
                      }
                      if (next != confirmCtrl.text) {
                        setModal(() => error = 'Пароли не совпадают');
                        return;
                      }
                      try {
                        await ref
                            .read(authServiceProvider)
                            .changePassword(next);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                      } catch (e) {
                        setModal(() => error = getApiErrorMessage(e));
                        return;
                      }
                      if (!mounted) return;
                      showAppToast(
                        context,
                        'Пароль обновлён',
                        type: AppToastType.success,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    nextCtrl.dispose();
    confirmCtrl.dispose();
  }

  Future<void> _openAvatarSheet() async {
    final source = await showAppBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Аватар',
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
              ],
            ),
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    var effective = source;
    if (source == ImageSource.camera &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows) {
      showAppToast(
        context,
        'Камера на Windows недоступна — выберите фото из галереи',
      );
      effective = ImageSource.gallery;
    }

    try {
      final file = await ImagePicker().pickImage(
        source: effective,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      final user = ref.read(authStateProvider).user;
      final parts = user?.name.trim().split(RegExp(r'\s+')) ?? [];
      await ref.read(authServiceProvider).updateProfile(
            firstName: parts.isNotEmpty ? parts.first : '',
            lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
            avatarPath: file.path,
          );
      await ref.read(authStateProvider.notifier).refreshProfile();
      if (mounted) {
        showAppToast(context, 'Аватар обновлён', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) showAppToast(context, getApiErrorMessage(e));
    }
  }

  Future<void> _openDevicesSheet() async {
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: ref.read(devicesServiceProvider).listDevices(),
          builder: (context, snap) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Устройства',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (snap.connectionState != ConnectionState.done)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snap.hasError)
                      Text(
                        getApiErrorMessage(snap.error!),
                        style: const TextStyle(color: Colors.red),
                      )
                    else if ((snap.data ?? []).isEmpty)
                      const Text(
                        'Нет зарегистрированных устройств',
                        style: TextStyle(color: OtterColors.sberGray),
                      )
                    else
                      ...snap.data!.map((d) {
                        final name = d['name']?.toString() ??
                            d['platform']?.toString() ??
                            'Устройство';
                        final platform = d['platform']?.toString() ?? '';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(LucideIcons.smartphone),
                          title: Text(name),
                          subtitle: platform.isEmpty ? null : Text(platform),
                        );
                      }),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Закрыть'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendContact() async {
    final message = _contactController.text.trim();
    if (message.isEmpty) return;
    KeyboardDismisser.dismiss();
    try {
      await ref.read(settingsServiceProvider).sendHelpMessage(message);
      _contactController.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Сообщение отправлено')));
        setState(() => _contactVisible = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getApiErrorMessage(e))));
      }
    }
  }

  String _calendarViewLabel(String view) => switch (view) {
        'week' => 'Неделя',
        'month' => 'Месяц',
        'year' => 'Год',
        _ => 'День',
      };

  Future<void> _openViewSettings(AppSettings settings) async {
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final s = ref.watch(appSettingsProvider);
            const options = <(String, String, IconData)>[
              ('day', 'День', LucideIcons.calendarDays),
              ('week', 'Неделя', LucideIcons.columns3),
              ('month', 'Месяц', LucideIcons.calendar),
              ('year', 'Год', LucideIcons.calendarRange),
            ];

            void setView(String id) {
              ref.read(appSettingsProvider.notifier).applyLocal(
                    s.copyWith(calendarDefaultView: id),
                  );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Вид',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Какой вид календаря открывать при входе в раздел «Календарь».',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: OtterColors.sberGray,
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'КАЛЕНДАРЬ ПО УМОЛЧАНИЮ',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: OtterColors.sberGray,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.35,
                      children: [
                        for (final opt in options)
                          _ViewOptionCard(
                            label: opt.$2,
                            icon: opt.$3,
                            selected: s.calendarDefaultView == opt.$1,
                            onTap: () => setView(opt.$1),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openDateTimeSettings(AppSettings settings) async {
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => const _DateTimeSettingsSheet(),
    );
  }

  Future<void> _openIntegrationsSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Интеграции и импорт',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Экспортируйте задачи в JSON или импортируйте их из файла Оттер.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OtterColors.sberGray,
                      ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.download),
                  title: const Text('Экспорт задач'),
                  subtitle: const Text('Поделиться JSON со всеми задачами'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _exportTasks();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.upload),
                  title: const Text('Импорт задач'),
                  subtitle: const Text('Загрузить JSON-файл Оттер'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _importTasks();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportTasks() async {
    try {
      final tasksState = ref.read(tasksStateProvider);
      var tasks = tasksState.groups.values.expand((e) => e).toList();
      if (tasks.isEmpty) {
        await ref.read(tasksStateProvider.notifier).loadGrouped();
        tasks = ref
            .read(tasksStateProvider)
            .groups
            .values
            .expand((e) => e)
            .toList();
      }
      if (tasks.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет задач для экспорта')),
        );
        return;
      }
      final json = encodeTasksExport(tasks);
      final name =
          'otter-tasks-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Экспорт задач',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: utf8.encode(json),
      );
      if (saved == null) {
        await Share.share(json, subject: name);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Экспортировано задач: ${tasks.length}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getApiErrorMessage(e))),
      );
    }
  }

  Future<void> _importTasks() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) {
        throw const FormatException('Не удалось прочитать файл');
      }
      final parsed = parseTasksExport(jsonDecode(utf8.decode(bytes)));
      var created = 0;
      for (final partial in parsed) {
        await ref.read(tasksStateProvider.notifier).addTask(partial);
        created++;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Импортировано задач: $created')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is FormatException
          ? e.message
          : getApiErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _pickLanguage(AppSettings settings) async {
    final current = normalizeAppLanguage(settings.language);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 12),
                  child: Text(
                    'Язык приложения',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                for (final lang in kSupportedAppLanguages)
                  ListTile(
                    title: Text(lang.label),
                    trailing: current == lang.id
                        ? const Icon(
                            LucideIcons.check,
                            color: OtterColors.sberGreen,
                          )
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: current == lang.id
                            ? OtterColors.sberGreen
                            : OtterColors.border(OtterColors.isDarkOf(ctx)),
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, lang.id),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || picked == current) return;
    await ref.read(appSettingsProvider.notifier).update(
          settings.copyWith(language: normalizeAppLanguage(picked)),
        );
  }

  Future<void> _pickSound({
    required String title,
    required String category,
    required String currentKey,
    required ValueChanged<String> onSelected,
  }) async {
    final feedback = ref.read(feedbackAudioProvider);
    await feedback.ensureLoaded();
    final apiSounds = category == 'completion'
        ? feedback.completion
        : feedback.notification;
    final options = apiSounds.isNotEmpty
        ? apiSounds
        : feedback.fallbackFor(category);

    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final sound in options)
                      ListTile(
                        leading: Text(
                          sound.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        title: Text(sound.title),
                        trailing: currentKey == sound.key
                            ? const Icon(
                                LucideIcons.check,
                                color: OtterColors.sberGreen,
                              )
                            : null,
                        onTap: () {
                          unawaited(feedback.preview(sound));
                          Navigator.pop(ctx, sound.key);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    onSelected(picked);
  }

  Future<void> _startTrial() async {
    // Android RuStore v1: commerce (including trial paywall) is hidden.
    if (isAndroidPremiumPurchaseBlocked) return;

    final tariff = ref.read(premiumStateProvider).selectedTariff;
    if (tariff?.isRecurring == true && !_recurringConsent) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Подтвердите согласие на автоматические списания'),
        ),
      );
      return;
    }
    try {
      await ref
          .read(premiumStateProvider.notifier)
          .startTrial(recurringConsent: _recurringConsent);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пробный период Premium активирован')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getApiErrorMessage(e))));
      }
    }
  }

  Future<void> _purchasePremium() async {
    // Android RuStore v1: no checkout UI / Robokassa. Kept for Windows/Web.
    if (isAndroidPremiumPurchaseBlocked) return;

    final tariff = ref.read(premiumStateProvider).selectedTariff;
    if (tariff?.isRecurring == true && !_recurringConsent) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Подтвердите согласие на автоматические списания'),
        ),
      );
      return;
    }
    try {
      final url = await ref
          .read(premiumStateProvider.notifier)
          .checkout(recurringConsent: _recurringConsent);
      if (!mounted || url.isEmpty) return;
      final opened = await openExternalUrl(url);
      if (!mounted) return;
      if (Platform.isWindows && opened) {
        final result = await showWindowsPremiumPaymentDialog(context: context);
        if (!mounted) return;

        switch (result) {
          case PremiumPaymentPollingResult.success:
            setState(() => _premiumVisible = false);
            unawaited(ref.read(appSettingsProvider.notifier).load());
            unawaited(ref.read(authStateProvider.notifier).refreshProfile());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Premium успешно активирован')),
            );
          case PremiumPaymentPollingResult.cancelled:
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Платёж отменён')));
          case PremiumPaymentPollingResult.timeout:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Время ожидания истекло. Статус можно обновить вручную.',
                ),
              ),
            );
          case PremiumPaymentPollingResult.fatalError:
            final error = ref.read(premiumStateProvider).error;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error ?? 'Не удалось проверить статус платежа'),
              ),
            );
          case PremiumPaymentPollingResult.stopped:
          case null:
            break;
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Откройте оплату. После оплаты нажмите «Обновить статус».'
                : 'Не удалось открыть ссылку. Скопируйте её вручную.',
          ),
          duration: const Duration(seconds: 5),
          action: opened
              ? null
              : SnackBarAction(
                  label: 'Копировать',
                  onPressed: () => Clipboard.setData(ClipboardData(text: url)),
                ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getApiErrorMessage(e))));
      }
    }
  }

  Future<void> _refreshPremium() async {
    try {
      final sub = await ref
          .read(premiumStateProvider.notifier)
          .refreshSubscription();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sub.isPremium
                ? 'Premium активен'
                : 'Оплата ещё не подтверждена. Подождите и обновите снова.',
          ),
        ),
      );
      if (sub.isPremium) {
        setState(() => _premiumVisible = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getApiErrorMessage(e))));
      }
    }
  }

  Future<void> _cancelPremium() async {
    try {
      await ref.read(premiumStateProvider.notifier).cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Автопродление отключено. Доступ сохранится до конца периода.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(getApiErrorMessage(e))));
      }
    }
  }

  Future<void> _shareApp() async {
    const url = 'https://ottertime.ru';
    try {
      await Share.share(
        'Оттер — планировщик задач: $url',
        subject: 'Оттер — Планировщик',
      );
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка скопирована')),
      );
    }
  }

  Future<void> _showAbout() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('О приложении'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Оттер',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text('Версия ${info.version}'),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.fileText),
              title: const Text('Юридические документы'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/app/legal');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Аккаунт и связанные данные будут удалены безвозвратно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(authStateProvider.notifier).deleteAccount();
      if (context.mounted) context.go('/');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getApiErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из профиля?'),
        content: const Text('Вы сможете войти снова в любое время.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(authStateProvider.notifier).logout();
      if (context.mounted) context.go('/');
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.auth,
    required this.isDark,
    required this.isPremium,
    required this.expiresLabel,
    required this.bannerTitle,
    required this.bannerSubtitle,
    required this.onPremiumTap,
  });

  final AuthState auth;
  final bool isDark;
  final bool isPremium;
  final String? expiresLabel;
  final String bannerTitle;
  final String? bannerSubtitle;
  final VoidCallback onPremiumTap;

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    return Material(
      color: OtterColors.surface(isDark),
      borderRadius: BorderRadius.circular(16),
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: () => context.go('/app/profile'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: isPremium
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFACC15),
                              width: 2,
                            ),
                          )
                        : null,
                    padding: isPremium ? const EdgeInsets.all(2) : EdgeInsets.zero,
                    child: CircleAvatar(
                      radius: 32,
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
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: OtterColors.sberGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.camera,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user?.name ?? 'Пользователь',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: OtterColors.text(isDark),
                            ),
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: 6),
                          const Text('⭐', style: TextStyle(fontSize: 16)),
                        ],
                      ],
                    ),
                    if (user?.email != null)
                      Text(
                        user!.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: OtterColors.muted(isDark),
                        ),
                      ),
                    if (isPremium && expiresLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Срок до $expiresLabel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFA16207),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onPremiumTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x4DFBBF24)
                                  : const Color(0xFFFDE68A),
                            ),
                            gradient: isDark
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFEFEFCE8),
                                      Color(0xFFFFFBEB),
                                    ],
                                  ),
                            color: isDark ? OtterColors.darkElevated : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PREMIUM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                  color: isDark
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFCA8A04),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                bannerTitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: OtterColors.text(isDark),
                                ),
                              ),
                              if (bannerSubtitle != null)
                                Text(
                                  bannerSubtitle!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: OtterColors.muted(isDark),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.chevronRight,
                color: OtterColors.sberGray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel({
    required this.state,
    required this.recurringConsent,
    required this.onConsentChanged,
    required this.onClose,
    required this.onSelectTariff,
    required this.onTrial,
    required this.onCheckout,
    required this.onRefresh,
    required this.onCancel,
  });

  final PremiumState state;
  final bool recurringConsent;
  final ValueChanged<bool?> onConsentChanged;
  final VoidCallback onClose;
  final ValueChanged<String> onSelectTariff;
  final VoidCallback onTrial;
  final VoidCallback onCheckout;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;

  String? _formatExpires(String? value) {
    if (value == null || value.isEmpty) return null;
    final date = DateTime.tryParse(value);
    if (date == null) return null;
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedTariff;
    final isPremium = state.isPremium;
    final expires = _formatExpires(state.subscription?.expiresAt);
    final needsConsent = selected?.isRecurring == true;
    final isDark = OtterColors.isDarkOf(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Оттер Premium',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (state.loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              ...state.features.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f.title)),
                    ],
                  ),
                ),
              ),
              if (isPremium) ...[
                const SizedBox(height: 8),
                Text(
                  state.subscription?.status == 'trial'
                      ? 'Пробный период активен'
                      : 'Premium активен',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: OtterColors.sberGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (expires != null)
                  Text(
                    'Срок до $expires',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: OtterColors.sberGray,
                    ),
                  ),
                if (state.subscription?.recurringEnabled == true &&
                    state.subscription?.cancelledAt == null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: state.actionLoading ? null : onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: Text(
                      state.actionLoading
                          ? 'Отмена…'
                          : 'Отменить автопродление',
                    ),
                  ),
                ],
                TextButton(
                  onPressed: state.actionLoading ? null : onRefresh,
                  child: Text(
                    state.actionLoading ? 'Обновление…' : 'Обновить статус',
                  ),
                ),
              ] else ...[
                if (state.tariffs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  for (final tariff in state.tariffs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: selected?.code == tariff.code
                            ? (isDark
                                ? const Color(0x33FBBF24)
                                : Colors.amber.shade50)
                            : OtterColors.elevated(isDark),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onSelectTariff(tariff.code),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tariff.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (tariff.promoDays > 0)
                                        Text(
                                          '${tariff.promoDays} дней бесплатно',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: OtterColors.sberGreen,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  tariff.priceLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
                if (needsConsent) ...[
                  OtterCheckbox(
                    value: recurringConsent,
                    onChanged: onConsentChanged,
                    child: const Text(
                      'Я согласен на автоматические списания согласно условиям оферты',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if ((selected?.promoDays ?? 0) > 0)
                  OutlinedButton(
                    onPressed: state.actionLoading ? null : onTrial,
                    child: Text(
                      state.actionLoading
                          ? 'Активация…'
                          : 'Попробовать бесплатно (${selected!.promoDays} дн.)',
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: state.actionLoading ? null : onCheckout,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade600,
                  ),
                  child: Text(
                    state.actionLoading
                        ? 'Открываем оплату…'
                        : 'Оплатить ${selected?.priceLabel ?? 'Premium'}',
                  ),
                ),
                TextButton(
                  onPressed: state.actionLoading ? null : onRefresh,
                  child: Text(
                    state.actionLoading
                        ? 'Проверяем…'
                        : 'Я оплатил — обновить статус',
                  ),
                ),
                const Text(
                  'После оплаты Premium включается автоматически. '
                  'Если статус не обновился — нажмите «обновить статус».',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: OtterColors.sberGray),
                ),
              ],
            ],
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            TextButton(onPressed: onClose, child: const Text('Закрыть')),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    required this.isDark,
  });

  final String title;
  final List<Widget> children;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: OtterColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: OtterColors.border(isDark)) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: OtterColors.muted(isDark),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.iconColor,
    this.labelColor,
    this.trailingIcon = LucideIcons.chevronRight,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;
  final Color? iconColor;
  final Color? labelColor;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? OtterColors.muted(isDark)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? OtterColors.text(isDark),
                ),
              ),
            ),
            if (value != null) ...[
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    color: OtterColors.muted(isDark),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(trailingIcon, size: 16, color: OtterColors.border(isDark)),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: OtterColors.muted(isDark)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: OtterColors.text(isDark),
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: OtterColors.sberGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ThemeBlock extends StatelessWidget {
  const _ThemeBlock({required this.isDark, required this.onSetTheme});

  final bool isDark;
  final ValueChanged<String> onSetTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: OtterColors.surfaceAlt(isDark),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isDark ? LucideIcons.sun : LucideIcons.moon,
              size: 20,
              color: OtterColors.text(isDark),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Переключение темы',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: OtterColors.text(isDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? OtterColors.sberBlue.withValues(alpha: 0.15)
                            : OtterColors.greenTint(isDark),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isDark ? 'Dark' : 'Light',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? OtterColors.sberBlue
                              : OtterColors.sberGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Интерфейс переключается мгновенно и сохраняет выбранное оформление.',
                  style: TextStyle(
                    fontSize: 12,
                    color: OtterColors.muted(isDark),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ThemeChip(
                      label: 'Светлая',
                      selected: !isDark,
                      selectedColor: OtterColors.sberGreen,
                      onTap: () => onSetTheme('light'),
                    ),
                    const SizedBox(width: 8),
                    _ThemeChip(
                      label: 'Тёмная',
                      selected: isDark,
                      selectedColor: OtterColors.sberBlue,
                      onTap: () => onSetTheme('dark'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    return Material(
      color: selected ? selectedColor : OtterColors.elevated(isDark),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : OtterColors.muted(isDark),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomMenuSection extends StatelessWidget {
  const _BottomMenuSection({
    required this.settings,
    required this.isDark,
    required this.onToggle,
    required this.onReorder,
  });

  final AppSettings settings;
  final bool isDark;
  final void Function(String id, bool enabled) onToggle;
  final ValueChanged<List<String>> onReorder;

  List<BottomNavItem> _ordered() {
    final byId = {for (final i in kAllNavItems) i.id: i};
    final enabled = settings.bottomNavItems
        .map((id) => byId[id])
        .whereType<BottomNavItem>()
        .toList();
    final rest =
        kAllNavItems.where((i) => !settings.bottomNavItems.contains(i.id));
    return [...enabled, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final items = _ordered();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: OtterColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: OtterColors.border(isDark)) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'НИЖНЕЕ МЕНЮ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: OtterColors.sberGray,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Включайте вкладки и меняйте порядок перетаскиванием.',
              style: TextStyle(fontSize: 12, color: OtterColors.sberGray),
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            // ignore: deprecated_member_use
            onReorder: (oldIndex, newIndex) {
              final next = List<BottomNavItem>.from(items);
              if (newIndex > oldIndex) newIndex -= 1;
              final moved = next.removeAt(oldIndex);
              next.insert(newIndex, moved);
              onReorder(next.map((e) => e.id).toList());
            },
            itemBuilder: (context, index) {
              final item = items[index];
              final enabled = settings.bottomNavItems.contains(item.id);
              final isSettings = item.id == 'settings';
              return Material(
                key: ValueKey(item.id),
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            LucideIcons.gripVertical,
                            size: 18,
                            color: OtterColors.muted(isDark),
                          ),
                        ),
                      ),
                      Icon(item.icon, size: 20, color: OtterColors.muted(isDark)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: OtterColors.text(isDark),
                          ),
                        ),
                      ),
                      if (isSettings)
                        Text(
                          'Всегда',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: OtterColors.muted(isDark),
                          ),
                        )
                      else
                        Switch(
                          value: enabled,
                          activeThumbColor: OtterColors.sberGreen,
                          onChanged: (v) => onToggle(item.id, v),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GroupToggle extends ConsumerWidget {
  const _GroupToggle({
    required this.label,
    required this.group,
    required this.color,
    required this.settings,
  });

  final String label;
  final String group;
  final Color color;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = settings.visibleGroups.contains(group);
    final isDark = OtterColors.isDarkOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: OtterColors.text(isDark),
              ),
            ),
          ),
          Switch(
            value: visible,
            activeThumbColor: OtterColors.sberGreen,
            onChanged: (v) {
              final groups = List<String>.from(settings.visibleGroups);
              if (v) {
                if (!groups.contains(group)) groups.add(group);
              } else {
                groups.remove(group);
              }
              ref
                  .read(appSettingsProvider.notifier)
                  .update(settings.copyWith(visibleGroups: groups));
            },
          ),
        ],
      ),
    );
  }
}

class _ViewOptionCard extends StatelessWidget {
  const _ViewOptionCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);
    return Material(
      color: selected
          ? OtterColors.greenTint(isDark)
          : OtterColors.surface(isDark),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? OtterColors.sberGreen
                  : OtterColors.border(isDark),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? OtterColors.sberGreen
                    : OtterColors.muted(isDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? OtterColors.sberGreen
                        : OtterColors.text(isDark),
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  LucideIcons.check,
                  size: 18,
                  color: OtterColors.sberGreen,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTimeSettingsSheet extends ConsumerStatefulWidget {
  const _DateTimeSettingsSheet();

  @override
  ConsumerState<_DateTimeSettingsSheet> createState() =>
      _DateTimeSettingsSheetState();
}

class _DateTimeSettingsSheetState
    extends ConsumerState<_DateTimeSettingsSheet> {
  Timer? _clock;
  DateTime _now = DateTime.now();
  bool _syncing = false;
  String? _deviceTz;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    unawaited(_loadDeviceTz());
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _loadDeviceTz() async {
    try {
      final tz = await deviceTimezone();
      if (!mounted) return;
      setState(() => _deviceTz = tz);
    } catch (_) {}
  }

  String _utcOffsetLabel(DateTime at) {
    final o = at.timeZoneOffset;
    final sign = o.isNegative ? '-' : '+';
    final h = o.inHours.abs().toString().padLeft(2, '0');
    final m = (o.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC$sign$h:$m';
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final deviceTz = await deviceTimezone();
      final s = ref.read(appSettingsProvider);
      await ref.read(appSettingsProvider.notifier).update(
            s.copyWith(timezone: deviceTz),
          );
      if (!mounted) return;
      setState(() => _deviceTz = deviceTz);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Часовой пояс обновлён')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getApiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appSettingsProvider);
    final isDark = OtterColors.isDarkOf(context);
    final tz = s.timezone?.isNotEmpty == true ? s.timezone! : 'Не задан';
    final nowLabel = DateFormat('d MMM yyyy, HH:mm:ss', 'ru').format(_now);
    final offset = _utcOffsetLabel(_now);
    final matchesDevice =
        _deviceTz != null && s.timezone != null && s.timezone == _deviceTz;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Дата и время',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Часовой пояс нужен для напоминаний и списков «Сегодня» и «Просрочено».',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OtterColors.muted(isDark),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: OtterColors.elevated(isDark),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: OtterColors.border(isDark).withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: OtterColors.surface(isDark),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: OtterColors.border(isDark)),
                    ),
                    child: const Icon(
                      LucideIcons.globe,
                      size: 22,
                      color: OtterColors.sberGreen,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ЧАСОВОЙ ПОЯС',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: OtterColors.muted(isDark),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tz,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: OtterColors.text(isDark),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: OtterColors.surface(isDark),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: OtterColors.border(isDark),
                                ),
                              ),
                              child: Text(
                                offset,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: OtterColors.text(isDark),
                                ),
                              ),
                            ),
                            if (matchesDevice)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: OtterColors.greenTint(isDark),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.check,
                                      size: 12,
                                      color: OtterColors.sberGreen,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Как на устройстве',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: OtterColors.sberGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Сейчас · $nowLabel',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: OtterColors.muted(isDark),
                                    height: 1.3,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _syncing ? null : _sync,
              style: FilledButton.styleFrom(
                backgroundColor: OtterColors.sberGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    OtterColors.sberGreen.withValues(alpha: 0.45),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.smartphone, size: 18),
              label: Text(
                _syncing
                    ? 'Синхронизация…'
                    : 'Синхронизировать с устройством',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

