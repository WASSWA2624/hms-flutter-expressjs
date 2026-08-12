import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_palette.dart';

/// Light theme palette: an elegant **white → light blue → blue** identity.
///
/// Surfaces stay porcelain-white and powder-blue; brand actions use a refined
/// clinical blue; accents stay in the same blue family (sky) so the UI reads
/// as one continuous, soft blend—no competing teal/green hue.
abstract final class AppLightThemePalette {
  // Brand — blue (white mist → clear blue)
  static const Color azure50 = Color(0xFFF4F9FE);
  static const Color azure100 = Color(0xFFE6F1FC);
  static const Color azure200 = Color(0xFFCBE0F7);
  static const Color azure300 = Color(0xFFA3C8ED);
  static const Color azure400 = Color(0xFF6BA6E0);
  static const Color azure500 = Color(0xFF3B87D4);
  static const Color azure600 = Color(0xFF2470C2);
  static const Color azure700 = Color(0xFF1A5CAD);
  static const Color azure800 = Color(0xFF144A8F);
  static const Color azure900 = Color(0xFF0E356C);

  // Accent — sky (lighter blue in the same hue family)
  static const Color sky100 = Color(0xFFEAF5FE);
  static const Color sky300 = Color(0xFF8DC9F4);
  static const Color sky500 = Color(0xFF4BA0E6);
  static const Color sky600 = Color(0xFF2F88D1);
  static const Color sky700 = Color(0xFF1C6BAE);

  // Neutrals — white + blue-tinted cools (never flat gray)
  static const Color transparent = Color(0x00000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF10253D);
  static const Color inkMuted = Color(0xFF5A7189);
  static const Color surfaceBase = Color(0xFFF6FAFE);
  static const Color surfaceRaised = white;
  static const Color surfaceSubtle = Color(0xFFEEF5FC);
  static const Color surfaceMuted = Color(0xFFE3EEF8);
  static const Color borderSubtle = Color(0xFFD2E2F2);
  static const Color borderMuted = Color(0xFFE8F1F9);

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
    infoContainer: azure100,
    onInfoContainer: azure900,
  );

  static final ColorScheme colorScheme =
      ColorScheme.fromSeed(seedColor: azure500).copyWith(
        primary: azure700,
        onPrimary: white,
        primaryContainer: azure100,
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
        tertiary: sky500,
        onTertiary: white,
        tertiaryContainer: sky100,
        onTertiaryContainer: sky700,
        tertiaryFixed: sky100,
        tertiaryFixedDim: sky300,
        onTertiaryFixed: sky700,
        onTertiaryFixedVariant: sky600,
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
