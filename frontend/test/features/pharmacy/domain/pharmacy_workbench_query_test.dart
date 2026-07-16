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
    test('exposes five desk worklist sections', () {
      expect(PharmacyDeskSection.values, hasLength(5));
      expect(
        PharmacyDeskSection.values,
        containsAll(<PharmacyDeskSection>[
          PharmacyDeskSection.queue,
          PharmacyDeskSection.inProgress,
          PharmacyDeskSection.pendingPayment,
          PharmacyDeskSection.completed,
          PharmacyDeskSection.allOrders,
        ]),
      );
    });
  });
}
