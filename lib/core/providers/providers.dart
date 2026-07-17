import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../firebase/firebase_bootstrap.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../storage/token_storage.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/calendar_service.dart';
import '../../data/services/matrix_service.dart';
import '../../data/services/pomodoro_service.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/premium_service.dart';
import '../../data/services/sounds_service.dart';
import '../../data/services/tasks_service.dart';
import '../../features/matrix/matrix_block_setting.dart';
import '../../data/mappers/task_mapper.dart';
import '../../data/models/api/api_models.dart';
import '../../data/models/ui/ui_models.dart';
import '../audio/pomodoro_audio.dart';
import '../utils/time_utils.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return ApiClient(storage, () async {
    await ref.read(authStateProvider.notifier).logout();
  });
});

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(apiClientProvider)),
);
final tasksServiceProvider = Provider<TasksService>(
  (ref) => TasksService(ref.watch(apiClientProvider)),
);
final calendarServiceProvider = Provider<CalendarService>(
  (ref) => CalendarService(ref.watch(apiClientProvider)),
);
final matrixServiceProvider = Provider<MatrixService>(
  (ref) => MatrixService(ref.watch(apiClientProvider)),
);
final pomodoroServiceProvider = Provider<PomodoroService>(
  (ref) => PomodoroService(ref.watch(apiClientProvider)),
);
final soundsServiceProvider = Provider<SoundsService>(
  (ref) => SoundsService(ref.watch(apiClientProvider)),
);
final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(ref.watch(apiClientProvider)),
);
final premiumServiceProvider = Provider<PremiumService>(
  (ref) => PremiumService(ref.watch(apiClientProvider)),
);

final premiumStateProvider =
    StateNotifierProvider<PremiumNotifier, PremiumState>((ref) {
      return PremiumNotifier(ref);
    });

enum PremiumPaymentPollingResult {
  success,
  cancelled,
  timeout,
  fatalError,
  stopped,
}

class PremiumState {
  const PremiumState({
    this.tariffs = const [],
    this.features = const [],
    this.subscription,
    this.selectedTariffCode = 'monthly',
    this.loading = false,
    this.actionLoading = false,
    this.error,
    this.paymentPolling = false,
    this.paymentPollingMessage,
  });

  final List<ApiTariff> tariffs;
  final List<ApiPremiumFeature> features;
  final ApiSubscription? subscription;
  final String selectedTariffCode;
  final bool loading;
  final bool actionLoading;
  final String? error;
  final bool paymentPolling;
  final String? paymentPollingMessage;

  ApiTariff? get selectedTariff {
    for (final t in tariffs) {
      if (t.code == selectedTariffCode) return t;
    }
    return tariffs.isEmpty ? null : tariffs.first;
  }

  bool get isPremium {
    final current = subscription;
    return current?.isPremium == true ||
        current?.status.toLowerCase() == 'active';
  }

  PremiumState copyWith({
    List<ApiTariff>? tariffs,
    List<ApiPremiumFeature>? features,
    ApiSubscription? subscription,
    String? selectedTariffCode,
    bool? loading,
    bool? actionLoading,
    String? error,
    bool clearError = false,
    bool? paymentPolling,
    String? paymentPollingMessage,
    bool clearPaymentPollingMessage = false,
  }) => PremiumState(
    tariffs: tariffs ?? this.tariffs,
    features: features ?? this.features,
    subscription: subscription ?? this.subscription,
    selectedTariffCode: selectedTariffCode ?? this.selectedTariffCode,
    loading: loading ?? this.loading,
    actionLoading: actionLoading ?? this.actionLoading,
    error: clearError ? null : (error ?? this.error),
    paymentPolling: paymentPolling ?? this.paymentPolling,
    paymentPollingMessage: clearPaymentPollingMessage
        ? null
        : (paymentPollingMessage ?? this.paymentPollingMessage),
  );
}

class PremiumNotifier extends StateNotifier<PremiumState> {
  PremiumNotifier(this._ref) : super(const PremiumState());

  final Ref _ref;
  Future<PremiumPaymentPollingResult>? _paymentPollingFuture;
  Completer<void>? _paymentPollingCancellation;
  Completer<void>? _paymentPollingWake;
  int _paymentPollingGeneration = 0;

  void _syncPremiumToSettings(ApiSubscription sub) {
    final settings = _ref.read(appSettingsProvider);
    final isPremium = sub.isPremium || sub.status.toLowerCase() == 'active';
    _ref
        .read(appSettingsProvider.notifier)
        .applyLocal(settings.copyWith(isPremium: isPremium));
  }

  Future<void> loadAll() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final service = _ref.read(premiumServiceProvider);
      final results = await Future.wait([
        service.fetchTariffs(),
        service.fetchSubscription(),
        service.fetchFeatures(),
      ]);
      final tariffs = results[0] as List<ApiTariff>;
      final subscription = results[1] as ApiSubscription;
      final features = results[2] as List<ApiPremiumFeature>;
      var selected = state.selectedTariffCode;
      if (!tariffs.any((t) => t.code == selected) && tariffs.isNotEmpty) {
        selected = tariffs.first.code;
      }
      state = state.copyWith(
        tariffs: tariffs,
        subscription: subscription,
        features: features,
        selectedTariffCode: selected,
        loading: false,
      );
      _syncPremiumToSettings(subscription);
    } catch (e) {
      state = state.copyWith(loading: false, error: getApiErrorMessage(e));
    }
  }

  void selectTariff(String code) {
    state = state.copyWith(selectedTariffCode: code);
  }

  Future<ApiSubscription> startTrial({bool recurringConsent = false}) async {
    state = state.copyWith(actionLoading: true, clearError: true);
    try {
      final sub = await _ref
          .read(premiumServiceProvider)
          .startTrial(
            tariff: state.selectedTariff?.code ?? state.selectedTariffCode,
            recurringConsent: recurringConsent,
          );
      state = state.copyWith(subscription: sub, actionLoading: false);
      _syncPremiumToSettings(sub);
      return sub;
    } catch (e) {
      state = state.copyWith(
        actionLoading: false,
        error: getApiErrorMessage(e),
      );
      rethrow;
    }
  }

  Future<String> checkout({bool recurringConsent = false}) async {
    state = state.copyWith(actionLoading: true, clearError: true);
    try {
      final response = await _ref
          .read(premiumServiceProvider)
          .checkout(
            tariff: state.selectedTariff?.code ?? state.selectedTariffCode,
            recurringConsent: recurringConsent,
          );
      state = state.copyWith(actionLoading: false);
      return response.checkoutUrl;
    } catch (e) {
      state = state.copyWith(
        actionLoading: false,
        error: getApiErrorMessage(e),
      );
      rethrow;
    }
  }

  Future<ApiSubscription> refreshSubscription() async {
    state = state.copyWith(actionLoading: true, clearError: true);
    try {
      final sub = await _ref.read(premiumServiceProvider).fetchSubscription();
      state = state.copyWith(subscription: sub, actionLoading: false);
      _syncPremiumToSettings(sub);
      return sub;
    } catch (e) {
      state = state.copyWith(
        actionLoading: false,
        error: getApiErrorMessage(e),
      );
      rethrow;
    }
  }

  Future<PremiumPaymentPollingResult> pollForPayment({
    Duration interval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final activePolling = _paymentPollingFuture;
    if (activePolling != null) return activePolling;

    final generation = ++_paymentPollingGeneration;
    final cancellation = Completer<void>();
    _paymentPollingCancellation = cancellation;
    final polling = _runPaymentPolling(
      generation: generation,
      interval: interval,
      timeout: timeout,
      cancellation: cancellation.future,
    );
    _paymentPollingFuture = polling;

    try {
      return await polling;
    } finally {
      if (identical(_paymentPollingFuture, polling)) {
        _paymentPollingFuture = null;
        _paymentPollingCancellation = null;
        _paymentPollingWake = null;
        state = state.copyWith(
          paymentPolling: false,
          clearPaymentPollingMessage: true,
        );
      }
    }
  }

  void cancelPaymentPolling() {
    _paymentPollingGeneration++;
    final cancellation = _paymentPollingCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
    final wake = _paymentPollingWake;
    if (wake != null && !wake.isCompleted) {
      wake.complete();
    }
    state = state.copyWith(
      paymentPolling: false,
      clearPaymentPollingMessage: true,
    );
  }

  /// Forces an immediate subscription check while Windows polling is active
  /// (for example after the app is restored from minimized state).
  void wakePaymentPolling() {
    if (!state.paymentPolling) return;
    final wake = _paymentPollingWake;
    if (wake != null && !wake.isCompleted) {
      wake.complete();
    }
  }

  Future<PremiumPaymentPollingResult> _runPaymentPolling({
    required int generation,
    required Duration interval,
    required Duration timeout,
    required Future<void> cancellation,
  }) async {
    final stopwatch = Stopwatch()..start();
    var transientFailures = 0;
    final baseline = state.subscription;
    final baselineStatus = baseline?.status.toLowerCase() ?? 'none';
    final baselineIsPremium = baseline?.isPremium == true;

    state = state.copyWith(
      paymentPolling: true,
      paymentPollingMessage: 'Ожидаем подтверждение оплаты…',
      clearError: true,
    );

    while (generation == _paymentPollingGeneration) {
      if (stopwatch.elapsed >= timeout) {
        return PremiumPaymentPollingResult.timeout;
      }

      try {
        final remaining = timeout - stopwatch.elapsed;
        if (remaining <= Duration.zero) {
          return PremiumPaymentPollingResult.timeout;
        }
        final subscription = await _ref
            .read(premiumServiceProvider)
            .fetchSubscription()
            .timeout(remaining);
        if (generation != _paymentPollingGeneration) {
          return PremiumPaymentPollingResult.stopped;
        }

        transientFailures = 0;
        state = state.copyWith(
          subscription: subscription,
          paymentPollingMessage: 'Ожидаем подтверждение оплаты…',
          clearError: true,
        );
        _syncPremiumToSettings(subscription);

        final status = subscription.status.toLowerCase();
        if (_isPaidCheckoutSuccess(
          subscription,
          baselineStatus: baselineStatus,
          baselineIsPremium: baselineIsPremium,
        )) {
          _syncPremiumToSettings(subscription);
          return PremiumPaymentPollingResult.success;
        }
        // Keep waiting while the user still has an existing trial; only stop on
        // terminal statuses that appear after checkout began.
        if (const {
              'cancelled',
              'canceled',
              'failed',
              'expired',
            }.contains(status) &&
            status != baselineStatus) {
          return PremiumPaymentPollingResult.cancelled;
        }

        await _waitForNextAttempt(
          interval,
          stopwatch: stopwatch,
          timeout: timeout,
          cancellation: cancellation,
        );
      } catch (error) {
        if (generation != _paymentPollingGeneration) {
          return PremiumPaymentPollingResult.stopped;
        }
        if (stopwatch.elapsed >= timeout) {
          return PremiumPaymentPollingResult.timeout;
        }
        if (!_isTransientPollingError(error)) {
          state = state.copyWith(error: getApiErrorMessage(error));
          return PremiumPaymentPollingResult.fatalError;
        }

        transientFailures++;
        final retryDelay = _pollingRetryDelay(
          transientFailures,
          baseInterval: interval,
        );
        state = state.copyWith(
          paymentPollingMessage:
              'Нет соединения. Повторная проверка через '
              '${retryDelay.inSeconds} сек…',
        );
        await _waitForNextAttempt(
          retryDelay,
          stopwatch: stopwatch,
          timeout: timeout,
          cancellation: cancellation,
        );
      }
    }

    return PremiumPaymentPollingResult.stopped;
  }

  /// Paid checkout is complete when Robokassa activates a paid subscription.
  /// Existing trial users already have [ApiSubscription.isPremium] == true, so
  /// that alone must not end polling.
  bool _isPaidCheckoutSuccess(
    ApiSubscription current, {
    required String baselineStatus,
    required bool baselineIsPremium,
  }) {
    final status = current.status.toLowerCase();
    if (status == 'active' && status != baselineStatus) return true;
    if (current.isPremium && !baselineIsPremium) return true;
    return false;
  }

  bool _isTransientPollingError(Object error) {
    if (error is! ApiException) return false;
    final status = error.statusCode;
    // 401 is handled by ApiClient JWT refresh; a surviving 401 is fatal.
    if (status == null || status >= 500 || status == 408 || status == 429) {
      return true;
    }
    return false;
  }

  Duration _pollingRetryDelay(
    int failureCount, {
    required Duration baseInterval,
  }) {
    final exponent = (failureCount - 1).clamp(0, 4);
    final seconds = baseInterval.inSeconds * (1 << exponent);
    return Duration(seconds: seconds.clamp(2, 30));
  }

  Future<void> _waitForNextAttempt(
    Duration requestedDelay, {
    required Stopwatch stopwatch,
    required Duration timeout,
    required Future<void> cancellation,
  }) async {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) return;
    final delay = requestedDelay < remaining ? requestedDelay : remaining;
    final wake = Completer<void>();
    _paymentPollingWake = wake;
    try {
      await Future.any<void>([
        Future<void>.delayed(delay),
        cancellation,
        wake.future,
      ]);
    } finally {
      if (identical(_paymentPollingWake, wake)) {
        _paymentPollingWake = null;
      }
    }
  }

  Future<ApiSubscription> cancel() async {
    state = state.copyWith(actionLoading: true, clearError: true);
    try {
      final sub = await _ref.read(premiumServiceProvider).cancel();
      state = state.copyWith(subscription: sub, actionLoading: false);
      _syncPremiumToSettings(sub);
      return sub;
    } catch (e) {
      state = state.copyWith(
        actionLoading: false,
        error: getApiErrorMessage(e),
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    cancelPaymentPolling();
    super.dispose();
  }
}

final themeModeProvider = StateProvider<String>((ref) => 'light');

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
      return AppSettingsNotifier(ref);
    });

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier(this._ref) : super(AppSettings.defaults());

  final Ref _ref;

  Future<void> load() async {
    try {
      final settings = await _ref.read(settingsServiceProvider).fetchSettings();
      state = settings;
    } catch (_) {}
  }

  Future<void> update(AppSettings next) async {
    final prevNotifications = state.notifications;
    state = next;
    try {
      final patched = await _ref
          .read(settingsServiceProvider)
          .patchSettings(next);
      state = patched.copyWith(
        theme: next.theme,
        notifications: next.notifications,
      );
    } catch (_) {
      state = next.copyWith(notifications: prevNotifications);
    }
  }

  void applyLocal(AppSettings next) {
    state = next;
  }

  void setTheme(String theme) {
    state = state.copyWith(theme: theme);
    _ref.read(themeModeProvider.notifier).state = theme;
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.requiresProfileFill = false,
    this.isBootstrapping = false,
  });

  final OtterUser? user;
  final bool isLoading;
  final bool isAuthenticated;
  final bool requiresProfileFill;
  final bool isBootstrapping;

  AuthState copyWith({
    OtterUser? user,
    bool clearUser = false,
    bool? isLoading,
    bool? isAuthenticated,
    bool? requiresProfileFill,
    bool? isBootstrapping,
  }) => AuthState(
    user: clearUser ? null : (user ?? this.user),
    isLoading: isLoading ?? this.isLoading,
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    requiresProfileFill: requiresProfileFill ?? this.requiresProfileFill,
    isBootstrapping: isBootstrapping ?? this.isBootstrapping,
  );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState(isBootstrapping: true)) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    try {
      // Windows credential storage can take an unexpectedly long time on a
      // first run or when its backing store is unavailable. Do not leave the
      // application-wide bootstrap overlay active indefinitely.
      final token = await _ref
          .read(tokenStorageProvider)
          .getAccessToken()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      if (token != null && token.isNotEmpty) {
        await _restoreSession().timeout(const Duration(seconds: 12));
      }
    } catch (_) {
      // Start on the public route when local persistence or the network is
      // unavailable. A later explicit sign-in can still establish a session.
    } finally {
      state = state.copyWith(isBootstrapping: false);
    }
  }

  Future<void> _restoreSession() async {
    try {
      await _loadProfileIntoState();
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        final refreshed = await _ref
            .read(apiClientProvider)
            .refreshAccessToken();
        if (refreshed != null) {
          try {
            await _loadProfileIntoState();
            return;
          } catch (_) {}
        }
        await logout();
        return;
      }
      await _markAuthenticatedFromStoredToken();
    }
  }

  Future<void> _loadProfileIntoState() async {
    final profile = await _ref.read(authServiceProvider).fetchProfile();
    final names = await _ref.read(tokenStorageProvider).getProfileNames();
    final first = names.first.isNotEmpty ? names.first : profile.firstName;
    final last = names.last.isNotEmpty ? names.last : profile.lastName;
    final user = _mapUser(profile, first, last);
    state = AuthState(
      user: user,
      isAuthenticated: true,
      requiresProfileFill: first.trim().isEmpty || last.trim().isEmpty,
      isBootstrapping: false,
    );
  }

  Future<void> _markAuthenticatedFromStoredToken() async {
    final token = await _ref.read(tokenStorageProvider).getAccessToken();
    if (token == null || token.isEmpty) {
      state = const AuthState();
      return;
    }
    final names = await _ref.read(tokenStorageProvider).getProfileNames();
    final fullName = '${names.first} ${names.last}'.trim();
    state = AuthState(
      isAuthenticated: true,
      user: OtterUser(
        id: '',
        email: '',
        name: fullName.isNotEmpty ? fullName : 'Пользователь',
      ),
      requiresProfileFill:
          names.first.trim().isEmpty || names.last.trim().isEmpty,
      isBootstrapping: false,
    );
  }

  Future<void> refreshProfile() async {
    state = state.copyWith(isLoading: true);
    try {
      await _loadProfileIntoState();
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        await logout();
      } else {
        await _markAuthenticatedFromStoredToken();
      }
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  OtterUser _mapUser(BackendUser profile, String first, String last) {
    final fullName = '$first $last'.trim();
    return OtterUser(
      id: profile.id.toString(),
      email: profile.email,
      name: fullName.isNotEmpty ? fullName : profile.email.split('@').first,
      avatar: profile.avatar,
    );
  }

  Future<void> applySession({
    required String access,
    required String refresh,
    required BackendUser backendUser,
  }) async {
    await _ref
        .read(tokenStorageProvider)
        .setTokens(access: access, refresh: refresh);
    await _ref
        .read(tokenStorageProvider)
        .saveProfileNames(backendUser.firstName, backendUser.lastName);
    state = AuthState(
      user: _mapUser(backendUser, backendUser.firstName, backendUser.lastName),
      isAuthenticated: true,
      requiresProfileFill:
          backendUser.firstName.trim().isEmpty ||
          backendUser.lastName.trim().isEmpty,
      isBootstrapping: false,
    );
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final tokens = await _ref
          .read(authServiceProvider)
          .login(email, password);
      await _ref
          .read(tokenStorageProvider)
          .setTokens(access: tokens.access, refresh: tokens.refresh);
      await refreshProfile();
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _ref
          .read(authServiceProvider)
          .register(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
          );
      await applySession(
        access: result.tokens.access,
        refresh: result.tokens.refresh,
        backendUser: result.user,
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loginWithGoogle(String firebaseToken) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _ref
          .read(authServiceProvider)
          .loginWithGoogle(firebaseToken);
      await applySession(
        access: result.tokens.access,
        refresh: result.tokens.refresh,
        backendUser: result.user,
      );
      await refreshProfile();
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> logout() async {
    try {
      await FirebaseBootstrap.signOut();
    } catch (_) {
      // Local/backend logout must still complete if Firebase is unavailable.
    }
    await _ref.read(tokenStorageProvider).clear();
    await _ref.read(tokenStorageProvider).clearProfileNames();
    state = const AuthState();
    _ref.invalidate(tasksStateProvider);
  }
}

final tasksStateProvider = StateNotifierProvider<TasksNotifier, TasksState>((
  ref,
) {
  return TasksNotifier(ref);
});

class TasksState {
  const TasksState({
    this.groups = const {},
    this.loading = false,
    this.error,
    this.searchQuery = '',
    this.searchResults = const [],
  });

  final Map<TaskGroupKey, List<Task>> groups;
  final bool loading;
  final String? error;
  final String searchQuery;
  final List<Task> searchResults;
}

class TasksNotifier extends StateNotifier<TasksState> {
  TasksNotifier(this._ref) : super(const TasksState());

  final Ref _ref;

  Future<void> loadGrouped() async {
    state = TasksState(
      groups: state.groups,
      loading: true,
      searchQuery: state.searchQuery,
      searchResults: state.searchResults,
    );
    try {
      final groups = await _ref.read(tasksServiceProvider).fetchGrouped();
      state = TasksState(
        groups: groups,
        searchQuery: state.searchQuery,
        searchResults: state.searchResults,
      );
    } catch (e) {
      state = TasksState(
        groups: state.groups,
        error: e.toString(),
        searchQuery: state.searchQuery,
        searchResults: state.searchResults,
      );
    }
  }

  Future<void> search(String query) async {
    state = TasksState(
      groups: state.groups,
      searchQuery: query,
      searchResults: state.searchResults,
    );
    if (query.trim().isEmpty) {
      state = TasksState(
        groups: state.groups,
        searchQuery: query,
        searchResults: const [],
      );
      return;
    }
    final results = await _ref.read(tasksServiceProvider).searchTasks(query);
    state = TasksState(
      groups: state.groups,
      searchQuery: query,
      searchResults: results,
    );
  }

  Future<void> completeTask(Task task) async {
    await _ref
        .read(tasksServiceProvider)
        .toggleComplete(task.id, wasCompleted: task.completed);
    await loadGrouped();
  }

  Future<void> deleteTask(String id) async {
    await _ref.read(tasksServiceProvider).deleteTask(id);
    await loadGrouped();
  }

  Future<Task> addTask(PartialTask partial) async {
    final task = await _ref.read(tasksServiceProvider).createTask(partial);
    await loadGrouped();
    return task;
  }

  Task? findTaskById(String id) {
    for (final tasks in state.groups.values) {
      for (final task in tasks) {
        if (task.id == id) return task;
      }
    }
    for (final task in _ref.read(calendarStateProvider).tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Future<Task> updateTask(
    String id,
    PartialTask partial, {
    bool refreshGrouped = true,
  }) async {
    final existing = findTaskById(id);
    if (existing == null) {
      throw StateError('Task $id not found');
    }

    final merged = TaskMapper.mergePartial(existing, partial);
    final payload = TaskMapper.uiToApiPayload(merged);
    debugPrint('[Tasks] PATCH tasks/$id/ payload=$payload');

    final task = await _ref.read(tasksServiceProvider).updateTask(id, merged);
    if (refreshGrouped) {
      await loadGrouped();
    }
    return task;
  }
}

final calendarStateProvider =
    StateNotifierProvider<CalendarNotifier, CalendarUiState>((ref) {
      return CalendarNotifier(ref);
    });

class CalendarUiState {
  const CalendarUiState({
    this.view = CalendarView.day,
    this.date,
    this.tasks = const [],
    this.loading = false,
  });

  final CalendarView view;
  final DateTime? date;
  final List<Task> tasks;
  final bool loading;

  CalendarUiState copyWith({
    CalendarView? view,
    DateTime? date,
    List<Task>? tasks,
    bool? loading,
  }) => CalendarUiState(
    view: view ?? this.view,
    date: date ?? this.date,
    tasks: tasks ?? this.tasks,
    loading: loading ?? this.loading,
  );

  String get displayLabel {
    final d = date ?? DateTime.now();
    switch (view) {
      case CalendarView.day:
        return '${d.day} ${_monthName(d.month)} ${d.year}';
      case CalendarView.week:
        final start = d.subtract(Duration(days: d.weekday - 1));
        final end = start.add(const Duration(days: 6));
        if (start.month == end.month) {
          return '${start.day}–${end.day} ${_monthName(end.month)} ${end.year}';
        }
        return '${start.day} ${_shortMonth(start.month)} – ${end.day} ${_shortMonth(end.month)} ${end.year}';
      case CalendarView.month:
        return '${_monthName(d.month)} ${d.year}';
      case CalendarView.year:
        return '${d.year}';
    }
  }

  static String _monthName(int m) => const [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ][m - 1];

  static String _shortMonth(int m) => const [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ][m - 1];
}

class CalendarNotifier extends StateNotifier<CalendarUiState> {
  CalendarNotifier(this._ref) : super(CalendarUiState(date: DateTime.now()));

  final Ref _ref;

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> load({
    CalendarView? view,
    DateTime? date,
    bool silent = false,
  }) async {
    final v = view ?? state.view;
    final d = date ?? state.date ?? DateTime.now();
    if (!silent) {
      state = state.copyWith(view: v, date: d, loading: true);
    }
    try {
      final tasks = await _ref
          .read(calendarServiceProvider)
          .fetchCalendar(view: v, date: _formatDate(d));
      state = CalendarUiState(view: v, date: d, tasks: tasks);
    } catch (_) {
      if (!silent) {
        state = CalendarUiState(view: v, date: d, tasks: const []);
      }
    }
  }

  void applyTaskUpdate(Task updated) {
    final tasks = state.tasks
        .map((t) => t.id == updated.id ? updated : t)
        .toList(growable: false);
    state = state.copyWith(tasks: tasks);
  }

  void setView(CalendarView view) => load(view: view);

  void goToday() => load(date: DateTime.now());

  void navigate(int step) {
    final d = state.date ?? DateTime.now();
    final next = switch (state.view) {
      CalendarView.day => d.add(Duration(days: step)),
      CalendarView.week => d.add(Duration(days: step * 7)),
      CalendarView.month => DateTime(d.year, d.month + step, d.day),
      CalendarView.year => DateTime(d.year + step, d.month, d.day),
    };
    load(date: next);
  }

  Future<void> rescheduleTask(
    Task task,
    int startMinutes,
    int endMinutes,
  ) async {
    final start = formatMinutesToTime(startMinutes);
    final end = formatMinutesToTime(endMinutes);
    debugPrint('[Calendar] reschedule ${task.id} $start – $end');

    final optimistic = task.copyWith(
      dueTime: start,
      duration: TaskDuration(start: start, end: end),
    );
    applyTaskUpdate(optimistic);

    try {
      final updated = await _ref
          .read(tasksStateProvider.notifier)
          .updateTask(
            task.id,
            PartialTask(
              dueDate: task.dueDate,
              dueTime: start,
              duration: TaskDuration(start: start, end: end),
            ),
            refreshGrouped: false,
          );
      applyTaskUpdate(updated);
    } catch (e) {
      applyTaskUpdate(task);
      rethrow;
    }
  }
}

class MatrixSettingsState {
  const MatrixSettingsState({this.blocks = const {}, this.loading = false});

  final Map<MatrixBlock, MatrixBlockUiSetting> blocks;
  final bool loading;

  MatrixSettingsState copyWith({
    Map<MatrixBlock, MatrixBlockUiSetting>? blocks,
    bool? loading,
  }) => MatrixSettingsState(
    blocks: blocks ?? this.blocks,
    loading: loading ?? this.loading,
  );
}

final matrixSettingsProvider =
    StateNotifierProvider<MatrixSettingsNotifier, MatrixSettingsState>((ref) {
      return MatrixSettingsNotifier(ref);
    });

class MatrixSettingsNotifier extends StateNotifier<MatrixSettingsState> {
  MatrixSettingsNotifier(this._ref)
    : super(MatrixSettingsState(blocks: MatrixBlockUiSetting.defaults()));

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true);
    try {
      final settings = await _ref.read(matrixServiceProvider).fetchSettings();
      final blocks = Map<MatrixBlock, MatrixBlockUiSetting>.from(
        MatrixBlockUiSetting.defaults(),
      );
      for (final item in settings) {
        final ui = MatrixBlockUiSetting.fromApi(item);
        blocks[ui.block] = ui;
      }
      state = MatrixSettingsState(blocks: blocks);
    } catch (_) {
      state = MatrixSettingsState(blocks: MatrixBlockUiSetting.defaults());
    }
  }

  Future<void> saveAll(Map<MatrixBlock, MatrixBlockUiSetting> blocks) async {
    final service = _ref.read(matrixServiceProvider);
    for (final setting in blocks.values) {
      await service.updateSetting(
        block: setting.block.apiValue,
        title: setting.title,
        allowedPriorities: setting.toApiPriorities(),
        dateFilter: setting.toApiDateFilter(),
      );
    }
    state = MatrixSettingsState(blocks: blocks);
    await _ref.read(matrixStateProvider.notifier).load();
  }
}

final matrixStateProvider =
    StateNotifierProvider<MatrixNotifier, Map<String, List<Task>>>((ref) {
      return MatrixNotifier(ref);
    });

class MatrixNotifier extends StateNotifier<Map<String, List<Task>>> {
  MatrixNotifier(this._ref) : super({});

  final Ref _ref;

  Future<void> load() async {
    final data = await _ref.read(matrixServiceProvider).fetchMatrix();
    state = data;
  }

  Future<void> moveTask(String taskId, MatrixBlock block) async {
    await _ref.read(tasksServiceProvider).moveToMatrix(taskId, block);
    await load();
  }
}

final pomodoroStateProvider =
    StateNotifierProvider<PomodoroNotifier, PomodoroUiState>((ref) {
      return PomodoroNotifier(ref);
    });

class PomodoroUiState {
  PomodoroUiState({
    PomodoroSettings? settings,
    this.secondsLeft = 25 * 60,
    this.timerState = 'idle',
    this.selectedTaskId,
    this.activeSessionId,
    this.timerEndSoundDetail,
    this.workSoundDetail,
    this.workBackgroundSounds = const [],
    this.timerEndSounds = const [],
    this.sessionCount = 0,
  }) : settings = settings ?? PomodoroSettings.defaults();

  final PomodoroSettings settings;
  final int secondsLeft;
  final String timerState;
  final String? selectedTaskId;
  final int? activeSessionId;
  final ApiSound? timerEndSoundDetail;
  final ApiSound? workSoundDetail;
  final List<ApiSound> workBackgroundSounds;
  final List<ApiSound> timerEndSounds;
  final int sessionCount;

  double get progress {
    final total = settings.duration * 60;
    if (total <= 0) return 0;
    return 1 - secondsLeft / total;
  }

  PomodoroUiState copyWith({
    PomodoroSettings? settings,
    int? secondsLeft,
    String? timerState,
    String? selectedTaskId,
    int? activeSessionId,
    ApiSound? timerEndSoundDetail,
    ApiSound? workSoundDetail,
    List<ApiSound>? workBackgroundSounds,
    List<ApiSound>? timerEndSounds,
    int? sessionCount,
    bool clearSession = false,
  }) {
    return PomodoroUiState(
      settings: settings ?? this.settings,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      timerState: timerState ?? this.timerState,
      selectedTaskId: selectedTaskId ?? this.selectedTaskId,
      activeSessionId: clearSession
          ? null
          : (activeSessionId ?? this.activeSessionId),
      timerEndSoundDetail: timerEndSoundDetail ?? this.timerEndSoundDetail,
      workSoundDetail: workSoundDetail ?? this.workSoundDetail,
      workBackgroundSounds: workBackgroundSounds ?? this.workBackgroundSounds,
      timerEndSounds: timerEndSounds ?? this.timerEndSounds,
      sessionCount: sessionCount ?? this.sessionCount,
    );
  }
}

class PomodoroNotifier extends StateNotifier<PomodoroUiState> {
  PomodoroNotifier(this._ref) : super(PomodoroUiState()) {
    _audio = PomodoroAudio();
  }

  final Ref _ref;
  late final PomodoroAudio _audio;
  Timer? _ticker;

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> loadAll() async {
    await Future.wait([loadSettings(), loadSounds()]);
  }

  Future<void> loadSettings() async {
    final data = await _ref.read(pomodoroServiceProvider).fetchSettings();
    state = state.copyWith(
      settings: data.settings,
      secondsLeft: state.timerState == 'idle'
          ? data.settings.duration * 60
          : state.secondsLeft,
      timerEndSoundDetail: data.timerEndSoundDetail,
      workSoundDetail: data.workSoundDetail,
    );
  }

  Future<void> loadSounds() async {
    final sounds = await _ref.read(soundsServiceProvider).fetchAll();
    state = state.copyWith(
      workBackgroundSounds: sounds.workBackground,
      timerEndSounds: sounds.timerEnd,
    );
  }

  Future<void> _syncBackgroundAudio() async {
    debugPrint(
      '[Pomodoro] syncBackgroundAudio timer=${state.timerState} '
      'sound=${state.settings.workingSound} '
      'url=${state.workSoundDetail?.audioUrl}',
    );

    if (state.timerState == 'paused') {
      debugPrint('[Pomodoro] timer paused — keep background position');
      return;
    }
    if (state.timerState != 'running') {
      debugPrint('[Pomodoro] timer not running — stop background');
      await _audio.stopBackground();
      return;
    }
    if (state.settings.workingSound == 'none') {
      debugPrint('[Pomodoro] sound=none — stop background');
      await _audio.stopBackground();
      return;
    }
    final url = state.workSoundDetail?.audioUrl;
    if (url != null) {
      await _audio.playBackgroundLoop(url);
    } else {
      debugPrint(
        '[Pomodoro] workSoundDetail has no audioUrl — stop background',
      );
      await _audio.stopBackground();
    }
  }

  Future<void> previewSound(ApiSound sound) async {
    if (sound.key == 'none') {
      debugPrint('[Pomodoro] previewSound skipped (none)');
      return;
    }
    debugPrint(
      '[Pomodoro] previewSound key=${sound.key} url=${sound.audioUrl}',
    );
    await _audio.playOnce(sound.audioUrl);
  }

  Future<void> setWorkSound(ApiSound sound) async {
    final isRunning = state.timerState == 'running';
    final data = await _ref.read(pomodoroServiceProvider).updateSettings({
      'work_sound': sound.key,
    });
    state = state.copyWith(
      settings: data.settings,
      workSoundDetail: data.workSoundDetail ?? sound,
    );
    if (isRunning) {
      await _audio.stopEffect();
      await _syncBackgroundAudio();
    } else {
      await previewSound(sound);
    }
  }

  Future<void> setTimerEndSound(ApiSound sound) async {
    final data = await _ref.read(pomodoroServiceProvider).updateSettings({
      'timer_end_sound': sound.key,
    });
    state = state.copyWith(
      settings: data.settings,
      timerEndSoundDetail: data.timerEndSoundDetail ?? sound,
    );
    await previewSound(sound);
  }

  Future<void> updateSettings({
    int? duration,
    int? shortBreak,
    bool? showOnLockScreen,
  }) async {
    final patch = <String, dynamic>{};
    if (duration != null) patch['duration_minutes'] = duration;
    if (shortBreak != null) patch['short_break_minutes'] = shortBreak;
    if (showOnLockScreen != null) {
      patch['show_on_lock_screen'] = showOnLockScreen;
    }
    if (patch.isEmpty) return;

    final data = await _ref.read(pomodoroServiceProvider).updateSettings(patch);
    state = state.copyWith(
      settings: data.settings,
      secondsLeft: state.timerState == 'idle'
          ? data.settings.duration * 60
          : state.secondsLeft,
      timerEndSoundDetail: data.timerEndSoundDetail,
      workSoundDetail: data.workSoundDetail,
    );
    await _syncBackgroundAudio();
  }

  void selectTask(String? taskId) {
    state = state.copyWith(selectedTaskId: taskId);
  }

  void tick() {
    if (state.timerState != 'running') return;
    if (state.secondsLeft <= 0) return;

    if (state.secondsLeft <= 1) {
      _onTimerComplete();
      return;
    }

    state = state.copyWith(secondsLeft: state.secondsLeft - 1);
  }

  Future<void> _onTimerComplete() async {
    _stopTicker();
    await _audio.stopBackground();
    if (state.settings.sound != 'none') {
      await _audio.playOnce(state.timerEndSoundDetail?.audioUrl);
    }
    final sessionId = state.activeSessionId;
    if (sessionId != null) {
      await _ref
          .read(pomodoroServiceProvider)
          .updateSessionState(sessionId, 'completed');
    }
    state = state.copyWith(
      secondsLeft: state.settings.duration * 60,
      timerState: 'idle',
      sessionCount: state.sessionCount + 1,
      clearSession: true,
    );
  }

  Future<void> start() async {
    if (state.timerState != 'idle' && state.timerState != 'paused') return;

    var sessionId = state.activeSessionId;
    if (sessionId == null) {
      final session = await _ref
          .read(pomodoroServiceProvider)
          .createSession(
            taskId: state.selectedTaskId != null
                ? int.tryParse(state.selectedTaskId!)
                : null,
            durationMinutes: state.settings.duration,
          );
      sessionId = session.id;
    } else {
      await _ref
          .read(pomodoroServiceProvider)
          .updateSessionState(sessionId, 'running');
    }

    state = state.copyWith(
      timerState: 'running',
      activeSessionId: sessionId,
      secondsLeft: state.timerState == 'idle'
          ? state.settings.duration * 60
          : state.secondsLeft,
    );
    _startTicker();
    await _audio.stopEffect();
    await _syncBackgroundAudio();
  }

  Future<void> pause() async {
    if (state.timerState != 'running') return;
    _stopTicker();
    await _audio.pauseBackground();
    if (state.activeSessionId != null) {
      await _ref
          .read(pomodoroServiceProvider)
          .updateSessionState(state.activeSessionId!, 'paused');
    }
    state = state.copyWith(timerState: 'paused');
  }

  Future<void> stop() async {
    _stopTicker();
    await _audio.stopAll();
    if (state.activeSessionId != null) {
      await _ref
          .read(pomodoroServiceProvider)
          .updateSessionState(state.activeSessionId!, 'stopped');
    }
    state = state.copyWith(
      secondsLeft: state.settings.duration * 60,
      timerState: 'idle',
      clearSession: true,
    );
  }

  @override
  void dispose() {
    _stopTicker();
    unawaited(_audio.dispose());
    super.dispose();
  }
}
