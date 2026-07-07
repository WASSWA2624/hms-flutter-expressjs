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
      'maximized desktop padding clears only the shell header',
      () {
        expect(
          AppDialogInsets.paddingFor(
            AppBreakpoint.lg,
            designTokens: tokens,
            maximized: true,
          ),
          const EdgeInsets.only(top: AppShellLayout.headerHeight),
        );
        expect(
          AppDialogInsets.paddingFor(
            AppBreakpoint.xl,
            designTokens: tokens,
            maximized: true,
          ),
          const EdgeInsets.only(top: AppShellLayout.headerHeight),
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
      'available size clears shell header when maximized on desktop',
      () {
        final Size available = AppDialogInsets.availableSizeFor(
          const Size(1000, 700),
          AppBreakpoint.lg,
          designTokens: tokens,
          maximized: true,
        );

        expect(available.width, 1000);
        expect(available.height, 700 - AppShellLayout.headerHeight);
      },
    );
  });
}
