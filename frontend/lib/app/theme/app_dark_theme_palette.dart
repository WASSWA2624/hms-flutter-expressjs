import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_palette.dart';

/// Dark theme palette: the same azure + teal brand as light, tuned for dark
/// mode with deep **navy** surfaces (not flat black) and luminous accents, for
/// a rich, readable, low-glare blend across text, surfaces, and controls.
abstract final class AppDarkThemePalette {
  // Brand — azure (brightened for legibility on dark surfaces)
  static const Color azure100 = Color(0xFFDCE8FF);
  static const Color azure200 = Color(0xFFAECBFF);
  static const Color azure300 = Color(0xFF83B0FF);
  static const Color azure400 = Color(0xFF5C93F5);
  static const Color azure500 = Color(0xFF3D78E6);
  static const Color azure700 = Color(0xFF1E4F9E);
  static const Color azure800 = Color(0xFF163C7C);
  static const Color azureContainer = Color(0xFF16386F);

  // Accent — teal
  static const Color teal200 = Color(0xFFA7ECE2);
  static const Color teal300 = Color(0xFF63D6C8);
  static const Color teal500 = Color(0xFF17B3A2);
  static const Color teal700 = Color(0xFF0C6E62);

  // Neutrals — deep navy surfaces + cool text
  static const Color transparent = Color(0x00000000);
  static const Color navy950 = Color(0xFF0B1220);
  static const Color navy900 = Color(0xFF111C2E);
  static const Color navy850 = Color(0xFF16233A);
  static const Color navy800 = Color(0xFF1D2E49);
  static const Color navy700 = Color(0xFF2A3E5E);
  static const Color slateOutline = Color(0xFF4A5E80);
  static const Color ink50 = Color(0xFFF2F6FC);
  static const Color ink100 = Color(0xFFE4ECF7);
  static const Color ink200 = Color(0xFFC4D0E2);
  static const Color inkMuted = Color(0xFFA6B4CB);
  static const Color deepShadow = Color(0xFF05080F);

  static const AppStatusColors statusColors = AppStatusColors(
    success: Color(0xFF7ED89B),
    onSuccess: navy950,
    successContainer: Color(0xFF133525),
    onSuccessContainer: Color(0xFFC9EED4),
    warning: Color(0xFFF2B366),
    onWarning: navy950,
    warningContainer: Color(0xFF3B2A12),
    onWarningContainer: Color(0xFFFCE1BD),
    error: Color(0xFFF19B9B),
    onError: navy950,
    errorContainer: Color(0xFF3F1E1E),
    onErrorContainer: Color(0xFFFBD2D2),
    danger: Color(0xFFFF968A),
    onDanger: navy950,
    dangerContainer: Color(0xFF46201B),
    onDangerContainer: Color(0xFFFFD6CF),
    info: azure300,
    onInfo: navy950,
    infoContainer: Color(0xFF143160),
    onInfoContainer: Color(0xFFDCE9FF),
  );

  static final ColorScheme colorScheme =
      ColorScheme.fromSeed(
        seedColor: azure500,
        brightness: Brightness.dark,
      ).copyWith(
        primary: azure300,
        onPrimary: navy950,
        primaryContainer: azureContainer,
        onPrimaryContainer: azure100,
        primaryFixed: azure100,
        primaryFixedDim: azure200,
        onPrimaryFixed: navy950,
        onPrimaryFixedVariant: azure800,
        secondary: azure200,
        onSecondary: navy950,
        secondaryContainer: navy800,
        onSecondaryContainer: ink50,
        secondaryFixed: azure100,
        secondaryFixedDim: azure200,
        onSecondaryFixed: navy950,
        onSecondaryFixedVariant: azure800,
        tertiary: teal300,
        onTertiary: navy950,
        tertiaryContainer: teal700,
        onTertiaryContainer: teal200,
        tertiaryFixed: teal200,
        tertiaryFixedDim: teal300,
        onTertiaryFixed: navy950,
        onTertiaryFixedVariant: teal500,
        surface: navy900,
        onSurface: ink100,
        surfaceDim: navy950,
        surfaceBright: navy850,
        surfaceContainerLowest: navy950,
        surfaceContainerLow: navy900,
        surfaceContainer: navy850,
        surfaceContainerHigh: navy800,
        surfaceContainerHighest: navy700,
        onSurfaceVariant: ink200,
        outline: slateOutline,
        outlineVariant: navy700,
        shadow: deepShadow,
        scrim: deepShadow,
        inverseSurface: ink100,
        onInverseSurface: navy900,
        inversePrimary: azure700,
        surfaceTint: transparent,
      );

  static final AppThemePalette palette = AppThemePalette(
    colorScheme: colorScheme,
    statusColors: statusColors,
    scaffoldBackgroundColor: navy950,
    canvasColor: navy900,
    hoverColor: navy800,
    splashColor: azure300.withValues(alpha: 0.12),
    highlightColor: azure300.withValues(alpha: 0.08),
    bodyTextColor: ink100,
    displayTextColor: ink50,
    borderColor: navy700,
    disabledBorderColor: navy700.withValues(alpha: 0.55),
    focusedBorderColor: azure300,
    inputFillColor: navy850,
    inputHoverColor: azure300.withValues(alpha: 0.06),
    inputHintColor: inkMuted.withValues(alpha: 0.80),
    inputLabelColor: ink200,
    inputFloatingLabelColor: azure200,
    appBarBackgroundColor: navy900,
    appBarForegroundColor: ink100,
    appBarSurfaceTintColor: transparent,
    dividerColor: navy700,
    drawerBackgroundColor: navy900,
  );
}
