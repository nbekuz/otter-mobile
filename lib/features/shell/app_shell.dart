import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/layout/responsive.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/otter_colors.dart';
import '../../shared/widgets/bottom_nav.dart';
import '../../shared/widgets/brand_logo.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final auth = ref.watch(authStateProvider);
    final isDark = settings.theme == 'dark';
    final path = GoRouterState.of(context).uri.path;
    final wide = Responsive.isWide(context);

    final bg = isDark ? OtterColors.darkBg : OtterColors.grayLight;

    return Theme(
      data: Theme.of(context),
      child: Scaffold(
        backgroundColor: bg,
        // Form routes need raw IME viewInsets so footers can pad above the keyboard.
        resizeToAvoidBottomInset: !_hideBottomNav(path),
        body: wide
            ? Padding(
                // Tight desktop chrome so more content fits the viewport.
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Sidebar(path: path, auth: auth, isDark: isDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isDark ? OtterColors.darkBg : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? OtterColors.darkBorder
                                : const Color(0xFFE9EBF1),
                          ),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A)
                                        .withValues(alpha: 0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Material(
                            color: isDark ? OtterColors.darkBg : Colors.white,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  if (!_hideFab(path))
                    Positioned(
                      right: 16,
                      bottom: 30,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: FloatingActionButton(
                          onPressed: () => context.push(
                            '/app/new-task?returnTo=${Uri.encodeComponent(path)}',
                          ),
                          child: const Icon(LucideIcons.plus, size: 22),
                        ),
                      ),
                    ),
                ],
              ),
        bottomNavigationBar: wide || _hideBottomNav(path)
            ? null
            : OtterBottomNav(order: settings.bottomNavItems, currentPath: path),
      ),
    );
  }

  bool _hideFab(String path) =>
      path.contains('new-task') ||
      path.contains('/profile') ||
      path.endsWith('/settings') ||
      path.contains('/settings?');

  bool _hideBottomNav(String path) =>
      path.contains('new-task') ||
      path.contains('/profile') ||
      path.contains('/notifications/') ||
      path.contains('/faq');
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.path,
    required this.auth,
    required this.isDark,
  });

  final String path;
  final AuthState auth;
  final bool isDark;

  Future<void> _shareApp(BuildContext context) async {
    const url = 'https://ottertime.ru';
    try {
      await Share.share(
        'Оттер — планировщик задач: $url',
        subject: 'Оттер — Планировщик',
      );
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: url));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ссылка скопирована')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final surface = isDark ? OtterColors.darkSurface : Colors.white;
    final byId = {for (final i in kAllNavItems) i.id: i};
    final items = settings.bottomNavItems
        .map((id) => byId[id])
        .whereType<BottomNavItem>()
        .toList();

    return Container(
      width: 268,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
        border: isDark ? Border.all(color: OtterColors.darkBorder) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrandLogo(showName: true, lightText: isDark),
          const SizedBox(height: 8),
          _ProfileCard(
            auth: auth,
            isDark: isDark,
            isPremium: settings.isPremium,
            active: path.startsWith('/app/profile'),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _NavRow(
                      label: item.label,
                      icon: item.icon,
                      active: item.path == '/app'
                          ? path == '/app'
                          : path.startsWith(item.path),
                      isDark: isDark,
                      onTap: () => context.go(item.path),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark
                  ? OtterColors.darkSurfaceAlt
                  : OtterColors.grayLight,
              borderRadius: BorderRadius.circular(16),
              border: isDark
                  ? Border.all(color: const Color(0xFF222833))
                  : null,
            ),
            child: Column(
              children: [
                _PremiumSidebarButton(
                  isDark: isDark,
                  onTap: () => context.push('/app/settings?openPremium=1'),
                ),
                const SizedBox(height: 2),
                _SidebarLink(
                  label: 'FAQ',
                  icon: LucideIcons.helpCircle,
                  active: path == '/app/faq',
                  isDark: isDark,
                  onTap: () => context.go('/app/faq'),
                ),
                const SizedBox(height: 2),
                _SidebarLink(
                  label: 'Рекомендовать друзьям',
                  icon: LucideIcons.share2,
                  active: false,
                  isDark: isDark,
                  onTap: () => _shareApp(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => context.push(
                '/app/new-task?returnTo=${Uri.encodeComponent(path)}',
              ),
              icon: const Icon(LucideIcons.plus, size: 18, color: Colors.white),
              label: const Text(
                'Новая задача',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: OtterColors.sberGreen,
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.label,
    required this.icon,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Colors.white
        : (isDark ? const Color(0xFFCBD5E1) : OtterColors.sberGray);

    return Material(
      color: active ? OtterColors.sberGreen : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      elevation: active ? 1 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumSidebarButton extends StatelessWidget {
  const _PremiumSidebarButton({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0x33F59E0B),
                      const Color(0x1AEAB308),
                      Colors.transparent,
                    ]
                  : [
                      const Color(0xFFFEF3C7),
                      const Color(0xFFFFFBEB),
                      Colors.white,
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? const Color(0x4DFBBF24)
                  : const Color(0xCCFDE68A),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x26FBBF24)
                        : const Color(0x99FDE68A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.crown,
                    size: 16,
                    color: isDark
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Премиум',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: isDark
                          ? const Color(0xFFFCD34D)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarLink extends StatelessWidget {
  const _SidebarLink({
    required this.label,
    required this.icon,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Colors.white
        : (isDark ? const Color(0xFFCBD5E1) : OtterColors.sberGray);

    return Material(
      color: active ? OtterColors.sberGreen : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.auth,
    required this.isDark,
    required this.isPremium,
    required this.active,
  });

  final AuthState auth;
  final bool isDark;
  final bool isPremium;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    return Material(
      color: active
          ? OtterColors.sberGreenLight
          : (isDark ? OtterColors.darkSurfaceAlt : OtterColors.grayLight),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.go('/app/profile'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: OtterColors.sberGreen,
                  border: isPremium
                      ? Border.all(color: const Color(0xFFFACC15), width: 2)
                      : null,
                  image: user?.avatar != null
                      ? DecorationImage(
                          image: NetworkImage(user!.avatar!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: user?.avatar == null
                    ? Text(
                        (user?.name.isNotEmpty == true ? user!.name[0] : 'A')
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user?.name ?? 'Профиль',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? OtterColors.darkText
                                  : OtterColors.sberBlack,
                            ),
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Color(0xFFFBBF24),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      user?.email ?? 'Профиль',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : OtterColors.sberGray,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : OtterColors.grayMid,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
