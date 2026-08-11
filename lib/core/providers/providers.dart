import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase/firebase_bootstrap.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../storage/token_storage.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/calendar_service.dart';
import '../../data/services/devices_service.dart';
import '../../data/services/matrix_service.dart';
import '../../data/services/pomodoro_service.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/premium_service.dart';
import '../../data/services/rustore_billing_service.dart';
import '../../data/services/reminders_service.dart';
import '../../data/services/sounds_service.dart';
import '../../data/services/tasks_service.dart';
import '../../data/services/notifications_service.dart';
import '../../features/matrix/matrix_block_setting.dart';
import '../../data/mappers/task_mapper.dart';
import '../../data/models/api/api_models.dart';
import '../../data/models/ui/ui_models.dart';
import '../../data/models/billing/billing_purchase.dart';
import '../../data/models/billing/subscription_product.dart';
import '../../data/models/billing/subscription_verify_request.dart';
import '../audio/pomodoro_audio.dart';
import '../audio/pomodoro_notifications.dart';
import '../audio/feedback_audio.dart';
import '../billing/android_premium_coming_soon.dart';
import '../billing/billing_exceptions.dart';
import '../billing/billing_logger.dart';
import '../billing/premium_billing.dart';
import '../billing/rustore_config.dart';
import '../push/push_notifications.dart';
import '../utils/premium_tariffs.dart';
import '../utils/recurrence.dart';
import '../utils/time_utils.dart';
import '../utils/timezone_utils.dart';
import '../locale/app_languages.dart';
import '../platform/windows_title_bar.dart';

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

final feedbackAudioProvider = Provider<FeedbackAudio>((ref) {
  final audio = FeedbackAudio(ref.watch(soundsServiceProvider));
  ref.onDispose(() {
    unawaited(audio.dispose());
  });
  return audio;
});
final settingsServiceProvider = Provider<SettingsService>(
  (ref) => SettingsService(ref.watch(apiClientProvider)),
);
final premiumServiceProvider = Provider<PremiumService>(
  (ref) => PremiumService(ref.watch(apiClientProvider)),
);

final rustoreBillingServiceProvider = Provider<RuStoreBillingService>(
  (ref) => RuStoreBillingService(),
);

bool get isRustoreBillingActive =>
    resolvePremiumBillingProvider() == PremiumBillingProvider.rustore;
final devicesServiceProvider = Provider<DevicesService>(
  (ref) => DevicesService(ref.watch(apiClientProvider)),
);
final remindersServiceProvider = Provider<RemindersService>(
  (ref) => RemindersService(ref.watch(apiClientProvider)),
);
final notificationsServiceProvider = Provider<NotificationsService>(
  (ref) => NotificationsService(ref.watch(apiClientProvider)),
);
final pushNotificationsProvider = Provider<PushNotifications>((ref) {
  return PushNotifications(
    devices: ref.watch(devicesServiceProvider),
    reminders: ref.watch(remindersServiceProvider),
    onTasksChanged: () => ref.read(tasksStateProvider.notifier).loadGrouped(),
    onReminderSound: () async {
      // Foreground: banner always; sound only when settings.notifications.
      final settings = ref.read(appSettingsProvider);
      if (!settings.notifications) return;
      await ref.read(feedbackAudioProvider).playKey(
            'notification',
            settings.notificationSound,
          );
    },
    onInboxChanged: () =>
        ref.read(notificationsInboxProvider.notifier).fetchUnreadCount(),
  );
});

class NotificationsInboxState {
  const NotificationsInboxState({
    this.items = const [],
    this.unreadCount = 0,
    this.loading = false,
    this.error,
  });

  final List<ApiNotificationItem> items;
  final int unreadCount;
  final bool loading;
  final String? error;

  NotificationsInboxState copyWith({
    List<ApiNotificationItem>? items,
    int? unreadCount,
    bool? loading,
    String? error,
    bool clearError = false,
  }) => NotificationsInboxState(
    items: items ?? this.items,
    unreadCount: unreadCount ?? this.unreadCount,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

class NotificationsInboxNotifier
    extends StateNotifier<NotificationsInboxState> {
  NotificationsInboxNotifier(this._ref)
    : super(const NotificationsInboxState());

  final Ref _ref;

  Future<void> fetchUnreadCount() async {
    try {
      final count = await _ref
          .read(notificationsServiceProvider)
          .unreadCount();
      state = state.copyWith(unreadCount: count);
    } catch (_) {}
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _ref.read(notificationsServiceProvider).list();
      state = NotificationsInboxState(
        items: page.results,
        unreadCount: page.unreadCount,
      );
      if (page.unreadCount == 0 && page.results.any((e) => !e.isRead)) {
        await fetchUnreadCount();
      }
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: getApiErrorMessage(e, 'Не удалось загрузить уведомления'),
      );
    }
  }

  Future<void> markRead(int id) async {
    await _ref.read(notificationsServiceProvider).markRead(id);
    final items = state.items.map((n) {
      if (n.id != id || n.isRead) return n;
      return ApiNotificationItem(
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        data: n.data,
        task: n.task,
        isRead: true,
        readAt: DateTime.now().toIso8601String(),
        createdAt: n.createdAt,
      );
    }).toList();
    final wasUnread = state.items.any((n) => n.id == id && !n.isRead);
    state = state.copyWith(
      items: items,
      unreadCount: wasUnread
          ? (state.unreadCount - 1).clamp(0, 1 << 30)
          : state.unreadCount,
    );
  }

  Future<void> markAllRead() async {
    final count = await _ref.read(notificationsServiceProvider).markAllRead();
    state = state.copyWith(
      items: state.items
          .map(
            (n) => ApiNotificationItem(
              id: n.id,
              type: n.type,
              title: n.title,
              body: n.body,
              data: n.data,
              task: n.task,
              isRead: true,
              readAt: n.readAt ?? DateTime.now().toIso8601String(),
              createdAt: n.createdAt,
            ),
          )
          .toList(),
      unreadCount: count,
    );
  }

  Future<void> remove(int id) async {
    await _ref.read(notificationsServiceProvider).delete(id);
    ApiNotificationItem? removed;
    for (final n in state.items) {
      if (n.id == id) {
        removed = n;
        break;
      }
    }
    state = state.copyWith(
      items: state.items.where((n) => n.id != id).toList(),
      unreadCount: removed != null && !removed.isRead
          ? (state.unreadCount - 1).clamp(0, 1 << 30)
          : state.unreadCount,
    );
  }

  /// Deletes multiple notifications (one API call per id) and syncs local inbox.
  Future<void> removeMany(Iterable<int> ids) async {
    final unique = ids.toSet();
    if (unique.isEmpty) return;

    final service = _ref.read(notificationsServiceProvider);
    final results = await Future.wait(
      unique.map((id) async {
        try {
          await service.delete(id);
          return id;
        } catch (_) {
          return null;
        }
      }),
    );
    final deleted = results.whereType<int>().toSet();
    if (deleted.isEmpty) {
      throw Exception('Не удалось удалить уведомления');
    }

    var unreadRemoved = 0;
    for (final n in state.items) {
      if (deleted.contains(n.id) && !n.isRead) unreadRemoved++;
    }
    state = state.copyWith(
      items: state.items.where((n) => !deleted.contains(n.id)).toList(),
      unreadCount: (state.unreadCount - unreadRemoved).clamp(0, 1 << 30),
    );

    if (deleted.length != unique.length) {
      throw Exception(
        'Удалено ${deleted.length} из ${unique.length}. Попробуйте ещё раз.',
      );
    }
  }

  /// GET by id (server auto-marks unread as read) and sync local inbox.
  Future<ApiNotificationItem> fetchById(int id) async {
    final item = await _ref.read(notificationsServiceProvider).getById(id);
    final prev = state.items.where((n) => n.id == id).firstOrNull;
    final others = state.items.where((n) => n.id != id).toList();
    state = state.copyWith(
      items: [item, ...others],
      unreadCount: prev != null && !prev.isRead && item.isRead
          ? (state.unreadCount - 1).clamp(0, 1 << 30)
          : state.unreadCount,
    );
    if (prev == null || (prev.isRead == item.isRead)) {
      await fetchUnreadCount();
    }
    return item;
  }
}

final notificationsInboxProvider =
    StateNotifierProvider<NotificationsInboxNotifier, NotificationsInboxState>((
      ref,
    ) {
      return NotificationsInboxNotifier(ref);
    });

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
    this.subscriptions = const [],
    this.selectedSubscriptionId = RuStoreConfig.monthlyProductId,
    this.loading = false,
    this.actionLoading = false,
    this.purchaseInProgress = false,
    this.error,
    this.purchaseError,
    this.paymentPolling = false,
    this.paymentPollingMessage,
  });

  final List<ApiTariff> tariffs;
  final List<ApiPremiumFeature> features;
  final ApiSubscription? subscription;
  final String selectedTariffCode;
  final List<SubscriptionProduct> subscriptions;
  final String selectedSubscriptionId;
  final bool loading;
  final bool actionLoading;
  final bool purchaseInProgress;
  final String? error;
  final String? purchaseError;
  final bool paymentPolling;
  final String? paymentPollingMessage;

  ApiTariff? get selectedTariff {
    for (final t in tariffs) {
      if (t.code == selectedTariffCode) return t;
    }
    return tariffs.isEmpty ? null : tariffs.first;
  }

  SubscriptionProduct? get selectedSubscription {
    for (final s in subscriptions) {
      if (s.productId == selectedSubscriptionId) return s;
    }
    return subscriptions.isEmpty ? null : subscriptions.first;
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
    List<SubscriptionProduct>? subscriptions,
    String? selectedSubscriptionId,
    bool? loading,
    bool? actionLoading,
    bool? purchaseInProgress,
    String? error,
    bool clearError = false,
    String? purchaseError,
    bool clearPurchaseError = false,
    bool? paymentPolling,
    String? paymentPollingMessage,
    bool clearPaymentPollingMessage = false,
  }) => PremiumState(
    tariffs: tariffs ?? this.tariffs,
    features: features ?? this.features,
    subscription: subscription ?? this.subscription,
    selectedTariffCode: selectedTariffCode ?? this.selectedTariffCode,
    subscriptions: subscriptions ?? this.subscriptions,
    selectedSubscriptionId:
        selectedSubscriptionId ?? this.selectedSubscriptionId,
    loading: loading ?? this.loading,
    actionLoading: actionLoading ?? this.actionLoading,
    purchaseInProgress: purchaseInProgress ?? this.purchaseInProgress,
    error: clearError ? null : (error ?? this.error),
    purchaseError:
        clearPurchaseError ? null : (purchaseError ?? this.purchaseError),
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
    state = state.copyWith(loading: true, clearError: true, clearPurchaseError: true);
    try {
      final service = _ref.read(premiumServiceProvider);
      final results = await Future.wait([
        service.fetchTariffs(),
        service.fetchSubscription(),
        service.fetchFeatures(),
      ]);
      final tariffs = normalizeTariffsForDisplay(
        results[0] as List<ApiTariff>,
      );
      final subscription = results[1] as ApiSubscription;
      final features = results[2] as List<ApiPremiumFeature>;
      var selected = state.selectedTariffCode;
      if (!tariffs.any((t) => t.code == selected) && tariffs.isNotEmpty) {
        selected = tariffs.firstOrNull?.code ?? selected;
      }
      state = state.copyWith(
        tariffs: tariffs,
        subscription: subscription,
        features: features,
        selectedTariffCode: selected,
        selectedSubscriptionId: rustoreProductIdForTariffCode(
          selected,
          tariffs: tariffs,
        ),
        loading: false,
      );
      _syncPremiumToSettings(subscription);

      if (isRustoreBillingActive) {
        await loadStoreSubscriptions();
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: getApiErrorMessage(e));
    }
  }

  Future<void> loadStoreSubscriptions() async {
    if (!isRustoreBillingActive) return;
    try {
      final productIds = rustoreProductIdsFromTariffs(state.tariffs);
      final products = await _ref
          .read(rustoreBillingServiceProvider)
          .getSubscriptions(productIds);
      var selectedId = state.selectedSubscriptionId;
      if (!products.any((p) => p.productId == selectedId) &&
          products.isNotEmpty) {
        selectedId = products.first.productId;
      }
      state = state.copyWith(
        subscriptions: products,
        selectedSubscriptionId: selectedId,
        selectedTariffCode: tariffCodeForRustoreProduct(
          selectedId,
          tariffs: state.tariffs,
        ),
        clearPurchaseError: true,
      );
    } catch (e) {
      BillingLogger.error('loadStoreSubscriptions', e);
      state = state.copyWith(purchaseError: billingErrorMessage(e));
    }
  }

  void selectTariff(String code) {
    state = state.copyWith(
      selectedTariffCode: code,
      selectedSubscriptionId: rustoreProductIdForTariffCode(
        code,
        tariffs: state.tariffs,
      ),
    );
  }

  void selectSubscription(String productId) {
    state = state.copyWith(
      selectedSubscriptionId: productId,
      selectedTariffCode: tariffCodeForRustoreProduct(
        productId,
        tariffs: state.tariffs,
      ),
    );
  }

  Future<ApiSubscription> startTrial({bool recurringConsent = false}) async {
    if (isAndroidPremiumPurchaseBlocked) {
      throw StateError(kAndroidPremiumUnavailableMessage);
    }
    if (isRustoreBillingActive) {
      throw StateError(
        'Пробный период оформляется через подписку в RuStore.',
      );
    }
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
    // Defensive: Android RuStore must never hit Robokassa checkout.
    if (isAndroidPremiumPurchaseBlocked || isRustoreBillingActive) {
      throw StateError(
        isRustoreBillingActive
            ? 'Оплата на Android доступна только через RuStore.'
            : kAndroidPremiumUnavailableMessage,
      );
    }
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

  /// RuStore purchase → backend verify → refresh subscription. Never unlocks locally.
  Future<void> purchaseSelected() async {
    if (!isRustoreBillingActive) {
      throw StateError('RuStore Billing недоступен на этой платформе.');
    }
    final productId = state.selectedSubscription?.productId ??
        state.selectedSubscriptionId;
    final appUserId = _ref.read(authStateProvider).user?.id;
    state = state.copyWith(
      purchaseInProgress: true,
      actionLoading: true,
      clearPurchaseError: true,
      clearError: true,
    );
    try {
      final billing = _ref.read(rustoreBillingServiceProvider);
      final result = await billing.purchase(
        productId,
        appUserId: appUserId,
      );
      if (result.isCancelled) {
        state = state.copyWith(
          purchaseInProgress: false,
          actionLoading: false,
          purchaseError: result.message ??
              const PurchaseCancelledException().message,
        );
        throw PurchaseCancelledException(
          result.message ?? const PurchaseCancelledException().message,
        );
      }
      if (!result.isSuccess) {
        final msg = result.message ?? const BillingUnknownException().message;
        state = state.copyWith(
          purchaseInProgress: false,
          actionLoading: false,
          purchaseError: msg,
        );
        throw BillingUnknownException(msg);
      }

      await _verifyPurchaseResult(result);
      await refreshSubscription();
      state = state.copyWith(
        purchaseInProgress: false,
        actionLoading: false,
        clearPurchaseError: true,
      );
    } on BillingException catch (e) {
      state = state.copyWith(
        purchaseInProgress: false,
        actionLoading: false,
        purchaseError: e.message,
      );
      rethrow;
    } catch (e) {
      final msg = billingErrorMessage(e);
      state = state.copyWith(
        purchaseInProgress: false,
        actionLoading: false,
        purchaseError: msg,
      );
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    if (!isRustoreBillingActive) {
      throw StateError('RuStore Billing недоступен на этой платформе.');
    }
    state = state.copyWith(
      purchaseInProgress: true,
      actionLoading: true,
      clearPurchaseError: true,
      clearError: true,
    );
    BillingLogger.info('Restore purchases (notifier)');
    try {
      final billing = _ref.read(rustoreBillingServiceProvider);
      final active = await billing.restorePurchases();
      if (active.isEmpty) {
        // Backend may still restore by app user / prior purchase.
        await _sendRestore();
        await refreshSubscription();
        if (!state.isPremium) {
          throw const ExpiredSubscriptionException(
            'Активных покупок в RuStore не найдено.',
          );
        }
        state = state.copyWith(
          purchaseInProgress: false,
          actionLoading: false,
        );
        return;
      }

      for (final purchase in active) {
        await _restoreBillingPurchase(purchase);
      }
      await refreshSubscription();
      state = state.copyWith(
        purchaseInProgress: false,
        actionLoading: false,
        clearPurchaseError: true,
      );
      BillingLogger.info('Restore purchases done isPremium=${state.isPremium}');
    } on BillingException catch (e) {
      state = state.copyWith(
        purchaseInProgress: false,
        actionLoading: false,
        purchaseError: e.message,
      );
      rethrow;
    } catch (e) {
      final msg = billingErrorMessage(e);
      state = state.copyWith(
        purchaseInProgress: false,
        actionLoading: false,
        purchaseError: msg,
      );
      rethrow;
    }
  }

  Future<void> _verifyPurchaseResult(PurchaseResult result) async {
    var purchaseId = result.purchaseId?.trim() ?? '';
    var orderId = result.orderId;
    final productId = result.productId ?? state.selectedSubscriptionId;

    if (purchaseId.isEmpty) {
      final purchases =
          await _ref.read(rustoreBillingServiceProvider).getPurchases();
      final match = purchases.cast<BillingPurchase?>().firstWhere(
            (p) =>
                p != null &&
                (p.purchaseId == result.purchaseId ||
                    p.productId == productId) &&
                (p.purchaseId ?? '').trim().isNotEmpty,
            orElse: () => null,
          );
      if (match == null) {
        throw const VerificationFailedException(
          'Не получен purchaseId из RuStore.',
        );
      }
      purchaseId = match.purchaseId!.trim();
      orderId = match.orderId ?? orderId;
    }

    await _sendVerify(
      productId: productId,
      purchaseId: purchaseId,
      orderId: orderId,
    );
  }

  Future<void> _restoreBillingPurchase(BillingPurchase purchase) async {
    final purchaseId = purchase.purchaseId?.trim();
    final productId = purchase.productId;
    if (purchaseId == null ||
        purchaseId.isEmpty ||
        productId == null ||
        productId.isEmpty) {
      throw const VerificationFailedException();
    }
    if (purchase.isExpired) {
      throw const ExpiredSubscriptionException();
    }
    await _sendRestore(
      RustoreVerifyRequest(
        productId: productId,
        purchaseId: purchaseId,
        orderId: purchase.orderId,
        packageName: RuStoreConfig.packageName,
      ),
    );
  }

  Future<void> _sendVerify({
    required String productId,
    required String purchaseId,
    String? orderId,
  }) async {
    BillingLogger.info(
      'Backend verification started productId=$productId '
      'purchaseId=$purchaseId',
    );
    try {
      final response =
          await _ref.read(premiumServiceProvider).verifyRustorePurchase(
                RustoreVerifyRequest(
                  productId: productId,
                  purchaseId: purchaseId,
                  orderId: orderId,
                  packageName: RuStoreConfig.packageName,
                ),
              );
      BillingLogger.info('Backend verification success code=${response.code}');
      if (response.subscription != null) {
        // Apply only after backend confirms — never from SDK alone.
        final sub = await _ref.read(premiumServiceProvider).fetchSubscription();
        state = state.copyWith(subscription: sub);
        _syncPremiumToSettings(sub);
      }
    } on ApiException catch (e) {
      BillingLogger.error('Backend verification failed', e);
      if (e.code == 'ACTIVE_SUBSCRIPTION_EXISTS' || e.statusCode == 409) {
        await refreshSubscription();
      }
      throw VerificationFailedException(e.message);
    } catch (e, st) {
      BillingLogger.error('Backend verification failed', e, st);
      throw VerificationFailedException(billingErrorMessage(e));
    }
  }

  Future<void> _sendRestore([RustoreVerifyRequest? request]) async {
    BillingLogger.info(
      'Backend restore started purchaseId=${request?.purchaseId}',
    );
    try {
      final response = await _ref
          .read(premiumServiceProvider)
          .restoreRustorePurchase(request);
      BillingLogger.info('Backend restore success code=${response.code}');
    } on ApiException catch (e) {
      BillingLogger.error('Backend restore failed', e);
      if (e.code == 'ACTIVE_SUBSCRIPTION_EXISTS' || e.statusCode == 409) {
        return;
      }
      throw VerificationFailedException(e.message);
    } catch (e, st) {
      BillingLogger.error('Backend restore failed', e, st);
      throw VerificationFailedException(billingErrorMessage(e));
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
  AppSettingsNotifier(this._ref) : super(AppSettings.defaults()) {
    unawaited(_hydrateLocalPrefs());
  }

  final Ref _ref;

  static const _themeKey = 'otter.settings.theme';
  static const _notificationsKey = 'otter.settings.notifications';
  static const _languageKey = 'otter.settings.language';
  static const _calendarViewKey = 'otter.settings.calendarDefaultView';
  static const _collapseEarlyKey = 'otter.settings.calendarCollapseEarlyHours';
  static const _collapseLateKey = 'otter.settings.calendarCollapseLateHours';

  Future<void> _hydrateLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString(_themeKey);
      final notifications = prefs.getBool(_notificationsKey);
      final language = prefs.getString(_languageKey);
      final calendarView = prefs.getString(_calendarViewKey);
      final collapseEarly = prefs.getBool(_collapseEarlyKey);
      final collapseLate = prefs.getBool(_collapseLateKey);
      if (theme == null &&
          notifications == null &&
          language == null &&
          calendarView == null &&
          collapseEarly == null &&
          collapseLate == null) {
        return;
      }
      state = state.copyWith(
        theme: theme ?? state.theme,
        notifications: notifications ?? state.notifications,
        language: language != null
            ? normalizeAppLanguage(language)
            : state.language,
        calendarDefaultView: calendarView ?? state.calendarDefaultView,
        calendarCollapseEarlyHours:
            collapseEarly ?? state.calendarCollapseEarlyHours,
        calendarCollapseLateHours:
            collapseLate ?? state.calendarCollapseLateHours,
      );
      if (theme != null) {
        _ref.read(themeModeProvider.notifier).state = theme;
        unawaited(syncWindowsTitleBarTheme(theme == 'dark'));
      }
      // Keep an already-created calendar in sync after prefs hydrate.
      try {
        _ref
            .read(calendarStateProvider.notifier)
            .applyViewDefaultsFromSettings();
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> _persistLocalPrefs(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, settings.theme);
      await prefs.setBool(_notificationsKey, settings.notifications);
      await prefs.setString(
        _languageKey,
        normalizeAppLanguage(settings.language),
      );
      await prefs.setString(_calendarViewKey, settings.calendarDefaultView);
      await prefs.setBool(
        _collapseEarlyKey,
        settings.calendarCollapseEarlyHours,
      );
      await prefs.setBool(
        _collapseLateKey,
        settings.calendarCollapseLateHours,
      );
    } catch (_) {}
  }

  AppSettings _mergeLocal(AppSettings remote) {
    return remote.copyWith(
      theme: state.theme,
      notifications: state.notifications,
      language: normalizeAppLanguage(remote.language),
      calendarDefaultView: state.calendarDefaultView,
      calendarCollapseEarlyHours: state.calendarCollapseEarlyHours,
      calendarCollapseLateHours: state.calendarCollapseLateHours,
    );
  }

  Future<void> load() async {
    try {
      final settings = await _ref.read(settingsServiceProvider).fetchSettings();
      state = _mergeLocal(settings);
      unawaited(_persistLocalPrefs(state));
      await ensureTimezoneSynced();
    } catch (_) {}
  }

  /// Persist device IANA timezone on first open / when empty or stale.
  Future<void> ensureTimezoneSynced() async {
    try {
      final tz = await deviceTimezone();
      if (tz.isEmpty) return;
      if (state.timezone == tz) return;
      final next = state.copyWith(timezone: tz);
      final patched = await _ref
          .read(settingsServiceProvider)
          .patchSettings(next);
      state = _mergeLocal(patched).copyWith(timezone: tz);
    } catch (_) {}
  }

  Future<void> syncPushRegistration() async {
    try {
      await _ref.read(pushNotificationsProvider).registerDevice();
    } catch (_) {}
  }

  Future<void> update(AppSettings next) async {
    final prevNotifications = state.notifications;
    final normalized = next.copyWith(
      language: normalizeAppLanguage(next.language),
    );
    final viewChanged =
        normalized.calendarDefaultView != state.calendarDefaultView ||
            normalized.calendarCollapseEarlyHours !=
                state.calendarCollapseEarlyHours ||
            normalized.calendarCollapseLateHours !=
                state.calendarCollapseLateHours;
    state = normalized;
    unawaited(_persistLocalPrefs(normalized));
    try {
      final patched = await _ref
          .read(settingsServiceProvider)
          .patchSettings(normalized);
      state = _mergeLocal(patched).copyWith(
        theme: normalized.theme,
        notifications: normalized.notifications,
        language: normalizeAppLanguage(
          normalized.language.isNotEmpty
              ? normalized.language
              : patched.language,
        ),
        timezone: normalized.timezone ?? patched.timezone,
        calendarDefaultView: normalized.calendarDefaultView,
        calendarCollapseEarlyHours: normalized.calendarCollapseEarlyHours,
        calendarCollapseLateHours: normalized.calendarCollapseLateHours,
      );
      unawaited(_persistLocalPrefs(state));
      if (viewChanged) {
        _ref.read(calendarStateProvider.notifier).applyViewDefaultsFromSettings();
      }
      _ref.read(themeModeProvider.notifier).state = state.theme;
      unawaited(syncWindowsTitleBarTheme(state.theme == 'dark'));
    } catch (_) {
      state = normalized.copyWith(notifications: prevNotifications);
    }
  }

  void applyLocal(AppSettings next) {
    final viewChanged = next.calendarDefaultView != state.calendarDefaultView ||
        next.calendarCollapseEarlyHours != state.calendarCollapseEarlyHours ||
        next.calendarCollapseLateHours != state.calendarCollapseLateHours;
    state = next;
    unawaited(_persistLocalPrefs(next));
    if (viewChanged) {
      _ref.read(calendarStateProvider.notifier).applyViewDefaultsFromSettings();
    }
  }

  void setTheme(String theme) {
    state = state.copyWith(theme: theme);
    _ref.read(themeModeProvider.notifier).state = theme;
    unawaited(_persistLocalPrefs(state));
    unawaited(syncWindowsTitleBarTheme(theme == 'dark'));
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
    // ignore: discarded_futures
    _postAuthSideEffects();
  }

  Future<void> _postAuthSideEffects() async {
    try {
      await _ref.read(appSettingsProvider.notifier).load();
      await _ref.read(appSettingsProvider.notifier).syncPushRegistration();
      await _ref.read(notificationsInboxProvider.notifier).fetchUnreadCount();
      await _ref.read(pushNotificationsProvider).pollDueReminders();
    } catch (_) {}
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
    // ignore: discarded_futures
    _postAuthSideEffects();
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
    // ignore: discarded_futures
    _postAuthSideEffects();
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
    } catch (e) {
      // Keep unauthenticated; rethrow so UI can show field errors.
      rethrow;
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
    } catch (e) {
      rethrow;
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
      await _ref.read(pushNotificationsProvider).unregisterDevice();
    } catch (_) {}
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

  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true);
    try {
      await _ref.read(authServiceProvider).deleteAccount();
      await logout();
    } finally {
      state = state.copyWith(isLoading: false);
    }
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
      final apiGroups = await _ref.read(tasksServiceProvider).fetchGrouped();
      // Match web `applyGrouped`: flatten + regroup by local calendar date.
      // API buckets alone can lag / use UTC day boundaries after a web create.
      final groups = _regroupLikeWeb(apiGroups, previous: state.groups);
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

  /// Optimistic insert/update into grouped lists (web `upsertTaskInState`).
  void upsertLocalTask(Task task) {
    final next = <TaskGroupKey, List<Task>>{
      for (final e in state.groups.entries)
        e.key: [for (final t in e.value) if (t.id != task.id) t],
    };
    final key = _groupKeyForTask(task);
    next[key] = [task, ...?next[key]];
    state = TasksState(
      groups: next,
      searchQuery: state.searchQuery,
      searchResults: state.searchResults,
    );
  }

  void removeLocalTask(String id) {
    final next = <TaskGroupKey, List<Task>>{
      for (final e in state.groups.entries)
        e.key: [for (final t in e.value) if (t.id != id) t],
    };
    state = TasksState(
      groups: next,
      searchQuery: state.searchQuery,
      searchResults: state.searchResults,
    );
  }

  /// Web `groupTasksByKey` + `preserveImages` after `tasks/grouped/`.
  Map<TaskGroupKey, List<Task>> _regroupLikeWeb(
    Map<TaskGroupKey, List<Task>> apiGroups, {
    required Map<TaskGroupKey, List<Task>> previous,
  }) {
    final prevById = <String, Task>{
      for (final list in previous.values)
        for (final t in list) t.id: t,
    };

    final seen = <String>{};
    final flat = <Task>[];
    for (final list in apiGroups.values) {
      for (final incoming in list) {
        if (!seen.add(incoming.id)) continue;
        flat.add(_preserveTaskFields(incoming, prevById[incoming.id]));
      }
    }

    final next = <TaskGroupKey, List<Task>>{
      for (final key in TaskGroupKey.values) key: <Task>[],
    };
    for (final task in flat) {
      next[_groupKeyForTask(task)]!.add(task);
    }
    return next;
  }

  /// Keep schedule/attachments when grouped payload briefly omits them (web).
  static Task _preserveTaskFields(Task incoming, Task? prev) {
    if (prev == null) return incoming;

    var task = incoming;
    if ((task.dueDate == null || task.dueDate!.isEmpty) &&
        prev.dueDate != null &&
        prev.dueDate!.isNotEmpty) {
      task = task.copyWith(
        dueDate: prev.dueDate,
        dueTime: task.dueTime ?? prev.dueTime,
        duration: task.duration ?? prev.duration,
      );
    }

    final hasImage = (task.imageUrl != null && task.imageUrl!.isNotEmpty) ||
        task.attachments.isNotEmpty;
    if (hasImage) return task;

    final prevCleared = (prev.imageUrl == null || prev.imageUrl!.isEmpty) &&
        prev.attachments.isEmpty;
    if (prevCleared) return task;

    if ((prev.imageUrl != null && prev.imageUrl!.isNotEmpty) ||
        prev.attachments.isNotEmpty) {
      return task.copyWith(
        imageUrl: prev.imageUrl,
        attachments: prev.attachments.isNotEmpty
            ? prev.attachments
            : task.attachments,
      );
    }
    return task;
  }

  /// Local YYYY-MM-DD bucketing — same rules as web `groupTasksByKey`.
  static TaskGroupKey _groupKeyForTask(Task task) {
    if (task.completed) return TaskGroupKey.completed;
    final raw = task.dueDate?.trim() ?? '';
    if (raw.isEmpty) return TaskGroupKey.nodate;
    final due = raw.length >= 10 ? raw.substring(0, 10) : raw;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(due)) {
      return TaskGroupKey.nodate;
    }

    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final tomorrowDate = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    final tomorrow =
        '${tomorrowDate.year.toString().padLeft(4, '0')}-'
        '${tomorrowDate.month.toString().padLeft(2, '0')}-'
        '${tomorrowDate.day.toString().padLeft(2, '0')}';

    if (due.compareTo(today) < 0) return TaskGroupKey.overdue;
    if (due == today) return TaskGroupKey.today;
    if (due == tomorrow) return TaskGroupKey.tomorrow;
    return TaskGroupKey.later;
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

  final Set<String> _completeInFlight = {};

  Future<void> completeTask(Task task) async {
    final realId = resolveRealTaskId(task.id);
    if (_completeInFlight.contains(realId)) return;
    _completeInFlight.add(realId);
    final calendar = _ref.read(calendarStateProvider.notifier);
    final willComplete = !task.completed;
    final optimistic = task.copyWith(
      id: realId,
      completed: willComplete,
      completedAt: willComplete
          ? DateTime.now().toIso8601String().split('T').first
          : null,
    );
    // Instant UI feedback — do not wait for a full calendar reload.
    upsertLocalTask(optimistic);
    calendar.upsertTask(optimistic);
    if (task.id != realId) {
      calendar.applyTaskUpdate(task.copyWith(
        completed: willComplete,
        completedAt: optimistic.completedAt,
      ));
    }

    try {
      final result = await _ref
          .read(tasksServiceProvider)
          .toggleComplete(realId, wasCompleted: task.completed);

      final pinned = TaskMapper.preferClientSchedule(
        result.task,
        PartialTask(
          dueDate: task.dueDate,
          dueTime: task.dueTime,
          duration: task.duration,
        ),
      );
      upsertLocalTask(pinned);
      calendar.upsertTask(pinned);
      if (task.id != realId) {
        calendar.applyTaskUpdate(pinned.copyWith(id: task.id));
      }

      if (willComplete) {
        final settings = _ref.read(appSettingsProvider);
        unawaited(
          _ref.read(feedbackAudioProvider).playKey(
                'completion',
                settings.completionSound,
              ),
        );
        // Backend spawn-on-complete: upsert nested next_task only — never POST.
        if (result.nextTask != null) {
          upsertLocalTask(result.nextTask!);
          calendar.upsertTask(result.nextTask!);
        }
      }

      // Refresh lists silently in the background — skip blocking calendar reload.
      unawaited(loadGrouped());
    } catch (e) {
      upsertLocalTask(task.copyWith(id: realId));
      calendar.upsertTask(task.copyWith(id: realId));
      if (task.id != realId) {
        calendar.applyTaskUpdate(task);
      }
      rethrow;
    } finally {
      _completeInFlight.remove(realId);
    }
  }

  Future<void> deleteTask(String id, {String? scope}) async {
    await _ref.read(tasksServiceProvider).deleteTask(id, scope: scope);
    removeLocalTask(id);
    _ref.read(calendarStateProvider.notifier).removeTask(id);
    await loadGrouped();
    try {
      await _ref.read(calendarStateProvider.notifier).load(silent: true);
    } catch (_) {}
  }

  /// Delete only this occurrence (`scope=this`). Backend owns series continuation.
  Future<void> deleteOccurrence(Task task) async {
    await deleteTask(task.id, scope: 'this');
  }

  Future<void> deleteSeries(String id) async {
    await deleteTask(id, scope: 'series');
  }

  Future<Task> addTask(PartialTask partial) async {
    final created = await _ref.read(tasksServiceProvider).createTask(partial);
    // Prefer the wall-clock we sent — API often echoes UTC (`…Z`).
    final task = TaskMapper.preferClientSchedule(created, partial);
    // Web: upsert into main tasks list immediately so calendar pool sees it.
    upsertLocalTask(task);
    _ref.read(calendarStateProvider.notifier).upsertTask(task);
    try {
      await loadGrouped();
    } catch (_) {}
    // Re-apply if grouped fetch was briefly stale.
    upsertLocalTask(task);
    try {
      await _ref.read(calendarStateProvider.notifier).load(silent: true);
    } catch (_) {}
    // Keep optimistic task if calendar fetch was briefly stale.
    _ref.read(calendarStateProvider.notifier).upsertTask(task);
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
    bool refreshCalendar = true,
    bool refreshMatrix = true,
  }) async {
    var existing = findTaskById(id);
    existing ??= await _ref.read(tasksServiceProvider).fetchTask(id);

    final merged = TaskMapper.mergePartial(existing, partial);
    final payload = TaskMapper.uiToApiPayload(merged);
    debugPrint(
      '[Tasks] PATCH tasks/$id/ '
      'due_at=${payload['due_at']} '
      'start_at=${payload['start_at']} '
      'end_at=${payload['end_at']}',
    );

    final fromApi =
        await _ref.read(tasksServiceProvider).updateTask(id, merged);
    final task = TaskMapper.preferClientSchedule(fromApi, partial);
    upsertLocalTask(task);
    _ref.read(calendarStateProvider.notifier).upsertTask(task);
    if (refreshGrouped) {
      await loadGrouped();
      upsertLocalTask(task);
    }
    // Keep Eisenhower matrix in sync with priority/date changes.
    if (refreshMatrix) {
      try {
        await _ref.read(matrixStateProvider.notifier).load();
      } catch (_) {}
    }
    // Calendar drag/reschedule keeps an optimistic block on screen; a silent
    // refetch here flashes the old slot until the response is merged back.
    if (refreshCalendar) {
      try {
        await _ref.read(calendarStateProvider.notifier).load(silent: true);
      } catch (_) {}
      _ref.read(calendarStateProvider.notifier).upsertTask(task);
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
    this.collapsedEarlyHours = true,
    this.collapsedLateHours = true,
  });

  final CalendarView view;
  final DateTime? date;
  final List<Task> tasks;
  final bool loading;

  /// Matches web: 00:00–06:00 collapsed by default.
  final bool collapsedEarlyHours;

  /// Matches web: 22:00–00:00 collapsed by default.
  final bool collapsedLateHours;

  CalendarUiState copyWith({
    CalendarView? view,
    DateTime? date,
    List<Task>? tasks,
    bool? loading,
    bool? collapsedEarlyHours,
    bool? collapsedLateHours,
  }) => CalendarUiState(
    view: view ?? this.view,
    date: date ?? this.date,
    tasks: tasks ?? this.tasks,
    loading: loading ?? this.loading,
    collapsedEarlyHours: collapsedEarlyHours ?? this.collapsedEarlyHours,
    collapsedLateHours: collapsedLateHours ?? this.collapsedLateHours,
  );

  String get displayLabel {
    final d = date ?? DateTime.now();
    switch (view) {
      case CalendarView.day:
        return '${d.day} ${_monthNameGenitive(d.month)} ${d.year}';
      case CalendarView.week:
        final start = d.subtract(Duration(days: d.weekday - 1));
        final end = start.add(const Duration(days: 6));
        if (start.month == end.month) {
          return '${start.day}–${end.day} ${_monthNameGenitive(end.month)} ${end.year}';
        }
        return '${start.day} ${_shortMonth(start.month)} – ${end.day} ${_shortMonth(end.month)} ${end.year}';
      case CalendarView.month:
        // Nominative month + year — same as web `MMMM YYYY`.
        return '${_monthNameNominative(d.month)} ${d.year}';
      case CalendarView.year:
        return '${d.year}';
    }
  }

  static String _monthNameGenitive(int m) => const [
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

  static String _monthNameNominative(int m) => const [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
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
  CalendarNotifier(this._ref)
      : super(CalendarUiState(date: DateTime.now())) {
    applyViewDefaultsFromSettings();
  }

  final Ref _ref;

  static CalendarView _parseView(String value) => switch (value) {
        'week' => CalendarView.week,
        'month' => CalendarView.month,
        'year' => CalendarView.year,
        _ => CalendarView.day,
      };

  /// Apply Settings → Вид defaults to the open calendar session.
  void applyViewDefaultsFromSettings() {
    final s = _ref.read(appSettingsProvider);
    state = state.copyWith(
      view: _parseView(s.calendarDefaultView),
      collapsedEarlyHours: false,
      collapsedLateHours: false,
    );
  }

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
    const collapsedEarly = false;
    const collapsedLate = false;
    if (!silent) {
      state = state.copyWith(view: v, date: d, loading: true);
    }
    try {
      final fetched = await _ref
          .read(calendarServiceProvider)
          .fetchCalendar(view: v, date: _formatDate(d));
      // Merge like web fetchCalendar: keep prior object when schedule unchanged.
      final prevById = {for (final t in state.tasks) t.id: t};
      final merged = [
        for (final task in fetched)
          if (prevById[task.id] != null &&
              _taskScheduleKey(prevById[task.id]!) == _taskScheduleKey(task))
            prevById[task.id]!
          else
            task,
      ];
      state = CalendarUiState(
        view: v,
        date: d,
        tasks: merged,
        collapsedEarlyHours: collapsedEarly,
        collapsedLateHours: collapsedLate,
      );
    } catch (_) {
      if (!silent) {
        state = CalendarUiState(
          view: v,
          date: d,
          tasks: const [],
          collapsedEarlyHours: collapsedEarly,
          collapsedLateHours: collapsedLate,
        );
      }
    }
  }

  void toggleEarlyHours() {
    /* no-op: full day timeline is always visible */
  }

  void toggleLateHours() {
    /* no-op: full day timeline is always visible */
  }

  static bool _calendarHasEarlyTasks(List<Task> tasks) {
    for (final task in tasks) {
      final start = taskScheduleStart(
        dueTime: task.dueTime,
        durationStart: task.duration?.start,
      );
      if (start == null || start.isEmpty) continue;
      if (parseTimeToMinutes(start) ~/ 60 < 6) return true;
    }
    return false;
  }

  static bool _calendarHasLateTasks(List<Task> tasks) {
    for (final task in tasks) {
      final start = taskScheduleStart(
        dueTime: task.dueTime,
        durationStart: task.duration?.start,
      );
      if (start == null || start.isEmpty) continue;
      final hour = parseTimeToMinutes(start) ~/ 60;
      final endHour = task.duration?.end != null
          ? parseTimeToMinutes(task.duration!.end) ~/ 60
          : hour;
      if (hour >= 21 || endHour >= 21) return true;
    }
    return false;
  }

  static String _taskScheduleKey(Task task) => [
        task.dueDate ?? '',
        task.dueTime ?? '',
        task.duration?.start ?? '',
        task.duration?.end ?? '',
        task.completed ? '1' : '0',
        task.title,
        task.priority.name,
        task.matrixBlock?.name ?? '',
      ].join('|');

  void applyTaskUpdate(Task updated) {
    final tasks = state.tasks
        .map((t) => t.id == updated.id ? updated : t)
        .toList(growable: false);
    state = state.copyWith(tasks: tasks);
  }

  void upsertTask(Task task) {
    final index = state.tasks.indexWhere((t) => t.id == task.id);
    if (index == -1) {
      state = state.copyWith(tasks: [...state.tasks, task]);
    } else {
      final next = [...state.tasks];
      next[index] = task;
      state = state.copyWith(tasks: next);
    }
  }

  void removeTask(String id) {
    state = state.copyWith(
      tasks: [for (final t in state.tasks) if (t.id != id) t],
    );
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
    int endMinutes, {
    String? dueDate,
  }) async {
    final realId = resolveRealTaskId(task.id);
    final start = formatMinutesToTime(startMinutes);
    final end = formatMinutesToTime(endMinutes);
    // Prefer explicit drag target day, then occurrence dueDate, then cache.
    final resolvedDue = (dueDate != null && dueDate.trim().isNotEmpty)
        ? dueDate.trim()
        : (task.dueDate != null && task.dueDate!.trim().isNotEmpty)
            ? task.dueDate!.trim()
            : _ref.read(tasksStateProvider.notifier).findTaskById(realId)?.dueDate;
    debugPrint(
      '[Calendar] reschedule $realId dueDate=$resolvedDue $start – $end',
    );

    final optimistic = task.copyWith(
      id: realId,
      dueDate: resolvedDue ?? task.dueDate,
      dueTime: start,
      duration: TaskDuration(start: start, end: end),
      isAllDay: false,
    );
    applyTaskUpdate(optimistic);
    // Also update any expanded occurrence id in the list.
    if (task.id != realId) {
      removeTask(task.id);
      upsertTask(optimistic);
    }

    try {
      final updated = await _ref
          .read(tasksStateProvider.notifier)
          .updateTask(
            realId,
            PartialTask(
              dueDate: resolvedDue,
              dueTime: start,
              duration: TaskDuration(start: start, end: end),
            ),
            refreshGrouped: false,
            refreshCalendar: false,
            refreshMatrix: false,
          );
      // PATCH response already upserted in updateTask; keep calendar pinned
      // to the saved schedule (covers any parse differences).
      applyTaskUpdate(
        updated.copyWith(
          dueDate: resolvedDue ?? updated.dueDate,
          dueTime: start,
          duration: TaskDuration(start: start, end: end),
          isAllDay: false,
        ),
      );
      _ref.read(tasksStateProvider.notifier).upsertLocalTask(updated);
    } catch (e) {
      applyTaskUpdate(task.copyWith(id: realId));
      rethrow;
    }
  }

  /// Drop onto «Без вр.»: move due date and clear clock (web handleUntimedDayDrop).
  Future<void> moveTaskToUntimed(Task task, String dueDate) async {
    final realId = resolveRealTaskId(task.id);
    final date = dueDate.trim();
    if (date.isEmpty) return;

    final optimistic = Task(
      id: realId,
      title: task.title,
      description: task.description,
      dueDate: date,
      dueTime: null,
      duration: null,
      priority: task.priority,
      completed: task.completed,
      completedAt: task.completedAt,
      notification: task.notification,
      repeat: task.repeat,
      repeatDays: task.repeatDays,
      repeatCustom: task.repeatCustom,
      imageUrl: task.imageUrl,
      attachmentId: task.attachmentId,
      attachmentName: task.attachmentName,
      attachmentMimeType: task.attachmentMimeType,
      attachments: task.attachments,
      isAllDay: true,
      listKey: task.listKey,
      matrixBlock: task.matrixBlock,
      seriesId: task.seriesId,
      parentTaskId: task.parentTaskId,
      createdAt: task.createdAt,
    );
    applyTaskUpdate(optimistic);
    if (task.id != realId) {
      removeTask(task.id);
      upsertTask(optimistic);
    }

    try {
      final updated = await _ref
          .read(tasksStateProvider.notifier)
          .updateTask(
            realId,
            PartialTask(
              dueDate: date,
              clearDueTime: true,
              clearDuration: true,
            ),
            refreshGrouped: false,
            refreshCalendar: false,
            refreshMatrix: false,
          );
      applyTaskUpdate(
        Task(
          id: updated.id,
          title: updated.title,
          description: updated.description,
          dueDate: date,
          dueTime: null,
          duration: null,
          priority: updated.priority,
          completed: updated.completed,
          completedAt: updated.completedAt,
          notification: updated.notification,
          repeat: updated.repeat,
          repeatDays: updated.repeatDays,
          repeatCustom: updated.repeatCustom,
          imageUrl: updated.imageUrl,
          attachmentId: updated.attachmentId,
          attachmentName: updated.attachmentName,
          attachmentMimeType: updated.attachmentMimeType,
          attachments: updated.attachments,
          isAllDay: true,
          listKey: updated.listKey,
          matrixBlock: updated.matrixBlock,
          seriesId: updated.seriesId,
          parentTaskId: updated.parentTaskId,
          createdAt: updated.createdAt,
        ),
      );
      _ref.read(tasksStateProvider.notifier).upsertLocalTask(updated);
    } catch (e) {
      applyTaskUpdate(task.copyWith(id: realId));
      rethrow;
    }
  }

  /// Month drag: change due date only (web handleMonthCellDrop).
  Future<void> moveTaskToDate(Task task, String dueDate) async {
    final realId = resolveRealTaskId(task.id);
    final date = dueDate.trim();
    if (date.isEmpty) return;
    if (task.dueDate == date) return;

    final optimistic = task.copyWith(id: realId, dueDate: date);
    applyTaskUpdate(optimistic);
    if (task.id != realId) {
      removeTask(task.id);
      upsertTask(optimistic);
    }

    try {
      final updated = await _ref
          .read(tasksStateProvider.notifier)
          .updateTask(
            realId,
            PartialTask(dueDate: date),
            refreshGrouped: false,
            refreshCalendar: false,
            refreshMatrix: false,
          );
      applyTaskUpdate(updated.copyWith(dueDate: date));
      _ref.read(tasksStateProvider.notifier).upsertLocalTask(updated);
    } catch (e) {
      applyTaskUpdate(task.copyWith(id: realId));
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
        dateFilters: setting.toApiDateFilters(),
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
    // Web matrix page: fetchGrouped + fetchMatrix, then client-side OR filters.
    var tasksState = _ref.read(tasksStateProvider);
    if (tasksState.groups.isEmpty) {
      await _ref.read(tasksStateProvider.notifier).loadGrouped();
      tasksState = _ref.read(tasksStateProvider);
    }

    Map<String, List<Task>> fromApi = {};
    try {
      fromApi = await _ref.read(matrixServiceProvider).fetchMatrix();
    } catch (_) {
      fromApi = {};
    }

    final settings = _ref.read(matrixSettingsProvider).blocks;
    final groups = tasksState.groups;

    // Unique incomplete tasks (same as web flatten + !completed).
    final seen = <String>{};
    final incomplete = <Task>[];
    for (final list in groups.values) {
      for (final t in list) {
        if (t.completed || !seen.add(t.id)) continue;
        incomplete.add(t);
      }
    }

    final result = <String, List<Task>>{};
    for (final block in MatrixBlock.values) {
      final setting =
          settings[block] ?? MatrixBlockUiSetting.defaults()[block]!;
      result[block.id] = _tasksForBlock(
        block: block,
        incomplete: incomplete,
        groups: groups,
        setting: setting,
        fromApi: fromApi[block.id] ?? const [],
      );
    }
    state = result;
  }

  /// Mirrors web `getTasksForMatrix`.
  List<Task> _tasksForBlock({
    required MatrixBlock block,
    required List<Task> incomplete,
    required Map<TaskGroupKey, List<Task>> groups,
    required MatrixBlockUiSetting setting,
    required List<Task> fromApi,
  }) {
    final hasDateFilters = setting.dateFilters.isNotEmpty;
    final hasPriorityFilters = setting.priorityFilters.isNotEmpty;

    if (hasDateFilters || hasPriorityFilters) {
      final matched = _filterTasksForBlock(incomplete, groups, setting);
      // Web: assigned = incomplete.filter(t => t.matrixBlock === blockId)
      // Do NOT union with matrix/ API lists — those inflate counts vs web.
      final assigned =
          incomplete.where((t) => t.matrixBlock == block).toList();
      final byId = <String, Task>{};
      for (final t in matched) {
        // Drag = move: don't keep a task in this block via filters when it
        // is explicitly assigned to another quadrant.
        if (t.matrixBlock != null && t.matrixBlock != block) continue;
        byId[t.id] = t;
      }
      for (final t in assigned) {
        byId[t.id] = t;
      }
      return byId.values.toList();
    }

    final apiList = fromApi.where((t) => !t.completed).toList();
    if (apiList.isNotEmpty) return apiList;
    return incomplete.where((t) => t.matrixBlock == block).toList();
  }

  List<Task> _filterTasksForBlock(
    List<Task> incomplete,
    Map<TaskGroupKey, List<Task>> groups,
    MatrixBlockUiSetting setting,
  ) {
    final hasDateFilters = setting.dateFilters.isNotEmpty;
    final hasPriorityFilters = setting.priorityFilters.isNotEmpty;

    if (!hasDateFilters && !hasPriorityFilters) {
      return const [];
    }

    final dateMatchedIds = <String>{};
    if (hasDateFilters) {
      for (final key in setting.dateFilters) {
        final groupKey = TaskGroupKeyX.fromApi(
          key == 'nodate' ? 'no_deadline' : key,
        );
        final list = groups[groupKey];
        if (list != null) {
          for (final t in list) {
            if (!t.completed) dateMatchedIds.add(t.id);
          }
        }
      }
    }

    final allowedPriorities = setting.priorityFilters.toSet();

    // Multiple filters are OR: any matching date chip OR any matching priority.
    return incomplete.where((t) {
      final byDate = hasDateFilters && dateMatchedIds.contains(t.id);
      final priority = switch (t.priority) {
        Priority.high => 'high',
        Priority.medium => 'medium',
        Priority.low => 'low',
        Priority.none => 'none',
      };
      final byPriority =
          hasPriorityFilters && allowedPriorities.contains(priority);
      if (hasDateFilters && hasPriorityFilters) return byDate || byPriority;
      if (hasDateFilters) return byDate;
      return byPriority;
    }).toList();
  }

  Future<void> moveTask(String taskId, MatrixBlock block) async {
    // Optimistic: mirror web `upsertTaskInState` before refresh.
    final groups = _ref.read(tasksStateProvider).groups;
    Task? existing;
    for (final list in groups.values) {
      for (final t in list) {
        if (t.id == taskId) {
          existing = t;
          break;
        }
      }
      if (existing != null) break;
    }
    if (existing != null) {
      final moved = existing.copyWith(matrixBlock: block);
      _ref.read(tasksStateProvider.notifier).upsertLocalTask(moved);
      // Instant exclusive move in the grid (remove from all other blocks).
      final next = <String, List<Task>>{
        for (final e in state.entries)
          e.key: [for (final t in e.value) if (t.id != taskId) t],
      };
      next[block.id] = [moved, ...?next[block.id]];
      state = next;
    }

    try {
      final updated =
          await _ref.read(tasksServiceProvider).moveToMatrix(taskId, block);
      _ref.read(tasksStateProvider.notifier).upsertLocalTask(updated);
    } catch (_) {
      if (existing != null) {
        _ref.read(tasksStateProvider.notifier).upsertLocalTask(existing);
      }
      await load();
      rethrow;
    }
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
    this.isBreak = false,
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
  final bool isBreak;

  int get phaseTotalSeconds {
    if (!isBreak) return settings.duration * 60;
    final useLong =
        sessionCount > 0 &&
        sessionCount % settings.sessionsUntilLong == 0;
    return (useLong ? settings.longBreak : settings.shortBreak) * 60;
  }

  double get progress {
    final total = phaseTotalSeconds;
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
    bool? isBreak,
    bool clearSession = false,
    bool clearSelectedTask = false,
  }) {
    return PomodoroUiState(
      settings: settings ?? this.settings,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      timerState: timerState ?? this.timerState,
      selectedTaskId: clearSelectedTask
          ? null
          : (selectedTaskId ?? this.selectedTaskId),
      activeSessionId: clearSession
          ? null
          : (activeSessionId ?? this.activeSessionId),
      timerEndSoundDetail: timerEndSoundDetail ?? this.timerEndSoundDetail,
      workSoundDetail: workSoundDetail ?? this.workSoundDetail,
      workBackgroundSounds: workBackgroundSounds ?? this.workBackgroundSounds,
      timerEndSounds: timerEndSounds ?? this.timerEndSounds,
      sessionCount: sessionCount ?? this.sessionCount,
      isBreak: isBreak ?? this.isBreak,
    );
  }
}

class PomodoroNotifier extends StateNotifier<PomodoroUiState>
    with WidgetsBindingObserver {
  PomodoroNotifier(this._ref) : super(PomodoroUiState()) {
    _audio = PomodoroAudio();
    _notifications = PomodoroNotifications();
    WidgetsBinding.instance.addObserver(this);
  }

  final Ref _ref;
  late final PomodoroAudio _audio;
  late final PomodoroNotifications _notifications;
  Timer? _ticker;
  /// Wall-clock end of the current phase (survives background throttling).
  DateTime? _phaseEndsAt;
  /// Prevents re-entrant phase completion while transitioning work ↔ break.
  bool _phaseCompleting = false;
  bool _appInBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appInBackground = false;
      onAppResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _appInBackground = true;
    }
  }

  /// Reconcile timer after the app returns from background / lock screen.
  void onAppResumed() {
    if (state.timerState != 'running') return;
    syncFromWallClock();
  }

  void _armPhaseDeadline(int seconds) {
    final secs = seconds.clamp(0, 24 * 60 * 60);
    _phaseEndsAt = DateTime.now().add(Duration(seconds: secs));
  }

  void _clearPhaseDeadline() {
    _phaseEndsAt = null;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _syncLockScreenNotification() async {
    if (!state.settings.showOnLockScreen ||
        state.timerState != 'running' ||
        _phaseEndsAt == null) {
      await _notifications.cancelOngoing();
      return;
    }
    final endsAt = _phaseEndsAt!;
    final title = state.isBreak ? 'Перерыв' : 'Фокус';
    final left = endsAt.difference(DateTime.now()).inSeconds.clamp(0, 99999);
    final m = (left ~/ 60).toString().padLeft(2, '0');
    final s = (left % 60).toString().padLeft(2, '0');
    await _notifications.showOngoing(
      title: 'Помодоро — $title',
      body: 'Осталось $m:$s',
      endsAt: endsAt,
    );
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
    await _syncLockScreenNotification();
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
      'break=${state.isBreak} sound=${state.settings.workingSound} '
      'url=${state.workSoundDetail?.audioUrl}',
    );

    if (state.timerState == 'paused') {
      debugPrint('[Pomodoro] timer paused — keep background position');
      return;
    }
    if (state.timerState != 'running' || state.isBreak) {
      debugPrint('[Pomodoro] timer not running / break — stop background');
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
    await _syncLockScreenNotification();
  }

  void selectTask(String? taskId) {
    state = state.copyWith(
      selectedTaskId: taskId,
      clearSelectedTask: taskId == null,
    );
  }

  void tick() {
    if (state.timerState != 'running') return;
    if (_phaseCompleting) return;
    syncFromWallClock();
  }

  /// Align [secondsLeft] to wall clock; complete overdue phases (work→break→idle).
  void syncFromWallClock() {
    if (state.timerState != 'running') return;
    if (_phaseCompleting) return;

    if (_phaseEndsAt == null) {
      _armPhaseDeadline(state.secondsLeft);
    }

    final endsAt = _phaseEndsAt!;
    final remaining = endsAt.difference(DateTime.now()).inSeconds;
    if (remaining > 0) {
      if (remaining != state.secondsLeft) {
        state = state.copyWith(secondsLeft: remaining);
      }
      return;
    }

    // Phase ended at [endsAt] (may be in the past if we were backgrounded).
    _onPhaseComplete(endedAt: endsAt);
  }

  /// Port of otter-app `onPhaseComplete`.
  ///
  /// [endedAt] is the wall-clock moment the previous phase finished — used so
  /// break time accounts for time spent in the background.
  void _onPhaseComplete({DateTime? endedAt}) {
    if (_phaseCompleting) return;
    if (state.timerState != 'running') return;
    _phaseCompleting = true;

    final wasBreak = state.isBreak;
    final sessionId = state.activeSessionId;
    final settings = state.settings;
    final endSoundUrl = state.timerEndSoundDetail?.audioUrl;
    final playEndSound = settings.sound != 'none';
    final phaseEndedAt = endedAt ?? DateTime.now();
    final notifyLock = settings.showOnLockScreen || _appInBackground;

    try {
      if (!wasBreak) {
        // Work → auto-start break (keep ticker running, like web).
        final nextCount = state.sessionCount + 1;
        final useLong =
            nextCount > 0 && nextCount % settings.sessionsUntilLong == 0;
        final breakMinutes =
            useLong ? settings.longBreak : settings.shortBreak;
        final breakEndsAt =
            phaseEndedAt.add(Duration(minutes: breakMinutes));
        final left = breakEndsAt.difference(DateTime.now()).inSeconds;

        if (left <= 0) {
          // Break also finished while away → idle.
          _stopTicker();
          _clearPhaseDeadline();
          state = state.copyWith(
            sessionCount: nextCount,
            isBreak: false,
            secondsLeft: settings.duration * 60,
            timerState: 'idle',
            clearSession: true,
          );
          unawaited(_notifications.cancelOngoing());
          if (notifyLock) {
            unawaited(
              _notifications.showPhaseEnded(
                title: 'Помодоро',
                body: 'Фокус и перерыв завершены',
              ),
            );
          }
          unawaited(
            _afterWorkPhaseComplete(
              sessionId: sessionId,
              playEndSound: playEndSound,
              endSoundUrl: endSoundUrl,
            ),
          );
          return;
        }

        _phaseEndsAt = breakEndsAt;
        state = state.copyWith(
          sessionCount: nextCount,
          isBreak: true,
          secondsLeft: left,
          timerState: 'running',
          clearSession: true,
        );

        if (notifyLock) {
          unawaited(
            _notifications.showPhaseEnded(
              title: 'Фокус завершён',
              body: useLong
                  ? 'Начался длинный перерыв ($breakMinutes мин)'
                  : 'Начался короткий перерыв ($breakMinutes мин)',
            ),
          );
        }
        unawaited(_syncLockScreenNotification());

        unawaited(
          _afterWorkPhaseComplete(
            sessionId: sessionId,
            playEndSound: playEndSound,
            endSoundUrl: endSoundUrl,
          ),
        );
        return;
      }

      // Break → idle work duration.
      _stopTicker();
      _clearPhaseDeadline();
      state = state.copyWith(
        isBreak: false,
        secondsLeft: settings.duration * 60,
        timerState: 'idle',
        clearSession: true,
      );
      unawaited(_notifications.cancelOngoing());
      if (notifyLock) {
        unawaited(
          _notifications.showPhaseEnded(
            title: 'Перерыв завершён',
            body: 'Можно начать следующий фокус',
          ),
        );
      }
      unawaited(
        _afterBreakPhaseComplete(
          playEndSound: playEndSound,
          endSoundUrl: endSoundUrl,
        ),
      );
    } finally {
      _phaseCompleting = false;
    }
  }

  Future<void> _afterWorkPhaseComplete({
    required int? sessionId,
    required bool playEndSound,
    required String? endSoundUrl,
  }) async {
    try {
      await _audio.stopBackground();
      if (playEndSound) {
        await _audio.playOnce(endSoundUrl);
      }
    } catch (_) {}
    if (sessionId != null) {
      try {
        await _ref
            .read(pomodoroServiceProvider)
            .updateSessionState(sessionId, 'completed');
      } catch (_) {}
    }
    try {
      await _syncBackgroundAudio();
    } catch (_) {}
  }

  Future<void> _afterBreakPhaseComplete({
    required bool playEndSound,
    required String? endSoundUrl,
  }) async {
    try {
      await _audio.stopBackground();
      if (playEndSound) {
        await _audio.playOnce(endSoundUrl);
      }
    } catch (_) {}
  }

  Future<void> start() async {
    if (state.timerState != 'idle' && state.timerState != 'paused') return;

    // Break resume: just continue ticking (no API work session).
    if (state.isBreak) {
      _armPhaseDeadline(state.secondsLeft);
      state = state.copyWith(timerState: 'running');
      _startTicker();
      await _audio.stopEffect();
      await _syncBackgroundAudio();
      await _syncLockScreenNotification();
      return;
    }

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

    final nextSeconds = state.timerState == 'idle'
        ? state.settings.duration * 60
        : state.secondsLeft;
    _armPhaseDeadline(nextSeconds);
    state = state.copyWith(
      timerState: 'running',
      activeSessionId: sessionId,
      isBreak: false,
      secondsLeft: nextSeconds,
    );
    _startTicker();
    await _audio.stopEffect();
    await _syncBackgroundAudio();
    await _syncLockScreenNotification();
  }

  Future<void> pause() async {
    if (state.timerState != 'running') return;
    // Freeze remaining time from wall clock before pausing.
    syncFromWallClock();
    if (state.timerState != 'running') return;

    _stopTicker();
    _clearPhaseDeadline();
    await _audio.pauseBackground();
    await _notifications.cancelOngoing();
    if (!state.isBreak && state.activeSessionId != null) {
      await _ref
          .read(pomodoroServiceProvider)
          .updateSessionState(state.activeSessionId!, 'paused');
    }
    state = state.copyWith(timerState: 'paused');
  }

  Future<void> stop() async {
    _stopTicker();
    _clearPhaseDeadline();
    await _audio.stopAll();
    await _notifications.cancelOngoing();
    if (!state.isBreak && state.activeSessionId != null) {
      await _ref
          .read(pomodoroServiceProvider)
          .updateSessionState(state.activeSessionId!, 'stopped');
    }
    state = state.copyWith(
      secondsLeft: state.settings.duration * 60,
      timerState: 'idle',
      isBreak: false,
      clearSession: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker();
    _clearPhaseDeadline();
    unawaited(_notifications.cancelOngoing());
    unawaited(_audio.dispose());
    super.dispose();
  }
}

