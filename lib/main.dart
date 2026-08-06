import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/billing/billing_logger.dart';
import 'core/billing/premium_billing.dart';
import 'core/config/env.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/push/push_notifications.dart';
import 'data/services/rustore_billing_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  await initializeDateFormatting('ru', null);
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
  runApp(const ProviderScope(child: OtterApp()));
}
