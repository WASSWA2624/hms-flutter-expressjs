import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('4'), findsOneWidget);

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
      regions.any((MouseRegion region) => region.cursor == SystemMouseCursors.click),
      isTrue,
    );
  });
}

void _noop() {}
