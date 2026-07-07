import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/layout/app_dialog_insets.dart';
import 'package:hosspi_hms/shared/layout/app_shell_layout.dart';

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

    test('maximized mobile padding fills the viewport without outer gutter', () {
      expect(
        AppDialogInsets.paddingFor(
          AppBreakpoint.sm,
          designTokens: tokens,
          maximized: true,
        ),
        EdgeInsets.zero,
      );
    });

    test(
      'maximized desktop padding clears the shell header and snack bar',
      () {
        expect(
          AppDialogInsets.paddingFor(
            AppBreakpoint.lg,
            designTokens: tokens,
            maximized: true,
          ),
          EdgeInsets.only(
            top: AppShellLayout.headerHeight,
            bottom: tokens.dialogSnackBarClearance,
          ),
        );
        expect(
          AppDialogInsets.paddingFor(
            AppBreakpoint.xl,
            designTokens: tokens,
            maximized: true,
          ),
          EdgeInsets.only(
            top: AppShellLayout.headerHeight,
            bottom: tokens.dialogSnackBarClearance,
          ),
        );
      },
    );

    test('available size uses full viewport on mobile when maximized', () {
      final Size available = AppDialogInsets.availableSizeFor(
        const Size(1000, 700),
        AppBreakpoint.sm,
        designTokens: tokens,
        maximized: true,
      );

      expect(available.width, 1000);
      expect(available.height, 700);
    });

    test(
      'available size clears shell header and snack bar when maximized on desktop',
      () {
        final Size available = AppDialogInsets.availableSizeFor(
          const Size(1000, 700),
          AppBreakpoint.lg,
          designTokens: tokens,
          maximized: true,
        );

        expect(available.width, 1000);
        expect(
          available.height,
          700 -
              AppShellLayout.headerHeight -
              tokens.dialogSnackBarClearance,
        );
      },
    );
  });
}
