import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_light_theme_palette.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

void main() {
  group('AppTheme', () {
    test('builds light theme with app design token extensions', () {
      final ThemeData theme = AppTheme.light;

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppLightThemePalette.shade500);
      expect(theme.colorScheme.primaryContainer, AppLightThemePalette.shade50);
      expect(theme.colorScheme.secondary, AppLightThemePalette.shade700);
      expect(theme.colorScheme.tertiary, AppLightThemePalette.accentA400);
      expect(theme.colorScheme.surfaceTint, AppLightThemePalette.shade500);
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
      expect(theme.statusColors.success, AppStatusColors.light.success);
      expect(theme.statusColors.info, AppLightThemePalette.shade700);
    });

    test('builds dark theme with dark status colors', () {
      final ThemeData theme = AppTheme.dark;

      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppLightThemePalette.shade200);
      expect(theme.colorScheme.primaryContainer, AppLightThemePalette.shade800);
      expect(theme.colorScheme.secondary, AppLightThemePalette.shade300);
      expect(theme.colorScheme.tertiary, AppLightThemePalette.accentA100);
      expect(theme.colorScheme.surfaceTint, AppLightThemePalette.shade200);
      expect(theme.statusColors.success, AppStatusColors.dark.success);
      expect(theme.statusColors.info, AppLightThemePalette.shade200);
      expect(theme.appTokens.minInteractiveDimension, 40);
    });
  });
}
