import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_palette.dart';

/// Light theme palette: porcelain surfaces + HOSSPI window cyan brand.
///
/// All azure / sky / surface / border / ink tokens are tinted from
/// [brandPrimary] (`#0079FD`) so the white theme reads as one continuous
/// family with `colorScheme.primary`.
abstract final class AppLightThemePalette {
  /// HOSSPI logo window cyan — primary CTA / auth app-name text.
  static const Color brandPrimary = Color(0xFF0079FD);

  // Brand scale — progressive tints/shades of [brandPrimary]
  static const Color azure50 = Color(0xFFF5FAFF);
  static const Color azure100 = Color(0xFFEBF4FF);
  static const Color azure200 = Color(0xFFD1E7FF);
  static const Color azure300 = Color(0xFFADD4FE);
  static const Color azure400 = Color(0xFF80BCFE);
  static const Color azure500 = Color(0xFF52A4FE);
  static const Color azure600 = Color(0xFF268DFD);
  static const Color azure700 = brandPrimary;
  static const Color azure800 = Color(0xFF0267D9);
  static const Color azure900 = Color(0xFF0455B4);
  static const Color azure950 = Color(0xFF054493);

  // Accent — lighter companions in the same cyan-blue hue
  static const Color sky100 = Color(0xFFF0F7FF);
  static const Color sky300 = Color(0xFF99C9FE);
  static const Color sky500 = Color(0xFF61ACFE);
  static const Color sky600 = Color(0xFF409AFE);
  static const Color sky700 = Color(0xFF035DC4);

  // Neutrals — white + primary-tinted cools (never flat gray)
  static const Color transparent = Color(0x00000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0D2744);
  static const Color inkMuted = Color(0xFF4F6B88);
  static const Color surfaceBase = Color(0xFFF7FBFF);
  static const Color surfaceRaised = white;
  static const Color surfaceSubtle = Color(0xFFF1F8FF);
  static const Color surfaceMuted = Color(0xFFE8F3FF);
  static const Color borderSubtle = Color(0xFFD0E3F7);
  static const Color borderMuted = Color(0xFFE8F1FA);

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
        secondaryContainer: azure50,
        onSecondaryContainer: azure900,
        secondaryFixed: azure100,
        secondaryFixedDim: azure200,
        onSecondaryFixed: azure900,
        onSecondaryFixedVariant: azure800,
        tertiary: sky500,
        onTertiary: white,
        tertiaryContainer: sky100,
        onTertiaryContainer: sky700,
        tertiaryFixed: sky100,
        tertiaryFixedDim: sky300,
        onTertiaryFixed: sky700,
        onTertiaryFixedVariant: sky600,
        error: statusColors.error,
        onError: statusColors.onError,
        errorContainer: statusColors.errorContainer,
        onErrorContainer: statusColors.onErrorContainer,
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
        inverseSurface: azure950,
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
