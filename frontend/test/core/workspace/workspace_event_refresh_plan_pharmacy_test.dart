import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';

void main() {
  group('WorkspaceEventRefreshPlan.forPharmacy', () {
    test('catalog updates reload catalogs and stock, not the order list', () {
      expect(
        RealtimeEventGroups.pharmacyWorkspace,
        contains(RealtimeEvents.pharmacyCatalogUpdated),
      );

      final WorkspaceRefreshPlan plan = WorkspaceEventRefreshPlan.forPharmacy(
        RealtimeEvents.pharmacyCatalogUpdated,
      );

      expect(plan.catalogs, isTrue);
      expect(plan.inventory, isTrue);
      expect(plan.primaryList, isFalse);
      expect(plan.selectedDetail, isFalse);
    });

    test('stock events still refresh orders and inventory', () {
      final WorkspaceRefreshPlan plan = WorkspaceEventRefreshPlan.forPharmacy(
        RealtimeEvents.inventoryStockUpdated,
      );

      expect(plan.primaryList, isTrue);
      expect(plan.inventory, isTrue);
      expect(plan.catalogs, isFalse);
    });
  });
}
