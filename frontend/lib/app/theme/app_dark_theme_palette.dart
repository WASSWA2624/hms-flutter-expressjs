import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_palette.dart';

abstract final class AppDarkThemePalette {
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray200 = Color(0xFFEEEEEE);
  static const Color gray300 = Color(0xFFE0E0E0);
  static const Color gray400 = Color(0xFFBDBDBD);
  static const Color gray500 = Color(0xFF9E9E9E);
  static const Color gray600 = Color(0xFF757575);
  static const Color gray700 = Color(0xFF616161);
  static const Color gray800 = Color(0xFF424242);
  static const Color gray900 = Color(0xFF212121);

  static const Color grayAccentA100 = Color(0xFFF5F5F5);
  static const Color grayAccentA200 = Color(0xFFEEEEEE);
  static const Color grayAccentA400 = Color(0xFFBDBDBD);
  static const Color grayAccentA700 = Color(0xFF616161);

  static const Color transparent = Color(0x00000000);
  static const Color darkBase = Color(0xFF161616);
  static const Color darkSurface = Color(0xFF202020);
  static const Color darkSurfaceRaised = Color(0xFF282828);
  static const Color darkSurfaceMuted = Color(0xFF303030);
  static const Color darkBorder = Color(0xFF4A4A4A);

  static const AppStatusColors statusColors = AppStatusColors(
    success: Color(0xFF81C784),
    onSuccess: darkBase,
    successContainer: Color(0xFF1D3324),
    onSuccessContainer: Color(0xFFC8E6C9),
    warning: Color(0xFFFFB74D),
    onWarning: darkBase,
    warningContainer: Color(0xFF3A2917),
    onWarningContainer: Color(0xFFFFE0B2),
    error: Color(0xFFEF9A9A),
    onError: darkBase,
    errorContainer: Color(0xFF3A1E1E),
    onErrorContainer: Color(0xFFFFCDD2),
    danger: Color(0xFFFF8A80),
    onDanger: darkBase,
    dangerContainer: Color(0xFF421F1B),
    onDangerContainer: Color(0xFFFFCDD2),
    info: Color(0xFF90CAF9),
    onInfo: darkBase,
    infoContainer: Color(0xFF173047),
    onInfoContainer: Color(0xFFE3F2FD),
  );

  static final ColorScheme colorScheme =
      ColorScheme.fromSeed(
        seedColor: gray500,
        brightness: Brightness.dark,
      ).copyWith(
        primary: gray200,
        onPrimary: gray900,
        primaryContainer: gray800,
        onPrimaryContainer: gray50,
        primaryFixed: gray100,
        primaryFixedDim: gray300,
        onPrimaryFixed: gray900,
        onPrimaryFixedVariant: gray700,
        secondary: gray400,
        onSecondary: gray900,
        secondaryContainer: darkSurfaceMuted,
        onSecondaryContainer: gray50,
        secondaryFixed: gray100,
        secondaryFixedDim: gray300,
        onSecondaryFixed: gray900,
        onSecondaryFixedVariant: gray700,
        tertiary: gray500,
        onTertiary: gray900,
        tertiaryContainer: gray700,
        onTertiaryContainer: gray50,
        tertiaryFixed: grayAccentA100,
        tertiaryFixedDim: grayAccentA200,
        onTertiaryFixed: gray900,
        onTertiaryFixedVariant: grayAccentA700,
        surface: darkSurface,
        onSurface: gray100,
        surfaceDim: darkBase,
        surfaceBright: darkSurfaceRaised,
        surfaceContainerLowest: darkBase,
        surfaceContainerLow: darkSurface,
        surfaceContainer: darkSurfaceRaised,
        surfaceContainerHigh: darkSurfaceMuted,
        surfaceContainerHighest: gray800,
        onSurfaceVariant: gray300,
        outline: gray500,
        outlineVariant: darkBorder,
        shadow: darkBase,
        scrim: darkBase,
        inverseSurface: gray100,
        onInverseSurface: gray900,
        inversePrimary: gray500,
        surfaceTint: transparent,
      );

  static final AppThemePalette palette = AppThemePalette(
    colorScheme: colorScheme,
    statusColors: statusColors,
    scaffoldBackgroundColor: darkBase,
    canvasColor: darkSurface,
    hoverColor: darkSurfaceMuted,
    splashColor: gray200.withValues(alpha: 0.10),
    highlightColor: gray200.withValues(alpha: 0.08),
    bodyTextColor: gray100,
    displayTextColor: gray50,
    borderColor: darkBorder,
    disabledBorderColor: darkBorder.withValues(alpha: 0.60),
    focusedBorderColor: gray300,
    inputFillColor: darkSurface,
    inputHoverColor: gray200.withValues(alpha: 0.06),
    inputHintColor: gray400.withValues(alpha: 0.78),
    inputLabelColor: gray300,
    inputFloatingLabelColor: gray100,
    appBarBackgroundColor: darkSurface,
    appBarForegroundColor: gray100,
    appBarSurfaceTintColor: transparent,
    dividerColor: darkBorder,
    drawerBackgroundColor: darkSurface,
  );
}
