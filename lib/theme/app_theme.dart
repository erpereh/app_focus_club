import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const double radiusSmall = 10;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;
  static const double radiusHero = 28;
  static const double radiusPill = 999;

  static const double radiusCard = radiusHero;
  static const double radiusControl = radiusPill;
  static const double radiusInput = radiusMedium;
  static const double radiusBadge = radiusPill;

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double gutter = 20;
  static const double navContentInset = 150;

  static const Duration motion = Duration(milliseconds: 180);
  static const Curve motionCurve = Curves.easeOut;

  static const Color background = Color(0xFFF3F1EA);
  static const Color backgroundSecondary = Color(0xFFEBE8DE);
  static const Color black = Color(0xFF11120F);
  static const Color blackElevated = Color(0xFF181A16);
  static const Color lime = Color(0xFFC8FF3D);
  static const Color onLime = Color(0xFF11120F);
  static const Color onBlack = Color(0xFFF4F1EA);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF151613);
  static const Color textSecondary = Color(0xFF74756F);
  static const Color danger = Color(0xFFFF645F);
  static const Color warning = Color(0xFFE9B94B);
  static const Color success = Color(0xFF2F9E5F);
  static const Color info = Color(0xFF6AA7FF);

  static const Color emerald = lime;
  static const Color emeraldDark = Color(0xFF9ED62A);
  static const Color amber = warning;
  static const Color surface = white;
  static const Color surfaceElevated = white;
  static const Color surfaceGlass = white;
  static const Color input = backgroundSecondary;
  static const Color border = Color(0x1A151613);
  static const Color borderStrong = Color(0x33151613);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: lime,
      brightness: Brightness.light,
      surface: white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme.copyWith(
        primary: lime,
        secondary: lime,
        surface: white,
        surfaceContainer: backgroundSecondary,
        surfaceContainerHigh: white,
        onSurface: textPrimary,
        onPrimary: onLime,
        error: danger,
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          height: 1.1,
        ),
      ),
      dividerColor: border,
      splashFactory: InkRipple.splashFactory,
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderStrong),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: black,
        contentTextStyle: const TextStyle(
          color: onBlack,
          fontWeight: FontWeight.w700,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: backgroundSecondary,
        selectedColor: lime,
        disabledColor: backgroundSecondary,
        labelStyle: const TextStyle(color: textPrimary),
        secondaryLabelStyle: const TextStyle(color: onLime),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return lime;
            return backgroundSecondary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return onLime;
            return textPrimary;
          }),
          side: WidgetStateProperty.all(BorderSide.none),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusPill),
            ),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusHero),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lime,
          foregroundColor: onLime,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textPrimary),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: white,
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        errorStyle: const TextStyle(color: danger),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: black, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: danger),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.08,
          letterSpacing: -0.6,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.1,
          letterSpacing: -0.4,
        ),
        displaySmall: TextStyle(
          color: textPrimary,
          fontSize: 48,
          fontWeight: FontWeight.w800,
          height: 0.95,
          letterSpacing: -1.2,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        titleSmall: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: textSecondary, fontSize: 15, height: 1.4),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        labelSmall: TextStyle(
          color: textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  static ThemeData get dark => light;
}
