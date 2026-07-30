import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

import '../components/component_test_app.dart';

void main() {
  testWidgets('AppWorkspace renders header, actions, and sections', (
    WidgetTester tester,
  ) async {
    var actionCount = 0;

    await pumpComponent(
      tester,
      ProviderScope(
        child: AppWorkspace(
          title: 'Admissions',
          primaryAction: AppButton.primary(
            label: 'Create',
            onPressed: () {
              actionCount += 1;
            },
          ),
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
      ),
      size: const Size(1000, 800),
    );

    expect(find.text('Admissions'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Workspace body'), findsOneWidget);
    expect(find.text('Patient admitted'), findsOneWidget);

    await tester.tap(find.text('Create'));
    await tester.pump();

    expect(actionCount, 1);
  });

  testWidgets('AppWorkspace hides title text on compact mobile widths', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const ProviderScope(
        child: AppWorkspace(
          title: 'Patient registry',
          leadingIcon: Icons.people_outline,
          body: Text('Workspace body'),
        ),
      ),
      size: const Size(330, 600),
    );

    expect(find.text('Patient registry'), findsNothing);
    expect(find.byIcon(Icons.people_outline), findsOneWidget);
  });

  testWidgets('AppWorkspace keeps title text on tablet widths', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const ProviderScope(
        child: AppWorkspace(
          title: 'Patient registry',
          leadingIcon: Icons.people_outline,
          body: Text('Workspace body'),
        ),
      ),
      size: const Size(720, 600),
    );

    expect(find.text('Patient registry'), findsOneWidget);
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
      fieldStyle: AppWorkspacePatientContextFieldStyle.tiles,
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

  testWidgets(
    'AppWorkspacePatientContextHeader inline facts stay in one overflow row',
    (WidgetTester tester) async {
      await pumpComponent(
        tester,
        const AppWorkspacePatientContextHeader(
          patientName: 'Amina Kato',
          patientNumber: 'MRN-10024',
          fieldStyle: AppWorkspacePatientContextFieldStyle.inline,
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: 'Encounter',
              value: 'OPD-1',
              icon: Icons.assignment_outlined,
            ),
            AppWorkspacePatientContextField(
              label: 'Location',
              value: 'Ward A',
              icon: Icons.location_on_outlined,
            ),
            AppWorkspacePatientContextField(
              label: 'Coverage',
              value: 'Insurance active',
              icon: Icons.verified_user_outlined,
            ),
          ],
        ),
        size: const Size(320, 500),
      );

      expect(find.textContaining('Encounter:'), findsOneWidget);
      expect(find.textContaining('Location:'), findsOneWidget);
      expect(find.textContaining('Coverage:'), findsOneWidget);
      expect(find.text('|'), findsNWidgets(2));
      expect(find.byType(SingleChildScrollView), findsWidgets);

      final double encounterY = tester
          .getTopLeft(find.textContaining('Encounter:'))
          .dy;
      final double coverageY = tester
          .getTopLeft(find.textContaining('Coverage:'))
          .dy;
      expect(coverageY, closeTo(encounterY, 1));
    },
  );

  testWidgets(
    'AppWorkspacePatientContextHeader merges fields into meta line and shows action labels',
    (WidgetTester tester) async {
      await pumpComponent(
        tester,
        AppWorkspacePatientContextHeader(
          patientName: 'Amina Kato',
          patientNumber: 'MRN-10024',
          patientNumberLabel: 'Patient ID',
          status: const AppWorkspaceStatus(
            label: 'Ordered',
            tone: AppWorkspaceStatusTone.warning,
          ),
          mergeFieldsIntoMetaLine: true,
          showActionLabels: true,
          fields: const <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: 'Study',
              value: 'Chest X-ray',
            ),
            AppWorkspacePatientContextField(
              label: 'Payment',
              value: 'Billing gate unavailable',
              tone: AppWorkspaceStatusTone.warning,
            ),
          ],
          actions: <Widget>[
            AppButton.secondary(
              label: 'Assign',
              leadingIcon: Icons.person_add_alt_outlined,
              onPressed: () {},
            ),
          ],
        ),
        size: const Size(1400, 500),
      );

      final Offset patientIdTop = tester.getTopLeft(find.text('Patient ID:'));
      final Offset studyTop = tester.getTopLeft(find.textContaining('Study'));
      final Offset paymentTop = tester.getTopLeft(
        find.textContaining('Payment'),
      );

      expect(studyTop.dy - patientIdTop.dy, lessThan(50));
      expect(paymentTop.dy - patientIdTop.dy, lessThan(50));
      expect(find.text('Assign'), findsOneWidget);
      expect(find.text('Billing gate unavailable'), findsOneWidget);
    },
  );

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

  testWidgets(
    'AppWorkspacePatientContextHeader copies patient and encounter identifiers',
    (WidgetTester tester) async {
      final List<String> copiedValues = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final arguments = Map<Object?, Object?>.from(
              methodCall.arguments as Map,
            );
            copiedValues.add(arguments['text']! as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpComponent(
        tester,
        const AppWorkspacePatientContextHeader(
          patientName: 'Amina Kato',
          patientNumber: 'MRN-10024',
          fields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: 'Encounter',
              value: 'OPD-2026-0007',
              copyable: true,
              copiedMessage: 'Encounter ID copied.',
            ),
          ],
        ),
        size: const Size(900, 500),
      );

      await tester.tap(find.text('MRN-10024'));
      await tester.pump();
      await tester.tap(find.text('OPD-2026-0007'));
      await tester.pump();

      expect(copiedValues, <String>['MRN-10024', 'OPD-2026-0007']);
      expect(find.byIcon(Icons.check), findsWidgets);
    },
  );

  testWidgets('AppCollapsibleSection collapses to header by default', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppCollapsibleSection(
        title: 'Orders',
        child: Text('Panel body'),
      ),
      size: const Size(800, 500),
    );

    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Panel body'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);

    final Text title = tester.widget<Text>(find.text('Orders'));
    expect(title.style?.fontWeight, FontWeight.w700);

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Panel body'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets(
    'AppCollapsibleSection keeps expand chevron extreme-right of header actions',
    (WidgetTester tester) async {
      await pumpComponent(
        tester,
        AppCollapsibleSection(
          title: 'CBC PANEL',
          headerActions: <Widget>[
            AppButton(
              iconOnly: true,
              leadingIcon: Icons.delete_outline,
              label: 'Delete',
              onPressed: () {},
            ),
          ],
          child: const Text('Panel body'),
        ),
        size: const Size(800, 500),
      );

      final Offset deleteCenter = tester.getCenter(
        find.byIcon(Icons.delete_outline),
      );
      final Offset chevronCenter = tester.getCenter(
        find.byIcon(Icons.expand_less),
      );
      expect(chevronCenter.dx, greaterThan(deleteCenter.dx));

      final Text title = tester.widget<Text>(find.text('CBC PANEL'));
      expect(title.style?.fontWeight, FontWeight.w700);
    },
  );

  testWidgets('AppCollapsibleSection can opt out of collapsing', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppCollapsibleSection(
        title: 'Fixed panel',
        collapsible: false,
        child: Text('Always visible'),
      ),
      size: const Size(800, 500),
    );

    expect(find.text('Always visible'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('appCollapsibleSectionSpacing inserts gaps between sections', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      Builder(
        builder: (BuildContext context) {
          return Column(
            children: appCollapsibleSectionSpacing(context, const <Widget>[
              AppCollapsibleSection(title: 'One', child: Text('A')),
              AppCollapsibleSection(title: 'Two', child: Text('B')),
            ]),
          );
        },
      ),
      size: const Size(800, 500),
    );

    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('AppSectionPanel with title uses collapsible AppCollapsibleSection', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppSectionPanel(
        title: 'Similarity matches',
        children: <Widget>[Text('Match row')],
      ),
      size: const Size(800, 500),
    );

    expect(find.byType(AppCollapsibleSection), findsOneWidget);
    expect(find.text('Similarity matches'), findsOneWidget);
    expect(find.text('Match row'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();

    expect(find.text('Match row'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('AppFormSection with title uses collapsible AppCollapsibleSection', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppFormSection(
        title: 'Patient details',
        children: <Widget>[Text('Form field')],
      ),
      size: const Size(800, 500),
    );

    expect(find.byType(AppCollapsibleSection), findsOneWidget);
    expect(find.text('Patient details'), findsOneWidget);
    expect(find.text('Form field'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();

    expect(find.text('Form field'), findsNothing);
  });

  testWidgets('AppCollapsibleSection collapses description with body', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppCollapsibleSection(
        title: 'Account',
        description: 'Manage account settings',
        child: Text('Account body'),
      ),
      size: const Size(800, 500),
    );

    expect(find.byType(AppCollapsibleSection), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Manage account settings'), findsOneWidget);
    expect(find.text('Account body'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();

    expect(find.text('Account body'), findsNothing);
    expect(find.text('Manage account settings'), findsNothing);
  });
}
