import 'package:flutter/material.dart';

import '../theme/otter_colors.dart';

/// Inline CTA when a premium-gated screen is blocked by the API.
class PremiumGateBanner extends StatelessWidget {
  const PremiumGateBanner({
    super.key,
    required this.message,
    required this.onConnect,
  });

  final String message;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final isDark = OtterColors.isDarkOf(context);

    return Material(
      color: OtterColors.sberGreen.withValues(alpha: isDark ? 0.14 : 0.1),
      child: InkWell(
        onTap: onConnect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: OtterColors.sberGreen,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OtterColors.text(isDark),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Подключить',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OtterColors.sberGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
