import 'package:flutter/widgets.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';

abstract final class ResponsiveSpacing {
  static EdgeInsets pagePaddingFor(
    AppBreakpoint breakpoint, {
    required AppDesignTokens designTokens,
  }) {
    final padding = pagePaddingValueFor(breakpoint, designTokens: designTokens);

    return EdgeInsets.symmetric(horizontal: padding, vertical: padding);
  }

  static double pagePaddingValueFor(
    AppBreakpoint breakpoint, {
    required AppDesignTokens designTokens,
  }) {
    return switch (breakpoint) {
      AppBreakpoint.xs || AppBreakpoint.sm => designTokens.pagePaddingMobile,
      AppBreakpoint.md || AppBreakpoint.lg => designTokens.pagePaddingTablet,
      AppBreakpoint.xl || AppBreakpoint.xxl => designTokens.pagePaddingDesktop,
    };
  }

  static double sectionGapFor(
    AppBreakpoint breakpoint, {
    required AppSpacingTokens spacing,
  }) {
    return switch (breakpoint) {
      AppBreakpoint.xs || AppBreakpoint.sm => spacing.xl,
      AppBreakpoint.md || AppBreakpoint.lg => spacing.xxl,
      AppBreakpoint.xl || AppBreakpoint.xxl => spacing.xxl,
    };
  }

  static double contentGapFor(
    AppBreakpoint breakpoint, {
    required AppSpacingTokens spacing,
  }) {
    return switch (breakpoint) {
      AppBreakpoint.xs => spacing.md,
      AppBreakpoint.sm || AppBreakpoint.md => spacing.lg,
      AppBreakpoint.lg || AppBreakpoint.xl || AppBreakpoint.xxl => spacing.xl,
    };
  }
}
