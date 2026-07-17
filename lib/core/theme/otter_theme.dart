import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'otter_colors.dart';

abstract final class OtterTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: OtterColors.grayLight,
      colorScheme: const ColorScheme.light(
        primary: OtterColors.sberGreen,
        secondary: OtterColors.sberBlue,
        surface: Colors.white,
        onSurface: OtterColors.sberBlack,
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: OtterColors.sberBlack,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: OtterColors.sberGreen,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OtterColors.grayLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OtterColors.radiusMd),
          borderSide: const BorderSide(color: OtterColors.grayMid),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OtterColors.radiusMd),
          borderSide: const BorderSide(color: OtterColors.grayMid),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OtterColors.radiusMd),
          borderSide: const BorderSide(color: OtterColors.sberGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OtterColors.radiusMd),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: OtterColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: OtterColors.sberGreen,
        secondary: OtterColors.sberBlue,
        surface: OtterColors.darkSurface,
        onSurface: OtterColors.darkText,
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: OtterColors.darkText,
        displayColor: OtterColors.darkText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: OtterColors.darkBg,
        foregroundColor: OtterColors.darkText,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OtterColors.darkSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OtterColors.radiusMd),
          borderSide: const BorderSide(color: OtterColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OtterColors.radiusMd),
          borderSide: const BorderSide(color: OtterColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OtterColors.radiusMd),
          borderSide: const BorderSide(color: OtterColors.sberGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: OtterColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OtterColors.radiusMd),
        ),
      ),
    );
  }
}
