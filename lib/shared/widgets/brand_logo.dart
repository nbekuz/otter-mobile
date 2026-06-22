import 'package:flutter/material.dart';

import '../../core/theme/otter_colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = LogoSize.md,
    this.showName = true,
    this.lightText = false,
  });

  final LogoSize size;
  final bool showName;
  final bool lightText;

  @override
  Widget build(BuildContext context) {
    final dim = switch (size) {
      LogoSize.sm => 36.0,
      LogoSize.md => 44.0,
      LogoSize.lg => 64.0,
    };
    final textSize = switch (size) {
      LogoSize.sm => 18.0,
      LogoSize.md => 20.0,
      LogoSize.lg => 28.0,
    };

    Widget logo = Image.asset(
      'assets/img/logo.png',
      width: dim,
      height: dim,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (lightText) {
      logo = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        child: logo,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size == LogoSize.lg ? 22 : 16),
          child: logo,
        ),
        if (showName) ...[
          const SizedBox(width: 8),
          Text(
            'Otter',
            style: TextStyle(
              fontSize: textSize,
              fontWeight: FontWeight.bold,
              color: lightText ? Colors.white : OtterColors.sberBlack,
            ),
          ),
        ],
      ],
    );
  }
}

enum LogoSize { sm, md, lg }
