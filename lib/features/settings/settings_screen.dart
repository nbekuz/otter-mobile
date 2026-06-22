import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/layout/responsive.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../data/models/api/api_models.dart';
import '../../data/models/ui/ui_models.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../../shared/widgets/keyboard_dismisser.dart';

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
  List<ApiPremiumFeature> _premiumFeatures = [];
  bool _premiumLoading = false;

  @override
  void initState() {
    super.initState();
    _contactVisible = widget.openContact;
    _premiumVisible = widget.openPremium;
    Future.microtask(() async {
      await ref.read(appSettingsProvider.notifier).load();
      if (widget.openPremium) await _loadPremiumFeatures();
    });
  }

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadPremiumFeatures() async {
    setState(() => _premiumLoading = true);
    try {
      _premiumFeatures =
          await ref.read(settingsServiceProvider).fetchPremiumFeatures();
    } catch (_) {}
    if (mounted) setState(() => _premiumLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final auth = ref.watch(authStateProvider);
    final isDark = settings.theme == 'dark';
    final wide = Responsive.isWide(context);

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
                  child: const Text(
                    'Выйти',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ProfileCard(auth: auth, isDark: isDark, isPremium: settings.isPremium),
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
                    settings.isPremium ? 'Premium активен' : 'Подключить Premium',
                  ),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () async {
                    setState(() => _premiumVisible = true);
                    await _loadPremiumFeatures();
                  },
                ),
              ],
            ),
            if (_premiumVisible) _PremiumPanel(
              features: _premiumFeatures,
              loading: _premiumLoading,
              isPremium: settings.isPremium,
              onClose: () => setState(() => _premiumVisible = false),
              onCheckout: _purchasePremium,
              onActivate: _activatePremium,
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
                  onChanged: (v) => ref.read(appSettingsProvider.notifier).update(
                        settings.copyWith(notifications: v),
                      ),
                ),
                SwitchListTile(
                  title: const Text('Вибрация'),
                  value: settings.vibration,
                  activeThumbColor: OtterColors.sberGreen,
                  onChanged: (v) => ref.read(appSettingsProvider.notifier).update(
                        settings.copyWith(vibration: v),
                      ),
                ),
              ],
            ),
            _Section(
              title: 'Разделы списка задач',
              children: [
                _GroupToggle(label: 'Просрочено', group: 'overdue', settings: settings),
                _GroupToggle(label: 'Сегодня', group: 'today', settings: settings),
                _GroupToggle(label: 'Завтра', group: 'tomorrow', settings: settings),
                _GroupToggle(label: 'Позже', group: 'later', settings: settings),
                _GroupToggle(label: 'Без срока', group: 'nodate', settings: settings),
                _GroupToggle(label: 'Готово', group: 'completed', settings: settings),
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
            ? ResponsiveContent(
                maxWidth: 960,
                child: content,
              )
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
          const SnackBar(
            content: Text('Нужно оставить минимум 2 вкладки'),
          ),
        );
        return;
      }
      items.remove(id);
    }
    if (!items.contains('settings')) items.add('settings');
    ref.read(appSettingsProvider.notifier).update(
          settings.copyWith(bottomNavItems: items),
        );
  }

  Future<void> _sendContact() async {
    final message = _contactController.text.trim();
    if (message.isEmpty) return;
    try {
      await ref.read(settingsServiceProvider).sendHelpMessage(message);
      _contactController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сообщение отправлено')),
        );
        setState(() => _contactVisible = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getApiErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _purchasePremium() async {
    try {
      final url =
          await ref.read(settingsServiceProvider).premiumCheckout('monthly');
      if (!mounted || url.isEmpty) return;
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ссылка на оплату скопирована. После оплаты нажмите «Я оплатил».',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getApiErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _activatePremium() async {
    try {
      final next =
          await ref.read(settingsServiceProvider).activatePremium();
      ref.read(appSettingsProvider.notifier).update(next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium активирован')),
        );
        setState(() => _premiumVisible = false);
      }
    } catch (e) {
      if (mounted) {
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
                backgroundImage:
                    user?.avatar != null ? NetworkImage(user!.avatar!) : null,
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
    required this.features,
    required this.loading,
    required this.isPremium,
    required this.onClose,
    required this.onCheckout,
    required this.onActivate,
  });

  final List<ApiPremiumFeature> features;
  final bool loading;
  final bool isPremium;
  final VoidCallback onClose;
  final VoidCallback onCheckout;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
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
            if (loading)
              const Center(child: CircularProgressIndicator())
            else
              ...features.map(
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
            if (!isPremium) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: onCheckout,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber.shade600,
                ),
                child: const Text('Оплатить 299 ₽/месяц'),
              ),
              TextButton(
                onPressed: onActivate,
                child: const Text('Я оплатил — активировать'),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Premium уже активен',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: OtterColors.sberGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
        ref.read(appSettingsProvider.notifier).update(
              settings.copyWith(visibleGroups: groups),
            );
      },
    );
  }
}
