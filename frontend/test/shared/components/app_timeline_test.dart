import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_timeline.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('AppTimeline renders chronological items with labels', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      AppTimeline(
        items: <AppTimelineItem>[
          AppTimelineItem(
            title: 'Ordered',
            occurredAt: DateTime.utc(2026, 1, 1, 10),
            tone: AppWorkspaceStatusTone.info,
          ),
          AppTimelineItem(
            title: 'Reported',
            occurredAt: DateTime.utc(2026, 1, 2, 12),
            tone: AppWorkspaceStatusTone.success,
          ),
        ],
      ),
    );

    expect(find.text('Ordered'), findsOneWidget);
    expect(find.text('Reported'), findsOneWidget);
  });

  testWidgets('AppTimeline shows empty state', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      const AppTimeline(
        emptyTitle: 'No timeline',
        emptyBody: 'Nothing yet',
        items: <AppTimelineItem>[],
      ),
    );

    expect(find.text('No timeline'), findsOneWidget);
    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('AppTimeline invokes onTap for interactive items', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await pumpComponent(
      tester,
      AppTimeline(
        items: <AppTimelineItem>[
          AppTimelineItem(
            title: 'Dispensed batch',
            occurredAt: DateTime.utc(2026, 1, 2, 12),
            onTap: () => tapped = true,
          ),
        ],
      ),
    );

    await tester.tap(find.text('Dispensed batch'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
