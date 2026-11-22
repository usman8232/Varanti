import 'package:flutter/material.dart';

class AppTheme {
  // Brand Palette (calibrated directly from Varanti V mark & VARANTi wordmark)
  static const Color brandCrimson = Color(0xFFE40034);
  static const Color brandCrimsonDark = Color(0xFFF41D4E);
  static const Color brandCrimsonDeep = Color(0xFFB80028);
  static const Color brandCrimsonSoftLight = Color(0xFFFDECEF);
  static const Color brandCrimsonSoftDark = Color(0xFF31121A);

  // Neutral Monochrome Surfaces & Typography
  static const Color inkPrimary = Color(0xFF0D0D0F);
  static const Color inkSecondary = Color(0xFF5F6368);
  static const Color inkDarkPrimary = Color(0xFFF8FAFC);
  static const Color inkDarkSecondary = Color(0xFF9CA3AF);

  static const Color canvasLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceSubtleLight = Color(0xFFF3F4F6);
  static const Color hairlineLight = Color(0xFFE6E8EC);

  static const Color canvasDark = Color(0xFF0B0C0E);
  static const Color surfaceDark = Color(0xFF14161A);
  static const Color surfaceSubtleDark = Color(0xFF1D2026);
  static const Color hairlineDark = Color(0xFF262A32);

  // Semantic Warranty Status Tokens (SRS FR-WAR-01)
  static const Color statusActive = Color(0xFF0F9D58); // Emerald (> 30 days)
  static const Color statusActiveSoftLight = Color(0xFFE8F7EF);
  static const Color statusActiveSoftDark = Color(0xFF102A1E);

  static const Color statusExpiringSoon = Color(0xFFD97706); // Amber (1-30 days)
  static const Color statusExpiringSoftLight = Color(0xFFFEF3C7);
  static const Color statusExpiringSoftDark = Color(0xFF2D220E);

  static const Color statusExpired = brandCrimson; // Varanti Crimson (<= 0 days)
  static const Color statusExpiredSoftLight = brandCrimsonSoftLight;
  static const Color statusExpiredSoftDark = brandCrimsonSoftDark;

  // Backward-compatible aliases
  static const Color primary = brandCrimson;
  static const Color backgroundLight = canvasLight;

  static const String fontFamily = 'Lexend';

  static Color crimsonOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? brandCrimsonDark
        : brandCrimson;
  }

  static Color hairlineOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? hairlineDark
        : hairlineLight;
  }

  static Color subtleSurfaceOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? surfaceSubtleDark
        : surfaceSubtleLight;
  }

  static Color mutedTextOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? inkDarkSecondary
        : inkSecondary;
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return statusActive;
      case 'expiring_soon':
        return statusExpiringSoon;
      case 'expired':
      default:
        return statusExpired;
    }
  }

  static Color getStatusSoftBg(String status, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (status.toLowerCase()) {
      case 'active':
        return isDark ? statusActiveSoftDark : statusActiveSoftLight;
      case 'expiring_soon':
        return isDark ? statusExpiringSoftDark : statusExpiringSoftLight;
      case 'expired':
      default:
        return isDark ? statusExpiredSoftDark : statusExpiredSoftLight;
    }
  }

  static String getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'expiring_soon':
        return 'Expiring Soon';
      case 'expired':
      default:
        return 'Expired';
    }
  }

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandCrimson,
      brightness: Brightness.light,
      primary: inkPrimary,
      onPrimary: Colors.white,
      secondary: brandCrimson,
      onSecondary: Colors.white,
      surface: surfaceLight,
      onSurface: inkPrimary,
      error: brandCrimson,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvasLight,
      dividerColor: hairlineLight,
      dividerTheme: const DividerThemeData(
        color: hairlineLight,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvasLight,
        foregroundColor: inkPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: inkPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: hairlineLight, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: hairlineLight, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        hintStyle: const TextStyle(color: inkSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: inkSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: hairlineLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: hairlineLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: inkPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandCrimson),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandCrimson, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: inkPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: const StadiumBorder(),
          side: const BorderSide(color: hairlineLight, width: 1.2),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandCrimson,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: inkPrimary,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: StadiumBorder(),
        side: BorderSide(color: hairlineLight),
        backgroundColor: surfaceLight,
        selectedColor: brandCrimsonSoftLight,
        checkmarkColor: brandCrimson,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandCrimson,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: inkPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandCrimsonDark,
      brightness: Brightness.dark,
      primary: inkDarkPrimary,
      onPrimary: inkPrimary,
      secondary: brandCrimsonDark,
      onSecondary: Colors.white,
      surface: surfaceDark,
      onSurface: inkDarkPrimary,
      error: brandCrimsonDark,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvasDark,
      dividerColor: hairlineDark,
      dividerTheme: const DividerThemeData(
        color: hairlineDark,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvasDark,
        foregroundColor: inkDarkPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: inkDarkPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: hairlineDark, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: hairlineDark, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        hintStyle: const TextStyle(color: inkDarkSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: inkDarkSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: hairlineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: hairlineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: inkDarkPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandCrimsonDark),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandCrimsonDark, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: inkDarkPrimary,
          foregroundColor: inkPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkDarkPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: const StadiumBorder(),
          side: const BorderSide(color: hairlineDark, width: 1.2),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandCrimsonDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: inkDarkPrimary,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: StadiumBorder(),
        side: BorderSide(color: hairlineDark),
        backgroundColor: surfaceDark,
        selectedColor: brandCrimsonSoftDark,
        checkmarkColor: brandCrimsonDark,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandCrimsonDark,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceSubtleDark,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: inkDarkPrimary,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
