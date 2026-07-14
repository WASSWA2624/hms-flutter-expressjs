import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/reporting/report_section_selection.dart';

void main() {
  group('report section selection', () {
    test('defaults to enabled sections only', () {
      const List<ReportSectionAvailability> sections =
          <ReportSectionAvailability>[
            ReportSectionAvailability(
              id: 'patient_information',
              count: 1,
              alwaysAvailable: true,
            ),
            ReportSectionAvailability(id: 'vitals', count: 0),
            ReportSectionAvailability(id: 'laboratory_results', count: 3),
            ReportSectionAvailability(
              id: 'billing_information',
              count: 2,
              authorized: false,
            ),
          ];

      final Set<Object> selected = resolveDefaultReportSectionSelection(
        sections,
      );

      expect(selected, <Object>{'patient_information', 'laboratory_results'});
      expect(selected.contains('vitals'), isFalse);
      expect(selected.contains('billing_information'), isFalse);
    });

    test('sanitizes selection when sections become empty', () {
      const List<ReportSectionAvailability> sections =
          <ReportSectionAvailability>[
            ReportSectionAvailability(id: 'vitals', count: 0),
            ReportSectionAvailability(id: 'laboratory_results', count: 2),
          ];

      final Set<Object> selected = sanitizeReportSectionSelection(
        selectedIds: <Object>{'vitals', 'laboratory_results'},
        sections: sections,
      );

      expect(selected, <Object>{'laboratory_results'});
    });

    test('builds disabled tiles for empty sections', () {
      final tiles = buildReportSectionTiles(
        sections: const <ReportSectionAvailability>[
          ReportSectionAvailability(id: 'vitals', count: 0),
          ReportSectionAvailability(id: 'laboratory_results', count: 1),
        ],
        titleFor: (Object id) => id.toString(),
        iconFor: (Object id) => Icons.science_outlined,
        emptyDisabledReason: 'No data available',
      );

      expect(tiles.first.enabled, isFalse);
      expect(tiles.first.disabledReason, 'No data available');
      expect(tiles.last.enabled, isTrue);
    });
  });
}
