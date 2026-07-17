import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/profile_fill_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/onboarding/landing_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/tasks/new_task_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/matrix/matrix_screen.dart';
import '../../features/pomodoro/pomodoro_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/faq/faq_screen.dart';
import '../../features/legal/legal_screen.dart';
import '../../features/legal/static_legal_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

GoRouter createAppRouter(Ref ref, Listenable refreshListenable) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;
      final isAuthRoute =
          loc == '/' ||
          loc == '/login' ||
          loc == '/register' ||
          loc.startsWith('/profile-fill');

      final isPublicLegal = loc.startsWith('/legal/');

      if (auth.isBootstrapping) return null;

      if (!auth.isAuthenticated) {
        if (loc.startsWith('/app')) return '/login';
        if (isPublicLegal) return null;
        return null;
      }

      if (auth.requiresProfileFill && loc != '/profile-fill') {
        return '/profile-fill';
      }

      if (auth.isAuthenticated && isAuthRoute && loc != '/profile-fill') {
        return '/app';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/profile-fill',
        builder: (_, _) => const ProfileFillScreen(),
      ),
      GoRoute(
        path: '/legal/:slug',
        builder: (context, state) =>
            StaticLegalScreen(slug: state.pathParameters['slug']!),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/app',
            builder: (_, _) => const TasksScreen(),
            routes: [
              GoRoute(
                path: 'new-task',
                builder: (context, state) => NewTaskScreen(
                  taskId: state.uri.queryParameters['taskId'],
                  initialDueDate: state.uri.queryParameters['dueDate'],
                  initialDueTime: state.uri.queryParameters['dueTime'],
                  initialDurationStart:
                      state.uri.queryParameters['durationStart'],
                  initialDurationEnd: state.uri.queryParameters['durationEnd'],
                  initialMatrixBlock: state.uri.queryParameters['matrixBlock'],
                  initialPriority: state.uri.queryParameters['priority'],
                  returnTo: state.uri.queryParameters['returnTo'],
                ),
              ),
              GoRoute(
                path: 'calendar',
                builder: (_, _) => const CalendarScreen(),
              ),
              GoRoute(path: 'matrix', builder: (_, _) => const MatrixScreen()),
              GoRoute(
                path: 'pomodoro',
                builder: (_, _) => const PomodoroScreen(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) {
                  final openContact =
                      state.uri.queryParameters['openContact'] == '1';
                  final openPremium =
                      state.uri.queryParameters['openPremium'] == '1';
                  return SettingsScreen(
                    openContact: openContact,
                    openPremium: openPremium,
                  );
                },
              ),
              GoRoute(path: 'faq', builder: (_, _) => const FaqScreen()),
              GoRoute(path: 'legal', builder: (_, _) => const LegalScreen()),
              GoRoute(
                path: 'profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  final router = createAppRouter(ref, refresh);

  ref.listen<AuthState>(
    authStateProvider,
    (previous, next) => refresh.refresh(),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });

  return router;
});
