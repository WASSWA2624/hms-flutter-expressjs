import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_dark_theme_palette.dart';
import 'package:hosspi_hms/app/theme/app_light_theme_palette.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

void main() {
  group('AppTheme', () {
    test('builds light theme with app design token extensions', () {
      final ThemeData theme = AppTheme.light;

      expect(theme.useMaterial3, isTrue);
      expect(theme.textTheme.bodyMedium?.fontFamily, AppFontFamily.primary);
      expect(
        theme.textTheme.bodyMedium?.fontFamilyFallback,
        AppFontFamily.fallback,
      );
      expect(theme.textTheme.bodyMedium?.fontWeight, AppFontWeight.body);
      expect(theme.textTheme.titleMedium?.fontWeight, AppFontWeight.title);
      expect(theme.textTheme.labelLarge?.fontWeight, AppFontWeight.regular);
      expect(theme.textTheme.displayLarge?.fontWeight, AppFontWeight.display);
      expect(theme.textTheme.headlineMedium?.fontWeight, AppFontWeight.light);
      expect(theme.fonts.family, AppFontFamily.primary);
      expect(theme.fonts.body, AppFontWeight.body);
      expect(theme.fonts.emphasis, AppFontWeight.emphasis);
      expect(
        theme.inputDecorationTheme.labelStyle?.fontWeight,
        AppFontWeight.light,
      );
      expect(
        theme.inputDecorationTheme.floatingLabelStyle?.fontWeight,
        AppFontWeight.regular,
      );
      expect(
        theme.inputDecorationTheme.hintStyle?.fontWeight,
        AppFontWeight.light,
      );
      expect(theme.inputDecorationTheme.hintStyle?.fontSize, 14);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppLightThemePalette.azure700);
      expect(theme.colorScheme.primaryContainer, AppLightThemePalette.azure50);
      expect(theme.colorScheme.secondary, AppLightThemePalette.azure800);
      expect(theme.colorScheme.tertiary, AppLightThemePalette.teal500);
      expect(theme.colorScheme.surface, AppLightThemePalette.surfaceRaised);
      expect(theme.colorScheme.onSurface, AppLightThemePalette.ink);
      expect(theme.colorScheme.surfaceTint, AppLightThemePalette.transparent);
      expect(
        theme.scaffoldBackgroundColor,
        AppLightThemePalette.palette.scaffoldBackgroundColor,
      );
      expect(
        theme.textTheme.bodyMedium?.color,
        AppLightThemePalette.palette.bodyTextColor,
      );
      expect(
        theme.dividerTheme.color,
        AppLightThemePalette.palette.dividerColor,
      );
      expect(theme.spacing.xs, 4);
      expect(theme.spacing.sm, 8);
      expect(theme.spacing.md, 12);
      expect(theme.spacing.lg, 16);
      expect(theme.spacing.xl, 24);
      expect(theme.spacing.xxl, 32);
      expect(theme.radius.xs, 4);
      expect(theme.radius.sm, 8);
      expect(theme.radius.md, 10);
      expect(theme.radius.lg, 12);
      expect(theme.radius.xl, 16);
      expect(theme.appTokens.pagePaddingMobile, 16);
      expect(theme.appTokens.pagePaddingTablet, 24);
      expect(theme.appTokens.pagePaddingDesktop, 32);
      expect(theme.appTokens.dialogInsetMobile, 12);
      expect(theme.appTokens.dialogInsetTablet, 24);
      expect(theme.appTokens.dialogInsetDesktop, 24);
      expect(theme.appTokens.dialogSnackBarClearance, 88);
      expect(theme.appTokens.dialogMinWidth, 360);
      expect(theme.appTokens.dialogMinHeight, 280);
      expect(theme.appTokens.listIconSize, 20);
      expect(theme.listTokens.mobileTitle.fontWeight, AppListTokens.mobileTitleWeight);
      expect(
        theme.listTokens.mobileTitle.fontSize,
        (theme.textTheme.bodyLarge?.fontSize ?? 15).clamp(14, 16).toDouble(),
      );
      expect(
        theme.listTokens.mobileCaption.fontWeight,
        AppListTokens.mobileSecondaryWeight,
      );
      expect(
        theme.listTokens.mobileCaption.fontSize,
        theme.textTheme.bodySmall?.fontSize ??
            theme.textTheme.labelMedium?.fontSize ??
            12,
      );
      expect(
        theme.listTokens.mobileMeta.fontWeight,
        AppListTokens.mobileSecondaryWeight,
      );
      expect(
        theme.listTokens.mobileAvatarSize,
        AppListTokens.mobileAvatarExtent,
      );
      expect(
        theme.statusColors.success,
        AppLightThemePalette.statusColors.success,
      );
      expect(theme.statusColors.info, AppLightThemePalette.statusColors.info);
      expect(
        theme.statusColors.danger,
        AppLightThemePalette.statusColors.danger,
      );
      expect(
        theme.sidebarTokens.selectedBackgroundColor,
        theme.colorScheme.primaryContainer,
      );
      expect(
        theme.sidebarTokens.selectedForegroundColor,
        theme.colorScheme.primary,
      );
      expect(theme.sidebarTokens.itemHeight, 40);
      expect(theme.sidebarTokens.itemBorderRadius, theme.radius.md);
      expect(
        theme.sidebarTokens.badgeAccentBackgroundColor,
        theme.colorScheme.tertiaryContainer,
      );
      expect(theme.borders.thin, 1);
      expect(theme.borders.medium, 1.4);
      expect(theme.borders.thick, 2);
      expect(theme.borders.faint, AppLightThemePalette.palette.disabledBorderColor);
      expect(theme.borders.subtle, AppLightThemePalette.palette.borderColor);
      expect(theme.borders.focused, AppLightThemePalette.palette.focusedBorderColor);
      expect(theme.borders.selected, theme.colorScheme.primary);
      expect(theme.borders.side().width, theme.borders.thin);
      expect(theme.borders.side().color, theme.borders.faint);
      expect(
        theme.borders.side(
          tone: AppBorderTone.focused,
          weight: AppBorderWeight.medium,
        ).width,
        theme.borders.medium,
      );
    });

    test('builds dark theme with dark status colors', () {
      final ThemeData theme = AppTheme.dark;

      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppDarkThemePalette.azure300);
      expect(
        theme.colorScheme.primaryContainer,
        AppDarkThemePalette.azureContainer,
      );
      expect(theme.colorScheme.secondary, AppDarkThemePalette.azure200);
      expect(theme.colorScheme.tertiary, AppDarkThemePalette.teal300);
      expect(theme.colorScheme.surface, AppDarkThemePalette.navy900);
      expect(theme.colorScheme.onSurface, AppDarkThemePalette.ink100);
      expect(theme.colorScheme.surfaceTint, AppDarkThemePalette.transparent);
      expect(
        theme.scaffoldBackgroundColor,
        AppDarkThemePalette.palette.scaffoldBackgroundColor,
      );
      expect(
        theme.textTheme.bodyMedium?.color,
        AppDarkThemePalette.palette.bodyTextColor,
      );
      expect(
        theme.dividerTheme.color,
        AppDarkThemePalette.palette.dividerColor,
      );
      expect(
        theme.statusColors.success,
        AppDarkThemePalette.statusColors.success,
      );
      expect(theme.statusColors.info, AppDarkThemePalette.statusColors.info);
      expect(
        theme.statusColors.danger,
        AppDarkThemePalette.statusColors.danger,
      );
      expect(theme.appTokens.minInteractiveDimension, 40);
      expect(theme.borders.faint, AppDarkThemePalette.palette.disabledBorderColor);
      expect(theme.borders.subtle, AppDarkThemePalette.palette.borderColor);
      expect(theme.borders.selected, theme.colorScheme.primary);
    });
  });
}
