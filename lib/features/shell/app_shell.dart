import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
        body: wide
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Sidebar(path: path, auth: auth, isDark: isDark),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Material(
                          color: isDark ? OtterColors.darkBg : Colors.white,
                          child: child,
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
        bottomNavigationBar: wide
            ? null
            : OtterBottomNav(
                order: settings.bottomNavItems,
                currentPath: path,
              ),
      ),
    );
  }

  bool _hideFab(String path) => path.contains('new-task');
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
      width: 288,
      margin: const EdgeInsets.only(right: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
        border: isDark
            ? Border.all(color: OtterColors.darkBorder)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrandLogo(
            showName: true,
            lightText: isDark,
          ),
          const SizedBox(height: 24),
          _ProfileCard(auth: auth, isDark: isDark),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: items.map((item) {
                final active = item.path == '/app'
                    ? path == '/app'
                    : path.startsWith(item.path);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: active
                        ? OtterColors.sberGreen
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      leading: Icon(
                        item.icon,
                        color: active
                            ? Colors.white
                            : (isDark
                                ? OtterColors.darkText
                                : OtterColors.sberGray),
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : (isDark
                                  ? OtterColors.darkText
                                  : OtterColors.sberGray),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onTap: () => context.go(item.path),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? OtterColors.darkSurfaceAlt : OtterColors.grayLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _SidebarLink(
                  label: 'FAQ',
                  icon: LucideIcons.helpCircle,
                  path: '/app/faq',
                  currentPath: path,
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                _SidebarLink(
                  label: 'Документы',
                  icon: LucideIcons.fileText,
                  path: '/app/legal',
                  currentPath: path,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push('/app/new-task'),
            icon: const Icon(LucideIcons.plus, color: Colors.white),
            label: const Text(
              'Новая задача',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: OtterColors.sberGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLink extends StatelessWidget {
  const _SidebarLink({
    required this.label,
    required this.icon,
    required this.path,
    required this.currentPath,
    required this.isDark,
  });

  final String label;
  final IconData icon;
  final String path;
  final String currentPath;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final active = currentPath == path;
    return Material(
      color: active ? OtterColors.sberGreen : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          size: 20,
          color: active ? Colors.white : OtterColors.sberGray,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: active
                ? Colors.white
                : (isDark ? OtterColors.darkText : OtterColors.sberGray),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => context.go(path),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.auth, required this.isDark});

  final AuthState auth;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    return Material(
      color: isDark ? OtterColors.darkSurfaceAlt : OtterColors.grayLight,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () => context.go('/app/profile'),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
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
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Пользователь',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? OtterColors.darkText : OtterColors.sberBlack,
                      ),
                    ),
                    if (user?.email != null)
                      Text(
                        user!.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: OtterColors.sberGray,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
