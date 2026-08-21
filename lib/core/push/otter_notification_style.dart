import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const otterNotificationSmallIcon = 'ic_notification';
const otterNotificationLargeIcon = 'ic_notification_large';

AndroidNotificationDetails otterAndroidNotificationDetails({
  required String channelId,
  required String channelName,
  String? channelDescription,
  Importance importance = Importance.high,
  Priority priority = Priority.high,
  bool? playSound,
  bool ongoing = false,
  bool autoCancel = true,
  AndroidNotificationCategory? category,
  NotificationVisibility visibility = NotificationVisibility.public,
  bool showWhen = true,
  int? when,
  bool usesChronometer = false,
  bool chronometerCountDown = false,
  bool onlyAlertOnce = false,
  List<AndroidNotificationAction>? actions,
}) {
  return AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: channelDescription,
    icon: otterNotificationSmallIcon,
    largeIcon: const DrawableResourceAndroidBitmap(otterNotificationLargeIcon),
    importance: importance,
    priority: priority,
    playSound: playSound ?? true,
    ongoing: ongoing,
    autoCancel: autoCancel,
    category: category,
    visibility: visibility,
    showWhen: showWhen,
    when: when,
    usesChronometer: usesChronometer,
    chronometerCountDown: chronometerCountDown,
    onlyAlertOnce: onlyAlertOnce,
    actions: actions,
  );
}

const otterAndroidInitSettings = AndroidInitializationSettings(
  '@drawable/ic_notification',
);
