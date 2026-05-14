import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppBreakpoints', () {
    test('maps widths to breakpoint tokens', () {
      expect(AppBreakpoints.fromWidth(320), AppBreakpoint.xs);
      expect(AppBreakpoints.fromWidth(359.9), AppBreakpoint.xs);
      expect(AppBreakpoints.fromWidth(360), AppBreakpoint.sm);
      expect(AppBreakpoints.fromWidth(599.9), AppBreakpoint.sm);
      expect(AppBreakpoints.fromWidth(600), AppBreakpoint.md);
      expect(AppBreakpoints.fromWidth(839.9), AppBreakpoint.md);
      expect(AppBreakpoints.fromWidth(840), AppBreakpoint.lg);
      expect(AppBreakpoints.fromWidth(1199.9), AppBreakpoint.lg);
      expect(AppBreakpoints.fromWidth(1200), AppBreakpoint.xl);
      expect(AppBreakpoints.fromWidth(1599.9), AppBreakpoint.xl);
      expect(AppBreakpoints.fromWidth(1600), AppBreakpoint.xxl);
    });

    test('exposes adaptive navigation decisions', () {
      expect(AppBreakpoint.xs.isMobile, isTrue);
      expect(AppBreakpoint.sm.isMobile, isTrue);
      expect(AppBreakpoint.md.supportsNavigationRail, isTrue);
      expect(AppBreakpoint.md.supportsExtendedNavigationRail, isFalse);
      expect(AppBreakpoint.lg.supportsExtendedNavigationRail, isTrue);
      expect(AppBreakpoint.xl.supportsExtendedNavigationRail, isTrue);
      expect(AppBreakpoint.xxl.supportsExtendedNavigationRail, isTrue);
    });
  });
}
