import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_clinical_results_preview.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('shows status badge and content', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      const AppClinicalResultsPreview(
        title: 'Lab results',
        status: AppClinicalResultStatus.verified,
        child: Text('Hemoglobin 13.2'),
      ),
    );

    expect(find.text('Lab results'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Hemoglobin 13.2'), findsOneWidget);
  });

  testWidgets('shows empty state', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      const AppClinicalResultsPreview(
        isEmpty: true,
        child: SizedBox.shrink(),
      ),
    );

    expect(find.text('No results to preview'), findsOneWidget);
  });
}
