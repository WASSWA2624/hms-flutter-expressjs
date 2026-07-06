import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';

abstract final class AppDialogInsets {
  static EdgeInsets paddingFor(
    AppBreakpoint breakpoint, {
    required AppDesignTokens designTokens,
    required bool maximized,
  }) {
    final double horizontalInset = _horizontalInsetFor(
      breakpoint,
      designTokens: designTokens,
      maximized: maximized,
    );
    final double topInset = maximized
        ? horizontalInset
        : _normalTopInsetFor(breakpoint, designTokens: designTokens);

    return EdgeInsets.only(
      left: horizontalInset,
      top: topInset,
      right: horizontalInset,
      bottom: horizontalInset + designTokens.dialogSnackBarClearance,
    );
  }

  static EdgeInsets paddingForContext(
    BuildContext context, {
    required bool maximized,
  }) {
    final ThemeData theme = Theme.of(context);
    return paddingFor(
      AppBreakpoints.of(context),
      designTokens: theme.appTokens,
      maximized: maximized,
    );
  }

  static Size availableSizeFor(
    Size viewport,
    AppBreakpoint breakpoint, {
    required AppDesignTokens designTokens,
    required bool maximized,
  }) {
    final EdgeInsets insetPadding = paddingFor(
      breakpoint,
      designTokens: designTokens,
      maximized: maximized,
    );

    return Size(
      (viewport.width - insetPadding.horizontal)
          .clamp(designTokens.dialogMinWidth, viewport.width)
          .toDouble(),
      (viewport.height - insetPadding.vertical)
          .clamp(designTokens.dialogMinHeight, viewport.height)
          .toDouble(),
    );
  }

  static double _horizontalInsetFor(
    AppBreakpoint breakpoint, {
    required AppDesignTokens designTokens,
    required bool maximized,
  }) {
    if (maximized) {
      return switch (breakpoint) {
        AppBreakpoint.xs || AppBreakpoint.sm =>
          designTokens.dialogMaximizedInsetMobile,
        AppBreakpoint.md || AppBreakpoint.lg =>
          designTokens.dialogMaximizedInsetTablet,
        AppBreakpoint.xl || AppBreakpoint.xxl =>
          designTokens.dialogMaximizedInsetDesktop,
      };
    }

    return _normalTopInsetFor(breakpoint, designTokens: designTokens);
  }

  static double _normalTopInsetFor(
    AppBreakpoint breakpoint, {
    required AppDesignTokens designTokens,
  }) {
    return switch (breakpoint) {
      AppBreakpoint.xs || AppBreakpoint.sm => designTokens.dialogInsetMobile,
      AppBreakpoint.md || AppBreakpoint.lg => designTokens.dialogInsetTablet,
      AppBreakpoint.xl || AppBreakpoint.xxl => designTokens.dialogInsetDesktop,
    };
  }
}
