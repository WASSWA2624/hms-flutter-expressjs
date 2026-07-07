import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/layout/app_shell_layout.dart';

abstract final class AppDialogInsets {
  static EdgeInsets paddingFor(
    AppBreakpoint breakpoint, {
    required AppDesignTokens designTokens,
    required bool maximized,
  }) {
    if (maximized) {
      return _maximizedPaddingFor(
        breakpoint,
        designTokens: designTokens,
      );
    }

    final double inset = _normalInsetFor(
      breakpoint,
      designTokens: designTokens,
    );

    return EdgeInsets.only(
      left: inset,
      top: inset,
      right: inset,
      bottom: inset + designTokens.dialogSnackBarClearance,
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

  static EdgeInsets _maximizedPaddingFor(
    AppBreakpoint breakpoint, {
    required AppDesignTokens designTokens,
  }) {
    if (breakpoint.index < AppBreakpoint.md.index) {
      return EdgeInsets.zero;
    }

    return EdgeInsets.only(
      top: AppShellLayout.headerHeight,
      bottom: designTokens.dialogSnackBarClearance,
    );
  }

  static double _normalInsetFor(
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
