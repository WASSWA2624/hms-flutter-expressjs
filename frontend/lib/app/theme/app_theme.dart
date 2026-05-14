import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

abstract final class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);

  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColorFor(brightness),
      brightness: brightness,
    );
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
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        ),
        constraints: BoxConstraints(
          minHeight: appTokens.minInteractiveDimension,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 34,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 34,
        ),
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: statusColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: statusColors.error),
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

  static Color _seedColorFor(Brightness brightness) {
    return switch (brightness) {
      Brightness.light => const Color(0xFF1565C0),
      Brightness.dark => const Color(0xFF90CAF9),
    };
  }
}
