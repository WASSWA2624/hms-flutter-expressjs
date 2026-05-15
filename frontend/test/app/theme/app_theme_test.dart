import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

void main() {
  group('AppTheme', () {
    test('builds light theme with app design token extensions', () {
      final ThemeData theme = AppTheme.light;
      final ColorScheme expectedColorScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF1565C0),
      );

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, expectedColorScheme.primary);
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
    });

    test('builds dark theme with dark status colors', () {
      final ThemeData theme = AppTheme.dark;
      final ColorScheme expectedColorScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF90CAF9),
        brightness: Brightness.dark,
      );

      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, expectedColorScheme.primary);
      expect(theme.statusColors.success, AppStatusColors.dark.success);
      expect(theme.statusColors.info, AppStatusColors.dark.info);
      expect(theme.appTokens.minInteractiveDimension, 40);
    });
  });
}
