import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

import '../components/component_test_app.dart';

void main() {
  testWidgets('AppWorkspace renders header, status, actions, and sections', (
    WidgetTester tester,
  ) async {
    var actionCount = 0;

    await pumpComponent(
      tester,
      AppWorkspace(
        title: 'Admissions',
        status: const AppWorkspaceStatus(
          label: 'Operational',
          tone: AppWorkspaceStatusTone.success,
        ),
        primaryAction: AppButton.primary(
          label: 'Create',
          onPressed: () {
            actionCount += 1;
          },
        ),
        summaryCards: const <Widget>[
          AppWorkspaceSummaryCard(label: 'Waiting', value: '12'),
        ],
        filters: const AppWorkspaceFilterBar(
          search: Text('Search'),
          filters: <Widget>[Text('Status filter')],
        ),
        body: const Text('Workspace body'),
        activity: const AppWorkspaceActivityList(
          title: 'Activity',
          items: <AppWorkspaceActivityItem>[
            AppWorkspaceActivityItem(
              title: 'Patient admitted',
              subtitle: 'Today 08:30',
            ),
          ],
        ),
      ),
      size: const Size(1000, 800),
    );

    expect(find.text('Admissions'), findsOneWidget);
    expect(find.text('Operational'), findsOneWidget);
    expect(find.text('Waiting'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Workspace body'), findsOneWidget);
    expect(find.text('Patient admitted'), findsOneWidget);

    await tester.tap(find.text('Create'));
    await tester.pump();

    expect(actionCount, 1);
  });

  testWidgets('AppWorkspaceSummaryGrid stacks cards on narrow screens', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppWorkspaceSummaryGrid(
        children: <Widget>[
          AppWorkspaceSummaryCard(label: 'First', value: '1'),
          AppWorkspaceSummaryCard(label: 'Second', value: '2'),
        ],
      ),
      size: const Size(420, 600),
    );

    final Offset firstTop = tester.getTopLeft(find.text('First'));
    final Offset secondTop = tester.getTopLeft(find.text('Second'));

    expect(secondTop.dy, greaterThan(firstTop.dy));
  });

  testWidgets('AppWorkspaceSummaryGrid uses columns on wide screens', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppWorkspaceSummaryGrid(
        children: <Widget>[
          AppWorkspaceSummaryCard(label: 'First', value: '1'),
          AppWorkspaceSummaryCard(label: 'Second', value: '2'),
        ],
      ),
      size: const Size(1200, 600),
    );

    final Offset firstTop = tester.getTopLeft(find.text('First'));
    final Offset secondTop = tester.getTopLeft(find.text('Second'));

    expect(secondTop.dy, closeTo(firstTop.dy, 0.1));
    expect(secondTop.dx, greaterThan(firstTop.dx));
  });

  testWidgets('AppWorkspaceSummaryGrid compacts into two medium columns', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppWorkspaceSummaryGrid(
        compact: true,
        children: <Widget>[
          AppWorkspaceSummaryCard(label: 'First', value: '1', compact: true),
          AppWorkspaceSummaryCard(label: 'Second', value: '2', compact: true),
          AppWorkspaceSummaryCard(label: 'Third', value: '3', compact: true),
          AppWorkspaceSummaryCard(label: 'Fourth', value: '4', compact: true),
        ],
      ),
      size: const Size(662, 600),
    );

    final Offset firstTop = tester.getTopLeft(find.text('First'));
    final Offset secondTop = tester.getTopLeft(find.text('Second'));
    final Offset thirdTop = tester.getTopLeft(find.text('Third'));

    expect(secondTop.dy, closeTo(firstTop.dy, 0.1));
    expect(secondTop.dx, greaterThan(firstTop.dx));
    expect(thirdTop.dy, greaterThan(firstTop.dy));
  });

  testWidgets('AppWorkspaceSummaryGrid fits four compact desktop cards', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppWorkspaceSummaryGrid(
        compact: true,
        children: <Widget>[
          AppWorkspaceSummaryCard(label: 'First', value: '1', compact: true),
          AppWorkspaceSummaryCard(label: 'Second', value: '2', compact: true),
          AppWorkspaceSummaryCard(label: 'Third', value: '3', compact: true),
          AppWorkspaceSummaryCard(label: 'Fourth', value: '4', compact: true),
        ],
      ),
      size: const Size(1000, 600),
    );

    final Offset firstTop = tester.getTopLeft(find.text('First'));
    final Offset secondTop = tester.getTopLeft(find.text('Second'));
    final Offset thirdTop = tester.getTopLeft(find.text('Third'));
    final Offset fourthTop = tester.getTopLeft(find.text('Fourth'));

    expect(secondTop.dy, closeTo(firstTop.dy, 0.1));
    expect(thirdTop.dy, closeTo(firstTop.dy, 0.1));
    expect(fourthTop.dy, closeTo(firstTop.dy, 0.1));
    expect(fourthTop.dx, greaterThan(thirdTop.dx));
  });

  testWidgets('AppWorkspaceSplitContent switches from side panel to stack', (
    WidgetTester tester,
  ) async {
    const primaryKey = ValueKey<String>('primary');
    const detailKey = ValueKey<String>('detail');

    await pumpComponent(
      tester,
      const AppWorkspaceSplitContent(
        primary: SizedBox(key: primaryKey, height: 64, child: Text('List')),
        detail: SizedBox(key: detailKey, height: 64, child: Text('Details')),
      ),
      size: const Size(1100, 600),
    );

    final Offset widePrimaryTop = tester.getTopLeft(find.byKey(primaryKey));
    final Offset wideDetailTop = tester.getTopLeft(find.byKey(detailKey));

    expect(wideDetailTop.dy, closeTo(widePrimaryTop.dy, 0.1));
    expect(wideDetailTop.dx, greaterThan(widePrimaryTop.dx));

    await pumpComponent(
      tester,
      const AppWorkspaceSplitContent(
        primary: SizedBox(key: primaryKey, height: 64, child: Text('List')),
        detail: SizedBox(key: detailKey, height: 64, child: Text('Details')),
      ),
      size: const Size(500, 600),
    );

    final Offset narrowPrimaryTop = tester.getTopLeft(find.byKey(primaryKey));
    final Offset narrowDetailTop = tester.getTopLeft(find.byKey(detailKey));

    expect(narrowDetailTop.dy, greaterThan(narrowPrimaryTop.dy));
  });

  testWidgets('AppWorkspaceActivityList renders empty state consistently', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppWorkspaceActivityList(
        title: 'Audit',
        items: <AppWorkspaceActivityItem>[],
        emptyTitle: 'No activity',
        emptyBody: 'Audit events will appear here.',
      ),
    );

    expect(find.text('Audit'), findsOneWidget);
    expect(find.text('No activity'), findsOneWidget);
    expect(find.text('Audit events will appear here.'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('AppWorkspaceStatePanel exposes standard workspace states', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const Column(
        children: <Widget>[
          AppWorkspaceStatePanel.forbidden(
            title: 'Restricted',
            body: 'You cannot view this workspace.',
            minHeight: 120,
          ),
          AppWorkspaceStatePanel.offline(
            title: 'Offline',
            body: 'Reconnect before loading records.',
            minHeight: 120,
          ),
        ],
      ),
    );

    expect(find.text('Restricted'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
  });

  testWidgets('AppWorkspaceStatePanel exposes validation and success states', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const Column(
        children: <Widget>[
          AppWorkspaceStatePanel.validation(
            title: 'Review form',
            body: 'Fix highlighted fields before submitting.',
            minHeight: 120,
          ),
          AppWorkspaceStatePanel.success(
            title: 'Saved',
            body: 'The workspace has the latest values.',
            minHeight: 120,
          ),
        ],
      ),
    );

    expect(find.text('Review form'), findsOneWidget);
    expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('AppWorkspacePatientContextHeader renders patient context', (
    WidgetTester tester,
  ) async {
    var actionCount = 0;

    await pumpComponent(
      tester,
      AppWorkspacePatientContextHeader(
        patientName: 'Amina Kato',
        patientNumber: 'MRN-10024',
        demographics: '34y | Female',
        status: const AppWorkspaceStatus(
          label: 'Waiting Doctor',
          tone: AppWorkspaceStatusTone.info,
        ),
        alerts: const <AppWorkspaceStatus>[
          AppWorkspaceStatus(
            label: 'Penicillin allergy',
            tone: AppWorkspaceStatusTone.error,
          ),
        ],
        fields: const <AppWorkspacePatientContextField>[
          AppWorkspacePatientContextField(
            label: 'Encounter',
            value: 'OPD-2026-0007',
            icon: Icons.assignment_outlined,
          ),
          AppWorkspacePatientContextField(
            label: 'Location',
            value: 'Clinic 2',
            icon: Icons.location_on_outlined,
          ),
          AppWorkspacePatientContextField(
            label: 'Coverage',
            value: 'Insurance active',
            icon: Icons.verified_user_outlined,
            tone: AppWorkspaceStatusTone.success,
          ),
        ],
        actions: <Widget>[
          AppButton.secondary(
            label: 'View',
            onPressed: () {
              actionCount += 1;
            },
          ),
        ],
      ),
      size: const Size(900, 500),
    );

    expect(find.text('Amina Kato'), findsOneWidget);
    expect(find.text('MRN-10024'), findsOneWidget);
    expect(find.text('34y | Female'), findsOneWidget);
    expect(find.text('Waiting Doctor'), findsOneWidget);
    expect(find.text('Penicillin allergy'), findsOneWidget);
    expect(find.text('Encounter'), findsOneWidget);
    expect(find.text('Coverage'), findsOneWidget);

    await tester.tap(find.text('View'));
    await tester.pump();

    expect(actionCount, 1);
  });

  testWidgets('AppWorkspacePatientContextHeader adapts field layout', (
    WidgetTester tester,
  ) async {
    const Widget header = AppWorkspacePatientContextHeader(
      patientName: 'Amina Kato',
      patientNumber: 'MRN-10024',
      fields: <AppWorkspacePatientContextField>[
        AppWorkspacePatientContextField(label: 'Encounter', value: 'OPD-1'),
        AppWorkspacePatientContextField(label: 'Location', value: 'Ward A'),
      ],
    );

    await pumpComponent(tester, header, size: const Size(420, 500));

    final Offset narrowEncounterTop = tester.getTopLeft(find.text('Encounter'));
    final Offset narrowLocationTop = tester.getTopLeft(find.text('Location'));

    expect(narrowLocationTop.dy, greaterThan(narrowEncounterTop.dy));

    await pumpComponent(tester, header, size: const Size(900, 500));

    final Offset wideEncounterTop = tester.getTopLeft(find.text('Encounter'));
    final Offset wideLocationTop = tester.getTopLeft(find.text('Location'));

    expect(wideLocationTop.dy, closeTo(wideEncounterTop.dy, 0.1));
    expect(wideLocationTop.dx, greaterThan(wideEncounterTop.dx));
  });

  testWidgets('showAppWorkspaceActionDialog opens a standard modal action', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open',
            onPressed: () {
              unawaited(
                showAppWorkspaceActionDialog<void>(
                  context: context,
                  title: const Text('Create record'),
                  content: const Text('Short form content'),
                  actions: <Widget>[
                    AppButton.primary(
                      label: 'Done',
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Create record'), findsOneWidget);
    expect(find.text('Short form content'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Create record'), findsNothing);
  });

  testWidgets(
    'showAppWorkspaceDetailDrawer opens an end-aligned detail panel',
    (WidgetTester tester) async {
      await pumpComponent(
        tester,
        Builder(
          builder: (BuildContext context) {
            return AppButton.primary(
              label: 'Inspect',
              onPressed: () {
                unawaited(
                  showAppWorkspaceDetailDrawer<void>(
                    context: context,
                    title: const Text('Patient details'),
                    description: const Text('Current visit context'),
                    child: const Text('Detail drawer body'),
                    actions: <Widget>[
                      AppButton.primary(
                        label: 'Close',
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        size: const Size(1000, 700),
      );

      await tester.tap(find.text('Inspect'));
      await tester.pumpAndSettle();

      expect(find.text('Patient details'), findsOneWidget);
      expect(find.text('Current visit context'), findsOneWidget);
      expect(find.text('Detail drawer body'), findsOneWidget);

      final Offset drawerTitleTop = tester.getTopLeft(
        find.text('Patient details'),
      );
      expect(drawerTitleTop.dx, greaterThan(500));

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Patient details'), findsNothing);
    },
  );
}
