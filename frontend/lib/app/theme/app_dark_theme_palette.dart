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

  static const AppStatusColors statusColors = AppStatusColors(
    success: Color(0xFF81C784),
    onSuccess: Color(0xFF1B5E20),
    successContainer: Color(0xFF1B5E20),
    onSuccessContainer: Color(0xFFE8F5E9),
    warning: Color(0xFFFFB74D),
    onWarning: Color(0xFFE65100),
    warningContainer: Color(0xFFE65100),
    onWarningContainer: Color(0xFFFFF3E0),
    error: Color(0xFFEF9A9A),
    onError: Color(0xFFB71C1C),
    errorContainer: Color(0xFFB71C1C),
    onErrorContainer: Color(0xFFFFEBEE),
    danger: Color(0xFFFF8A80),
    onDanger: Color(0xFFB71C1C),
    dangerContainer: Color(0xFFC62828),
    onDangerContainer: Color(0xFFFFEBEE),
    info: Color(0xFF90CAF9),
    onInfo: Color(0xFF0D47A1),
    infoContainer: Color(0xFF1565C0),
    onInfoContainer: Color(0xFFE3F2FD),
  );

  static final ColorScheme colorScheme =
      ColorScheme.fromSeed(
        seedColor: gray500,
        brightness: Brightness.dark,
      ).copyWith(
        primary: gray100,
        onPrimary: gray900,
        primaryContainer: gray700,
        onPrimaryContainer: gray50,
        primaryFixed: gray100,
        primaryFixedDim: gray300,
        onPrimaryFixed: gray900,
        onPrimaryFixedVariant: gray700,
        secondary: gray300,
        onSecondary: gray900,
        secondaryContainer: gray800,
        onSecondaryContainer: gray50,
        secondaryFixed: gray100,
        secondaryFixedDim: gray300,
        onSecondaryFixed: gray900,
        onSecondaryFixedVariant: gray700,
        tertiary: grayAccentA400,
        onTertiary: gray900,
        tertiaryContainer: grayAccentA700,
        onTertiaryContainer: gray50,
        tertiaryFixed: grayAccentA100,
        tertiaryFixedDim: grayAccentA200,
        onTertiaryFixed: gray900,
        onTertiaryFixedVariant: grayAccentA700,
        surface: gray900,
        onSurface: gray50,
        surfaceDim: gray900,
        surfaceBright: gray700,
        surfaceContainerLowest: gray900,
        surfaceContainerLow: gray800,
        surfaceContainer: gray800,
        surfaceContainerHigh: gray700,
        surfaceContainerHighest: gray700,
        onSurfaceVariant: gray300,
        outline: gray500,
        outlineVariant: gray700,
        shadow: gray900,
        scrim: gray900,
        inverseSurface: gray100,
        onInverseSurface: gray900,
        inversePrimary: gray500,
        surfaceTint: gray100,
      );

  static final AppThemePalette palette = AppThemePalette(
    colorScheme: colorScheme,
    statusColors: statusColors,
    scaffoldBackgroundColor: gray900,
    canvasColor: gray900,
    hoverColor: gray800,
    splashColor: gray100.withValues(alpha: 0.10),
    highlightColor: gray100.withValues(alpha: 0.08),
    bodyTextColor: gray50,
    displayTextColor: gray50,
    borderColor: gray700,
    disabledBorderColor: gray700.withValues(alpha: 0.55),
    focusedBorderColor: gray100,
    inputFillColor: gray900,
    inputHoverColor: gray100.withValues(alpha: 0.06),
    inputHintColor: gray300.withValues(alpha: 0.70),
    inputLabelColor: gray300.withValues(alpha: 0.90),
    inputFloatingLabelColor: gray100,
    appBarBackgroundColor: gray900,
    appBarForegroundColor: gray50,
    appBarSurfaceTintColor: transparent,
    dividerColor: gray700,
    drawerBackgroundColor: gray900,
  );
}
