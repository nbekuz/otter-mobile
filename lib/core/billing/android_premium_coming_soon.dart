import 'package:flutter/material.dart';

import '../theme/otter_colors.dart';

/// Non-blocking sheet shown when the user taps pay on Android
/// while store billing is not yet available.
Future<void> showAndroidPremiumComingSoon(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Подписка скоро будет доступна',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Скоро будет доступно',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: OtterColors.sberGray,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: OtterColors.sberGreen,
                ),
                child: const Text('Понятно'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
