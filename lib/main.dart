import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/billing/billing_logger.dart';
import 'core/billing/premium_billing.dart';
import 'core/config/env.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/platform/windows_title_bar.dart';
import 'core/providers/providers.dart';
import 'core/push/push_notifications.dart';
import 'data/services/rustore_billing_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  await initializeDateFormatting('ru', null);

  // Apply saved theme before first frame so Windows title bar + auth
  // scaffolds don't flash light when dark mode is on.
  var initialTheme = 'light';
  try {
    final prefs = await SharedPreferences.getInstance();
    initialTheme = prefs.getString('otter.settings.theme') ?? 'light';
  } catch (_) {}
  await syncWindowsTitleBarTheme(initialTheme == 'dark');

  try {
    await FirebaseBootstrap.init();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e, st) {
    debugPrint('[FirebaseBootstrap] init failed: $e\n$st');
  }
  if (defaultTargetPlatform == TargetPlatform.android &&
      resolvePremiumBillingProvider() == PremiumBillingProvider.rustore) {
    try {
      await RuStoreBillingService().initialize();
    } catch (e, st) {
      BillingLogger.error('Startup billing init failed', e, st);
    }
  }
  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => initialTheme),
      ],
      child: const OtterApp(),
    ),
  );
}
