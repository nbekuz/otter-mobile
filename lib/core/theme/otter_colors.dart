import 'package:flutter/material.dart';

abstract final class OtterColors {
  static const sberGreen = Color(0xFF21A038);
  static const sberGreenLight = Color(0xFFE8F7EB);
  static const sberGreenDark = Color(0xFF1A7F2C);
  static const sberBlue = Color(0xFF007AFF);
  static const sberBlueLight = Color(0xFFE5F1FF);
  static const sberBlack = Color(0xFF1A1A1A);
  static const sberGray = Color(0xFF8E8E93);
  static const grayLight = Color(0xFFF2F2F7);
  static const grayMid = Color(0xFFD1D1D6);

  static const priorityHigh = Color(0xFFFF3B30);
  static const priorityMedium = Color(0xFFFF9500);
  static const priorityLow = Color(0xFF34C759);
  static const priorityNone = Color(0xFFC7C7CC);

  /// Matches otter-app `.dark` tokens in `assets/css/main.css`.
  static const darkBg = Color(0xFF0F1115);
  static const darkSurface = Color(0xFF171A21);
  static const darkSurfaceAlt = Color(0xFF11151B);
  static const darkElevated = Color(0xFF20242D);
  static const darkBorder = Color(0xFF2A303A);
  static const darkText = Color(0xFFF3F4F6);
  static const darkMuted = Color(0xFF9AA3AF);
  static const darkGreenTint = Color(0x2E21A038); // rgba(33,160,56,0.18)
  static const darkGreenTintStrong = Color(0x3821A038); // rgba(33,160,56,0.22)

  static const radiusMd = 16.0;
  static const radiusLg = 24.0;

  static bool isDarkOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color pageBg(bool isDark) => isDark ? darkBg : grayLight;

  static Color surface(bool isDark) => isDark ? darkSurface : Colors.white;

  static Color surfaceAlt(bool isDark) => isDark ? darkSurfaceAlt : grayLight;

  static Color elevated(bool isDark) => isDark ? darkElevated : grayLight;

  static Color border(bool isDark) => isDark ? darkBorder : grayMid;

  static Color text(bool isDark) => isDark ? darkText : sberBlack;

  static Color muted(bool isDark) => isDark ? darkMuted : sberGray;

  static Color greenTint(bool isDark) =>
      isDark ? darkGreenTint : sberGreenLight;

  static Color greenTintStrong(bool isDark) =>
      isDark ? darkGreenTintStrong : sberGreenLight;

  /// Soft accent wash on dark surfaces (Windows / desktop dark mode).
  static Color softTint(bool isDark, Color accent, {Color? light}) {
    if (isDark) {
      return Color.alphaBlend(accent.withValues(alpha: 0.18), darkSurface);
    }
    return light ?? accent.withValues(alpha: 0.12);
  }

  static Color blueTint(bool isDark) =>
      softTint(isDark, sberBlue, light: sberBlueLight);

  static Color dangerSoft(bool isDark) => softTint(
        isDark,
        priorityHigh,
        light: const Color(0xFFFEF2F2),
      );

  static Color warningSoft(bool isDark) => softTint(
        isDark,
        priorityMedium,
        light: const Color(0xFFFFF7E0),
      );

  static Color yellowSoft(bool isDark) => softTint(
        isDark,
        const Color(0xFFFBBF24),
        light: const Color(0xFFFFFBEB),
      );
}
