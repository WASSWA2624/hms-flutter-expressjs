import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('AppReportActionButton uses standard print affordance', (
    WidgetTester tester,
  ) async {
    var printCount = 0;

    await pumpComponent(
      tester,
      AppReportActionButton.print(
        label: 'Print report',
        onPressed: () {
          printCount += 1;
        },
      ),
    );

    expect(find.byIcon(Icons.print_outlined), findsOneWidget);

    await tester.tap(find.text('Print report'));
    await tester.pump();

    expect(printCount, 1);
  });

  testWidgets('AppReportSummaryGrid renders compact report metrics', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppReportSummaryGrid(
        records: <AppReportSummaryItem>[
          AppReportSummaryItem(
            label: 'Encounters',
            value: '3',
            icon: Icons.medical_services_outlined,
          ),
          AppReportSummaryItem(
            label: 'Invoices',
            value: '1',
            icon: Icons.receipt_long_outlined,
          ),
        ],
      ),
      size: const Size(700, 500),
    );

    expect(find.text('Encounters'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
  });

  testWidgets('AppReportPreviewPanel exposes selectable preview content', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppReportPreviewPanel(
        title: 'Preview',
        selectable: true,
        child: Text('Generated report body'),
      ),
    );

    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Generated report body'), findsOneWidget);
    expect(find.byType(SelectionArea), findsOneWidget);
  });
}
