import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/components/app_clinical_results_preview.dart';
import 'package:hosspi_hms/shared/components/app_status_badge.dart';

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
      const AppClinicalResultsPreview(isEmpty: true, child: SizedBox.shrink()),
    );

    expect(find.text('No results to preview'), findsOneWidget);
  });

  testWidgets('shows forbidden and error states with retry', (
    WidgetTester tester,
  ) async {
    var retried = false;
    await pumpComponent(
      tester,
      AppClinicalResultsPreview(
        isForbidden: true,
        child: const SizedBox.shrink(),
      ),
    );
    expect(find.text('Results are not available'), findsOneWidget);

    await pumpComponent(
      tester,
      AppClinicalResultsPreview(
        failure: const AppFailure.network(),
        onRetry: () => retried = true,
        child: const SizedBox.shrink(),
      ),
    );
    expect(find.text('Results could not be loaded'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('fullScreen mode wraps content in expanded safe area', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppClinicalResultsPreview(
        mode: AppClinicalResultsPreviewMode.fullScreen,
        title: 'Full report',
        status: AppClinicalResultStatus.preliminary,
        child: Text('Draft findings'),
      ),
      size: const Size(900, 1200),
    );

    expect(find.byType(SafeArea), findsWidgets);
    expect(find.text('Full report'), findsOneWidget);
    expect(find.text('Draft findings'), findsOneWidget);
    expect(find.text('Preliminary'), findsOneWidget);
  });

  testWidgets('status vocabulary uses non-color badges', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppClinicalResultsPreview(
        status: AppClinicalResultStatus.corrected,
        child: Text('Amended report'),
      ),
    );

    expect(find.text('Corrected'), findsOneWidget);
    expect(find.byType(AppStatusBadge), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_outlined), findsOneWidget);
  });

  testWidgets('print action appears only when eligible', (
    WidgetTester tester,
  ) async {
    var printed = false;
    await pumpComponent(
      tester,
      AppClinicalResultsPreview(
        printEligible: false,
        onPrint: () => printed = true,
        child: const Text('Hidden print'),
      ),
    );
    expect(find.text('Print'), findsNothing);

    await pumpComponent(
      tester,
      AppClinicalResultsPreview(
        printEligible: true,
        onPrint: () => printed = true,
        child: const Text('Ready to print'),
      ),
    );
    expect(find.text('Print'), findsOneWidget);
    await tester.tap(find.text('Print'));
    expect(printed, isTrue);
  });

  testWidgets('print eligibility ignores selection state helper', (
    WidgetTester tester,
  ) async {
    expect(
      appClinicalResultsPrintEligible(
        authorized: true,
        hasPrintableReleasedContent: true,
      ),
      isTrue,
    );
    expect(
      appClinicalResultsPrintEligible(
        authorized: true,
        hasPrintableReleasedContent: false,
      ),
      isFalse,
    );
    expect(
      appClinicalResultsPrintEligible(
        authorized: false,
        hasPrintableReleasedContent: true,
      ),
      isFalse,
    );
  });

  testWidgets('chronological list sorts and renders module adapters', (
    WidgetTester tester,
  ) async {
    final DateTime older = DateTime.utc(2026, 1, 1, 10);
    final DateTime newer = DateTime.utc(2026, 1, 2, 10);

    await pumpComponent(
      tester,
      AppClinicalResultsPreview(
        title: 'Encounter results',
        encounterPublicId: 'ENC-100',
        child: AppClinicalResultsPreviewList(
          entries: <AppClinicalResultPreviewEntry>[
            AppClinicalResultPreviewEntry(
              id: 'lab-1',
              module: AppClinicalResultModule.laboratory,
              title: 'Hemoglobin',
              status: AppClinicalResultStatus.verified,
              occurredAt: older,
              laboratory: const AppClinicalLaboratoryResultContent(
                value: '13.2',
                unit: 'g/dL',
                referenceRange: '12.0-15.0',
                flag: AppClinicalResultFlag.normal,
              ),
            ),
            AppClinicalResultPreviewEntry(
              id: 'rad-1',
              module: AppClinicalResultModule.radiology,
              title: 'Chest X-Ray',
              status: AppClinicalResultStatus.corrected,
              occurredAt: newer,
              radiology: const AppClinicalRadiologyReportContent(
                reportText: 'No acute infiltrate.',
                modality: 'XR',
              ),
            ),
            const AppClinicalResultPreviewEntry(
              id: 'proc-1',
              module: AppClinicalResultModule.procedure,
              title: 'Wound care',
              status: AppClinicalResultStatus.preliminary,
              procedure: AppClinicalProcedureResultContent(
                findings: 'Dressing applied',
                performedBy: 'Nurse A',
              ),
            ),
            const AppClinicalResultPreviewEntry(
              id: 'assess-1',
              module: AppClinicalResultModule.clinicalAssessment,
              title: 'Admission assessment',
              status: AppClinicalResultStatus.verified,
              assessment: AppClinicalAssessmentResultContent(
                summary: 'Stable',
                assessor: 'Dr. B',
              ),
            ),
          ],
        ),
      ),
      size: const Size(1000, 1400),
    );

    expect(find.text('Encounter ENC-100'), findsOneWidget);
    expect(find.text('Chest X-Ray'), findsOneWidget);
    expect(find.text('Hemoglobin'), findsOneWidget);
    expect(find.text('13.2 g/dL'), findsOneWidget);
    expect(find.text('Reference range: 12.0-15.0'), findsOneWidget);
    expect(find.text('No acute infiltrate.'), findsOneWidget);
    expect(find.text('Dressing applied'), findsOneWidget);
    expect(find.text('Performed by Nurse A'), findsOneWidget);
    expect(find.text('Stable'), findsOneWidget);
    expect(find.text('Assessed by Dr. B'), findsOneWidget);
    expect(find.text('Laboratory'), findsWidgets);
    expect(find.text('Radiology'), findsWidgets);
    expect(find.text('Critical'), findsNothing);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    // Newer radiology entry should appear before older lab entry.
    final double radY = tester.getTopLeft(find.text('Chest X-Ray')).dy;
    final double labY = tester.getTopLeft(find.text('Hemoglobin')).dy;
    expect(radY < labY, isTrue);
  });

  testWidgets('abnormal and critical flags use icon cues', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppClinicalResultsPreviewList(
        entries: const <AppClinicalResultPreviewEntry>[
          AppClinicalResultPreviewEntry(
            id: 'a',
            module: AppClinicalResultModule.laboratory,
            title: 'Potassium',
            status: AppClinicalResultStatus.verified,
            laboratory: AppClinicalLaboratoryResultContent(
              value: '6.1',
              unit: 'mmol/L',
              flag: AppClinicalResultFlag.critical,
            ),
          ),
          AppClinicalResultPreviewEntry(
            id: 'b',
            module: AppClinicalResultModule.laboratory,
            title: 'Sodium',
            status: AppClinicalResultStatus.verified,
            laboratory: AppClinicalLaboratoryResultContent(
              value: '148',
              unit: 'mmol/L',
              flag: AppClinicalResultFlag.abnormal,
            ),
          ),
        ],
      ),
    );

    expect(find.text('Critical'), findsOneWidget);
    expect(find.text('Abnormal'), findsOneWidget);
    expect(find.byIcon(Icons.priority_high), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
  });

  testWidgets('modal mode renders status chrome without fullscreen wrapper', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppClinicalResultsPreview(
        mode: AppClinicalResultsPreviewMode.modal,
        title: 'Modal results',
        status: AppClinicalResultStatus.unavailable,
        child: Text('Unavailable content'),
      ),
    );

    expect(find.text('Modal results'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Unavailable content'), findsOneWidget);
    expect(find.byType(SafeArea), findsNothing);
  });
}
