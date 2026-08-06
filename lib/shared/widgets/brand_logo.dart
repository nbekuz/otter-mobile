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
    // Match web BrandLogo.vue sizes: sm h-9, md h-11, lg h-16.
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
    final radius = size == LogoSize.lg ? 22.0 : 16.0;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    // Same artwork as web (`logo.svg` embeds this PNG). Decode at 2–3×
    // display size so Windows desktop scaling keeps crisp contours.
    final logo = ColorFiltered(
      colorFilter: ColorFilter.mode(
        lightText ? Colors.white : Colors.black,
        BlendMode.srcIn,
      ),
      child: Image.asset(
        'assets/img/logo.png',
        width: dim,
        height: dim,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        cacheWidth: (dim * dpr * 3).round().clamp(128, 1024),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: logo,
        ),
        if (showName) ...[
          const SizedBox(width: 8),
          Text(
            'Оттер',
            style: TextStyle(
              fontSize: textSize,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.3,
              color: lightText ? Colors.white : OtterColors.sberBlack,
            ),
          ),
        ],
      ],
    );
  }
}

enum LogoSize { sm, md, lg }
