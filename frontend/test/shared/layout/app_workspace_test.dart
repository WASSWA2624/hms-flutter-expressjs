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
        description: 'Manage active queues and admission handoffs.',
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
}
