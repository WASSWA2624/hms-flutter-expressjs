import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('RadiologyWorkspaceQuery', () {
    test('parses section and search deep links', () {
      final RadiologyWorkspaceQuery query = RadiologyWorkspaceQuery.fromUri(
        Uri.parse('/radiology?section=reporting&search=Ada'),
      );

      expect(query.section, 'reporting');
      expect(query.search, 'Ada');
      expect(query.hasRouteTargeting, isTrue);
      expect(query.signature, contains('reporting'));
    });

    test('accepts section aliases panel and tab', () {
      expect(
        RadiologyWorkspaceQuery.fromUri(
          Uri.parse('/radiology?panel=worklist'),
        ).section,
        'worklist',
      );
      expect(
        RadiologyWorkspaceQuery.fromUri(
          Uri.parse('/radiology?tab=released'),
        ).section,
        'released',
      );
      expect(
        RadiologyWorkspaceQuery.fromUri(
          Uri.parse('/radiology?section=all'),
        ).section,
        'all',
      );
    });

    test('empty uri has no route targeting', () {
      final RadiologyWorkspaceQuery query = RadiologyWorkspaceQuery.fromUri(
        Uri.parse('/radiology'),
      );

      expect(query.section, isEmpty);
      expect(query.hasRouteTargeting, isFalse);
    });

    test('copyWith preserves and updates section', () {
      const RadiologyWorkspaceQuery base = RadiologyWorkspaceQuery(
        section: 'worklist',
      );
      expect(base.copyWith(section: 'reporting').section, 'reporting');
      expect(base.copyWith(search: 'x').section, 'worklist');
    });
  });

  group('RadiologyDeskSection', () {
    test('exposes expected desk tabs', () {
      expect(RadiologyDeskSection.values, <RadiologyDeskSection>[
        RadiologyDeskSection.worklist,
        RadiologyDeskSection.reporting,
        RadiologyDeskSection.released,
        RadiologyDeskSection.allOrders,
        RadiologyDeskSection.followUps,
      ]);
    });
  });

  group('RadiologyWorkspaceState section counts', () {
    test('maps summary fields for patients and orders views', () {
      const RadiologySummary summary = RadiologySummary(
        totalOrders: 12,
        orderedQueue: 3,
        processingQueue: 2,
        draftReports: 4,
        finalizedReports: 5,
        amendedReports: 1,
        totalPatients: 8,
        actionablePatients: 6,
        reportingPatients: 2,
        releasedPatients: 3,
      );
      const AppPage<RadiologyOrder> emptyOrders = AppPage<RadiologyOrder>(
        items: <RadiologyOrder>[],
        request: AppPageRequest(),
        totalItemCount: 0,
      );

      const RadiologyWorkspaceState patientsState = RadiologyWorkspaceState(
        orders: emptyOrders,
        summary: summary,
        references: RadiologyReferenceData(),
        query: RadiologyWorkspaceQuery(),
      );
      expect(patientsState.workloadCount, 6);
      expect(patientsState.reportingCount, 2);
      expect(patientsState.releasedCount, 3);
      expect(summary.totalForView(RadiologyWorkbenchView.patients), 8);

      const RadiologyWorkspaceState ordersState = RadiologyWorkspaceState(
        orders: emptyOrders,
        summary: summary,
        references: RadiologyReferenceData(),
        query: RadiologyWorkspaceQuery(view: RadiologyWorkbenchView.orders),
      );
      expect(ordersState.workloadCount, 9);
      expect(ordersState.reportingCount, 4);
      expect(ordersState.releasedCount, 6);
      expect(summary.totalForView(RadiologyWorkbenchView.orders), 12);
    });
  });
}
