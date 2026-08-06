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
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
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
        onPrimary: Colors.white,
        secondary: OtterColors.sberBlue,
        onSecondary: Colors.white,
        surface: OtterColors.darkSurface,
        onSurface: OtterColors.darkText,
        error: OtterColors.priorityHigh,
        onError: Colors.white,
        outline: OtterColors.darkBorder,
      ),
      dividerColor: OtterColors.darkBorder,
      dialogTheme: const DialogThemeData(
        backgroundColor: OtterColors.darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: OtterColors.darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: OtterColors.darkText,
        displayColor: OtterColors.darkText,
      ),
      iconTheme: const IconThemeData(color: OtterColors.darkText),
      primaryIconTheme: const IconThemeData(color: OtterColors.darkText),
      appBarTheme: const AppBarTheme(
        backgroundColor: OtterColors.darkBg,
        foregroundColor: OtterColors.darkText,
        elevation: 0,
        iconTheme: IconThemeData(color: OtterColors.darkText),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: OtterColors.sberGreen,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OtterColors.darkSurfaceAlt,
        hintStyle: const TextStyle(color: OtterColors.darkMuted),
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
      datePickerTheme: DatePickerThemeData(
        backgroundColor: OtterColors.darkSurface,
        headerBackgroundColor: OtterColors.darkElevated,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return OtterColors.darkMuted.withValues(alpha: 0.4);
          }
          if (states.contains(WidgetState.selected)) return Colors.white;
          return OtterColors.darkText;
        }),
        todayForegroundColor: const WidgetStatePropertyAll(OtterColors.sberGreen),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return OtterColors.darkText;
        }),
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: OtterColors.darkSurface,
        hourMinuteTextColor: OtterColors.darkText,
        dialBackgroundColor: OtterColors.darkElevated,
        dialTextColor: OtterColors.darkText,
        dayPeriodTextColor: OtterColors.darkText,
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
