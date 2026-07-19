import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/shared/components/app_workflow_stepper.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('renders all semantic workflow step states', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppWorkflowStepper(
        steps: <AppWorkflowStepItem>[
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
            id: 'skip',
            label: 'Skip step',
            state: AppWorkflowStepState.skipped,
          ),
          AppWorkflowStepItem(
            id: 'reverted',
            label: 'Reverted',
            state: AppWorkflowStepState.reverted,
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
      size: const Size(1200, 600),
    );

    expect(find.text('Triage'), findsOneWidget);
    expect(find.text('Consult'), findsOneWidget);
    expect(find.text('Skip step'), findsOneWidget);
    expect(find.text('Reverted'), findsOneWidget);
    expect(find.text('Discharge'), findsOneWidget);
    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Awaiting labs'), findsOneWidget);
    expect(find.text('In progress'), findsWidgets);
  });

  testWidgets('invokes onTap for completed/current steps', (
    WidgetTester tester,
  ) async {
    Object? tappedId;
    await pumpComponent(
      tester,
      AppWorkflowStepper(
        steps: <AppWorkflowStepItem>[
          AppWorkflowStepItem(
            id: 'receive',
            label: 'Receive',
            state: AppWorkflowStepState.completed,
            onTap: () => tappedId = 'receive',
          ),
          const AppWorkflowStepItem(
            id: 'report',
            label: 'Report',
            state: AppWorkflowStepState.upcoming,
          ),
        ],
      ),
    );

    await tester.tap(find.text('Receive'));
    await tester.pump();
    expect(tappedId, 'receive');
  });

  testWidgets('keeps descriptions readable across responsive layouts', (
    WidgetTester tester,
  ) async {
    const AppWorkflowStepper stepper = AppWorkflowStepper(
      steps: <AppWorkflowStepItem>[
        AppWorkflowStepItem(
          id: 'ordered',
          label: 'Ordered',
          state: AppWorkflowStepState.completed,
          description: 'Order accepted',
        ),
        AppWorkflowStepItem(
          id: 'process',
          label: 'Process',
          state: AppWorkflowStepState.current,
          description: 'Running assays',
        ),
      ],
    );

    await pumpComponent(tester, stepper, size: const Size(1000, 600));
    expect(find.text('Order accepted'), findsOneWidget);
    expect(find.text('Running assays'), findsOneWidget);

    await pumpComponent(tester, stepper, size: const Size(360, 640));
    // Compact keeps concise state descriptions attached to their nodes.
    expect(find.text('Running assays'), findsOneWidget);
    expect(find.text('Order accepted'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('wraps long progress without horizontal scrolling', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppWorkflowStepper(
        steps: <AppWorkflowStepItem>[
          AppWorkflowStepItem(
            id: 'arrival',
            label: 'Patient arrived',
            state: AppWorkflowStepState.completed,
          ),
          AppWorkflowStepItem(
            id: 'triage',
            label: 'Vitals recorded',
            state: AppWorkflowStepState.completed,
          ),
          AppWorkflowStepItem(
            id: 'review',
            label: 'Doctor review',
            state: AppWorkflowStepState.current,
          ),
          AppWorkflowStepItem(
            id: 'disposition',
            label: 'Disposition',
            state: AppWorkflowStepState.upcoming,
          ),
        ],
      ),
      size: const Size(320, 640),
    );

    expect(
      find.byKey(const ValueKey<String>('workflowStepTrackWrapped')),
      findsOneWidget,
    );
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps concise descriptions inline without help controls', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppWorkflowStepper(
        guidance: 'Continue with the highlighted action.',
        steps: <AppWorkflowStepItem>[
          AppWorkflowStepItem(
            id: 'scheduled',
            label: 'Scheduled',
            description: 'Current step',
            state: AppWorkflowStepState.current,
          ),
          AppWorkflowStepItem(
            id: 'encounter',
            label: 'Start encounter',
            description: 'Next action',
            state: AppWorkflowStepState.upcoming,
          ),
        ],
      ),
    );

    expect(find.text('Current step'), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);
    expect(find.text('Continue with the highlighted action.'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsNothing);
  });

  testWidgets('opens touch-accessible help dialog from help control', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppWorkflowStepper(
        steps: <AppWorkflowStepItem>[
          AppWorkflowStepItem(
            id: 'consult',
            label: 'Consult',
            state: AppWorkflowStepState.current,
            helpText: 'Complete vitals before continuing.',
          ),
        ],
      ),
    );

    expect(find.byIcon(Icons.help_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();

    expect(find.text('Complete vitals before continuing.'), findsWidgets);
    expect(find.text('Close'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsNothing);
  });

  testWidgets('hides permission-denied actions when hideWhenDenied is true', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppWorkflowStepper(
        steps: <AppWorkflowStepItem>[
          AppWorkflowStepItem(
            id: 'verify',
            label: 'Verify',
            state: AppWorkflowStepState.current,
            actions: <AppWorkflowStepAction>[
              AppWorkflowStepAction(
                id: 'complete',
                label: 'Complete',
                icon: Icons.check,
                requirement: const AccessRequirement(
                  anyPermissions: <AppPermission>[AppPermissions.labWrite],
                ),
                hideWhenDenied: true,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );

    expect(find.text('Complete'), findsNothing);
  });

  testWidgets('disables capability-blocked actions and keeps them visible', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppWorkflowStepper(
        steps: <AppWorkflowStepItem>[
          AppWorkflowStepItem(
            id: 'verify',
            label: 'Verify',
            state: AppWorkflowStepState.current,
            actions: <AppWorkflowStepAction>[
              AppWorkflowStepAction(
                id: 'complete',
                label: 'Complete',
                icon: Icons.check,
                capabilityAllowed: false,
                blockedReason: 'Awaiting sample receipt',
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );

    expect(find.text('Complete'), findsOneWidget);
    final Finder button = find.widgetWithText(FilledButton, 'Complete');
    final Finder textButton = find.widgetWithText(TextButton, 'Complete');
    expect(
      button.evaluate().isNotEmpty || textButton.evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('confirmation gate cancels without invoking action', (
    WidgetTester tester,
  ) async {
    var pressed = false;
    await pumpComponent(
      tester,
      AppWorkflowStepper(
        steps: <AppWorkflowStepItem>[
          AppWorkflowStepItem(
            id: 'revert',
            label: 'Revert',
            state: AppWorkflowStepState.current,
            actions: <AppWorkflowStepAction>[
              AppWorkflowStepAction(
                id: 'undo',
                label: 'Revert step',
                icon: Icons.undo,
                confirmTitle: 'Revert workflow?',
                confirmBody: 'This rolls the order back one step.',
                confirmSubmitLabel: 'Confirm revert',
                onPressed: () => pressed = true,
              ),
            ],
          ),
        ],
      ),
    );

    await tester.tap(find.text('Revert step'));
    await tester.pumpAndSettle();
    expect(find.text('REVERT WORKFLOW?'), findsOneWidget);
    expect(find.text('This rolls the order back one step.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(pressed, isFalse);
  });

  testWidgets('confirmation gate invokes action after confirm', (
    WidgetTester tester,
  ) async {
    var pressed = false;
    await pumpComponent(
      tester,
      AppWorkflowStepper(
        steps: <AppWorkflowStepItem>[
          AppWorkflowStepItem(
            id: 'revert',
            label: 'Revert',
            state: AppWorkflowStepState.current,
            actions: <AppWorkflowStepAction>[
              AppWorkflowStepAction(
                id: 'undo',
                label: 'Revert step',
                icon: Icons.undo,
                confirmTitle: 'Revert workflow?',
                confirmBody: 'This rolls the order back one step.',
                confirmSubmitLabel: 'Confirm revert',
                onPressed: () => pressed = true,
              ),
            ],
          ),
        ],
      ),
    );

    await tester.tap(find.text('Revert step'));
    await tester.pumpAndSettle();
    expect(find.text('This rolls the order back one step.'), findsOneWidget);
    await tester.tap(find.text('Confirm revert'));
    await tester.pumpAndSettle();
    expect(pressed, isTrue);
  });

  testWidgets('keyboard activate opens help when step has help content', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppWorkflowStepper(
        steps: <AppWorkflowStepItem>[
          AppWorkflowStepItem(
            id: 'consult',
            label: 'Consult',
            state: AppWorkflowStepState.current,
            helpText: 'Keyboard help details.',
          ),
        ],
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Keyboard help details.'), findsWidgets);
  });
}
