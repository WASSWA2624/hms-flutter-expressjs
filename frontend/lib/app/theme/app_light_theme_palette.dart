import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_palette.dart';

/// Light theme palette: an elegant **white → light blue → blue** identity.
///
/// Surfaces stay porcelain-white and powder-blue; brand actions use the HOSSPI
/// window cyan (same as auth app-name text); accents stay in the same blue
/// family so the UI reads as one continuous, soft blend.
abstract final class AppLightThemePalette {
  /// HOSSPI logo window cyan — primary CTA / auth app-name text.
  static const Color brandPrimary = Color(0xFF0079FD);

  // Brand scale — tinted around [brandPrimary]
  static const Color azure50 = Color(0xFFF3F8FF);
  static const Color azure100 = Color(0xFFE5F1FF);
  static const Color azure200 = Color(0xFFC5DEFF);
  static const Color azure300 = Color(0xFF9AC6FF);
  static const Color azure400 = Color(0xFF5AA3FF);
  static const Color azure500 = Color(0xFF2B8BFF);
  static const Color azure600 = Color(0xFF0F7FF8);
  static const Color azure700 = brandPrimary;
  static const Color azure800 = Color(0xFF0062D1);
  static const Color azure900 = Color(0xFF004A9E);

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
    info: brandPrimary,
    onInfo: white,
    infoContainer: azure100,
    onInfoContainer: azure900,
  );

  static final ColorScheme colorScheme =
      ColorScheme.fromSeed(seedColor: brandPrimary).copyWith(
        primary: brandPrimary,
        onPrimary: white,
        primaryContainer: azure100,
        onPrimaryContainer: azure900,
        primaryFixed: azure100,
        primaryFixedDim: azure200,
        onPrimaryFixed: azure900,
        onPrimaryFixedVariant: brandPrimary,
        secondary: azure800,
        onSecondary: white,
        secondaryContainer: surfaceSubtle,
        onSecondaryContainer: azure900,
        secondaryFixed: azure100,
        secondaryFixedDim: azure200,
        onSecondaryFixed: azure900,
        onSecondaryFixedVariant: brandPrimary,
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
    splashColor: brandPrimary.withValues(alpha: 0.08),
    highlightColor: brandPrimary.withValues(alpha: 0.06),
    bodyTextColor: ink,
    displayTextColor: ink,
    borderColor: borderSubtle,
    disabledBorderColor: borderMuted,
    focusedBorderColor: brandPrimary,
    inputFillColor: surfaceRaised,
    inputHoverColor: brandPrimary.withValues(alpha: 0.04),
    inputHintColor: inkMuted.withValues(alpha: 0.78),
    inputLabelColor: inkMuted,
    inputFloatingLabelColor: brandPrimary,
    appBarBackgroundColor: surfaceRaised,
    appBarForegroundColor: ink,
    appBarSurfaceTintColor: transparent,
    dividerColor: borderSubtle,
    drawerBackgroundColor: surfaceRaised,
  );
}
