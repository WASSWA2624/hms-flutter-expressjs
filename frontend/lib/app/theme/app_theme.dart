import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_dark_theme_palette.dart';
import 'package:hosspi_hms/app/theme/app_light_theme_palette.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_palette.dart';

abstract final class AppTheme {
  static ThemeData get light => _buildTheme(AppLightThemePalette.palette);

  static ThemeData get dark => _buildTheme(AppDarkThemePalette.palette);

  static ThemeData _buildTheme(AppThemePalette palette) {
    final ColorScheme colorScheme = palette.colorScheme;
    final Brightness brightness = colorScheme.brightness;
    const RoundedRectangleBorder rectangularShape = RoundedRectangleBorder();
    const AppSpacingTokens spacing = AppSpacingTokens.standard;
    const AppDesignTokens appTokens = AppDesignTokens.standard;
    const Size minimumControlSize = Size(40, 40);
    final EdgeInsets buttonPadding = EdgeInsets.symmetric(
      horizontal: spacing.lg,
      vertical: spacing.sm,
    );
    final AppStatusColors statusColors = palette.statusColors;
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
        color: palette.borderColor,
        width: appTokens.dividerThickness,
      ),
    );
    final OutlineInputBorder focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: palette.focusedBorderColor, width: 1.4),
    );
    final OutlineInputBorder errorInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(
        color: statusColors.error,
        width: appTokens.dividerThickness,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.scaffoldBackgroundColor,
      canvasColor: palette.canvasColor,
      hoverColor: palette.hoverColor,
      splashColor: palette.splashColor,
      highlightColor: palette.highlightColor,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textTheme: baseTextTheme.apply(
        bodyColor: palette.bodyTextColor,
        displayColor: palette.displayTextColor,
      ),
      extensions: <ThemeExtension<dynamic>>[
        spacing,
        AppRadiusTokens.standard,
        statusColors,
        appTokens,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.appBarBackgroundColor,
        foregroundColor: palette.appBarForegroundColor,
        surfaceTintColor: palette.appBarSurfaceTintColor,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: const CardThemeData(
        shape: rectangularShape,
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(
        color: palette.dividerColor,
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
        fillColor: palette.inputFillColor,
        hoverColor: palette.inputHoverColor,
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
            color: palette.disabledBorderColor,
            width: appTokens.dividerThickness,
          ),
        ),
        focusedBorder: focusedInputBorder,
        errorBorder: errorInputBorder,
        focusedErrorBorder: errorInputBorder.copyWith(
          borderSide: BorderSide(color: statusColors.error, width: 1.4),
        ),
        labelStyle: TextStyle(
          color: palette.inputLabelColor,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: palette.inputFloatingLabelColor,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: palette.inputHintColor,
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
        backgroundColor: palette.drawerBackgroundColor,
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
}
