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

GoRouter createAppRouter(Ref ref, AuthState auth) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/' ||
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
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/profile-fill',
        builder: (_, __) => const ProfileFillScreen(),
      ),
      GoRoute(
        path: '/legal/:slug',
        builder: (context, state) => StaticLegalScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/app',
            builder: (_, __) => const TasksScreen(),
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
                  initialMatrixBlock:
                      state.uri.queryParameters['matrixBlock'],
                  initialPriority: state.uri.queryParameters['priority'],
                  returnTo: state.uri.queryParameters['returnTo'],
                ),
              ),
              GoRoute(
                path: 'calendar',
                builder: (_, __) => const CalendarScreen(),
              ),
              GoRoute(
                path: 'matrix',
                builder: (_, __) => const MatrixScreen(),
              ),
              GoRoute(
                path: 'pomodoro',
                builder: (_, __) => const PomodoroScreen(),
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
              GoRoute(
                path: 'faq',
                builder: (_, __) => const FaqScreen(),
              ),
              GoRoute(
                path: 'legal',
                builder: (_, __) => const LegalScreen(),
              ),
              GoRoute(
                path: 'profile',
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  return createAppRouter(ref, auth);
});
