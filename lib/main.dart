import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/firebase/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  await initializeDateFormatting('ru', null);
  try {
    await FirebaseBootstrap.init();
  } catch (e, st) {
    debugPrint('[FirebaseBootstrap] init failed: $e\n$st');
  }
  runApp(const ProviderScope(child: OtterApp()));
}
