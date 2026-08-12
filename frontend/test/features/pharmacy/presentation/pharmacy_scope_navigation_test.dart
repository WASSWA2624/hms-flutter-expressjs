import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_scope_navigation.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

PharmacyWorkspaceState _state({
  int orderedQueue = 5,
  int partiallyDispensedQueue = 3,
  int pendingPaymentQueue = 2,
  int dispensedOrders = 8,
  int cancelledOrders = 1,
  int totalOrders = 19,
  int? ordersTotalItemCount,
  int suppliersTotal = 4,
  int expiringSoonRows = 6,
  int expiredRows = 2,
  int lowStockRows = 7,
  int outOfStockRows = 3,
}) {
  return PharmacyWorkspaceState(
    query: const PharmacyWorkbenchQuery(),
    workbench: PharmacyWorkbench(
      summary: PharmacyWorkbenchSummary(
        orderedQueue: orderedQueue,
        partiallyDispensedQueue: partiallyDispensedQueue,
        pendingPaymentQueue: pendingPaymentQueue,
        dispensedOrders: dispensedOrders,
        cancelledOrders: cancelledOrders,
        totalOrders: totalOrders,
      ),
      orders: AppPage<PharmacyOrder>(
        items: const <PharmacyOrder>[],
        request: const AppPageRequest(),
        totalItemCount: ordersTotalItemCount,
      ),
    ),
    drugQuery: const PharmacyDrugQuery(),
    drugs: const AppPage<PharmacyDrug>(
      items: <PharmacyDrug>[],
      request: AppPageRequest(),
    ),
    formularyQuery: const PharmacyFormularyQuery(),
    formularyItems: const AppPage<PharmacyFormularyItem>(
      items: <PharmacyFormularyItem>[],
      request: AppPageRequest(),
    ),
    inventoryQuery: const PharmacyInventoryStockQuery(),
    inventoryWorkbench: const PharmacyInventoryWorkbench(
      summary: PharmacyInventoryStockSummary(),
      stocks: AppPage<PharmacyInventoryStock>(
        items: <PharmacyInventoryStock>[],
        request: AppPageRequest(),
      ),
    ),
    suppliers: AppPage<PharmacySupplier>(
      items: const <PharmacySupplier>[],
      request: const AppPageRequest(),
      totalItemCount: suppliersTotal,
    ),
    stockAlertSummary: PharmacyInventoryStockSummary(
      expiringSoonRows: expiringSoonRows,
      expiredRows: expiredRows,
      lowStockRows: lowStockRows,
      outOfStockRows: outOfStockRows,
    ),
  );
}

void main() {
  group('pharmacySectionFromQuery / pharmacySectionToQueryValue', () {
    test('round-trips canonical section query values', () {
      for (final PharmacyDeskSection section in PharmacyDeskSection.values) {
        final String query = pharmacySectionToQueryValue(section);
        expect(pharmacySectionFromQuery(query), section);
      }
    });

    test('accepts Ready / inventory aliases from the tab index', () {
      expect(pharmacySectionFromQuery('ready'), PharmacyDeskSection.queue);
      expect(pharmacySectionFromQuery('inventory'), PharmacyDeskSection.catalog);
      expect(
        pharmacySectionFromQuery('pending-payment'),
        PharmacyDeskSection.pendingPayment,
      );
    });
  });

  group('pharmacySectionTabCount', () {
    test('siblings use dedicated summary / stock / supplier totals', () {
      final PharmacyWorkspaceState state = _state(
        orderedQueue: 5,
        partiallyDispensedQueue: 3,
        pendingPaymentQueue: 2,
        dispensedOrders: 8,
        cancelledOrders: 1,
        totalOrders: 19,
        ordersTotalItemCount: 1,
        suppliersTotal: 4,
        expiringSoonRows: 6,
        expiredRows: 2,
        lowStockRows: 7,
        outOfStockRows: 3,
      );

      expect(pharmacySectionTabCount(state, PharmacyDeskSection.queue), 5);
      expect(pharmacySectionTabCount(state, PharmacyDeskSection.inProgress), 3);
      expect(
        pharmacySectionTabCount(state, PharmacyDeskSection.pendingPayment),
        2,
      );
      expect(pharmacySectionTabCount(state, PharmacyDeskSection.completed), 8);
      expect(pharmacySectionTabCount(state, PharmacyDeskSection.cancelled), 1);
      expect(pharmacySectionTabCount(state, PharmacyDeskSection.allOrders), 19);
      expect(pharmacySectionTabCount(state, PharmacyDeskSection.suppliers), 4);
      expect(pharmacySectionTabCount(state, PharmacyDeskSection.nearExpiry), 6);
      expect(pharmacySectionTabCount(state, PharmacyDeskSection.expired), 2);
      expect(pharmacySectionTabCount(state, PharmacyDeskSection.lowStock), 7);
      expect(pharmacySectionTabCount(state, PharmacyDeskSection.outOfStock), 3);
      expect(pharmacySectionTabCount(state, PharmacyDeskSection.catalog), 0);
    });

    test('active order tab uses filtered list totalItemCount', () {
      final PharmacyWorkspaceState state = _state(
        orderedQueue: 5,
        partiallyDispensedQueue: 3,
        ordersTotalItemCount: 1,
      );

      expect(
        pharmacySectionTabCount(
          state,
          PharmacyDeskSection.queue,
          activeSection: PharmacyDeskSection.queue,
        ),
        1,
      );
      expect(
        pharmacySectionTabCount(
          state,
          PharmacyDeskSection.inProgress,
          activeSection: PharmacyDeskSection.queue,
        ),
        3,
      );
    });
  });

  group('pharmacySectionCountTone', () {
    test('warning / danger only for attention queues', () {
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.queue),
        AppTabCountTone.warning,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.inProgress),
        AppTabCountTone.warning,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.pendingPayment),
        AppTabCountTone.warning,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.nearExpiry),
        AppTabCountTone.warning,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.lowStock),
        AppTabCountTone.warning,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.cancelled),
        AppTabCountTone.danger,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.expired),
        AppTabCountTone.danger,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.outOfStock),
        AppTabCountTone.danger,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.completed),
        AppTabCountTone.info,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.allOrders),
        AppTabCountTone.info,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.suppliers),
        AppTabCountTone.info,
      );
      expect(
        pharmacySectionCountTone(PharmacyDeskSection.catalog),
        AppTabCountTone.info,
      );
    });
  });
}
