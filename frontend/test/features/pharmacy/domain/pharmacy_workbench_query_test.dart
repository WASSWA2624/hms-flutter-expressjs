import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';

void main() {
  group('PharmacyWorkbenchQuery', () {
    test('defaults to all statuses with no active filters', () {
      const PharmacyWorkbenchQuery query = PharmacyWorkbenchQuery();

      expect(query.status, isNull);
      expect(query.isDefaultFilters, isTrue);
    });

    test('ready chip applies ORDERED status filter', () {
      final PharmacyWorkbenchQuery query = PharmacyWorkbenchQuery.fromChip(
        PharmacyOrderFilter.ready,
      );

      expect(query.status, 'ORDERED');
      expect(query.isDefaultFilters, isFalse);
    });

    test('all chip clears status filter', () {
      final PharmacyWorkbenchQuery query = PharmacyWorkbenchQuery.fromChip(
        PharmacyOrderFilter.all,
      );

      expect(query.status, isNull);
      expect(query.isDefaultFilters, isTrue);
    });
  });

  group('PharmacyWorkspaceQuery', () {
    test('parses section=queue from URI', () {
      final PharmacyWorkspaceQuery query = PharmacyWorkspaceQuery.fromUri(
        Uri.parse('/pharmacy?section=queue'),
      );

      expect(query.section, 'queue');
      expect(query.hasRouteTargeting, isTrue);
      expect(query.signature, contains('queue'));
    });

    test('parses section=pending from URI', () {
      final PharmacyWorkspaceQuery query = PharmacyWorkspaceQuery.fromUri(
        Uri.parse('/pharmacy?section=pending'),
      );

      expect(query.section, 'pending');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('parses from/to date range from URI', () {
      final PharmacyWorkspaceQuery query = PharmacyWorkspaceQuery.fromUri(
        Uri.parse(
          '/pharmacy?section=completed&from=2026-08-06T00:00:00.000Z&to=2026-08-07T00:00:00.000Z',
        ),
      );

      expect(query.section, 'completed');
      expect(query.from, isNotNull);
      expect(query.to, isNotNull);
      expect(query.hasDateRange, isTrue);
      expect(query.signature, contains('2026-08-06'));
    });

    test('parses section=in-progress with search', () {
      final PharmacyWorkspaceQuery query = PharmacyWorkspaceQuery.fromUri(
        Uri.parse('/pharmacy?section=in-progress&search=Noah'),
      );

      expect(query.section, 'in-progress');
      expect(query.search, 'Noah');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('parses inventory section for catalog deep link', () {
      final PharmacyWorkspaceQuery query = PharmacyWorkspaceQuery.fromUri(
        Uri.parse('/pharmacy?section=inventory'),
      );

      expect(query.section, 'inventory');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('empty query has no route targeting', () {
      final PharmacyWorkspaceQuery query = PharmacyWorkspaceQuery.fromUri(
        Uri.parse('/pharmacy'),
      );

      expect(query.section, isEmpty);
      expect(query.hasRouteTargeting, isFalse);
    });
  });

  group('PharmacyDeskSection', () {
    test('exposes order, catalog, and stock desk worklist sections', () {
      expect(PharmacyDeskSection.values, hasLength(11));
      expect(
        PharmacyDeskSection.values,
        containsAll(<PharmacyDeskSection>[
          PharmacyDeskSection.queue,
          PharmacyDeskSection.inProgress,
          PharmacyDeskSection.pendingPayment,
          PharmacyDeskSection.completed,
          PharmacyDeskSection.cancelled,
          PharmacyDeskSection.allOrders,
          PharmacyDeskSection.catalog,
          PharmacyDeskSection.nearExpiry,
          PharmacyDeskSection.expired,
          PharmacyDeskSection.lowStock,
          PharmacyDeskSection.outOfStock,
        ]),
      );
    });

    test('maps stock sections to inventory queries and order sections to null', () {
      expect(PharmacyDeskSection.queue.isStockSection, isFalse);
      expect(PharmacyDeskSection.nearExpiry.isStockSection, isTrue);
      expect(PharmacyDeskSection.queue.stockQuery, isNull);
      expect(
        PharmacyDeskSection.expired.stockQuery?.expiredOnly,
        isTrue,
      );
      expect(
        PharmacyDeskSection.outOfStock.stockQuery?.stockStatus,
        'OUT_OF_STOCK',
      );
    });

    test('catalog section is neither an order nor a stock-alert worklist', () {
      expect(PharmacyDeskSection.catalog.isCatalogSection, isTrue);
      expect(PharmacyDeskSection.catalog.isStockSection, isFalse);
      expect(PharmacyDeskSection.catalog.stockQuery, isNull);
      expect(PharmacyDeskSection.queue.isCatalogSection, isFalse);
    });
  });
}
