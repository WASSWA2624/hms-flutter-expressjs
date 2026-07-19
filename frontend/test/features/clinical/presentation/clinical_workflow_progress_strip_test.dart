import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/presentation/widgets/clinical_encounter_detail_panels.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import '../../../shared/components/component_test_app.dart';

void main() {
  testWidgets('uses one shared compact journey for current and next steps', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const ClinicalWorkflowProgressStrip(
        handoff: ClinicalTriageHandoff(
          stage: 'WAITING_VITALS',
          nextStep: 'ASSIGN_DOCTOR',
          timeline: <ClinicalWorkflowTimelineItem>[
            ClinicalWorkflowTimelineItem(
              action: 'CHECK_IN',
              stage: 'WAITING_CONSULTATION_PAYMENT',
            ),
            ClinicalWorkflowTimelineItem(
              action: 'RECORD_VITALS',
              stage: 'WAITING_VITALS',
            ),
          ],
        ),
      ),
      size: const Size(360, 640),
    );

    expect(find.byType(AppWorkflowStepper), findsOneWidget);
    expect(find.text('Current stage'), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);
    expect(find.text('Vitals needed'), findsOneWidget);
    expect(find.text('Assign doctor'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
