import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_dark_theme_palette.dart';
import 'package:hosspi_hms/app/theme/app_light_theme_palette.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_palette.dart';

abstract final class AppTheme {
  static final ThemeData light = _buildTheme(AppLightThemePalette.palette);

  static final ThemeData dark = _buildTheme(AppDarkThemePalette.palette);

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
    final AppSidebarTokens sidebarTokens = _sidebarTokens(
      palette: palette,
      radius: radius,
      softShadow: softShadow,
    );

    final EdgeInsets buttonPadding = EdgeInsets.symmetric(
      horizontal: spacing.lg,
      vertical: spacing.sm,
    );
    final AppStatusColors statusColors = palette.statusColors;
    final AppBorderTokens borders = AppBorderTokens(
      thin: appTokens.dividerThickness,
      medium: 1.4,
      thick: 2,
      // Default decorative border: softest palette stroke (thin + faint).
      faint: palette.disabledBorderColor,
      subtle: palette.borderColor,
      strong: colorScheme.outline,
      focused: palette.focusedBorderColor,
      selected: colorScheme.primary,
      disabled: palette.disabledBorderColor,
      error: statusColors.error,
    );
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
      // Resting controls: thin + faint (default AppBorderTokens.side).
      borderSide: borders.side(),
    );
    final OutlineInputBorder focusedInputBorder = OutlineInputBorder(
      borderRadius: controlRadius,
      borderSide: borders.side(
        tone: AppBorderTone.focused,
        weight: AppBorderWeight.medium,
      ),
    );
    final OutlineInputBorder errorInputBorder = OutlineInputBorder(
      borderRadius: controlRadius,
      borderSide: borders.side(tone: AppBorderTone.error),
    );

    final TextTheme textTheme = _withAppFontWeights(
      baseTextTheme.apply(
        fontFamily: AppFontFamily.primary,
        fontFamilyFallback: AppFontFamily.fallback,
        bodyColor: palette.bodyTextColor,
        displayColor: palette.displayTextColor,
      ),
    );
    final TextStyle inputTextStyle = AppFontFamily.style(
      fontWeight: AppFontWeight.label,
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
      primaryTextTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        spacing,
        AppRadiusTokens.standard,
        borders,
        statusColors,
        appTokens,
        AppFontTokens.standard,
        AppListTokens.compact(
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        sidebarTokens,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.appBarBackgroundColor,
        foregroundColor: palette.appBarForegroundColor,
        surfaceTintColor: palette.appBarSurfaceTintColor,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: softShadow,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: palette.appBarForegroundColor,
          fontWeight: AppFontWeight.title,
        ),
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
        thickness: borders.thin,
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
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minimumControlSize,
          padding: buttonPadding,
          shape: controlShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minimumControlSize,
          padding: buttonPadding,
          shape: controlShape,
          side: borders.side(),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minimumControlSize,
          padding: buttonPadding,
          shape: controlShape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: AppFontWeight.emphasis,
          ),
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
          borderSide: borders.side(tone: AppBorderTone.disabled),
        ),
        focusedBorder: focusedInputBorder,
        errorBorder: errorInputBorder,
        focusedErrorBorder: errorInputBorder.copyWith(
          borderSide: borders.side(
            tone: AppBorderTone.error,
            weight: AppBorderWeight.medium,
          ),
        ),
        // Empty-field labels must read as placeholders (light + muted), not
        // as entered values. Hints stay lightest; floating labels stay ≤ regular.
        labelStyle: inputTextStyle.copyWith(
          color: palette.inputHintColor,
          fontWeight: AppFontWeight.label,
          fontSize: 14,
          height: 1.5,
        ),
        floatingLabelStyle: inputTextStyle.copyWith(
          color: palette.inputFloatingLabelColor,
          fontWeight: AppFontWeight.regular,
        ),
        hintStyle: inputTextStyle.copyWith(
          color: palette.inputHintColor,
          fontWeight: AppFontWeight.label,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(indicatorShape: controlShape),
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
        dataRowMaxHeight: 48,
        headingRowHeight: 48,
        horizontalMargin: spacing.md,
        columnSpacing: spacing.lg,
        dividerThickness: borders.thin,
        headingRowColor: WidgetStatePropertyAll<Color>(
          colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
        ),
        headingTextStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: AppFontWeight.emphasis,
          letterSpacing: 0.1,
        ),
        dataTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: AppFontWeight.body,
        ),
        dataRowColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.hovered)) {
            return colorScheme.primary.withValues(alpha: 0.05);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.08);
          }
          return null;
        }),
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
        side: borders.side(),
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

  /// Applies the light-first [AppFontWeight] roles across Material text roles
  /// so every platform inherits thin/light defaults from the theme.
  static TextTheme _withAppFontWeights(TextTheme theme) {
    TextStyle? apply(TextStyle? style, FontWeight weight) {
      if (style == null) {
        return null;
      }
      return style.copyWith(fontWeight: weight);
    }

    return theme.copyWith(
      displayLarge: apply(theme.displayLarge, AppFontWeight.display),
      displayMedium: apply(theme.displayMedium, AppFontWeight.display),
      displaySmall: apply(theme.displaySmall, AppFontWeight.thin),
      headlineLarge: apply(theme.headlineLarge, AppFontWeight.light),
      headlineMedium: apply(theme.headlineMedium, AppFontWeight.light),
      headlineSmall: apply(theme.headlineSmall, AppFontWeight.light),
      titleLarge: apply(theme.titleLarge, AppFontWeight.title),
      titleMedium: apply(theme.titleMedium, AppFontWeight.title),
      titleSmall: apply(theme.titleSmall, AppFontWeight.regular),
      bodyLarge: apply(theme.bodyLarge, AppFontWeight.body),
      bodyMedium: apply(theme.bodyMedium, AppFontWeight.body),
      bodySmall: apply(theme.bodySmall, AppFontWeight.light),
      labelLarge: apply(theme.labelLarge, AppFontWeight.regular),
      labelMedium: apply(theme.labelMedium, AppFontWeight.label),
      labelSmall: apply(theme.labelSmall, AppFontWeight.label),
    );
  }

  static AppSidebarTokens _sidebarTokens({
    required AppThemePalette palette,
    required AppRadiusTokens radius,
    required Color softShadow,
  }) {
    final ColorScheme colors = palette.colorScheme;

    return AppSidebarTokens(
      backgroundColor: palette.drawerBackgroundColor,
      shadowColor: softShadow,
      elevation: 1,
      itemHeight: 40,
      itemBorderRadius: radius.md,
      selectedBackgroundColor: colors.primaryContainer,
      selectedForegroundColor: colors.primary,
      hoverBackgroundColor: colors.primary.withValues(alpha: 0.07),
      hoverForegroundColor: colors.primary,
      defaultForegroundColor: colors.onSurfaceVariant,
      focusBorderColor: colors.primary.withValues(alpha: 0.56),
      badgeAccentBackgroundColor: colors.tertiaryContainer,
      badgeAccentForegroundColor: colors.onTertiaryContainer,
    );
  }
}
