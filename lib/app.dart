import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const appPaper     = Color(0xFFF5F0E8);
  static const appCream     = Color(0xFFF5F0E8);
  static const appInk       = Color(0xFF1A1208);
  static const appTeal      = Color(0xFF2C7873);
  static const appTealLight = Color(0xFF52AB98);
  static const appRed       = Color(0xFFC0392B);
  static const appGold      = Color(0xFFB8860B);
  static const place1       = Color(0xFFC9A84C);
  static const place2       = Color(0xFF9EA3A8);
  static const place3       = Color(0xFFB87333);
  static const place4       = Color(0xFF888888);

  // Dark mode
  static const appPaperDark = Color(0xFF2A2018);
  static const appCreamDark = Color(0xFF2A2018);
  static const appInkDark   = Color(0xFFF5F0E8);
  static const appTealDark  = Color(0xFF3D9E99);
  static const appRedDark   = Color(0xFFE05445);
}

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      surface: AppColors.appPaper,
      primary: AppColors.appTeal,
      secondary: AppColors.appTealLight,
      error: AppColors.appRed,
      onSurface: AppColors.appInk,
      onPrimary: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.appPaper,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.appPaper,
      foregroundColor: AppColors.appInk,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.appPaper,
      selectedItemColor: AppColors.appTeal,
      unselectedItemColor: AppColors.place4,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.appCream,
      elevation: 1,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.appInk : null),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.appPaper
                : AppColors.appInk),
        side: WidgetStatePropertyAll(
            BorderSide(color: AppColors.appInk.withAlpha(77))),
      ),
    ),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      surface: AppColors.appPaperDark,
      primary: AppColors.appTealDark,
      secondary: AppColors.appTealLight,
      error: AppColors.appRedDark,
      onSurface: AppColors.appInkDark,
      onPrimary: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.appPaperDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.appPaperDark,
      foregroundColor: AppColors.appInkDark,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.appPaperDark,
      selectedItemColor: AppColors.appTealDark,
      unselectedItemColor: AppColors.place4,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.appCreamDark,
      elevation: 1,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.appInkDark : null),
        foregroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.appPaperDark
                : AppColors.appInkDark),
        side: WidgetStatePropertyAll(
            BorderSide(color: AppColors.appInkDark.withAlpha(77))),
      ),
    ),
  );
}
