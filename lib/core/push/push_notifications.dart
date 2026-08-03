import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firebase_options.dart';
import '../../data/services/devices_service.dart';
import '../../data/services/reminders_service.dart';

const _deviceIdKey = 'otter.device_id';
const _deviceDbIdKey = 'otter.fcm.device_db_id';
const _taskRemindersChannelId = 'task_reminders';
const _completeActionId = 'complete';
const _snoozeActionId = 'snooze';

typedef PushTaskReload = Future<void> Function();
typedef PushOpenTask = void Function(String taskId);
typedef PushReminderSound = Future<void> Function();

/// Must be registered from [main] before [runApp].
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e, st) {
    debugPrint('[PushBG] Firebase init failed: $e\n$st');
    return;
  }

  // System tray already shows messages that include a `notification` payload.
  if (message.notification != null) return;

  final title =
      message.data['title']?.toString() ?? 'Оттер — напоминание';
  final body =
      message.data['body']?.toString() ??
      message.data['task_title']?.toString() ??
      '';
  final payload = _pushPayloadFromData(message.data);

  final local = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await local.initialize(
    const InitializationSettings(android: androidInit),
  );

  final androidPlugin = local
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      _taskRemindersChannelId,
      'Напоминания о задачах',
      description: 'Уведомления о сроках задач Оттер',
      importance: Importance.high,
    ),
  );

  final taskId = message.data['task_id']?.toString() ?? '';
  await local.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _taskRemindersChannelId,
        'Напоминания о задачах',
        channelDescription: 'Уведомления о сроках задач Оттер',
        importance: Importance.high,
        priority: Priority.high,
        actions: taskId.isEmpty
            ? null
            : const [
                AndroidNotificationAction(
                  _completeActionId,
                  'Выполнить',
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  _snoozeActionId,
                  'Отложить',
                  showsUserInterface: false,
                ),
              ],
      ),
    ),
    payload: payload,
  );
}

/// Local notification payload: `n:<inboxId>` or bare `task_id`.
String _pushPayloadFromData(Map<String, dynamic> data) {
  final notificationId = data['notification_id']?.toString();
  if (notificationId != null &&
      notificationId.isNotEmpty &&
      notificationId != '0') {
    return 'n:$notificationId';
  }
  return data['task_id']?.toString() ?? '';
}

class PushNotifications {
  PushNotifications({
    required DevicesService devices,
    required RemindersService reminders,
    PushTaskReload? onTasksChanged,
    PushOpenTask? onOpenTask,
    PushReminderSound? onReminderSound,
    PushTaskReload? onInboxChanged,
    void Function(int notificationId)? onOpenNotification,
  })  : _devices = devices,
        _reminders = reminders,
        _onTasksChanged = onTasksChanged,
        _onOpenTask = onOpenTask,
        _onReminderSound = onReminderSound,
        _onInboxChanged = onInboxChanged,
        _onOpenNotification = onOpenNotification;

  final DevicesService _devices;
  final RemindersService _reminders;
  final PushTaskReload? _onTasksChanged;
  PushOpenTask? _onOpenTask;
  final PushReminderSound? _onReminderSound;
  final PushTaskReload? _onInboxChanged;
  void Function(int notificationId)? _onOpenNotification;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  String? _pendingOpenTaskId;
  int? _pendingOpenNotificationId;

  bool get _supported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String get _platformApiValue =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  String get _deviceName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'iPhone' : 'Android';

  void setOpenTaskHandler(PushOpenTask? handler) {
    _onOpenTask = handler;
    final pending = _pendingOpenTaskId;
    if (pending != null && handler != null) {
      _pendingOpenTaskId = null;
      handler(pending);
    }
  }

  void setOpenNotificationHandler(void Function(int id)? handler) {
    _onOpenNotification = handler;
    final pending = _pendingOpenNotificationId;
    if (pending != null && handler != null) {
      _pendingOpenNotificationId = null;
      handler(pending);
    }
  }

  void _openTask(String taskId) {
    if (taskId.isEmpty) return;
    final handler = _onOpenTask;
    if (handler != null) {
      handler(taskId);
    } else {
      _pendingOpenTaskId = taskId;
    }
  }

  void _openNotification(int id) {
    if (id <= 0) return;
    final handler = _onOpenNotification;
    if (handler != null) {
      handler(id);
    } else {
      _pendingOpenNotificationId = id;
    }
  }

  Future<void> init() async {
    if (!_supported || _initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationResponse,
    );

    // Cold start: app opened by tapping a local notification (data-only FCM
    // / poll fallback). Queue via _openTask if navigation handlers are not
    // bound yet — same pending path as FCM getInitialMessage.
    try {
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        final response = launch!.notificationResponse;
        if (response != null) {
          _onLocalNotificationResponse(response);
        }
      }
    } catch (e, st) {
      debugPrint('[PushNotifications] launch details failed: $e\n$st');
    }

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _taskRemindersChannelId,
        'Напоминания о задачах',
        description: 'Уведомления о сроках задач Оттер',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);
    messaging.onTokenRefresh.listen((_) {
      // ignore: discarded_futures
      registerDevice();
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _handleMessageOpen(initial);
    }
  }

  Future<void> registerDevice() async {
    if (!_supported) return;
    try {
      await init();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      final deviceId = await _stableDeviceId();
      final info = await PackageInfo.fromPlatform();
      final id = await _devices.registerDevice(
        token: token,
        deviceId: deviceId,
        platform: _platformApiValue,
        name: _deviceName,
        appVersion: info.version,
      );
      if (id != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_deviceDbIdKey, id);
      }
    } catch (e, st) {
      debugPrint('[PushNotifications] register failed: $e\n$st');
    }
  }

  Future<void> unregisterDevice() async {
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt(_deviceDbIdKey);
      if (id != null) {
        await _devices.deleteDevice(id);
        await prefs.remove(_deviceDbIdKey);
      } else {
        final deviceId = prefs.getString(_deviceIdKey);
        if (deviceId != null) {
          final devices = await _devices.listDevices();
          for (final d in devices) {
            if (d['device_id'] == deviceId && d['id'] is num) {
              await _devices.deleteDevice((d['id'] as num).toInt());
              break;
            }
          }
        }
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e, st) {
      debugPrint('[PushNotifications] unregister failed: $e\n$st');
    }
  }

  Future<String> _stableDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _uuidV4();
    await prefs.setString(_deviceIdKey, created);
    return created;
  }

  String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'Оттер';
    final body =
        message.notification?.body ?? message.data['body']?.toString() ?? '';
    final taskId = message.data['task_id']?.toString() ?? '';
    final payload = _pushPayloadFromData(message.data);

    // Settings «Уведомления»: banner still shows; sound is gated in
    // onReminderSound (provider checks appSettings.notifications).
    // ignore: discarded_futures
    _onReminderSound?.call();
    // ignore: discarded_futures
    _onInboxChanged?.call();

    await _local.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _taskRemindersChannelId,
          'Напоминания о задачах',
          channelDescription: 'Уведомления о сроках задач Оттер',
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
          actions: taskId.isEmpty
              ? null
              : const [
                  AndroidNotificationAction(
                    _completeActionId,
                    'Выполнить',
                    showsUserInterface: true,
                  ),
                  AndroidNotificationAction(
                    _snoozeActionId,
                    'Отложить',
                    showsUserInterface: false,
                  ),
                ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: 'OTTER_TASK_REMINDER',
          presentSound: false,
        ),
      ),
      payload: payload,
    );
  }

  void _handleMessageOpen(RemoteMessage message) {
    final notificationIdRaw = message.data['notification_id']?.toString();
    final notificationId = int.tryParse(notificationIdRaw ?? '');
    if (notificationId != null && notificationId > 0) {
      _openNotification(notificationId);
      return;
    }
    final taskId = message.data['task_id']?.toString();
    if (taskId == null || taskId.isEmpty) return;
    final id = int.tryParse(taskId);
    if (id != null) {
      // ignore: discarded_futures
      _reminders.ack(id).catchError((_) {});
    }
    _openTask(taskId);
  }

  void _onLocalNotificationResponse(NotificationResponse response) {
    final raw = response.payload ?? '';
    if (raw.startsWith('n:')) {
      final inboxId = int.tryParse(raw.substring(2));
      if (inboxId != null && inboxId > 0) {
        _openNotification(inboxId);
      }
      return;
    }

    final taskId = raw;
    final parsed = int.tryParse(taskId);
    switch (response.actionId) {
      case _completeActionId:
        if (parsed == null) return;
        // ignore: discarded_futures
        _reminders.complete(parsed).then((_) async {
          await _onTasksChanged?.call();
        }).catchError((_) {});
      case _snoozeActionId:
        if (parsed == null) return;
        // ignore: discarded_futures
        _reminders.snooze(parsed, minutes: 10).catchError((_) {});
      default:
        if (parsed != null) {
          // ignore: discarded_futures
          _reminders.ack(parsed).catchError((_) {});
        }
        if (taskId.isNotEmpty) _openTask(taskId);
    }
  }

  /// Polling fallback when FCM is unavailable or delayed.
  Future<void> pollDueReminders() async {
    if (!_supported) return;
    try {
      await init();
      final due = await _reminders.due();
      for (final item in due) {
        final taskId = item['task_id'] ?? item['task'] ?? item['id'];
        final id = taskId is int
            ? taskId
            : int.tryParse(taskId?.toString() ?? '');
        if (id == null) continue;
        final title = item['title']?.toString() ?? 'Напоминание о задаче';
        final body = item['body']?.toString() ?? title;
        await _local.show(
          id,
          'Оттер — напоминание',
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _taskRemindersChannelId,
              'Напоминания о задачах',
              channelDescription: 'Уведомления о сроках задач Оттер',
              importance: Importance.high,
              priority: Priority.high,
              actions: const [
                AndroidNotificationAction(
                  _completeActionId,
                  'Выполнить',
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  _snoozeActionId,
                  'Отложить',
                  showsUserInterface: false,
                ),
              ],
            ),
            iOS: const DarwinNotificationDetails(
              categoryIdentifier: 'OTTER_TASK_REMINDER',
            ),
          ),
          payload: id.toString(),
        );
        await _reminders.ack(id);
      }
    } catch (e, st) {
      debugPrint('[PushNotifications] pollDue failed: $e\n$st');
    }
  }
}
