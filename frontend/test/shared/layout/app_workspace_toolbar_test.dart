import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

import '../components/component_test_app.dart';

void main() {
  testWidgets('toolbar overflow shows notifications submenu with counts', (
    WidgetTester tester,
  ) async {
    var filterApplied = false;

    await pumpComponent(
      tester,
      ProviderScope(
        child: AppWorkspace(
          title: 'Lab',
          toolbar: AppWorkspaceToolbarConfig(
            summaryNotifications: <AppWorkspaceSummaryNotification>[
              AppWorkspaceSummaryNotification(
                label: 'Pending collection',
                count: 4,
                icon: Icons.biotech_outlined,
                tone: AppWorkspaceStatusTone.warning,
                onSelected: () {
                  filterApplied = true;
                },
              ),
            ],
            notificationsMenuLabel: 'Notifications',
            overflowLabel: 'More actions',
          ),
          body: const Text('Worklist'),
        ),
      ),
      size: const Size(900, 600),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Pending collection'), findsOneWidget);
    expect(find.text('4'), findsNWidgets(2));

    await tester.tap(find.text('Pending collection'));
    await tester.pump();

    expect(filterApplied, isTrue);
  });

  testWidgets('notifications parent is hidden when all counts are zero', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const ProviderScope(
        child: AppWorkspace(
          title: 'Lab',
          toolbar: AppWorkspaceToolbarConfig(
            showGlobalActions: false,
            summaryNotifications: <AppWorkspaceSummaryNotification>[
              AppWorkspaceSummaryNotification(
                label: 'Hidden queue',
                count: 0,
                icon: Icons.queue_outlined,
                onSelected: _noop,
              ),
            ],
            notificationsMenuLabel: 'Notifications',
            overflowLabel: 'More actions',
          ),
          body: Text('Worklist'),
        ),
      ),
      size: const Size(900, 600),
    );

    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text('Notifications'), findsNothing);
  });

  testWidgets('notifications parent shows aggregate count badge', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const ProviderScope(
        child: AppWorkspace(
          title: 'Lab',
          toolbar: AppWorkspaceToolbarConfig(
            summaryNotifications: <AppWorkspaceSummaryNotification>[
              AppWorkspaceSummaryNotification(
                label: 'Pending collection',
                count: 4,
                icon: Icons.biotech_outlined,
                onSelected: _noop,
              ),
              AppWorkspaceSummaryNotification(
                label: 'Critical results',
                count: 2,
                icon: Icons.warning_amber_outlined,
                onSelected: _noop,
              ),
            ],
            notificationsMenuLabel: 'Notifications',
            overflowLabel: 'More actions',
          ),
          body: Text('Worklist'),
        ),
      ),
      size: const Size(900, 600),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('more actions trigger shows attention dot when counts pending', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const ProviderScope(
        child: AppWorkspace(
          title: 'Billing',
          toolbar: AppWorkspaceToolbarConfig(
            showGlobalActions: false,
            summaryNotifications: <AppWorkspaceSummaryNotification>[
              AppWorkspaceSummaryNotification(
                label: 'Awaiting payment',
                count: 2,
                icon: Icons.payments_outlined,
                onSelected: _noop,
              ),
            ],
            overflowLabel: 'More actions',
          ),
          body: Text('Worklist'),
        ),
      ),
      size: const Size(900, 600),
    );

    expect(find.byType(Badge), findsOneWidget);
  });

  testWidgets('attention dot hidden when all notification counts are zero', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const ProviderScope(
        child: AppWorkspace(
          title: 'Billing',
          toolbar: AppWorkspaceToolbarConfig(
            showGlobalActions: false,
            summaryNotifications: <AppWorkspaceSummaryNotification>[
              AppWorkspaceSummaryNotification(
                label: 'Awaiting payment',
                count: 0,
                icon: Icons.payments_outlined,
                onSelected: _noop,
              ),
            ],
            overflowLabel: 'More actions',
          ),
          body: Text('Worklist'),
        ),
      ),
      size: const Size(900, 600),
    );

    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('notifications submenu uses constrained cross axis', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const ProviderScope(
        child: AppWorkspace(
          title: 'Lab',
          toolbar: AppWorkspaceToolbarConfig(
            summaryNotifications: <AppWorkspaceSummaryNotification>[
              AppWorkspaceSummaryNotification(
                label: 'Pending collection',
                count: 4,
                icon: Icons.biotech_outlined,
                onSelected: _noop,
              ),
            ],
            notificationsMenuLabel: 'Notifications',
            overflowLabel: 'More actions',
          ),
          body: Text('Worklist'),
        ),
      ),
      size: const Size(900, 600),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    final List<MenuAnchor> menuAnchors = tester
        .widgetList<MenuAnchor>(find.byType(MenuAnchor))
        .toList();
    expect(menuAnchors.length, greaterThanOrEqualTo(2));
    expect(menuAnchors.last.crossAxisUnconstrained, isFalse);
    expect(menuAnchors.last.alignmentOffset, const Offset(-1, 0));
  });

  testWidgets('more actions trigger uses pointer cursor', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const ProviderScope(
        child: AppWorkspace(
          title: 'Billing',
          toolbar: AppWorkspaceToolbarConfig(
            showGlobalActions: false,
            summaryNotifications: <AppWorkspaceSummaryNotification>[
              AppWorkspaceSummaryNotification(
                label: 'Awaiting payment',
                count: 2,
                icon: Icons.payments_outlined,
                onSelected: _noop,
              ),
            ],
            overflowLabel: 'More actions',
          ),
          body: Text('Worklist'),
        ),
      ),
      size: const Size(900, 600),
    );

    final Finder trigger = find.byIcon(Icons.more_vert);
    expect(trigger, findsOneWidget);

    final Iterable<MouseRegion> regions = tester.widgetList<MouseRegion>(
      find.descendant(
        of: find.byType(MenuAnchor),
        matching: find.byType(MouseRegion),
      ),
    );
    expect(
      regions.any(
        (MouseRegion region) => region.cursor == SystemMouseCursors.click,
      ),
      isTrue,
    );
  });

  testWidgets('sectioned overflow renders headers and dividers in order', (
    WidgetTester tester,
  ) async {
    final Widget manageAccess = AppButton.secondary(
      label: 'Manage users and roles',
      leadingIcon: Icons.manage_accounts_outlined,
      onPressed: () {},
    );
    final Widget scheduleTemplates = AppButton.secondary(
      label: 'Create schedule template',
      leadingIcon: Icons.view_week_outlined,
      onPressed: () {},
    );
    final Widget hrActivity = AppButton.secondary(
      label: 'HR activity',
      leadingIcon: Icons.timeline_outlined,
      onPressed: () {},
    );
    final Widget refreshAction = AppWorkspaceRefreshAction(
      label: 'Refresh',
      onPressed: () {},
    );

    await pumpComponent(
      tester,
      ProviderScope(
        child: AppWorkspace(
          title: 'HR',
          toolbar: AppWorkspaceToolbarConfig(
            showGlobalActions: false,
            maxVisibleScreenActions: 0,
            overflowLabel: 'More actions',
            toolbarLayoutActions: <Widget>[
              manageAccess,
              scheduleTemplates,
              hrActivity,
              refreshAction,
            ],
            overflowSections: <AppToolbarOverflowSection>[
              AppToolbarOverflowSection(
                headerLabel: 'Staff & access',
                actions: <Widget>[manageAccess],
              ),
              AppToolbarOverflowSection(
                headerLabel: 'Scheduling & roster',
                actions: <Widget>[scheduleTemplates],
              ),
              AppToolbarOverflowSection(
                headerLabel: 'Activity & audit',
                actions: <Widget>[hrActivity],
              ),
              AppToolbarOverflowSection(
                headerLabel: 'Workspace',
                actions: <Widget>[refreshAction],
              ),
            ],
          ),
          body: const Text('Directory'),
        ),
      ),
      size: const Size(900, 600),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Staff & access'), findsOneWidget);
    expect(find.text('Scheduling & roster'), findsOneWidget);
    expect(find.text('Activity & audit'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(3));
    expect(find.byIcon(Icons.manage_accounts_outlined), findsOneWidget);
    expect(find.byIcon(Icons.view_week_outlined), findsOneWidget);
    expect(find.byIcon(Icons.timeline_outlined), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('facilities section hidden when both global actions disallowed', (
    WidgetTester tester,
  ) async {
    const Widget housekeepingAction = AppGlobalHousekeepingRequestAction(
      label: 'Request maintenance',
    );
    const Widget faultReportAction = AppGlobalFaultReportAction(
      label: 'Report equipment fault',
    );

    await pumpComponent(
      tester,
      const ProviderScope(
        child: AppWorkspace(
          title: 'HR',
          toolbar: AppWorkspaceToolbarConfig(
            showGlobalActions: false,
            maxVisibleScreenActions: 0,
            overflowLabel: 'More actions',
            toolbarLayoutActions: <Widget>[
              housekeepingAction,
              faultReportAction,
            ],
            overflowSections: <AppToolbarOverflowSection>[
              AppToolbarOverflowSection(
                headerLabel: 'Facilities',
                actions: <Widget>[housekeepingAction, faultReportAction],
              ),
            ],
          ),
          body: Text('Directory'),
        ),
      ),
      size: const Size(900, 600),
    );

    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text('Facilities'), findsNothing);
  });

  testWidgets('sectioned overflow keeps notifications in approvals section', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const ProviderScope(
        child: AppWorkspace(
          title: 'HR',
          toolbar: AppWorkspaceToolbarConfig(
            showGlobalActions: false,
            maxVisibleScreenActions: 0,
            overflowLabel: 'More actions',
            summaryNotifications: <AppWorkspaceSummaryNotification>[
              AppWorkspaceSummaryNotification(
                label: 'Leave requests',
                count: 2,
                icon: Icons.event_busy_outlined,
                onSelected: _noop,
              ),
            ],
            notificationsMenuLabel: 'Notifications',
            overflowSections: <AppToolbarOverflowSection>[
              AppToolbarOverflowSection(
                headerLabel: 'Approvals & alerts',
                showsNotifications: true,
              ),
            ],
          ),
          body: Text('Directory'),
        ),
      ),
      size: const Size(900, 600),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Approvals & alerts'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('mobile toolbar keeps primary action inline as icon only', (
    WidgetTester tester,
  ) async {
    var primaryTapped = false;

    await pumpComponent(
      tester,
      ProviderScope(
        child: AppWorkspace(
          title: 'Patients',
          leadingIcon: Icons.people_outline,
          toolbar: AppWorkspaceToolbarConfig(
            primary: AppButton.primary(
              leadingIcon: Icons.person_add_alt_1_outlined,
              label: 'Register patient',
              onPressed: () {
                primaryTapped = true;
              },
            ),
            onRefresh: () async {},
            overflowLabel: 'More actions',
          ),
          body: const Text('Worklist'),
        ),
      ),
      size: const Size(330, 600),
    );

    expect(find.text('Patients'), findsNothing);
    expect(find.text('Register patient'), findsNothing);
    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_add_alt_1_outlined));
    await tester.pump();

    expect(primaryTapped, isTrue);
  });

  testWidgets('tablet toolbar shows title but keeps primary action icon only', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      ProviderScope(
        child: AppWorkspace(
          title: 'Patients',
          leadingIcon: Icons.people_outline,
          toolbar: AppWorkspaceToolbarConfig(
            primary: AppButton.primary(
              leadingIcon: Icons.person_add_alt_1_outlined,
              label: 'Register patient',
              onPressed: () {},
            ),
            onRefresh: () async {},
            overflowLabel: 'More actions',
          ),
          body: const Text('Worklist'),
        ),
      ),
      size: const Size(649, 600),
    );

    expect(find.text('Patients'), findsOneWidget);
    expect(find.text('Register patient'), findsNothing);
    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
  });

  testWidgets('desktop toolbar shows primary action label', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      ProviderScope(
        child: AppWorkspace(
          title: 'Patients',
          leadingIcon: Icons.people_outline,
          toolbar: AppWorkspaceToolbarConfig(
            primary: AppButton.primary(
              leadingIcon: Icons.person_add_alt_1_outlined,
              label: 'Register patient',
              onPressed: () {},
            ),
            onRefresh: () async {},
            overflowLabel: 'More actions',
          ),
          body: const Text('Worklist'),
        ),
      ),
      size: const Size(900, 600),
    );

    expect(find.text('Patients'), findsOneWidget);
    expect(find.text('Register patient'), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
  });

  testWidgets(
    'mobile toolbar keeps pinned primary inline with summary notifications',
    (WidgetTester tester) async {
      var primaryTapped = false;

      await pumpComponent(
        tester,
        ProviderScope(
          child: AppWorkspace(
            title: 'Patients',
            leadingIcon: Icons.people_outline,
            toolbar: AppWorkspaceToolbarConfig(
              primary: AppButton.primary(
                leadingIcon: Icons.person_add_alt_1_outlined,
                label: 'Register patient',
                onPressed: () {
                  primaryTapped = true;
                },
              ),
              summaryNotifications: <AppWorkspaceSummaryNotification>[
                const AppWorkspaceSummaryNotification(
                  label: 'All patients',
                  count: 12,
                  icon: Icons.groups_outlined,
                  onSelected: _noop,
                ),
                const AppWorkspaceSummaryNotification(
                  label: 'Active patients',
                  count: 8,
                  icon: Icons.how_to_reg_outlined,
                  onSelected: _noop,
                ),
              ],
              onRefresh: () async {},
              overflowLabel: 'More actions',
            ),
            body: const Text('Worklist'),
          ),
        ),
        size: const Size(330, 600),
      );
      await tester.pumpAndSettle();

      expect(find.text('Register patient'), findsNothing);
      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_add_alt_1_outlined));
      await tester.pump();

      expect(primaryTapped, isTrue);
    },
  );
}

void _noop() {}
