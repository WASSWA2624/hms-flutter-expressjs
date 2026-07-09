import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_layout.dart';

void main() {
  group('dashboardMetricColumnCount', () {
    test('desktop uses one column per card for 2–4 cards', () {
      expect(dashboardMetricColumnCount(1200, 2), 2);
      expect(dashboardMetricColumnCount(1200, 3), 3);
      expect(dashboardMetricColumnCount(1200, 4), 4);
    });

    test('tablet caps at two columns', () {
      expect(dashboardMetricColumnCount(900, 4), 2);
      expect(dashboardMetricColumnCount(900, 2), 2);
      expect(dashboardMetricColumnCount(900, 1), 1);
    });

    test('mobile uses single column below 340px', () {
      expect(dashboardMetricColumnCount(320, 4), 1);
    });
  });

  group('dashboardQuickActionColumnCount', () {
    test('desktop lays out all actions in one row', () {
      expect(dashboardQuickActionColumnCount(1200, 3), 3);
      expect(dashboardQuickActionColumnCount(1200, 2), 2);
    });

    test('tablet caps at two columns', () {
      expect(dashboardQuickActionColumnCount(900, 3), 2);
      expect(dashboardQuickActionColumnCount(900, 2), 2);
    });

    test('narrow screens cap at two columns then one', () {
      expect(dashboardQuickActionColumnCount(400, 3), 2);
      expect(dashboardQuickActionColumnCount(320, 3), 1);
    });
  });
}
