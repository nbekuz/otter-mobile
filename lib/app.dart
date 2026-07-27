import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/locale/app_languages.dart';
import 'core/providers/providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/otter_theme.dart';

class OtterApp extends ConsumerWidget {
  const OtterApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(
      appSettingsProvider.select((s) => s.language),
    );
    final locale = localeFromAppLanguage(language);
    // Only watch bootstrap flag — watching full AuthState remounts the tree
    // on every isLoading flip and dismisses the soft keyboard.
    final isBootstrapping = ref.watch(
      authStateProvider.select((s) => s.isBootstrapping),
    );

    // Bind FCM / local-notification taps → task / notification screens.
    ref.listen(routerProvider, (_, next) {
      final push = ref.read(pushNotificationsProvider);
      push.setOpenTaskHandler((taskId) {
        next.go(
          '/app/new-task?taskId=${Uri.encodeComponent(taskId)}&returnTo=/app',
        );
      });
      push.setOpenNotificationHandler((id) {
        next.go('/app/notifications/$id');
      });
    });
    final push = ref.read(pushNotificationsProvider);
    push.setOpenTaskHandler((taskId) {
      router.go(
        '/app/new-task?taskId=${Uri.encodeComponent(taskId)}&returnTo=/app',
      );
    });
    push.setOpenNotificationHandler((id) {
      router.go('/app/notifications/$id');
    });

    return MaterialApp.router(
      title: 'Оттер',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: kSupportedAppLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child ?? const SizedBox.shrink(),
                if (isBootstrapping)
                  Positioned.fill(
                    child: AbsorbPointer(
                      child: ColoredBox(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      theme: OtterTheme.light(),
      darkTheme: OtterTheme.dark(),
      themeMode: themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
