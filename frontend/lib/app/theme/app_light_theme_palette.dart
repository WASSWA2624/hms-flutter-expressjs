import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_palette.dart';

/// Light theme palette: a calm, modern medical identity built on a refined
/// **azure** brand with a fresh **teal** accent and cool-slate neutrals for a
/// clean, high-contrast blend across text, surfaces, and controls.
abstract final class AppLightThemePalette {
  // Brand — azure
  static const Color azure50 = Color(0xFFECF3FF);
  static const Color azure100 = Color(0xFFD6E6FF);
  static const Color azure200 = Color(0xFFADC9FF);
  static const Color azure300 = Color(0xFF7FA9FA);
  static const Color azure400 = Color(0xFF4F87F2);
  static const Color azure500 = Color(0xFF2C6BE4);
  static const Color azure600 = Color(0xFF1D59D4);
  static const Color azure700 = Color(0xFF1549BE);
  static const Color azure800 = Color(0xFF103A99);
  static const Color azure900 = Color(0xFF0B2A70);

  // Accent — teal
  static const Color teal100 = Color(0xFFD3F3EE);
  static const Color teal300 = Color(0xFF66D6C8);
  static const Color teal500 = Color(0xFF12A594);
  static const Color teal600 = Color(0xFF0C8474);
  static const Color teal700 = Color(0xFF0A6055);

  // Neutrals — cool slate
  static const Color transparent = Color(0x00000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0E1B2A);
  static const Color inkMuted = Color(0xFF566579);
  static const Color surfaceBase = Color(0xFFF2F6FC);
  static const Color surfaceRaised = white;
  static const Color surfaceSubtle = Color(0xFFECF3FB);
  static const Color surfaceMuted = Color(0xFFE1EBF6);
  static const Color borderSubtle = Color(0xFFD0DFEF);
  static const Color borderMuted = Color(0xFFE6EEF8);

  static const AppStatusColors statusColors = AppStatusColors(
    success: Color(0xFF1C844A),
    onSuccess: white,
    successContainer: Color(0xFFE6F5EC),
    onSuccessContainer: Color(0xFF0F5C34),
    warning: Color(0xFFBB6209),
    onWarning: white,
    warningContainer: Color(0xFFFFF2E0),
    onWarningContainer: Color(0xFF743B00),
    error: Color(0xFFCE2F2F),
    onError: white,
    errorContainer: Color(0xFFFBEAEA),
    onErrorContainer: Color(0xFF8A1C1C),
    danger: Color(0xFFBE241A),
    onDanger: white,
    dangerContainer: Color(0xFFFEE6E2),
    onDangerContainer: Color(0xFF7C1E14),
    info: azure700,
    onInfo: white,
    infoContainer: Color(0xFFE9F1FE),
    onInfoContainer: azure900,
  );

  static final ColorScheme colorScheme =
      ColorScheme.fromSeed(seedColor: azure500).copyWith(
        primary: azure700,
        onPrimary: white,
        primaryContainer: azure50,
        onPrimaryContainer: azure900,
        primaryFixed: azure100,
        primaryFixedDim: azure200,
        onPrimaryFixed: azure900,
        onPrimaryFixedVariant: azure700,
        secondary: azure800,
        onSecondary: white,
        secondaryContainer: surfaceSubtle,
        onSecondaryContainer: azure900,
        secondaryFixed: azure100,
        secondaryFixedDim: azure200,
        onSecondaryFixed: azure900,
        onSecondaryFixedVariant: azure700,
        tertiary: teal500,
        onTertiary: white,
        tertiaryContainer: teal100,
        onTertiaryContainer: teal700,
        tertiaryFixed: teal100,
        tertiaryFixedDim: teal300,
        onTertiaryFixed: teal700,
        onTertiaryFixedVariant: teal600,
        surface: surfaceRaised,
        onSurface: ink,
        surfaceDim: surfaceMuted,
        surfaceBright: surfaceRaised,
        surfaceContainerLowest: surfaceRaised,
        surfaceContainerLow: surfaceSubtle,
        surfaceContainer: surfaceSubtle,
        surfaceContainerHigh: surfaceMuted,
        surfaceContainerHighest: azure50,
        onSurfaceVariant: inkMuted,
        outline: azure300,
        outlineVariant: borderSubtle,
        shadow: ink,
        scrim: ink,
        inverseSurface: azure900,
        onInverseSurface: surfaceRaised,
        inversePrimary: azure200,
        surfaceTint: transparent,
      );

  static final AppThemePalette palette = AppThemePalette(
    colorScheme: colorScheme,
    statusColors: statusColors,
    scaffoldBackgroundColor: surfaceBase,
    canvasColor: surfaceRaised,
    hoverColor: surfaceMuted,
    splashColor: azure700.withValues(alpha: 0.08),
    highlightColor: azure700.withValues(alpha: 0.06),
    bodyTextColor: ink,
    displayTextColor: ink,
    borderColor: borderSubtle,
    disabledBorderColor: borderMuted,
    focusedBorderColor: azure600,
    inputFillColor: surfaceRaised,
    inputHoverColor: azure700.withValues(alpha: 0.04),
    inputHintColor: inkMuted.withValues(alpha: 0.78),
    inputLabelColor: inkMuted,
    inputFloatingLabelColor: azure700,
    appBarBackgroundColor: surfaceRaised,
    appBarForegroundColor: ink,
    appBarSurfaceTintColor: transparent,
    dividerColor: borderSubtle,
    drawerBackgroundColor: surfaceRaised,
  );
}
