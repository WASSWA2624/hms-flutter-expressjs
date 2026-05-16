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
  static const Color ink = Color(0xFF102033);
  static const Color inkMuted = Color(0xFF52677A);
  static const Color surfaceBase = Color(0xFFF6F9FC);
  static const Color surfaceRaised = white;
  static const Color surfaceSubtle = Color(0xFFF1F7FD);
  static const Color surfaceMuted = Color(0xFFEAF3FB);
  static const Color borderSubtle = Color(0xFFCFE0F2);
  static const Color borderMuted = Color(0xFFE1EDF7);

  static const AppStatusColors statusColors = AppStatusColors(
    success: Color(0xFF1B7F45),
    onSuccess: white,
    successContainer: Color(0xFFEAF7EE),
    onSuccessContainer: Color(0xFF145A32),
    warning: Color(0xFFB95D00),
    onWarning: white,
    warningContainer: Color(0xFFFFF4E5),
    onWarningContainer: Color(0xFF8A4300),
    error: Color(0xFFC62828),
    onError: white,
    errorContainer: Color(0xFFFDEDED),
    onErrorContainer: Color(0xFF8E1B1B),
    danger: Color(0xFFB42318),
    onDanger: white,
    dangerContainer: Color(0xFFFFE7E3),
    onDangerContainer: Color(0xFF842018),
    info: blue700,
    onInfo: white,
    infoContainer: Color(0xFFEAF4FE),
    onInfoContainer: blue900,
  );

  static final ColorScheme colorScheme =
      ColorScheme.fromSeed(seedColor: blue500).copyWith(
        primary: blue700,
        onPrimary: white,
        primaryContainer: blue50,
        onPrimaryContainer: blue900,
        primaryFixed: blue100,
        primaryFixedDim: blue200,
        onPrimaryFixed: blue900,
        onPrimaryFixedVariant: blue700,
        secondary: blue800,
        onSecondary: white,
        secondaryContainer: surfaceSubtle,
        onSecondaryContainer: blue900,
        secondaryFixed: blue100,
        secondaryFixedDim: blue200,
        onSecondaryFixed: blue900,
        onSecondaryFixedVariant: blue700,
        tertiary: blue500,
        onTertiary: white,
        tertiaryContainer: blue100,
        onTertiaryContainer: blue900,
        tertiaryFixed: blueAccentA100,
        tertiaryFixedDim: blueAccentA200,
        onTertiaryFixed: blue900,
        onTertiaryFixedVariant: blueAccentA700,
        surface: surfaceRaised,
        onSurface: ink,
        surfaceDim: surfaceMuted,
        surfaceBright: surfaceRaised,
        surfaceContainerLowest: surfaceRaised,
        surfaceContainerLow: surfaceSubtle,
        surfaceContainer: surfaceSubtle,
        surfaceContainerHigh: surfaceMuted,
        surfaceContainerHighest: blue50,
        onSurfaceVariant: inkMuted,
        outline: blue300,
        outlineVariant: borderSubtle,
        shadow: ink,
        scrim: ink,
        inverseSurface: blue900,
        onInverseSurface: surfaceRaised,
        inversePrimary: blue200,
        surfaceTint: transparent,
      );

  static final AppThemePalette palette = AppThemePalette(
    colorScheme: colorScheme,
    statusColors: statusColors,
    scaffoldBackgroundColor: surfaceBase,
    canvasColor: surfaceRaised,
    hoverColor: surfaceMuted,
    splashColor: blue700.withValues(alpha: 0.08),
    highlightColor: blue700.withValues(alpha: 0.06),
    bodyTextColor: ink,
    displayTextColor: ink,
    borderColor: borderSubtle,
    disabledBorderColor: borderMuted,
    focusedBorderColor: blue600,
    inputFillColor: surfaceRaised,
    inputHoverColor: blue700.withValues(alpha: 0.04),
    inputHintColor: inkMuted.withValues(alpha: 0.78),
    inputLabelColor: inkMuted,
    inputFloatingLabelColor: blue700,
    appBarBackgroundColor: surfaceRaised,
    appBarForegroundColor: ink,
    appBarSurfaceTintColor: transparent,
    dividerColor: borderSubtle,
    drawerBackgroundColor: surfaceRaised,
  );
}
