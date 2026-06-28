import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_info_sheet.dart';

import 'component_test_app.dart';

void main() {
  const List<AppInfoSheetItem> sampleItems = <AppInfoSheetItem>[
    AppInfoSheetItem(label: 'Staff number', value: 'STF-001', copyable: true),
    AppInfoSheetItem(label: 'Position', value: 'Nurse'),
    AppInfoSheetItem(label: 'Department', value: 'Emergency'),
    AppInfoSheetItem(label: 'Hire date', value: 'Jan 1, 2024'),
  ];

  Future<void> pumpGrid(WidgetTester tester, double width) async {
    await pumpComponent(
      tester,
      SizedBox(
        width: width,
        child: const AppInfoSheetGrid(items: sampleItems),
      ),
      size: Size(width, 400),
    );
  }

  double wrapChildWidth(WidgetTester tester, int index) {
    final Finder child = find
        .descendant(
          of: find.byType(Wrap),
          matching: find.byType(SizedBox),
        )
        .at(index);
    final RenderBox box = tester.renderObject<RenderBox>(child);
    return box.size.width;
  }

  testWidgets('AppInfoSheetGrid uses one column at narrow width', (
    WidgetTester tester,
  ) async {
    await pumpGrid(tester, 360);

    expect(find.text('Staff number'), findsOneWidget);
    expect(find.text('STF-001'), findsOneWidget);
    expect(wrapChildWidth(tester, 0), greaterThan(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppInfoSheetGrid uses multiple columns at wide width', (
    WidgetTester tester,
  ) async {
    await pumpGrid(tester, 800);

    expect(find.text('Staff number'), findsOneWidget);
    expect(find.text('Hire date'), findsOneWidget);
    expect(wrapChildWidth(tester, 0), lessThan(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppInfoSheetRow copies copyable values', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppInfoSheetRow(
        label: 'Staff number',
        value: 'STF-001',
        copyable: true,
        copiedMessage: 'Copied.',
      ),
    );

    expect(find.text('Staff number'), findsOneWidget);
    expect(find.text('STF-001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
