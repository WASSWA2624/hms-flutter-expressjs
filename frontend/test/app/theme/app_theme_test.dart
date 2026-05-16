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
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppLightThemePalette.blue500);
      expect(theme.colorScheme.primaryContainer, AppLightThemePalette.blue50);
      expect(theme.colorScheme.secondary, AppLightThemePalette.blue700);
      expect(theme.colorScheme.tertiary, AppLightThemePalette.blueAccentA400);
      expect(theme.colorScheme.surfaceTint, AppLightThemePalette.blue500);
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
      expect(theme.appTokens.pagePaddingMobile, 12);
      expect(theme.appTokens.pagePaddingTablet, 16);
      expect(theme.appTokens.pagePaddingDesktop, 24);
      expect(theme.appTokens.listIconSize, 20);
      expect(
        theme.statusColors.success,
        AppLightThemePalette.statusColors.success,
      );
      expect(theme.statusColors.info, AppLightThemePalette.statusColors.info);
      expect(
        theme.statusColors.danger,
        AppLightThemePalette.statusColors.danger,
      );
    });

    test('builds dark theme with dark status colors', () {
      final ThemeData theme = AppTheme.dark;

      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppDarkThemePalette.gray100);
      expect(theme.colorScheme.primaryContainer, AppDarkThemePalette.gray700);
      expect(theme.colorScheme.secondary, AppDarkThemePalette.gray300);
      expect(theme.colorScheme.tertiary, AppDarkThemePalette.grayAccentA400);
      expect(theme.colorScheme.surfaceTint, AppDarkThemePalette.gray100);
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
    });
  });
}
