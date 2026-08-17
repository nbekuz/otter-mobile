import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../push/otter_notification_style.dart';

/// Local notifications for Pomodoro (ongoing timer + phase-end alerts).
class PomodoroNotifications {
  PomodoroNotifications();

  static const _channelId = 'pomodoro_timer';
  static const _ongoingId = 71001;
  static const _eventId = 71002;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  bool get _supported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> ensureReady() async {
    if (!_supported || _ready) return;
    const androidInit = otterAndroidInitSettings;
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        'Помодоро',
        description: 'Таймер фокуса и перерывов',
        importance: Importance.high,
      ),
    );
    _ready = true;
  }

  Future<void> showOngoing({
    required String title,
    required String body,
    required DateTime endsAt,
  }) async {
    if (!_supported) return;
    await ensureReady();
    final android = otterAndroidNotificationDetails(
      channelId: _channelId,
      channelName: 'Помодоро',
      channelDescription: 'Таймер фокуса и перерывов',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.progress,
      showWhen: true,
      when: endsAt.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,
      onlyAlertOnce: true,
    );
    await _plugin.show(
      _ongoingId,
      title,
      body,
      NotificationDetails(android: android),
    );
  }

  Future<void> cancelOngoing() async {
    if (!_supported) return;
    await _plugin.cancel(_ongoingId);
  }

  Future<void> showPhaseEnded({
    required String title,
    required String body,
  }) async {
    if (!_supported) return;
    await ensureReady();
    final android = otterAndroidNotificationDetails(
      channelId: _channelId,
      channelName: 'Помодоро',
      channelDescription: 'Таймер фокуса и перерывов',
      category: AndroidNotificationCategory.alarm,
    );
    await _plugin.show(
      _eventId,
      title,
      body,
      NotificationDetails(android: android),
    );
  }
}
