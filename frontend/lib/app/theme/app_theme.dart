import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_light_theme_palette.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

abstract final class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final ColorScheme colorScheme = _blueColorSchemeFor(brightness);
    const RoundedRectangleBorder rectangularShape = RoundedRectangleBorder();
    const AppSpacingTokens spacing = AppSpacingTokens.standard;
    const AppDesignTokens appTokens = AppDesignTokens.standard;
    const Size minimumControlSize = Size(40, 40);
    final EdgeInsets buttonPadding = EdgeInsets.symmetric(
      horizontal: spacing.lg,
      vertical: spacing.sm,
    );
    final AppStatusColors statusColors = switch (brightness) {
      Brightness.light => AppStatusColors.light,
      Brightness.dark => AppStatusColors.dark,
    };
    final TextTheme baseTextTheme = switch (brightness) {
      Brightness.light => Typography.material2021(
        colorScheme: colorScheme,
      ).black,
      Brightness.dark => Typography.material2021(
        colorScheme: colorScheme,
      ).white,
    };
    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(
        color: colorScheme.outlineVariant,
        width: appTokens.dividerThickness,
      ),
    );
    final OutlineInputBorder focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
    );
    final OutlineInputBorder errorInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(
        color: statusColors.error,
        width: appTokens.dividerThickness,
      ),
    );
    final Color inputFillColor = colorScheme.surfaceContainerLowest;
    final Color inputHoverColor = colorScheme.primary.withValues(alpha: 0.04);
    final Color inputHintColor = colorScheme.onSurfaceVariant.withValues(
      alpha: brightness == Brightness.light ? 0.58 : 0.7,
    );
    final Color inputLabelColor = colorScheme.onSurfaceVariant.withValues(
      alpha: brightness == Brightness.light ? 0.86 : 0.9,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      canvasColor: colorScheme.surface,
      hoverColor: colorScheme.surfaceContainerHighest,
      splashColor: colorScheme.primary.withValues(alpha: 0.08),
      highlightColor: colorScheme.primary.withValues(alpha: 0.06),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textTheme: baseTextTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      extensions: <ThemeExtension<dynamic>>[
        spacing,
        AppRadiusTokens.standard,
        statusColors,
        appTokens,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: const CardThemeData(
        shape: rectangularShape,
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: appTokens.dividerThickness,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: minimumControlSize,
          padding: buttonPadding,
          shape: rectangularShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minimumControlSize,
          padding: buttonPadding,
          shape: rectangularShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minimumControlSize,
          padding: buttonPadding,
          shape: rectangularShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minimumControlSize,
          padding: buttonPadding,
          shape: rectangularShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(40),
          padding: EdgeInsets.all(spacing.xs),
          shape: rectangularShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: inputFillColor,
        hoverColor: inputHoverColor,
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: 13,
        ),
        constraints: const BoxConstraints(minHeight: 48),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            width: appTokens.dividerThickness,
          ),
        ),
        focusedBorder: focusedInputBorder,
        errorBorder: errorInputBorder,
        focusedErrorBorder: errorInputBorder.copyWith(
          borderSide: BorderSide(color: statusColors.error, width: 1.4),
        ),
        labelStyle: TextStyle(
          color: inputLabelColor,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: inputHintColor,
          fontWeight: FontWeight.w400,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        indicatorShape: rectangularShape,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        indicatorShape: rectangularShape,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        width: 280,
        shape: rectangularShape,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: spacing.sm),
        dense: true,
        horizontalTitleGap: spacing.sm,
        minLeadingWidth: 24,
        minTileHeight: 40,
        minVerticalPadding: spacing.xs,
        shape: rectangularShape,
        visualDensity: VisualDensity.compact,
      ),
      dataTableTheme: DataTableThemeData(
        dataRowMinHeight: 40,
        dataRowMaxHeight: 44,
        headingRowHeight: 40,
        horizontalMargin: spacing.md,
        columnSpacing: spacing.xl,
      ),
      snackBarTheme: const SnackBarThemeData(
        shape: rectangularShape,
        behavior: SnackBarBehavior.fixed,
      ),
      dialogTheme: const DialogThemeData(shape: rectangularShape),
    );
  }

  static ColorScheme _blueColorSchemeFor(Brightness brightness) {
    final ColorScheme baseColorScheme = ColorScheme.fromSeed(
      seedColor: AppLightThemePalette.shade500,
      brightness: brightness,
    );

    return switch (brightness) {
      Brightness.light => baseColorScheme.copyWith(
        primary: AppLightThemePalette.shade500,
        onPrimary: Colors.white,
        primaryContainer: AppLightThemePalette.shade50,
        onPrimaryContainer: AppLightThemePalette.shade900,
        primaryFixed: AppLightThemePalette.shade100,
        primaryFixedDim: AppLightThemePalette.shade200,
        onPrimaryFixed: AppLightThemePalette.shade900,
        onPrimaryFixedVariant: AppLightThemePalette.shade700,
        secondary: AppLightThemePalette.shade700,
        onSecondary: Colors.white,
        secondaryContainer: AppLightThemePalette  .shade100,
        onSecondaryContainer: AppLightThemePalette  .shade900,
        secondaryFixed: AppLightThemePalette.shade100,
        secondaryFixedDim: AppLightThemePalette.shade200,
        onSecondaryFixed: AppLightThemePalette.shade900,
        onSecondaryFixedVariant: AppLightThemePalette.shade700,
        tertiary: AppLightThemePalette.accentA400,
        onTertiary: Colors.white,
        tertiaryContainer: AppLightThemePalette.accentA100,
        onTertiaryContainer: AppLightThemePalette.shade900,
        tertiaryFixed: AppLightThemePalette.accentA100,
        tertiaryFixedDim: AppLightThemePalette.accentA200,
        onTertiaryFixed: AppLightThemePalette.shade900,
        onTertiaryFixedVariant: AppLightThemePalette.accentA700,
        inversePrimary: AppLightThemePalette.shade200,
        surfaceTint: AppLightThemePalette.shade500,
      ),
      Brightness.dark => baseColorScheme.copyWith(
        primary: AppLightThemePalette.shade200,
        onPrimary: AppLightThemePalette.shade900,
        primaryContainer: AppLightThemePalette.shade800,
        onPrimaryContainer: AppLightThemePalette.shade50,
        primaryFixed: AppLightThemePalette.shade100,
        primaryFixedDim: AppLightThemePalette.shade200,
        onPrimaryFixed: AppLightThemePalette.shade900,
        onPrimaryFixedVariant: AppLightThemePalette.shade700,
        secondary: AppLightThemePalette.shade300,
        onSecondary: AppLightThemePalette.shade900,
        secondaryContainer: AppLightThemePalette.shade700,
        onSecondaryContainer: AppLightThemePalette.shade50,
        secondaryFixed: AppLightThemePalette.shade100,
        secondaryFixedDim: AppLightThemePalette.shade200,
        onSecondaryFixed: AppLightThemePalette.shade900,
        onSecondaryFixedVariant: AppLightThemePalette.shade700,
        tertiary: AppLightThemePalette.accentA100,
        onTertiary: AppLightThemePalette.shade900,
        tertiaryContainer: AppLightThemePalette.accentA700,
        onTertiaryContainer: AppLightThemePalette.shade50,
        tertiaryFixed: AppLightThemePalette.accentA100,
        tertiaryFixedDim: AppLightThemePalette.accentA200,
        onTertiaryFixed: AppLightThemePalette.shade900,
        onTertiaryFixedVariant: AppLightThemePalette.accentA700,
        inversePrimary: AppLightThemePalette.shade500,
        surfaceTint: AppLightThemePalette.shade200,
      ),
    };
  }
}
