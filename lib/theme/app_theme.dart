import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color background = Color(0xFF050807);
  static const Color surface = Color(0xFF101614);
  static const Color surfaceElevated = Color(0xFF17211E);
  static const Color surfaceGlass = Color(0xCC121A17);
  static const Color input = Color(0xFF0B100E);
  static const Color emerald = Color(0xFF24D18F);
  static const Color emeraldDark = Color(0xFF0D8F63);
  static const Color amber = Color(0xFFF2B84B);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color textPrimary = Color(0xFFF4FBF7);
  static const Color textSecondary = Color(0xFF9AA8A2);
  static const Color border = Color(0xFF26332F);
  static const Color borderStrong = Color(0xFF375247);

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: Brightness.dark,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme.copyWith(
        primary: emerald,
        secondary: emerald,
        surface: surface,
        onSurface: textPrimary,
        error: danger,
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: background,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: emerald,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: input,
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
        errorStyle: const TextStyle(color: danger),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: emerald, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger, width: 1.4),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 34,
          fontWeight: FontWeight.w900,
          height: 1.05,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.12,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
        bodyLarge: TextStyle(color: textSecondary, fontSize: 16, height: 1.45),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}
