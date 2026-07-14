import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/layout/responsive_spacing.dart';

void main() {
  group('ResponsiveSpacing', () {
    test('resolves page padding from design tokens by breakpoint', () {
      const AppDesignTokens tokens = AppDesignTokens.standard;

      expect(
        ResponsiveSpacing.pagePaddingValueFor(
          AppBreakpoint.xs,
          designTokens: tokens,
        ),
        tokens.pagePaddingMobile,
      );
      expect(
        ResponsiveSpacing.pagePaddingValueFor(
          AppBreakpoint.md,
          designTokens: tokens,
        ),
        tokens.pagePaddingTablet,
      );
      expect(
        ResponsiveSpacing.pagePaddingValueFor(
          AppBreakpoint.xl,
          designTokens: tokens,
        ),
        tokens.pagePaddingDesktop,
      );
      expect(tokens.pagePaddingMobile, 16);
      expect(tokens.pagePaddingTablet, 24);
      expect(tokens.pagePaddingDesktop, 32);
    });

    test('resolves section and content gaps from spacing tokens', () {
      final ThemeData theme = AppTheme.light;

      expect(
        ResponsiveSpacing.sectionGapFor(
          AppBreakpoint.sm,
          spacing: theme.spacing,
        ),
        theme.spacing.lg,
      );
      expect(
        ResponsiveSpacing.sectionGapFor(
          AppBreakpoint.xl,
          spacing: theme.spacing,
        ),
        theme.spacing.xl,
      );
      expect(
        ResponsiveSpacing.contentGapFor(
          AppBreakpoint.md,
          spacing: theme.spacing,
        ),
        theme.spacing.md,
      );
      expect(
        ResponsiveSpacing.contentGapFor(
          AppBreakpoint.lg,
          spacing: theme.spacing,
        ),
        theme.spacing.lg,
      );
    });
  });
}
