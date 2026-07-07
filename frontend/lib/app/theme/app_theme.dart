import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_dark_theme_palette.dart';
import 'package:hosspi_hms/app/theme/app_font_family.dart';
import 'package:hosspi_hms/app/theme/app_light_theme_palette.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_palette.dart';

abstract final class AppTheme {
  static ThemeData get light => _buildTheme(AppLightThemePalette.palette);

  static ThemeData get dark => _buildTheme(AppDarkThemePalette.palette);

  static ThemeData _buildTheme(AppThemePalette palette) {
    final ColorScheme colorScheme = palette.colorScheme;
    final Brightness brightness = colorScheme.brightness;
    const AppSpacingTokens spacing = AppSpacingTokens.standard;
    const AppRadiusTokens radius = AppRadiusTokens.standard;
    const AppDesignTokens appTokens = AppDesignTokens.standard;
    const Size minimumControlSize = Size(40, 40);

    // Modern shape language derived from the shared radius tokens so every
    // surface stays uniform: small radius for controls, medium for overlays,
    // large for elevated surfaces.
    final BorderRadius controlRadius = BorderRadius.circular(radius.sm);
    final BorderRadius overlayRadius = BorderRadius.circular(radius.md);
    final BorderRadius surfaceRadius = BorderRadius.circular(radius.lg);
    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: controlRadius,
    );
    final RoundedRectangleBorder overlayShape = RoundedRectangleBorder(
      borderRadius: overlayRadius,
    );
    final RoundedRectangleBorder surfaceShape = RoundedRectangleBorder(
      borderRadius: surfaceRadius,
    );
    // Soft, low-alpha shadow that reads as gentle depth rather than a hard
    // drop shadow on the light/dark surfaces.
    final Color softShadow = colorScheme.shadow.withValues(alpha: 0.12);

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
      borderRadius: controlRadius,
      borderSide: BorderSide(
        color: palette.borderColor,
        width: appTokens.dividerThickness,
      ),
    );
    final OutlineInputBorder focusedInputBorder = OutlineInputBorder(
      borderRadius: controlRadius,
      borderSide: BorderSide(color: palette.focusedBorderColor, width: 1.4),
    );
    final OutlineInputBorder errorInputBorder = OutlineInputBorder(
      borderRadius: controlRadius,
      borderSide: BorderSide(
        color: statusColors.error,
        width: appTokens.dividerThickness,
      ),
    );

    final TextTheme textTheme = baseTextTheme.apply(
      fontFamily: AppFontFamily.primary,
      fontFamilyFallback: AppFontFamily.fallback,
      bodyColor: palette.bodyTextColor,
      displayColor: palette.displayTextColor,
    );
    const TextStyle inputTextStyle = TextStyle(
      fontFamily: AppFontFamily.primary,
      fontFamilyFallback: AppFontFamily.fallback,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppFontFamily.primary,
      fontFamilyFallback: AppFontFamily.fallback,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.scaffoldBackgroundColor,
      canvasColor: palette.canvasColor,
      hoverColor: palette.hoverColor,
      splashColor: palette.splashColor,
      highlightColor: palette.highlightColor,
      shadowColor: softShadow,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: textTheme,
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
        scrolledUnderElevation: 2,
        shadowColor: softShadow,
      ),
      cardTheme: CardThemeData(
        shape: surfaceShape,
        elevation: 1,
        shadowColor: softShadow,
        surfaceTintColor: Colors.transparent,
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
          shape: controlShape,
          elevation: 1,
          shadowColor: softShadow,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minimumControlSize,
          padding: buttonPadding,
          shape: controlShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minimumControlSize,
          padding: buttonPadding,
          shape: controlShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minimumControlSize,
          padding: buttonPadding,
          shape: controlShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(40),
          padding: EdgeInsets.all(spacing.xs),
          shape: controlShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: false,
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
        labelStyle: inputTextStyle.copyWith(
          color: palette.inputLabelColor,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: inputTextStyle.copyWith(
          color: palette.inputFloatingLabelColor,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: inputTextStyle.copyWith(
          color: palette.inputHintColor,
          fontWeight: FontWeight.w400,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: controlShape,
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorShape: controlShape,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: palette.drawerBackgroundColor,
        width: 280,
        elevation: 1,
        shadowColor: softShadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(radius.xl),
            bottomRight: Radius.circular(radius.xl),
          ),
        ),
        endShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(radius.xl),
            bottomLeft: Radius.circular(radius.xl),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: spacing.sm),
        dense: true,
        horizontalTitleGap: spacing.sm,
        minLeadingWidth: 24,
        minTileHeight: 40,
        minVerticalPadding: spacing.xs,
        shape: controlShape,
        visualDensity: VisualDensity.compact,
      ),
      dataTableTheme: DataTableThemeData(
        dataRowMinHeight: 40,
        dataRowMaxHeight: 44,
        headingRowHeight: 40,
        horizontalMargin: spacing.md,
        columnSpacing: spacing.xl,
      ),
      snackBarTheme: SnackBarThemeData(
        shape: controlShape,
        behavior: SnackBarBehavior.floating,
        elevation: 3,
        insetPadding: EdgeInsets.all(spacing.lg),
      ),
      dialogTheme: DialogThemeData(
        shape: surfaceShape,
        elevation: 3,
        shadowColor: softShadow,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: overlayShape,
        elevation: 3,
        shadowColor: softShadow,
        surfaceTintColor: Colors.transparent,
        color: colorScheme.surface,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          shape: WidgetStatePropertyAll<OutlinedBorder>(overlayShape),
          elevation: const WidgetStatePropertyAll<double>(3),
          shadowColor: WidgetStatePropertyAll<Color>(softShadow),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
          backgroundColor: WidgetStatePropertyAll<Color>(colorScheme.surface),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          shape: WidgetStatePropertyAll<OutlinedBorder>(overlayShape),
          elevation: const WidgetStatePropertyAll<double>(3),
          shadowColor: WidgetStatePropertyAll<Color>(softShadow),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
          backgroundColor: WidgetStatePropertyAll<Color>(colorScheme.surface),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface.withValues(alpha: 0.94),
          borderRadius: controlRadius,
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: controlShape,
        side: BorderSide(color: palette.borderColor),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        shadowColor: softShadow,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(radius.xl),
            topRight: Radius.circular(radius.xl),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(shape: controlShape),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        borderRadius: BorderRadius.circular(radius.xs),
      ),
    );
  }
}
