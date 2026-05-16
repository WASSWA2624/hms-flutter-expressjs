import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_palette.dart';

abstract final class AppLightThemePalette {
  static const Color blue50 = Color(0xFFE3F2FD);
  static const Color blue100 = Color(0xFFBBDEFB);
  static const Color blue200 = Color(0xFF90CAF9);
  static const Color blue300 = Color(0xFF64B5F6);
  static const Color blue400 = Color(0xFF42A5F5);
  static const Color blue500 = Color(0xFF2196F3);
  static const Color blue600 = Color(0xFF1E88E5);
  static const Color blue700 = Color(0xFF1976D2);
  static const Color blue800 = Color(0xFF1565C0);
  static const Color blue900 = Color(0xFF0D47A1);

  static const Color blueAccentA100 = Color(0xFF82B1FF);
  static const Color blueAccentA200 = Color(0xFF448AFF);
  static const Color blueAccentA400 = Color(0xFF2979FF);
  static const Color blueAccentA700 = Color(0xFF2962FF);

  static const Color transparent = Color(0x00000000);
  static const Color white = Color(0xFFFFFFFF);

  static const AppStatusColors statusColors = AppStatusColors(
    success: Color(0xFF2E7D32),
    onSuccess: white,
    successContainer: Color(0xFFE8F5E9),
    onSuccessContainer: Color(0xFF1B5E20),
    warning: Color(0xFFED6C02),
    onWarning: white,
    warningContainer: Color(0xFFFFF3E0),
    onWarningContainer: Color(0xFFE65100),
    error: Color(0xFFD32F2F),
    onError: white,
    errorContainer: Color(0xFFFFEBEE),
    onErrorContainer: Color(0xFFB71C1C),
    danger: Color(0xFFC62828),
    onDanger: white,
    dangerContainer: Color(0xFFFFCDD2),
    onDangerContainer: Color(0xFFB71C1C),
    info: blue700,
    onInfo: white,
    infoContainer: blue50,
    onInfoContainer: blue900,
  );

  static final ColorScheme colorScheme =
      ColorScheme.fromSeed(seedColor: blue500).copyWith(
        primary: blue500,
        onPrimary: white,
        primaryContainer: blue50,
        onPrimaryContainer: blue900,
        primaryFixed: blue100,
        primaryFixedDim: blue200,
        onPrimaryFixed: blue900,
        onPrimaryFixedVariant: blue700,
        secondary: blue700,
        onSecondary: white,
        secondaryContainer: blue100,
        onSecondaryContainer: blue900,
        secondaryFixed: blue100,
        secondaryFixedDim: blue200,
        onSecondaryFixed: blue900,
        onSecondaryFixedVariant: blue700,
        tertiary: blueAccentA400,
        onTertiary: white,
        tertiaryContainer: blueAccentA100,
        onTertiaryContainer: blue900,
        tertiaryFixed: blueAccentA100,
        tertiaryFixedDim: blueAccentA200,
        onTertiaryFixed: blue900,
        onTertiaryFixedVariant: blueAccentA700,
        surface: blue50,
        onSurface: blue900,
        surfaceDim: blue100,
        surfaceBright: blue50,
        surfaceContainerLowest: blue50,
        surfaceContainerLow: blue50,
        surfaceContainer: blue100,
        surfaceContainerHigh: blue100,
        surfaceContainerHighest: blue200,
        onSurfaceVariant: blue800,
        outline: blue500,
        outlineVariant: blue100,
        shadow: blue900,
        scrim: blue900,
        inverseSurface: blue900,
        onInverseSurface: blue50,
        inversePrimary: blue200,
        surfaceTint: blue500,
      );

  static final AppThemePalette palette = AppThemePalette(
    colorScheme: colorScheme,
    statusColors: statusColors,
    scaffoldBackgroundColor: blue50,
    canvasColor: blue50,
    hoverColor: blue100,
    splashColor: blue500.withValues(alpha: 0.08),
    highlightColor: blue500.withValues(alpha: 0.06),
    bodyTextColor: blue900,
    displayTextColor: blue900,
    borderColor: blue100,
    disabledBorderColor: blue100.withValues(alpha: 0.55),
    focusedBorderColor: blue500,
    inputFillColor: blue50,
    inputHoverColor: blue500.withValues(alpha: 0.04),
    inputHintColor: blue900.withValues(alpha: 0.58),
    inputLabelColor: blue900.withValues(alpha: 0.86),
    inputFloatingLabelColor: blue500,
    appBarBackgroundColor: blue50,
    appBarForegroundColor: blue900,
    appBarSurfaceTintColor: transparent,
    dividerColor: blue100,
    drawerBackgroundColor: blue50,
  );
}
