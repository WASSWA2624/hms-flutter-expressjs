import 'package:flutter/widgets.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';

abstract final class ResponsiveSpacing {
  static EdgeInsets pagePaddingFor(
    AppBreakpoint breakpoint, {
    required AppDesignTokens designTokens,
  }) {
    // Minimal side inset only; top/bottom stay flush so tab strips can sit
    // against the app bar and content can reach the bottom edge.
    return EdgeInsets.symmetric(
      horizontal: AppSpacingTokens.standard.xs,
    );
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
      AppBreakpoint.xs || AppBreakpoint.sm || AppBreakpoint.md => spacing.lg,
      AppBreakpoint.lg || AppBreakpoint.xl || AppBreakpoint.xxl => spacing.xl,
    };
  }

  static double contentGapFor(
    AppBreakpoint breakpoint, {
    required AppSpacingTokens spacing,
  }) {
    return switch (breakpoint) {
      AppBreakpoint.xs || AppBreakpoint.sm || AppBreakpoint.md => spacing.md,
      AppBreakpoint.lg || AppBreakpoint.xl || AppBreakpoint.xxl => spacing.lg,
    };
  }

  static double compactContentGapFor(
    AppBreakpoint breakpoint, {
    required AppSpacingTokens spacing,
  }) {
    return switch (breakpoint) {
      AppBreakpoint.xs || AppBreakpoint.sm => spacing.sm,
      AppBreakpoint.md ||
      AppBreakpoint.lg ||
      AppBreakpoint.xl ||
      AppBreakpoint.xxl => spacing.sm,
    };
  }
}
