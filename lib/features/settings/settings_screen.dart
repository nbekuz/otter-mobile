import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../core/utils/open_url.dart';
import '../../data/models/ui/ui_models.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../../shared/widgets/keyboard_dismisser.dart';
import '../../shared/widgets/otter_checkbox.dart';
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
      if (widget.openPremium) {
        await ref.read(premiumStateProvider.notifier).loadAll();
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

    final content = ListView(
      padding: const EdgeInsets.all(16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Настройки',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () => _confirmLogout(context),
              child: const Text('Выйти', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ProfileCard(auth: auth, isDark: isDark, isPremium: isPremium),
        const SizedBox(height: 16),
        _Section(
          title: 'Аккаунт',
          children: [
            ListTile(
              leading: const Icon(LucideIcons.user),
              title: const Text('Мой профиль'),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => context.go('/app/profile'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.crown, color: Colors.amber),
              title: const Text('Premium'),
              subtitle: Text(
                isPremium ? 'Premium активен' : 'Подключить Premium',
              ),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: _openPremium,
            ),
          ],
        ),
        if (_premiumVisible)
          _PremiumPanel(
            state: premium,
            recurringConsent: _recurringConsent,
            onConsentChanged: (v) =>
                setState(() => _recurringConsent = v ?? false),
            onClose: () => setState(() => _premiumVisible = false),
            onSelectTariff: (code) =>
                ref.read(premiumStateProvider.notifier).selectTariff(code),
            onTrial: _startTrial,
            onCheckout: _purchasePremium,
            onRefresh: _refreshPremium,
            onCancel: _cancelPremium,
          ),
        _Section(
          title: 'Нижнее меню',
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Включайте вкладки для нижней панели.',
                style: TextStyle(fontSize: 12, color: OtterColors.sberGray),
              ),
            ),
            for (final item in kAllNavItems)
              SwitchListTile(
                title: Text(item.label),
                subtitle: item.id == 'settings'
                    ? const Text('Всегда включено')
                    : null,
                value: settings.bottomNavItems.contains(item.id),
                activeThumbColor: OtterColors.sberGreen,
                onChanged: item.id == 'settings'
                    ? null
                    : (v) => _toggleNavItem(item.id, v, settings),
              ),
          ],
        ),
        _Section(
          title: 'Приложение',
          children: [
            SwitchListTile(
              title: const Text('Тёмная тема'),
              value: isDark,
              activeThumbColor: OtterColors.sberGreen,
              onChanged: (v) {
                final theme = v ? 'dark' : 'light';
                ref.read(appSettingsProvider.notifier).setTheme(theme);
                ref.read(themeModeProvider.notifier).state = theme;
              },
            ),
          ],
        ),
        _Section(
          title: 'Звуки и уведомления',
          children: [
            SwitchListTile(
              title: const Text('Уведомления'),
              value: settings.notifications,
              activeThumbColor: OtterColors.sberGreen,
              onChanged: (v) => ref
                  .read(appSettingsProvider.notifier)
                  .update(settings.copyWith(notifications: v)),
            ),
            SwitchListTile(
              title: const Text('Вибрация'),
              value: settings.vibration,
              activeThumbColor: OtterColors.sberGreen,
              onChanged: (v) => ref
                  .read(appSettingsProvider.notifier)
                  .update(settings.copyWith(vibration: v)),
            ),
          ],
        ),
        _Section(
          title: 'Разделы списка задач',
          children: [
            _GroupToggle(
              label: 'Просрочено',
              group: 'overdue',
              settings: settings,
            ),
            _GroupToggle(label: 'Сегодня', group: 'today', settings: settings),
            _GroupToggle(
              label: 'Завтра',
              group: 'tomorrow',
              settings: settings,
            ),
            _GroupToggle(label: 'Позже', group: 'later', settings: settings),
            _GroupToggle(
              label: 'Без срока',
              group: 'nodate',
              settings: settings,
            ),
            _GroupToggle(
              label: 'Готово',
              group: 'completed',
              settings: settings,
            ),
          ],
        ),
        _Section(
          title: 'Помощь и информация',
          children: [
            ListTile(
              leading: const Icon(LucideIcons.helpCircle),
              title: const Text('Частые вопросы (FAQ)'),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => context.push('/app/faq'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.fileText),
              title: const Text('Юридические документы'),
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: () => context.push('/app/legal'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.messageSquare),
              title: const Text('Написать нам'),
              trailing: Icon(
                _contactVisible
                    ? LucideIcons.chevronUp
                    : LucideIcons.chevronDown,
              ),
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
          ],
        ),
        SizedBox(height: wide ? 24 : 80),
      ],
    );

    return Scaffold(
      backgroundColor: isDark ? OtterColors.darkBg : OtterColors.grayLight,
      body: SafeArea(
        bottom: false,
        child: wide
            ? ResponsiveContent(maxWidth: 960, child: content)
            : content,
      ),
    );
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

  Future<void> _sendContact() async {
    final message = _contactController.text.trim();
    if (message.isEmpty) return;
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

  Future<void> _startTrial() async {
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
  });

  final AuthState auth;
  final bool isDark;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    return Card(
      child: InkWell(
        onTap: () => context.go('/app/profile'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: OtterColors.sberGreen,
                backgroundImage: user?.avatar != null
                    ? NetworkImage(user!.avatar!)
                    : null,
                child: user?.avatar == null
                    ? Text(
                        (user?.name.isNotEmpty == true ? user!.name[0] : 'A')
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user?.name ?? 'Пользователь',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '⭐ ПРЕМИУМ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (user?.email != null)
                      Text(
                        user!.email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: OtterColors.sberGray,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronRight, color: OtterColors.sberGray),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Otter Premium',
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
                            ? Colors.amber.shade50
                            : OtterColors.grayLight,
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
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: OtterColors.sberGray,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _GroupToggle extends ConsumerWidget {
  const _GroupToggle({
    required this.label,
    required this.group,
    required this.settings,
  });

  final String label;
  final String group;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = settings.visibleGroups.contains(group);
    return SwitchListTile(
      title: Text(label),
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
    );
  }
}
