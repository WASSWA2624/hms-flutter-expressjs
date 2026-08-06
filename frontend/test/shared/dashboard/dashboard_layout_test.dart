import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_layout.dart';

void main() {
  group('dashboardMetricColumnsForWidth', () {
    test('maps mobile tablet and desktop budgets', () {
      expect(dashboardMetricColumnsForWidth(AppBreakpoints.md - 1), 1);
      expect(dashboardMetricColumnsForWidth(320), 1);
      expect(dashboardMetricColumnsForWidth(AppBreakpoints.md), 3);
      expect(dashboardMetricColumnsForWidth(900), 3);
      expect(dashboardMetricColumnsForWidth(AppBreakpoints.xl - 1), 3);
      expect(dashboardMetricColumnsForWidth(AppBreakpoints.xl), 5);
      expect(dashboardMetricColumnsForWidth(1600), 5);
    });
  });

  group('dashboardMetricColumnCount', () {
    test('desktop caps at five columns', () {
      expect(dashboardMetricColumnCount(1200, 2), 2);
      expect(dashboardMetricColumnCount(1200, 3), 3);
      expect(dashboardMetricColumnCount(1200, 4), 4);
      expect(dashboardMetricColumnCount(1200, 5), 5);
      expect(dashboardMetricColumnCount(1200, 9), 5);
    });

    test('tablet caps at three columns', () {
      expect(dashboardMetricColumnCount(900, 4), 3);
      expect(dashboardMetricColumnCount(900, 2), 2);
      expect(dashboardMetricColumnCount(900, 1), 1);
    });

    test('mobile uses single column below md breakpoint', () {
      expect(dashboardMetricColumnCount(AppBreakpoints.md - 1, 4), 1);
      expect(dashboardMetricColumnCount(320, 4), 1);
    });
  });

  group('dashboardQuickActionColumnCount', () {
    test('desktop lays out all actions in one row', () {
      expect(dashboardQuickActionColumnCount(1200, 3), 3);
      expect(dashboardQuickActionColumnCount(1200, 2), 2);
      expect(dashboardQuickActionColumnCount(1200, 5), 5);
      expect(dashboardQuickActionColumnCount(1200, 8), 8);
    });

    test('tablet lays out all actions in one row', () {
      expect(dashboardQuickActionColumnCount(900, 3), 3);
      expect(dashboardQuickActionColumnCount(900, 2), 2);
      expect(dashboardQuickActionColumnCount(900, 4), 4);
    });

    test('mobile uses single column below md breakpoint', () {
      expect(dashboardQuickActionColumnCount(AppBreakpoints.md - 1, 3), 1);
      expect(dashboardQuickActionColumnCount(320, 3), 1);
    });
  });
}
