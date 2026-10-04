import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/otter_colors.dart';
import 'offline_support.dart';
import 'task_outbox.dart';

class OfflineSyncState {
  const OfflineSyncState({
    this.offline = false,
    this.pending = 0,
  });

  final bool offline;
  final int pending;

  bool get showBanner => offline || pending > 0;
}

class OfflineSyncNotifier extends StateNotifier<OfflineSyncState> {
  OfflineSyncNotifier(this._ref) : super(const OfflineSyncState()) {
    onTaskOutboxChanged = () {
      unawaited(noteQueued());
    };
    onNetworkReachabilityChanged = (offline) {
      state = OfflineSyncState(offline: offline, pending: state.pending);
      if (!offline) unawaited(refresh());
    };
    try {
      _sub = Connectivity().onConnectivityChanged.listen((_) {
        unawaited(refresh());
      });
    } catch (_) {}
    unawaited(refresh());
  }

  final Ref _ref;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> noteQueued() async {
    final pending = await TaskOutbox.pendingCount();
    state = OfflineSyncState(offline: state.offline, pending: pending);
  }

  var _pluginOffline = false;

  Future<void> refresh() async {
    var pluginOffline = false;
    var pluginKnown = false;
    try {
      final results = await Connectivity().checkConnectivity();
      pluginKnown = true;
      pluginOffline = results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none);
    } catch (_) {}
    final cameOnline = pluginKnown && _pluginOffline && !pluginOffline;
    if (pluginKnown) _pluginOffline = pluginOffline;

    final pending = await TaskOutbox.pendingCount();
    if (pluginOffline) {
      state = OfflineSyncState(offline: true, pending: pending);
      return;
    }
    if (pending > 0) {
      await _ref.read(tasksStateProvider.notifier).replayOutbox();
      final left = await TaskOutbox.pendingCount();
      state = OfflineSyncState(offline: left > 0, pending: left);
      return;
    }
    // Windows often keeps the adapter "connected" with no internet.
    // Only a successful request, or a real offline-to-online change, clears
    // the banner.
    state = OfflineSyncState(
      offline: cameOnline ? false : state.offline,
      pending: pending,
    );
  }

  @override
  void dispose() {
    if (onTaskOutboxChanged != null) onTaskOutboxChanged = null;
    if (onNetworkReachabilityChanged != null) {
      onNetworkReachabilityChanged = null;
    }
    unawaited(_sub?.cancel());
    super.dispose();
  }
}

final offlineSyncProvider =
    StateNotifierProvider<OfflineSyncNotifier, OfflineSyncState>((ref) {
  return OfflineSyncNotifier(ref);
});

class OfflineStatusBanner extends ConsumerWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(offlineSyncProvider);
    if (!sync.showBanner) return const SizedBox.shrink();
    final isDark = OtterColors.isDarkOf(context);
    final text = sync.offline
        ? (sync.pending > 0
            ? 'Нет сети. Изменения (${sync.pending}) отправятся при подключении.'
            : 'Нет сети. Показаны сохранённые задачи.')
        : 'Есть изменения (${sync.pending}), которые ещё не отправлены на сервер.';
    return Material(
      color: sync.offline
          ? OtterColors.warningSoft(isDark)
          : OtterColors.greenTint(isDark),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: OtterColors.text(isDark),
            ),
          ),
        ),
      ),
    );
  }
}
