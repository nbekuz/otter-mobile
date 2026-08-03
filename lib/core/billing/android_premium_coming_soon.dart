import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/otter_colors.dart';

/// Exact RuStore-safe copy for Android while store billing is off.
const kAndroidPremiumUnavailableMessage =
    'Подписка станет доступна в одном из следующих обновлений приложения.';

/// Inline Premium placeholder for Android (no tariffs, prices, or checkout UI).
class AndroidPremiumUnavailablePanel extends StatelessWidget {
  const AndroidPremiumUnavailablePanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Оттер Premium',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Icon(
              LucideIcons.crown,
              size: 40,
              color: Colors.amber.shade600,
            ),
            const SizedBox(height: 16),
            const Text(
              kAndroidPremiumUnavailableMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: OtterColors.sberGray,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(onPressed: onClose, child: const Text('Закрыть')),
          ],
        ),
      ),
    );
  }
}
