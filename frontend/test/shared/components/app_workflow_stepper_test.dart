import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_workflow_stepper.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('renders semantic workflow step states', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppWorkflowStepper(
        steps: const <AppWorkflowStepItem>[
          AppWorkflowStepItem(
            id: 'triage',
            label: 'Triage',
            state: AppWorkflowStepState.completed,
          ),
          AppWorkflowStepItem(
            id: 'consult',
            label: 'Consult',
            state: AppWorkflowStepState.current,
            description: 'In progress',
            blockedReason: 'Awaiting labs',
          ),
          AppWorkflowStepItem(
            id: 'discharge',
            label: 'Discharge',
            state: AppWorkflowStepState.upcoming,
          ),
          AppWorkflowStepItem(
            id: 'billing',
            label: 'Billing',
            state: AppWorkflowStepState.unavailable,
          ),
        ],
      ),
      size: const Size(1000, 600),
    );

    expect(find.text('Triage'), findsOneWidget);
    expect(find.text('Consult'), findsOneWidget);
    expect(find.text('Discharge'), findsOneWidget);
    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Awaiting labs'), findsOneWidget);
  });
}
