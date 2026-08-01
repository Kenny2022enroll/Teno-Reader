import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_palette.dart';

/// Typography following Apple SF Pro / SF Pro Text metric style.
class AppTypography {
  AppTypography._();

  static const String fontDisplay = 'SF Pro Display';
  static const String fontText = 'SF Pro Text';
  static const String fontSerif = 'Charter';

  static TextTheme buildTextTheme(bool dark) {
    const base = TextStyle(
      fontFamily: fontText,
      fontWeight: FontWeight.w400,
      height: 1.3,
    );
    return TextTheme(
      displayLarge: base.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      displayMedium: base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      headlineLarge: base.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      headlineMedium: base.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      titleLarge: base.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
      titleMedium: base.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
      bodyLarge: base.copyWith(fontSize: 17),
      bodyMedium: base.copyWith(fontSize: 15),
      bodySmall: base.copyWith(
        fontSize: 13,
        color: dark
            ? AppPalette.darkTertiaryLabel
            : AppPalette.lightTertiaryLabel,
      ),
      labelLarge: base.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
      labelMedium: base.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
      labelSmall: base.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
    );
  }
}

/// Spacing tokens following HIG "spacing grid" (multiples of 4/8/12/16/20/24).
class AppSpacing {
  AppSpacing._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Radius tokens — HIG prefers continuous squircle-like curves.
class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;
}

/// Animation durations & curves matching Apple motion spec.
class AppMotion {
  AppMotion._();
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve curveIn = Curves.easeInCubic;
  static const Curve curveInOut = Curves.easeInOutCubic;
}

class AppTheme {
  final ThemeMode mode;
  final AppPaletteData light;
  final AppPaletteData dark;

  const AppTheme({required this.mode, required this.light, required this.dark});

  ThemeData get lightTheme => _buildTheme(light, Brightness.light);
  ThemeData get darkTheme => _buildTheme(dark, Brightness.dark);

  ThemeData _buildTheme(AppPaletteData palette, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
      surface: palette.surface,
      onSurface: palette.label,
      surfaceContainerHighest: palette.tertiaryBackground,
      primary: palette.accent,
      onPrimary: Colors.white,
      secondary: palette.secondaryAccent,
      onSecondary: Colors.white,
      error: AppPalette.lightRed,
    );

    final textTheme = AppTypography.buildTextTheme(
      brightness == Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(
        surface: palette.surface,
        onSurface: palette.label,
        primary: palette.accent,
      ),
      scaffoldBackgroundColor: palette.background,
      textTheme: textTheme,
      fontFamily: AppTypography.fontText,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.label,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge!.copyWith(color: palette.label),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.accent,
        unselectedItemColor: palette.tertiaryLabel,
        elevation: 0.5,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: DividerThemeData(
        color: palette.separator,
        space: 0,
        thickness: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.tertiaryBackground,
        contentTextStyle: textTheme.bodyMedium!.copyWith(color: palette.label),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
      splashColor: palette.accent.withOpacity(0.12),
      highlightColor: Colors.transparent,
    );
  }
}

class AppPaletteData {
  final Color background;
  final Color secondaryBackground;
  final Color tertiaryBackground;
  final Color surface;
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color separator;
  final Color accent;
  final Color secondaryAccent;

  const AppPaletteData({
    required this.background,
    required this.secondaryBackground,
    required this.tertiaryBackground,
    required this.surface,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.separator,
    required this.accent,
    required this.secondaryAccent,
  });
}

const lightPalette = AppPaletteData(
  background: AppPalette.lightBackground,
  secondaryBackground: AppPalette.lightSecondaryBackground,
  tertiaryBackground: AppPalette.lightTertiaryBackground,
  surface: AppPalette.lightSecondaryBackground,
  label: AppPalette.lightLabel,
  secondaryLabel: AppPalette.lightSecondaryLabel,
  tertiaryLabel: AppPalette.lightTertiaryLabel,
  separator: AppPalette.lightSeparator,
  accent: AppPalette.lightBlue,
  secondaryAccent: AppPalette.lightPurple,
);

const darkPalette = AppPaletteData(
  background: AppPalette.darkBackground,
  secondaryBackground: AppPalette.darkSecondaryBackground,
  tertiaryBackground: AppPalette.darkTertiaryBackground,
  surface: AppPalette.darkSecondaryBackground,
  label: AppPalette.darkLabel,
  secondaryLabel: AppPalette.darkSecondaryLabel,
  tertiaryLabel: AppPalette.darkTertiaryLabel,
  separator: AppPalette.darkSeparator,
  accent: AppPalette.lightBlue,
  secondaryAccent: AppPalette.lightPurple,
);

final appThemeProvider = StateNotifierProvider<AppThemeController, AppTheme>(
  (ref) => AppThemeController(),
);

class AppThemeController extends StateNotifier<AppTheme> {
  AppThemeController()
    : super(
        const AppTheme(
          mode: ThemeMode.system,
          light: lightPalette,
          dark: darkPalette,
        ),
      );

  void setMode(ThemeMode mode) {
    state = AppTheme(mode: mode, light: state.light, dark: state.dark);
  }

  void setAccent(Color accent, {Color? secondary}) {
    state = AppTheme(
      mode: state.mode,
      light: AppPaletteData(
        background: state.light.background,
        secondaryBackground: state.light.secondaryBackground,
        tertiaryBackground: state.light.tertiaryBackground,
        surface: state.light.surface,
        label: state.light.label,
        secondaryLabel: state.light.secondaryLabel,
        tertiaryLabel: state.light.tertiaryLabel,
        separator: state.light.separator,
        accent: accent,
        secondaryAccent: secondary ?? state.light.secondaryAccent,
      ),
      dark: AppPaletteData(
        background: state.dark.background,
        secondaryBackground: state.dark.secondaryBackground,
        tertiaryBackground: state.dark.tertiaryBackground,
        surface: state.dark.surface,
        label: state.dark.label,
        secondaryLabel: state.dark.secondaryLabel,
        tertiaryLabel: state.dark.tertiaryLabel,
        separator: state.dark.separator,
        accent: accent,
        secondaryAccent: secondary ?? state.dark.secondaryAccent,
      ),
    );
  }
}
