import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/layout/app_dialog_insets.dart';

void main() {
  group('AppDialogInsets', () {
    const AppDesignTokens tokens = AppDesignTokens.standard;

    test('normal padding uses dialog inset tokens per breakpoint', () {
      expect(
        AppDialogInsets.paddingFor(
          AppBreakpoint.sm,
          designTokens: tokens,
          maximized: false,
        ),
        const EdgeInsets.only(left: 12, top: 12, right: 12, bottom: 100),
      );
      expect(
        AppDialogInsets.paddingFor(
          AppBreakpoint.lg,
          designTokens: tokens,
          maximized: false,
        ),
        const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 112),
      );
    });

    test('maximized padding uses maximized inset tokens per breakpoint', () {
      expect(
        AppDialogInsets.paddingFor(
          AppBreakpoint.sm,
          designTokens: tokens,
          maximized: true,
        ),
        const EdgeInsets.only(left: 8, top: 8, right: 8, bottom: 96),
      );
      expect(
        AppDialogInsets.paddingFor(
          AppBreakpoint.xl,
          designTokens: tokens,
          maximized: true,
        ),
        const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 112),
      );
    });

    test('available size subtracts inset padding from viewport', () {
      final Size available = AppDialogInsets.availableSizeFor(
        const Size(1000, 700),
        AppBreakpoint.lg,
        designTokens: tokens,
        maximized: true,
      );

      expect(available.width, 968);
      expect(available.height, 580);
    });
  });
}
