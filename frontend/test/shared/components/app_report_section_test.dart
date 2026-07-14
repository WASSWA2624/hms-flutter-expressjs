import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_report_section.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('toggles report section selection', (WidgetTester tester) async {
    Set<Object> selected = <Object>{'labs'};

    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AppReportSectionList(
            sections: const <AppReportSectionData>[
              AppReportSectionData(
                id: 'labs',
                title: 'Laboratory',
                icon: Icons.science_outlined,
                count: 3,
              ),
              AppReportSectionData(
                id: 'radiology',
                title: 'Radiology',
                icon: Icons.image_outlined,
                count: 1,
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

    expect(find.text('Laboratory'), findsOneWidget);
    expect(find.text('Radiology'), findsOneWidget);

    await tester.tap(find.text('Radiology'));
    await tester.pumpAndSettle();

    expect(selected.contains('radiology'), isTrue);
  });
}
