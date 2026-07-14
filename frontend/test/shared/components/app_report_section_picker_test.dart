import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_report_section.dart';
import 'package:hosspi_hms/shared/components/app_report_section_picker.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('does not toggle disabled empty sections', (
    WidgetTester tester,
  ) async {
    Set<Object> selected = <Object>{'labs'};

    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AppReportSectionPicker(
            sections: const <AppReportSectionData>[
              AppReportSectionData(
                id: 'labs',
                title: 'Laboratory',
                icon: Icons.science_outlined,
                count: 2,
              ),
              AppReportSectionData(
                id: 'billing',
                title: 'Billing',
                icon: Icons.payments_outlined,
                count: 0,
                enabled: false,
                disabledReason: 'No data available',
              ),
            ],
            selectedIds: selected,
            onSelectionChanged: (Set<Object> next) {
              setState(() => selected = next);
            },
          );
        },
      ),
    );

    await tester.tap(find.text('Billing'));
    await tester.pumpAndSettle();

    expect(selected.contains('billing'), isFalse);
    expect(selected.contains('labs'), isTrue);
  });
}
